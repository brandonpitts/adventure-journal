-- ============================================================================
-- Journal_Raids - Constants.lua
-- Raids module metadata.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Raids or {} ; parent.Raids = ns

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Constants = {
    ADDON_NAME = addonName,
    MODULE_ID = "raids",
    TITLE = "Raids",
    DESCRIPTION = "Raid encounters, abilities, and loot. Under construction.",
    TAB_ORDER = 20,
    ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}
