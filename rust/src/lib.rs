//! Application-owned Sked Agent core.
//!
//! Flutter owns the UI and the existing domain host. The native core owns
//! model execution, conversation state, and the Agent's local stores.

pub mod api;
pub mod context;
mod frb_generated;
pub mod model_client;
pub mod plugins;
pub mod runtime;
pub mod storage;

#[cfg(target_os = "android")]
mod android;
