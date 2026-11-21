-- ============================================================================
-- Adventure Journal - Core/Data/InstanceAccess.lua
-- The data feed for instance pages (dungeons and raids): instances, wings,
-- encounters and loot, answered from the DataStore only, as plain view tables.
--   instance view:  key, id, instanceID, wingKey, instanceType, maxPlayers, tier, attunement, name, fullName, level,
--                   minLevel, maxLevel, location, description, icon, art, aliases, comingSoon, wingCount,
--                   zoneItemIDs
--   encounter view: key, name, level, minLevel, maxLevel, classification, rare, isMinor, isChallenge,
--                   isEvent, holidayID, displayID, icon, description, npcID, itemIDs (everything it drops),
--                   baseItemIDs (its own loot), lootSets ({ label, itemIDs }: loot that depends on circumstances)
-- Entrances and the instance the player is in: InstanceLocations.lua. Search and the boss list's groups:
-- InstanceSearch.lua.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local sort = table.sort
local concat = table.concat
local format = string.format
local strfind = string.find
local strlower = string.lower

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local SKULL_LEVEL = -1

-- Session cache: dungeon key -> view, and view -> list of boss views
local viewCache, bossCache = {}, {}

-- A store, or nil when the DataStore is off; every public call checks first
---@return any
local function store(name)
    local DataStore = ns.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore[name] or nil
end

