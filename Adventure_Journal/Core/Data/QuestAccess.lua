-- ============================================================================
-- Adventure Journal - Core/Data/QuestAccess.lua
-- The data feed for quests, from the DataStore (QuestStore, NpcStore,
-- FixtureStore, ItemStore). Source and Turn-In come from links: the giver's
-- name, hint or zone, whether it is inside an instance, and its map point.
-- Player state is read live. Missing values stay nil; templates show them.
--   quest view: id, name, level, questLevel, reqLevel, faction, classOnly (first of classes), classes, baseXP, objective,
--               pickup, giver, turnin, turninGiver, rewardItems, rewardChoice, isQuestline
--   giver:      kind ("npc" | "fixture" | "item"), key, name, where, inside, point
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local select = select
local sort = table.sort
local strupper = string.upper
local C_Item = C_Item
local UnitFactionGroup = UnitFactionGroup
local UnitClass = UnitClass

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Session cache: questID -> view
local questCache = {}

-- A store, or nil when the DataStore is off; every public call checks first
---@return any
local function store(name)
    local DataStore = ns.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore[name] or nil
end

-- The first map point of an NPC or fixture record: { mapID, x, y, label, targetName }
local function spawnPoint(record, label)
    local spawn = record and record.spawns and record.spawns[1]
    if spawn then
        return { mapID = spawn.uiMapID, x = spawn.x, y = spawn.y, label = label, targetName = label }
    end
end

-- Where a giver stands: its first hint, else the zone of its first spawn
local function whereText(storeName, key)
    local giverStore = store(storeName)
    local hint = giverStore:GetHints(key, "spawns")[1]
    if hint then
        return hint.text
    end
    local record = giverStore:Get(key)
    local spawn = record and record.spawns and record.spawns[1]
    return spawn and store("ZoneStore"):GetLabel(spawn.uiMapID)
end

-- An NPC or fixture giver: inside an instance when its record names one
local function standingGiver(kind, storeName, key)
    local record = store(storeName):Get(key)
    local name = store(storeName):GetLabel(key)
    return { kind = kind, key = key, name = name, where = whereText(storeName, key),
        inside = record ~= nil and record.instanceID ~= nil, point = spawnPoint(record, name) }
end

-- Describes one startedBy / endedBy entry (see the giver shape above)
local function describe(entry)
    if entry.npcID then
        return standingGiver("npc", "NpcStore", entry.npcID)
    elseif entry.fixtureID then
        return standingGiver("fixture", "FixtureStore", entry.fixtureID)
    elseif entry.itemID then
        local items = store("ItemStore")
        local source = items:GetObtainedFrom(entry.itemID)[1]
        local where = source and source.kind == "encounter"
            and ("dropped by " .. store("EncounterStore"):GetLabel(source.key)) or nil
        return { kind = "item", key = entry.itemID, name = items:GetLabel(entry.itemID), where = where,
            inside = true, icon = C_Item.GetItemIconByID(entry.itemID) }
    end
end

-- "Name, where" for a quest field, and its giver; the quest's own hint when nothing is linked
local function sentence(questID, field)
    local quests = store("QuestStore")
    local record = quests:Get(questID)
    local giver = record[field] and record[field][1] and describe(record[field][1])
    local hint = quests:GetHints(questID, field)[1]
    if not giver then
        return hint and hint.text or nil, nil
    end
    local where = (giver.kind == "item" and hint and hint.text) or giver.where
    return where and (giver.name .. ", " .. where) or giver.name, giver
end

