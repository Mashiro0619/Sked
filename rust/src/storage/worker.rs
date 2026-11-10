use std::{
    path::PathBuf,
    sync::{Arc, Mutex, mpsc},
    thread,
};

use tokio::sync::oneshot;

use super::services::{PersistenceJob, PersistenceProvider, PersistenceService};
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
    sender: Arc<Mutex<Option<mpsc::Sender<Command>>>>,
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
            handle: StorageHandle {
                sender: Arc::new(Mutex::new(Some(sender))),
            },
            thread: Some(thread),
        })
    }

    pub fn handle(&self) -> StorageHandle {
        self.handle.clone()
    }

    pub fn service(&self) -> PersistenceService {
        self.handle.clone().into()
    }

    /// Queue shutdown after all accepted work, then wait for the owner to release files.
    pub fn shutdown(mut self) -> Result<()> {
        self.handle.stop();
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
        self.handle.stop();
    }
}

impl StorageHandle {
    fn enqueue(&self, work: Work) -> Result<()> {
        self.sender
            .lock()
            .expect("storage admission mutex poisoned")
            .as_ref()
            .ok_or(StorageError::WorkerClosed)?
            .send(Command::Work(work))
            .map_err(|_| StorageError::WorkerClosed)
    }

    fn stop(&self) {
        let mut sender = self
            .sender
            .lock()
            .expect("storage admission mutex poisoned");
        if let Some(sender) = sender.take() {
            // Work and Stop share this gate: success cannot queue a job behind
            // Stop while the receiver is still alive but already retiring.
            let _ = sender.send(Command::Stop);
        }
    }

    /// A dropped waiter does not cancel an already accepted storage transaction.
    pub async fn call<T: Send + 'static>(
        &self,
        operation: impl FnOnce(&mut AgentStorage) -> Result<T> + Send + 'static,
    ) -> Result<T> {
        let (sender, receiver) = oneshot::channel();
        self.enqueue(Box::new(move |storage| {
            let _ = sender.send(operation(storage));
        }))?;
        receiver.await.map_err(|_| StorageError::WorkerClosed)?
    }
}

impl PersistenceProvider for StorageHandle {
    fn dispatch(&self, job: PersistenceJob) -> Result<()> {
        self.enqueue(Box::new(move |store| job(store)))
    }
}
