//! Context assembly, estimation and compaction strategy with durable summaries.
//! Runtime retains admission, cancellation, presentation and execution ownership.

mod contracts;
mod history;
mod local;
mod provider;
mod service;

pub use contracts::{
    CompactionPlan, ContextEstimate, ContextEstimateInput, ContextMutation, ContextProvider,
    SummaryRequest,
};
pub use local::DefaultContextProvider;
pub use provider::DefaultContextPlugin;
pub use service::{CONTEXT_SERVICE, ContextService};

pub(crate) use history::{archive_history, attachment_source, attachment_source_id};
