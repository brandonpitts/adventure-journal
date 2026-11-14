-- ============================================================================
-- Journal_Base - Constants.lua
-- Single source of truth for dimensions, asset paths, sound kits, and defaults.
-- ============================================================================
local addonName, ns = ...

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
    TITLE = "Adventure Journal",
    VERSION = "0.4.0",
    PLUGIN_API_VERSION = 1,

    BINDING_HEADER = "JOURNALBASE",
    BINDING_ACTION = "JOURNALBASE_TOGGLE",

    CHAT_PREFIX = "|cffd9b34c[Adventure Journal]|r ",

    -- Exact rectangular EncounterJournal dimensions (800 x 496, ~1.61:1 ratio)
    WINDOW = {
        WIDTH = 800,
        HEIGHT = 496,
        HEADER_TOP_Y = -23,
        HEADER_HEIGHT = 33,
        CRUMB_TRACK_LEFT_X = 60,
        CRUMB_TRACK_RIGHT_X = -252,
        CRUMB_TRACK_HEIGHT = 28,
        NAVBAR_SCALE = 0.86,
        BREADCRUMB_BUTTON_HEIGHT = 24,
        SEARCH_WIDTH = 205,
        SEARCH_HEIGHT = 20,
        SEARCH_OFFSET_X = -34,
        GEAR_ICON_SIZE = 20,
        GEAR_OFFSET_X = -8,
        INSET_TOP_OFFSET = -58,
        INSET_BOTTOM_OFFSET = 6,
        INSET_LEFT_OFFSET = 4,
        INSET_RIGHT_OFFSET = -6,
        EMPTY_CARD_WIDTH = 460,
        EMPTY_CARD_HEIGHT = 200,
        DEFAULT_OFFSET_X = 0,
        DEFAULT_OFFSET_Y = 20,
    },

    MINIMAP = {
        SIZE = 31,
        ICON_SIZE = 20,
        BORDER_SIZE = 54,
        RADIUS_OFFSET = 8,
        DEFAULT_ANGLE = 225,
    },

    SETTINGS = {
        CATEGORY_NAME = "Adventure Journal",
        CATEGORY_ID = "JournalBase",
        KEYBIND_BUTTON_WIDTH = 170,
        KEYBIND_BUTTON_HEIGHT = 24,
    },

    ASSETS = {
        JOURNAL_PORTRAIT = "Interface\\EncounterJournal\\UI-EJ-PortraitIcon",
        FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Book_09",
        GEAR_ICON = "Interface\\Buttons\\UI-OptionsButton",
        HOME_ATLAS = "common-icon-home",
        HOME_FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Rune_01",
        PARCHMENT_ATLAS = "Spellbook-Page-1",
        PARCHMENT_FALLBACK = "Interface\\Spellbook\\Spellbook-Page-1",
        BUTTON_HIGHLIGHT = "Interface\\Buttons\\UI-Common-MouseHilight",
        MINIMAP_BG = "Interface\\Minimap\\UI-Minimap-Background",
        MINIMAP_BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder",
        MINIMAP_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
        WHITE_8X8 = "Interface\\Buttons\\WHITE8X8",
        TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
        NAV_CHEVRON_ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow",
    },

    -- Canonical ecosystem catalog displayed on the Home page (even before a plugin is installed)
    -- and merged with live `description`, `version`, and `lastUpdated` registered by loaded plugins.
    KNOWN_PLUGINS = {
        {
            id = "home",
            title = "Home",
            addonName = "Journal_Base",
            defaultOrder = 1,
            icon = "Interface\\Icons\\INV_Misc_Book_09",
            description = "Browse the module catalog, view installed plugin statuses, and discover ecosystem features.",
            version = "0.4.0",
            lastUpdated = "2026-11-13",
        },
        {
            id = "dungeons",
            title = "Dungeons",
            addonName = "Journal_Dungeons",
            defaultOrder = 10,
            icon = "Interface\\Icons\\INV_Misc_Key_03",
            description = "Explore 5-player dungeons across Classic and WoW Forever, including level brackets, boss encounters, role notes, and loot drops.",
            version = "0.4.0",
            lastUpdated = "2026-11-13",
        },
        {
            id = "raids",
            title = "Raids",
            addonName = "Journal_Raids",
            defaultOrder = 20,
            icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
            description = "Prepare for 10, 20, and 40-player raid tiers with multi-phase encounter strategies, boss abilities, and tier set loot tables.",
            version = "0.0.0",
            lastUpdated = "2026-11-13",
        },
        {
            id = "professions",
            title = "Professions",
            addonName = "Journal_Professions",
            defaultOrder = 30,
            icon = "Interface\\Icons\\Trade_BlackSmithing",
            description = "Browse primary and secondary professions, recipe and schematic sources, trainer locations, and crafting reagent breakdowns.",
            version = "0.0.0",
            lastUpdated = "2026-11-13",
        },
        {
            id = "quests",
            title = "Quests",
            addonName = "Journal_Quests",
            defaultOrder = 40,
            icon = "Interface\\Icons\\INV_Misc_Book_08",
            description = "Track dungeon questlines, raid attunement chains, class quests, and notable reward paths across Azeroth.",
            version = "0.0.0",
            lastUpdated = "2026-11-13",
        },
        {
            id = "map_icons",
            title = "Map Icons",
            addonName = "Utility_MapIcons",
            defaultOrder = 900,
            icon = "Interface\\Icons\\INV_Misc_Map02",
            description = "Provides world and zone map indicators for dungeon and raid entrances, with level-bracket filtering.",
            version = "0.4.0",
            lastUpdated = "2026-11-13",
            isUtility = true,
        },
    },

    SOUNDS = {
        OPEN = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN) or 839,
        CLOSE = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE) or 840,
        TAB = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB) or 841,
        CHECKBOX_ON = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856,
        CHECKBOX_OFF = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) or 857,
        CLICK = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION) or 852,
    },

    DB_DEFAULTS = {
        schemaVersion = 1,
        minimap = {
            show = true,
            hide = false,
            angle = 225,
        },
        window = {
            lastPluginId = nil,
            homePluginId = nil,
            defaultLandingPluginId = nil,
            point = nil,
        },
        disabledPlugins = {
            ["home"] = true,
        },
        pluginOrder = {},
        dungeons = {
            showBossLevel = true,
            showBossDifficultyColor = true,
            showMinorMonsters = true,
            showEventBosses = "holiday",
            showDungeonSetChallenges = false,
            worldMapDungeonIcons = "min_level",
            dungeonGridSort = "level",
        },
        map_icons = {
            worldMapDungeonIcons = "min_level",
            worldMapRaidIcons = "disabled",
        },
    },
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Constants = Constants
ns.UI = ns.UI or {}

