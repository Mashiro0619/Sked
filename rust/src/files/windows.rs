use std::{
    ffi::OsStr,
    fs::{File, OpenOptions},
    io,
    mem::{offset_of, size_of, zeroed},
    os::windows::{
        ffi::{OsStrExt, OsStringExt},
        fs::OpenOptionsExt,
        io::{AsRawHandle, FromRawHandle},
    },
    path::{Component, Path, PathBuf, Prefix},
    ptr::{null, null_mut},
};

use windows_sys::{
    Wdk::{
        Foundation::OBJECT_ATTRIBUTES,
        Storage::FileSystem::{
            FILE_CREATE, FILE_DISPOSITION_INFORMATION, FILE_NAMES_INFORMATION,
            FILE_NON_DIRECTORY_FILE, FILE_OPEN, FILE_OPEN_REPARSE_POINT, FILE_RENAME_INFORMATION,
            FILE_SYNCHRONOUS_IO_NONALERT, FileDispositionInformation, FileNamesInformation,
            FileRenameInformation, NtCreateFile, NtQueryDirectoryFile, NtSetInformationFile,
        },
    },
    Win32::{
        Foundation::{
            GENERIC_READ, GENERIC_WRITE, HANDLE, LocalFree, OBJ_CASE_INSENSITIVE,
            RtlNtStatusToDosError, STATUS_NO_MORE_FILES, UNICODE_STRING,
        },
        Security::{
            ACE_HEADER, ACL,
            Authorization::{GetSecurityInfo, SE_FILE_OBJECT, SetSecurityInfo},
            DACL_SECURITY_INFORMATION, GetAce, GetSecurityDescriptorControl,
            GetSecurityDescriptorDacl, IsValidAcl, IsValidSecurityDescriptor,
            PROTECTED_DACL_SECURITY_INFORMATION, PSECURITY_DESCRIPTOR, SE_DACL_PROTECTED,
            UNPROTECTED_DACL_SECURITY_INFORMATION,
        },
        Storage::FileSystem::{
            BY_HANDLE_FILE_INFORMATION, DELETE, FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_ENCRYPTED,
            FILE_ATTRIBUTE_NORMAL, FILE_ATTRIBUTE_REPARSE_POINT, FILE_CASE_SENSITIVE_INFO,
            FILE_FLAG_BACKUP_SEMANTICS, FILE_FLAG_OPEN_REPARSE_POINT, FILE_ID_INFO,
            FILE_LIST_DIRECTORY, FILE_READ_ATTRIBUTES, FILE_SHARE_DELETE, FILE_SHARE_READ,
            FILE_SHARE_WRITE, FILE_TRAVERSE, FILE_TYPE_DISK, FileCaseSensitiveInfo, FileIdInfo,
            GetFileInformationByHandle, GetFileInformationByHandleEx, GetFileType,
            GetFinalPathNameByHandleW, GetVolumeInformationByHandleW, READ_CONTROL, SYNCHRONIZE,
            WRITE_DAC,
        },
        System::{
            IO::IO_STATUS_BLOCK,
            SystemServices::{FILE_CS_FLAG_CASE_SENSITIVE_DIR, FILE_PERSISTENT_ACLS},
        },
    },
};

use super::{
    Cancellation, FileEntry, FileError, FileErrorCode, FileKind, FileResourceCapabilities,
    FileResourceKind, FileResourceRef, FileVersion, FileWriteGuarantee, Result, digest,
};

pub(super) fn available() -> bool {
    true
}

pub(super) fn resource_kinds() -> Vec<FileResourceKind> {
    vec![FileResourceKind::WindowsPath]
}

