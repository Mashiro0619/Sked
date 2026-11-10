use std::{
    any::Any,
    collections::{BTreeMap, BTreeSet},
    panic::AssertUnwindSafe,
    sync::{
        Arc, Mutex,
        atomic::{AtomicBool, Ordering},
    },
};

use futures::FutureExt;
use tokio::sync::{Notify, mpsc, oneshot, watch};

use super::{
    AgentProfile, PLUGIN_CONTRACT_VERSION, PluginContext, PluginDescriptor, PluginError,
    PluginInstance, PluginSpec, PluginState, ServiceDefinition, ServiceKey, ServiceLease,
    UiContributionOwner, UiContributionSnapshot,
    scope::{Cleanup, ServiceSlot},
};

type LifecycleResult = Result<(), PluginError>;
type Reply = oneshot::Sender<LifecycleResult>;

enum Command {
    Install(PluginSpec, Reply),
    Update(PluginSpec, Reply),
    Remove(String, Reply),
    Shutdown,
}

struct Registry {
    accepting: bool,
    services: BTreeMap<ServiceKey, Arc<ServiceSlot>>,
}

struct Shared {
    registry: Mutex<Registry>,
    ui_contributions: watch::Sender<UiContributionSnapshot>,
    instances: Mutex<BTreeMap<String, PluginInstance>>,
    closing: AtomicBool,
    completion: Mutex<Option<LifecycleResult>>,
    completed: Notify,
}

impl Shared {
    fn begin_shutdown(&self) -> bool {
        let first = !self.closing.swap(true, Ordering::AcqRel);
        self.registry.lock().unwrap().accepting = false;
        self.publish_ui(Vec::new());
        first
    }

    fn publish_ui(&self, mut owners: Vec<UiContributionOwner>) {
        self.ui_contributions.send_if_modified(|snapshot| {
            // Recheck under the watch lock: an activation racing shutdown
            // cannot republish renderers after the empty retirement snapshot.
            if self.closing.load(Ordering::Acquire) {
                owners.clear();
            }
            if snapshot.owners == owners {
                return false;
            }
            snapshot.revision = snapshot
                .revision
                .checked_add(1)
                .expect("UI contribution revision exhausted");
            snapshot.owners = owners;
            true
        });
    }

    fn complete(&self, result: LifecycleResult) {
        let mut completion = self.completion.lock().unwrap();
        if completion.is_none() {
            *completion = Some(result);
        }
        drop(completion);
        self.completed.notify_waiters();
    }

    async fn wait_for_shutdown(&self) -> LifecycleResult {
        loop {
            let completed = self.completed.notified();
            tokio::pin!(completed);
            completed.as_mut().enable();
            if let Some(result) = self.completion.lock().unwrap().clone() {
                return result;
            }
            completed.await;
        }
    }
}

/// A serial lifecycle actor owns all plugin transitions. Dropping the final
/// container handle also asks the actor to drain and dispose its composition.
#[derive(Clone)]
pub struct PluginContainer {
    shared: Arc<Shared>,
    commands: mpsc::UnboundedSender<Command>,
}

impl PluginContainer {
    /// Default startup is transactional: any failed setup or required service
    /// rolls back every instance introduced by this profile before returning.
    pub async fn assemble(profile: AgentProfile) -> Result<Self, PluginError> {
        let shared = Arc::new(Shared {
            registry: Mutex::new(Registry {
                accepting: true,
                services: BTreeMap::new(),
            }),
            instances: Mutex::new(BTreeMap::new()),
            ui_contributions: watch::channel(UiContributionSnapshot::default()).0,
            closing: AtomicBool::new(false),
            completion: Mutex::new(None),
            completed: Notify::new(),
        });
        let (commands, receiver) = mpsc::unbounded_channel();
        let (ready, initialized) = oneshot::channel();
        let actor_shared = shared.clone();
        tokio::spawn(async move {
            let mut worker = Worker::new(actor_shared.clone());
            let initialized = worker.initialize(profile).await;
            if let Err(error) = initialized {
                actor_shared.begin_shutdown();
                actor_shared.complete(Err(error.clone()));
                let _ = ready.send(Err(error));
                return;
            }
            if ready.send(Ok(())).is_err() {
                // The caller abandoned initialization after resources started.
                actor_shared.begin_shutdown();
                let result = worker.shutdown().await;
                actor_shared.complete(result);
                return;
            }
            worker.run(receiver).await;
        });
        initialized
            .await
            .map_err(|_| PluginError::new("Plugin lifecycle actor stopped during startup"))??;
        Ok(Self { shared, commands })
    }

