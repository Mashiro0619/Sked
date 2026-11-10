//! Typed renderer declarations. Flutter maps these keys to compiled widgets.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UiContributionSlot {
    ToolResult,
    Settings,
    InspectorSection,
}

#[derive(Debug, Clone)]
pub struct UiContributionDefinition {
    pub id: String,
    pub slot: UiContributionSlot,
    pub renderer_id: String,
    pub order: i32,
}

#[derive(Debug, Clone)]
pub struct UiContributionOwner {
    pub instance_id: String,
    pub generation: u64,
    pub contributions: Vec<UiContributionDefinition>,
}

#[derive(Debug, Clone)]
pub struct UiContributionSnapshot {
    pub contract_version: u32,
    pub revision: u64,
    pub owners: Vec<UiContributionOwner>,
}

impl From<crate::plugins::UiContributionSnapshot> for UiContributionSnapshot {
    fn from(value: crate::plugins::UiContributionSnapshot) -> Self {
        Self {
            contract_version: value.contract_version,
            revision: value.revision,
            owners: value
                .owners
                .into_iter()
                .map(|owner| UiContributionOwner {
                    instance_id: owner.instance_id,
                    generation: owner.generation,
                    contributions: owner
                        .contributions
                        .into_iter()
                        .map(|entry| UiContributionDefinition {
                            id: entry.id,
                            slot: match entry.slot {
                                crate::plugins::UiContributionSlot::ToolResult => {
                                    UiContributionSlot::ToolResult
                                }
                                crate::plugins::UiContributionSlot::Settings => {
                                    UiContributionSlot::Settings
                                }
                                crate::plugins::UiContributionSlot::InspectorSection => {
                                    UiContributionSlot::InspectorSection
                                }
                            },
                            renderer_id: entry.renderer_id,
                            order: entry.order,
                        })
                        .collect(),
                })
                .collect(),
        }
    }
}
