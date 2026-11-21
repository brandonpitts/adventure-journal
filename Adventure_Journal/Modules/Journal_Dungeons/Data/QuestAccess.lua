-- ============================================================================
-- Journal_Dungeons - Data/QuestAccess.lua
-- The dungeon quest questions the Dungeons screens ask, answered from the
-- DataStore (QuestStore, NpcStore, FixtureStore, ItemStore). Quest Source and
-- Turn In are built from links: the giver's name, its
-- hint or zone, and its map point. Player state (completed, in the log) is read
-- live from the client and never stored.
--   quest view: id, name, level, questLevel, reqLevel, faction, classOnly, baseXP, objective,
--               pickup, turnin, rewardItems, rewardChoice, isChain
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local sort = table.sort
local strupper = string.upper
local C_Item = C_Item
local C_QuestLog = C_QuestLog
local UnitFactionGroup = UnitFactionGroup
local UnitClass = UnitClass

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Session caches: questID -> view; shown giver name -> { store, key } (for map lookups by name)
local questCache, linkByName = {}, {}

-- A store, or nil when the DataStore is off; every public call checks first
---@return any
local function store(name)
    local DataStore = parent.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore[name] or nil
end

-- The first map point of an NPC or fixture: { mapID, x, y, label, targetName }
local function spawnPoint(storeName, key, label)
    local record = store(storeName):Get(key)
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

-- Describes one startedBy / endedBy entry: name, where, and what it is
local function describe(entry)
    if entry.npcID then
        local name = store("NpcStore"):GetLabel(entry.npcID)
        linkByName[name] = { "NpcStore", entry.npcID }
        return { kind = "npc", key = entry.npcID, name = name, where = whereText("NpcStore", entry.npcID) }
    elseif entry.fixtureID then
        local name = store("FixtureStore"):GetLabel(entry.fixtureID)
        linkByName[name] = { "FixtureStore", entry.fixtureID }
        return { kind = "fixture", key = entry.fixtureID, name = name, where = whereText("FixtureStore", entry.fixtureID) }
    elseif entry.itemID then
        local items = store("ItemStore")
        local source = items:GetObtainedFrom(entry.itemID)[1]
        local where = source and source.kind == "encounter"
            and ("dropped by " .. store("EncounterStore"):GetLabel(source.key)) or nil
        return { kind = "item", key = entry.itemID, name = items:GetLabel(entry.itemID), where = where }
    end
end

-- "Name, where" for a quest field; the quest's own hint when nothing is linked
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
    local isChain = false
    for _, requirement in ipairs(record.requires or {}) do
        isChain = isChain or requirement.questID ~= nil
    end
    local view = {
        id = questID, name = quests:GetLabel(questID),
        questLevel = record.questLevel, level = record.questLevel, reqLevel = record.requiredLevel,
        faction = record.faction or "Both", classOnly = record.classes and record.classes[1],
        baseXP = record.xp, objective = quests:GetText(questID, "objective"),
        rewardItems = record.rewardItemIDs, rewardChoice = record.rewardChoice, isChain = isChain,
    }
    view.pickup, view.giver = sentence(questID, "startedBy")
    view.turnin, view.turninGiver = sentence(questID, "endedBy")
    return view
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