    pub fn lease<T: Send + Sync + 'static>(
        &self,
        definition: ServiceDefinition<T>,
    ) -> Result<ServiceLease<T>, PluginError> {
        let registry = self.shared.registry.lock().unwrap();
        if !registry.accepting || self.shared.closing.load(Ordering::Acquire) {
            return Err(closed());
        }
        registry
            .services
            .get(&definition.key())
            .ok_or_else(|| {
                PluginError::new(format!("Service {} is unavailable", definition.key()))
            })?
            .lease()
    }

    pub fn instances(&self) -> Vec<PluginInstance> {
        self.shared
            .instances
            .lock()
            .unwrap()
            .values()
            .cloned()
            .collect()
    }

    pub fn ui_contributions(&self) -> watch::Receiver<UiContributionSnapshot> {
        self.shared.ui_contributions.subscribe()
    }

    /// Missing dependencies leave an installed instance suspended. Returning
    /// providers activate it automatically; failed setup requires update().
    pub async fn install(&self, spec: PluginSpec) -> LifecycleResult {
        self.request(|reply| Command::Install(spec, reply)).await
    }

    /// Explicitly replace/retry an instance, retaining its declared consumers
    /// as suspended until the replacement has successfully provided services.
    pub async fn update(&self, spec: PluginSpec) -> LifecycleResult {
        self.request(|reply| Command::Update(spec, reply)).await
    }

    pub async fn remove(&self, instance_id: impl Into<String>) -> LifecycleResult {
        let instance_id = instance_id.into();
        self.request(|reply| Command::Remove(instance_id, reply))
            .await
    }

    async fn request(&self, command: impl FnOnce(Reply) -> Command) -> LifecycleResult {
        if self.shared.closing.load(Ordering::Acquire) {
            return Err(closed());
        }
        let (reply, result) = oneshot::channel();
        self.commands.send(command(reply)).map_err(|_| closed())?;
        result.await.map_err(|_| closed())?
    }

    /// All callers join the same completion, including a caller arriving while
    /// cleanup is already running or after an earlier shutdown future dropped.
    pub async fn shutdown(&self) -> LifecycleResult {
        if self.shared.begin_shutdown() && self.commands.send(Command::Shutdown).is_err() {
            self.shared.complete(Err(PluginError::new(
                "Plugin lifecycle actor is unavailable",
            )));
        }
        self.shared.wait_for_shutdown().await
    }
}

struct Instance {
    spec: PluginSpec,
    descriptor: PluginDescriptor,
    generation: u64,
    state: PluginState,
    context: Option<PluginContext>,
    failure: Option<PluginError>,
}

impl Instance {
    fn snapshot(&self) -> PluginInstance {
        PluginInstance {
            instance_id: self.spec.instance_id.clone(),
            plugin_id: self.descriptor.id,
            contract_version: self.descriptor.contract_version,
            generation: self.generation,
            state: self.state,
            failure: self.failure.clone(),
        }
    }
}

struct Worker {
    shared: Arc<Shared>,
    instances: BTreeMap<String, Instance>,
    declaration_order: Vec<String>,
    activation_order: Vec<String>,
    generation: u64,
    shutdown_failures: Vec<PluginError>,
}

