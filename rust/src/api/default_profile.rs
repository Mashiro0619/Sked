//! The shipped composition owns the existing implementations through plugins.
//! Domain APIs stay on their current implementations while their providers are
//! split into narrower contracts in the following migration steps.

use super::{contracts::*, descriptors, host::BridgeHost, runtime_event};
use crate::{
    model_client::{
        RigModelClient,
        offline::{ScriptedReply, ScriptedTransport},
    },
    plugins::{
        AgentProfile, Plugin, PluginContainer, PluginContext, PluginDescriptor, PluginError,
        PluginSpec, ServiceDefinition,
    },
    runtime::{RuntimeManager, ToolDescriptor},
    storage::{StorageHandle, StorageWorker},
};
use async_trait::async_trait;
use serde_json::{Value, json};
use std::{collections::HashSet, path::PathBuf, sync::Arc};
use tokio::sync::{broadcast, watch};
use tokio_util::sync::CancellationToken;

const STORAGE: ServiceDefinition<StorageHandle> = ServiceDefinition::new("sked.storage", 1);
const HOST: ServiceDefinition<BridgeHost> = ServiceDefinition::new("sked.business-host", 1);
const MODEL: ServiceDefinition<RigModelClient> = ServiceDefinition::new("sked.model", 1);
const RUNTIME: ServiceDefinition<RuntimeManager> = ServiceDefinition::new("sked.runtime", 1);
const EVENT_RELAY: ServiceDefinition<()> = ServiceDefinition::new("sked.runtime-events", 1);

/// A clear operation can reach shutdown after ordinary shutdown has begun.
/// Its registration must wake the drain already waiting on that same run.
type ShutdownExclusions = watch::Sender<HashSet<String>>;

pub(super) struct DefaultAgentProfile {
    plugins: PluginContainer,
    shutdown_exclusions: ShutdownExclusions,
    pub(super) manager: RuntimeManager,
    pub(super) host: BridgeHost,
    pub(super) events: broadcast::Sender<AgentEvent>,
    pub(super) events_closed: CancellationToken,
}

impl DefaultAgentProfile {
    pub(super) async fn open(config: CoreConfig) -> Result<Self, String> {
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
                    Arc::new(StoragePlugin),
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
                    Arc::new(ModelPlugin { offline_replies }),
                    Value::Null,
                ),
                PluginSpec::new(
                    "default.runtime",
                    Arc::new(RuntimePlugin {
                        tools,
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
                MODEL.key(),
                RUNTIME.key(),
                EVENT_RELAY.key(),
            ],
        };
        let plugins = PluginContainer::assemble(profile)
            .await
            .map_err(|error| error.to_string())?;
        // The private default profile is fixed for this core's lifetime. The
        // runtime plugin retains provider dependencies; bridge methods keep
        // their existing handles rather than a lease that could block shutdown.
        let exports = (|| -> Result<_, PluginError> {
            let manager = plugins.lease(RUNTIME)?;
            let host = plugins.lease(HOST)?;
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

struct StoragePlugin;

#[async_trait]
impl Plugin for StoragePlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.storage",
            contract_version: 1,
            provides: vec![STORAGE.key()],
            dependencies: vec![],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let root = context
            .config()
            .get("directory")
            .and_then(Value::as_str)
            .ok_or_else(|| PluginError::new("Storage provider requires its data directory"))?;
        let root = PathBuf::from(root);
        let worker = tokio::task::spawn_blocking(move || StorageWorker::open(root))
            .await
            .map_err(|error| PluginError::new(error.to_string()))?
            .map_err(|error| PluginError::new(error.to_string()))?;
        let handle = worker.handle();
        context.on_dispose(move || {
            Box::pin(async move {
                tokio::task::spawn_blocking(move || worker.shutdown())
                    .await
                    .map_err(|error| PluginError::new(error.to_string()))?
                    .map_err(|error| PluginError::new(error.to_string()))
            })
        })?;
        context.provide(STORAGE, handle)
    }
}

struct HostPlugin {
    events: broadcast::Sender<AgentEvent>,
}

#[async_trait]
impl Plugin for HostPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.business-host",
            contract_version: 1,
            provides: vec![HOST.key()],
            dependencies: vec![],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        context.provide(HOST, BridgeHost::new(self.events.clone()))
    }
}

struct ModelPlugin {
    offline_replies: Option<Vec<ScriptedReply>>,
}

#[async_trait]
impl Plugin for ModelPlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.model",
            contract_version: 1,
            provides: vec![MODEL.key()],
            dependencies: vec![],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let client = match &self.offline_replies {
            Some(replies) => RigModelClient::with_transport(rig::http_client::DynHttpClient::new(
                ScriptedTransport::new(replies.clone()),
            )),
            None => RigModelClient::default(),
        };
        context.provide(MODEL, client)
    }
}

struct RuntimePlugin {
    tools: Vec<ToolDescriptor>,
    preamble: String,
    generate_titles: bool,
    shutdown_exclusions: ShutdownExclusions,
}

#[async_trait]
impl Plugin for RuntimePlugin {
    fn descriptor(&self) -> PluginDescriptor {
        PluginDescriptor {
            id: "sked.default.runtime",
            contract_version: 1,
            provides: vec![RUNTIME.key()],
            dependencies: vec![STORAGE.key(), HOST.key(), MODEL.key()],
        }
    }

    async fn setup(&self, context: PluginContext) -> Result<(), PluginError> {
        let storage = context.require(STORAGE)?;
        let host = context.require(HOST)?;
        let model = context.require(MODEL)?;
        let manager = RuntimeManager::new(
            (*storage).clone(),
            Arc::new((*host).clone()),
            (*model).clone(),
        );
        let draining = manager.clone();
        let exclusions = self.shutdown_exclusions.subscribe();
        context.on_quiesce(move || {
            Box::pin(async move {
                draining.shutdown_with_exclusions(exclusions).await;
                Ok(())
            })
        })?;
        manager.set_tools(self.tools.clone());
        manager.set_preamble(self.preamble.clone());
        manager.set_title_generation_enabled(self.generate_titles);
        manager
            .recover_interrupted()
            .await
            .map_err(|error| PluginError::new(error.to_string()))?;
        context.provide(RUNTIME, manager)
    }
}

struct EventRelayPlugin {
    events: broadcast::Sender<AgentEvent>,
    events_closed: CancellationToken,
}

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
