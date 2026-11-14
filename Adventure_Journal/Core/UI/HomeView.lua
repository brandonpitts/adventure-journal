-- ============================================================================
-- Journal_Base - UI/HomeView.lua
-- Canonical WoW Forever Journal style sheet & Home page:
--   * Sits over `MainFrame`'s `CollectionsBackgroundTemplate` (Appearances dark stone + corner filigrees)
--   * Uses the actual in-game `ObjectiveTrackerFrame.Header.Background` texture for the
--     top header divider and card title dividers (3-sliced so the diamond finials never stretch)
--   * Module button cards feature a single clean bronze border with `4px` notched corner
--     geometry (zero black outer moat or multi-border clutter) and 4-quadrant circular
--     window-portrait icon borders.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local _G = _G
local ipairs = ipairs
local pairs = pairs
local math = math
local pcall = pcall
local tostring = tostring
local CreateFrame = CreateFrame
local CreateColor = CreateColor
local C_Texture = C_Texture
local PlaySound = PlaySound
local SetPortraitToTexture = SetPortraitToTexture
local Constants = ns.Constants

local GRID_COLS = 2
local CARD_WIDTH = 352
local CARD_HEIGHT = 114
local CARD_GAP_X = 20
local CARD_GAP_Y = 18
local GRID_TOP_OFFSET = -68
local GRID_LEFT_OFFSET = 21

local CORNER_STEP = 4
local FOOTER_HEIGHT = 20
local ICON_AREA_WIDTH = 82
local MEDALLION_ICON_SIZE = 46
local MEDALLION_SIZE = 58

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Resolves the texture file and UV rectangle `[uL, uR, vT, vB]` of the in-game
--- `ObjectiveTrackerFrame.Header.Background` texture identified via `/fstack`.
local function getObjectiveHeaderTextureInfo()
    local tracker = _G.ObjectiveTrackerFrame
    local srcBg = tracker and tracker.Header and tracker.Header.Background
    if not srcBg then
        local questTracker = _G.QuestObjectiveTracker
        srcBg = questTracker and questTracker.Header and questTracker.Header.Background
    end

    if srcBg then
        local atlas = srcBg.GetAtlas and srcBg:GetAtlas()
        if atlas and C_Texture and C_Texture.GetAtlasInfo then
            local info = C_Texture.GetAtlasInfo(atlas)
            if info and (info.file or info.filename) then
                return (info.file or info.filename),
                    info.leftTexCoord or 0,
                    info.rightTexCoord or 1,
                    info.topTexCoord or 0,
                    info.bottomTexCoord or 1
            end
        end

        local tex = srcBg:GetTexture()
        if tex then
            local ulx, uly, llx, lly, urx = srcBg:GetTexCoord()
            return tex, ulx or 0, urx or 1, uly or 0, lly or 1
        end
    end

    -- Fallback if `Blizzard_ObjectiveTracker` has not initialized yet: try atlas `"Objective-Header"`
    if C_Texture and C_Texture.GetAtlasInfo then
        local info = C_Texture.GetAtlasInfo("Objective-Header")
        if info and (info.file or info.filename) then
            return (info.file or info.filename),
                info.leftTexCoord or 0,
                info.rightTexCoord or 1,
                info.topTexCoord or 0,
                info.bottomTexCoord or 1
        end
    end

    return nil, 0, 1, 0, 1
end

--- Applies or refreshes the 3-slice in-game `ObjectiveTrackerFrame.Header.Background`
--- top bronze divider bar onto `bar` so it uses Blizzard's actual drawn divider + finials.
local function syncQuestDividerBar(bar)
    local texFile, uL, uR, vT, vB = getObjectiveHeaderTextureInfo()
    if not texFile then
        return
    end

    -- The top horizontal bronze bar with diamond finials occupies the top 20% of `ObjectiveTrackerFrame.Header.Background`
    local vBarTop = vT
    local vBarBot = vT + (vB - vT) * 0.20

    -- Left 5% and right 5% hold the left/right diamond finials; middle 90% is the straight bronze bar
    local uCapL = uL + (uR - uL) * 0.055
    local uCapR = uR - (uR - uL) * 0.055

    bar.leftCap:SetTexture(texFile)
    bar.leftCap:SetTexCoord(uL, uCapL, vBarTop, vBarBot)

    bar.rightCap:SetTexture(texFile)
    bar.rightCap:SetTexCoord(uCapR, uR, vBarTop, vBarBot)

    bar.centerLine:SetTexture(texFile)
    bar.centerLine:SetTexCoord(uCapL, uCapR, vBarTop, vBarBot)
