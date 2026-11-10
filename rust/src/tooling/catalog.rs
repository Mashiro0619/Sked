use std::{
    collections::HashSet,
    sync::{Arc, Mutex, Weak},
};

use futures::future::BoxFuture;
use serde_json::Value;

use super::lifecycle::{ActivityGuard, SourceLease, SourceLifetime};
use super::{ToolCall, ToolContribution, ToolHandler, ToolRegistryError, ToolRunContext};
use crate::{
    plugins::{PluginContext, PluginError},
    runtime::{RuntimeError, ToolDescriptor},
};

#[derive(Clone)]
struct RegisteredTool {
    descriptor: ToolDescriptor,
    handler: Weak<dyn ToolHandler>,
    bootstrap: bool,
    lifetime: Arc<SourceLifetime>,
    legacy_business: bool,
}

struct AdmittedTool {
    // Field order also releases handler-owned resources before the lease
    // signals drain when the invocation future is dropped or unwinds.
    handler: Arc<dyn ToolHandler>,
    lease: SourceLease,
}

struct Source {
    owner: String,
    revision: u64,
    lifetime: Arc<SourceLifetime>,
    tools: Vec<ToolContribution>,
    legacy_business: bool,
}

#[derive(Default)]
struct Catalog {
    revision: u64,
    closed: bool,
    sources: Vec<Source>,
}

/// Removes only the registration returned by replace_source. An old disposer
/// cannot withdraw a later replacement with the same owner name.
#[derive(Clone)]
pub struct ToolRegistrationToken {
    owner: String,
    revision: u64,
    lifetime: Arc<SourceLifetime>,
    registry: Weak<Mutex<Catalog>>,
}

#[derive(Clone, Default)]
pub struct ToolService {
    inner: Arc<Mutex<Catalog>>,
}

impl ToolService {
    /// Replace a complete source atomically after validating its definitions.
    /// Consumers retain the old handlers for already accepted calls. Low-level
    /// callers must keep the old token and withdraw_and_drain it before disposing
    /// its resources; plugins normally use register_scoped for automatic cleanup.
    pub fn replace_source(
        &self,
        owner: impl Into<String>,
        tools: Vec<ToolContribution>,
    ) -> Result<ToolRegistrationToken, ToolRegistryError> {
        self.replace_source_with_policy(owner.into(), tools, true, None)
    }

    /// Runtime-owned adapters keep their existing cancellation and self-clear
    /// exclusion policy. Their owning runtime already drains accepted calls.
    pub(super) fn replace_runtime_source(
        &self,
        owner: &str,
        tools: Vec<ToolContribution>,
    ) -> Result<ToolRegistrationToken, ToolRegistryError> {
        self.replace_source_with_policy(owner.into(), tools, false, None)
    }

    fn replace_source_with_policy(
        &self,
        owner: String,
        tools: Vec<ToolContribution>,
        cancel_on_close: bool,
        activity_guard: Option<ActivityGuard>,
    ) -> Result<ToolRegistrationToken, ToolRegistryError> {
        if owner.trim().is_empty() {
            return Err(ToolRegistryError::InvalidSource);
        }
        let mut names = HashSet::new();
        for tool in &tools {
            if tool.descriptor.name.is_empty() || !names.insert(tool.descriptor.name.clone()) {
                return Err(ToolRegistryError::InvalidName(tool.descriptor.name.clone()));
            }
        }
        let mut catalog = self.inner.lock().expect("tool catalog mutex poisoned");
        if catalog.closed {
            return Err(ToolRegistryError::Closed);
        }
        for source in catalog
            .sources
            .iter()
            .filter(|source| source.owner != owner && !source.legacy_business)
        {
            for tool in &source.tools {
                if names.contains(&tool.descriptor.name) {
                    return Err(ToolRegistryError::Duplicate(tool.descriptor.name.clone()));
                }
            }
        }
        let revision = catalog
            .revision
            .checked_add(1)
            .ok_or(ToolRegistryError::RevisionExhausted)?;
        let lifetime = SourceLifetime::new(cancel_on_close, activity_guard);
        let source = Source {
            owner: owner.clone(),
            revision,
            lifetime: lifetime.clone(),
            tools,
            legacy_business: false,
        };
        let retired = if let Some(index) = catalog
            .sources
            .iter()
            .position(|source| source.owner == owner)
        {
            catalog.sources[index].lifetime.stop_accepting();
            Some(std::mem::replace(&mut catalog.sources[index], source))
        } else {
            catalog.sources.push(source);
            None
        };
        catalog.revision = revision;
        drop(catalog);
        if let Some(retired) = retired {
            retired.lifetime.close();
            // Handler Drop may itself withdraw another source.
            drop(retired);
        }
        Ok(ToolRegistrationToken {
            owner,
            revision,
            lifetime,
            registry: Arc::downgrade(&self.inner),
        })
    }