pub(super) fn capabilities(
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<FileResourceCapabilities> {
    cancellation.check()?;
    let file = open_metadata(&path(resource)?, false)?;
    let entry = entry(&file)?;
    let mut info: BY_HANDLE_FILE_INFORMATION = unsafe { zeroed() };
    if unsafe { GetFileInformationByHandle(file.as_raw_handle(), &mut info) } == 0 {
        return Err(io::Error::last_os_error().into());
    }
    let directory = entry.kind == FileKind::Directory;
    let ordinary = entry.kind == FileKind::File;
    let modify =
        ordinary && !entry.is_link && info.dwFileAttributes & FILE_ATTRIBUTE_ENCRYPTED == 0;
    cancellation.check()?;
    Ok(FileResourceCapabilities {
        read: ordinary,
        list: directory,
        create: directory,
        modify,
        write_guarantees: if directory || modify {
            vec![FileWriteGuarantee::HandleExclusive]
        } else {
            Vec::new()
        },
    })
}

pub(super) type SourceReader = File;

pub(super) fn open_source(
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<SourceReader> {
    cancellation.check()?;
    open_read(resource)
}

pub(super) fn source_entry(source: &SourceReader) -> Result<FileEntry> {
    super::snapshots::ordinary_entry(source)
}

pub(super) fn source_read(
    source: &mut SourceReader,
    bytes: &mut [u8],
    cancellation: &Cancellation,
) -> Result<usize> {
    cancellation.check()?;
    Ok(std::io::Read::read(source, bytes)?)
}

pub(super) fn close_source(_source: &mut SourceReader) -> Result<()> {
    Ok(())
}

pub(super) fn read_directory_cancellable(
    resource: &FileResourceRef,
    cancellation: &Cancellation,
) -> Result<DirectoryReader> {
    cancellation.check()?;
    read_directory(resource)
}

pub(super) fn path(resource: &FileResourceRef) -> Result<PathBuf> {
    if resource.kind != FileResourceKind::WindowsPath {
        return Err(FileError::new(
            FileErrorCode::Unsupported,
            "This provider requires a Windows filesystem path.",
        ));
    }
    if resource.value.contains('\0') {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "A filesystem path cannot contain a null character.",
        ));
    }
    let value = PathBuf::from(&resource.value);
    let allowed_prefix = matches!(value.components().next(), Some(Component::Prefix(prefix))
        if matches!(prefix.kind(), Prefix::Disk(_) | Prefix::VerbatimDisk(_) | Prefix::UNC(..) | Prefix::VerbatimUNC(..)));
    if !value.is_absolute()
        || !allowed_prefix
        || value.components().any(|part| match part {
            Component::Normal(name) => name.encode_wide().any(|c| c == b':' as u16),
            _ => false,
        })
    {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "Use an absolute drive or UNC file path; device namespaces and alternate streams are separate resource types.",
        ));
    }
    Ok(value)
}

pub(super) fn resource(path: &Path) -> Result<FileResourceRef> {
    let value = path.to_str().ok_or_else(|| {
        FileError::new(
            FileErrorCode::Unsupported,
            "The filename cannot be represented as Unicode.",
        )
    })?;
    Ok(FileResourceRef {
        kind: FileResourceKind::WindowsPath,
        value: value.into(),
    })
}

pub(super) fn open_read(resource: &FileResourceRef) -> Result<File> {
    // The short snapshot copy holds this handle until all bytes and metadata
    // are captured. Incompatible writers return sharing violation immediately.
    Ok(OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS)
        .open(path(resource)?)?)
}

pub(super) fn open_shared(resource: &FileResourceRef) -> Result<File> {
    Ok(OpenOptions::new()
        .read(true)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS)
        .open(path(resource)?)?)
}

pub(super) fn stat(resource: &FileResourceRef) -> Result<FileEntry> {
    entry(&open_metadata(&path(resource)?, true)?)
}

fn open_metadata(path: &Path, follow: bool) -> Result<File> {
    Ok(OpenOptions::new()
        .access_mode(FILE_READ_ATTRIBUTES | SYNCHRONIZE)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
        .custom_flags(
            FILE_FLAG_BACKUP_SEMANTICS
                | if follow {
                    0
                } else {
                    FILE_FLAG_OPEN_REPARSE_POINT
                },
        )
        .open(path)?)
}