impl Worker {
    fn new(shared: Arc<Shared>) -> Self {
        Self {
            shared,
            instances: BTreeMap::new(),
            declaration_order: Vec::new(),
            activation_order: Vec::new(),
            generation: 0,
            shutdown_failures: Vec::new(),
        }
    }

    fn publish(&self, id: &str) {
        if let Some(instance) = self.instances.get(id) {
            self.shared
                .instances
                .lock()
                .unwrap()
                .insert(id.to_owned(), instance.snapshot());
        }
        let owners = self
            .instances
            .values()
            .filter(|instance| instance.state == PluginState::Active)
            .filter_map(|instance| {
                let contributions = instance.context.as_ref()?.ui_contributions();
                (!contributions.is_empty()).then(|| UiContributionOwner {
                    instance_id: instance.spec.instance_id.clone(),
                    generation: instance.generation,
                    contributions,
                })
            })
            .collect();
        self.shared.publish_ui(owners);
    }

    fn insert(&mut self, spec: PluginSpec, descriptor: PluginDescriptor) {
        let id = spec.instance_id.clone();
        self.declaration_order.push(id.clone());
        self.instances.insert(
            id.clone(),
            Instance {
                spec,
                descriptor,
                generation: 0,
                state: PluginState::Suspended,
                context: None,
                failure: None,
            },
        );
        self.publish(&id);
    }

    async fn initialize(&mut self, profile: AgentProfile) -> LifecycleResult {
        if profile.id.trim().is_empty() {
            return Err(PluginError::new("A plugin profile requires an id"));
        }
        for spec in profile.plugins {
            let descriptor = self.validate(&spec, None)?;
            self.insert(spec, descriptor);
        }
        let mut failures = self.reconcile().await;
        {
            let registry = self.shared.registry.lock().unwrap();
            for required in profile.required_services {
                if !registry.services.contains_key(&required) {
                    failures.push(PluginError::new(format!(
                        "Profile {} requires unavailable service {required}",
                        profile.id
                    )));
                }
            }
        }
        if failures.is_empty() {
            return Ok(());
        }
        // Close admissions before unwinding the complete partial composition.
        self.shared.begin_shutdown();
        if let Err(error) = self.shutdown().await {
            failures.push(error);
        }
        Err(PluginError::aggregate(
            format!("Profile {} failed to assemble", profile.id),
            failures,
        ))
    }

    fn validate(
        &self,
        spec: &PluginSpec,
        replacing: Option<&str>,
    ) -> Result<PluginDescriptor, PluginError> {
        if spec.instance_id.trim().is_empty() {
            return Err(PluginError::new("A plugin instance requires an id"));
        }
        if self.instances.contains_key(&spec.instance_id)
            && replacing != Some(spec.instance_id.as_str())
        {
            return Err(PluginError::new(format!(
                "Plugin instance {} already exists",
                spec.instance_id
            )));
        }
        let descriptor = std::panic::catch_unwind(AssertUnwindSafe(|| spec.plugin.descriptor()))
            .map_err(panic_error)?;
        if descriptor.id.trim().is_empty() || descriptor.contract_version != PLUGIN_CONTRACT_VERSION
        {
            return Err(PluginError::new(format!(
                "Plugin {} has an unsupported descriptor",
                spec.instance_id
            )));
        }
        for (kind, keys) in [
            ("provider", &descriptor.provides),
            ("dependency", &descriptor.dependencies),
        ] {
            let mut seen = BTreeSet::new();
            for key in keys {
                if key.name.trim().is_empty() || key.version == 0 || !seen.insert(*key) {
                    return Err(PluginError::new(format!(
                        "Plugin {} declares an invalid or duplicate {kind} {key}",
                        spec.instance_id
                    )));
                }
            }
        }
        for existing in self.instances.values() {
            if replacing == Some(existing.spec.instance_id.as_str()) {
                continue;
            }
            for key in &descriptor.provides {
                if existing.descriptor.provides.contains(key) {
                    return Err(PluginError::new(format!(
                        "Service {key} is already assigned to plugin {}",
                        existing.spec.instance_id
                    )));
                }
            }
        }
        Ok(descriptor)
    }

