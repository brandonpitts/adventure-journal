-- ============================================================================
-- Adventure Journal - Core/Data/InstanceLocations.lua
-- Where instances are, for the instance data feed (InstanceAccess): an
-- instance's or wing's entrance on the world map, and the instance (and wing,
-- by the subzone under the minimap) the player is standing in.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local GetInstanceInfo = GetInstanceInfo
local GetSubZoneText = GetSubZoneText

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Our instance types and the client's names for them (GetInstanceInfo)
local CLIENT_INSTANCE_TYPE = { dungeon = "party", raid = "raid" }

-- A store, or nil when the DataStore is off
---@return any
local function store(name)
    local DataStore = ns.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore[name] or nil
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Access = ns.Data.InstanceAccess

--- The entrance record key for an instance view: the wing's own door, else the instance's; an instance whose
--- doors all belong to wings uses its first wing's.
function Access:GetEntranceKey(view)
    local locations = store("LocationStore")
    if not locations or not view then
        return nil
    end
    if view.wingKey then
        for _, key in ipairs(locations:FindBy("wingKey", view.wingKey)) do
            if locations:Get(key).kind == "entrance" then
                return key
            end
        end
    end
    for _, key in ipairs(locations:FindBy("instanceID", view.instanceID)) do
        local record = locations:Get(key)
        if record.kind == "entrance" and (not record.wingKey or record.wingKey == view.wingKey) then
            return key
        end
    end
    if view.wingKey then
        return nil
    end
    local instances = store("InstanceStore")
    local wingKeys = instances and instances:FindBy("instanceID", view.instanceID) or {}
    local firstWing
    for _, wingKey in ipairs(wingKeys) do
        if not firstWing or (instances:Get(wingKey).order or 0) < (instances:Get(firstWing).order or 0) then
            firstWing = wingKey
        end
    end
    return firstWing and self:GetEntranceKey({ wingKey = firstWing, instanceID = view.instanceID })
end

--- The entrance's map point: { uiMapID, x, y, name }, or nil.
function Access:GetEntrance(view)
    local key = self:GetEntranceKey(view)
    local record = key and store("LocationStore"):Get(key)
    if not record or not record.uiMapID then
        return nil
    end
    return { uiMapID = record.uiMapID, x = record.x, y = record.y, name = view.fullName }
end

--- The wing whose region (named subzone, LocationStore) is `subzone`, or nil.
--- @param instanceID number
--- @param subzone string|nil the name under the minimap
function Access:GetWingBySubzone(instanceID, subzone)
    local locations = store("LocationStore")
    if not locations or not subzone or subzone == "" then
        return nil
    end
    for _, key in ipairs(locations:FindBy("instanceID", instanceID)) do
        local region = locations:Get(key)
        if region.kind == "region" and region.wingKey and region.label == subzone then
            return self:GetInstance(region.wingKey)
        end
    end
end

--- The instance of `instanceType` ("dungeon" or "raid") the player is inside, or nil outside one or in one
--- not in the catalog. In an instance with wings, the wing the current subzone belongs to; the instance itself
--- when the subzone has no wing.
function Access:GetCurrentInstance(instanceType)
    local _, clientType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if clientType ~= CLIENT_INSTANCE_TYPE[instanceType] or not instanceID then
        return nil
    end
    local dungeon = self:GetInstance(instanceID)
    if dungeon and dungeon.instanceType ~= instanceType then
        return nil
    end
    if dungeon and dungeon.wingCount > 0 and GetSubZoneText then
        return self:GetWingBySubzone(instanceID, GetSubZoneText()) or dungeon
    end
    return dungeon
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.Data.InstanceAccess)
