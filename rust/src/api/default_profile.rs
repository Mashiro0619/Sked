//! The shipped composition owns the existing implementations through plugins.
//! Domain APIs stay on their current implementations while their providers are
//! split into narrower contracts in the following migration steps.

use super::{contracts::*, descriptors, host::BridgeHost, runtime_event};
use crate::{
    context::{CONTEXT_SERVICE as CONTEXT, DefaultContextPlugin},
    execution::{EXECUTION_SERVICE as EXECUTION, ExecutionService},
    files::{FILES_SERVICE as FILES, FileService},
    model_client::{
        offline::ScriptedReply,
        services::{DefaultModelPlugin, MODEL_SERVICE as MODEL},
    },
    plugins::{
        AgentProfile, Plugin, PluginContainer, PluginContext, PluginDescriptor, PluginError,
        PluginSpec, ServiceDefinition, ServiceLease, UiContributionDefinition, UiContributionSlot,
    },
    runtime::{
        RuntimeManager,
        services::{RUNTIME_SERVICE as RUNTIME, RuntimeService},
    },
    storage::services::{DefaultPersistencePlugin, PERSISTENCE_SERVICE as STORAGE},
    tooling::{
        BUSINESS_HOST_SERVICE as HOST, BusinessHostService, DefaultToolPlugin,
        TOOL_SERVICE as TOOLS,
    },
};
use async_trait::async_trait;
use serde_json::{Value, json};
use std::{collections::HashSet, sync::Arc};
use tokio::sync::{broadcast, watch};
use tokio_util::sync::CancellationToken;

const BRIDGE: ServiceDefinition<BridgeHost> =
    ServiceDefinition::new("sked.business-host.bridge", 1);
const EVENT_RELAY: ServiceDefinition<()> = ServiceDefinition::new("sked.runtime-events", 1);

/// A clear operation can reach shutdown after ordinary shutdown has begun.
/// Its registration must wake the drain already waiting on that same run.
type ShutdownExclusions = watch::Sender<HashSet<String>>;

pub(super) struct DefaultAgentProfile {
    plugins: PluginContainer,
    shutdown_exclusions: ShutdownExclusions,
    pub(super) manager: RuntimeService,
    pub(super) host: BridgeHost,
    pub(super) events: broadcast::Sender<AgentEvent>,
    pub(super) events_closed: CancellationToken,
}

