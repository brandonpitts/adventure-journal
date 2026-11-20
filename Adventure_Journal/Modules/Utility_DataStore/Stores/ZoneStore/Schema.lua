-- ============================================================================
-- Utility_DataStore - Stores/ZoneStore/Schema.lua
--
-- A zone is a map you can open in the world map window: Westfall, Orgrimmar,
-- Un'Goro Crater. Keyed by the game's UI map ID, the same ID map pins and
-- NPC spawns use. Holds the zone's level range and fishing skill, which the
-- client doesn't provide. Named areas inside a zone live in AreaStore.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Store Definition
-- ----------------------------------------------------------------------------
DataStore.StoreBase:New({
    name = "ZoneStore",
    kind = "Zone",
    liveName = "uiMap",
    fields = {
        minLevel     = { type = "number", comment = "Recommended minimum level." },
        maxLevel     = { type = "number", comment = "Recommended maximum level." },
        fishingSkill = { type = "number", comment = "Fishing skill needed; the lowest of the zone's areas." },
    },
})