pub(super) fn entry(file: &File) -> Result<FileEntry> {
    let handle = file.as_raw_handle();
    let mut info: BY_HANDLE_FILE_INFORMATION = unsafe { zeroed() };
    // FILE_TYPE_DISK excludes pipes and consoles; native file ID lookup also
    // excludes volume/device handles from ordinary-file operations.
    if unsafe { GetFileType(handle) } != FILE_TYPE_DISK {
        return Err(FileError::new(
            FileErrorCode::Unsupported,
            "The resource is not a filesystem file or directory.",
        ));
    }
    if unsafe { GetFileInformationByHandle(handle, &mut info) } == 0 {
        return Err(io::Error::last_os_error().into());
    }
    let mut id: FILE_ID_INFO = unsafe { zeroed() };
    let resource_id = if unsafe {
        GetFileInformationByHandleEx(
            handle,
            FileIdInfo,
            (&mut id as *mut FILE_ID_INFO).cast(),
            size_of::<FILE_ID_INFO>() as u32,
        )
    } != 0
        && id.FileId.Identifier.iter().any(|part| *part != 0)
    {
        format!(
            "windows:{:016x}:{}",
            id.VolumeSerialNumber,
            id.FileId
                .Identifier
                .iter()
                .map(|v| format!("{v:02x}"))
                .collect::<String>()
        )
    } else {
        let index = (u64::from(info.nFileIndexHigh) << 32) | u64::from(info.nFileIndexLow);
        if index == 0 {
            return Err(FileError::new(
                FileErrorCode::Unsupported,
                "This filesystem does not expose a stable file identity.",
            ));
        }
        format!("windows:{:08x}:{index:016x}", info.dwVolumeSerialNumber)
    };
    let modified = (u64::from(info.ftLastWriteTime.dwHighDateTime) << 32)
        | u64::from(info.ftLastWriteTime.dwLowDateTime);
    let created = (u64::from(info.ftCreationTime.dwHighDateTime) << 32)
        | u64::from(info.ftCreationTime.dwLowDateTime);
    let length = (u64::from(info.nFileSizeHigh) << 32) | u64::from(info.nFileSizeLow);
    let is_directory = info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != 0;
    let path = final_path(file)?;
    let resource = resource(&path)?;
    Ok(FileEntry {
        name: path
            .file_name()
            .and_then(OsStr::to_str)
            .unwrap_or(&resource.value)
            .into(),
        resource,
        kind: if is_directory {
            FileKind::Directory
        } else {
            FileKind::File
        },
        is_link: info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != 0,
        version: FileVersion {
            version: digest(
                format!(
                    "{resource_id}|{created}|{modified}|{length}|{}",
                    info.dwFileAttributes
                )
                .as_bytes(),
            ),
            resource_id,
            sha256: None,
            byte_length: (!is_directory).then_some(length),
            modified_at_ms: Some((modified / 10_000) as i64 - 11_644_473_600_000),
        },
    })
}

fn final_path(file: &File) -> Result<PathBuf> {
    let mut buffer = vec![0u16; 512];
    loop {
        let length = unsafe {
            GetFinalPathNameByHandleW(
                file.as_raw_handle(),
                buffer.as_mut_ptr(),
                buffer.len() as u32,
                0,
            )
        };
        if length == 0 {
            return Err(io::Error::last_os_error().into());
        }
        if (length as usize) < buffer.len() {
            buffer.truncate(length as usize);
            return Ok(PathBuf::from(std::ffi::OsString::from_wide(&buffer)));
        }
        buffer.resize(length as usize + 1, 0);
    }
}

pub(super) struct Parent {
    pub file: File,
    pub entry: FileEntry,
    pub name: String,
    requested_parent: PathBuf,
}

pub(super) fn parent(target: &FileResourceRef) -> Result<Parent> {
    let target_path = path(target)?;
    let name = target_path
        .file_name()
        .and_then(OsStr::to_str)
        .ok_or_else(|| {
            FileError::new(
                FileErrorCode::InvalidArgument,
                "A destination must name a file.",
            )
        })?
        .to_owned();
    if target.value.rsplit(['/', '\\']).next() != Some(name.as_str()) {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "A destination must end with one normal file name.",
        ));
    }
    name_units(&name)?;
    let verbatim = matches!(target_path.components().next(), Some(Component::Prefix(prefix))
        if matches!(prefix.kind(), Prefix::VerbatimDisk(_) | Prefix::VerbatimUNC(..)));
    if !verbatim && name.ends_with(['.', ' ']) {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "Use a verbatim path for a filename ending with a dot or space.",
        ));
    }
    if !verbatim && is_dos_device_name(&name) {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "Use a verbatim path for a filename reserved by the Windows device namespace.",
        ));
    }
    let requested_parent = target_path
        .parent()
        .ok_or_else(|| {
            FileError::new(
                FileErrorCode::InvalidArgument,
                "The destination has no parent directory.",
            )
        })?
        .to_path_buf();
    // Only traverse/read-attributes are requested. Relative rename opens may
    // request directory write access without conflicting with this handle.
    let file = OpenOptions::new()
        .access_mode(FILE_TRAVERSE | FILE_READ_ATTRIBUTES | SYNCHRONIZE)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS)
        .open(&requested_parent)?;
    let entry = entry(&file)?;
    if entry.kind != FileKind::Directory {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "The destination parent is not a directory.",
        ));
    }
    let parent = Parent {
        file,
        entry,
        name,
        requested_parent,
    };
    parent.verify_identity()?;
    Ok(parent)
}

