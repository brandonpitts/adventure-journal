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
    VERSION = "0.6.0",

    -- Native Blizzard Atlas Identifiers
    ATLAS = {
        DUNGEON = "Dungeon",
        RAID = "Raid",
        TAXI_NEUTRAL = "TaxiNode_Neutral",
        TAXI_ALLIANCE = "TaxiNode_Alliance",
        TAXI_HORDE = "TaxiNode_Horde",
    },

    -- Flight path colors
    FLIGHT_COLORS = {
        ALLIANCE = { 0.25, 0.60, 1.00, "4099ff" }, -- Blue
        HORDE = { 1.00, 0.25, 0.25, "ff4040" },    -- Red
        NEUTRAL = { 1.00, 0.82, 0.00, "ffd100" },  -- Gold
    },

    -- Pin dimensions on the World Map canvas
    PIN = {
        SIZE = 42,
        FLIGHT_SIZE = 30,
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
