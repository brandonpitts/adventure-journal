-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/EncounterList.lua
-- The boss list on a book's left page: encounter buttons (a medallion bulb on
-- a warm slab, name, level tag) in sections. Sections come from the caller in
-- order; each may have a header line (label in its color, divider under it),
-- a divider after it, or a divider before it.
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
local NAME = { 1.0, 0.88, 0.55 }
local NAME_HOVER = { 1.0, 0.94, 0.68 }
local NAME_SELECTED = { 1.0, 0.98, 0.82 }
local LEFT_MARGIN = 26
local START_Y = -16

local function shadowed(fs)
    fs:SetShadowColor(0, 0, 0, 1.0)
    fs:SetShadowOffset(1, -1)
    return fs
end

local function placeAcross(region, child, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", child, "TOPLEFT", 10, y)
    region:SetPoint("TOPRIGHT", child, "TOPRIGHT", -14, y)
    region:Show()
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local EncounterList = {}
EncounterList.__index = EncounterList

--- An encounter list drawn into `child` (the left page's scroll child; `scroll` its scroll frame). `sizes`:
--- `{ width, height, gap, iconSize, ringSize }` of the buttons. `onSelect(encounter)` runs on a click.
function EncounterList:Create(scroll, child, sizes, onSelect)
    local list = setmetatable({ scroll = scroll, child = child, sizes = sizes, onSelect = onSelect,
        buttons = {}, headers = {}, dividers = {} }, EncounterList)
    return list
end

function EncounterList:CreateButton()
    local sizes = self.sizes
    local btn = CreateFrame("Button", nil, self.child)
    btn:SetSize(sizes.width, sizes.height)
    Blocks.SlabButton:Style(btn, "encounter")

    -- The medallion reaches past the slab's left edge
    local medallion = Blocks.Medallion:Create(btn, sizes.iconSize, sizes.ringSize)
    medallion:SetPoint("LEFT", btn, "LEFT", -10, 0)
    medallion:SetFrameLevel(btn:GetFrameLevel() + 5)
    btn.medallion = medallion

    local nameText = shadowed(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    local file, size, flags = nameText:GetFont()
    nameText:SetFont(file, (size or 12) + 2, flags or "")
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(true)
    nameText:SetSpacing(2)
    btn.nameText = nameText

    local levelText = shadowed(btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
    levelText:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    levelText:SetJustifyH("RIGHT")
    levelText:Hide()
    btn.levelText = levelText

    btn:HookScript("OnEnter", function(b)
        if self.selected ~= b.boss then
            b.nameText:SetTextColor(NAME_HOVER[1], NAME_HOVER[2], NAME_HOVER[3])
        end
    end)
    btn:HookScript("OnLeave", function(b)
        if self.selected ~= b.boss then
            b.nameText:SetTextColor(NAME[1], NAME[2], NAME[3])
        end
    end)
    btn:SetScript("OnClick", function(b)
        PlaySound(Styles.SOUNDS.CLICK)
        if b.boss then
            self.onSelect(b.boss)
        end
    end)
    return btn
end

--- A section header: `label` in `color` with a divider under it.
function EncounterList:Header(index)
    local hdr = self.headers[index]
    if not hdr then
        hdr = CreateFrame("Frame", nil, self.child)
        hdr:SetHeight(26)
        local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", hdr, "TOPLEFT", 6, 0)
        title:SetPoint("TOPRIGHT", hdr, "TOPRIGHT", -6, 0)
        title:SetJustifyH("LEFT")
        hdr.title = title
        local divider = Blocks.Divider:CreateHorizontal(hdr, 4)
        divider:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 4, 0)
        divider:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -8, 0)
        self.headers[index] = hdr
    end
    return hdr
end

function EncounterList:Divider(index)
    self.dividers[index] = self.dividers[index] or Blocks.Divider:CreateHorizontal(self.child, 4)
    return self.dividers[index]
end

--- Fills one button for `boss`.
function EncounterList:SetButton(btn, boss, options)
    local isSelected = self.selected == boss
    Blocks.Medallion:SetEncounterPortrait(btn.medallion, boss, options.iconFor and options.iconFor(boss))
    Blocks.Medallion:SyncRing(btn.medallion)
    Blocks.Medallion:SetClassification(btn.medallion, boss)
    Blocks.SlabButton:SetSelected(btn, isSelected)

    btn.nameText:ClearAllPoints()
    btn.nameText:SetPoint("LEFT", btn, "LEFT", 56, 0)
    btn.nameText:SetPoint("RIGHT", btn, "RIGHT", options.showLevel and -58 or -12, 0)
    btn.nameText:SetText(boss.name or "")
    local c = isSelected and NAME_SELECTED or NAME
    btn.nameText:SetTextColor(c[1], c[2], c[3])

    if options.showLevel then
        Blocks.LevelTag:ApplyEncounter(btn.levelText, boss, options.useDifficultyColor)
        btn.levelText:Show()
    else
        btn.levelText:Hide()
    end
end

--- Draws `sections` in order. Each section: `{ encounters, label, color, dividerAfter, dividerBefore }`; a
--- `label` adds a header line. `options`: `selected` (the selected encounter), `showLevel`,
--- `useDifficultyColor`, `instance` (for portraits), `iconFor(encounter)` (the icon shown without a portrait).
--- Returns the number of buttons drawn.
function EncounterList:Render(sections, options)
    self:Hide()
    self.selected = options.selected
    local sizes = self.sizes
    local step = sizes.height + sizes.gap
    local y, index, headerIndex, dividerIndex = START_Y, 0, 0, 0
    local lastButtonY

    local function addButton(boss)
        index = index + 1
        local btn = self.buttons[index] or self:CreateButton()
        self.buttons[index] = btn
        btn.boss = boss
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.child, "TOPLEFT", LEFT_MARGIN, y)
        self:SetButton(btn, boss, options)
        btn:Show()
        lastButtonY = y
    end

    for _, section in ipairs(sections) do
        if #section.encounters > 0 then
            if section.dividerBefore then
                dividerIndex = dividerIndex + 1
                placeAcross(self:Divider(dividerIndex), self.child, y)
                y = y - 30
            end
            if section.label then
                y = y - 14
                headerIndex = headerIndex + 1
                local hdr = self:Header(headerIndex)
                hdr.title:SetText(section.label)
                hdr.title:SetTextColor(section.color[1], section.color[2], section.color[3])
                placeAcross(hdr, self.child, y)
                y = y - 44
            end
            for _, boss in ipairs(section.encounters) do
                addButton(boss)
                y = y - step
            end
            if section.dividerAfter then
                dividerIndex = dividerIndex + 1
                placeAcross(self:Divider(dividerIndex), self.child, y)
                y = y - 30
            end
        end
    end

    local height
    if sections[#sections].dividerBefore and lastButtonY and #sections[#sections].encounters > 0 then
        -- The list ends on a section after a divider: measure to the last button's bottom
        height = -(lastButtonY - sizes.height - 6) + 16
    else
        height = index > 0 and (-y + 10) or 1
    end
    self.child:SetHeight(max(1, height))
    ns.UI.ScrollFrame:UpdateBar(self.scroll, height)
    return index
end

--- Hides every button, header and divider.
function EncounterList:Hide()
    for _, group in ipairs({ self.buttons, self.headers, self.dividers }) do
        for _, region in ipairs(group) do
            region:Hide()
        end
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.EncounterList = EncounterList
