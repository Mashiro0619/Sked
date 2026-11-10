//! Declarative keys for compiled Flutter renderers, owned by a plugin instance.
//! Definitions are staged with services and never contain executable UI code.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UiContributionSlot {
    ToolResult,
    Settings,
    InspectorSection,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UiContributionDefinition {
    pub id: String,
    pub slot: UiContributionSlot,
    pub renderer_id: String,
    pub order: i32,
}

impl UiContributionDefinition {
    pub fn builtin(slot: UiContributionSlot, renderer_id: &str, order: i32) -> Self {
        Self {
            id: renderer_id.into(),
            slot,
            renderer_id: renderer_id.into(),
            order,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UiContributionOwner {
    pub instance_id: String,
    pub generation: u64,
    pub contributions: Vec<UiContributionDefinition>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UiContributionSnapshot {
    pub contract_version: u32,
    pub revision: u64,
    pub owners: Vec<UiContributionOwner>,
}

impl Default for UiContributionSnapshot {
    fn default() -> Self {
        Self {
            contract_version: 1,
            revision: 0,
            owners: Vec::new(),
        }
    }
}
