use std::{
    any::{Any, type_name},
    collections::BTreeMap,
    ops::Deref,
    sync::{
        Arc, Mutex,
        atomic::{AtomicUsize, Ordering},
    },
};

use futures::future::BoxFuture;
use serde_json::Value;
use tokio::sync::Notify;

use super::{PluginDescriptor, PluginError, PluginState, ServiceDefinition, ServiceKey};

pub(crate) type Cleanup =
    Box<dyn FnOnce() -> BoxFuture<'static, Result<(), PluginError>> + Send + 'static>;

pub(crate) struct ServiceSlot {
    pub key: ServiceKey,
    pub instance_id: String,
    pub generation: u64,
    value: Arc<dyn Any + Send + Sync>,
    type_name: &'static str,
    leases: AtomicUsize,
    released: Notify,
}

impl ServiceSlot {
    fn new<T: Send + Sync + 'static>(
        definition: ServiceDefinition<T>,
        value: T,
        instance_id: String,
        generation: u64,
    ) -> Self {
        Self {
            key: definition.key(),
            instance_id,
            generation,
            value: Arc::new(value),
            type_name: type_name::<T>(),
            leases: AtomicUsize::new(0),
            released: Notify::new(),
        }
    }

    pub fn lease<T: Send + Sync + 'static>(
        self: &Arc<Self>,
    ) -> Result<ServiceLease<T>, PluginError> {
        let value = self.value.clone().downcast::<T>().map_err(|_| {
            PluginError::new(format!(
                "Service {} has type {}, requested {}",
                self.key,
                self.type_name,
                type_name::<T>()
            ))
        })?;
        Ok(ServiceLease {
            value,
            binding: self.retain(),
        })
    }

    pub fn retain(self: &Arc<Self>) -> RetainedService {
        self.leases.fetch_add(1, Ordering::AcqRel);
        RetainedService { slot: self.clone() }
    }

    pub async fn wait_for_leases(&self) {
        loop {
            let released = self.released.notified();
            if self.leases.load(Ordering::Acquire) == 0 {
                return;
            }
            released.await;
        }
    }
}

pub(crate) struct RetainedService {
    pub slot: Arc<ServiceSlot>,
}

impl Clone for RetainedService {
    fn clone(&self) -> Self {
        self.slot.retain()
    }
}

impl Drop for RetainedService {
    fn drop(&mut self) {
        if self.slot.leases.fetch_sub(1, Ordering::AcqRel) == 1 {
            // The lifecycle actor is the single waiter for a provider slot.
            self.slot.released.notify_one();
        }
    }
}

/// A binding to one provider generation, valid throughout admitted work and
/// cleanup. Withdrawing the provider only prevents acquiring new bindings.
pub struct ServiceLease<T> {
    value: Arc<T>,
    binding: RetainedService,
}

impl<T> ServiceLease<T> {
    pub fn instance_id(&self) -> &str {
        &self.binding.slot.instance_id
    }

    pub fn generation(&self) -> u64 {
        self.binding.slot.generation
    }

    pub fn key(&self) -> ServiceKey {
        self.binding.slot.key
    }
}

impl<T> Clone for ServiceLease<T> {
    fn clone(&self) -> Self {
        Self {
            value: self.value.clone(),
            binding: self.binding.clone(),
        }
    }
}

impl<T> Deref for ServiceLease<T> {
    type Target = T;

    fn deref(&self) -> &T {
        &self.value
    }
}

struct ScopeState {
    phase: PluginState,
    provided: BTreeMap<ServiceKey, Arc<ServiceSlot>>,
    dependencies: BTreeMap<ServiceKey, RetainedService>,
    quiesce: Vec<Cleanup>,
    dispose: Vec<Cleanup>,
}

struct ScopeInner {
    instance_id: String,
    generation: u64,
    descriptor: PluginDescriptor,
    config: Value,
    state: Mutex<ScopeState>,
}

/// Explicit contribution ownership replaces ambient caller tracing across the
/// Rust/Dart boundary. A saved context cannot register resources after teardown.
#[derive(Clone)]
pub struct PluginContext {
    inner: Arc<ScopeInner>,
}

impl PluginContext {
    pub(crate) fn new(
        instance_id: String,
        generation: u64,
        descriptor: PluginDescriptor,
        config: Value,
        dependencies: BTreeMap<ServiceKey, RetainedService>,
    ) -> Self {
        Self {
            inner: Arc::new(ScopeInner {
                instance_id,
                generation,
                descriptor,
                config,
                state: Mutex::new(ScopeState {
                    phase: PluginState::Starting,
                    provided: BTreeMap::new(),
                    dependencies,
                    quiesce: Vec::new(),
                    dispose: Vec::new(),
                }),
            }),
        }
    }

    pub fn instance_id(&self) -> &str {
        &self.inner.instance_id
    }

    pub fn generation(&self) -> u64 {
        self.inner.generation
    }

    pub fn config(&self) -> &Value {
        &self.inner.config
    }

