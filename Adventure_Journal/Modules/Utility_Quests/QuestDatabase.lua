-- ============================================================================
-- Utility_Quests - QuestDatabase.lua
-- Central quest storage and query engine for Adventure Journal.
-- Provides tag-indexed search, dynamic player-level relative XP evaluation,
-- bi-directional reward item indexing, prerequisite resolution, and map lookup.
-- ============================================================================
local addonName, parent = ...
parent.Utility_Quests = parent.Utility_Quests or {}
local ns = parent.Utility_Quests

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local type = type
local tonumber = tonumber
local tostring = tostring
local pcall = pcall
local math = math
local table = table
local UnitLevel = UnitLevel
local UnitFactionGroup = UnitFactionGroup
local GetQuestLogRewardXP = GetQuestLogRewardXP
local C_QuestLog = C_QuestLog
local strfind = string.find
local strlower = string.lower

-- ----------------------------------------------------------------------------
-- 2. QuestDatabase Definition & Storage
-- ----------------------------------------------------------------------------
local QuestDatabase = {
    isInitialized = false,
    Catalog = {},             -- [questID] = record
    DungeonQuests = {},       -- [dungeonID] = { questID1, questID2, ... }
    Chains = {},              -- [questID] = { { id = ..., name = "..." }, ... }
    Maps = {},                -- [questID] = { mapID = ..., x = ..., y = ..., ... }
    Shareability = {},        -- [questID] = boolean
    TagIndex = {},            -- [canonicalTag] = { [questID] = true }
    RewardItemToQuests = {},  -- [itemID] = { questID1, ... }
    ClientRewardsCache = {},  -- [questID] = { xp = number, money = number, timestamp = number }
}

-- Hidden tooltip scanner frame for client quest reward querying
local questScannerTooltip = nil
local function getScannerTooltip()
    if not questScannerTooltip then
        questScannerTooltip = CreateFrame("GameTooltip", "AdventureJournalQuestScannerTooltip", nil, "GameTooltipTemplate")
        questScannerTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return questScannerTooltip
end

--- Safely parses an experience amount from text (e.g. "1,550 XP" or "Experience: 2,400").
local function parseXPFromText(text)
    if not text or type(text) ~= "string" then return nil end
    local clean = text:gsub(",", ""):gsub(" ", "")
    local xpMatch = clean:match("(%d+)XP") or clean:match("(%d+)Experience") or clean:match("Experience:(%d+)")
    if xpMatch then
        return tonumber(xpMatch)
    end
    return nil
end

--- Safely parses a copper monetary amount from text or coin textures in tooltip lines.
local function parseMoneyFromText(text)
    if not text or type(text) ~= "string" then return nil end
    local gold = tonumber(text:match("(%d+)%s*Gold") or text:match("(%d+)%s*|TInterface\\MoneyFrame\\UI%-GoldIcon")) or 0
    local silver = tonumber(text:match("(%d+)%s*Silver") or text:match("(%d+)%s*|TInterface\\MoneyFrame\\UI%-SilverIcon")) or 0
    local copper = tonumber(text:match("(%d+)%s*Copper") or text:match("(%d+)%s*|TInterface\\MoneyFrame\\UI%-CopperIcon")) or 0
    local total = (gold * 10000) + (silver * 100) + copper
    return total > 0 and total or nil
end

