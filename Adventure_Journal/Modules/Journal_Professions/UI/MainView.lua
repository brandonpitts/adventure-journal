-- ============================================================================
-- Journal_Professions - UI/MainView.lua
-- Base view for the Professions plugin ("Under Construction" WoW Forever plaque).
-- ============================================================================
local addonName, parent = ...
local ns = parent.Professions or {} ; parent.Professions = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Applies the beveled bronze/slate plaque frame to `card`.
local function stylePlaqueCard(card)
    local white8x8 = Constants.ASSETS.WHITE_8X8

    local cardBg = card:CreateTexture(nil, "BACKGROUND")
    cardBg:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    cardBg:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 1)
    cardBg:SetTexture(white8x8)
    cardBg:SetVertexColor(0.14, 0.12, 0.10, 0.88)

    local headerGlow = card:CreateTexture(nil, "BORDER")
    headerGlow:SetHeight(48)
    headerGlow:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    headerGlow:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
    headerGlow:SetTexture(white8x8)
    headerGlow:SetVertexColor(0.32, 0.23, 0.12, 0.35)

    local bTop = card:CreateTexture(nil, "ARTWORK")
    bTop:SetHeight(1)
    bTop:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    bTop:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
    bTop:SetTexture(white8x8)
    bTop:SetVertexColor(0.58, 0.46, 0.26, 0.90)

    local bBottom = card:CreateTexture(nil, "ARTWORK")
    bBottom:SetHeight(1)
    bBottom:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
    bBottom:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
    bBottom:SetTexture(white8x8)
    bBottom:SetVertexColor(0.30, 0.24, 0.14, 0.90)

    local bLeft = card:CreateTexture(nil, "ARTWORK")
    bLeft:SetWidth(1)
    bLeft:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -1)
    bLeft:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 1)
    bLeft:SetTexture(white8x8)
    bLeft:SetVertexColor(0.44, 0.35, 0.20, 0.90)

    local bRight = card:CreateTexture(nil, "ARTWORK")
    bRight:SetWidth(1)
    bRight:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -1)
    bRight:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 1)
    bRight:SetTexture(white8x8)
    bRight:SetVertexColor(0.44, 0.35, 0.20, 0.90)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local MainView = {
    rootFrame = nil,
}

--- Builds the initial Professions base view inside `parentCanvas`.
--- @param parentCanvas Frame
function MainView:Init(parentCanvas)
    if self.rootFrame then
        return
    end

    local root = CreateFrame("Frame", nil, parentCanvas)
    root:SetAllPoints(parentCanvas)

    local card = CreateFrame("Frame", nil, root)
    card:SetSize(Constants.CARD.WIDTH, Constants.CARD.HEIGHT)
    card:SetPoint("CENTER", root, "CENTER", 0, 6)
    stylePlaqueCard(card)

    local iconFrame = CreateFrame("Frame", nil, card)
    iconFrame:SetSize(Constants.CARD.ICON_BOX_SIZE, Constants.CARD.ICON_BOX_SIZE)
    iconFrame:SetPoint("TOP", card, "TOP", 0, -28)

    local iconBorder = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBorder:SetAllPoints(iconFrame)
    iconBorder:SetTexture(Constants.ASSETS.WHITE_8X8)
    iconBorder:SetVertexColor(0.62, 0.49, 0.26, 0.95)

    local iconWell = iconFrame:CreateTexture(nil, "BORDER")
    iconWell:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 2, -2)
    iconWell:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
    iconWell:SetTexture(Constants.ASSETS.WHITE_8X8)
    iconWell:SetVertexColor(0.08, 0.07, 0.06, 1.0)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -4, 4)
    icon:SetTexture(Constants.ASSETS.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", iconFrame, "BOTTOM", 0, -16)
    title:SetText(Constants.COPY.HEADING)

    local divider = card:CreateTexture(nil, "ARTWORK")
    divider:SetSize(Constants.CARD.DIVIDER_WIDTH, 1)
    divider:SetPoint("TOP", title, "BOTTOM", 0, -8)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.48, 0.38, 0.22, 0.70)

    local subtitle = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", divider, "BOTTOM", 0, -12)
    subtitle:SetWidth(400)
    subtitle:SetJustifyH("CENTER")
    subtitle:SetText(Constants.COPY.SUBTITLE)

    self.rootFrame = root
end

--- Resets and displays the root Professions base view (invoked when selecting the
--- `Professions` bottom tab or clicking `Professions` in the header breadcrumb bar).
function MainView:ShowRoot()
    if self.rootFrame then
        self.rootFrame:Show()
    end
end

--- Hides the Professions view when switching away to another tab or Home.
function MainView:Hide()
    if self.rootFrame then
        self.rootFrame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.MainView = MainView