impl Parent {
    pub fn child_resource(&self, name: &str) -> Result<FileResourceRef> {
        name_units(name)?;
        self.verify_identity()?;
        resource(&final_path(&self.file)?.join(name))
    }

    pub fn verify_identity(&self) -> Result<()> {
        verify_directory(&self.file, &self.entry, &self.requested_parent)
    }

    pub fn open_original(&self) -> Result<File> {
        self.open_child_owned(&self.name)
    }

    pub fn open_child_owned(&self, name: &str) -> Result<File> {
        self.open_file(
            name,
            GENERIC_READ | READ_CONTROL | DELETE,
            FILE_SHARE_READ,
            FILE_OPEN,
        )
    }

    pub fn open_child_locked(&self, name: &str) -> Result<File> {
        // Recovery after restart has no retained DELETE handle to pin the
        // target name. This reader itself denies both write and delete sharing.
        self.open_file(name, GENERIC_READ, FILE_SHARE_READ, FILE_OPEN)
    }

    pub fn create_staged(&self, name: &str) -> Result<File> {
        let access = GENERIC_READ
            | GENERIC_WRITE
            | READ_CONTROL
            | DELETE
            | if persistent_acls(&self.file)? {
                WRITE_DAC
            } else {
                0
            };
        self.open_file(
            name,
            access,
            // A reader opened under the inherited ACL would retain access
            // after the original DACL is restored. Keep creation exclusive
            // until content and permissions are sealed and the writer closes.
            0,
            FILE_CREATE,
        )
    }

    fn open_file(&self, name: &str, access: u32, share: u32, disposition: u32) -> Result<File> {
        self.verify_identity()?;
        let file = open_relative(
            &self.file,
            name,
            access | SYNCHRONIZE,
            share,
            disposition,
            FILE_NON_DIRECTORY_FILE,
        )?;
        let found = entry(&file)?;
        if found.kind != FileKind::File || found.is_link {
            return Err(FileError::new(
                FileErrorCode::Conflict,
                "The destination is no longer the expected ordinary file.",
            ));
        }
        Ok(file)
    }

    /// Both objects are selected by handles. FALSE forbids replacing any
    /// external file created under the destination name during publication.
    pub fn rename_owned(&self, file: &File, name: &str) -> Result<()> {
        self.verify_identity()?;
        let units = name_units(name)?;
        let source = entry(file)?;
        let parent_path = final_path(&self.file)?;
        if source.kind != FileKind::File
            || source.is_link
            || path(&source.resource)?.parent() != Some(parent_path.as_path())
        {
            return Err(FileError::new(
                FileErrorCode::IdentityMismatch,
                "The owned file is no longer in the captured parent directory.",
            ));
        }
        let byte_size = size_of::<FILE_RENAME_INFORMATION>() + units.len() * 2;
        let mut buffer = vec![0usize; byte_size.div_ceil(size_of::<usize>())];
        let info = buffer.as_mut_ptr().cast::<FILE_RENAME_INFORMATION>();
        unsafe {
            (*info).Anonymous.ReplaceIfExists = false;
            (*info).RootDirectory = self.file.as_raw_handle();
            (*info).FileNameLength = (units.len() * 2) as u32;
            std::ptr::copy_nonoverlapping(
                units.as_ptr(),
                std::ptr::addr_of_mut!((*info).FileName).cast::<u16>(),
                units.len(),
            );
        }
        let mut status = IO_STATUS_BLOCK::default();
        nt_result(unsafe {
            NtSetInformationFile(
                file.as_raw_handle(),
                &mut status,
                info.cast(),
                byte_size as u32,
                FileRenameInformation,
            )
        })
    }
}

