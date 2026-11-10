//! Persistence contracts shared by the runtime, native API and storage plugins.
//! A provider runs each admitted job exclusively, preserving the domain methods'
//! own transaction and receipt boundaries within that job.

mod contracts;
mod local;
mod provider;
mod service;

pub use contracts::{
    ArchiveStore, AttachmentStore, ConversationStore, KnowledgeStore, PersistenceStore,
};
pub use provider::DefaultPersistencePlugin;
pub use service::{PERSISTENCE_SERVICE, PersistenceJob, PersistenceProvider, PersistenceService};