-- ----------------------------------------------------------------------------
-- 3. Initialization & Indexing
-- ----------------------------------------------------------------------------
function QuestDatabase:Init()
    if self.isInitialized then
        return
    end

    self.Catalog = ns.QuestsCatalog or {}
    self.DungeonQuests = ns.QuestsDungeons or {}
    self.Chains = ns.QuestsChains or {}
    self.PrereqDetails = ns.QuestsPrereqDetails or {}
    self.Maps = ns.QuestsMaps or {}
    self.Shareability = ns.QuestsShareability or {}
    self.NpcIds = ns.QuestsNpcIds or {}
    self.NpcDisplayIds = ns.QuestsNpcDisplayIds or {}
    self.ItemIcons = ns.QuestsItemIcons or {}
    self.TagIndex = {}
    self.RewardItemToQuests = {}
    self.ClientRewardsCache = {}

    -- Build Inverted Tag Index & Reward Item Link Index
    for qId, rec in pairs(self.Catalog) do
        -- 1. Index Tags
        if rec.tags and type(rec.tags) == "table" then
            for _, tag in ipairs(rec.tags) do
                local bucket = self.TagIndex[tag]
                if not bucket then
                    bucket = {}
                    self.TagIndex[tag] = bucket
                end
                bucket[qId] = true
            end
        end

        -- 2. Index Reward Item IDs
        if rec.rewardItems and type(rec.rewardItems) == "table" then
            for _, itId in ipairs(rec.rewardItems) do
                local list = self.RewardItemToQuests[itId]
                if not list then
                    list = {}
                    self.RewardItemToQuests[itId] = list
                end
                list[#list + 1] = qId
            end
        end
    end

    self.isInitialized = true
end

--- Purges all quest tables and caches from memory when the module is unloaded/disabled.
function QuestDatabase:Unload()
    self.Catalog = {}
    self.DungeonQuests = {}
    self.Chains = {}
    self.Maps = {}
    self.Shareability = {}
    self.TagIndex = {}
    self.RewardItemToQuests = {}
    self.ClientRewardsCache = {}
    self.isInitialized = false
    if collectgarbage then
        collectgarbage("collect")
    end
end

-- ----------------------------------------------------------------------------
-- 4. Retrieval & Query Methods
-- ----------------------------------------------------------------------------

--- Retrieves a quest record by ID.
--- @param questID number
--- @return table|nil
function QuestDatabase:GetQuest(questID)
    if not self.isInitialized then self:Init() end
    return questID and self.Catalog[questID] or nil
end

--- Retrieves all quests associated with a dungeon, optionally filtered by faction and class.
--- @param dungeonID string Canonical dungeon ID (e.g. "wailing_caverns")
--- @param factionFilter string|nil "Alliance" | "Horde" | "All" | nil (defaults to player faction if nil)
--- @param classFilter string|nil English uppercase class (e.g. "PALADIN", "All", nil defaults to player class)
--- @return table Array of quest records sorted by reqLevel then name
function QuestDatabase:GetDungeonQuests(dungeonID, factionFilter, classFilter)
    if not self.isInitialized then self:Init() end
    if not dungeonID then return {} end

    local qIds = self.DungeonQuests[dungeonID]
    if not qIds or #qIds == 0 then
        return {}
    end

    local playerFaction = UnitFactionGroup("player") or "Both"
    local filter = factionFilter or playerFaction

    local _, playerClass = UnitClass("player")
    local cFilter = classFilter or playerClass

    local results = {}
    for _, qId in ipairs(qIds) do
        local q = self.Catalog[qId]
        if q then
            local matchesFaction = true
            if filter and filter ~= "All" then
                matchesFaction = (q.faction == "Both") or (q.faction == filter)
            end

            local matchesClass = true
            local questClass = q.classOnly
            if not questClass and q.tags then
                for _, t in ipairs(q.tags) do
                    local c = t:match("^CLASS:(.+)$")
                    if c then
                        questClass = c
                        break
                    end
                end
            end

            if questClass and questClass ~= "" and questClass ~= "All" then
                if cFilter and cFilter ~= "All" then
                    matchesClass = (questClass:upper() == cFilter:upper())
                end
            end

            if matchesFaction and matchesClass then
                results[#results + 1] = q
            end
        end
    end

    table.sort(results, function(a, b)
        local la = (a.reqLevel and a.reqLevel > 0 and a.reqLevel) or a.questLevel or 0
        local lb = (b.reqLevel and b.reqLevel > 0 and b.reqLevel) or b.questLevel or 0
        if la ~= lb then
            return la < lb
        end
        return (a.name or "") < (b.name or "")
    end)

    return results
end

--- Returns all quests that award a specific item ID.
--- @param itemID number
--- @return table Array of quest records
function QuestDatabase:GetQuestsForRewardItem(itemID)
    if not self.isInitialized then self:Init() end
    if not itemID then return {} end

    local qIds = self.RewardItemToQuests[itemID]
    if not qIds then return {} end

    local results = {}
    for _, qId in ipairs(qIds) do
        local q = self.Catalog[qId]
        if q then
            results[#results + 1] = q
        end
    end
    return results
end

--- Returns the prerequisite chain for a quest (if any).
--- @param questID number
--- @return table|nil Array of { id = number, name = string }
function QuestDatabase:GetQuestPrereqs(questID)
    if not self.isInitialized then self:Init() end
    return questID and self.Chains[questID] or nil
end

--- Returns detailed metadata for a prerequisite chain step.
--- @param stepID number
--- @return table|nil
function QuestDatabase:GetPrereqDetails(stepID)
    if not self.isInitialized then self:Init() end
    return stepID and self.PrereqDetails and self.PrereqDetails[stepID] or nil
end

--- Returns the complete ordered chain for a quest, including all prerequisite steps
--- and the final dungeon quest itself as the last step.
--- @param questID number
--- @return table|nil Array of ordered step objects
function QuestDatabase:GetFullChain(questID)
    if not self.isInitialized then self:Init() end
    if not questID then return nil end

    local prereqs = self.Chains[questID]
    if not prereqs or #prereqs == 0 then
        return nil
    end

    local chain = {}
    local totalSteps = #prereqs + 1

    for i, p in ipairs(prereqs) do
        local pDetails = (self.PrereqDetails and self.PrereqDetails[p.id]) or {}
        local step = {
            id = p.id,
            name = p.name or ("Quest #" .. tostring(p.id)),
            stepIndex = i,
            totalSteps = totalSteps,
            level = pDetails.level or p.level or 0,
            reqLevel = pDetails.requires or pDetails.reqLevel or p.requires or p.reqLevel or 0,
            objective = pDetails.objective or "No objective description available.",
            pickup = pDetails.pickup or "Unknown",
            turnin = pDetails.turnin or pDetails.pickup or "Unknown",
            map = pDetails.map or (self.Maps and self.Maps[p.id]),
            isDungeonQuest = false,
            isCompleted = self:IsQuestCompleted(p.id),
            isActive = self:IsQuestActive(p.id),
        }
        table.insert(chain, step)
    end

    local finalRec = self.Catalog[questID] or {}
    local finalStep = {
        id = questID,
        name = finalRec.name or ("Quest #" .. tostring(questID)),
        stepIndex = totalSteps,
        totalSteps = totalSteps,
        level = finalRec.questLevel or finalRec.level or finalRec.reqLevel or 0,
        reqLevel = finalRec.reqLevel or 0,
        objective = finalRec.objective or "No objective description available.",
        pickup = finalRec.pickup or "Unknown",
        turnin = finalRec.turnin or finalRec.pickup or "Unknown",
        map = self.Maps and self.Maps[questID],
        rewardItems = finalRec.rewardItems,
        rewardChoice = finalRec.rewardChoice,
        baseXP = finalRec.baseXP,
        isDungeonQuest = true,
        isCompleted = self:IsQuestCompleted(questID),
        isActive = self:IsQuestActive(questID),
    }
    table.insert(chain, finalStep)

    return chain
end

--- Returns world map coordinates and quest-giver info for a quest.
--- @param questID number
--- @return table|nil { mapID, x, y, label, targetName, detail }
function QuestDatabase:GetQuestMap(questID)
    if not self.isInitialized then self:Init() end
    if not questID then return nil end
    local num = tonumber(questID)
    if num and self.Maps and self.Maps[num] then
        return self.Maps[num]
    end
    if self.Maps and self.Maps[questID] then
        return self.Maps[questID]
    end
    return nil
end

--- Finds world map coordinates for an NPC by searching known quest map entries.
--- @param npcName string
--- @return table|nil { mapID, x, y, label, targetName, detail }
function QuestDatabase:FindMapForNpc(npcName)
    if not self.isInitialized then self:Init() end
    if not npcName or npcName == "" or npcName == "Unknown" then return nil end
    local cleanName = npcName:gsub("%s*%(.-%)", ""):match("^(.-),") or npcName:gsub("%s*%(.-%)", "")
    cleanName = cleanName:match("^%s*(.-)%s*$")
    if not cleanName or cleanName == "" then return nil end
    local lowerClean = cleanName:lower()

    if self.Maps then
        for _, m in pairs(self.Maps) do
            if m.targetName and m.targetName ~= "" and m.targetName:lower() == lowerClean then
                return m
            elseif m.label and m.label:lower():find(lowerClean, 1, true) then
                return m
            end
        end
    end
    if self.PrereqDetails then
        for _, p in pairs(self.PrereqDetails) do
            if p.map then
                if p.map.targetName and p.map.targetName ~= "" and p.map.targetName:lower() == lowerClean then
                    return p.map
                elseif p.map.label and p.map.label:lower():find(lowerClean, 1, true) then
                    return p.map
                end
            end
        end
    end
    return nil
end

--- Returns creature ID for an NPC name.
--- @param npcName string
--- @return number|nil
function QuestDatabase:GetNpcID(npcName)
    if not self.isInitialized then self:Init() end
    if not npcName or npcName == "" then return nil end
    local id = self.NpcIds and self.NpcIds[npcName]
    if id then return id end
    -- Clean away coordinates or trailing descriptions
    local cleanName = npcName:gsub("%s*%(.-%)", ""):match("^%s*(.-)%s*$")
    if cleanName and self.NpcIds and self.NpcIds[cleanName] then
        return self.NpcIds[cleanName]
    end
    return nil
end

--- Retrieves the authentic 3D creature display ID for an NPC name.
--- @param npcName string
--- @return number|nil
function QuestDatabase:GetNpcDisplayID(npcName)
    if not self.isInitialized then self:Init() end
    if not npcName or npcName == "" then return nil end
    local cleanName = npcName:gsub("%s*%(.-%)", ""):match("^%s*(.-)%s*$")
    if self.NpcDisplayIds and self.NpcDisplayIds[cleanName] then
        return self.NpcDisplayIds[cleanName]
    end
    if self.NpcDisplayIds then
        local lower = cleanName:lower()
        for k, v in pairs(self.NpcDisplayIds) do
            if k:lower() == lower then
                return v
            end
        end
    end
    return nil
end

--- Retrieves the pre-mapped icon texture path for a quest-starting item.
--- @param itemName string
--- @return string|nil
function QuestDatabase:GetItemIcon(itemName)
    if not self.isInitialized then self:Init() end
    if not itemName or itemName == "" then return nil end
    local cleanName = itemName:gsub("%s*%(.-%)", ""):match("^%s*(.-)%s*$")
    if self.ItemIcons and self.ItemIcons[cleanName] then
        return self.ItemIcons[cleanName]
    end
    if self.ItemIcons then
        local lower = cleanName:lower()
        for k, v in pairs(self.ItemIcons) do
            if k:lower() == lower then
                return v
            end
        end
    end
    return nil
end

--- Sanitizes raw pickup locations to strict Sublocation and Location standards,
--- stripping all conversational directions, entrance hints, and corpse references.
--- @param rawLoc string
--- @param dungeonName string|nil
--- @return string
local function CleanLocationString(rawLoc, dungeonName)
    if not rawLoc or rawLoc == "" then
        return dungeonName or "Azeroth"
    end

    local loc = rawLoc

    -- 1. Remove parenthesized coordinates e.g. "(56.4, 47.5)" or "(56, 47)"
    loc = loc:gsub("%s*%(%d+%.?%d*,%s*%d+%.?%d*%)", "")

    -- 2. Strip conversational / directional prefixes and hints
    local prefixes = {
        "^[Aa]bove the entrance to%s*",
        "^[Bb]elow the entrance to%s*",
        "^[Oo]utside the entrance to%s*",
        "^[Ii]nside the entrance to%s*",
        "^[Nn]ear the entrance to%s*",
        "^[Aa]t the entrance to%s*",
        "^[Ee]ntrance to%s*",
        "^[Jj]ust outside the entrance to%s*",
        "^[Jj]ust inside the entrance to%s*",
        "^[Jj]ust outside%s*",
        "^[Jj]ust inside%s*",
        "^[Ii]n a cave above%s*",
        "^[Ii]n the cave above%s*",
        "^[Tt]aken from.-inside%s*",
        "^[Tt]aken from.-in%s*",
        "^[Tt]aken from%s*.-,%s*",
        "^[Dd]ropped by.-inside%s*",
        "^[Dd]ropped by.-in%s*",
        "^[Dd]ropped by%s*.-,%s*",
        "^[Ll]ooted from.-inside%s*",
        "^[Ll]ooted from%s*.-,%s*",
        "^[Ff]ound inside%s*",
        "^[Ff]ound in%s*",
        "^[Ii]nside%s*",
        "^[Oo]utside%s*",
    }

    for _, pat in ipairs(prefixes) do
        loc = loc:gsub(pat, "")
    end

    -- Trim whitespace
    loc = loc:match("^%s*(.-)%s*$") or loc

    -- If location became empty or generic, fall back to dungeon
    local lowerLoc = loc:lower()
    if loc == "" or lowerLoc == "the dungeon" or lowerLoc == "inside" or lowerLoc == "dungeon" then
        loc = dungeonName or "Azeroth"
    end

    return loc
end

--- Returns structured quest giver info (NPC or Item, giver name, location, display ID, item icon, and chain status).
--- @param quest table|number
--- @param dungeonName string|nil Optional dungeon name used as obtaining location for dungeon drops/items
--- @param dungeonLocation string|nil Optional full standard dungeon location string (e.g. "Ragefire Chasm, Orgrimmar")
--- @return table { isItem = boolean, giverName = string, location = string, npcID = number|nil, displayID = number|nil, itemIcon = string|nil, isChain = boolean }
function QuestDatabase:GetQuestGiverInfo(quest, dungeonName, dungeonLocation)
    if not self.isInitialized then self:Init() end
    if type(quest) == "number" then
        quest = self.Catalog[quest]
    end
    if not quest then
        return { isItem = false, giverName = "", location = "", npcID = nil, displayID = nil, itemIcon = nil, isChain = false }
    end

    local pickup = quest.pickup or ""
    local isItem = false
    local giverName = ""
    local location = ""
    local npcID = nil
    local displayID = nil
    local itemIcon = nil

    -- Check if quest is part of a prerequisite chain
    local isChain = false
    if quest.tags then
        for _, t in ipairs(quest.tags) do
            if t == "CHAIN" then
                isChain = true
                break
            end
        end
    end
    if not isChain and quest.id and self.Chains and self.Chains[quest.id] then
        local chainList = self.Chains[quest.id]
        if type(chainList) == "table" and #chainList > 0 then
            isChain = true
        end
    end

    local lowerPickup = pickup:lower()
    local isDropOrCorpse = lowerPickup:find("taken from") or lowerPickup:find("dropped by") or lowerPickup:find("corpse") or lowerPickup:find("looted in") or lowerPickup:find("inside")

    -- 1. Check for item-started or dungeon-drop quest
    if pickup:match("^[Ii]tem start:") or pickup:match("^[Uu]se the.-quest%-start item") or isDropOrCorpse then
        isItem = true
        if pickup:match("^[Ii]tem start:%s*(.-),") then
            giverName = pickup:match("^[Ii]tem start:%s*(.-),")
        elseif pickup:match("^[Ii]tem start:%s*(.*)") then
            giverName = pickup:match("^[Ii]tem start:%s*(.*)")
        elseif pickup:match("^[Uu]se the%s*(.-)%s*quest%-start item") then
            giverName = pickup:match("^[Uu]se the%s*(.-)%s*quest%-start item")
        elseif isDropOrCorpse and pickup:find(",") then
            giverName = pickup:match("^(.-),")
        else
            giverName = pickup ~= "" and pickup or "Quest Item"
        end

        giverName = giverName:match("^%s*(.-)%s*$") or giverName
        itemIcon = self:GetItemIcon(giverName)

        -- Obtaining location for dungeon drops/items follows standard dungeon location
        location = CleanLocationString(dungeonLocation or dungeonName, dungeonName)
    end

    -- 2. NPC-started quest
    if not isItem then
        local namePart, locPart = pickup:match("^(.-),%s*(.*)")
        if namePart and locPart then
            giverName = namePart
            location = locPart
        else
            giverName = pickup ~= "" and pickup or "Unknown"
            location = ""
        end

        -- Check map record for supplementary targetName or location if empty
        local mapRec = quest.id and self.Maps and self.Maps[quest.id]
        if mapRec then
            if (giverName == "" or giverName == "Unknown") and mapRec.targetName and mapRec.targetName ~= "" then
                giverName = mapRec.targetName
            end
            if location == "" and mapRec.label and mapRec.label ~= "" then
                local mapLoc = mapRec.label:match("—%s*(.*)") or mapRec.label:match("%-%s*(.*)")
                if mapLoc then
                    location = mapLoc
                end
            end
        end

        giverName = giverName:match("^%s*(.-)%s*$") or giverName
        npcID = self:GetNpcID(giverName)
        displayID = self:GetNpcDisplayID(giverName)
    end

    location = CleanLocationString(location, dungeonName)

    return {
        isItem = isItem,
        giverName = giverName,
        location = location,
        npcID = npcID,
        displayID = displayID,
        itemIcon = itemIcon,
        isChain = isChain,
    }
end

--- Checks if a quest can be shared with party members.
--- @param questID number
--- @return boolean
function QuestDatabase:IsQuestShareable(questID)
    if not self.isInitialized then self:Init() end
    if not questID then return false end

    -- Check audited table first
    if self.Shareability[questID] ~= nil then
        return self.Shareability[questID]
    end

    -- Runtime client fallback
    if C_QuestLog and C_QuestLog.IsPushableQuest then
        local ok, pushable = pcall(C_QuestLog.IsPushableQuest, questID)
        if ok and type(pushable) == "boolean" then
            return pushable
        end
    end

    return false
end

--- Checks if a quest has been completed by the current character.
--- @param questID number
--- @return boolean
function QuestDatabase:IsQuestCompleted(questID)
    if not questID then return false end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok and done then return true end
    end
    if _G.IsQuestFlaggedCompleted then
        local ok, done = pcall(_G.IsQuestFlaggedCompleted, questID)
        if ok and done then return true end
    end
    if _G.GetQuestsCompleted then
        if not self.completedQuestsCache then
            local cache = {}
            local ok, ret = pcall(_G.GetQuestsCompleted, cache)
            self.completedQuestsCache = (ok and (ret or cache)) or {}
        end
        if self.completedQuestsCache and self.completedQuestsCache[questID] then return true end
    end
    return false
end

--- Checks if a quest is currently active in the player's quest log.
--- @param questID number
--- @return boolean
function QuestDatabase:IsQuestActive(questID)
    if not questID then return false end
    if C_QuestLog and C_QuestLog.IsOnQuest then
        local ok, onQ = pcall(C_QuestLog.IsOnQuest, questID)
        if ok and onQ then return true end
    end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and idx and idx > 0 then return true end
    end
    if _G.GetNumQuestLogEntries then
        local num = _G.GetNumQuestLogEntries() or 0
        for i = 1, num do
            if C_QuestLog and C_QuestLog.GetInfo then
                local info = C_QuestLog.GetInfo(i)
                if info and info.questID == questID then return true end
            elseif _G.GetQuestLogTitle then
                local _, _, _, isHeader, _, _, _, id = _G.GetQuestLogTitle(i)
                if not isHeader and id == questID then return true end
            end
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- 5. Dynamic Player-Relative XP Evaluator
-- ----------------------------------------------------------------------------

--- Evaluates the expected XP reward for a quest relative to a viewing player level.
--- Uses live client reward if available in the log; otherwise calculates diminishing
--- returns from baseXP. Never estimates or hardcodes gold conversions.
--- @param quest table|number
--- @param playerLevel number|nil Optional player level (defaults to UnitLevel("player"))
--- @return number xpReward, boolean isLiveFromClient
function QuestDatabase:GetQuestXP(quest, playerLevel)
    if not self.isInitialized then self:Init() end
    if type(quest) == "number" then
        quest = self.Catalog[quest]
    end
    if not quest then return 0, false end

    local qId = quest.id
    local pLevel = playerLevel or UnitLevel("player") or 1

    -- Max level characters receive 0 XP. We intentionally do not estimate gold
    -- conversions without authoritative client data.
    if pLevel >= 60 then
        return 0, false
    end

    -- 1. Try Live Client Value if Quest is in player's log
    if qId and GetQuestLogRewardXP then
        local ok, liveXP = pcall(GetQuestLogRewardXP, qId)
        if ok and type(liveXP) == "number" and liveXP > 0 then
            return liveXP, true
        end
    end

    -- 2. Dynamic Mathematical Diminishing Returns based on baseXP
    local baseXP = quest.baseXP or 0
    if baseXP <= 0 then
        return 0, false
    end

    local qLevel = quest.questLevel or quest.level or pLevel
    local diff = pLevel - qLevel

    -- At or below quest level: 100% full XP
    if diff <= 0 then
        return baseXP, false
    end

    -- Classic bracket reduction: quests diminish as level difference increases
    local bracket = 5
    if pLevel >= 50 then bracket = 9
    elseif pLevel >= 40 then bracket = 8
    elseif pLevel >= 30 then bracket = 7
    elseif pLevel >= 20 then bracket = 6
    end

    if diff >= bracket then
        -- Gray quest: classic 10% minimal or negligible XP
        local factor = math.max(0.10, 1.0 - (diff / bracket))
        return math.floor(baseXP * factor), false
    else
        -- Diminishing returns: approx 20% drop per level above quest level
        local factor = math.max(0.10, 1.0 - (diff * 0.20))
        return math.floor(baseXP * factor), false
    end
end

--- Queries authoritative client rewards (XP and copper) or falls back to
--- dynamic diminishing returns XP. Never guesses gold conversions.
--- @param questID number
--- @param playerLevel number|nil
--- @return table rewards `{ xp = number, xpIsLive = boolean, money = number, moneyIsLive = boolean, isCompleted = boolean, isActive = boolean }`
function QuestDatabase:GetQuestRewards(questID, playerLevel)
    if not self.isInitialized then self:Init() end
    if not questID then
        return { xp = 0, xpIsLive = false, money = 0, moneyIsLive = false, isCompleted = false, isActive = false }
    end

    local qRec = self.Catalog[questID]
    local pLevel = playerLevel or UnitLevel("player") or 1
    local isCompleted = self:IsQuestCompleted(questID)
    local isActive = self:IsQuestActive(questID)

    local clientXP = nil
    local clientMoney = nil

    -- 1. If currently in player's quest log, query authoritative live log API
    if isActive then
        -- XP from log
        if GetQuestLogRewardXP then
            local ok, val = pcall(GetQuestLogRewardXP, questID)
            if ok and type(val) == "number" and val > 0 then
                clientXP = val
            end
        end
        if not clientXP and C_QuestLog and C_QuestLog.GetQuestRewardXP then
            local ok, val = pcall(C_QuestLog.GetQuestRewardXP, questID)
            if ok and type(val) == "number" and val > 0 then
                clientXP = val
            end
        end

        -- Money from log
        if GetQuestLogRewardMoney then
            local ok, val = pcall(GetQuestLogRewardMoney, questID)
            if ok and type(val) == "number" and val > 0 then
                clientMoney = val
            end
        end
        if not clientMoney and C_QuestLog and C_QuestLog.GetQuestLogRewardMoney then
            local ok, val = pcall(C_QuestLog.GetQuestLogRewardMoney, questID)
            if ok and type(val) == "number" and val > 0 then
                clientMoney = val
            end
        end

        -- In Classic/Wrath, index-based query if questID-based returned nil
        if (not clientXP or not clientMoney) and C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
            local ok, logIndex = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
            if ok and logIndex and logIndex > 0 then
                if not clientXP and GetQuestLogRewardXP then
                    local okXP, val = pcall(GetQuestLogRewardXP, logIndex)
                    if okXP and type(val) == "number" and val > 0 then clientXP = val end
                end
                if not clientMoney and GetQuestLogRewardMoney then
                    local okM, val = pcall(GetQuestLogRewardMoney, logIndex)
                    if okM and type(val) == "number" and val > 0 then clientMoney = val end
                end
            end
        end
    end

    -- 2. Check cached client rewards from previous tooltip/client queries
    if not clientXP or not clientMoney then
        local cached = self.ClientRewardsCache[questID]
        if cached then
            clientXP = clientXP or cached.xp
            clientMoney = clientMoney or cached.money
        end
    end

    -- 3. If not in log or missing rewards, query client cache / tooltip system
    if not clientXP or not clientMoney then
        -- Prime client cache
        if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
            pcall(C_QuestLog.RequestLoadQuestByID, questID)
        end

        -- Check C_TooltipInfo (Dragonflight / 10.x / 16001 engine)
        if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
            local ok, data = pcall(C_TooltipInfo.GetHyperlink, "quest:" .. questID)
            if ok and data and data.lines then
                for _, line in ipairs(data.lines) do
                    local txt = line.leftText
                    if txt and type(txt) == "string" then
                        if not clientXP then
                            local parsedXP = parseXPFromText(txt)
                            if parsedXP and parsedXP > 0 then clientXP = parsedXP end
                        end
                        if not clientMoney then
                            local parsedMoney = parseMoneyFromText(txt)
                            if parsedMoney and parsedMoney > 0 then clientMoney = parsedMoney end
                        end
                    end
                end
            end
        end

        -- Fallback: Scan via hidden GameTooltip
        if not clientXP or not clientMoney then
            local scanner = getScannerTooltip()
            if scanner then
                scanner:ClearLines()
                local ok = pcall(scanner.SetHyperlink, scanner, "quest:" .. questID)
                if ok then
                    local numLines = scanner:NumLines() or 0
                    for i = 1, numLines do
                        local leftLine = _G["AdventureJournalQuestScannerTooltipTextLeft" .. i]
                        local txt = leftLine and leftLine:GetText()
                        if txt and type(txt) == "string" then
                            if not clientXP then
                                local parsedXP = parseXPFromText(txt)
                                if parsedXP and parsedXP > 0 then clientXP = parsedXP end
                            end
                            if not clientMoney then
                                local parsedMoney = parseMoneyFromText(txt)
                                if parsedMoney and parsedMoney > 0 then clientMoney = parsedMoney end
                            end
                        end
                    end
                end
            end
        end

        -- Cache any discovered client values
        if clientXP or clientMoney then
            self.ClientRewardsCache[questID] = {
                xp = clientXP,
                money = clientMoney,
            }
        end
    end

    -- 4. Calculate Final XP: Authoritative Live Client vs Diminishing Returns Fallback
    local finalXP = 0
    local xpIsLive = false

    if clientXP and clientXP > 0 then
        finalXP = clientXP
        xpIsLive = true
    elseif qRec then
        finalXP, _ = self:GetQuestXP(qRec, pLevel)
        xpIsLive = false
    end

    -- 5. Calculate Final Money: Only from authoritative client data, never estimated
    local finalMoney = clientMoney or 0
    local moneyIsLive = (clientMoney ~= nil and clientMoney > 0)

    return {
        xp = finalXP,
        xpIsLive = xpIsLive,
        money = finalMoney,
        moneyIsLive = moneyIsLive,
        isCompleted = isCompleted,
        isActive = isActive,
    }
end

-- ----------------------------------------------------------------------------
-- 6. Search & Filter Query Evaluator
-- ----------------------------------------------------------------------------

--- Searches the quest catalog against query text and optional tag filters.
--- @param query string Search text (e.g. "Defias", "Hides", "Ironforge")
--- @param factionFilter string|nil
--- @param classFilter string|nil
--- @return table Array of matching quest records
function QuestDatabase:QueryQuests(query, factionFilter, classFilter)
    if not self.isInitialized then self:Init() end
    local results = {}

    local qLower = query and strlower(query) or ""
    local playerFaction = UnitFactionGroup("player") or "Both"
    local fFilter = factionFilter or playerFaction

    local _, playerClass = UnitClass("player")
    local cFilter = classFilter or playerClass

    for _, q in pairs(self.Catalog) do
        local match = true

        -- Faction filter
        if fFilter and fFilter ~= "All" then
            if q.faction ~= "Both" and q.faction ~= fFilter then
                match = false
            end
        end

        -- Class filter
        if match then
            local questClass = q.classOnly
            if not questClass and q.tags then
                for _, t in ipairs(q.tags) do
                    local c = t:match("^CLASS:(.+)$")
                    if c then
                        questClass = c
                        break
                    end
                end
            end

            if questClass and questClass ~= "" and questClass ~= "All" then
                if cFilter and cFilter ~= "All" then
                    if questClass:upper() ~= cFilter:upper() then
                        match = false
                    end
                end
            end
        end

        -- Query text match (name, objective, pickup, turnin)
        if match and qLower ~= "" then
            local inName = q.name and strfind(strlower(q.name), qLower, 1, true)
            local inObj = q.objective and strfind(strlower(q.objective), qLower, 1, true)
            local inPick = q.pickup and strfind(strlower(q.pickup), qLower, 1, true)
            local inTurn = q.turnin and strfind(strlower(q.turnin), qLower, 1, true)
            if not (inName or inObj or inPick or inTurn) then
                match = false
            end
        end

        if match then
            results[#results + 1] = q
        end
    end

    table.sort(results, function(a, b)
        local la = (a.reqLevel and a.reqLevel > 0 and a.reqLevel) or a.questLevel or 0
        local lb = (b.reqLevel and b.reqLevel > 0 and b.reqLevel) or b.questLevel or 0
        if la ~= lb then return la < lb end
        return (a.name or "") < (b.name or "")
    end)

    return results
end

ns.QuestDatabase = QuestDatabase
_G.AdventureJournalQuestDatabase = QuestDatabase
return QuestDatabase
