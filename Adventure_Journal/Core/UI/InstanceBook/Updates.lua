-- ============================================================================
-- Adventure Journal - Core/UI/InstanceBook/Updates.lua
-- What redraws an instance book while it's open: a new window theme, game data
-- the client loads later (item names, quest titles), setting changes, leveling
-- up, and changes to the player's quest log.
-- ============================================================================
local addonName, ns = ...
local addonNs = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local next = next
local pairs = pairs
local C_Timer = C_Timer
local Blocks = ns.UI.Blocks
local WindowBackground = ns.UI.WindowBackground

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- Settings that change the list, not the open book
local LIST_SETTINGS = { listSort = true, listLayout = true }

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local InstanceBook = ns.UI.InstanceBook

--- Starts listening for everything that redraws the book (`frame`, the book's frame).
function InstanceBook:RegisterUpdates(frame)
    -- A new window background recolors the open page's body text (ink on parchment)
    WindowBackground:OnChange(function()
        if self.frame and self.frame:IsShown() and self.currentDungeon then
            self:RefreshRightPage()
        end
    end)

    -- Loaded client data redraws only what it changes, batched over a short delay. It never
    -- re-runs the search's auto-select, so the player's selection stays put.
    local liveTimer, loadedItems, loadedQuests = nil, {}, false
    local function applyLoadedData()
        liveTimer = nil
        local items, quests = loadedItems, loadedQuests
        loadedItems, loadedQuests = {}, false
        if not (self.frame and self.frame:IsShown() and self.currentDungeon) then
            return
        end
        local itemsLoaded = next(items) ~= nil
        if itemsLoaded and self.searchQuery and self.searchQuery:match("%S") then
            self.skipSearchAutoSelect = true
            self:RefreshLeftPage()
            self.skipSearchAutoSelect = false
        end
        if self.activeRightTab == "quests" then
            if quests or itemsLoaded then
                self:RefreshRightPage()
            end
            return
        end
        local lootShown = self.selectedBoss or self.activeRightTab == "loot"
        local listed = self.lootList.listedItemIDs
        for itemID in pairs(items) do
            if lootShown and listed[itemID] then
                if self.selectedBoss then
                    self:RenderItemDrops(self.currentDungeon, self.selectedBoss)
                else
                    self:RenderDungeonItemDrops(self.currentDungeon)
                end
                return
            end
        end
    end
    local liveData = addonNs.DataStore and addonNs.DataStore.Live
    if liveData then
        liveData:AddListener(function(batch)
            for itemID in pairs(batch and batch.item or {}) do
                loadedItems[itemID] = true
            end
            loadedQuests = loadedQuests or (batch and batch.quest ~= nil) or false
            if not liveTimer then
                liveTimer = C_Timer.NewTimer(0.08, applyLoadedData)
            end
        end)
    end

    frame:SetScript("OnShow", function()
        Blocks.Medallion:SyncRing(self.dungeonMedallion)
        Blocks.Medallion:SyncRing(self.encounterDetail.medallion)
        self:UpdateSideTabs()
        -- An open quest page is rebuilt with current progress, so a questline opens on the step the player is on
        -- (Questline resets its open steps when the window has been closed since)
        if self.activeRightTab == "quests" and self.selectedQuest then
            self:RefreshRightPage()
        end
    end)

    -- The template's settings that change what the open page shows redraw it
    local watched = {}
    for name, key in pairs(self.template.settingKeys) do
        watched[key] = not LIST_SETTINGS[name] or nil
    end
    self.settingsListener = addonNs.Settings:AddChangeListener(function(moduleKey, key)
        if moduleKey == self.template.settings and watched[key] and self.frame and self.frame:IsShown() then
            self:UpdateSideTabs()
            self:RefreshLeftPage()
            self:RefreshRightPage()
        end
    end)

    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("QUEST_REMOVED")
    frame:SetScript("OnEvent", function(f, event, ...)
        if not self.frame or not self.frame:IsShown() then return end
        if event == "PLAYER_LEVEL_UP" then
            self:RefreshLeftPage()
            self:RefreshRightPage()
        elseif self.activeRightTab == "quests" then
            self:RefreshLeftPage()
            self:RefreshRightPage()
        end
    end)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.InstanceBook)
