//! Lifecycle-owned tool registrations and the existing business host seam.

mod catalog;
mod contracts;
mod defaults;
mod host;
mod lifecycle;
mod native;

pub use catalog::{ToolCatalogSnapshot, ToolRegistrationToken, ToolService};
pub use contracts::{
    RuntimeToolGroup, ToolCall, ToolContribution, ToolHandler, ToolRegistryError, ToolResult,
    ToolRunContext,
};
pub use defaults::{DefaultToolPlugin, default_tool_service};
pub use host::{BusinessHostProvider, BusinessHostService};

use crate::plugins::ServiceDefinition;

pub const TOOL_SERVICE: ServiceDefinition<ToolService> = ServiceDefinition::new("sked.tools", 1);
pub const BUSINESS_HOST_SERVICE: ServiceDefinition<BusinessHostService> =
    ServiceDefinition::new("sked.business-host", 1);
