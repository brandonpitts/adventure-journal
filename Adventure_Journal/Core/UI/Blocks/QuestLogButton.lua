-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/QuestLogButton.lua
-- The arrow at the right of a quest's Objectives: opens the world map and quest log to
-- that one quest, as clicking its title in the objective tracker does. Shown
-- only for a quest in the player's quest log. Hover and press follow the map
-- pin (MapPinButton).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local SetCursor = SetCursor
local ResetCursor = ResetCursor
local SOUNDKIT = SOUNDKIT

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- The game's travel-directions arrow (Wowpedia: Iconsmall-obj265), 26x34, drawn two text lines tall
local ATLAS = "poi-traveldirections-arrow"
local WIDTH, HEIGHT = 24, 31

local function setOffset(btn, x, y)
    btn.icon:SetPoint("CENTER", btn, "CENTER", x, y)
    btn.hl:SetPoint("CENTER", btn, "CENTER", x, y)
end

local function onEnter(btn)
    SetCursor("Interface\\CURSOR\\Point")
    btn.icon:SetVertexColor(1.0, 0.95, 0.60, 1.0)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine(btn.text.title, 1.0, 0.82, 0.0)
    GameTooltip:AddLine(btn.text.hint, 0.25, 0.92, 0.32, true)
    GameTooltip:Show()
end

local function onLeave(btn)
    ResetCursor()
    btn.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    GameTooltip:Hide()
end

local function onClick(btn)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    ns.GameApi:OpenQuestInLog(btn.questID)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestLogButton = {}

QuestLogButton.WIDTH, QuestLogButton.HEIGHT = WIDTH, HEIGHT

--- A quest log button on `parent`, drawn above the parent's other contents.
--- @return Button
function QuestLogButton:Create(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(WIDTH, HEIGHT)
    btn:SetFrameLevel(parent:GetFrameLevel() + 25)
    btn:SetHitRectInsets(-4, -4, -4, -4)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(WIDTH, HEIGHT)
    icon:SetAtlas(ATLAS)
    btn.icon = icon
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(WIDTH, HEIGHT)
    hl:SetAtlas(ATLAS)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.95, 0.80, 0.35, 0.35)
    btn.hl = hl
    setOffset(btn, 0, 0)

    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnMouseDown", function(b) setOffset(b, 1, -1) end)
    btn:SetScript("OnMouseUp", function(b) setOffset(b, 0, 0) end)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", onLeave)
    btn:SetScript("OnClick", onClick)
    return btn
end

--- Points the button at `questID`. `text` is the tooltip's wording: `{ title, hint }`.
function QuestLogButton:Configure(btn, questID, text)
    btn.questID, btn.text = questID, text
    btn.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.QuestLogButton = QuestLogButton