pub(super) fn validate_replacement(original: &File) -> Result<()> {
    let mut info: BY_HANDLE_FILE_INFORMATION = unsafe { zeroed() };
    if unsafe { GetFileInformationByHandle(original.as_raw_handle(), &mut info) } == 0 {
        return Err(io::Error::last_os_error().into());
    }
    if info.dwFileAttributes & FILE_ATTRIBUTE_ENCRYPTED != 0 {
        return Err(FileError::new(
            FileErrorCode::Unsupported,
            "EFS replacement is not supported because its encryption metadata cannot be preserved.",
        ));
    }
    Ok(())
}

/// Apply the original DACL before new content reaches the staging file. Both
/// objects are already selected by handles; no security operation uses a path.
pub(super) fn preserve_access(original: &File, staged: &File) -> Result<()> {
    distinct_access_objects(original, staged)?;
    if !common_acl_capability(original, staged)? {
        return Ok(());
    }
    let original_access = AccessDescriptor::read(original)?;
    let protection = if original_access.material.protected {
        PROTECTED_DACL_SECURITY_INFORMATION
    } else {
        UNPROTECTED_DACL_SECURITY_INFORMATION
    };
    let result = unsafe {
        SetSecurityInfo(
            staged.as_raw_handle(),
            SE_FILE_OBJECT,
            DACL_SECURITY_INFORMATION | protection,
            null_mut(),
            null_mut(),
            original_access.dacl,
            null(),
        )
    };
    if result != 0 {
        return Err(access_error(
            "The original DACL could not be applied to staging",
            result,
        ));
    }
    let staged_access = AccessDescriptor::read(staged)?;
    let current_original_access = AccessDescriptor::read(original)?;
    if original_access.material != current_original_access.material
        || original_access.material != staged_access.material
    {
        return Err(access_changed());
    }
    Ok(())
}

/// Recheck after the writable staging handle closes and just before changing
/// the target name. Inheritance must not have added or changed any ACE.
pub(super) fn verify_access(original: &File, staged: &File) -> Result<()> {
    distinct_access_objects(original, staged)?;
    if !common_acl_capability(original, staged)? {
        return Ok(());
    }
    let original_access = AccessDescriptor::read(original)?;
    let staged_access = AccessDescriptor::read(staged)?;
    let current_original_access = AccessDescriptor::read(original)?;
    if original_access.material != current_original_access.material
        || original_access.material != staged_access.material
    {
        return Err(access_changed());
    }
    Ok(())
}

fn persistent_acls(file: &File) -> Result<bool> {
    let mut flags = 0u32;
    if unsafe {
        GetVolumeInformationByHandleW(
            file.as_raw_handle(),
            null_mut(),
            0,
            null_mut(),
            null_mut(),
            &mut flags,
            null_mut(),
            0,
        )
    } == 0
    {
        let mut error = FileError::io(io::Error::last_os_error());
        error.message = format!(
            "The filesystem's persistent ACL capability could not be read: {}",
            error.message
        );
        return Err(error);
    }
    Ok(flags & FILE_PERSISTENT_ACLS != 0)
}

fn common_acl_capability(original: &File, staged: &File) -> Result<bool> {
    let original = persistent_acls(original)?;
    let staged = persistent_acls(staged)?;
    if original != staged {
        return Err(FileError::new(
            FileErrorCode::IdentityMismatch,
            "The original and staging files have different filesystem ACL capabilities.",
        ));
    }
    Ok(original)
}

fn distinct_access_objects(original: &File, staged: &File) -> Result<()> {
    let original = entry(original)?;
    let staged = entry(staged)?;
    if original.kind != FileKind::File
        || original.is_link
        || staged.kind != FileKind::File
        || staged.is_link
        || original.version.resource_id == staged.version.resource_id
    {
        return Err(FileError::new(
            FileErrorCode::IdentityMismatch,
            "Access preservation requires distinct ordinary original and staging files.",
        ));
    }
    Ok(())
}

struct OwnedSecurityDescriptor(PSECURITY_DESCRIPTOR);

impl Drop for OwnedSecurityDescriptor {
    fn drop(&mut self) {
        // GetSecurityInfo allocates this complete descriptor with LocalAlloc.
        unsafe {
            LocalFree(self.0);
        }
    }
}

#[derive(PartialEq, Eq)]
struct AccessMaterial {
    present: bool,
    protected: bool,
    revision: Option<u8>,
    aces: Option<Vec<Vec<u8>>>,
}