end

--- Creates a divider line using the actual in-game `ObjectiveTrackerFrame.Header.Background`
--- texture (3-sliced so the left/right finials stay unstretched at any width).
local function createQuestDividerBar(parentFrame, leftPoint, leftX, leftY, rightPoint, rightX, rightY, barHeight)
    local h = barHeight or 6
    local capW = math.floor(h * 2.2 + 0.5)

    local bar = CreateFrame("Frame", nil, parentFrame)
    bar:SetHeight(h)
    bar:SetPoint("LEFT", parentFrame, leftPoint, leftX, leftY)
    bar:SetPoint("RIGHT", parentFrame, rightPoint, rightX, rightY)
    bar:EnableMouse(false)

    local leftCap = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    leftCap:SetSize(capW, h)
    leftCap:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.leftCap = leftCap

    local rightCap = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    rightCap:SetSize(capW, h)
    rightCap:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    bar.rightCap = rightCap

    local centerLine = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    centerLine:SetHeight(h)
    centerLine:SetPoint("LEFT", leftCap, "RIGHT", 0, 0)
    centerLine:SetPoint("RIGHT", rightCap, "LEFT", 0, 0)
    bar.centerLine = centerLine

    syncQuestDividerBar(bar)
    return bar
end

--- Extracts ONLY the clean top-left 90-degree arc of the main window's portrait ring
--- (`TopLeftCorner`, from its top-left edge to the exact center of `winPortrait`)
--- and mirrors it across all 4 quadrants (`TL`, `TR`, `BL`, `BR`) around `iconTexture`.
local function syncWindowPortraitBorder(medallion)
    local quadrants = medallion.ringQuadrants
    local iconTexture = medallion.iconTexture
    local mainFrame = ns.UI and ns.UI.MainFrame and ns.UI.MainFrame.frame
    if not quadrants or not iconTexture or not mainFrame then
        return
    end

    local winCorner = (mainFrame.NineSlice and mainFrame.NineSlice.TopLeftCorner)
        or mainFrame.TopLeftCorner
        or mainFrame.PortraitFrame
    local winPortrait = mainFrame.portrait
        or (mainFrame.PortraitContainer and mainFrame.PortraitContainer.portrait)

    local texFile = nil
    local uL, uR, vT, vB = 0, 1, 0, 1

    if winCorner then
        local atlas = winCorner.GetAtlas and winCorner:GetAtlas()
        if atlas and C_Texture and C_Texture.GetAtlasInfo then
            local info = C_Texture.GetAtlasInfo(atlas)
            if info and (info.file or info.filename) then
                texFile = info.file or info.filename
                uL = info.leftTexCoord or 0
                uR = info.rightTexCoord or 1
                vT = info.topTexCoord or 0
                vB = info.bottomTexCoord or 1
            end
        end
        if not texFile then
            texFile = winCorner:GetTexture()
            local ulx, uly, llx, lly, urx = winCorner:GetTexCoord()
            if ulx and urx and uly and lly then
                uL, uR, vT, vB = ulx, urx, uly, lly
            end
        end
    end

    local pw, ph = 60, 60
    if winPortrait then
        local w, h = winPortrait:GetSize()
        if w and w > 0 then
            pw, ph = w, h
        end
    end

    local cw, ch = 134, 134
    if winCorner then
        local w, h = winCorner:GetSize()
        if w and w > 0 then
            cw, ch = w, h
        end
    end

    local dx, dy = -8, 9
    if winCorner and winPortrait and winCorner:GetLeft() and winPortrait:GetLeft() and winCorner:GetTop() and winPortrait:GetTop() then
        dx = winCorner:GetLeft() - winPortrait:GetLeft()
        dy = winCorner:GetTop() - winPortrait:GetTop()
    end

    local qWidth = (-dx) + (pw * 0.5)
    local qHeight = dy + (ph * 0.5)

    local uMid = uL + (uR - uL) * (qWidth / cw)
    local vMid = vT + (vB - vT) * (qHeight / ch)

    local scale = MEDALLION_ICON_SIZE / pw
    local dispW = qWidth * scale
    local dispH = qHeight * scale

    local configs = {
        { q = quadrants.TL, anchor = "BOTTOMRIGHT", u1 = uL,   u2 = uMid, v1 = vT,   v2 = vMid },
        { q = quadrants.TR, anchor = "BOTTOMLEFT",  u1 = uMid, u2 = uL,   v1 = vT,   v2 = vMid },
        { q = quadrants.BL, anchor = "TOPRIGHT",    u1 = uL,   u2 = uMid, v1 = vMid, v2 = vT   },
        { q = quadrants.BR, anchor = "TOPLEFT",     u1 = uMid, u2 = uL,   v1 = vMid, v2 = vT   },
    }

    for _, cfg in ipairs(configs) do
        local tex = cfg.q
        if texFile then
            tex:SetTexture(texFile)
            tex:SetTexCoord(cfg.u1, cfg.u2, cfg.v1, cfg.v2)
        end
        tex:ClearAllPoints()
        tex:SetSize(dispW, dispH)
        tex:SetPoint(cfg.anchor, iconTexture, "CENTER", 0, 0)
    end
