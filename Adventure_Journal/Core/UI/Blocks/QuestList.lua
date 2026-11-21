-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/QuestList.lua
-- The quest list on a book's left page, drawn from QuestGroup's rows: one
-- pale slab button per quest with its status marker (the questline marker for
-- a questline), name, and level in its difficulty color. A section
-- can open with a divider (the other faction's quests).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local max = math.max
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local PlaySound = PlaySound

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks
local Styles = ns.UI.Styles
local BUTTON_GAP = 26
local HEADER_HEIGHT = 26 -- a section header: its title over a divider
local NAME = { 1.0, 0.82, 0.0 }
local NAME_SELECTED = { 1.0, 0.94, 0.50 }

local function shadowed(fs)
    fs:SetShadowColor(0, 0, 0, 1.0)
    fs:SetShadowOffset(1, -1)
    return fs
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestList = {}
QuestList.__index = QuestList

--- A quest list drawn into `child` (the left page's scroll child; `scroll` its scroll frame). Buttons are
--- `width` x `height`. `onSelect(quest)` runs on a click.
function QuestList:Create(scroll, child, width, height, onSelect)
    local list = setmetatable({ scroll = scroll, child = child, width = width, height = height,
        onSelect = onSelect, buttons = {}, dividers = {}, dividerCount = 0 }, QuestList)
    return list
end

function QuestList:CreateButton()
    local btn = CreateFrame("Button", nil, self.child)
    btn:SetSize(self.width, self.height)
    Blocks.SlabButton:Style(btn, "quest")



    local marker = btn:CreateTexture(nil, "OVERLAY")
    marker:SetSize(24, 24)
    marker:SetPoint("CENTER", btn, "LEFT", 22, 0)
    marker:SetAtlas("QuestNormal")
    btn.marker = marker

    local levelText = shadowed(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    levelText:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
    levelText:SetJustifyH("RIGHT")
    btn.levelText = levelText

    local nameText = shadowed(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    nameText:SetTextColor(NAME[1], NAME[2], NAME[3])
    nameText:SetPoint("LEFT", btn, "LEFT", 40, 0)
    nameText:SetPoint("RIGHT", levelText, "LEFT", -6, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(true)
    nameText:SetHeight(btn:GetHeight() - 6)
    btn.nameText = nameText

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function(b)
        PlaySound(Styles.SOUNDS.CLICK)
        self.onSelect(b.quest)
    end)
    return btn
end

--- Fills one button from `row` (QuestGroup:Rows).
function QuestList:SetButton(btn, row)
    btn.quest = row.quest
    btn.nameText:SetText(row.name)
    btn.levelText:SetText(row.levelText)
    btn.levelText:SetTextColor(ns.LevelColors:ForText(row.level))
    Blocks.QuestMarker:Apply(btn.marker, Blocks.QuestMarker:Status(row.isCompleted, row.isActive), "list",
        row.isQuestline)

    Blocks.SlabButton:SetSelected(btn, row.isSelected)
    local c = row.isSelected and NAME_SELECTED or NAME
    btn.nameText:SetTextColor(c[1], c[2], c[3])
end

--- A section header (pooled): its title over a divider.
function QuestList:Header(index)
    self.headers = self.headers or {}
    local header = self.headers[index]
    if not header then
        header = CreateFrame("Frame", nil, self.child)
        header:SetHeight(HEADER_HEIGHT)
        local title = shadowed(header:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        title:SetPoint("TOPLEFT", header, "TOPLEFT", 6, 0)
        title:SetJustifyH("LEFT")
        header.title = title
        local divider = Blocks.Divider:CreateHorizontal(header, 4)
        divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 4, 0)
        divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -8, 0)
        self.headers[index] = header
    end
    header:Show()
    return header
end

--- The next divider between sections (pooled).
function QuestList:SectionDivider()
    self.dividerCount = self.dividerCount + 1
    local divider = self.dividers[self.dividerCount]
    if not divider then
        divider = Blocks.Divider:CreateHorizontal(self.child, 4)
        self.dividers[self.dividerCount] = divider
    end
    return divider
end

--- Draws `sections` (QuestGroup:Rows: `{ { header, dividerBefore, rows } }`) in order. A section with a header
--- opens with it; one with `dividerBefore`, or following a headed section, opens with a divider when buttons are
--- drawn above it. Sizes the scroll child.
function QuestList:Render(sections)
    self:Hide()
    local y, index, headers, afterHeader = -16, 0, 0, false
    local function add(row)
        index = index + 1
        local btn = self.buttons[index]
        if not btn then
            btn = self:CreateButton()
            self.buttons[index] = btn
        end
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.child, "TOPLEFT", 18, y)
        btn:SetSize(self.width, self.height)
        self:SetButton(btn, row)
        btn:Show()
        y = y - (self.height + BUTTON_GAP)
    end
    for _, section in ipairs(sections) do
        if #section.rows > 0 then
            if section.header then
                headers = headers + 1
                local header = self:Header(headers)
                header:ClearAllPoints()
                local headerTop = y + 6
                header:SetPoint("TOPLEFT", self.child, "TOPLEFT", 10, headerTop)
                header:SetPoint("RIGHT", self.child, "RIGHT", -14, 0)
                header.title:SetText(section.header)
                y = headerTop - HEADER_HEIGHT - 12
            elseif (section.dividerBefore or afterHeader) and index > 0 then
                local divider = self:SectionDivider()
                local dividerY = y + 13
                divider:ClearAllPoints()
                divider:SetPoint("TOPLEFT", self.child, "TOPLEFT", 10, dividerY)
                divider:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -14, dividerY)
                divider:Show()
                y = dividerY - 20
            end
            afterHeader = section.header ~= nil
            for _, row in ipairs(section.rows) do
                add(row)
            end
        end
    end
    local height = -y + 16
    self.child:SetHeight(max(1, height))
    ns.UI.ScrollFrame:UpdateBar(self.scroll, height)
end

--- Hides every button, header and divider.
function QuestList:Hide()
    for _, btn in ipairs(self.buttons) do
        btn:Hide()
    end
    for _, divider in ipairs(self.dividers) do
        divider:Hide()
    end
    self.dividerCount = 0
    for _, header in ipairs(self.headers or {}) do
        header:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.QuestList = QuestList
