use std::{ops::Deref, sync::Arc};

use super::RuntimeProvider;
use crate::{plugins::ServiceDefinition, runtime::RuntimeManager};

pub const RUNTIME_SERVICE: ServiceDefinition<RuntimeService> =
    ServiceDefinition::new("sked.runtime", 1);

/// A shared handle to one provider instance. Domain calls borrow this handle,
/// and plugin dependencies retain it through admitted work and quiescence.
/// The provider owns all session locks, task control and durable settlement.
#[derive(Clone)]
pub struct RuntimeService {
    provider: Arc<dyn RuntimeProvider>,
}

impl RuntimeService {
    pub fn new(provider: Arc<dyn RuntimeProvider>) -> Self {
        Self { provider }
    }
}

impl Deref for RuntimeService {
    type Target = dyn RuntimeProvider;

    fn deref(&self) -> &Self::Target {
        self.provider.as_ref()
    }
}

impl From<RuntimeManager> for RuntimeService {
    fn from(manager: RuntimeManager) -> Self {
        Self::new(Arc::new(manager))
    }
}