end

--- Builds the circular icon medallion on the left of a card.
local function buildCircularIconMedallion(card)
    local medallion = CreateFrame("Frame", nil, card)
    medallion:SetSize(MEDALLION_SIZE, MEDALLION_SIZE)
    medallion:SetPoint("LEFT", card, "LEFT", 14, (FOOTER_HEIGHT * 0.5) - 1)
    medallion:EnableMouse(false)

    local back = medallion:CreateTexture(nil, "BORDER", nil, 1)
    back:SetSize(MEDALLION_ICON_SIZE + 2, MEDALLION_ICON_SIZE + 2)
    back:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    back:SetTexture(Constants.ASSETS.MINIMAP_BG)
    back:SetVertexColor(0.05, 0.04, 0.04, 0.98)

    local iconTexture = medallion:CreateTexture(nil, "ARTWORK", nil, 2)
    iconTexture:SetSize(MEDALLION_ICON_SIZE, MEDALLION_ICON_SIZE)
    iconTexture:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    medallion.iconTexture = iconTexture

    if medallion.CreateMaskTexture then
        local iconMask = medallion:CreateMaskTexture()
        iconMask:SetAllPoints(iconTexture)
        iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        iconTexture:AddMaskTexture(iconMask)
    end

    medallion.ringQuadrants = {
        TL = medallion:CreateTexture(nil, "OVERLAY", nil, 4),
        TR = medallion:CreateTexture(nil, "OVERLAY", nil, 4),
        BL = medallion:CreateTexture(nil, "OVERLAY", nil, 4),
        BR = medallion:CreateTexture(nil, "OVERLAY", nil, 4),
    }

    syncWindowPortraitBorder(medallion)
    return medallion, iconTexture
end

