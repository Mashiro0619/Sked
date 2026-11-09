use std::{path::PathBuf, sync::mpsc, thread};

use tokio::sync::oneshot;

use super::{AgentStorage, Result, StorageError};

type Work = Box<dyn FnOnce(&mut AgentStorage) + Send + 'static>;
enum Command {
    Work(Work),
    Stop,
}

/// The worker owns both SQLite connections and all blocking filesystem I/O.
pub struct StorageWorker {
    handle: StorageHandle,
    thread: Option<thread::JoinHandle<()>>,
}

#[derive(Clone)]
pub struct StorageHandle {
    sender: mpsc::Sender<Command>,
}

impl StorageWorker {
    /// Opens synchronously; call during application initialization or on a blocking task.
    pub fn open(root: PathBuf) -> Result<Self> {
        let (sender, receiver) = mpsc::channel();
        let (ready_sender, ready_receiver) = mpsc::sync_channel(1);
        let thread = thread::Builder::new()
            .name("sked-agent-storage".into())
            .spawn(move || {
                let mut storage = match AgentStorage::open(root) {
                    Ok(storage) => {
                        let _ = ready_sender.send(Ok(()));
                        storage
                    }
                    Err(error) => {
                        let _ = ready_sender.send(Err(error));
                        return;
                    }
                };
                while let Ok(command) = receiver.recv() {
                    match command {
                        Command::Work(work) => work(&mut storage),
                        Command::Stop => break,
                    }
                }
            })?;
        ready_receiver
            .recv()
            .map_err(|_| StorageError::WorkerClosed)??;
        Ok(Self {
            handle: StorageHandle { sender },
            thread: Some(thread),
        })
    }

    pub fn handle(&self) -> StorageHandle {
        self.handle.clone()
    }

    /// Queue shutdown after all accepted work, then wait for the owner to release files.
    pub fn shutdown(mut self) -> Result<()> {
        let _ = self.handle.sender.send(Command::Stop);
        if let Some(thread) = self.thread.take() {
            thread.join().map_err(|_| StorageError::WorkerClosed)?;
        }
        Ok(())
    }
}

impl Drop for StorageWorker {
    fn drop(&mut self) {
        // Explicit shutdown is the wait boundary; dropping still closes after
        // already queued writes without blocking an async executor thread.
        let _ = self.handle.sender.send(Command::Stop);
    }
}

impl StorageHandle {
    /// A dropped waiter does not cancel an already accepted storage transaction.
    pub async fn call<T: Send + 'static>(
        &self,
        operation: impl FnOnce(&mut AgentStorage) -> Result<T> + Send + 'static,
    ) -> Result<T> {
        let (sender, receiver) = oneshot::channel();
        self.sender
            .send(Command::Work(Box::new(move |storage| {
                let _ = sender.send(operation(storage));
            })))
            .map_err(|_| StorageError::WorkerClosed)?;
        receiver.await.map_err(|_| StorageError::WorkerClosed)?
    }
}
