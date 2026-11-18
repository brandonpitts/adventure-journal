-- ============================================================================
-- Utility_Quests - Constants.lua
-- Module-level constants, faction enumerations, and quest status identifiers.
-- ============================================================================
local addonName, parent = ...
parent.Utility_Quests = parent.Utility_Quests or {}
local ns = parent.Utility_Quests

ns.Constants = {
    FACTIONS = {
        ALLIANCE = "Alliance",
        HORDE = "Horde",
        BOTH = "Both",
    },
    TAGS = {
        SHAREABLE = "SHAREABLE",
        NOT_SHAREABLE = "NOT_SHAREABLE",
        CHAIN = "CHAIN",
    },
}
