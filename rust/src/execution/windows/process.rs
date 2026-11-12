use std::{
    collections::BTreeMap,
    fs::OpenOptions,
    io,
    mem::{size_of, zeroed},
    os::windows::io::{AsRawHandle, FromRawHandle, OwnedHandle},
    path::{Path, PathBuf},
    process::Stdio,
    ptr::{null, null_mut},
};

use tokio::{
    io::{AsyncRead, AsyncReadExt, AsyncWriteExt},
    process::Command,
    sync::mpsc::Sender,
};
use tokio_util::sync::CancellationToken;
use windows_sys::Win32::{
    Foundation::{HANDLE, INVALID_HANDLE_VALUE},
    System::{
        IO::{CreateIoCompletionPort, GetQueuedCompletionStatus},
        JobObjects::{
            AssignProcessToJobObject, CreateJobObjectW, JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
            JOBOBJECT_ASSOCIATE_COMPLETION_PORT, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
            JobObjectAssociateCompletionPortInformation, JobObjectExtendedLimitInformation,
            SetInformationJobObject, TerminateJobObject,
        },
        SystemServices::JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO,
        Threading::{CREATE_NO_WINDOW, INFINITE},
    },
};

use super::{error, io_error, ledger, now_ms, runtime::RuntimeBundle};
use crate::execution::{
    EnvironmentValue, ExecutionError, ExecutionErrorCode, ExecutionEventKind, ExecutionReceipt,
    FrozenExecutionSpec, OutputStream, Result,
};

struct Job {
    handle: OwnedHandle,
    completion: OwnedHandle,
}

impl Job {
    fn new() -> io::Result<Self> {
        let raw = unsafe { CreateJobObjectW(null(), null()) };
        if raw.is_null() {
            return Err(io::Error::last_os_error());
        }
        let handle = unsafe { OwnedHandle::from_raw_handle(raw) };
        let port = unsafe { CreateIoCompletionPort(INVALID_HANDLE_VALUE, null_mut(), 0, 1) };
        if port.is_null() {
            return Err(io::Error::last_os_error());
        }
        let completion = unsafe { OwnedHandle::from_raw_handle(port) };
        let mut limits: JOBOBJECT_EXTENDED_LIMIT_INFORMATION = unsafe { zeroed() };
        limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        if unsafe {
            SetInformationJobObject(
                raw,
                JobObjectExtendedLimitInformation,
                (&limits as *const JOBOBJECT_EXTENDED_LIMIT_INFORMATION).cast(),
                size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32,
            )
        } == 0
        {
            return Err(io::Error::last_os_error());
        }
        let association = JOBOBJECT_ASSOCIATE_COMPLETION_PORT {
            CompletionKey: 1usize as *mut _,
            CompletionPort: port,
        };
        if unsafe {
            SetInformationJobObject(
                raw,
                JobObjectAssociateCompletionPortInformation,
                (&association as *const JOBOBJECT_ASSOCIATE_COMPLETION_PORT).cast(),
                size_of::<JOBOBJECT_ASSOCIATE_COMPLETION_PORT>() as u32,
            )
        } == 0
        {
            return Err(io::Error::last_os_error());
        }
        Ok(Self { handle, completion })
    }

    fn assign(&self, process: HANDLE) -> io::Result<()> {
        if unsafe { AssignProcessToJobObject(self.handle.as_raw_handle(), process) } == 0 {
            Err(io::Error::last_os_error())
        } else {
            Ok(())
        }
    }

    fn terminate(&self) -> io::Result<()> {
        if unsafe { TerminateJobObject(self.handle.as_raw_handle(), 1) } == 0 {
            Err(io::Error::last_os_error())
        } else {
            Ok(())
        }
    }

    fn wait_empty(completion: OwnedHandle) -> io::Result<()> {
        loop {
            let mut message = 0;
            let mut key = 0;
            let mut overlapped = null_mut();
            if unsafe {
                GetQueuedCompletionStatus(
                    completion.as_raw_handle(),
                    &mut message,
                    &mut key,
                    &mut overlapped,
                    INFINITE,
                )
            } == 0
            {
                return Err(io::Error::last_os_error());
            }
            if message == JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO && key == 1 {
                return Ok(());
            }
        }
    }
}

