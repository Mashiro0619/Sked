use tokio::sync::watch;
use tokio_util::sync::CancellationToken;

use super::{AgentCore, ui_contracts::UiContributionSnapshot};
use crate::frb_generated::StreamSink;

impl AgentCore {
    /// The caller owns this subscription and closes it when unsubscribing.
    /// The handle contains value snapshots and cancellation signals only.
    #[flutter_rust_bridge::frb(sync)]
    pub fn open_ui_contributions(&self) -> UiContributionSubscription {
        UiContributionSubscription {
            updates: self.profile.ui_contributions(),
            core_closed: self.closed.clone(),
            cancelled: CancellationToken::new(),
        }
    }
}

/// Independent ownership lets Dart cancellation release a waiting watcher
/// without retaining AgentCore or waiting for another plugin-state change.
#[flutter_rust_bridge::frb(opaque)]
pub struct UiContributionSubscription {
    updates: watch::Receiver<crate::plugins::UiContributionSnapshot>,
    core_closed: CancellationToken,
    cancelled: CancellationToken,
}

impl UiContributionSubscription {
    /// Complete snapshots replace earlier declarations. Core shutdown sends
    /// its final snapshot; an explicit close stops this subscription directly.
    pub async fn watch(&self, sink: StreamSink<UiContributionSnapshot>) -> Result<(), String> {
        let mut updates = self.updates.clone();
        loop {
            if self.cancelled.is_cancelled() {
                return Ok(());
            }
            let snapshot = updates.borrow_and_update().clone();
            if sink.add(snapshot.into()).is_err() {
                return Ok(());
            }
            tokio::select! {
                _ = self.cancelled.cancelled() => return Ok(()),
                changed = updates.changed() => if changed.is_err() { return Ok(()); },
                _ = self.core_closed.cancelled() => {
                    let snapshot = updates.borrow_and_update().clone();
                    let _ = sink.add(snapshot.into());
                    return Ok(());
                },
            }
        }
    }

    /// Shared access allows close to wake watch while its opaque read guard
    /// is held. Closing repeatedly or before watch starts is harmless.
    #[flutter_rust_bridge::frb(sync)]
    pub fn close(&self) {
        self.cancelled.cancel();
    }
}