--- Collects all texture regions belonging to an in-game `InsetFrameTemplate` border
--- so we can brighten them on mouseover or dim them when disabled.
local function collectInsetBorderRegions(insetFrame)
    local regions = {}
    local function gather(f)
        if not f or not f.GetRegions then
            return
        end
        local list = { f:GetRegions() }
        for _, r in ipairs(list) do
            if r and r.IsObjectType and r:IsObjectType("Texture") and r ~= insetFrame.Bg then
                regions[#regions + 1] = r
            end
        end
    end
    gather(insetFrame)
    if insetFrame.NineSlice then
        gather(insetFrame.NineSlice)
    end
    return regions
end

--- Updates the visual state of `card` for resting vs mouseover vs disabled states.
local function updateCardVisualState(card, isHovered)
    if not card.isEnabled then
        card.amberBase:SetVertexColor(0.16, 0.15, 0.14, 0.92)
        card.stoneFill:SetVertexColor(0.22, 0.21, 0.20, 0.28)
        card.hoverGlow:Hide()
        if card.medallion and card.medallion.ringQuadrants then
            for _, q in pairs(card.medallion.ringQuadrants) do
                q:SetDesaturated(true)
                q:SetVertexColor(0.55, 0.55, 0.55, 0.85)
            end
        end
        for _, r in ipairs(card.borderPieces) do
            r:SetDesaturated(true)
            r:SetVertexColor(0.50, 0.48, 0.44, 0.80)
        end
        card.title:SetTextColor(0.62, 0.60, 0.56)
        card.description:SetTextColor(0.55, 0.52, 0.48)
        return
    end

    if card.medallion and card.medallion.ringQuadrants then
        for _, q in pairs(card.medallion.ringQuadrants) do
            q:SetDesaturated(false)
        end
    end
    for _, r in ipairs(card.borderPieces) do
        r:SetDesaturated(false)
    end

    if isHovered then
        card.amberBase:SetVertexColor(0.35, 0.24, 0.09, 0.96)
        card.stoneFill:SetVertexColor(0.85, 0.62, 0.26, 0.62)
        card.hoverGlow:Show()
        if card.medallion and card.medallion.ringQuadrants then
            for _, q in pairs(card.medallion.ringQuadrants) do
                q:SetVertexColor(1.0, 0.96, 0.78, 1.0)
            end
        end
        for _, r in ipairs(card.borderPieces) do
            r:SetVertexColor(1.0, 0.92, 0.62, 1.0)
        end
        card.title:SetTextColor(1.0, 0.95, 0.72)
        card.description:SetTextColor(1.0, 0.90, 0.58)
    else
        card.amberBase:SetVertexColor(0.26, 0.18, 0.07, 0.94)
        card.stoneFill:SetVertexColor(0.60, 0.42, 0.17, 0.48)
        card.hoverGlow:Hide()
        if card.medallion and card.medallion.ringQuadrants then
            for _, q in pairs(card.medallion.ringQuadrants) do
                q:SetVertexColor(1.0, 1.0, 1.0, 1.0)
            end
        end
        for _, r in ipairs(card.borderPieces) do
            r:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        end
        card.title:SetTextColor(1.0, 1.0, 1.0)
        card.description:SetTextColor(0.95, 0.82, 0.45)
    end
end

--- Builds a module button card using the real in-game `InsetFrameTemplate` border at
--- `SetAllPoints(card)` (zero outer black moat), with the card's bronze-stone surface
--- placed at `ARTWORK` sublevel `-2` (`2px` inset) so it covers `InsetFrameTemplate`'s
--- inner black drop-shadow trench and leaves only the single clean in-game bronze border.
local function buildModuleCard(card)
    local white = Constants.ASSETS.WHITE_8X8
    local pad = 2

    -- 1. In-Game `InsetFrameTemplate` Border spanning the full card (no outer black moat)
    local insetBorder = CreateFrame("Frame", nil, card, "InsetFrameTemplate")
    insetBorder:SetAllPoints(card)
    insetBorder:EnableMouse(false)
    if insetBorder.Bg then
        insetBorder.Bg:Hide()
    end
    card.insetBorder = insetBorder
    card.borderPieces = collectInsetBorderRegions(insetBorder)

    -- 2. Warm Bronze Base Fill + Additive Stone Relief placed on `insetBorder` at `ARTWORK`
    -- sublevel `-2` (`2px` inset) so it sits ABOVE `InsetFrameTemplate`'s inner black shadow
    -- trench (`BORDER` layer), leaving only the single crisp 2px in-game bronze border visible!
    local amberBase = insetBorder:CreateTexture(nil, "ARTWORK", nil, -2)
    amberBase:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -pad)
    amberBase:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -pad, pad)
    amberBase:SetTexture(white)
    amberBase:SetVertexColor(0.26, 0.18, 0.07, 0.94)
    card.amberBase = amberBase

    local stoneFill = insetBorder:CreateTexture(nil, "ARTWORK", nil, -1)
    stoneFill:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -pad)
    stoneFill:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -pad, pad)
    stoneFill:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
    stoneFill:SetHorizTile(true)
    stoneFill:SetVertTile(true)
    stoneFill:SetBlendMode("ADD")
    stoneFill:SetVertexColor(0.60, 0.42, 0.17, 0.48)
    card.stoneFill = stoneFill

    -- 3. Interactive Mouseover Illumination Overlay
    local hoverGlow = insetBorder:CreateTexture(nil, "ARTWORK", nil, 0)
    hoverGlow:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -pad)
    hoverGlow:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -pad, FOOTER_HEIGHT)
    hoverGlow:SetTexture(white)
    hoverGlow:SetBlendMode("ADD")
    if CreateColor and hoverGlow.SetGradient then
        local botGlow = CreateColor(0.85, 0.62, 0.18, 0.08)
        local topGlow = CreateColor(1.0, 0.84, 0.36, 0.22)
        pcall(hoverGlow.SetGradient, hoverGlow, "VERTICAL", botGlow, topGlow)
    else
        hoverGlow:SetVertexColor(1.0, 0.82, 0.32, 0.15)
    end
    hoverGlow:Hide()
    card.hoverGlow = hoverGlow

    -- 4. Subtle Bronze-Tinted Footer Strip (warm dark bronze, NOT black)
    local footerBg = insetBorder:CreateTexture(nil, "ARTWORK", nil, 1)
    footerBg:SetHeight(FOOTER_HEIGHT - pad)
    footerBg:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", pad, pad)
    footerBg:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -pad, pad)
    footerBg:SetTexture(white)
    footerBg:SetVertexColor(0.14, 0.09, 0.04, 0.38)

    local footerTopLine = insetBorder:CreateTexture(nil, "ARTWORK", nil, 2)
    footerTopLine:SetHeight(1)
    footerTopLine:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", pad, FOOTER_HEIGHT)
    footerTopLine:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -pad, FOOTER_HEIGHT)
    footerTopLine:SetTexture(white)
    footerTopLine:SetVertexColor(0.56, 0.43, 0.21, 0.48)

    local versionText = insetBorder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    versionText:SetPoint("LEFT", footerBg, "LEFT", 8, 0)
    versionText:SetTextColor(0.82, 0.72, 0.52)
    card.versionText = versionText

    local dateText = insetBorder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dateText:SetPoint("RIGHT", footerBg, "RIGHT", -8, 0)
    dateText:SetTextColor(0.74, 0.66, 0.52)
    card.dateText = dateText

    -- 5. Left Circular Medallion & Right Content Area (with in-game Quest divider bar)
    local medallion, iconTexture = buildCircularIconMedallion(insetBorder)
    card.medallion = medallion
    card.icon = iconTexture

    local title = insetBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", ICON_AREA_WIDTH, -10)
    card.title = title

    local badge = insetBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -12)
    card.badge = badge

    local titleDivider = createQuestDividerBar(
        insetBorder,
        "TOPLEFT", ICON_AREA_WIDTH - 2, -29,
        "TOPRIGHT", -10, -29,
        5
    )
    card.titleDivider = titleDivider

    local description = insetBorder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    description:SetPoint("TOPLEFT", titleDivider, "BOTTOMLEFT", 2, -3)
    description:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, FOOTER_HEIGHT + 5)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetTextColor(0.95, 0.82, 0.45)
    card.description = description
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local HomeView = {
    rootFrame = nil,
    topDivider = nil,
    cards = {},
}

