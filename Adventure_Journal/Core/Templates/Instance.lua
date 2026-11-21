-- ============================================================================
-- Adventure Journal - Core/Templates/Instance.lua
-- The base template for instance pages (dungeons and raids): the book and
-- list sizes, the side tabs, the loot categories, the slots with their
-- placeholders, and the page's text. The Quests tab draws from its own quest
-- template (`quests`). Dungeons and Raids extend it with their noun,
-- settings, boss-list sections and anything else of their own.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Template Definition
-- ----------------------------------------------------------------------------
ns.Templates:Extend("base", "instance", {
    -- The template for the Quests tab
    quests = "questGroup",

    layout = {
        book = {
            LEFT_WIDTH = 330, BOSS_BTN_WIDTH = 268, BOSS_BTN_HEIGHT = 44, BOSS_BTN_GAP = 30,
            WING_BTN_HEIGHT = 67, WING_BTN_GAP = 18, BOSS_ICON_SIZE = 50, BOSS_RING_SIZE = 68,
            ART_FRAME_WIDTH = 376, ART_FRAME_HEIGHT = 186, RIGHT_CONTENT_WIDTH = 376,
        },
        -- Card layouts across the list's 730 px (the list layout setting). centered: the name in capitals and the
        -- levels centered on the card; otherwise the name on the left over "Lvl - zone".
        list = {
            LAYOUTS = {
                two_compact = { columns = 2, width = 358, height = 67 },
                two_large = { columns = 2, width = 358, height = 88 },
                three = { columns = 3, width = 234, height = 67 },
                four = { columns = 4, width = 172, height = 88, centered = true, noFade = true },
            },
            DEFAULT_LAYOUT = "four",
            GAP_X = 14, GAP_Y = 12, START_X = 6, START_Y = -8,
            SCROLL_TOP_Y = -8, SCROLL_BOTTOM_Y = 8, SCROLL_LEFT_X = 12, SCROLL_RIGHT_X = -28,
            -- A card without art: the question mark in its corner (false: plain black)
            MISSING_ART_ICON = true,
        },
    },

    -- The list cards' second line leads with: "level" (the level range, behind the show-levels setting) or
    -- "size" (the group size)
    listInfo = "level",
    -- Grouping the list under headers: nil for none, or `{ field, setting, text }`: the view field to group by,
    -- the setting (by its settingKeys name) that turns it on, and the header's text key ("%s" the value).
    -- Entries without the field come last, under no header.
    listGroups = nil,

    -- The left page header's meta line, in order, joined with " • ": "level" (colored by the difficulty-color
    -- setting), "location", "size" (the `header.size` slot; raids list it)
    headerMeta = { "level", "location" },

    -- Side tabs down the window's right edge, in order
    tabs = {
        { key = "overview", title = "overviewTab", icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01" },
        { key = "loot", title = "lootTab", icon = "Interface\\Icons\\INV_Box_02" },
        { key = "quests", title = "questsTab", atlas = "QuestNormal" },
    },

    -- The loot list's categories, in order
    lootCategories = {
        { id = "EQUIPMENT", title = "Equipment" },
        { id = "RECIPE", title = "Recipes" },
        { id = "QUEST", title = "Quest Items & Keys" },
        { id = "COLLECTIBLE", title = "Collectibles" },
        { id = "MISC", title = "Other" },
    },

    -- Fields the page shows and what shows when one is missing (false: nothing). Display overrides target these.
    slots = {
        ["header.title"] = { field = "fullName", placeholder = "?" },
        ["header.crest"] = { field = "crest", placeholder = false },
        ["header.size"] = { field = "maxPlayers", placeholder = false },
        -- A list card's picture crop: nothing by default (the standard crop); a `replace` display override sets
        -- `{ centerV }`, where the crop centers down the picture (0 top, 1 bottom)
        ["card.crop"] = { placeholder = false },
        ["overview.lore"] = { field = "description", placeholder = false },
        ["encounter.description"] = { field = "description", placeholder = false },
        -- The icon an encounter's medallion shows when it has no creature portrait; the medallion shows the
        -- missing-icon question mark when there is none. A `replace` display override sets it (an icon path).
        ["encounter.icon"] = { field = "icon", placeholder = false },
        ["bossList"] = { placeholder = false },
    },

    text = {
        crumbHome = "Home",
        size = "%s Players",
        tierHeader = "Tier %s",
        comingSoon = "Coming Soon",
        overviewTab = "{noun} Overview",
        overviewTabHint = "View {noun_lower} lore, artwork, and world map entrance.",
        overviewTabOff = "Overview is only available on the main {noun_lower} page.",
        overviewTabHow = "Click the {noun_lower} portrait in the upper-left to enable.",
        lootTab = "Loot",
        encounterLoot = "%s — Loot",
        encounterLootHint = "Viewing categorized item drops for this encounter.",
        allLoot = "All {noun} Loot",
        allLootHint = "View every item drop across the entire {noun_lower}.",
        questsTab = "{noun} Quests",
        questsTabHint = "View all quests, questlines, and rewards for this {noun_lower}.",
        questsTabOff = "No quests available for your faction or class in this {noun_lower}.",
        headerToAllLoot = "Click to view All {noun} Loot & enable Overview tab",
        headerToOverview = "Click to return to {noun} Overview",
        headerSelected = "Main {noun} Page selected",
        zoneDrops = "Zone Drops",
        zoneDropsSearch = "zone drops",
        zoneDropsDescription = "Notable zone-wide drops from creatures throughout %s.",
        thisInstance = "the {noun_lower}",
        noMatches = "No encounters or items matching\n|cffffd200\"%s\"|r",
        noLoot = "No item drops recorded for this encounter.",
        noInstanceLoot = "No item drops recorded for this {noun_lower}.",
        noLootMatches = "No drops matching \"%s\".",
        mapEntrance = "Click to view %s entrance on the World Map.",
        mapEntranceUnnamed = "Click to view {noun_lower} entrance on the World Map.",
        listLevel = "Level %s",
        listLevelShort = "Lvl %s",
        listWings = "Wings",
        listOpen = "Click to open",
    },
})

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Registered with ns.Templates)
