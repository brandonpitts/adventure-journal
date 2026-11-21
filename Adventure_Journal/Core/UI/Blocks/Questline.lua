-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/Questline.lua
-- A questline on a QuestDetail page: one banner per step (status, title,
-- level); a step's banner opens to its sections, indented under it. The
-- first unfinished step starts open.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestDetail = Blocks.QuestDetail

--- A questline (`page.steps`): one banner per step; open steps show their sections.
function QuestDetail:RenderQuestline(page)
    local steps = page.steps
    if self.openQuestID ~= page.questID then
        self.openQuestID, self.openSteps = page.questID, {}
        local first
        for _, step in ipairs(steps) do
            first = first or (not step.isCompleted and step.id)
        end
        self.openSteps[first or steps[#steps].id] = true
    end

    local y = -4
    for _, step in ipairs(steps) do
        local banner = self:Banner()
        banner:SetPoint("TOPLEFT", self.child, "TOPLEFT", 4, y)
        banner:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -4, y)
        local isOpen = self.openSteps[step.id] == true
        Blocks.QuestlineBanner:Set(banner, step, Blocks.QuestMarker:Status(step.isCompleted, step.isActive), isOpen)
        banner:SetScript("OnClick", function()
            self.openSteps[step.id] = not self.openSteps[step.id]
            self:Render(self.page)
        end)
        y = y - 32
        if isOpen then
            y = self:RenderStep(page, step, y - 4) - 6
        end
        y = y - 4
    end
    return y
end

--- One open step's sections, indented under its banner.
function QuestDetail:RenderStep(page, step, y)
    local Sections = Blocks.QuestSections
    local bodyX, bodyWidth = 14, self.contentWidth - 24
    local pinX = bodyX + 6
    local textX = pinX + 36 + 8
    local fieldWidth = bodyWidth - (textX - bodyX)
    for _, section in ipairs(step.sections) do
        if section.kind == "objectives" then
            y = Sections:Objectives(self, section, bodyX, y, bodyWidth)
        elseif section.kind == "giver" then
            y = Sections:GiverRow(self, section, page.pinText, pinX, textX, y, fieldWidth,
                section.role == "source" and 12 or 14)
        elseif section.kind == "requirements" then
            y = Sections:Requirements(self, section, bodyX, y, bodyWidth)
        elseif section.kind == "rewards" then
            y = Sections:Rewards(self, section, bodyX, y, bodyX, bodyWidth, bodyWidth)
        end
    end
    return y
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.Blocks.QuestDetail)
