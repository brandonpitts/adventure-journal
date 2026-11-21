-- ============================================================================
-- Adventure Journal - Core/UI/InstanceBook/RightPage.lua
-- An instance book's right page: the overview, an encounter with its loot (loot
-- sets under their own headers), the whole instance's loot, or the selected
-- quest (from the Quests tab's composer). Text comes from the templates.
-- ============================================================================
local addonName, ns = ...
local addonNs = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local string = string
local strfind = strfind
local strlower = strlower
local UnitLevel = UnitLevel
local Blocks = ns.UI.Blocks
local Access = ns.Data.InstanceAccess
local Search = ns.Search

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- The boss list's groups in list order (InstanceAccess:GroupEncounters)
local ENCOUNTER_GROUPS = { "event", "boss", "rare", "minor", "challenge" }

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local InstanceBook = ns.UI.InstanceBook

--- The instance's entrance for the Show on Map button ({ uiMapID, x, y, name }), or nil when the button
--- shouldn't show: no entrance, the setting is off, or the player is below (or outside) the level range.
function InstanceBook:MapEntrance(d)
    local entrance = d and Access:GetEntrance(d)
    if not (entrance and entrance.uiMapID) then
        return nil
    end
    local setting = self:Setting("mapButton")
    if setting == "disabled" then
        return nil
    elseif setting == "always" then
        return entrance
    end
    local playerLevel = UnitLevel("player") or 1
    local minLevel, maxLevel = d.minLevel or 1, d.maxLevel or 60
    if setting == "min_level" then
        return playerLevel >= minLevel and entrance or nil
    elseif setting == "bracket" then
        return (playerLevel >= minLevel and playerLevel <= maxLevel) and entrance or nil
    end
    return entrance
end

--- Renders the Right Page based on whether a boss is selected and which right-side tab is active.
function InstanceBook:RefreshRightPage()
    local d = self.currentDungeon
    if not d or not self.frame then
        return
    end

    local boss = self.selectedBoss
    self:UpdateSideTabs()

    -- ========================================================================
    -- MODE 1: NO ENCOUNTER SELECTED (the overview, the whole instance's loot, or quests)
    -- ========================================================================
    if not boss then
        self.encounterDetail:Hide()

        if self.activeRightTab == "loot" then
            -- The whole instance's loot, each item with where it drops
            if self.questDetailContainer then
                self.questDetailContainer:Hide()
            end
            self.overviewPane:Hide()
            self.detailScroll:ClearAllPoints()
            self.detailScroll:SetPoint("TOPLEFT", self.rightPage, "TOPLEFT", 6, -8)
            self.detailScroll:SetPoint("BOTTOMRIGHT", self.rightPage, "BOTTOMRIGHT", -24, 8)
            self.detailScroll:SetVerticalScroll(0)
            self.detailScroll:Show()
            self:RenderDungeonItemDrops(d)
            return
        elseif self.activeRightTab == "quests" then
            -- Quests: the list is on the left page; the selected quest here
            self.overviewPane:Hide()
            self.detailScroll:Hide()
            if self.questDetailContainer then
                self.questDetailContainer:Show()

                if self.selectedQuest then
                    self.questDetail:SetHeader(self.quests:Header(self.selectedQuest, d))
                    self.questDetail:Render(self.quests:Page(self.selectedQuest, d))
                else
                    self.questDetail:Clear()
                end
            end
            return
        end

        -- The overview: art, description, Show on Map
        if self.questDetailContainer then
            self.questDetailContainer:Hide()
        end
        self.detailScroll:Hide()
        self.overviewPane:Show()

        local lore = ns.Templates.Resolver:Slot(self.template, "overview.lore", d, "InstanceStore", d.key)
        if not lore and d.comingSoon then
            lore = self:T("comingSoon")
        end
        self.overview:Show(d, self:MapEntrance(d), lore, {
            named = self:T("mapEntrance"), unnamed = self:T("mapEntranceUnnamed"),
        })
        return
    end

    -- ========================================================================
    -- MODE 2: BOSS ENCOUNTER OVERVIEW & DROPS (Boss selected, Loot tab active)
    -- ========================================================================
    self.overviewPane:Hide()
    if self.questDetailContainer then
        self.questDetailContainer:Hide()
    end

    local description = ns.Templates.Resolver:Slot(self.template, "encounter.description", boss, "EncounterStore",
        boss.key)
    self.encounterDetail:Show(boss, d, self:Setting("showColor") == true, description, self:EncounterIcon(boss))

    -- 4. Clean Scrollable Container under Divider
    self.detailScroll:ClearAllPoints()
    self.detailScroll:SetPoint("TOPLEFT", self.encounterDetail.divider, "BOTTOMLEFT", 0, -8)
    self.detailScroll:SetPoint("BOTTOMRIGHT", self.rightPage, "BOTTOMRIGHT", -24, 8)
    self.detailScroll:SetVerticalScroll(0)
    self.detailScroll:Show()

    self:RenderItemDrops(d, boss)
end

--- Draws loot entries (`{ itemID, source }`) in the loot list, then `sets` (`{ { title, entries } }`, each under its
--- own header); while searching (`filterByItem`), only items matching the search, or whose source matches it.
function InstanceBook:RenderCategorizedDropEntries(entries, filterByItem, parsedQuery, q, emptyText, sets)
    self.questList:Hide()
    local filter
    if filterByItem then
        filter = function(entry)
            if Search:ItemMatches(entry.itemID, parsedQuery or q) then
                return true
            end
            return entry.source ~= nil and q ~= "" and strfind(strlower(entry.source), q, 1, true) ~= nil
        end
    end
    self.lootList:Render(entries, {
        filter = filter,
        emptyText = emptyText or self:T("noLoot"),
        noMatchText = self:T("noLootMatches", self.searchQuery or ""),
        categories = self.template.lootCategories,
        sets = sets,
    })
end

--- Draws an encounter's loot: its own items by category, then each loot set under its own header.
--- @param d table
--- @param boss table an encounter view (or the Zone Drops entry)
function InstanceBook:RenderItemDrops(d, boss)
    local dropIDs = boss.baseItemIDs or boss.itemIDs or {}

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""
    local parsedQuery = (q ~= "") and Search:Parse(q) or nil
    local isMultiConstraint = Search:IsMultiConstraint(parsedQuery)
    local bossNameMatches = (not isMultiConstraint) and (boss.name and strfind(strlower(boss.name), q, 1, true))
    local filterByItem = (q ~= "" and not bossNameMatches)

    local entries = {}
    for _, itemID in ipairs(dropIDs) do
        entries[#entries + 1] = {
            itemID = itemID,
        }
    end

    local sets = {}
    for _, set in ipairs(boss.lootSets or {}) do
        local setEntries = {}
        for _, itemID in ipairs(set.itemIDs or {}) do
            setEntries[#setEntries + 1] = { itemID = itemID }
        end
        sets[#sets + 1] = { title = set.label, entries = setEntries }
    end
    self:RenderCategorizedDropEntries(entries, filterByItem, parsedQuery, q, self:T("noLoot"), sets)
end

--- Draws every item across the whole instance (`d`) by category, each with the encounters (or Zone Drops) it
--- drops from under it.
--- @param d table
function InstanceBook:RenderDungeonItemDrops(d)
    local showMinor = self:Setting("showMinor") == true
    local showEventBosses = self:Setting("showEvents")
    local showDungeonSetChallenges = self:Setting("showChallenges") == true

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""
    local parsedQuery = (q ~= "") and Search:Parse(q) or nil
    local isSearching = (q ~= "")

    local groups = Access:GroupEncounters(d, {
        isSearching = isSearching, showMinor = showMinor, showChallenges = showDungeonSetChallenges,
        eventSetting = showEventBosses, hideIncomplete = self:HidesIncomplete(),
    })

    local orderedSources = {}
    for _, kind in ipairs(ENCOUNTER_GROUPS) do
        for _, b in ipairs(groups[kind]) do
            orderedSources[#orderedSources + 1] = { label = b.name, itemIDs = b.itemIDs }
        end
    end
    orderedSources[#orderedSources + 1] = { label = self:T("zoneDrops"), itemIDs = d.zoneItemIDs }

    local entries = {}
    local entryByItemID = {}

    for _, src in ipairs(orderedSources) do
        local dropIDs = src.itemIDs or {}
        for _, itemID in ipairs(dropIDs) do
            local existing = entryByItemID[itemID]
            if not existing then
                local newEntry = {
                    itemID = itemID,
                    source = src.label,
                    _seenBosses = { [src.label] = true },
                }
                entryByItemID[itemID] = newEntry
                entries[#entries + 1] = newEntry
            elseif not existing._seenBosses[src.label] then
                existing._seenBosses[src.label] = true
                existing.source = existing.source .. ", " .. src.label
            end
        end
    end

    self:RenderCategorizedDropEntries(entries, isSearching, parsedQuery, q, self:T("noInstanceLoot"))
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.InstanceBook)
