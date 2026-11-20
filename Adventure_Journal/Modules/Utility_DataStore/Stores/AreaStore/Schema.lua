-- ============================================================================
-- Utility_DataStore - Stores/AreaStore/Schema.lua
--
-- An area is a named place inside a zone or an instance: Moonbrook in
-- Westfall, the Valley of Wisdom in Orgrimmar, the Grim Guzzler in Blackrock
-- Depths. It's the name the game shows under the minimap as you walk in.
-- Keyed by the game's area ID. Holds which zone or instance it's in.
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
    name = "AreaStore",
    kind = "Area",
    liveName = "area",
    fields = {
        uiMapID    = { type = "number", links = "ZoneStore", comment = "The zone it's in (outdoors)." },
        instanceID = { type = "number", links = "InstanceStore", comment = "The instance it's in." },
    },
})
