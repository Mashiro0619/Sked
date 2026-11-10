use std::sync::Arc;

use tokio::sync::oneshot;

use super::PersistenceStore;
use crate::{
    plugins::ServiceDefinition,
    storage::{Result, StorageError, StorageHandle},
};

pub const PERSISTENCE_SERVICE: ServiceDefinition<PersistenceService> =
    ServiceDefinition::new("sked.persistence", 1);

pub type PersistenceJob = Box<dyn FnOnce(&mut dyn PersistenceStore) + Send + 'static>;

/// The provider owns exclusive execution after dispatch succeeds. Teardown must
/// reject new jobs and finish already admitted jobs before releasing its store.
/// Domain operations define their own durable transactions; a job is not an
/// additional transaction spanning the conversation journal and knowledge DB.
pub trait PersistenceProvider: Send + Sync + 'static {
    fn dispatch(&self, job: PersistenceJob) -> Result<()>;
}

/// Consumers depend on domain contracts, not a concrete SQLite/JSONL store or
/// worker. Dropping a caller's future does not cancel a dispatched transaction.
#[derive(Clone)]
pub struct PersistenceService {
    provider: Arc<dyn PersistenceProvider>,
}

impl PersistenceService {
    pub fn new(provider: Arc<dyn PersistenceProvider>) -> Self {
        Self { provider }
    }

    pub async fn call<T: Send + 'static>(
        &self,
        operation: impl FnOnce(&mut dyn PersistenceStore) -> Result<T> + Send + 'static,
    ) -> Result<T> {
        let (sender, receiver) = oneshot::channel();
        self.provider.dispatch(Box::new(move |store| {
            let _ = sender.send(operation(store));
        }))?;
        receiver.await.map_err(|_| StorageError::WorkerClosed)?
    }
}

impl From<StorageHandle> for PersistenceService {
    fn from(handle: StorageHandle) -> Self {
        Self::new(Arc::new(handle))
    }
}
