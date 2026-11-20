-- ============================================================================
-- Utility_DataStore - Stores/FlightPointStore/Schema.lua
--
-- A flight point is where a flight master offers flights to other places:
-- Sentinel Hill, the Crossroads, Marshal's Refuge. Keyed by the game's flight
-- node ID. Holds the zone map it's drawn on and where. The game answers the
-- same per map while playing (C_TaxiMap), which can verify these records.
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
    name = "FlightPointStore",
    kind = "Flight Point",
    fields = {
        uiMapID = { type = "number", required = true, links = "ZoneStore", comment = "The zone map it's drawn on." },
        x       = { type = "number", required = true, comment = "Position on the map, 0-1." },
        y       = { type = "number", required = true, comment = "Position on the map, 0-1." },
    },
})
