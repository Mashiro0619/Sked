use std::{
    collections::BTreeMap,
    fmt,
    fs::{File, OpenOptions},
    io::{BufRead, BufReader, Read, Seek, SeekFrom, Write},
    path::Path,
};

use serde::{
    Deserialize, Serialize,
    de::{DeserializeSeed, IgnoredAny, MapAccess, SeqAccess, Visitor},
};
use serde_json::Value;

use super::{
    error::{Result, StorageError},
    models::JournalCommit,
};

#[derive(Debug, Clone, Copy)]
pub(crate) struct Location {
    pub offset: u64,
    pub length: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub(crate) enum PathPart {
    Field(String),
    Item(usize),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct RecordPath(pub Vec<PathPart>);

impl RecordPath {
    pub fn change(index: usize, field: &str) -> Self {
        Self(vec![
            PathPart::Field("changes".into()),
            PathPart::Item(index),
            PathPart::Field("data".into()),
            PathPart::Field(field.into()),
        ])
    }

    pub fn field(mut self, field: &str) -> Self {
        self.0.push(PathPart::Field(field.into()));
        self
    }

    pub fn item(mut self, index: usize) -> Self {
        self.0.push(PathPart::Item(index));
        self
    }
}

#[derive(Default)]
struct Selection {
    targets: Vec<usize>,
    children: BTreeMap<PathPart, Selection>,
}

struct SelectedSeed<'a> {
    selection: &'a Selection,
    values: &'a mut [Option<Value>],
    omitted_fields: &'a [&'a str],
}

impl<'de> DeserializeSeed<'de> for SelectedSeed<'_> {
    type Value = ();

    fn deserialize<D: serde::Deserializer<'de>>(
        self,
        deserializer: D,
    ) -> std::result::Result<(), D::Error> {
        if !self.selection.targets.is_empty() {
            let value = if self.omitted_fields.is_empty() {
                Value::deserialize(deserializer)?
            } else {
                deserializer.deserialize_map(DisplayRecord {
                    omitted_fields: self.omitted_fields,
                })?
            };
            for &target in &self.selection.targets {
                self.values[target] = Some(value.clone());
            }
            return Ok(());
        }
        deserializer.deserialize_any(self)
    }
}

impl<'de> Visitor<'de> for SelectedSeed<'_> {
    type Value = ();

    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("a journal object or array containing an indexed record")
    }

    fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> std::result::Result<(), A::Error> {
        while let Some(key) = map.next_key::<String>()? {
            if let Some(selection) = self.selection.children.get(&PathPart::Field(key)) {
                map.next_value_seed(SelectedSeed {
                    selection,
                    values: &mut *self.values,
                    omitted_fields: self.omitted_fields,
                })?;
            } else {
                map.next_value::<IgnoredAny>()?;
            }
        }
        Ok(())
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut sequence: A) -> std::result::Result<(), A::Error> {
        let mut index = 0;
        loop {
            let found = if let Some(selection) = self.selection.children.get(&PathPart::Item(index))
            {
                sequence
                    .next_element_seed(SelectedSeed {
                        selection,
                        values: &mut *self.values,
                        omitted_fields: self.omitted_fields,
                    })?
                    .is_some()
            } else {
                sequence.next_element::<IgnoredAny>()?.is_some()
            };
            if !found {
                break;
            }
            index += 1;
        }
        Ok(())
    }
}

struct DisplayRecord<'a> {
    omitted_fields: &'a [&'a str],
}

impl<'de> Visitor<'de> for DisplayRecord<'_> {
    type Value = Value;
    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("an indexed display record")
    }
    fn visit_map<A: MapAccess<'de>>(self, mut map: A) -> std::result::Result<Value, A::Error> {
        let mut value = serde_json::Map::new();
        while let Some(key) = map.next_key::<String>()? {
            if self.omitted_fields.contains(&key.as_str()) {
                map.next_value::<IgnoredAny>()?;
            } else {
                value.insert(key, map.next_value()?);
            }
        }
        Ok(Value::Object(value))
    }
}