impl DefaultAgentProfile {
    pub(super) async fn open(config: CoreConfig) -> Result<Self, String> {
        #[cfg(any(windows, target_os = "android"))]
        let file_root = std::path::PathBuf::from(&config.data_directory).join("files");
        let tools = descriptors(config.tools)?;
        let (events, _) = broadcast::channel(2048);
        let events_closed = CancellationToken::new();
        let (shutdown_exclusions, _) = watch::channel(HashSet::new());
        let offline_replies = config.offline_replies.map(|replies| {
            replies
                .into_iter()
                .map(|reply| ScriptedReply {
                    status: reply.status,
                    content_type: reply.content_type,
                    body: reply.body,
                })
                .collect()
        });
        let profile = AgentProfile {
            id: "sked.default".into(),
            plugins: vec![
                PluginSpec::new(
                    "default.storage",
                    Arc::new(DefaultPersistencePlugin),
                    json!({"directory": config.data_directory}),
                ),
                PluginSpec::new(
                    "default.business-host",
                    Arc::new(HostPlugin {
                        events: events.clone(),
                    }),
                    Value::Null,
                ),
                PluginSpec::new(
                    "default.model",
                    Arc::new(DefaultModelPlugin::new(offline_replies)),
                    Value::Null,
                ),
                PluginSpec::new(
                    "default.context",
                    Arc::new(DefaultContextPlugin),
                    Value::Null,
                ),
                PluginSpec::new(
                    "default.tools",
                    Arc::new(DefaultToolPlugin::new(tools)),
                    Value::Null,
                ),
                PluginSpec::new(
                    "default.runtime",
                    Arc::new(RuntimePlugin {
                        preamble: config.preamble,
                        generate_titles: config.generate_titles,
                        shutdown_exclusions: shutdown_exclusions.clone(),
                    }),
                    Value::Null,
                ),
                PluginSpec::new(
                    "default.runtime-events",
                    Arc::new(EventRelayPlugin {
                        events: events.clone(),
                        events_closed: events_closed.clone(),
                    }),
                    Value::Null,
                ),
            ],
            required_services: vec![
                STORAGE.key(),
                HOST.key(),
                BRIDGE.key(),
                TOOLS.key(),
                MODEL.key(),
                CONTEXT.key(),
                RUNTIME.key(),
                EVENT_RELAY.key(),
            ],
        };
        #[cfg(any(windows, target_os = "android"))]
        let profile = {
            let mut profile = profile;
            profile.plugins.push(PluginSpec::new(
                "default.files",
                Arc::new(FilePlugin { root: file_root }),
                Value::Null,
            ));
            profile.required_services.push(FILES.key());
            profile
        };
        let plugins = PluginContainer::assemble(profile)
            .await
            .map_err(|error| error.to_string())?;
        // The private default profile is fixed for this core's lifetime. The
        // runtime plugin retains provider dependencies; bridge methods keep
        // their existing handles rather than a lease that could block shutdown.
        let exports = (|| -> Result<_, PluginError> {
            let manager = plugins.lease(RUNTIME)?;
            let host = plugins.lease(BRIDGE)?;
            Ok(((*manager).clone(), (*host).clone()))
        })();
        let (manager, host) = match exports {
            Ok(exports) => exports,
            Err(error) => {
                return match plugins.shutdown().await {
                    Ok(()) => Err(error.to_string()),
                    Err(cleanup) => Err(format!("{error}; cleanup: {cleanup}")),
                };
            }
        };
        Ok(Self {
            plugins,
            shutdown_exclusions,
            manager,
            host,
            events,
            events_closed,
        })
    }

    pub(super) fn ui_contributions(
        &self,
    ) -> watch::Receiver<crate::plugins::UiContributionSnapshot> {
        self.plugins.ui_contributions()
    }

    /// Execution is optional until a real platform provider is installed.
    pub(super) fn execution_service(&self) -> Option<ServiceLease<ExecutionService>> {
        self.plugins.lease(EXECUTION).ok()
    }

    pub(super) fn file_service(&self) -> Option<ServiceLease<FileService>> {
        self.plugins.lease(FILES).ok()
    }

    pub(super) async fn shutdown(&self, except: Option<String>) -> Result<(), String> {
        if let Some(id) = except {
            self.shutdown_exclusions.send_modify(|excluded| {
                excluded.insert(id);
            });
        }
        self.plugins
            .shutdown()
            .await
            .map_err(|error| error.to_string())
    }
}

#[cfg(any(windows, target_os = "android"))]
struct FilePlugin {
    root: std::path::PathBuf,
}

#[cfg(any(windows, target_os = "android"))]
#[flutter_rust_bridge::frb(ignore)]
#[async_trait]
impl Plugin for FilePlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: if cfg!(windows) {
                "sked.windows.files"
            } else {
                "sked.android.files"
            },
            contract_version: 1,
            provides: vec![FILES.key()],
            dependencies: vec![STORAGE.key()],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let _storage = context.require(STORAGE)?;
        let service = FileService::open(self.root.clone())
            .await
            .map_err(|error| PluginError::new(error.to_string()))?;
        let draining = service.clone();
        context.on_quiesce(move || {
            Box::pin(async move {
                draining
                    .shutdown()
                    .await
                    .map_err(|error| PluginError::new(error.to_string()))
            })
        })?;
        context.provide(FILES, service)
    }
}

struct HostPlugin {
    events: broadcast::Sender<AgentEvent>,
}

