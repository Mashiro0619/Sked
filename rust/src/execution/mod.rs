//! Frozen execution material, single-use admission and platform provider seams.
//! The Dart operation coordinator retains approval authority; this module owns
//! prepared-handle identity, cancellation, completion and receipt consistency.

mod contracts;
mod models;
mod prepared;
mod service;
mod validation;

pub use contracts::{
    ControlledReaderRegistration, ExecutionCapabilities, ExecutionPreparation, ExecutionProvider,
    ExecutionStartRequest, PreparedExecutionBackend, Result,
};
pub use models::*;
pub use prepared::PreparedExecution;
pub use service::{EXECUTION_SERVICE, ExecutionService};