/// Decodes only selected records from one transaction. Large sibling fields,
/// including provider history and other versions, are streamed through IgnoredAny.
pub(crate) fn read_selected(
    path: &Path,
    location: Location,
    paths: &[RecordPath],
) -> Result<Vec<Value>> {
    read_selected_without_fields(path, location, paths, &[])
}

pub(crate) fn read_selected_without_fields(
    path: &Path,
    location: Location,
    paths: &[RecordPath],
    omitted_fields: &[&str],
) -> Result<Vec<Value>> {
    let mut selection = Selection::default();
    for (index, path) in paths.iter().enumerate() {
        let mut cursor = &mut selection;
        for part in &path.0 {
            cursor = cursor.children.entry(part.clone()).or_default();
        }
        cursor.targets.push(index);
    }
    let mut file = File::open(path)?;
    file.seek(SeekFrom::Start(location.offset))?;
    let reader = BufReader::new(file.take(location.length));
    let mut values = vec![None; paths.len()];
    let mut decoder = serde_json::Deserializer::from_reader(reader);
    SelectedSeed {
        selection: &selection,
        values: &mut values,
        omitted_fields,
    }
    .deserialize(&mut decoder)?;
    decoder.end()?;
    values
        .into_iter()
        .map(|value| {
            value.ok_or_else(|| {
                StorageError::Invalid("Indexed record is missing from its transaction".into())
            })
        })
        .collect()
}

/// Visits complete transaction lines. A crash-truncated final line is uncommitted.
pub(crate) fn scan(
    path: &Path,
    mut visit: impl FnMut(JournalCommit, Location) -> Result<()>,
) -> Result<u64> {
    let mut reader = BufReader::new(File::open(path)?);
    let mut offset = 0_u64;
    let mut line = Vec::new();
    loop {
        line.clear();
        let count = reader.read_until(b'\n', &mut line)?;
        if count == 0 || line.last() != Some(&b'\n') {
            return Ok(offset);
        }
        let location = Location {
            offset,
            length: count as u64,
        };
        let commit = serde_json::from_slice::<JournalCommit>(&line).map_err(|error| {
            StorageError::CorruptJournal {
                path: path.to_path_buf(),
                offset,
                reason: error.to_string(),
            }
        })?;
        visit(commit, location)?;
        offset += count as u64;
    }
}

pub(crate) fn read_at(path: &Path, location: Location) -> Result<JournalCommit> {
    let mut file = File::open(path)?;
    file.seek(SeekFrom::Start(location.offset))?;
    let mut bytes = Vec::new();
    file.take(location.length).read_to_end(&mut bytes)?;
    Ok(serde_json::from_slice(&bytes)?)
}

pub(crate) fn append(path: &Path, length: u64, commit: &JournalCommit) -> Result<Location> {
    let mut bytes = serde_json::to_vec(commit)?;
    bytes.push(b'\n');
    let mut file = OpenOptions::new()
        .create(true)
        .read(true)
        .write(true)
        .truncate(false)
        .open(path)?;
    if file.metadata()?.len() != length {
        return Err(StorageError::Conflict(
            "Journal changed since its index was read; reload before appending".into(),
        ));
    }
    file.seek(SeekFrom::Start(length))?;
    if let Err(error) = file.write_all(&bytes).and_then(|_| file.sync_all()) {
        // A confirmed rollback permits retry; if truncation fails, reopening and
        // reading the journal is required before another append.
        let rollback = file.set_len(length).and_then(|_| file.sync_all());
        if let Err(rollback) = rollback {
            return Err(StorageError::Conflict(format!(
                "Journal write and rollback need recovery: {error}; {rollback}"
            )));
        }
        return Err(error.into());
    }
    Ok(Location {
        offset: length,
        length: bytes.len() as u64,
    })
}