    /// Compatibility with the original infallible set_tools(Vec) entrypoint.
    /// The application's single business handler owns every legacy entry,
    /// including duplicate descriptions. New plugin sources remain unique.
    pub(super) fn replace_legacy_business_source(&self, owner: &str, tools: Vec<ToolContribution>) {
        let mut catalog = self.inner.lock().expect("tool catalog mutex poisoned");
        if catalog.closed {
            return;
        }
        if catalog.sources.iter().any(|source| {
            source.owner == owner
                && source.legacy_business
                && source.tools.len() == tools.len()
                && source.tools.iter().zip(&tools).all(|(before, after)| {
                    before.descriptor.name == after.descriptor.name
                        && before.descriptor.description == after.descriptor.description
                        && before.descriptor.parameters == after.descriptor.parameters
                        && before.bootstrap == after.bootstrap
                })
        }) {
            return;
        }
        let revision = catalog.revision.saturating_add(1);
        let source = Source {
            owner: owner.into(),
            revision,
            lifetime: SourceLifetime::new(false, None),
            tools,
            legacy_business: true,
        };
        let retired = if let Some(index) = catalog
            .sources
            .iter()
            .position(|source| source.owner == owner)
        {
            catalog.sources[index].lifetime.stop_accepting();
            Some(std::mem::replace(&mut catalog.sources[index], source))
        } else {
            catalog.sources.push(source);
            None
        };
        catalog.revision = revision;
        drop(catalog);
        if let Some(retired) = retired {
            retired.lifetime.close();
            drop(retired);
        }
    }

    pub fn withdraw(&self, token: &ToolRegistrationToken) {
        if !Weak::ptr_eq(&token.registry, &Arc::downgrade(&self.inner)) {
            return;
        }
        let mut catalog = self.inner.lock().expect("tool catalog mutex poisoned");
        token.lifetime.stop_accepting();
        let retired = if let Some(index) = catalog.sources.iter().position(|source| {
            source.owner == token.owner
                && source.revision == token.revision
                && Arc::ptr_eq(&source.lifetime, &token.lifetime)
        }) {
            let source = catalog.sources.remove(index);
            catalog.revision = catalog.revision.saturating_add(1);
            Some(source)
        } else {
            None
        };
        drop(catalog);
        token.lifetime.close();
        drop(retired);
    }

    /// Even after replacement, the token still drains its original generation.
    pub async fn withdraw_and_drain(&self, token: &ToolRegistrationToken) {
        if !Weak::ptr_eq(&token.registry, &Arc::downgrade(&self.inner)) {
            return;
        }
        self.withdraw(token);
        token.lifetime.drain().await;
    }

    /// The plugin's quiesce phase withdraws and drains calls before any of its
    /// dispose callbacks close files, processes or other handler resources.
    pub fn register_scoped(
        &self,
        context: &PluginContext,
        tools: Vec<ToolContribution>,
    ) -> Result<ToolRegistrationToken, PluginError> {
        struct Binding {
            retired: bool,
            token: Option<ToolRegistrationToken>,
        }
        let binding = Arc::new(Mutex::new(Binding {
            retired: false,
            token: None,
        }));
        let cleanup_binding = binding.clone();
        let cleanup_service = self.clone();
        // Install cleanup before publishing. This local gate also handles a
        // concurrent quiesce between callback registration and source install.
        context.on_quiesce(move || {
            Box::pin(async move {
                let token = {
                    let mut binding = cleanup_binding.lock().expect("tool binding mutex poisoned");
                    binding.retired = true;
                    binding.token.take()
                };
                if let Some(token) = token {
                    cleanup_service.withdraw_and_drain(&token).await;
                }
                Ok(())
            })
        })?;
        let mut binding = binding.lock().expect("tool binding mutex poisoned");
        if binding.retired {
            return Err(PluginError::new(
                "Tool contribution owner is already retiring",
            ));
        }
        let owner = format!(
            "plugin:{}:{}@{}",
            context.instance_id().len(),
            context.instance_id(),
            context.generation()
        );
        let token = self
            .replace_source_with_policy(
                owner,
                tools,
                true,
                Some(Arc::new(context.activity_guard())),
            )
            .map_err(|error| PluginError::new(error.to_string()))?;
        binding.token = Some(token.clone());
        Ok(token)
    }

