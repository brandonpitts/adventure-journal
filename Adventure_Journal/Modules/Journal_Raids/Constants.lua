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
    DESCRIPTION = "Explore raids on WoW Forever: raid sizes, boss encounters, and item drops.",
    TAB_ORDER = 20,
    ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}