--- A dungeon's (or wing's) quests, filtered by faction ("All" for both) and class ("All" for any),
--- sorted by required level, then name. A wing also shows its instance's quests that name no wing.
--- A chain with several steps here is listed once, as its last step.
function QuestAccess:GetDungeonQuests(view, factionFilter, classFilter)
    local quests = store("QuestStore")
    if not quests or not view then
        return {}
    end
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
    local faction = factionFilter or UnitFactionGroup("player")
    local _, playerClass = UnitClass("player")
    local class = classFilter or playerClass
    local shown = {}
    for _, questID in ipairs(ids) do
        local quest = self:GetQuest(questID)
        local factionOk = faction == "All" or quest.faction == "Both" or quest.faction == faction
        local classOk = not quest.classOnly or class == "All" or strupper(quest.classOnly) == class
        if factionOk and classOk then
            shown[#shown + 1] = quest
        end
    end
    -- One entry per chain: a quest that is an earlier step of another listed quest's chain is
    -- reached through that quest's chain view
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

--- The whole chain ending in `questID`, prerequisites first (walking `requires`), or nil without one.
function QuestAccess:GetFullChain(questID)
    local quests = store("QuestStore")
    if not quests or not quests:Get(questID) then
        return nil
    end
    local order = prerequisites(questID)
    if #order == 0 then
        return nil
    end
    order[#order + 1] = questID
    local chain = {}
    for i, id in ipairs(order) do
        local quest = self:GetQuest(id)
        chain[i] = {
            id = id, name = quest.name, stepIndex = i, totalSteps = #order,
            level = quest.questLevel or 0, reqLevel = quest.reqLevel or 0,
            objective = quest.objective or "No objective description available.",
            pickup = quest.pickup or "Unknown", turnin = quest.turnin or quest.pickup or "Unknown",
            map = self:GetQuestMap(id), rewardItems = quest.rewardItems, rewardChoice = quest.rewardChoice,
            baseXP = quest.baseXP, isDungeonQuest = (id == questID),
            isCompleted = self:IsQuestCompleted(id), isActive = self:IsQuestActive(id),
        }
    end
    return chain
end

--- The quest giver's map point, or nil.
function QuestAccess:GetQuestMap(questID)
    local quest = self:GetQuest(questID)
    local giver = quest and quest.giver
    if giver and (giver.kind == "npc" or giver.kind == "fixture") then
        return spawnPoint(giver.kind == "npc" and "NpcStore" or "FixtureStore", giver.key, giver.name)
    end
end

--- The map point of an NPC or object by the name shown in a Quest Source or Turn In line.
function QuestAccess:FindMapForNpc(text)
    local name = text and (text:match("^(.-),") or text):gsub("%s*%(.-%)", ""):match("^%s*(.-)%s*$")
    local link = name and linkByName[name]
    if link then
        return spawnPoint(link[1], link[2], name)
    end
end

--- Who starts the quest: { isItem, giverName, location, npcID, displayID, itemIcon, isChain }.
--- Items and objects count as items (they show an icon, not a portrait).
function QuestAccess:GetQuestGiverInfo(quest, dungeonName, dungeonLocation)
    local info = { isItem = false, giverName = "", location = "", isChain = quest and quest.isChain or false }
    local giver = quest and quest.giver
    if not giver then
        info.giverName = quest and quest.pickup or "Unknown"
        return info
    end
    info.giverName = giver.name
    if giver.kind == "npc" then
        local npc = store("NpcStore"):Get(giver.key)
        info.npcID, info.displayID, info.location = giver.key, npc and npc.displayID, giver.where or ""
    elseif giver.kind == "fixture" then
        local fixture = store("FixtureStore"):Get(giver.key)
        info.isItem, info.itemIcon, info.location = true, fixture and fixture.icon, giver.where or ""
    else
        info.isItem = true
        info.itemIcon = C_Item.GetItemIconByID(giver.key)
        info.location = dungeonLocation or dungeonName or ""
    end
    return info
end

--- Whether the player has completed the quest.
function QuestAccess:IsQuestCompleted(questID)
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return ok and done == true
end

--- Whether the quest is in the player's quest log.
function QuestAccess:IsQuestActive(questID)
    local ok, onQuest = pcall(C_QuestLog.IsOnQuest, questID)
    return ok and onQuest == true
end

--- Forgets cached quest views (after a data change or a title load).
function QuestAccess:ClearCache()
    for key in pairs(questCache) do questCache[key] = nil end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Data.QuestAccess = QuestAccess

-- Quest titles and NPC names arrive from the client later; cached views rebuild with them
local liveData = parent.DataStore and parent.DataStore.Live
if liveData then
    liveData:AddListener(function()
        QuestAccess:ClearCache()
    end)
end