struct AccessDescriptor {
    _owned: OwnedSecurityDescriptor,
    dacl: *mut ACL,
    material: AccessMaterial,
}

impl AccessDescriptor {
    fn read(file: &File) -> Result<Self> {
        let mut raw: PSECURITY_DESCRIPTOR = null_mut();
        let result = unsafe {
            GetSecurityInfo(
                file.as_raw_handle(),
                SE_FILE_OBJECT,
                DACL_SECURITY_INFORMATION,
                null_mut(),
                null_mut(),
                null_mut(),
                null_mut(),
                &mut raw,
            )
        };
        if result != 0 {
            return Err(access_error(
                "The file access descriptor could not be read",
                result,
            ));
        }
        if raw.is_null() {
            return Err(invalid_access_descriptor());
        }
        let owned = OwnedSecurityDescriptor(raw);
        if unsafe { IsValidSecurityDescriptor(raw) } == 0 {
            return Err(invalid_access_descriptor());
        }
        let mut control = 0u16;
        let mut descriptor_revision = 0u32;
        if unsafe { GetSecurityDescriptorControl(raw, &mut control, &mut descriptor_revision) } == 0
        {
            return Err(io::Error::last_os_error().into());
        }
        let mut present = 0;
        let mut defaulted = 0;
        let mut dacl: *mut ACL = null_mut();
        if unsafe { GetSecurityDescriptorDacl(raw, &mut present, &mut dacl, &mut defaulted) } == 0 {
            return Err(io::Error::last_os_error().into());
        }
        let (revision, aces) = if present != 0 && !dacl.is_null() {
            if unsafe { IsValidAcl(dacl) } == 0 {
                return Err(invalid_access_descriptor());
            }
            let acl = unsafe { &*dacl };
            let length = usize::from(acl.AclSize);
            if length < size_of::<ACL>() {
                return Err(invalid_access_descriptor());
            }
            let mut aces = Vec::with_capacity(usize::from(acl.AceCount));
            for index in 0..u32::from(acl.AceCount) {
                let mut ace = null_mut();
                if unsafe { GetAce(dacl, index, &mut ace) } == 0 {
                    return Err(io::Error::last_os_error().into());
                }
                let offset = (ace as usize)
                    .checked_sub(dacl as usize)
                    .ok_or_else(invalid_access_descriptor)?;
                if offset < size_of::<ACL>()
                    || offset > length.saturating_sub(size_of::<ACE_HEADER>())
                {
                    return Err(invalid_access_descriptor());
                }
                let header = unsafe { ace.cast::<ACE_HEADER>().read_unaligned() };
                let ace_length = usize::from(header.AceSize);
                if ace_length < size_of::<ACE_HEADER>() || ace_length > length - offset {
                    return Err(invalid_access_descriptor());
                }
                aces.push(
                    unsafe { std::slice::from_raw_parts(ace.cast::<u8>(), ace_length) }.to_vec(),
                );
            }
            // Compare the actual ACE sequence, including masks, SIDs and
            // inheritance flags, without unused ACL allocation padding.
            (Some(acl.AclRevision), Some(aces))
        } else {
            dacl = null_mut();
            (None, None)
        };
        Ok(Self {
            _owned: owned,
            dacl,
            material: AccessMaterial {
                present: present != 0,
                protected: control & SE_DACL_PROTECTED != 0,
                revision,
                aces,
            },
        })
    }
}

fn access_error(context: &str, code: u32) -> FileError {
    let mut error = FileError::io(io::Error::from_raw_os_error(code as i32));
    if matches!(code, 1 | 50) {
        error.code = FileErrorCode::Unsupported;
    }
    error.message = format!("{context}: {}", error.message);
    error
}

fn access_changed() -> FileError {
    FileError::new(
        FileErrorCode::Conflict,
        "The original DACL or its inheritance protection could not be preserved exactly.",
    )
}

fn invalid_access_descriptor() -> FileError {
    FileError::new(
        FileErrorCode::StorageFailure,
        "The filesystem returned an invalid access descriptor.",
    )
}

/// Delete only the object for which this operation still owns a native handle.
pub(super) fn delete_owned(file: &File) -> Result<()> {
    let info = FILE_DISPOSITION_INFORMATION { DeleteFile: true };
    let mut status = IO_STATUS_BLOCK::default();
    nt_result(unsafe {
        NtSetInformationFile(
            file.as_raw_handle(),
            &mut status,
            (&info as *const FILE_DISPOSITION_INFORMATION).cast(),
            size_of::<FILE_DISPOSITION_INFORMATION>() as u32,
            FileDispositionInformation,
        )
    })
}