local function appendUnique(list, seen, values)
    for _, value in ipairs(values or {}) do
        if not seen[value] then
            seen[value] = true
            list[#list + 1] = value
        end
    end
end

-- "19", "19-21", or "??" for skull levels
local function levelText(minLevel, maxLevel)
    if minLevel == SKULL_LEVEL or maxLevel == SKULL_LEVEL then
        return "??"
    elseif not minLevel then
        return nil
    elseif maxLevel and maxLevel ~= minLevel then
        return format("%d-%d", minLevel, maxLevel)
    end
    return tostring(minLevel)
end

-- "Moonbrook, Westfall" from the entrance's area (or our place name) and zone; the legacy hint when neither is known
local function locationText(entranceKey)
    local locations = store("LocationStore")
    local entrance = locations and locations:Get(entranceKey)
    if not entrance then
        return nil
    end
    local zone = entrance.uiMapID and store("ZoneStore"):GetLabel(entrance.uiMapID)
    local area = entrance.areaID and store("AreaStore"):GetLabel(entrance.areaID) or entrance.place
    if area then
        return (zone and zone ~= area) and (area .. ", " .. zone) or area
    end
    local hint = locations:GetHints(entranceKey, "areaID")[1]
    return hint and hint.text or zone
end

-- An instance with no wings and several entrances: each entrance's place in their order, "A / B / C"; nil otherwise
local function entrancesText(view)
    local locations = store("LocationStore")
    if not locations or view.wingKey or view.wingCount > 0 then
        return nil
    end
    local keys = {}
    for _, key in ipairs(locations:FindBy("instanceID", view.instanceID)) do
        if locations:Get(key).kind == "entrance" then
            keys[#keys + 1] = key
        end
    end
    if #keys < 2 then
        return nil
    end
    sort(keys, function(a, b)
        return (locations:Get(a).order or 0) < (locations:Get(b).order or 0)
    end)
    local parts = {}
    for i, key in ipairs(keys) do
        parts[i] = locationText(key)
    end
    return concat(parts, " / ")
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Access = {}

--- The view for an instance key (instance map ID or wing slug), built once per session.
function Access:GetInstance(key)
    if viewCache[key] then
        return viewCache[key]
    end
    local instances = store("InstanceStore")
    local record = instances and instances:Get(key)
    if not record then
        return nil
    end
    local instanceID = record.instanceID or key
    local instance = instances:Get(instanceID)
    local wingKeys = instances:FindBy("instanceID", instanceID)
    local view = {
        key = key, id = key, instanceID = instanceID, wingKey = record.instanceID and key or nil,
        instanceType = instance.type, maxPlayers = instance.maxPlayers, tier = instance.tier,
        attunement = instance.attunement,
        name = instances:GetLabel(key),
        icon = record.icon or instance.icon,
        aliases = record.aliases,
        comingSoon = instance.comingSoon,
        description = instances:GetText(key, "description"),
        art = { record.loadingScreen or instance.loadingScreen },
        wingCount = (not record.instanceID) and #wingKeys or 0,
        minLevel = record.minLevel, maxLevel = record.maxLevel,
    }
    if view.wingKey then
        local parentName = instances:GetLabel(instanceID)
        view.fullName = strfind(view.name, parentName, 1, true) and view.name or (parentName .. ": " .. view.name)
    else
        view.fullName = view.name
    end
    -- An instance with wings spans its wings' levels
    for _, wingKey in ipairs(view.wingCount > 0 and wingKeys or {}) do
        local wing = instances:Get(wingKey)
        if wing.minLevel and (not view.minLevel or wing.minLevel < view.minLevel) then view.minLevel = wing.minLevel end
        if wing.maxLevel and (not view.maxLevel or wing.maxLevel > view.maxLevel) then view.maxLevel = wing.maxLevel end
    end
    view.level = levelText(view.minLevel, view.maxLevel)
    view.location = entrancesText(view) or locationText(self:GetEntranceKey(view))
    -- Instance-wide drops: the wing's own plus its instance's (shared by every wing)
    local seen = {}
    view.zoneItemIDs = {}
    appendUnique(view.zoneItemIDs, seen, record.itemIDs)
    if record.instanceID then
        appendUnique(view.zoneItemIDs, seen, instance.itemIDs)
    end
    viewCache[key] = view
    return view
end

--- The list: one view per instance of `instanceType` ("dungeon" or "raid"); wings live on their instance's
--- wing page.
function Access:GetInstanceList(instanceType)
    local instances = store("InstanceStore")
    local list = {}
    if not instances then
        return list
    end
    for key in instances:EachKey() do
        local record = instances:Get(key)
        if not record.instanceID and record.type == instanceType then
            list[#list + 1] = self:GetInstance(key)
        end
    end
    return list
end

--- A parent's wings, in their order.
function Access:GetWings(view)
    local instances = store("InstanceStore")
    local list = {}
    for _, key in ipairs(instances and instances:FindBy("instanceID", view.instanceID) or {}) do
        list[#list + 1] = self:GetInstance(key)
    end
    sort(list, function(a, b)
        return (instances:Get(a.key).order or 0) < (instances:Get(b.key).order or 0)
    end)
    return list
end

--- One encounter view; a group gathers its members' NPCs and loot.
function Access:BuildEncounter(key, record)
    local encounters, npcs = store("EncounterStore"), store("NpcStore")
    local parts = { record }
    for _, field in ipairs({ "encounterID", "encounterKey" }) do
        for _, memberKey in ipairs(encounters:FindBy(field, key)) do
            parts[#parts + 1] = encounters:Get(memberKey)
        end
    end
    local itemIDs, seenItems = {}, {}
    local baseItemIDs, seenBase, lootSets = {}, {}, {}
    local minLevel, maxLevel, mainNpc
    for _, part in ipairs(parts) do
        appendUnique(itemIDs, seenItems, part.itemIDs)
        appendUnique(baseItemIDs, seenBase, part.itemIDs)
        for _, set in ipairs(part.lootSets or {}) do
            appendUnique(itemIDs, seenItems, set.itemIDs)
            lootSets[#lootSets + 1] = { label = set.label, itemIDs = set.itemIDs }
        end
        for _, entry in ipairs(part.npcs or {}) do
            if entry.role == "boss" then
                local npc = npcs:Get(entry.npcID)
                mainNpc = mainNpc or (npc and entry.npcID)
                local low, high = npc and npc.minLevel, npc and (npc.maxLevel or npc.minLevel)
                if low == SKULL_LEVEL or high == SKULL_LEVEL then
                    minLevel, maxLevel = SKULL_LEVEL, SKULL_LEVEL
                elseif low and minLevel ~= SKULL_LEVEL then
                    minLevel = (minLevel and minLevel < low) and minLevel or low
                    maxLevel = (maxLevel and maxLevel > high) and maxLevel or high
                end
            end
        end
    end
    local kind = record.kind or "boss"
    local npc = mainNpc and npcs:Get(mainNpc)
    local description = encounters:GetText(key, "description")
    return {
        key = key, name = encounters:GetLabel(key),
        level = levelText(minLevel, maxLevel), minLevel = minLevel, maxLevel = maxLevel,
        classification = (kind == "rare" and "rare") or (kind == "minor" and "minor") or nil,
        rare = kind == "rare", isMinor = kind == "minor", isChallenge = kind == "challenge",
        isEvent = kind == "event", holidayID = record.holidayID,
        npcID = mainNpc, displayID = npc and npc.displayID, icon = record.icon,
        description = description,
        -- Known only by name: no loot, no NPC and no description
        isIncomplete = #itemIDs == 0 and not mainNpc and not description,
        itemIDs = itemIDs, baseItemIDs = baseItemIDs, lootSets = lootSets,
    }
end

--- An instance's (or wing's) encounters in boss-list order. Group members appear inside their group.
function Access:GetEncounters(view)
    if not view or view.wingCount > 0 then
        return {}
    end
    if bossCache[view] then
        return bossCache[view]
    end
    local encounters = store("EncounterStore")
    local entries = {}
    for _, key in ipairs(encounters and encounters:FindBy("instanceID", view.instanceID) or {}) do
        local record = encounters:Get(key)
        -- A `place` display override shows an encounter on a wing's page (its data names no wing)
        local placed = encounters:GetDisplayOverride(key, "place", "bossList")
        local wingKey = placed and placed.value.wingKey or record.wingKey
        if not (record.encounterID or record.encounterKey) and wingKey == view.wingKey then
            entries[#entries + 1] = { key = key, order = record.order or 0, view = self:BuildEncounter(key, record) }
        end
    end
    sort(entries, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.view.name < b.view.name
    end)
    local list = {}
    for i, entry in ipairs(entries) do
        list[i] = entry.view
    end
    bossCache[view] = list
    return list
end

--- Forgets cached views (after a data change).
function Access:ClearCache()
    for key in pairs(viewCache) do viewCache[key] = nil end
    for key in pairs(bossCache) do bossCache[key] = nil end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Data = ns.Data or {}
ns.Data.InstanceAccess = Access
