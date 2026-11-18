-- ============================================================================
-- Journal_Quests - Constants.lua
-- Single source of truth for Quests plugin metadata, assets, and dimensions.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Quests or {} ; parent.Quests = ns

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
    PLUGIN_ID = "quests",
    TITLE = "Quests",
    VERSION = "0.0.0",
    LAST_UPDATED = "2026-11-13",
    DESCRIPTION = "Track dungeon questlines, raid attunement chains, class quests, and notable reward paths across Azeroth.",
    API_VERSION = 1,
    TAB_ORDER = 40,

    CARD = {
        WIDTH = 460,
        HEIGHT = 200,
        ICON_BOX_SIZE = 54,
        DIVIDER_WIDTH = 280,
    },

    ASSETS = {
        ICON = "Interface\\Icons\\INV_Misc_Book_08",
        WHITE_8X8 = "Interface\\Buttons\\WHITE8X8",
    },

    COPY = {
        HEADING = "Quests — Under Construction",
        SUBTITLE = "The Quest & Attunement Guide is currently under construction.",
    },
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}

