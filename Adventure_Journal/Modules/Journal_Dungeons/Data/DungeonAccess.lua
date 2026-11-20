-- ============================================================================
-- Journal_Dungeons - Data/DungeonAccess.lua
-- Every question the Dungeons screens ask about dungeons, wings, bosses and
-- loot, answered from the DataStore only. Answers are
-- plain view tables shaped for today's screens; the templating branch carries
-- this file over and rebuilds only the screens.
--   dungeon view: key, id, instanceID, wingKey, name, fullName, level, minLevel, maxLevel,
--                 location, description, icon, art, aliases, comingSoon, wingCount, crest
--   boss view:    key, name, level, minLevel, maxLevel, classification, rare, isMinor, isChallenge,
--                 isEvent, holidayID, displayID, icon, description, npcID, itemIDs
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local GetInstanceInfo = GetInstanceInfo
local GetSubZoneText = GetSubZoneText
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local sort = table.sort
local format = string.format
local strfind = string.find
local strlower = string.lower

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local SKULL_LEVEL = -1

-- Capital-city dungeons show their city's faction crest by the title. A display choice, not data;
-- belongs to the dungeon template's header slot when templates arrive.
local CREST_BY_INSTANCE = { [389] = "Horde", [2999] = "Horde", [34] = "Alliance", [3065] = "Alliance" }

-- Session cache: dungeon key -> view, and view -> list of boss views
local viewCache, bossCache = {}, {}

-- A store, or nil when the DataStore is off; every public call checks first
---@return any
local function store(name)
    local DataStore = parent.DataStore
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

-- "Moonbrook, Westfall" from the entrance's area and zone; the legacy hint when the area is unknown
local function locationText(entranceKey)
    local locations = store("LocationStore")
    local entrance = locations and locations:Get(entranceKey)
    if not entrance then
        return nil
    end
    local zone = entrance.uiMapID and store("ZoneStore"):GetLabel(entrance.uiMapID)
    if entrance.areaID then
        local area = store("AreaStore"):GetLabel(entrance.areaID)
        return (zone and zone ~= area) and (area .. ", " .. zone) or area
    end
    local hint = locations:GetHints(entranceKey, "areaID")[1]
    return hint and hint.text or zone
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Access = {}

--- The entrance record key for a dungeon view: the wing's own door, else the instance's; an instance whose
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

--- The view for a dungeon key (instance map ID or wing slug), built once per session.
function Access:GetDungeon(key)
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
        name = instances:GetLabel(key),
        icon = record.icon or instance.icon,
        aliases = record.aliases,
        comingSoon = instance.comingSoon,
        crest = CREST_BY_INSTANCE[instanceID],
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
    view.location = locationText(self:GetEntranceKey(view))
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

--- The grid: one view per instance (wings live on their instance's wing page).
function Access:GetDungeonList()
    local instances = store("InstanceStore")
    local list = {}
    if not instances then
        return list
    end
    for key in instances:EachKey() do
        if not instances:Get(key).instanceID then
            list[#list + 1] = self:GetDungeon(key)
        end
    end
    return list
end

--- A parent's wings, in their order.
function Access:GetWings(view)
    local instances = store("InstanceStore")
    local list = {}
    for _, key in ipairs(instances and instances:FindBy("instanceID", view.instanceID) or {}) do
        list[#list + 1] = self:GetDungeon(key)
    end
    sort(list, function(a, b)
        return (instances:Get(a.key).order or 0) < (instances:Get(b.key).order or 0)
    end)
    return list
end

--- One boss view from an encounter; a group gathers its members' NPCs and loot.
function Access:BuildBoss(key, record)
    local encounters, npcs = store("EncounterStore"), store("NpcStore")
    local parts = { record }
    for _, field in ipairs({ "encounterID", "encounterKey" }) do
        for _, memberKey in ipairs(encounters:FindBy(field, key)) do
            parts[#parts + 1] = encounters:Get(memberKey)
        end
    end
    local itemIDs, seenItems = {}, {}
    local minLevel, maxLevel, mainNpc
    for _, part in ipairs(parts) do
        appendUnique(itemIDs, seenItems, part.itemIDs)
        for _, set in ipairs(part.lootSets or {}) do
            appendUnique(itemIDs, seenItems, set.itemIDs)
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
    return {
        key = key, name = encounters:GetLabel(key),
        level = levelText(minLevel, maxLevel), minLevel = minLevel, maxLevel = maxLevel,
        classification = (kind == "rare" and "rare") or (kind == "minor" and "minor") or nil,
        rare = kind == "rare", isMinor = kind == "minor", isChallenge = kind == "challenge",
        isEvent = kind == "event", holidayID = record.holidayID,
        npcID = mainNpc, displayID = npc and npc.displayID, icon = record.icon,
        description = encounters:GetText(key, "description"),
        itemIDs = itemIDs,
    }
end

--- A dungeon's (or wing's) bosses in boss-list order. Group members appear inside their group.
function Access:GetBosses(view)
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
        if not (record.encounterID or record.encounterKey) and record.wingKey == view.wingKey then
            entries[#entries + 1] = { key = key, order = record.order or 0, view = self:BuildBoss(key, record) }
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

--- Whether a boss matches the search: its name (for a simple query) or any of its loot.
function Access:BossMatches(boss, query)
    local Search = parent.Search
    local parsed = Search:Parse(query)
    if parsed.isEmpty then
        return true
    end
    if not Search:IsMultiConstraint(parsed) and strfind(strlower(boss.name or ""), parsed.raw, 1, true) then
        return true
    end
    for _, itemID in ipairs(boss.itemIDs or {}) do
        if Search:ItemMatches(itemID, parsed) then
            return true
        end
    end
    return false
end

--- Whether a grid entry matches the search: name, location, levels, aliases, a wing, a boss or any loot.
function Access:DungeonMatches(view, query)
    local q = strlower(query or ""):match("^%s*(.-)%s*$")
    if q == "" then
        return true
    end
    for _, text in ipairs({ view.fullName, view.location, view.level }) do
        if text and strfind(strlower(text), q, 1, true) then
            return true
        end
    end
    for _, alias in ipairs(view.aliases or {}) do
        if strfind(strlower(alias), q, 1, true) then
            return true
        end
    end
    local targets = view.wingCount > 0 and self:GetWings(view) or { view }
    for _, target in ipairs(targets) do
        if target ~= view and self:DungeonMatches(target, query) then
            return true
        end
        for _, boss in ipairs(self:GetBosses(target)) do
            if self:BossMatches(boss, query) then
                return true
            end
        end
        if self:BossMatches({ itemIDs = target.zoneItemIDs }, query) then
            return true
        end
    end
    return false
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
            return self:GetDungeon(region.wingKey)
        end
    end
end

--- The dungeon the player is inside, or nil outside a dungeon or in one not in the catalog. In an instance
--- with wings, the wing the current subzone belongs to; the instance itself when the subzone has no wing.
function Access:GetCurrentInstanceDungeon()
    if not GetInstanceInfo then
        return nil
    end
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" or not instanceID then
        return nil
    end
    local dungeon = self:GetDungeon(instanceID)
    if dungeon and dungeon.wingCount > 0 and GetSubZoneText then
        return self:GetWingBySubzone(instanceID, GetSubZoneText()) or dungeon
    end
    return dungeon
end

--- Forgets cached views (after a data change).
function Access:ClearCache()
    for key in pairs(viewCache) do viewCache[key] = nil end
    for key in pairs(bossCache) do bossCache[key] = nil end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Data.DungeonAccess = Access