    /// A weak phase guard lets contributed resources follow activation without
    /// retaining the plugin's services or extending its disposal lifetime.
    pub fn activity_guard(&self) -> impl Fn() -> bool + Send + Sync + 'static {
        let inner = Arc::downgrade(&self.inner);
        move || {
            inner
                .upgrade()
                .is_some_and(|inner| inner.state.lock().unwrap().phase == PluginState::Active)
        }
    }

    /// Services are staged during setup and become discoverable together only
    /// after the complete setup succeeds.
    pub fn provide<T: Send + Sync + 'static>(
        &self,
        definition: ServiceDefinition<T>,
        value: T,
    ) -> Result<(), PluginError> {
        let key = definition.key();
        if !self.inner.descriptor.provides.contains(&key) {
            return Err(PluginError::new(format!(
                "Plugin {} did not declare provider {key}",
                self.instance_id()
            )));
        }
        let mut state = self.inner.state.lock().unwrap();
        if state.phase != PluginState::Starting {
            return Err(PluginError::new(
                "Services can only be provided during setup",
            ));
        }
        if state.provided.contains_key(&key) {
            return Err(PluginError::new(format!(
                "Service {key} was already provided"
            )));
        }
        state.provided.insert(
            key,
            Arc::new(ServiceSlot::new(
                definition,
                value,
                self.instance_id().to_owned(),
                self.generation(),
            )),
        );
        Ok(())
    }

    /// Dependencies remain bound to their original implementations throughout
    /// quiesce and disposal, even after those providers stop new admissions.
    pub fn require<T: Send + Sync + 'static>(
        &self,
        definition: ServiceDefinition<T>,
    ) -> Result<ServiceLease<T>, PluginError> {
        let key = definition.key();
        if !self.inner.descriptor.dependencies.contains(&key) {
            return Err(PluginError::new(format!(
                "Plugin {} did not declare dependency {key}",
                self.instance_id()
            )));
        }
        let state = self.inner.state.lock().unwrap();
        if state.phase == PluginState::Disposed {
            return Err(PluginError::new("Plugin instance has been disposed"));
        }
        state
            .dependencies
            .get(&key)
            .ok_or_else(|| PluginError::new(format!("Dependency {key} is unavailable")))?
            .slot
            .lease()
    }

    /// Stop admissions/cancellable tasks and drain accepted work. All affected
    /// instances finish this phase before any dispose callback is run.
    pub fn on_quiesce<F>(&self, cleanup: F) -> Result<(), PluginError>
    where
        F: FnOnce() -> BoxFuture<'static, Result<(), PluginError>> + Send + 'static,
    {
        self.register(Box::new(cleanup), true)
    }

    /// Release resources after consumers have disposed and outstanding leases
    /// have returned. Callbacks run in reverse registration order.
    pub fn on_dispose<F>(&self, cleanup: F) -> Result<(), PluginError>
    where
        F: FnOnce() -> BoxFuture<'static, Result<(), PluginError>> + Send + 'static,
    {
        self.register(Box::new(cleanup), false)
    }

    fn register(&self, cleanup: Cleanup, quiesce: bool) -> Result<(), PluginError> {
        let mut state = self.inner.state.lock().unwrap();
        if !matches!(state.phase, PluginState::Starting | PluginState::Active) {
            return Err(PluginError::new(
                "Plugin instance is no longer accepting effects",
            ));
        }
        if quiesce {
            state.quiesce.push(cleanup);
        } else {
            state.dispose.push(cleanup);
        }
        Ok(())
    }

    pub(crate) fn ready_services(&self) -> Result<Vec<Arc<ServiceSlot>>, PluginError> {
        let state = self.inner.state.lock().unwrap();
        for key in &self.inner.descriptor.provides {
            if !state.provided.contains_key(key) {
                return Err(PluginError::new(format!(
                    "Plugin {} completed setup without providing {key}",
                    self.instance_id()
                )));
            }
        }
        Ok(state.provided.values().cloned().collect())
    }

    pub(crate) fn set_phase(&self, phase: PluginState) {
        self.inner.state.lock().unwrap().phase = phase;
    }

    pub(crate) fn services(&self) -> Vec<Arc<ServiceSlot>> {
        self.inner
            .state
            .lock()
            .unwrap()
            .provided
            .values()
            .cloned()
            .collect()
    }

    pub(crate) fn take_quiesce(&self) -> Vec<Cleanup> {
        std::mem::take(&mut self.inner.state.lock().unwrap().quiesce)
    }

    pub(crate) fn take_dispose(&self) -> Vec<Cleanup> {
        std::mem::take(&mut self.inner.state.lock().unwrap().dispose)
    }

    pub(crate) fn finish(&self) {
        let (provided, dependencies) = {
            let mut state = self.inner.state.lock().unwrap();
            state.phase = PluginState::Disposed;
            (
                std::mem::take(&mut state.provided),
                std::mem::take(&mut state.dependencies),
            )
        };
        drop(provided);
        drop(dependencies);
    }
}