pub(super) struct DirectoryReader {
    pub directory: FileEntry,
    file: File,
    requested: PathBuf,
    buffer: Vec<u64>,
    restart: bool,
    finished: bool,
}

pub(super) fn read_directory(resource: &FileResourceRef) -> Result<DirectoryReader> {
    let requested = path(resource)?;
    let file = OpenOptions::new()
        .access_mode(FILE_LIST_DIRECTORY | FILE_TRAVERSE | FILE_READ_ATTRIBUTES | SYNCHRONIZE)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE)
        .custom_flags(FILE_FLAG_BACKUP_SEMANTICS)
        .open(&requested)?;
    let directory = entry(&file)?;
    if directory.kind != FileKind::Directory {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "The requested resource is not a directory.",
        ));
    }
    let reader = DirectoryReader {
        directory,
        file,
        requested,
        // One native filename is bounded by UNICODE_STRING, independently of
        // how many entries the directory contains.
        buffer: vec![0; (size_of::<FILE_NAMES_INFORMATION>() + u16::MAX as usize).div_ceil(8)],
        restart: true,
        finished: false,
    };
    reader.verify_identity()?;
    Ok(reader)
}

impl DirectoryReader {
    pub fn verify_identity(&self) -> Result<()> {
        verify_directory(&self.file, &self.directory, &self.requested)
    }

    fn next_name(&mut self) -> Result<Option<String>> {
        if let Err(error) = self.verify_identity() {
            self.finished = true;
            return Err(error);
        }
        let mut status = IO_STATUS_BLOCK::default();
        let result = unsafe {
            NtQueryDirectoryFile(
                self.file.as_raw_handle(),
                null_mut(),
                None,
                null(),
                &mut status,
                self.buffer.as_mut_ptr().cast(),
                (self.buffer.len() * size_of::<u64>()) as u32,
                FileNamesInformation,
                true,
                null(),
                self.restart,
            )
        };
        self.restart = false;
        if result == STATUS_NO_MORE_FILES {
            return Ok(None);
        }
        if let Err(error) = nt_result(result) {
            self.finished = true;
            return Err(error);
        }
        let name_offset = offset_of!(FILE_NAMES_INFORMATION, FileName);
        let bytes = status.Information;
        if bytes < name_offset || bytes > self.buffer.len() * size_of::<u64>() {
            self.finished = true;
            return Err(invalid_directory_record());
        }
        let info = self.buffer.as_ptr().cast::<FILE_NAMES_INFORMATION>();
        let name_length = unsafe { (*info).FileNameLength } as usize;
        if name_length % 2 != 0
            || name_length == 0
            || name_length > bytes - name_offset
            || unsafe { (*info).NextEntryOffset } != 0
        {
            self.finished = true;
            return Err(invalid_directory_record());
        }
        let units = unsafe {
            std::slice::from_raw_parts(
                std::ptr::addr_of!((*info).FileName).cast::<u16>(),
                name_length / 2,
            )
        };
        String::from_utf16(units).map(Some).map_err(|_| {
            FileError::new(
                FileErrorCode::Unsupported,
                "A directory entry cannot be represented as Unicode.",
            )
        })
    }
}

impl Iterator for DirectoryReader {
    type Item = Result<FileEntry>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.finished {
            return None;
        }
        loop {
            let name = match self.next_name() {
                Ok(Some(name)) => name,
                Ok(None) => {
                    self.finished = true;
                    return None;
                }
                Err(error) => {
                    // A non-Unicode name is one entry issue; enumeration has
                    // advanced and can continue. Native/identity failures set
                    // finished inside next_name before returning their error.
                    return Some(Err(error));
                }
            };
            if name == "." || name == ".." {
                continue;
            }
            return Some(
                open_relative(
                    &self.file,
                    &name,
                    FILE_READ_ATTRIBUTES | SYNCHRONIZE,
                    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                    FILE_OPEN,
                    0,
                )
                .and_then(|file| entry(&file)),
            );
        }
    }
}

