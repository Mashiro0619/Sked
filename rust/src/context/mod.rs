//! Context assembly, estimation and compaction strategy with durable summaries.
//! Runtime retains admission, cancellation, presentation and execution ownership.

mod attachments;
mod contracts;
mod history;
mod local;
mod provider;
mod service;
mod sources;

pub(crate) use attachments::{attachment_tool_metadata, project_attachments, task_file_metadata};
pub use contracts::{
    CompactionPlan, ContextEstimate, ContextEstimateInput, ContextMutation, ContextProvider,
    SummaryRequest,
};
pub use local::DefaultContextProvider;
pub(crate) use local::native_content_supported;
pub use provider::DefaultContextPlugin;
pub use service::{CONTEXT_SERVICE, ContextService};
pub use sources::ContextContent;
pub(crate) use sources::{
    content_index, context_source_digest, imported_message_text, provider_call_group,
    real_input_positions, recorded_message_text, tool_content_sources,
    tool_content_sources_for_reading,
};

pub(crate) use history::{archive_history, attachment_source, attachment_source_id};
