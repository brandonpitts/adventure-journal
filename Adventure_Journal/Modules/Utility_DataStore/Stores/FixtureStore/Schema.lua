-- ============================================================================
-- Utility_DataStore - Stores/FixtureStore/Schema.lua
--
-- A fixture is something placed in the world that you click but never carry:
-- wanted posters, books on pedestals, the Battered Dwarven Skeleton at Agmond's
-- End, the Discs of Norgannon in Uldaman, and later chests, herb nodes and ore
-- veins. In the game's own data these are "game objects" (GameObject in their
-- GUIDs); we call them fixtures because "object" means something else in
-- programming. If clicking one puts an item in your bags and that item starts
-- the quest, the quest links to the item instead, and the fixture needs no
-- record. Keyed by the game's object ID.
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
    name = "FixtureStore",
    kind = "Fixture",
    fields = {
        icon       = { type = "string", comment = "Our chosen icon." },
        spawns     = { type = "table",  list = true, comment = "Where it is: { { uiMapID, x, y } }, 0-1 coordinates." },
        instanceID = { type = "number", links = "InstanceStore", comment = "For fixtures inside an instance." },
        regionKey  = { type = "string", links = "LocationStore", comment = "Reserved (instance maps): landmark region." },
    },
})
