//! Session and run contracts consumed by the native API and profile lifecycle.
//! The default adapter keeps the existing manager's admission, durable receipts
//! and per-session coordination together behind the shared provider handle.

mod contracts;
mod local;
mod service;

pub use contracts::{
    ConversationRuntime, HistoryRuntime, RunRuntime, RuntimeLifecycle, RuntimeProvider,
};
pub use service::{RUNTIME_SERVICE, RuntimeService};
