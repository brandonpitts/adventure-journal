-- ============================================================================
-- Journal_Professions - Constants.lua
-- Single source of truth for Professions plugin metadata, assets, and dimensions.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Professions or {} ; parent.Professions = ns

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
    PLUGIN_ID = "professions",
    TITLE = "Professions",
    VERSION = "0.0.0",
    LAST_UPDATED = "2026-11-13",
    DESCRIPTION = "Browse primary and secondary professions, recipe and schematic sources, trainer locations, and crafting reagent breakdowns.",
    API_VERSION = 1,
    TAB_ORDER = 30,

    CARD = {
        WIDTH = 460,
        HEIGHT = 200,
        ICON_BOX_SIZE = 54,
        DIVIDER_WIDTH = 280,
    },

    ASSETS = {
        ICON = "Interface\\Icons\\Trade_BlackSmithing",
        WHITE_8X8 = "Interface\\Buttons\\WHITE8X8",
    },

    COPY = {
        HEADING = "Professions — Under Construction",
        SUBTITLE = "The Professions & Recipe Guide is currently under construction.",
    },
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}

