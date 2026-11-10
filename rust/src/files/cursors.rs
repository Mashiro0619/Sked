use super::{
    BUFFER_SIZE, Cancellation, FileDirectoryPage, FileEntry, FileError, FileErrorCode, FileIssue,
    FileKind, FileResourceRef, FileSearchHit, FileSearchPage, FileSearchRequest, Result,
    collect_cleanup, native, with_cleanup_error,
};

pub(super) enum Cursor {
    Directory(DirectoryCursor),
    Search(SearchCursor),
    #[cfg(target_os = "android")]
    PendingClose(super::android_jni::PendingCloses),
}

impl Cursor {
    pub fn close(&mut self) -> Result<()> {
        match self {
            Self::Directory(cursor) => close_directory(&mut cursor.reader),
            Self::Search(cursor) => cursor.close(),
            #[cfg(target_os = "android")]
            Self::PendingClose(pending) => pending.close(),
        }
    }
}

fn close_directory(reader: &mut native::DirectoryReader) -> Result<()> {
    #[cfg(target_os = "android")]
    {
        reader.close()
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = reader;
        Ok(())
    }
}

pub(super) struct DirectoryCursor {
    pub request: FileResourceRef,
    reader: native::DirectoryReader,
}

impl DirectoryCursor {
    pub fn open(request: FileResourceRef, cancellation: &Cancellation) -> Result<Self> {
        let reader = native::read_directory_cancellable(&request, cancellation)?;
        Ok(Self { request, reader })
    }

    pub fn page(
        &mut self,
        count: usize,
        cancellation: &Cancellation,
    ) -> Result<(FileDirectoryPage, bool)> {
        cancellation.check()?;
        self.reader.verify_identity()?;
        let mut page = FileDirectoryPage {
            directory: self.reader.directory.clone(),
            entries: Vec::new(),
            issues: Vec::new(),
            next_cursor: None,
        };
        while page.entries.len() + page.issues.len() < count {
            cancellation.check()?;
            match self.reader.next() {
                None => return Ok((page, true)),
                Some(Ok(entry)) => page.entries.push(entry),
                Some(Err(error)) => page.issues.push(FileIssue {
                    resource: self.request.clone(),
                    error,
                }),
            }
        }
        self.reader.verify_identity()?;
        Ok((page, false))
    }
}

struct Query {
    text: String,
    bytes: Vec<u8>,
    prefix: Vec<usize>,
    newlines: u64,
}

impl Query {
    fn new(text: &str) -> Result<Self> {
        if text.is_empty() || text.contains('\0') {
            return Err(FileError::new(
                FileErrorCode::InvalidArgument,
                "A file search requires a nonempty literal query.",
            ));
        }
        let bytes = text.as_bytes().to_vec();
        let mut prefix = vec![0; bytes.len()];
        let mut matched = 0;
        for index in 1..bytes.len() {
            while matched > 0 && bytes[index] != bytes[matched] {
                matched = prefix[matched - 1];
            }
            if bytes[index] == bytes[matched] {
                matched += 1;
            }
            prefix[index] = matched;
        }
        let newlines = bytes.iter().filter(|&&value| value == b'\n').count() as u64;
        Ok(Self {
            text: text.to_owned(),
            bytes,
            prefix,
            newlines,
        })
    }
}

struct TextReader {
    file: native::SourceReader,
    entry: FileEntry,
    buffer: Vec<u8>,
    position: usize,
    filled: usize,
    offset: u64,
    line: u64,
    matched: usize,
}

impl TextReader {
    fn open(entry: FileEntry, cancellation: &Cancellation) -> Result<Self> {
        let file = native::open_source(&entry.resource, cancellation)?;
        Ok(Self {
            file,
            entry,
            buffer: vec![0; BUFFER_SIZE],
            position: 0,
            filled: 0,
            offset: 0,
            line: 1,
            matched: 0,
        })
    }

    fn close(&mut self) -> Result<()> {
        native::close_source(&mut self.file)
    }

    fn next(
        &mut self,
        query: &Query,
        cancellation: &Cancellation,
    ) -> Result<Option<FileSearchHit>> {
        cancellation.check()?;
        if native::source_entry(&self.file)?.version != self.entry.version {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The file changed during text search.",
            ));
        }
        loop {
            if self.position == self.filled {
                cancellation.check()?;
                self.filled = native::source_read(&mut self.file, &mut self.buffer, cancellation)?;
                self.position = 0;
                if self.filled == 0 {
                    if native::source_entry(&self.file)?.version != self.entry.version {
                        return Err(FileError::new(
                            FileErrorCode::Conflict,
                            "The file changed during text search.",
                        ));
                    }
                    return Ok(None);
                }
            }
            let value = self.buffer[self.position];
            self.position += 1;
            self.offset = self.offset.checked_add(1).ok_or_else(|| {
                FileError::new(
                    FileErrorCode::StorageFailure,
                    "The file offset exceeds the filesystem range.",
                )
            })?;
            if value == b'\n' {
                self.line = self.line.saturating_add(1);
            }
            while self.matched > 0 && value != query.bytes[self.matched] {
                self.matched = query.prefix[self.matched - 1];
            }
            if value == query.bytes[self.matched] {
                self.matched += 1;
            }
            if self.matched == query.bytes.len() {
                self.matched = query.prefix[self.matched - 1];
                return Ok(Some(FileSearchHit {
                    entry: self.entry.clone(),
                    byte_offset: Some(self.offset - query.bytes.len() as u64),
                    line: Some(self.line.saturating_sub(query.newlines)),
                    matched_text: query.text.clone(),
                }));
            }
        }
    }
}