    async fn run(&mut self, mut receiver: mpsc::UnboundedReceiver<Command>) {
        while let Some(command) = receiver.recv().await {
            if matches!(command, Command::Shutdown) {
                break;
            }
            let shutting_down = self.shared.closing.load(Ordering::Acquire);
            match command {
                Command::Install(spec, reply) => {
                    let result = if shutting_down {
                        Err(closed())
                    } else {
                        self.install(spec).await
                    };
                    let _ = reply.send(result);
                }
                Command::Update(spec, reply) => {
                    let result = if shutting_down {
                        Err(closed())
                    } else {
                        self.update(spec).await
                    };
                    let _ = reply.send(result);
                }
                Command::Remove(id, reply) => {
                    let result = if shutting_down {
                        Err(closed())
                    } else {
                        self.remove(&id).await
                    };
                    let _ = reply.send(result);
                }
                Command::Shutdown => unreachable!(),
            }
        }
        self.shared.begin_shutdown();
        let result = self.shutdown().await;
        self.shared.complete(result);
    }

    async fn install(&mut self, spec: PluginSpec) -> LifecycleResult {
        let descriptor = self.validate(&spec, None)?;
        self.insert(spec, descriptor);
        collected("Plugin installation failed", self.reconcile().await)
    }

    async fn update(&mut self, spec: PluginSpec) -> LifecycleResult {
        let id = spec.instance_id.clone();
        if !self.instances.contains_key(&id) {
            return Err(PluginError::new(format!(
                "Plugin instance {id} does not exist"
            )));
        }
        let descriptor = self.validate(&spec, Some(&id))?;
        let affected = self.dependents_of(&id);
        let failures = self.stop_instances(&affected).await;
        self.retain_shutdown_failures(&failures);
        if !failures.is_empty() {
            return collected("Plugin replacement cleanup failed", failures);
        }
        let instance = self.instances.get_mut(&id).unwrap();
        instance.spec = spec;
        instance.descriptor = descriptor;
        instance.state = PluginState::Suspended;
        instance.failure = None;
        self.publish(&id);
        collected("Plugin replacement failed", self.reconcile().await)
    }

    async fn remove(&mut self, id: &str) -> LifecycleResult {
        if !self.instances.contains_key(id) {
            return Err(PluginError::new(format!(
                "Plugin instance {id} does not exist"
            )));
        }
        let affected = self.dependents_of(id);
        let failures = self.stop_instances(&affected).await;
        self.retain_shutdown_failures(&failures);
        self.instances.remove(id);
        self.declaration_order.retain(|candidate| candidate != id);
        self.shared.instances.lock().unwrap().remove(id);
        collected("Plugin removal cleanup failed", failures)
    }

    fn dependents_of(&self, id: &str) -> BTreeSet<String> {
        let mut affected = BTreeSet::from([id.to_owned()]);
        loop {
            let services: BTreeSet<_> = affected
                .iter()
                .filter_map(|id| self.instances.get(id))
                .flat_map(|instance| instance.descriptor.provides.iter().copied())
                .collect();
            let added: Vec<_> = self
                .instances
                .iter()
                .filter(|(id, instance)| {
                    !affected.contains(*id)
                        && instance
                            .descriptor
                            .dependencies
                            .iter()
                            .any(|key| services.contains(key))
                })
                .map(|(id, _)| id.clone())
                .collect();
            if added.is_empty() {
                return affected;
            }
            affected.extend(added);
        }
    }

