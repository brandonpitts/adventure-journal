-- ============================================================================
-- Journal_Quests - Constants.lua
-- Quests module metadata.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Quests or {} ; parent.Quests = ns

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Constants = {
    ADDON_NAME = addonName,
    MODULE_ID = "quests",
    TITLE = "Quests",
    DESCRIPTION = "Quest chains, attunements, and rewards. Under construction.",
    TAB_ORDER = 30,
    ICON = "Interface\\Icons\\INV_Misc_Book_08",
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}