#[flutter_rust_bridge::frb(ignore)]
#[async_trait]
impl Plugin for HostPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.business-host",
            contract_version: 1,
            provides: vec![HOST.key(), BRIDGE.key()],
            dependencies: vec![],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let bridge = BridgeHost::new(self.events.clone());
        context.provide(HOST, BusinessHostService::new(Arc::new(bridge.clone())))?;
        context.provide(BRIDGE, bridge)
    }
}

struct RuntimePlugin {
    preamble: String,
    generate_titles: bool,
    shutdown_exclusions: ShutdownExclusions,
}

#[flutter_rust_bridge::frb(ignore)]
#[async_trait]
impl Plugin for RuntimePlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.runtime",
            contract_version: 1,
            provides: vec![RUNTIME.key()],
            dependencies: vec![
                STORAGE.key(),
                HOST.key(),
                MODEL.key(),
                CONTEXT.key(),
                TOOLS.key(),
            ],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let storage = context.require(STORAGE)?;
        let host = context.require(HOST)?;
        let model = context.require(MODEL)?;
        let context_service = context.require(CONTEXT)?;
        let tools = context.require(TOOLS)?;
        let manager = RuntimeService::from(RuntimeManager::new_with_services(
            (*storage).clone(),
            (*host).clone(),
            (*model).clone(),
            (*context_service).clone(),
            (*tools).clone(),
        ));
        let draining = manager.clone();
        let exclusions = self.shutdown_exclusions.subscribe();
        context.on_quiesce(move || {
            Box::pin(async move {
                draining.shutdown_with_exclusions(exclusions).await;
                Ok(())
            })
        })?;
        manager.set_preamble(self.preamble.clone());
        manager.set_title_generation_enabled(self.generate_titles);
        manager
            .recover_interrupted()
            .await
            .map_err(|error| PluginError::new(error.to_string()))?;
        for contribution in [
            UiContributionDefinition::builtin(
                UiContributionSlot::ToolResult,
                "sked.tool.operation",
                0,
            ),
            UiContributionDefinition::builtin(
                UiContributionSlot::InspectorSection,
                "sked.inspector.changes",
                0,
            ),
            UiContributionDefinition::builtin(
                UiContributionSlot::InspectorSection,
                "sked.inspector.plan",
                10,
            ),
        ] {
            context.contribute_ui(contribution)?;
        }
        context.provide(RUNTIME, manager)
    }
}

struct EventRelayPlugin {
    events: broadcast::Sender<AgentEvent>,
    events_closed: CancellationToken,
}

#[flutter_rust_bridge::frb(ignore)]
#[async_trait]
impl Plugin for EventRelayPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.runtime-events",
            contract_version: 1,
            provides: vec![EVENT_RELAY.key()],
            dependencies: vec![RUNTIME.key()],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let runtime = context.require(RUNTIME)?;
        let mut source = runtime.subscribe();
        let target = self.events.clone();
        let stop = CancellationToken::new();
        let stopped = stop.clone();
        let forward = tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = stopped.cancelled() => {
                        loop {
                            match source.try_recv() {
                                Ok(event) => { let _ = target.send(runtime_event(event)); }
                                Err(broadcast::error::TryRecvError::Lagged(_)) => {
                                    let _ = target.send(AgentEvent::empty(EventKind::Resync, String::new()));
                                }
                                Err(broadcast::error::TryRecvError::Empty | broadcast::error::TryRecvError::Closed) => break,
                            }
                        }
                        break;
                    },
                    event = source.recv() => match event {
                        Ok(event) => { let _ = target.send(runtime_event(event)); }
                        Err(broadcast::error::RecvError::Lagged(_)) => {
                            let _ = target.send(AgentEvent::empty(EventKind::Resync, String::new()));
                        }
                        Err(broadcast::error::RecvError::Closed) => break,
                    }
                }
            }
        });
        let events_closed = self.events_closed.clone();
        context.on_dispose(move || {
            Box::pin(async move {
                stop.cancel();
                let result = forward
                    .await
                    .map_err(|error| PluginError::new(error.to_string()));
                events_closed.cancel();
                result
            })
        })?;
        context.provide(EVENT_RELAY, ())
    }
}