pub(super) struct CapturedOutput {
    pub stream: OutputStream,
    pub path: PathBuf,
    pub error: Option<ExecutionError>,
}

pub(super) struct ProcessResult {
    pub started: bool,
    pub cancelled: bool,
    pub exit_code: Option<i32>,
    pub outputs: Vec<CapturedOutput>,
    pub error: Option<ExecutionError>,
}

impl ProcessResult {
    fn not_started(failure: ExecutionError) -> Self {
        Self {
            started: false,
            cancelled: false,
            exit_code: None,
            outputs: Vec::new(),
            error: Some(failure),
        }
    }
}

pub(super) async fn run(
    bundle: &RuntimeBundle,
    specification: &FrozenExecutionSpec,
    directory: &Path,
    receipt: &mut ExecutionReceipt,
    cancellation: CancellationToken,
    events: Sender<ExecutionEventKind>,
) -> ProcessResult {
    let prepared = (|| -> Result<_> {
        super::runtime::check_cancelled(&cancellation)?;
        let job = Job::new().map_err(io_error)?;
        let waiting_port = job.completion.try_clone().map_err(io_error)?;
        let stdout_path = directory.join("stdout.txt");
        let stderr_path = directory.join("stderr.txt");
        let output = |path: &Path| {
            OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(path)
                .map_err(io_error)
        };
        let stdout = output(&stdout_path)?;
        let stderr = output(&stderr_path)?;
        let mut variables: BTreeMap<String, String> = bundle.system_variables.clone();
        for (name, value) in &specification.variables {
            let EnvironmentValue::Plain(value) = value else {
                return Err(error(
                    ExecutionErrorCode::Unsupported,
                    "This Python provider does not resolve secret handles.",
                ));
            };
            if let Some(previous) = variables
                .keys()
                .find(|key| key.eq_ignore_ascii_case(name))
                .cloned()
            {
                variables.remove(&previous);
            }
            variables.insert(name.clone(), value.clone());
        }
        let mut command = Command::new(bundle.directory.join("python.exe"));
        command
            .arg("-I")
            .arg("-u")
            .arg("-B")
            .arg("-X")
            .arg("utf8")
            .arg(bundle.directory.join("bootstrap.py"))
            .arg(directory)
            .current_dir(&specification.cwd_resource.value)
            .env_clear()
            .envs(variables)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .creation_flags(CREATE_NO_WINDOW)
            .kill_on_drop(true);
        let child = command
            .spawn()
            .map_err(|failure| error(ExecutionErrorCode::AdmissionFailed, failure.to_string()))?;
        Ok((
            job,
            waiting_port,
            child,
            stdout,
            stderr,
            stdout_path,
            stderr_path,
        ))
    })();
    let (job, waiting_port, mut child, stdout, stderr, stdout_path, stderr_path) = match prepared {
        Ok(prepared) => prepared,
        Err(failure) => return ProcessResult::not_started(failure),
    };
    let assignment = child
        .raw_handle()
        .ok_or_else(|| io::Error::other("The Python process has already ended."))
        .and_then(|handle| job.assign(handle));
    if let Err(failure) = assignment {
        let _ = child.kill().await;
        let _ = child.wait().await;
        return ProcessResult::not_started(error(
            ExecutionErrorCode::AdmissionFailed,
            format!("Python could not join its execution job: {failure}"),
        ));
    }
    let stdout_task = tokio::spawn(capture(
        child.stdout.take().expect("piped stdout"),
        stdout,
        stdout_path,
        OutputStream::Stdout,
        events.clone(),
    ));
    let stderr_task = tokio::spawn(capture(
        child.stderr.take().expect("piped stderr"),
        stderr,
        stderr_path,
        OutputStream::Stderr,
        events.clone(),
    ));
    let mut empty = tokio::task::spawn_blocking(move || Job::wait_empty(waiting_port));
    // Persist launch evidence before releasing the trusted bootstrap handshake.
    receipt.started_at_ms = Some(now_ms());
    let launch = ledger::append(directory, receipt)
        .and_then(|()| super::runtime::check_cancelled(&cancellation));
    let mut input = child.stdin.take().expect("piped stdin");
    let launch = match launch {
        Ok(()) => input.write_all(b"\x01").await.map_err(io_error),
        Err(failure) => Err(failure),
    };
    drop(input);
    let started = launch.is_ok();
    let mut failure = launch.err();
    let mut cancelled = false;
    if started {
        let _ = events.send(ExecutionEventKind::Started).await;
    } else {
        receipt.started_at_ms = None;
        if let Err(termination) = job.terminate() {
            failure = Some(error(
                ExecutionErrorCode::OutcomeUnknown,
                format!("The bootstrap could not be stopped: {termination}"),
            ));
        }
    }
    let ended = if started {
        tokio::select! {
            result = &mut empty => result,
            _ = cancellation.cancelled() => {
                cancelled = true;
                if let Err(termination) = job.terminate() {
                    failure = Some(error(ExecutionErrorCode::OutcomeUnknown, format!("The execution job could not be stopped: {termination}")));
                }
                empty.await
            }
        }
    } else {
        empty.await
    };
    if let Err(waiting) = ended
        .map_err(|failure| failure.to_string())
        .and_then(|result| result.map_err(|failure| failure.to_string()))
    {
        let _ = job.terminate();
        failure = Some(error(
            ExecutionErrorCode::OutcomeUnknown,
            format!("The execution job could not be observed to completion: {waiting}"),
        ));
    }
    let exit_code = match child.wait().await {
        Ok(status) => status.code(),
        Err(waiting) => {
            failure = Some(error(
                ExecutionErrorCode::OutcomeUnknown,
                waiting.to_string(),
            ));
            None
        }
    };
    let mut outputs = Vec::new();
    for captured in [stdout_task.await, stderr_task.await] {
        match captured {
            Ok(output) => {
                if failure.is_none() {
                    failure = output.error.clone();
                }
                if started {
                    outputs.push(output);
                }
            }
            Err(capture) => {
                failure = Some(error(
                    ExecutionErrorCode::OutputUnavailable,
                    capture.to_string(),
                ))
            }
        }
    }
    ProcessResult {
        started,
        cancelled,
        exit_code: started.then_some(exit_code).flatten(),
        outputs,
        error: failure,
    }
}