    pub fn snapshot(&self) -> ToolCatalogSnapshot {
        let catalog = self.inner.lock().expect("tool catalog mutex poisoned");
        // Freeze visibility once for both shadowing and captured definitions.
        // A Starting plugin neither hides legacy tools nor becomes visible
        // retroactively in a run that took its snapshot before activation.
        let visible_sources: Vec<_> = catalog
            .sources
            .iter()
            .filter(|source| source.lifetime.accepting())
            .collect();
        let provider_names: HashSet<_> = visible_sources
            .iter()
            .filter(|source| !source.legacy_business)
            .flat_map(|source| {
                source
                    .tools
                    .iter()
                    .map(|tool| tool.descriptor.name.as_str())
            })
            .collect();
        ToolCatalogSnapshot {
            revision: catalog.revision,
            tools: visible_sources
                .iter()
                .flat_map(|source| {
                    let provider_names = &provider_names;
                    source
                        .tools
                        .iter()
                        // Native/plugin definitions retain ownership if a
                        // later legacy host refresh repeats their names.
                        .filter(move |tool| {
                            !source.legacy_business
                                || !provider_names.contains(tool.descriptor.name.as_str())
                        })
                        .map(move |contribution| RegisteredTool {
                            descriptor: contribution.descriptor.clone(),
                            handler: Arc::downgrade(&contribution.handler),
                            bootstrap: contribution.bootstrap,
                            lifetime: source.lifetime.clone(),
                            legacy_business: source.legacy_business,
                        })
                })
                .collect(),
        }
    }

    /// Withdrawal rejects pending dispatch and cancels independent plugin calls.
    /// Scoped registrations drain during quiesce; the runtime owns draining the
    /// shipped sources, including its data-clear exclusion of the initiating run.
    pub fn close(&self) {
        let mut catalog = self.inner.lock().expect("tool catalog mutex poisoned");
        catalog.closed = true;
        catalog.revision = catalog.revision.saturating_add(1);
        for source in &catalog.sources {
            source.lifetime.stop_accepting();
        }
        let retired = std::mem::take(&mut catalog.sources);
        drop(catalog);
        for source in retired {
            source.lifetime.close();
        }
    }
}

/// Descriptions, activation and dispatch share these exact registrations. A
/// removed definition never silently dispatches through a same-name replacement.
#[derive(Clone)]
pub struct ToolCatalogSnapshot {
    pub revision: u64,
    tools: Vec<RegisteredTool>,
}

impl ToolCatalogSnapshot {
    pub fn contributed_descriptors(&self) -> Vec<ToolDescriptor> {
        self.tools
            .iter()
            .filter(|tool| !tool.legacy_business && tool.lifetime.accepting())
            .map(|tool| tool.descriptor.clone())
            .collect()
    }

    pub fn descriptors(&self) -> Vec<ToolDescriptor> {
        self.tools
            .iter()
            .filter(|tool| tool.lifetime.accepting())
            .map(|tool| tool.descriptor.clone())
            .collect()
    }

    pub fn names(&self) -> HashSet<String> {
        self.tools
            .iter()
            .filter(|tool| tool.lifetime.accepting())
            .map(|tool| tool.descriptor.name.clone())
            .collect()
    }

    pub fn bootstrap_names(&self) -> HashSet<String> {
        self.tools
            .iter()
            .filter(|tool| tool.bootstrap && tool.lifetime.accepting())
            .map(|tool| tool.descriptor.name.clone())
            .collect()
    }

    pub fn execute(
        &self,
        call: ToolCall,
        context: Arc<dyn ToolRunContext>,
    ) -> BoxFuture<'static, Result<Value, String>> {
        let registration = self
            .tools
            .iter()
            .find(|tool| tool.descriptor.name == call.name)
            .cloned();
        Box::pin(async move {
            let cancelled = call.cancellation.is_cancelled();
            // Count admission before upgrading, so every strong handler is
            // retained through settlement and released before signalling drain.
            let admitted = if cancelled {
                None
            } else {
                registration.as_ref().and_then(|registration| {
                    let lease = registration.lifetime.acquire(&call.cancellation)?;
                    let handler = registration.handler.upgrade()?;
                    Some(AdmittedTool { handler, lease })
                })
            };
            let outcome = if cancelled {
                Err(RuntimeError::Cancelled("工具调用已取消".into()))
            } else {
                match admitted.as_ref() {
                    Some(admitted) if admitted.lease.cancellation().is_cancelled() => {
                        Err(RuntimeError::Cancelled("工具调用已取消".into()))
                    }
                    Some(admitted) => {
                        let mut invocation = call.clone();
                        invocation.cancellation = admitted.lease.cancellation().clone();
                        admitted.handler.execute(invocation, context.clone()).await
                    }
                    None => Err(RuntimeError::Invalid(format!(
                        "工具已不可用，请重新发现能力：{}",
                        call.name
                    ))),
                }
            };
            let result = context.settle(call, outcome).await;
            drop(admitted);
            result
        })
    }
}
