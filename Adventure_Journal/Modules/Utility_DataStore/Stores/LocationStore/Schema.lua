-- ============================================================================
-- Utility_DataStore - Stores/LocationStore/Schema.lua
--
-- A location is a place of our own on a map, one the game has no ID for:
-- dungeon and raid entrances, quest hubs, and regions: the named rooms
-- inside an instance (the name under the minimap as you walk in, such as
-- Huntsman's Cloister in the Scarlet Monastery Library), with the wing each
-- belongs to. Keyed by slug. Zones, outdoor areas and flight points have the
-- game's own IDs and live in ZoneStore, AreaStore and FlightPointStore.
-- Where NPCs and fixtures stand lives on those records. Regions so far cover
-- the instances with wings; floor maps come with the instance maps project.
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
    name = "LocationStore",
    kind = "Location",
    fields = {
        kind         = { type = "string", required = true, comment = "entrance, hub or region." },
        uiMapID      = { type = "number", links = "ZoneStore", comment = "The zone map it's drawn on." },
        x            = { type = "number", comment = "Position on the map, 0-1." },
        y            = { type = "number", comment = "Position on the map, 0-1." },
        areaID       = { type = "number", links = "AreaStore", comment = "The named area it sits in." },
        place        = { type = "string", comment = "Our name for its spot within the zone when the client has no area for it (e.g. \"Summit\"); the area wins once there is one." },
        instanceID   = { type = "key",    links = "InstanceStore", comment = "The instance it leads into or belongs to: its map ID, or its slug until the client ships the map." },
        order        = { type = "number", comment = "An entrance's place among its instance's entrances, when it has several." },
        wingKey      = { type = "string", links = "InstanceStore", comment = "The wing (entrances, regions)." },
        wmoIDs       = { type = "table",  list = true, comment = "Regions: the client's building models (WMOAreaTable WMOID) the name comes from." },
        -- Reserved for instance maps (region kind)
        floor        = { type = "number", comment = "Reserved: which of the wing's floorMaps a region is drawn on." },
        neighborKeys = { type = "table",  list = true, links = "LocationStore", comment = "Reserved: regions you can walk to." },
        areaIDs      = { type = "table",  list = true, links = "AreaStore", comment = "Reserved: areas that light up this region." },
        outline      = { type = "table",  comment = "Reserved: the region's shape on the floor map." },
    },
})