--- Creates the Home page over `MainFrame`'s `CollectionsBackgroundTemplate` stone canvas.
--- @param parentCanvas Frame
--- @return Frame
function HomeView:Create(parentCanvas)
    if self.rootFrame then
        return self.rootFrame
    end

    local root = CreateFrame("Frame", nil, parentCanvas)
    root:SetAllPoints(parentCanvas)

    -- Top "Modules" section header + subtitle shifted right to `x = 70` so it sits
    -- completely clear of `CollectionsBackgroundTemplate`'s top-left corner filigree
    local pageTitle = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    pageTitle:SetPoint("TOPLEFT", root, "TOPLEFT", 70, -15)
    pageTitle:SetText("Modules")

    local pageSub = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pageSub:SetPoint("LEFT", pageTitle, "RIGHT", 14, -1)
    pageSub:SetText("Select an installed module below to open it, or assign a default Home tab in Settings.")
    pageSub:SetTextColor(0.82, 0.74, 0.58)

    -- Top Divider using the actual in-game `ObjectiveTrackerFrame.Header.Background` bar
    self.topDivider = createQuestDividerBar(root, "TOPLEFT", 32, -45, "TOPRIGHT", -32, -45, 6)

    root:SetScript("OnShow", function()
        self:Refresh()
    end)

    self.rootFrame = root
    self.cards = {}
    self:Refresh()
    return root
