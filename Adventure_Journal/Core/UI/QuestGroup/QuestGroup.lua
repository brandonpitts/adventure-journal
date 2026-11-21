-- ============================================================================
-- Adventure Journal - Core/UI/QuestGroup/QuestGroup.lua
-- Composes a quest group (template "questGroup" or one extending it) for the
-- blocks to draw: the list's sections and rows, the selection, and the
-- chosen quest's header. QuestPage.lua adds the detail page. Text, sections
-- and placeholders come from the template; data from the quest feed. The
-- host is the book showing the group: it gives the noun ("Dungeon") and
-- the settings (`host.template.noun`, `host:Setting(name)`).
--   group: the subject's view (an instance or wing view: name, location, instanceID, wingKey)
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local tostring = tostring
local setmetatable = setmetatable
local concat = table.concat
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Feed = ns.Data.QuestAccess

--- The level a quest is shown at: its required level, else its quest level.
local function shownLevel(quest)
    return (quest.reqLevel and quest.reqLevel > 0 and quest.reqLevel) or quest.questLevel or quest.level or 0
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestGroup = {}
QuestGroup.__index = QuestGroup

--- A composer for `template` (a registered quest template) shown inside `host`.
function QuestGroup:New(template, host)
    return setmetatable({ template = template, host = host }, QuestGroup)
end

--- The template's text for `key`, with the host's noun.
function QuestGroup:T(key, ...)
    return ns.Templates:TextWithNoun(self.template, self.host.template.noun, key, ...)
end

--- A slot's value for `quest` (display overrides from QuestStore), and whether it is hidden.
function QuestGroup:Slot(name, quest)
    return ns.Templates.Resolver:Slot(self.template, name, quest, "QuestStore", quest.id)
end

--- The level shown for `quest`, and its tag text ("Lv 24").
function QuestGroup:Level(quest)
    local level = shownLevel(quest)
    return level, self:T("level", tostring(level))
end

--- The group's quests by the template's list sections: `{ { section, quests } }` in order, sections turned off
--- by their setting left out. Returns the sections and the number of quests in them.
function QuestGroup:Lists(group)
    local playerFaction = UnitFactionGroup("player") or "Both"
    local _, playerClass = UnitClass("player")
    local sections, wantsOther = {}, false
    for _, section in ipairs(self.template.listSections) do
        if not section.setting or self.host:Setting(section.setting) == true then
            sections[#sections + 1] = { section = section, quests = {} }
            wantsOther = wantsOther or section.faction == "other"
        end
    end
    local factionFilter = wantsOther and "All" or playerFaction
    local total, attuning = 0, {}
    for _, entry in ipairs(sections) do
        if entry.section.kind == "attunement" then
            for _, quest in ipairs(Feed:GetAttunementQuests(group, factionFilter, playerClass)) do
                attuning[quest.id] = true
                entry.quests[#entry.quests + 1] = quest
                total = total + 1
            end
        end
    end
    for _, quest in ipairs(Feed:GetInstanceQuests(group, factionFilter, playerClass)) do
        local mine = quest.faction == "Both" or quest.faction == playerFaction
        for _, entry in ipairs(sections) do
            if not attuning[quest.id] and entry.section.kind == "faction" and (entry.section.faction == "player") == mine then
                entry.quests[#entry.quests + 1] = quest
                total = total + 1
                break
            end
        end
    end
    return sections, total
end

--- The quest to show: the one with `selectedID` when it's still listed (its fresh view), else the first listed.
function QuestGroup:Select(sections, selectedID)
    local first
    for _, entry in ipairs(sections) do
        for _, quest in ipairs(entry.quests) do
            if quest.id == selectedID then
                return quest
            end
            first = first or quest
        end
    end
    return first
end

--- The list's rows by section, for QuestList: `{ { header, dividerBefore, rows = { row } } }` (`header` the
--- section's title, or nil).
--- row: `{ quest, name, level, levelText, isQuestline, isCompleted, isActive, isSelected }`.
function QuestGroup:Rows(sections, selected)
    local out = {}
    for _, entry in ipairs(sections) do
        local rows = {}
        for _, quest in ipairs(entry.quests) do
            local questline = Feed:GetQuestline(quest.id)
            local isActive = Feed:IsQuestActive(quest.id)
            for _, step in ipairs((not isActive and questline) or {}) do
                isActive = isActive or Feed:IsQuestActive(step.id)
            end
            local level, levelText = self:Level(quest)
            rows[#rows + 1] = {
                quest = quest, name = self:Slot("quest.title", quest), level = level, levelText = levelText,
                isQuestline = ((questline and #questline > 1) or quest.isQuestline) == true,
                isCompleted = Feed:IsQuestCompleted(quest.id), isActive = isActive,
                isSelected = selected ~= nil and selected.id == quest.id,
            }
        end
        out[#out + 1] = { header = entry.section.label and self:T(entry.section.label),
            dividerBefore = entry.section.dividerBefore, rows = rows }
    end
    return out
end

--- Where the quest starts, for the header: the giver's place, or the group's for an item.
function QuestGroup:StartPlace(quest, group)
    local giver = quest.giver
    if giver and giver.kind == "item" then
        return (group.location and group.location ~= "") and (group.name .. ", " .. group.location) or group.name
    end
    return giver and giver.where or ""
end

--- The quest page's header: `{ title, level, meta, faction }`. The meta line is "Lv N • where it starts", then
--- "Item Drop" for a quest started by an item or object, or "Questline" for a step of a questline.
function QuestGroup:Header(quest, group)
    local level, levelText = self:Level(quest)
    local r, g, b = ns.LevelColors:ForText(level)
    local place = self:StartPlace(quest, group)
    if place == "" then
        place = group.name or self.host.template.noun
    end
    local parts = { ns.UI.Blocks.LevelTag:Colorize(levelText, r, g, b), place }
    if quest.giver and quest.giver.kind ~= "npc" then
        parts[#parts + 1] = self:T("itemDrop")
    elseif quest.isQuestline then
        parts[#parts + 1] = self:T("questline")
    end
    return { title = self:Slot("quest.title", quest), meta = concat(parts, " • "), faction = quest.faction }
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.QuestGroup = QuestGroup