async fn capture(
    mut reader: impl AsyncRead + Unpin,
    file: std::fs::File,
    path: PathBuf,
    stream: OutputStream,
    events: Sender<ExecutionEventKind>,
) -> CapturedOutput {
    let mut file = tokio::fs::File::from_std(file);
    let mut buffer = [0_u8; 16 * 1024];
    let mut offset = 0_u64;
    let mut failure = None;
    loop {
        let count = match reader.read(&mut buffer).await {
            Ok(0) => break,
            Ok(count) => count,
            Err(read) => {
                failure = Some(error(
                    ExecutionErrorCode::OutputUnavailable,
                    read.to_string(),
                ));
                break;
            }
        };
        if failure.is_none() {
            match file.write_all(&buffer[..count]).await {
                Ok(()) => {}
                Err(write) => {
                    failure = Some(error(
                        ExecutionErrorCode::OutputUnavailable,
                        write.to_string(),
                    ))
                }
            }
        }
        let _ = events
            .send(ExecutionEventKind::Output {
                stream,
                offset,
                bytes: buffer[..count].to_vec(),
            })
            .await;
        offset += count as u64;
    }
    if let Err(sync) = file.sync_all().await {
        failure = Some(error(
            ExecutionErrorCode::OutputUnavailable,
            sync.to_string(),
        ));
    }
    CapturedOutput {
        stream,
        path,
        error: failure,
    }
}
