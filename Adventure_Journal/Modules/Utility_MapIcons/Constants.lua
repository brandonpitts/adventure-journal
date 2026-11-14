-- ============================================================================
-- Utility_MapIcons - Constants.lua
-- Configuration, textures, and dimensions for Adventure Journal map pins.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals
-- ----------------------------------------------------------------------------
local _G = _G

-- ----------------------------------------------------------------------------
-- 2. Constants Definition
-- ----------------------------------------------------------------------------
local Constants = {
    ADDON_NAME = addonName,
    MODULE_ID = "map_icons",
    TITLE = "Map Icons",
    VERSION = "0.4.0",

    -- Native Blizzard Atlas Identifiers
    ATLAS = {
        DUNGEON = "Dungeon",
        RAID = "Raid",
    },

    -- Pin dimensions on the World Map canvas
    PIN = {
        SIZE = 42,
        HIT_SCALE = 0.8,
        POI_SCALE = 0.70,
        FRAME_STRATA = "HIGH",
        FRAME_LEVEL = 120,
    },

    -- Retail-style Tooltip Formatting
    TOOLTIP = {
        TITLE_COLOR = { 1.0, 1.0, 1.0 },
        SUBTITLE_COLOR = { 1.0, 0.82, 0.0 }, -- Gold ("Dungeon")
        ACTION_COLOR = { 0.0, 1.0, 0.0 },   -- Bright Green ("<Click to open Adventure Journal>")
        ACTION_TEXT = "<Click to open Adventure Journal>",
    },
}

-- ----------------------------------------------------------------------------
-- 3. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.MapIconsConstants = Constants
