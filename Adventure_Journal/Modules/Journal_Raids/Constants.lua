-- ============================================================================
-- Journal_Raids - Constants.lua
-- Single source of truth for Raids module metadata, assets, and dimensions.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Raids or {} ; parent.Raids = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
-- (None required for static constants)

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required for static constants)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local Constants = {
    ADDON_NAME = addonName,
    MODULE_ID = "raids",
    TITLE = "Raids",
    DESCRIPTION = "Prepare for 10, 20, and 40-player raid tiers with multi-phase encounter strategies, boss abilities, and tier set loot tables.",
    TAB_ORDER = 20,

    CARD = {
        WIDTH = 460,
        HEIGHT = 200,
        ICON_BOX_SIZE = 54,
        DIVIDER_WIDTH = 280,
    },

    ASSETS = {
        ICON = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        WHITE_8X8 = "Interface\\Buttons\\WHITE8X8",
    },

    COPY = {
        HEADING = "Raids — Under Construction",
        SUBTITLE = "The 10/20/40-player Raid Guide is currently under construction.",
    },
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}