    async fn reconcile(&mut self) -> Vec<PluginError> {
        let mut failures = Vec::new();
        loop {
            if self.shared.closing.load(Ordering::Acquire) {
                break;
            }
            let ready = {
                let registry = self.shared.registry.lock().unwrap();
                self.declaration_order
                    .iter()
                    .find(|id| {
                        let instance = &self.instances[*id];
                        instance.state == PluginState::Suspended
                            && instance
                                .descriptor
                                .dependencies
                                .iter()
                                .all(|key| registry.services.contains_key(key))
                    })
                    .cloned()
            };
            let Some(id) = ready else { break };
            if let Err(error) = self.activate(&id).await {
                // Admission failures before setup must also settle the instance
                // instead of leaving reconcile to retry the same candidate.
                if self.instances[&id].state == PluginState::Suspended {
                    let instance = self.instances.get_mut(&id).unwrap();
                    instance.state = PluginState::Failed;
                    instance.failure = Some(error.clone());
                    self.publish(&id);
                }
                failures.push(error);
            }
        }
        failures
    }

    async fn activate(&mut self, id: &str) -> LifecycleResult {
        self.generation = self
            .generation
            .checked_add(1)
            .ok_or_else(|| PluginError::new("Plugin instance generation exhausted"))?;
        let instance = &self.instances[id];
        let dependencies = {
            let registry = self.shared.registry.lock().unwrap();
            if !registry.accepting || self.shared.closing.load(Ordering::Acquire) {
                return Err(closed());
            }
            instance
                .descriptor
                .dependencies
                .iter()
                .map(|key| {
                    let binding = registry
                        .services
                        .get(key)
                        .ok_or_else(|| {
                            PluginError::new(format!("Dependency {key} became unavailable"))
                        })?
                        .retain();
                    Ok((*key, binding))
                })
                .collect::<Result<BTreeMap<_, _>, PluginError>>()?
        };
        let plugin = instance.spec.plugin.clone();
        let context = PluginContext::new(
            id.to_owned(),
            self.generation,
            instance.descriptor.clone(),
            instance.spec.config.clone(),
            dependencies,
        );
        let instance = self.instances.get_mut(id).unwrap();
        instance.generation = self.generation;
        instance.state = PluginState::Starting;
        instance.context = Some(context.clone());
        instance.failure = None;
        self.activation_order.push(id.to_owned());
        self.publish(id);
        let setup = AssertUnwindSafe(plugin.setup(context.clone()))
            .catch_unwind()
            .await
            .map_err(panic_error)
            .and_then(|result| result);
        let result = setup.and_then(|()| self.commit(&context));
        if let Err(error) = result {
            let mut failures = vec![error.context(format!("Plugin {id} setup failed"))];
            let cleanup = self.stop_instances(&BTreeSet::from([id.to_owned()])).await;
            self.retain_shutdown_failures(&cleanup);
            failures.extend(cleanup);
            let error = PluginError::aggregate(format!("Plugin {id} could not activate"), failures);
            let instance = self.instances.get_mut(id).unwrap();
            instance.state = PluginState::Failed;
            instance.failure = Some(error.clone());
            self.publish(id);
            return Err(error);
        }
        self.instances.get_mut(id).unwrap().state = PluginState::Active;
        self.publish(id);
        Ok(())
    }

    fn commit(&self, context: &PluginContext) -> LifecycleResult {
        let services = context.ready_services()?;
        let mut registry = self.shared.registry.lock().unwrap();
        if !registry.accepting || self.shared.closing.load(Ordering::Acquire) {
            return Err(closed());
        }
        for service in &services {
            if registry.services.contains_key(&service.key) {
                return Err(PluginError::new(format!(
                    "Service {} is already active",
                    service.key
                )));
            }
        }
        for service in services {
            registry.services.insert(service.key, service);
        }
        drop(registry);
        context.set_phase(PluginState::Active);
        Ok(())
    }

