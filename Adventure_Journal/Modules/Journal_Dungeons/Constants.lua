-- ============================================================================
-- Journal_Dungeons - Constants.lua
-- Dungeons module metadata. The page's sizes, text and sections are in the
-- dungeon template (Template.lua, extending Core/Templates/Instance.lua).
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Constants = {
    ADDON_NAME = addonName,
    MODULE_ID = "dungeons",
    TITLE = "Dungeons",
    DESCRIPTION = "Explore 5-player dungeons across Classic and WoW Forever, including level brackets, boss encounters, and item drops.",
    TAB_ORDER = 10,
    ICON = "Interface\\Icons\\INV_Misc_Key_03",
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}
