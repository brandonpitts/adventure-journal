-- ============================================================================
-- Journal_Raids - Template.lua
-- The raid template: Core's instance template with the raid's noun, settings
-- and boss-list sections, and the raid's size in the header.
-- ============================================================================
local addonName, parent = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Template Definition
-- ----------------------------------------------------------------------------
parent.Templates:Extend("instance", "raid", {
    noun = "Raid",
    instanceType = "raid",
    settings = "raids",
    -- The page's settings: our name -> the saved setting's key in the "raids" settings
    settingKeys = {
        showLevel = "showBossLevel", showColor = "showBossDifficultyColor", showMinor = "showMinorMonsters",
        hideMinor = "hideMinorMonsters", showEvents = "showEventBosses", showChallenges = "showChallenges",
        showBothFactions = "showBothFactionData", mapButton = "worldMapRaidIcons",
        listSort = "raidListSort", listLayout = "raidListLayout", groupByTier = "groupRaidsByTier",
    },
    -- The header's meta line: the raid's size after its level
    headerMeta = { "level", "size", "location" },
    -- The raid list: cards show the group size (raids share one level), black alone marks missing art, and
    -- raids can be grouped by tier
    listInfo = "size",
    listGroups = { field = "tier", setting = "groupByTier", text = "tierHeader" },
    layout = { list = { MISSING_ART_ICON = false } },
    -- The boss list's sections, in order (InstanceAccess:GroupEncounters sorts encounters into these kinds)
    encounterSections = {
        { kind = "event", dividerAfter = true },
        { kind = "boss" },
        { kind = "rare", label = "Rare Encounters", color = { 0.85, 0.90, 1.0 } },
        { kind = "minor", label = "Minor & Quest Encounters", color = { 0.75, 0.70, 0.60 } },
        { kind = "zone", dividerBefore = true },
    },
})

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Registered with parent.Templates)