fn open_relative(
    parent: &File,
    name: &str,
    access: u32,
    share: u32,
    disposition: u32,
    options: u32,
) -> Result<File> {
    let mut units = name_units(name)?;
    let string = UNICODE_STRING {
        Length: (units.len() * 2) as u16,
        MaximumLength: (units.len() * 2) as u16,
        Buffer: units.as_mut_ptr(),
    };
    let attributes = OBJECT_ATTRIBUTES {
        Length: size_of::<OBJECT_ATTRIBUTES>() as u32,
        RootDirectory: parent.as_raw_handle(),
        ObjectName: &string,
        Attributes: directory_lookup_flags(parent)?,
        SecurityDescriptor: null(),
        SecurityQualityOfService: null(),
    };
    let mut status = IO_STATUS_BLOCK::default();
    let mut handle: HANDLE = null_mut();
    let result = unsafe {
        NtCreateFile(
            &mut handle,
            access,
            &attributes,
            &mut status,
            null(),
            FILE_ATTRIBUTE_NORMAL,
            share,
            disposition,
            options | FILE_OPEN_REPARSE_POINT | FILE_SYNCHRONOUS_IO_NONALERT,
            null(),
            0,
        )
    };
    nt_result(result)?;
    Ok(unsafe { File::from_raw_handle(handle) })
}

fn directory_lookup_flags(parent: &File) -> Result<u32> {
    let mut info = FILE_CASE_SENSITIVE_INFO::default();
    if unsafe {
        GetFileInformationByHandleEx(
            parent.as_raw_handle(),
            FileCaseSensitiveInfo,
            (&mut info as *mut FILE_CASE_SENSITIVE_INFO).cast(),
            size_of::<FILE_CASE_SENSITIVE_INFO>() as u32,
        )
    } != 0
    {
        return Ok(if info.Flags & FILE_CS_FLAG_CASE_SENSITIVE_DIR != 0 {
            0
        } else {
            OBJ_CASE_INSENSITIVE
        });
    }
    let error = io::Error::last_os_error();
    if matches!(error.raw_os_error(), Some(1 | 50 | 87 | 124)) {
        // Filesystems without this extension use ordinary Windows lookup.
        Ok(OBJ_CASE_INSENSITIVE)
    } else {
        Err(error.into())
    }
}

fn verify_directory(file: &File, expected: &FileEntry, requested: &Path) -> Result<()> {
    let current = entry(file)?;
    if current.kind != FileKind::Directory
        || current.version.resource_id != expected.version.resource_id
        || current.resource != expected.resource
    {
        return Err(directory_changed());
    }
    let resolved = entry(&open_metadata(requested, true)?)?;
    if resolved.kind != FileKind::Directory
        || resolved.version.resource_id != expected.version.resource_id
        || resolved.resource != expected.resource
    {
        return Err(directory_changed());
    }
    Ok(())
}

fn directory_changed() -> FileError {
    FileError::new(
        FileErrorCode::IdentityMismatch,
        "The directory identity or resolved path changed after it was captured.",
    )
}

fn invalid_directory_record() -> FileError {
    FileError::new(
        FileErrorCode::StorageFailure,
        "The filesystem returned an invalid directory record.",
    )
}

fn is_dos_device_name(name: &str) -> bool {
    let stem = name
        .split('.')
        .next()
        .unwrap_or(name)
        .trim_end_matches(' ')
        .to_ascii_uppercase();
    matches!(
        stem.as_str(),
        "CON" | "PRN" | "AUX" | "NUL" | "CONIN$" | "CONOUT$"
    ) || matches!(
        stem.strip_prefix("COM")
            .or_else(|| stem.strip_prefix("LPT")),
        Some("1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "¹" | "²" | "³")
    )
}

fn name_units(name: &str) -> Result<Vec<u16>> {
    if name.is_empty() || name == "." || name == ".." || name.contains(['\0', '/', '\\', ':']) {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "A relative file name must contain one normal component.",
        ));
    }
    let units: Vec<_> = name.encode_utf16().collect();
    if units.len() * 2 > u16::MAX as usize {
        return Err(FileError::new(
            FileErrorCode::InvalidArgument,
            "The filename exceeds the native Unicode-string length.",
        ));
    }
    Ok(units)
}

fn nt_result(status: i32) -> Result<()> {
    if status >= 0 {
        Ok(())
    } else {
        Err(io::Error::from_raw_os_error(unsafe { RtlNtStatusToDosError(status) } as i32).into())
    }
}
