use std::sync::{Arc, Mutex, Weak};

use tokio_util::{sync::CancellationToken, task::TaskTracker};

use super::{
    ExecutionCapabilities, ExecutionError, ExecutionErrorCode, ExecutionIdentity,
    ExecutionProvider, ExecutionProviderIdentity, ExecutionReceipt, ExecutionSpec,
    PreparedExecution, Result,
    prepared::{PreparedInner, normalize_receipt, unknown_receipt},
    validation,
};
use crate::plugins::ServiceDefinition;

pub const EXECUTION_SERVICE: ServiceDefinition<ExecutionService> =
    ServiceDefinition::new("sked.execution", 1);

pub(super) struct Admission {
    pub accepting: Mutex<bool>,
    pub cancellation: CancellationToken,
    pub tasks: TaskTracker,
    pub prepared: Mutex<Vec<Weak<PreparedInner>>>,
}

/// Platform plugins construct this service with their actual provider and
/// register shutdown as quiescence before releasing interpreter resources.
/// No default provider or executable capability is installed by this module.
#[derive(Clone)]
pub struct ExecutionService {
    provider: Arc<dyn ExecutionProvider>,
    identity: ExecutionProviderIdentity,
    admission: Arc<Admission>,
}

impl ExecutionService {
    pub fn new(provider: Arc<dyn ExecutionProvider>) -> Self {
        let identity = provider.identity();
        Self {
            provider,
            identity,
            admission: Arc::new(Admission {
                accepting: Mutex::new(true),
                cancellation: CancellationToken::new(),
                tasks: TaskTracker::new(),
                prepared: Mutex::new(Vec::new()),
            }),
        }
    }

    pub fn identity(&self) -> ExecutionProviderIdentity {
        self.identity.clone()
    }

    pub fn capabilities(&self) -> ExecutionCapabilities {
        if *self
            .admission
            .accepting
            .lock()
            .expect("execution admission mutex poisoned")
        {
            self.provider.capabilities()
        } else {
            ExecutionCapabilities::default()
        }
    }

    pub async fn prepare(&self, specification: ExecutionSpec) -> Result<PreparedExecution> {
        let _tracked = {
            let accepting = self
                .admission
                .accepting
                .lock()
                .expect("execution admission mutex poisoned");
            if !*accepting {
                return Err(unavailable());
            }
            self.admission.tasks.token()
        };
        let capabilities = self.provider.capabilities();
        validation::validate_request(&specification, &capabilities)?;
        let mut prepared = self
            .provider
            .prepare(
                specification.clone(),
                self.admission.cancellation.child_token(),
            )
            .await?;
        validation::freeze(
            &specification,
            &mut prepared.specification,
            &self.identity,
            &capabilities,
        )?;
        let accepting = self
            .admission
            .accepting
            .lock()
            .expect("execution admission mutex poisoned");
        if !*accepting {
            return Err(unavailable());
        }
        Ok(PreparedExecution::new(
            prepared.specification,
            prepared.backend,
            self.admission.clone(),
        ))
    }

    /// Recovery queries old evidence through the same provider family. An
    /// instance generation change cannot turn an old lookup into a fresh run.
    pub async fn inspect(&self, identity: ExecutionIdentity) -> Result<ExecutionReceipt> {
        validation::validate_identity(&identity)?;
        if identity.provider.provider_id != self.identity.provider_id
            || identity.provider.contract_version != self.identity.contract_version
        {
            return Err(ExecutionError::new(
                ExecutionErrorCode::ProviderUnavailable,
                "The original execution provider is unavailable for inspection.",
            ));
        }
        let _tracked = {
            let accepting = self
                .admission
                .accepting
                .lock()
                .expect("execution admission mutex poisoned");
            if !*accepting {
                return Err(unavailable());
            }
            self.admission.tasks.token()
        };
        Ok(
            match self
                .provider
                .inspect(identity.clone(), self.admission.cancellation.child_token())
                .await
            {
                Ok(receipt) => normalize_receipt(receipt, &identity, None, None, false),
                Err(error) => unknown_receipt(&identity, None, None, error),
            },
        )
    }

    pub async fn shutdown(&self) {
        let (prepared, cleanup) = {
            let mut accepting = self
                .admission
                .accepting
                .lock()
                .expect("execution admission mutex poisoned");
            *accepting = false;
            // Concurrent shutdown callers must also wait for the synchronous
            // release of unadmitted backends, not just admitted drivers.
            let cleanup = self.admission.tasks.token();
            self.admission.tasks.close();
            let prepared = self
                .admission
                .prepared
                .lock()
                .expect("prepared executions mutex poisoned")
                .drain(..)
                .filter_map(|entry| entry.upgrade())
                .collect::<Vec<_>>();
            (prepared, cleanup)
        };
        self.admission.cancellation.cancel();
        // Release unused frozen backend resources without holding admission or
        // state locks. Running backends remain owned by their tracked drivers.
        for prepared in prepared {
            prepared.discard_prepared();
        }
        drop(cleanup);
        self.admission.tasks.wait().await;
    }
}

fn unavailable() -> ExecutionError {
    ExecutionError::new(
        ExecutionErrorCode::ProviderUnavailable,
        "The execution provider is closing.",
    )
}