    async fn stop_instances(&mut self, affected: &BTreeSet<String>) -> Vec<PluginError> {
        // Successful activation order is a topological order of concrete
        // bindings. Reversing it retires every consumer before its providers.
        let ids: Vec<_> = self
            .activation_order
            .iter()
            .rev()
            .filter(|id| affected.contains(*id))
            .cloned()
            .collect();
        let mut contexts = Vec::new();
        for id in ids {
            let instance = self.instances.get_mut(&id).unwrap();
            if let Some(context) = instance.context.take() {
                context.set_phase(PluginState::Quiescing);
                instance.state = PluginState::Quiescing;
                self.publish(&id);
                contexts.push((id, context));
            }
        }
        {
            let mut registry = self.shared.registry.lock().unwrap();
            for (_, context) in &contexts {
                for service in context.services() {
                    if registry
                        .services
                        .get(&service.key)
                        .is_some_and(|current| Arc::ptr_eq(current, &service))
                    {
                        registry.services.remove(&service.key);
                    }
                }
            }
        }
        let mut failures = BTreeMap::<String, Vec<PluginError>>::new();
        // Keep every event/resource contribution alive while consumers finish
        // cancellation and accepted writes. Dispose only after all quiesce.
        for (id, context) in &contexts {
            let errors = cleanup(context.take_quiesce(), id, "quiesce").await;
            failures.entry(id.clone()).or_default().extend(errors);
        }
        for (id, context) in contexts {
            for service in context.services() {
                service.wait_for_leases().await;
            }
            context.set_phase(PluginState::Disposing);
            self.instances.get_mut(&id).unwrap().state = PluginState::Disposing;
            self.publish(&id);
            let errors = cleanup(context.take_dispose(), &id, "dispose").await;
            let own_failures = failures.entry(id.clone()).or_default();
            own_failures.extend(errors);
            if let Err(error) = std::panic::catch_unwind(AssertUnwindSafe(|| context.finish())) {
                own_failures.push(
                    panic_error(error).context(format!("Plugin {id} resource release failed")),
                );
            }
            let instance = self.instances.get_mut(&id).unwrap();
            if own_failures.is_empty() {
                instance.state = PluginState::Suspended;
            } else {
                instance.state = PluginState::Failed;
                instance.failure = Some(PluginError::aggregate(
                    format!("Plugin {id} cleanup failed"),
                    own_failures.clone(),
                ));
            }
            self.publish(&id);
        }
        self.activation_order.retain(|id| !affected.contains(id));
        failures.into_values().flatten().collect()
    }

    fn retain_shutdown_failures(&mut self, failures: &[PluginError]) {
        // An already-running install/update can unwind while a shutdown request
        // waits in the actor queue. Its cleanup belongs to that same shutdown.
        if self.shared.closing.load(Ordering::Acquire) {
            self.shutdown_failures.extend_from_slice(failures);
        }
    }

    async fn shutdown(&mut self) -> LifecycleResult {
        let affected = self.instances.keys().cloned().collect();
        let mut failures = std::mem::take(&mut self.shutdown_failures);
        failures.extend(self.stop_instances(&affected).await);
        for instance in self.instances.values_mut() {
            if instance.state != PluginState::Failed {
                instance.state = PluginState::Disposed;
            }
        }
        for id in &self.declaration_order {
            self.publish(id);
        }
        collected("Plugin shutdown failed", failures)
    }
}

async fn cleanup(callbacks: Vec<Cleanup>, id: &str, phase: &str) -> Vec<PluginError> {
    let mut failures = Vec::new();
    for callback in callbacks.into_iter().rev() {
        let result = AssertUnwindSafe(async move { callback().await })
            .catch_unwind()
            .await;
        if let Err(error) = result.map_err(panic_error).and_then(|result| result) {
            failures.push(error.context(format!("Plugin {id} {phase} failed")));
        }
    }
    failures
}

fn panic_error(error: Box<dyn Any + Send>) -> PluginError {
    let message = error
        .downcast_ref::<String>()
        .map(String::as_str)
        .or_else(|| error.downcast_ref::<&str>().copied())
        .unwrap_or("Plugin callback panicked");
    PluginError::new(message)
}

fn collected(message: &str, failures: Vec<PluginError>) -> LifecycleResult {
    if failures.is_empty() {
        Ok(())
    } else {
        Err(PluginError::aggregate(message, failures))
    }
}

fn closed() -> PluginError {
    PluginError::new("Plugin container is shutting down")
}
