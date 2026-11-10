//! Built-in plugin composition, service bindings and owned asynchronous cleanup.
//!
//! Lifecycle changes run on one actor. Service lookup and scope registration use
//! short synchronous locks; plugin code is never awaited while holding a lock.

mod container;
mod contracts;
mod scope;

pub use container::PluginContainer;
pub use contracts::{
    AgentProfile, PLUGIN_CONTRACT_VERSION, Plugin, PluginDescriptor, PluginError, PluginInstance,
    PluginSpec, PluginState, ServiceDefinition, ServiceKey,
};
pub use scope::{PluginContext, ServiceLease};
