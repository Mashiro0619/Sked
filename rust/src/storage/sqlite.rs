//! SQLite stores signed integers; public byte offsets and sequences are unsigned.
use super::{Result, StorageError};
use rusqlite::Row;

pub(crate) fn integer<T: TryInto<i64>>(value: T) -> Result<i64> {
    value.try_into().map_err(|_| {
        StorageError::Invalid("Integer is outside SQLite's representable range".into())
    })
}

pub(crate) fn unsigned(row: &Row<'_>, index: usize) -> rusqlite::Result<u64> {
    let value = row.get::<_, i64>(index)?;
    u64::try_from(value).map_err(|_| rusqlite::Error::IntegralValueOutOfRange(index, value))
}

pub(crate) fn position(row: &Row<'_>, index: usize) -> rusqlite::Result<usize> {
    let value = row.get::<_, i64>(index)?;
    usize::try_from(value).map_err(|_| rusqlite::Error::IntegralValueOutOfRange(index, value))
}

pub(crate) fn optional_position(row: &Row<'_>, index: usize) -> rusqlite::Result<Option<usize>> {
    row.get::<_, Option<i64>>(index)?
        .map(|value| {
            usize::try_from(value)
                .map_err(|_| rusqlite::Error::IntegralValueOutOfRange(index, value))
        })
        .transpose()
}