end

--- Acquires or creates the `index`-th module button card on the Home grid.
--- @param index number
--- @return Button
function HomeView:AcquireCard(index)
    local card = self.cards[index]
    if card then
        card:Show()
        return card
    end

    card = CreateFrame("Button", nil, self.rootFrame)
    card:SetSize(CARD_WIDTH, CARD_HEIGHT)
    buildModuleCard(card)

    local col = (index - 1) % GRID_COLS
    local row = math.floor((index - 1) / GRID_COLS)
    local x = GRID_LEFT_OFFSET + col * (CARD_WIDTH + CARD_GAP_X)
    local y = GRID_TOP_OFFSET - row * (CARD_HEIGHT + CARD_GAP_Y)
    card:SetPoint("TOPLEFT", self.rootFrame, "TOPLEFT", x, y)

    card:SetScript("OnEnter", function(btn)
        if not btn.isEnabled then
            return
        end
        updateCardVisualState(btn, true)
    end)

    card:SetScript("OnLeave", function(btn)
        btn.title:SetPoint("TOPLEFT", btn, "TOPLEFT", ICON_AREA_WIDTH, -10)
        updateCardVisualState(btn, false)
    end)

    card:SetScript("OnMouseDown", function(btn)
        if not btn.isEnabled then
            return
        end
        btn.title:SetPoint("TOPLEFT", btn, "TOPLEFT", ICON_AREA_WIDTH + 1, -11)
    end)

    card:SetScript("OnMouseUp", function(btn)
        btn.title:SetPoint("TOPLEFT", btn, "TOPLEFT", ICON_AREA_WIDTH, -10)
    end)

    card:SetScript("OnClick", function(btn)
        if not btn.pluginId or not btn.isEnabled then
            return
        end
        if PlaySound then
            PlaySound(Constants.SOUNDS.TAB)
        end
        ns.PluginRegistry:ActivatePlugin(btn.pluginId)
    end)

    self.cards[index] = card
    return card
end

--- Re-populates the Home page cards in the user's current plugin order (`GetCatalogPlugins`).
function HomeView:Refresh()
    if not self.rootFrame then
        return
    end

    if self.topDivider then
        syncQuestDividerBar(self.topDivider)
    end

    for _, card in ipairs(self.cards) do
        card:Hide()
    end

    local catalog = ns.PluginRegistry:GetCatalogPlugins()
    local defaultLandingId = ns.Database:GetDefaultLandingPluginId()

    local cardIndex = 1
    for _, entry in ipairs(catalog) do
        if entry.id ~= "home" and not entry.isUtility then
            local card = self:AcquireCard(cardIndex)
            card.pluginId = entry.id
            card.isEnabled = entry.isEnabled

            syncWindowPortraitBorder(card.medallion)
            if card.titleDivider then
                syncQuestDividerBar(card.titleDivider)
            end

            if SetPortraitToTexture then
                local ok = pcall(SetPortraitToTexture, card.icon, entry.icon)
                if not ok then
                    card.icon:SetTexture(entry.icon)
                end
            else
                card.icon:SetTexture(entry.icon)
            end
            card.icon:SetDesaturated(not entry.isEnabled)
            card.icon:SetAlpha(entry.isEnabled and 1.0 or 0.45)

            card.title:SetText(entry.title)
            card.description:SetText(entry.description)

            if not entry.isInstalled then
                card.badge:SetText("|cff808080Not Installed|r")
            elseif not entry.isEnabled then
                card.badge:SetText("|cff999999Disabled|r")
            elseif defaultLandingId == entry.id then
                card.badge:SetText("|cffffd100Default Tab|r")
            else
                card.badge:SetText("|cff40ff40Installed|r")
            end

            card.versionText:SetText("v" .. tostring(entry.version))
            card.dateText:SetText("Updated " .. tostring(entry.lastUpdated))

            updateCardVisualState(card, card:IsMouseOver() and entry.isEnabled)
            cardIndex = cardIndex + 1
        end
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.HomeView = HomeView
