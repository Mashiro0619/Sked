//! Model execution contracts shared by the runtime and model plugins.
//! Providers own protocol execution and the tool loop; the service filters
//! credential-bearing output before it reaches runtime events or persistence.

mod contracts;
mod provider;
mod service;

pub use contracts::{ModelProvider, ModelRequest};
pub use provider::DefaultModelPlugin;
pub use service::{MODEL_SERVICE, ModelService};
