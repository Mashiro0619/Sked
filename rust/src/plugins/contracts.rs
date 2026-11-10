use std::{fmt, marker::PhantomData, sync::Arc};

use async_trait::async_trait;
use serde_json::Value;

use super::PluginContext;

pub const PLUGIN_CONTRACT_VERSION: u32 = 1;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ServiceKey {
    pub name: &'static str,
    pub version: u32,
}

impl fmt::Display for ServiceKey {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}@{}", self.name, self.version)
    }
}

pub struct ServiceDefinition<T> {
    key: ServiceKey,
    marker: PhantomData<fn() -> T>,
}

impl<T> ServiceDefinition<T> {
    pub const fn new(name: &'static str, version: u32) -> Self {
        Self {
            key: ServiceKey { name, version },
            marker: PhantomData,
        }
    }

    pub const fn key(self) -> ServiceKey {
        self.key
    }
}

impl<T> Copy for ServiceDefinition<T> {}

impl<T> Clone for ServiceDefinition<T> {
    fn clone(&self) -> Self {
        *self
    }
}

impl<T> fmt::Debug for ServiceDefinition<T> {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(&self.key, formatter)
    }
}

/// Original activation and cleanup failures remain available as separate causes.
#[derive(Debug, Clone)]
pub struct PluginError {
    pub message: String,
    pub causes: Vec<PluginError>,
}

impl PluginError {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            causes: Vec::new(),
        }
    }

    pub fn aggregate(message: impl Into<String>, causes: Vec<PluginError>) -> Self {
        Self {
            message: message.into(),
            causes,
        }
    }

    pub(crate) fn context(self, message: impl Into<String>) -> Self {
        Self::aggregate(message, vec![self])
    }
}

impl fmt::Display for PluginError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.message)?;
        for cause in &self.causes {
            write!(formatter, "\n  {cause}")?;
        }
        Ok(())
    }
}

impl std::error::Error for PluginError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        self.causes
            .first()
            .map(|cause| cause as &(dyn std::error::Error + 'static))
    }
}

#[derive(Debug, Clone)]
pub struct PluginDescriptor {
    pub id: &'static str,
    pub contract_version: u32,
    pub provides: Vec<ServiceKey>,
    pub dependencies: Vec<ServiceKey>,
}

#[async_trait]
pub trait Plugin: Send + Sync + 'static {
    fn descriptor(&self) -> PluginDescriptor;

    /// Acquire resources through this instance's scope. Register their cleanup
    /// as they are acquired so an incomplete setup can be unwound completely.
    async fn setup(&self, context: PluginContext) -> Result<(), PluginError>;
}

#[derive(Clone)]
pub struct PluginSpec {
    pub instance_id: String,
    pub plugin: Arc<dyn Plugin>,
    pub config: Value,
}

impl PluginSpec {
    pub fn new(instance_id: impl Into<String>, plugin: Arc<dyn Plugin>, config: Value) -> Self {
        Self {
            instance_id: instance_id.into(),
            plugin,
            config,
        }
    }
}

pub struct AgentProfile {
    pub id: String,
    pub plugins: Vec<PluginSpec>,
    pub required_services: Vec<ServiceKey>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PluginState {
    Suspended,
    Starting,
    Active,
    Quiescing,
    Disposing,
    Failed,
    Disposed,
}

#[derive(Debug, Clone)]
pub struct PluginInstance {
    pub instance_id: String,
    pub plugin_id: &'static str,
    pub contract_version: u32,
    pub generation: u64,
    pub state: PluginState,
    pub failure: Option<PluginError>,
}
