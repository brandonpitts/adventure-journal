-- ============================================================================
-- Journal_Dungeons - Constants.lua
-- Single source of truth for Dungeons module metadata, assets, and dimensions.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local SOUNDKIT = SOUNDKIT

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required for static constants)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local Constants = {
    ADDON_NAME = addonName,
    MODULE_ID = "dungeons",
    TITLE = "Dungeons",
    DESCRIPTION = "Explore 5-player dungeons across Classic and WoW Forever, including level brackets, boss encounters, and item drops.",
    TAB_ORDER = 10,

    -- View 1: Scrollable Dungeon Tile Grid (782 x 424 canvas)
    GRID = {
        COLUMNS = 3,
        TILE_WIDTH = 234,
        TILE_HEIGHT = 67,
        GAP_X = 14,
        GAP_Y = 12,
        START_X = 6,
        START_Y = -8,
        SCROLL_TOP_Y = -8,
        SCROLL_BOTTOM_Y = 8,
        SCROLL_LEFT_X = 12,
        SCROLL_RIGHT_X = -28,
    },

    -- View 2: Open-Book Split View (Left Boss List + Right Detail Page)
    BOOK = {
        LEFT_WIDTH = 330,
        RIGHT_WIDTH = 426,
        BOSS_BTN_WIDTH = 268,
        BOSS_BTN_HEIGHT = 44,
        BOSS_BTN_GAP = 30,
        WING_BTN_HEIGHT = 67,
        WING_BTN_GAP = 18,
        BOSS_ICON_SIZE = 50,
        BOSS_RING_SIZE = 68,
        ART_FRAME_WIDTH = 376,
        ART_FRAME_HEIGHT = 186,
        RIGHT_CONTENT_WIDTH = 376,
    },

    ASSETS = {
        ICON = "Interface\\Icons\\INV_Misc_Key_03",
        WHITE_8X8 = "Interface\\Buttons\\WHITE8X8",
        BUTTON_HIGHLIGHT = "Interface\\Buttons\\UI-Common-MouseHilight",
        PARCHMENT_ATLAS = "Spellbook-Page-1",
        PARCHMENT_FALLBACK = "Interface\\Spellbook\\Spellbook-Page-1",
        WARNING_ICON = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew",
        MISSING_ICON = "Interface\\Icons\\INV_Misc_QuestionMark",
    },

    SOUNDS = {
        CLICK = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856,
        PAGE_TURN = (SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN) or 836,
    },
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.Data = ns.Data or {}
ns.UI = ns.UI or {}
