-- ============================================================================
-- Adventure Journal - Core/UI/QuestGroup/QuestPage.lua
-- The quest page's model for QuestDetail: a single quest's sections, or a
-- questline's steps with theirs, in the template's order (`detailSections`).
-- Map pins come from the givers' data: a giver inside an instance has none.
--   page:    { questID, pinText, sections } or { questID, pinText, steps }
--   step:    { id, title, level, levelText, isCompleted, isActive, sections }
--   section: { kind = "objectives", header, body }
--            { kind = "giver", role = "source" | "turnin", header, body, point, label, reason }
--            { kind = "requirements", header, body }
--            { kind = "rewards", header, xpText, items, caption, loading }
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local _G = _G
local ipairs = ipairs
local tostring = tostring
local concat = table.concat

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Feed = ns.Data.QuestAccess
local QuestGroup = ns.UI.QuestGroup

--- The class a quest is for, as the game names it, or nil.
local function className(quest)
    local class = quest.classOnly
    for _, tag in ipairs((not class and quest.tags) or {}) do
        class = class or tag:match("^CLASS:(.+)$")
    end
    if not class or class == "" or class == "All" then
        return nil
    end
    local upper = class:upper()
    return (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[upper]) or _G[upper]
        or (upper:sub(1, 1) .. upper:sub(2):lower())
end

--- A giver row's pin: the giver's map point unless it's inside an instance, and why there's none.
local function pin(giver, insideReason, noneReason)
    if giver and giver.inside then
        return nil, insideReason
    end
    return giver and giver.point, noneReason
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------

--- The Quest Source row's text: where it starts. On a single quest's page, an item with no place of its own
--- names the group's place.
function QuestGroup:SourceText(quest, group, isStep)
    local text = self:Slot("quest.source", quest)
    local place = not isStep and quest.giver and quest.giver.kind == "item" and self:StartPlace(quest, group)
    if text and place and place ~= "" and not text:find(place, 1, true) and not text:find(",") then
        text = text .. ", " .. place
    end
    return text
end

--- The Turn-In row's text and giver. With no turn-in recorded, the quest is turned in where it started (an
--- item giver has no place to turn in).
function QuestGroup:TurnIn(quest)
    local text = self:Slot("quest.turnin", quest)
    if text then
        return text, quest.turninGiver
    end
    local giver = quest.giver
    return quest.pickup or self:Slot("quest.source", quest), giver and giver.kind ~= "item" and giver or nil
end

--- One detail section by name, or nil when it has nothing to show (or its slot is hidden). On a questline's step
--- (`isStep`) a missing source or turn-in is left out, and requirements list only the level.
function QuestGroup:Section(name, quest, group, isStep)
    local value, hidden = self:Slot("quest." .. name, quest)
    if hidden then
        return nil
    end
    if name == "objectives" then
        local inLog = quest.id and Feed:IsQuestActive(quest.id)
        return { kind = "objectives", header = self:T("objectives"), body = value,
            logQuestID = inLog and quest.id or nil,
            logText = inLog and { title = self:T("questLogTitle"), hint = self:T("questLogHint") } or nil }
    elseif name == "source" then
        if isStep and not quest.pickup then
            return nil
        end
        local point, reason = pin(quest.giver, self:T("sourceInside"), self:T("noCoords"))
        return { kind = "giver", role = "source", header = self:T("source"), body = self:SourceText(quest, group, isStep),
            point = point, label = quest.giver and quest.giver.name or self:T("source"), reason = reason }
    elseif name == "turnin" then
        if isStep and not (quest.turnin or quest.pickup) then
            return nil
        end
        local text, giver = self:TurnIn(quest)
        local point, reason = pin(giver, self:T("turninInside"), self:T("noCoords"))
        return { kind = "giver", role = "turnin", header = self:T("turnin"), body = text, point = point,
            label = text, reason = reason }
    elseif name == "requirements" then
        local parts = {}
        if quest.reqLevel and quest.reqLevel > 0 then
            parts[#parts + 1] = self:T("requiresLevel", tostring(quest.reqLevel))
        end
        if not isStep then
            if quest.faction and quest.faction ~= "" and quest.faction ~= "Both" then
                parts[#parts + 1] = quest.faction
            end
            parts[#parts + 1] = className(quest)
        end
        return #parts > 0 and { kind = "requirements", header = self:T("requirements"), body = concat(parts, " • ") }
            or nil
    elseif name == "rewards" then
        local xp, items = quest.baseXP, value
        local hasXP, hasItems = xp and xp > 0, items and #items > 0
        if not (hasXP or hasItems) then
            return nil
        end
        return { kind = "rewards", header = self:T("rewards"),
            xpText = hasXP and self:T("experience", tostring(xp)) or nil, items = hasItems and items or nil,
            caption = quest.rewardChoice == true and self:T("rewardChoice") or self:T("rewardAlso"),
            loading = self:T("loading") }
    end
end

--- The quest's sections in the template's order.
function QuestGroup:Sections(quest, group, isStep)
    local sections = {}
    for _, name in ipairs(self.template.detailSections) do
        sections[#sections + 1] = self:Section(name, quest, group, isStep)
    end
    return sections
end

--- The quest page for `quest` in `group`: its questline's steps when it ends a questline, else its own sections.
function QuestGroup:Page(quest, group)
    local page = { questID = quest.id, pinText = {
        title = self:T("pinTitle"), coords = self:T("pinCoords"), hint = self:T("pinHint"),
        unavailable = self:T("pinUnavailable"), target = self:T("pinTarget"),
    } }
    local questline = Feed:GetQuestline(quest.id)
    if not (questline and #questline > 1) then
        page.sections = self:Sections(quest, group, false)
        return page
    end
    page.steps = {}
    for i, step in ipairs(questline) do
        local stepQuest = step.quest
        local level = (stepQuest.reqLevel and stepQuest.reqLevel > 0 and stepQuest.reqLevel) or stepQuest.questLevel or 0
        page.steps[i] = {
            id = step.id, title = self:T("step", step.stepIndex, self:Slot("quest.title", stepQuest)),
            level = level, levelText = self:T("level", tostring(level)),
            isCompleted = step.isCompleted, isActive = step.isActive or Feed:IsQuestActive(step.id),
            sections = self:Sections(stepQuest, group, true),
        }
    end
    return page
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.QuestGroup)