pub(super) struct SearchCursor {
    pub request: FileSearchRequest,
    query: Query,
    directories: Vec<native::DirectoryReader>,
    text: Option<TextReader>,
}

impl SearchCursor {
    pub fn open(request: FileSearchRequest, cancellation: &Cancellation) -> Result<Self> {
        let query = Query::new(&request.query)?;
        let reader = native::read_directory_cancellable(&request.root, cancellation)?;
        Ok(Self {
            request,
            query,
            directories: vec![reader],
            text: None,
        })
    }

    fn close(&mut self) -> Result<()> {
        let mut result = Ok(());
        if let Some(text) = &mut self.text {
            match text.close() {
                Ok(()) => self.text = None,
                Err(error) => collect_cleanup(&mut result, Err(error)),
            }
        }
        self.directories
            .retain_mut(|directory| match close_directory(directory) {
                Ok(()) => false,
                Err(error) => {
                    collect_cleanup(&mut result, Err(error));
                    true
                }
            });
        result
    }

    pub fn page(
        &mut self,
        count: usize,
        cancellation: &Cancellation,
    ) -> Result<(FileSearchPage, bool)> {
        cancellation.check()?;
        let mut page = FileSearchPage {
            hits: Vec::new(),
            issues: Vec::new(),
            next_cursor: None,
        };
        while page.hits.len() + page.issues.len() < count {
            cancellation.check()?;
            if let Some(text) = &mut self.text {
                match text.next(&self.query, cancellation) {
                    Ok(Some(hit)) => {
                        page.hits.push(hit);
                        continue;
                    }
                    Ok(None) => {
                        text.close()?;
                        self.text = None;
                    }
                    Err(error) if error.code == FileErrorCode::Cancelled => return Err(error),
                    Err(error) => {
                        if let Err(cleanup) = text.close() {
                            return Err(with_cleanup_error(error, cleanup));
                        }
                        page.issues.push(FileIssue {
                            resource: text.entry.resource.clone(),
                            error,
                        });
                        self.text = None;
                        continue;
                    }
                }
            }
            let Some(directory) = self.directories.last_mut() else {
                return Ok((page, true));
            };
            directory.verify_identity()?;
            let entry = match directory.next() {
                None => {
                    close_directory(directory)?;
                    self.directories.pop();
                    continue;
                }
                Some(Err(error)) => {
                    page.issues.push(FileIssue {
                        resource: directory.directory.resource.clone(),
                        error,
                    });
                    continue;
                }
                Some(Ok(entry)) => entry,
            };
            let is_hit = !self.request.text && entry.name.contains(&self.query.text);
            if is_hit {
                page.hits.push(FileSearchHit {
                    entry: entry.clone(),
                    byte_offset: None,
                    line: None,
                    matched_text: entry.name.clone(),
                });
            }
            if entry.kind == FileKind::Directory && self.request.recursive {
                if entry.is_link {
                    page.issues.push(FileIssue {
                        resource: entry.resource,
                        error: FileError::new(
                            FileErrorCode::Unsupported,
                            "Recursive search does not follow a directory link.",
                        ),
                    });
                } else if self
                    .directories
                    .iter()
                    .any(|parent| parent.directory.version.resource_id == entry.version.resource_id)
                {
                    page.issues.push(FileIssue {
                        resource: entry.resource,
                        error: FileError::new(
                            FileErrorCode::Conflict,
                            "The directory identity forms a traversal cycle.",
                        ),
                    });
                } else {
                    match native::read_directory_cancellable(&entry.resource, cancellation) {
                        Ok(reader)
                            if reader.directory.version.resource_id
                                == entry.version.resource_id =>
                        {
                            self.directories.push(reader)
                        }
                        Ok(mut reader) => {
                            let error = FileError::new(
                                FileErrorCode::Conflict,
                                "The directory changed before traversal.",
                            );
                            if let Err(cleanup) = close_directory(&mut reader) {
                                self.directories.push(reader);
                                return Err(with_cleanup_error(error, cleanup));
                            }
                            page.issues.push(FileIssue {
                                resource: entry.resource,
                                error,
                            });
                        }
                        Err(error) => page.issues.push(FileIssue {
                            resource: entry.resource,
                            error,
                        }),
                    }
                }
            } else if self.request.text && entry.kind == FileKind::File && !entry.is_link {
                match TextReader::open(entry.clone(), cancellation) {
                    Ok(text) => self.text = Some(text),
                    Err(error) => page.issues.push(FileIssue {
                        resource: entry.resource,
                        error,
                    }),
                }
            }
        }
        Ok((page, false))
    }
}
