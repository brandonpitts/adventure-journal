-- ============================================================================
-- Journal_Dungeons - Template.lua
-- The dungeon template: Core's instance template with the dungeon's noun,
-- settings, and boss-list sections.
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
parent.Templates:Extend("instance", "dungeon", {
    noun = "Dungeon",
    instanceType = "dungeon",
    settings = "dungeons",
    -- The page's settings: our name -> the saved setting's key in the "dungeons" settings
    settingKeys = {
        showLevel = "showBossLevel", showColor = "showBossDifficultyColor", showMinor = "showMinorMonsters",
        hideMinor = "hideMinorMonsters", showEvents = "showEventBosses", showChallenges = "showDungeonSetChallenges",
        showIncomplete = "showIncompleteBosses",
        showBothFactions = "showBothFactionData", mapButton = "worldMapDungeonIcons",
        listSort = "dungeonListSort", listLayout = "dungeonListLayout",
    },
    -- The boss list's sections, in order (InstanceAccess:GroupEncounters sorts encounters into these kinds)
    encounterSections = {
        { kind = "event", dividerAfter = true },
        { kind = "boss" },
        { kind = "rare", label = "Rare Encounters", color = { 0.85, 0.90, 1.0 } },
        { kind = "minor", label = "Minor & Quest Encounters", color = { 0.75, 0.70, 0.60 } },
        { kind = "challenge", label = "Dungeon Set Challenges (Tier 0.5)", color = { 1.0, 0.82, 0.20 } },
        { kind = "zone", dividerBefore = true },
    },
})

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Registered with parent.Templates)
