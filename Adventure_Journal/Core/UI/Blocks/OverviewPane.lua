-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/OverviewPane.lua
-- An instance's overview: its loading-screen art in a dialog-border frame
-- with its name across the top, a divider, its description, and a Show on
-- Map button that opens the world map at its entrance.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local format = string.format
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local CreateColor = CreateColor
local GameTooltip = GameTooltip
local PlaySound = PlaySound

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks
local Styles = ns.UI.Styles
local LORE = { 0.92, 0.85, 0.72 }

local function createMapButton(pane, anchor)
    local btn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    btn:SetSize(200, 32)
    btn:SetPoint("TOP", anchor, "BOTTOM", 0, -18)
    btn:RegisterForClicks("LeftButtonUp")
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetAtlas("Dungeon")
    icon:SetPoint("LEFT", btn, "LEFT", 36, 0)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText("Show on Map")
    label:SetTextColor(1.0, 0.82, 0.15)
    label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    btn:SetScript("OnEnter", function(b)
        if not b.entrance then
            return
        end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show on World Map", 1.0, 0.82, 0.0)
        if b.entrance.name then
            GameTooltip:AddLine(format(b.text.named, b.entrance.name), 1.0, 1.0, 1.0, true)
        else
            GameTooltip:AddLine(b.text.unnamed, 1.0, 1.0, 1.0, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(b)
        PlaySound(Styles.SOUNDS.CLICK)
        if b.entrance then
            ns.GameApi:OpenWorldMap(b.entrance.uiMapID)
        end
    end)
    return btn
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local OverviewPane = {}
OverviewPane.__index = OverviewPane

--- An overview pane filling `page` (less its margins), with an art frame of `artWidth` x `artHeight`.
function OverviewPane:Create(page, artWidth, artHeight)
    local pane = CreateFrame("Frame", nil, page)
    pane:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -8)
    pane:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 6)
    local overview = setmetatable({ frame = pane }, OverviewPane)

    local artBox = CreateFrame("Frame", nil, pane)
    artBox:SetSize(artWidth, artHeight)
    artBox:SetPoint("TOPLEFT", pane, "TOPLEFT", 4, -22)

    local backing = artBox:CreateTexture(nil, "BACKGROUND")
    backing:SetAllPoints(artBox)
    backing:SetTexture(Styles.ASSETS.WHITE_8X8)
    backing:SetVertexColor(0.06, 0.05, 0.04, 0.98)

    local art = artBox:CreateTexture(nil, "ARTWORK", nil, 0)
    art:SetPoint("TOPLEFT", artBox, "TOPLEFT", 2, -2)
    art:SetPoint("BOTTOMRIGHT", artBox, "BOTTOMRIGHT", -2, 2)
    overview.art = art

    -- Darkens the art's top so the name reads
    local shade = artBox:CreateTexture(nil, "ARTWORK", nil, 2)
    shade:SetPoint("TOPLEFT", artBox, "TOPLEFT", 2, -2)
    shade:SetPoint("TOPRIGHT", artBox, "TOPRIGHT", -2, -2)
    shade:SetHeight(48)
    shade:SetTexture(Styles.ASSETS.WHITE_8X8)
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.05), CreateColor(0, 0, 0, 0.80))

    local banner = artBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    banner:SetPoint("TOP", artBox, "TOP", 0, -14)
    banner:SetTextColor(1.0, 0.84, 0.18)
    overview.banner = banner

    local border = CreateFrame("Frame", nil, artBox, "BackdropTemplate")
    border:SetPoint("TOPLEFT", artBox, "TOPLEFT", -8, 8)
    border:SetPoint("BOTTOMRIGHT", artBox, "BOTTOMRIGHT", 8, -8)
    border:SetFrameLevel(artBox:GetFrameLevel() + 5)
    border:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24 })
    border:SetBackdropBorderColor(1, 1, 1, 1)

    local divider = Blocks.Divider:CreateHorizontal(pane, 4)
    divider:SetPoint("TOPLEFT", artBox, "BOTTOMLEFT", 0, -14)
    divider:SetPoint("TOPRIGHT", artBox, "BOTTOMRIGHT", 0, -14)

    local lore = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lore:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 4, -12)
    lore:SetWidth(artWidth - 8)
    lore:SetJustifyH("LEFT")
    lore:SetJustifyV("TOP")
    lore:SetSpacing(4)
    lore:SetTextColor(LORE[1], LORE[2], LORE[3])
    overview.lore = lore

    overview.mapButton = createMapButton(pane, lore)
    return overview
end

--- Shows `instance` with `lore` under its art (nil leaves it blank). `entrance` (InstanceAccess:GetEntrance) shows
--- the Show on Map button; nil hides it. `mapText`: the button's tooltip lines, `{ named, unnamed }`.
function OverviewPane:Show(instance, entrance, lore, mapText)
    self.banner:SetText((instance.fullName or ""):upper())
    Blocks.InstanceArt:Apply(self.art, instance)
    self.lore:SetText(lore or "")
    self.mapButton.text = mapText
    ns.UI.WindowBackground:ColorBodyText(self.lore, LORE[1], LORE[2], LORE[3])
    self.mapButton.entrance = entrance
    self.mapButton:SetShown(entrance ~= nil)
    self.frame:Show()
end

function OverviewPane:Hide()
    self.frame:Hide()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.OverviewPane = OverviewPane
