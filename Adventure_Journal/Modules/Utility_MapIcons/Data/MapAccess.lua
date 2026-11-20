-- ============================================================================
-- Utility_MapIcons - Data/MapAccess.lua
-- What the map pins and zone labels show, answered from the DataStore:
-- dungeon entrances (LocationStore and
-- InstanceStore), flight points (FlightPointStore) and zone levels and
-- fishing skill (ZoneStore). Coordinates are 0-1, as the client's map API uses.
--   entrance pin: kind ("Dungeon" | "Raid"), dungeonKey (map ID or wing slug), name, x, y, minLevel, maxLevel
--   flight pin:   kind = "FlightPath", faction ("Alliance" | "Horde" | "Neutral"), name, x, y
--   zone:         minLevel, maxLevel, fishing
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local PIN_KIND = { dungeon = "Dungeon", raid = "Raid" }

-- A store, or nil when the DataStore is off; every public call checks first
---@return any
local function store(name)
    local DataStore = ns.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore[name] or nil
end

-- Levels of an instance or wing; an instance with wings spans its wings
local function levelRange(instances, key)
    local record = instances:Get(key)
    local minLevel, maxLevel = record.minLevel, record.maxLevel
    if not record.instanceID then
        for _, wingKey in ipairs(instances:FindBy("instanceID", key)) do
            local wing = instances:Get(wingKey)
            if wing.minLevel and (not minLevel or wing.minLevel < minLevel) then minLevel = wing.minLevel end
            if wing.maxLevel and (not maxLevel or wing.maxLevel > maxLevel) then maxLevel = wing.maxLevel end
        end
    end
    return minLevel, maxLevel
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local MapAccess = {}

--- Dungeon and raid entrance pins on one map.
function MapAccess:GetEntrancePins(uiMapID)
    local locations, instances = store("LocationStore"), store("InstanceStore")
    local pins = {}
    if not locations or not instances then
        return pins
    end
    for _, key in ipairs(locations:FindBy("uiMapID", uiMapID)) do
        local entrance = locations:Get(key)
        local instance = entrance.kind == "entrance" and instances:Get(entrance.instanceID)
        if instance then
            local dungeonKey = entrance.wingKey or entrance.instanceID
            local minLevel, maxLevel = levelRange(instances, dungeonKey)
            pins[#pins + 1] = {
                kind = PIN_KIND[instance.type] or "Dungeon", dungeonKey = dungeonKey,
                name = locations:GetLabel(key), x = entrance.x, y = entrance.y,
                minLevel = minLevel, maxLevel = maxLevel,
            }
        end
    end
    return pins
end

--- Flight point pins on one map.
function MapAccess:GetFlightPins(uiMapID)
    local flights = store("FlightPointStore")
    local pins = {}
    for _, key in ipairs(flights and flights:FindBy("uiMapID", uiMapID) or {}) do
        local node = flights:Get(key)
        pins[#pins + 1] = {
            kind = "FlightPath", faction = node.faction or "Neutral",
            name = flights:GetLabel(key), x = node.x, y = node.y,
        }
    end
    return pins
end

--- A zone's levels and fishing skill, or nil when the zone isn't in ZoneStore.
function MapAccess:GetZone(uiMapID)
    local zones = store("ZoneStore")
    local zone = zones and zones:Get(uiMapID)
    if not zone then
        return nil
    end
    return { minLevel = zone.minLevel, maxLevel = zone.maxLevel, fishing = zone.fishingSkill }
end

--- Every zone ZoneStore knows, as uiMapID -> zone (for matching zones by their map name).
function MapAccess:GetZones()
    local zones = store("ZoneStore")
    local result = {}
    if zones then
        for key in zones:EachKey() do
            result[key] = self:GetZone(key)
        end
    end
    return result
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.MapAccess = MapAccess
