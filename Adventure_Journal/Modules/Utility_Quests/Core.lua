-- ============================================================================
-- Utility_Quests - Core.lua
-- Module lifecycle and cross-system registration for Adventure Journal.
-- Initializes QuestDatabase, links into parent namespace, and enriches ItemDatabase.
-- ============================================================================
local addonName, parent = ...
parent.Utility_Quests = parent.Utility_Quests or {}
local ns = parent.Utility_Quests

local _G = _G
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local type = type
local QuestDatabase = ns.QuestDatabase

-- Export to parent namespace for cross-module consumption (Dungeons, Raids, Collectibles)
parent.QuestDatabase = QuestDatabase
ns.QuestDatabase = QuestDatabase

-- Initialize the database at load time
if QuestDatabase and QuestDatabase.Init then
    QuestDatabase:Init()
end

-- Cross-link quest reward items into central ItemDatabase
if parent.ItemDatabase and parent.ItemDatabase.RegisterSource then
    local catalog = ns.QuestsCatalog or {}
    for qId, qRec in pairs(catalog) do
        if qRec.rewardItems and #qRec.rewardItems > 0 then
            for _, itemID in ipairs(qRec.rewardItems) do
                parent.ItemDatabase:RegisterSource(itemID, {
                    kind = "quest",
                    questID = qId,
                    questName = qRec.name,
                    faction = qRec.faction,
                    level = qRec.questLevel,
                })
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Module Registration with Adventure Journal PluginRegistry
-- ----------------------------------------------------------------------------
local QuestsPlugin = {
    id = "utility_quests",
    title = "Quests",
    addonName = "Utility_Quests",
    version = (parent.Constants and parent.Constants.VERSION) or "0.6.0",
    lastUpdated = "2026-11-14",
    description = "Provides dungeon quest catalogs, prerequisite chain tracking, map markers, and level-relative reward XP calculations.",
    apiVersion = (parent.Constants and parent.Constants.PLUGIN_API_VERSION) or 1,
    order = 850,
    icon = "Interface\\Icons\\INV_Misc_Book_08",
    isUtility = true,
    hasTab = false,
}

--- Event frame for listening to quest cache updates from the WoW client
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:SetScript("OnEvent", function(self, event, questID, success)
    if event == "QUEST_DATA_LOAD_RESULT" and success and questID then
        -- Invalidate cached reward data so live query updates with fresh data
        if QuestDatabase and QuestDatabase.ClientRewardsCache then
            QuestDatabase.ClientRewardsCache[questID] = nil
        end
    elseif event == "QUEST_LOG_UPDATE" then
        -- Clear volatile cache on quest log changes
        if QuestDatabase and QuestDatabase.ClientRewardsCache then
            table.wipe(QuestDatabase.ClientRewardsCache)
        end
    end
end)

--- Unloads all quest tables and caches from memory when the module is disabled
function QuestsPlugin:OnUnload()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
    end
    if QuestDatabase and QuestDatabase.Unload then
        QuestDatabase:Unload()
    end
end

if _G.JournalBase and _G.JournalBase.RegisterPlugin then
    _G.JournalBase:RegisterPlugin(QuestsPlugin)
elseif parent.PluginRegistry and parent.PluginRegistry.Register then
    parent.PluginRegistry:Register(QuestsPlugin)
end

ns.Plugin = QuestsPlugin
