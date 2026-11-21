-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/QuestSections.lua
-- The sections of a quest's detail (QuestPage.lua's section models):
-- Objectives, a Quest Source or Turn-In row with its map pin, Requirements,
-- and Rewards. Each draws through a QuestDetail writer (`detail`) at a given
-- x and y and returns the y below it, so the questline view and the single-quest
-- view share them with their own spacing.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local max = math.max
local min = math.min

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local GOLD = { 1.0, 0.82, 0.20 }
local BODY = { 0.92, 0.88, 0.80 }
local XP = { 0.80, 0.95, 0.80 }
local PIN_SIZE = 36
local LINE = 16 -- a header line, and the step from a header to its body
local LOG_BUTTON_DROP = 5 -- the quest log button sits this far below the header line's top

local function header(detail, text, x, y, width)
    local fs = detail:Text("GameFontNormal", GOLD[1], GOLD[2], GOLD[3], false, width)
    fs:SetPoint("TOPLEFT", detail.child, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

local function body(detail, text, x, y, width)
    local fs = detail:Text("GameFontHighlightSmall", BODY[1], BODY[2], BODY[3], true, width)
    fs:SetPoint("TOPLEFT", detail.child, "TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestSections = {}

--- The objectives header and text. `width` nil uses the writer's text width. A section with `logQuestID` (a
--- quest in the player's log) puts the quest log button at their right, two lines tall, the text narrowed for it.
function QuestSections:Objectives(detail, section, x, y, width)
    local top = y
    if section.logQuestID then
        local LogButton = ns.UI.Blocks.QuestLogButton
        local button = detail:LogButton()
        local full = width or detail.textWidth
        button:SetPoint("TOPLEFT", detail.child, "TOPLEFT", x + full - LogButton.WIDTH, y - LOG_BUTTON_DROP)
        LogButton:Configure(button, section.logQuestID, section.logText)
        width = full - LogButton.WIDTH - 8
    end
    header(detail, section.header, x, y, width)
    y = y - LINE
    local fs = body(detail, section.body, x, y, width)
    y = y - (fs:GetStringHeight() or 14)
    if section.logQuestID then
        y = min(y, top - LOG_BUTTON_DROP - ns.UI.Blocks.QuestLogButton.HEIGHT)
    end
    return y - 24
end

--- One Quest Source or Turn-In row: the map pin at `pinX`, then the header and text at `textX`, `fieldWidth`
--- wide. A section without a point greys the pin out with its reason. `pinText` is the page's pin wording.
--- `gapAfter` is the space under the row.
function QuestSections:GiverRow(detail, section, pinText, pinX, textX, y, fieldWidth, gapAfter)
    local pin = detail:Pin()
    pin:SetPoint("TOPLEFT", detail.child, "TOPLEFT", pinX, y)
    local map = section.point
    local hasCoords = map ~= nil and map.mapID ~= nil and map.x ~= nil and map.y ~= nil
    ns.UI.Blocks.MapPinButton:Configure(pin, hasCoords and map or nil, section.label, section.reason, pinText)
    header(detail, section.header, textX, y - 2, fieldWidth)
    local fs = body(detail, section.body, textX, y - 2 - LINE, fieldWidth)
    local bodyHeight = max(14, fs:GetStringHeight() or 14)
    return y - max(PIN_SIZE, 2 + LINE + bodyHeight) - gapAfter
end

--- The requirements header and its line.
function QuestSections:Requirements(detail, section, x, y, width)
    header(detail, section.header, x, y, width)
    y = y - LINE
    local fs = body(detail, section.body, x, y, width)
    return y - (fs:GetStringHeight() or 14) - 4
end

--- A divider, the rewards header, the experience line and the reward grid.
--- `rightInset` is the divider's distance from the right edge; `width` the header width (nil: the writer's);
--- `gridWidth` the reward grid's width.
function QuestSections:Rewards(detail, section, x, y, rightInset, width, gridWidth)
    y = y - 8
    local divider = detail:Divider()
    divider:SetPoint("TOPLEFT", detail.child, "TOPLEFT", x, y)
    divider:SetPoint("TOPRIGHT", detail.child, "TOPRIGHT", -rightInset, y)
    y = y - 4 - 12
    header(detail, section.header, x, y, width)
    y = y - LINE
    if section.xpText then
        local fs = detail:Text("GameFontHighlightSmall", XP[1], XP[2], XP[3], false, width)
        fs:SetPoint("TOPLEFT", detail.child, "TOPLEFT", x, y)
        fs:SetText(section.xpText)
        y = y - LINE
    end
    if section.items then
        y = ns.UI.Blocks.RewardGrid:Layout(detail, detail.child, section.items, x, y, gridWidth, section.caption,
            section.loading)
    end
    return y
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.QuestSections = QuestSections
