//! Frozen execution material, single-use admission and platform provider seams.
//! The Dart operation coordinator retains approval authority; this module owns
//! prepared-handle identity, cancellation, completion and receipt consistency.

#[cfg(target_os = "android")]
mod android;
mod contracts;
mod models;
mod prepared;
mod service;
mod validation;
#[cfg(windows)]
mod windows;

#[cfg(target_os = "android")]
pub use android::AndroidExecutionPlugin;
pub use contracts::{
    ControlledReaderRegistration, ExecutionCapabilities, ExecutionPreparation, ExecutionProvider,
    ExecutionStartRequest, PreparedExecutionBackend, Result,
};
pub use models::*;
pub use prepared::PreparedExecution;
pub use service::{EXECUTION_SERVICE, ExecutionService};
pub(crate) use validation::environment_names_equal;
#[cfg(windows)]
pub use windows::WindowsExecutionPlugin;
