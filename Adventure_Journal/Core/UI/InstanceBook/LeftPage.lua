-- ============================================================================
-- Adventure Journal - Core/UI/InstanceBook/LeftPage.lua
-- An instance book's left page: the header, then the boss list (sections from
-- the template), the wing list or the quest list, with the search's automatic
-- selection.
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

--- Draws the left page: the header, then the wing list, the quest list or the boss list.
function InstanceBook:RefreshLeftPage()
    local d = self.currentDungeon
    if not d or not self.frame then
        return
    end

    local showBossLevel = self:Setting("showLevel") == true
    local showDifficultyColor = self:Setting("showColor") == true
    local showMinor = self:Setting("showMinor") == true
    local showEventBosses = self:Setting("showEvents")
    local showDungeonSetChallenges = self:Setting("showChallenges") == true

    local Resolver = ns.Templates.Resolver
    local metaParts = {}
    for _, part in ipairs(self.template.headerMeta) do
        if part == "level" then
            local text = self:T("level", d.level or "?")
            if showDifficultyColor then
                local r, g, b = Blocks.LevelTag:InstanceColor(d)
                text = Blocks.LevelTag:Colorize(text, r, g, b)
            end
            metaParts[#metaParts + 1] = text
        elseif part == "location" then
            metaParts[#metaParts + 1] = d.location or ""
        elseif part == "size" then
            local size = Resolver:Slot(self.template, "header.size", d, "InstanceStore", d.instanceID)
            metaParts[#metaParts + 1] = size and self:T("size", size) or nil
        end
    end
    local metaText = table.concat(metaParts, " • ")
    local title = Resolver:Slot(self.template, "header.title", d, "InstanceStore", d.key)
    local crest = Resolver:Slot(self.template, "header.crest", d, "InstanceStore", d.instanceID)
    self.header:Set(d, title, metaText, crest)

    self.encounterList:Hide()

    if self.wingPage then
        self:RenderWingList(d)
        return
    end
    self.wingList:Hide()

    if self.activeRightTab == "quests" then
        self.leftDivider:Show()
        self.bossScroll:Show()
        if self.noEncountersText then self.noEncountersText:Hide() end

        self:RenderDungeonQuests(d)
        return
    else
        self.leftDivider:Show()
        self.bossScroll:Show()
        self.questList:Hide()
    end

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""

    local isSearching = (q ~= "")
    local groups = Access:GroupEncounters(d, {
        match = isSearching and function(boss) return Access:EncounterMatches(boss, q) end or nil,
        isSearching = isSearching, showMinor = showMinor, showChallenges = showDungeonSetChallenges,
        eventSetting = showEventBosses, hideIncomplete = self:HidesIncomplete(),
    })
    -- The first shown encounter in list order, and whether the selected one is shown
    local shown = {}
    for _, kind in ipairs(ENCOUNTER_GROUPS) do
        for _, boss in ipairs(groups[kind]) do
            shown[boss] = true
        end
    end
    local firstMatchingBoss
    for _, boss in ipairs(Access:GetEncounters(d)) do
        firstMatchingBoss = firstMatchingBoss or (shown[boss] and boss) or nil
    end
    local selectedBossMatches = self.selectedBoss ~= nil and shown[self.selectedBoss] == true

    -- Evaluate Zone Drops and search match counts before choosing a selection
    local zoneDrops = d.zoneItemIDs or {}
    local hasZoneDrops = (#zoneDrops > 0)
    if hasZoneDrops and q ~= "" then
        hasZoneDrops = strfind(self:T("zoneDropsSearch"), q, 1, true) ~= nil
            or Access:EncounterMatches({ name = self:T("zoneDrops"), itemIDs = zoneDrops }, q)
    end

    if not self.zoneBossEntry or self.zoneBossEntry.dungeonId ~= d.id then
        self.zoneBossEntry = {
            dungeonId = d.id,
            itemIDs = zoneDrops,
            name = self:T("zoneDrops"),
            isZone = true,
            icon = "Interface\\Icons\\INV_Box_01",
            description = self:T("zoneDropsDescription", d.name or self:T("thisInstance")),
        }
    end

    if hasZoneDrops and self.selectedBoss and self.selectedBoss.isZone then
        self.selectedBoss = self.zoneBossEntry
        selectedBossMatches = true
    end

    -- While searching: several matching encounters or items open the dungeon's whole loot list; a single
    -- match selects that encounter
    if q ~= "" and not self.suppressSearchAutoBoss and not self.skipSearchAutoSelect then
        local matchingEncounterCount = (hasZoneDrops and 1 or 0)
        local matchingItemCount = 0
        local parsedQuery = Search:Parse(q)
        local seenItems = {}
        local function countBossItems(itemIDs)
            for _, itemID in ipairs(itemIDs or {}) do
                if not seenItems[itemID] then
                    seenItems[itemID] = true
                    if Search:ItemMatches(itemID, parsedQuery) then
                        matchingItemCount = matchingItemCount + 1
                    end
                end
            end
        end
        for _, kind in ipairs(ENCOUNTER_GROUPS) do
            matchingEncounterCount = matchingEncounterCount + #groups[kind]
            for _, b in ipairs(groups[kind]) do countBossItems(b.itemIDs) end
        end
        if hasZoneDrops then countBossItems(zoneDrops) end

        if not selectedBossMatches then
            if matchingItemCount > 1 or matchingEncounterCount > 1 then
                self.selectedBoss = nil
            elseif firstMatchingBoss then
                self.selectedBoss = firstMatchingBoss
            elseif hasZoneDrops then
                self.selectedBoss = self.zoneBossEntry
            else
                self.selectedBoss = nil
            end
            self.activeRightTab = "loot"
        end
    end

    -- A selected encounter whose section is now hidden is deselected
    local selected = self.selectedBoss
    if selected then
        if #groups.event == 0 and selected.isEvent
            and not addonNs.HolidayManager:ShouldShowEventBoss(selected, showEventBosses) then
            self.selectedBoss = nil
        elseif #groups.minor == 0 and selected.isMinor and not showMinor then
            self.selectedBoss = nil
        elseif #groups.challenge == 0 and selected.isChallenge and not showDungeonSetChallenges then
            self.selectedBoss = nil
        elseif selected.isIncomplete and not isSearching and self:HidesIncomplete() then
            self.selectedBoss = nil
        elseif not hasZoneDrops and selected.isZone then
            self.selectedBoss = nil
        end
    end

    -- The template's sections, in order; the zone section holds the Zone Drops entry
    local sections = {}
    for i, section in ipairs(self.template.encounterSections) do
        local encounters = groups[section.kind]
        if section.kind == "zone" then
            encounters = hasZoneDrops and { self.zoneBossEntry } or {}
        end
        sections[i] = { encounters = encounters or {}, label = section.label, color = section.color,
            dividerAfter = section.dividerAfter, dividerBefore = section.dividerBefore }
    end
    local drawn = self.encounterList:Render(sections, { selected = self.selectedBoss, showLevel = showBossLevel,
        useDifficultyColor = showDifficultyColor, instance = d,
        iconFor = function(boss) return self:EncounterIcon(boss) end })

    if self.noEncountersText then
        if drawn == 0 and q ~= "" then
            Blocks.BookLayout:ShowEmpty(self.book, self:T("noMatches", self.searchQuery or ""))
        else
            self.noEncountersText:Hide()
        end
    end
end

--- Renders the wing list on the left page of the wing selection page.
--- @param d table the instance view (with wings)
function InstanceBook:RenderWingList(d)
    self.questList:Hide()
    self.encounterList:Hide()
    self.wingList:Hide()
    if self.noEncountersText then
        self.noEncountersText:Hide()
    end
    self.leftDivider:Show()
    self.bossScroll:Show()

    local showLevel = self:Setting("showLevel") == true
    local showColor = self:Setting("showColor") == true

    -- While searching, list only the wings holding a match; fall back to every wing when the
    -- query matched the parent alone (e.g. a parent-only alias)
    local wings = Access:GetWings(d)
    local query = self.searchQuery
    if query and query:match("%S") then
        local matching = {}
        for _, wing in ipairs(wings) do
            if Access:InstanceMatches(wing, query) then
                matching[#matching + 1] = wing
            end
        end
        if #matching > 0 then
            wings = matching
        end
    end

    self.wingList:Render(wings, { showLevel = showLevel, useDifficultyColor = showColor })
end

--- Draws the instance's quests on the left page in the quest template's sections (the player's faction, then
--- the other faction's behind a divider). Keeps the selected quest when it's still listed.
--- @param d table
function InstanceBook:RenderDungeonQuests(d)
    self.questList:Hide()
    if not d then return end

    local sections, total = self.quests:Lists(d)
    if total == 0 then
        self.selectedQuest = nil
        Blocks.BookLayout:ShowEmpty(self.book, self.quests:T("noQuests"))
        return
    end
    self.noEncountersText:Hide()
    self.selectedQuest = self.quests:Select(sections, self.selectedQuest and self.selectedQuest.id)
    self.questList:Render(self.quests:Rows(sections, self.selectedQuest))
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.InstanceBook)