-- Every quest `questID` requires, directly or through its prerequisites, earliest first
local function prerequisites(questID)
    local quests = store("QuestStore")
    local order, seen = {}, {}
    local function walk(id)
        for _, requirement in ipairs(quests:Get(id).requires or {}) do
            local required = requirement.questID
            if required and not seen[required] and quests:Get(required) then
                seen[required] = true
                walk(required)
                order[#order + 1] = required
            end
        end
    end
    walk(questID)
    return order
end

local function buildQuest(questID)
    local quests = store("QuestStore")
    local record = quests:Get(questID)
    if not record then
        return nil
    end
    local isQuestline = false
    for _, requirement in ipairs(record.requires or {}) do
        isQuestline = isQuestline or requirement.questID ~= nil
    end
    local view = {
        id = questID, name = quests:GetLabel(questID),
        questLevel = record.questLevel, level = record.questLevel, reqLevel = record.requiredLevel,
        faction = record.faction or "Both", classOnly = record.classes and record.classes[1], classes = record.classes,
        baseXP = record.xp, objective = quests:GetText(questID, "objective"),
        rewardItems = record.rewardItemIDs, rewardChoice = record.rewardChoice, isQuestline = isQuestline,
    }
    view.pickup, view.giver = sentence(questID, "startedBy")
    view.turnin, view.turninGiver = sentence(questID, "endedBy")
    return view
end

-- The quest IDs listed for an instance (or wing) view; a wing also takes its instance's quests that name no wing
local function instanceQuestIDs(quests, view)
    local ids, seen = {}, {}
    local function add(list, onlyWithoutWing)
        for _, questID in ipairs(list) do
            if not seen[questID] and not (onlyWithoutWing and quests:Get(questID).wingKeys) then
                seen[questID] = true
                ids[#ids + 1] = questID
            end
        end
    end
    if view.wingKey then
        add(quests:FindBy("wingKeys", view.wingKey))
        add(quests:FindBy("instanceIDs", view.instanceID), true)
    else
        add(quests:FindBy("instanceIDs", view.instanceID))
    end
    return ids
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local QuestAccess = {}

--- True when quests can be shown (the DataStore is on).
function QuestAccess:IsAvailable()
    return store("QuestStore") ~= nil
end

--- One quest's view, built once per session.
function QuestAccess:GetQuest(questID)
    if not questCache[questID] then
        questCache[questID] = store("QuestStore") and buildQuest(questID) or nil
    end
    return questCache[questID]
end

--- Whether `quest` passes the faction ("All" for both) and class ("All" for any) filters.
function QuestAccess:Passes(quest, factionFilter, classFilter)
    local faction = factionFilter or UnitFactionGroup("player")
    local class = classFilter or select(2, UnitClass("player"))
    local factionOk = faction == "All" or quest.faction == "Both" or quest.faction == faction
    local classOk = not quest.classOnly or class == "All"
    for _, allowed in ipairs(quest.classes or { quest.classOnly }) do
        classOk = classOk or strupper(allowed) == class
    end
    return factionOk and classOk
end

--- An instance's (or wing's) quests, filtered by faction and class (QuestAccess:Passes), sorted by required
--- level, then name. A questline with several steps here is listed once, as its last step.
function QuestAccess:GetInstanceQuests(view, factionFilter, classFilter)
    local quests = store("QuestStore")
    if not quests or not view then
        return {}
    end
    local shown = {}
    for _, questID in ipairs(instanceQuestIDs(quests, view)) do
        local quest = self:GetQuest(questID)
        if self:Passes(quest, factionFilter, classFilter) then
            shown[#shown + 1] = quest
        end
    end
    -- One entry per questline: a quest that is an earlier step of another listed quest's questline is
    -- reached through that quest's questline view
    local earlierStep = {}
    for _, quest in ipairs(shown) do
        for _, required in ipairs(prerequisites(quest.id)) do
            earlierStep[required] = true
        end
    end
    local results = {}
    for _, quest in ipairs(shown) do
        if not earlierStep[quest.id] then
            results[#results + 1] = quest
        end
    end
    sort(results, function(a, b)
        local la = (a.reqLevel and a.reqLevel > 0 and a.reqLevel) or a.questLevel or 0
        local lb = (b.reqLevel and b.reqLevel > 0 and b.reqLevel) or b.questLevel or 0
        if la ~= lb then return la < lb end
        return (a.name or "") < (b.name or "")
    end)
    return results
end

--- The quests an instance's attunement lists (`view.attunement.questIDs`, the quests that award what lets you in),
--- passing the faction and class filters, in the attunement's order.
function QuestAccess:GetAttunementQuests(view, factionFilter, classFilter)
    local results = {}
    if not store("QuestStore") or not (view and view.attunement) then
        return results
    end
    for _, questID in ipairs(view.attunement.questIDs or {}) do
        local quest = self:GetQuest(questID)
        if quest and self:Passes(quest, factionFilter, classFilter) then
            results[#results + 1] = quest
        end
    end
    return results
end

--- Whether an instance (or wing) has any quest, its own or its attunement's, passing the filters; cheaper than
--- listing them.
function QuestAccess:HasInstanceQuests(view, factionFilter, classFilter)
    local quests = store("QuestStore")
    if not quests or not view then
        return false
    end
    for _, questID in ipairs(instanceQuestIDs(quests, view)) do
        if self:Passes(self:GetQuest(questID), factionFilter, classFilter) then
            return true
        end
    end
    return #self:GetAttunementQuests(view, factionFilter, classFilter) > 0
end

--- The whole questline ending in `questID`, prerequisites first (walking `requires`), or nil without one.
--- Each step: `{ id, quest (its view), stepIndex, totalSteps, isDungeonQuest, isCompleted, isActive }`.
function QuestAccess:GetQuestline(questID)
    local quests = store("QuestStore")
    if not quests or not quests:Get(questID) then
        return nil
    end
    local order = prerequisites(questID)
    if #order == 0 then
        return nil
    end
    order[#order + 1] = questID
    local questline = {}
    for i, id in ipairs(order) do
        questline[i] = {
            id = id, quest = self:GetQuest(id), stepIndex = i, totalSteps = #order, isDungeonQuest = (id == questID),
            isCompleted = self:IsQuestCompleted(id), isActive = self:IsQuestActive(id),
        }
    end
    return questline
end

--- Whether the player has completed the quest.
function QuestAccess:IsQuestCompleted(questID)
    return ns.GameApi:IsQuestCompleted(questID)
end

--- Whether the quest is in the player's quest log.
function QuestAccess:IsQuestActive(questID)
    return ns.GameApi:IsQuestActive(questID)
end

--- Forgets cached quest views (after a data change or a title load).
function QuestAccess:ClearCache()
    for key in pairs(questCache) do questCache[key] = nil end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Data = ns.Data or {}
ns.Data.QuestAccess = QuestAccess

-- Quest titles and NPC names arrive from the client later; cached views rebuild with them
local liveData = ns.DataStore and ns.DataStore.Live
if liveData then
    liveData:AddListener(function()
        QuestAccess:ClearCache()
    end)
end
