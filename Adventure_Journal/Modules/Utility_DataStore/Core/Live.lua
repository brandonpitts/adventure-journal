-- ============================================================================
-- Utility_DataStore - Core/Live.lua
-- Asks the client for values it can answer by ID (names of items, quests,
-- spells, instances, maps and cached NPCs). Starts async loads when needed,
-- keeps answers for the session, and tells listeners when a load finishes.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local type = type
local ipairs = ipairs
local tostring = tostring
local wipe = wipe
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local C_Item = C_Item
local C_QuestLog = C_QuestLog
local C_Spell = C_Spell
local C_Map = C_Map
local C_TooltipInfo = C_TooltipInfo
local GetRealZoneText = GetRealZoneText
local issecretvalue = issecretvalue
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Session cache of answers the client gave: kind -> id -> value
local cache = {}
-- Loads asked for and not yet answered: kind -> id -> true
local pending = {}
-- Listeners called once per frame with { kind = { [id] = true } } for finished loads
local listeners = {}
local changed, flushScheduled = {}, false

local function remember(kind, id, value)
    -- The client can hide an answer as a secret value (e.g. NPC names inside instances), which can't be compared
    -- or shown as data: treated as no answer, so the store's own value is used
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    if value == nil or value == "" then
        return nil
    end
    cache[kind] = cache[kind] or {}
    cache[kind][id] = value
    return value
end

local function flush()
    flushScheduled = false
    local batch = changed
    changed = {}
    for _, listener in ipairs(listeners) do
        listener(batch)
    end
end

local function markLoaded(kind, id)
    if not (pending[kind] and pending[kind][id]) then
        return
    end
    pending[kind][id] = nil
    changed[kind] = changed[kind] or {}
    changed[kind][id] = true
    if not flushScheduled then
        flushScheduled = true
        C_Timer.After(0, flush)
    end
end

local function requestLoad(kind, id, request)
    pending[kind] = pending[kind] or {}
    if not pending[kind][id] then
        pending[kind][id] = true
        request(id)
    end
end

-- Name resolvers per kind. Each returns the name now, or nil (and may start a load).
local RESOLVERS = {
    item = function(id)
        local name = C_Item.GetItemNameByID(id)
        if not name and C_Item.GetItemInfoInstant(id) then
            requestLoad("item", id, C_Item.RequestLoadItemDataByID)
        end
        return name
    end,
    quest = function(id)
        local title = C_QuestLog.GetTitleForQuestID(id)
        if not title then
            requestLoad("quest", id, C_QuestLog.RequestLoadQuestByID)
        end
        return title
    end,
    spell = function(id)
        local info = C_Spell.GetSpellInfo(id)
        if not info then
            requestLoad("spell", id, C_Spell.RequestLoadSpellData)
        end
        return info and info.name
    end,
    instance = function(id)
        return GetRealZoneText(id)
    end,
    uiMap = function(id)
        local info = C_Map.GetMapInfo(id)
        return info and info.name
    end,
    -- Outdoor zones and subzones by area ID
    area = function(id)
        return C_Map.GetAreaInfo(id)
    end,
    -- The client names an NPC by ID only when it has the creature cached
    npc = function(id)
        local data = C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-" .. tostring(id) .. "-0")
        local line = data and data.lines and data.lines[1]
        return line and line.leftText
    end,
}

-- Existence checks per kind: true, false, or nil when the client can't tell.
local EXISTS = {
    item = function(id)
        return C_Item.GetItemInfoInstant(id) ~= nil
    end,
}

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Live = {}

--- The client's name for a record, or nil. May start an async load; listeners hear when it lands.
--- @param kind string item | quest | spell | instance | uiMap | area | npc
--- @param id number
function Live:GetName(kind, id)
    if type(id) ~= "number" then
        return nil
    end
    local known = cache[kind] and cache[kind][id]
    if known then
        return known
    end
    local resolve = RESOLVERS[kind]
    return resolve and remember(kind, id, resolve(id))
end

--- Whether the client has this record: true, false, or nil when the client can't tell.
function Live:Exists(kind, id)
    local check = EXISTS[kind]
    if not check or type(id) ~= "number" then
        return nil
    end
    return check(id)
end

--- Registers `callback(changes)`, called once per frame when async loads finish.
function Live:AddListener(callback)
    listeners[#listeners + 1] = callback
end

--- Drops the session cache and listeners (used when the DataStore unloads).
function Live:Reset()
    wipe(cache)
    wipe(pending)
    wipe(listeners)
    changed = {}
end

-- ----------------------------------------------------------------------------
-- 4. Event Wiring & Namespace Attachment
-- ----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("SPELL_DATA_LOAD_RESULT")
eventFrame:SetScript("OnEvent", function(_, event, id)
    if event == "ITEM_DATA_LOAD_RESULT" then
        markLoaded("item", id)
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        markLoaded("quest", id)
    elseif event == "SPELL_DATA_LOAD_RESULT" then
        markLoaded("spell", id)
    end
end)

Live.eventFrame = eventFrame
DataStore.Live = Live
