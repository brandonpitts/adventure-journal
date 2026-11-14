-- ============================================================================
-- Journal_Dungeons - UI/SharedWidgets.lua
-- UI widgets and style helpers for Dungeon Grid and Book views.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pcall = pcall
local type = type
local CreateFrame = CreateFrame
local SetPortraitToTexture = SetPortraitToTexture
local SetPortraitTextureFromCreatureDisplayID = SetPortraitTextureFromCreatureDisplayID
local GetFileIDFromPath = GetFileIDFromPath
local Constants = ns.Constants

local FDJ_PORTRAIT_PATH = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Portraits\\"

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Resolves texture path and UV coordinates for objective tracker header background.
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

        local tex = srcBg.GetTexture and srcBg:GetTexture()
        if tex then
            local ulx, uly, llx, lly, urx = srcBg:GetTexCoord()
            return tex, ulx or 0, urx or 1, uly or 0, lly or 1
        end
    end

    -- Fallback if ObjectiveTrackerFrame not initialized yet
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

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local SharedWidgets = {}

--- Creates a horizontal etched divider bar matching the clean, bright vertical spine divider.
--- Features a delicate 1px warm bronze highlight line paired with a 1px recessed dark shadow,
--- with smooth alpha fade-outs at the left and right ends.
--- @param parent Frame
--- @param height number|nil
--- @return Frame
function SharedWidgets:CreateHorizontalDividerBar(parent, height)
    local h = height or 4
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(h)

    local fadeW = 28
    local white = Constants.ASSETS.WHITE_8X8

    -- Bronze highlight line (1px)
    local bronzeLeft = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bronzeLeft:SetHeight(1)
    bronzeLeft:SetWidth(fadeW)
    bronzeLeft:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
    bronzeLeft:SetTexture(white)

    local bronzeRight = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bronzeRight:SetHeight(1)
    bronzeRight:SetWidth(fadeW)
    bronzeRight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -1)
    bronzeRight:SetTexture(white)

    local bronzeCenter = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bronzeCenter:SetHeight(1)
    bronzeCenter:SetPoint("LEFT", bronzeLeft, "RIGHT", 0, 0)
    bronzeCenter:SetPoint("RIGHT", bronzeRight, "LEFT", 0, 0)
    bronzeCenter:SetTexture(white)
    bronzeCenter:SetVertexColor(0.65, 0.52, 0.28, 0.80)

    -- Recessed dark stone shadow line (1px directly below at Y = -2)
    local shadowLeft = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    shadowLeft:SetHeight(1)
    shadowLeft:SetWidth(fadeW)
    shadowLeft:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -2)
    shadowLeft:SetTexture(white)

    local shadowRight = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    shadowRight:SetHeight(1)
    shadowRight:SetWidth(fadeW)
    shadowRight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -2)
    shadowRight:SetTexture(white)

    local shadowCenter = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    shadowCenter:SetHeight(1)
    shadowCenter:SetPoint("LEFT", shadowLeft, "RIGHT", 0, 0)
    shadowCenter:SetPoint("RIGHT", shadowRight, "LEFT", 0, 0)
    shadowCenter:SetTexture(white)
    shadowCenter:SetVertexColor(0.08, 0.06, 0.04, 0.55)

    if bronzeLeft.SetGradient and CreateColor then
        bronzeLeft:SetGradient("HORIZONTAL", CreateColor(0.65, 0.52, 0.28, 0.0), CreateColor(0.65, 0.52, 0.28, 0.80))
        bronzeRight:SetGradient("HORIZONTAL", CreateColor(0.65, 0.52, 0.28, 0.80), CreateColor(0.65, 0.52, 0.28, 0.0))
        shadowLeft:SetGradient("HORIZONTAL", CreateColor(0.08, 0.06, 0.04, 0.0), CreateColor(0.08, 0.06, 0.04, 0.55))
        shadowRight:SetGradient("HORIZONTAL", CreateColor(0.08, 0.06, 0.04, 0.55), CreateColor(0.08, 0.06, 0.04, 0.0))
    else
        bronzeLeft:SetVertexColor(0.65, 0.52, 0.28, 0.40)
        bronzeRight:SetVertexColor(0.65, 0.52, 0.28, 0.40)
        shadowLeft:SetVertexColor(0.08, 0.06, 0.04, 0.25)
        shadowRight:SetVertexColor(0.08, 0.06, 0.04, 0.25)
    end

    return bar
end

--- Backward-compatible alias for CreateHorizontalDividerBar.
function SharedWidgets:CreateQuestDividerBar(parent, height, _capWidth)
    return self:CreateHorizontalDividerBar(parent, height)
end

--- Synchronizes a divider bar.
--- @param bar Frame
function SharedWidgets:SyncQuestDividerBar(bar)
end

--- Creates a vertical 2-tone etched divider bar with alpha fade finials.
--- @param parent Frame
--- @param width number|nil
--- @return Frame
function SharedWidgets:CreateVerticalDividerBar(parent, width)
    local w = width or 4
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(w)

    local fadeH = 28
    local white = Constants.ASSETS.WHITE_8X8

    -- Bronze highlight line (1px)
    local bronzeTop = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bronzeTop:SetWidth(1)
    bronzeTop:SetHeight(fadeH)
    bronzeTop:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, 0)
    bronzeTop:SetTexture(white)

    local bronzeBot = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bronzeBot:SetWidth(1)
    bronzeBot:SetHeight(fadeH)
    bronzeBot:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 1, 0)
    bronzeBot:SetTexture(white)

    local bronzeCenter = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    bronzeCenter:SetWidth(1)
    bronzeCenter:SetPoint("TOPLEFT", bronzeTop, "BOTTOMLEFT", 0, 0)
    bronzeCenter:SetPoint("BOTTOMLEFT", bronzeBot, "TOPLEFT", 0, 0)
    bronzeCenter:SetTexture(white)
    bronzeCenter:SetVertexColor(0.65, 0.52, 0.28, 0.80)

    -- Recessed dark stone shadow line (1px directly adjacent on the right)
    local shadowTop = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    shadowTop:SetWidth(1)
    shadowTop:SetHeight(fadeH)
    shadowTop:SetPoint("TOPLEFT", bar, "TOPLEFT", 2, 0)
    shadowTop:SetTexture(white)

    local shadowBot = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    shadowBot:SetWidth(1)
    shadowBot:SetHeight(fadeH)
    shadowBot:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 2, 0)
    shadowBot:SetTexture(white)

    local shadowCenter = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    shadowCenter:SetWidth(1)
    shadowCenter:SetPoint("TOPLEFT", shadowTop, "BOTTOMLEFT", 0, 0)
    shadowCenter:SetPoint("BOTTOMLEFT", shadowBot, "TOPLEFT", 0, 0)
    shadowCenter:SetTexture(white)
    shadowCenter:SetVertexColor(0.08, 0.06, 0.04, 0.55)

    if bronzeTop.SetGradient and CreateColor then
        bronzeTop:SetGradient("VERTICAL", CreateColor(0.65, 0.52, 0.28, 0.80), CreateColor(0.65, 0.52, 0.28, 0.0))
        bronzeBot:SetGradient("VERTICAL", CreateColor(0.65, 0.52, 0.28, 0.0), CreateColor(0.65, 0.52, 0.28, 0.80))
        shadowTop:SetGradient("VERTICAL", CreateColor(0.08, 0.06, 0.04, 0.55), CreateColor(0.08, 0.06, 0.04, 0.0))
        shadowBot:SetGradient("VERTICAL", CreateColor(0.08, 0.06, 0.04, 0.0), CreateColor(0.08, 0.06, 0.04, 0.55))
    else
        bronzeTop:SetVertexColor(0.65, 0.52, 0.28, 0.40)
        bronzeBot:SetVertexColor(0.65, 0.52, 0.28, 0.40)
        shadowTop:SetVertexColor(0.08, 0.06, 0.04, 0.25)
        shadowBot:SetVertexColor(0.08, 0.06, 0.04, 0.25)
    end

    return bar
end

--- Updates scrollbar visibility on a ScrollFrame based on whether content exceeds viewable height.
--- @param scrollFrame ScrollFrame
--- @param contentHeight number|nil
function SharedWidgets:UpdateScrollFrameVisibility(scrollFrame, contentHeight)
    if not scrollFrame then
        return
    end

    scrollFrame.scrollBarHideable = true

    local scrollBar = (scrollFrame.GetName and _G[scrollFrame:GetName() .. "ScrollBar"]) or scrollFrame.ScrollBar
    if not scrollBar then
        return
    end

    local viewHeight = scrollFrame:GetHeight() or 0
    local targetHeight = contentHeight or (scrollFrame:GetScrollChild() and scrollFrame:GetScrollChild():GetHeight()) or 0
    local canScroll = (viewHeight > 0 and targetHeight > (viewHeight + 1))

    if canScroll then
        scrollBar:Show()
    else
        scrollBar:Hide()
        if scrollFrame.SetVerticalScroll then
            scrollFrame:SetVerticalScroll(0)
        end
    end
end

--- Creates a circular medallion frame with `iconSize` interior and `ringSize`
--- 4-quadrant window-portrait border copied from `JournalBaseMainFrame`.
--- Applies `TempPortraitAlphaMask` so the icon texture never bleeds outside the ring.
--- @param parent Frame
--- @param iconSize number
--- @param ringSize number
--- @return Frame medallion
function SharedWidgets:CreateCircularMedallion(parent, iconSize, ringSize)
    local medallion = CreateFrame("Frame", nil, parent)
    medallion:SetSize(iconSize, iconSize)
    medallion.iconSize = iconSize
    medallion.ringSize = ringSize

    local iconWell = medallion:CreateTexture(nil, "BORDER", nil, 1)
    iconWell:SetAllPoints(medallion)
    iconWell:SetTexture(Constants.ASSETS.WHITE_8X8)
    iconWell:SetVertexColor(0.04, 0.04, 0.03, 0.96)
    medallion.iconWell = iconWell

    local icon = medallion:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetAllPoints(medallion)
    medallion.icon = icon

    -- Apply Alpha Mask so ALL contents (textures, icons, loading-screen art)
    -- are 100% clipped to a smooth circle and NEVER bleed out past the ring.
    if medallion.CreateMaskTexture then
        local mask = medallion:CreateMaskTexture()
        mask:SetAllPoints(icon)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        icon:AddMaskTexture(mask)
        medallion.mask = mask

        local wellMask = medallion:CreateMaskTexture()
        wellMask:SetAllPoints(iconWell)
        wellMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        iconWell:AddMaskTexture(wellMask)
        medallion.wellMask = wellMask
    end

    local ringFrame = CreateFrame("Frame", nil, medallion)
    ringFrame:SetSize(ringSize, ringSize)
    ringFrame:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    ringFrame:SetFrameLevel(medallion:GetFrameLevel() + 3)
    medallion.ringFrame = ringFrame

    local qTL = ringFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    qTL:SetPoint("TOPLEFT", ringFrame, "TOPLEFT", 0, 0)
    qTL:SetPoint("BOTTOMRIGHT", ringFrame, "CENTER", 0, 0)

    local qTR = ringFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    qTR:SetPoint("TOPRIGHT", ringFrame, "TOPRIGHT", 0, 0)
    qTR:SetPoint("BOTTOMLEFT", ringFrame, "CENTER", 0, 0)

    local qBL = ringFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    qBL:SetPoint("BOTTOMLEFT", ringFrame, "BOTTOMLEFT", 0, 0)
    qBL:SetPoint("TOPRIGHT", ringFrame, "CENTER", 0, 0)

    local qBR = ringFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    qBR:SetPoint("BOTTOMRIGHT", ringFrame, "BOTTOMRIGHT", 0, 0)
    qBR:SetPoint("TOPLEFT", ringFrame, "CENTER", 0, 0)

    medallion.ringQuads = { TL = qTL, TR = qTR, BL = qBL, BR = qBR }

    -- Luminous hover highlight for the circular portrait
    local highlightIcon = medallion:CreateTexture(nil, "OVERLAY", nil, 4)
    highlightIcon:SetAllPoints(medallion)
    highlightIcon:SetTexture(Constants.ASSETS.WHITE_8X8)
    highlightIcon:SetBlendMode("ADD")
    highlightIcon:SetVertexColor(1.0, 0.92, 0.65, 0.35)
    if medallion.mask then
        highlightIcon:AddMaskTexture(medallion.mask)
    end
    highlightIcon:Hide()
    medallion.highlightIcon = highlightIcon

    -- Luminous hover highlight for the 4-quadrant frame ring
    local hTL = ringFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    hTL:SetPoint("TOPLEFT", ringFrame, "TOPLEFT", 0, 0)
    hTL:SetPoint("BOTTOMRIGHT", ringFrame, "CENTER", 0, 0)
    hTL:SetBlendMode("ADD")
    hTL:SetVertexColor(1.0, 0.90, 0.60, 0.70)
    hTL:Hide()

    local hTR = ringFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    hTR:SetPoint("TOPRIGHT", ringFrame, "TOPRIGHT", 0, 0)
    hTR:SetPoint("BOTTOMLEFT", ringFrame, "CENTER", 0, 0)
    hTR:SetBlendMode("ADD")
    hTR:SetVertexColor(1.0, 0.90, 0.60, 0.70)
    hTR:Hide()

    local hBL = ringFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    hBL:SetPoint("BOTTOMLEFT", ringFrame, "BOTTOMLEFT", 0, 0)
    hBL:SetPoint("TOPRIGHT", ringFrame, "CENTER", 0, 0)
    hBL:SetBlendMode("ADD")
    hBL:SetVertexColor(1.0, 0.90, 0.60, 0.70)
    hBL:Hide()

    local hBR = ringFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    hBR:SetPoint("BOTTOMRIGHT", ringFrame, "BOTTOMRIGHT", 0, 0)
    hBR:SetPoint("TOPLEFT", ringFrame, "CENTER", 0, 0)
    hBR:SetBlendMode("ADD")
    hBR:SetVertexColor(1.0, 0.90, 0.60, 0.70)
    hBR:Hide()

    medallion.ringHighlightQuads = { TL = hTL, TR = hTR, BL = hBL, BR = hBR }

    --- Toggles interactive mouseover illumination on portrait and frame ring.
    --- @param isHighlighted boolean
    function medallion:SetHighlighted(isHighlighted)
        local show = isHighlighted and true or false
        if self.highlightIcon then
            self.highlightIcon:SetShown(show)
        end
        if self.ringHighlightQuads then
            self.ringHighlightQuads.TL:SetShown(show)
            self.ringHighlightQuads.TR:SetShown(show)
            self.ringHighlightQuads.BL:SetShown(show)
            self.ringHighlightQuads.BR:SetShown(show)
        end
    end

    -- Classification Dragon overlay (Gold Elite for bosses, Silver Rare for rare spawns)
    local dragonFrame = CreateFrame("Frame", nil, medallion)
    dragonFrame:SetSize(iconSize * 1.8, iconSize * 1.5)
    dragonFrame:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    dragonFrame:SetFrameLevel(ringFrame:GetFrameLevel() + 2)
    medallion.dragonFrame = dragonFrame

    local dragon = dragonFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    dragon:SetAllPoints(dragonFrame)
    dragon:Hide()
    medallion.dragon = dragon

    self:SyncWindowPortraitBorder(medallion)
    return medallion
end

--- Sets the classification dragon overlay for a circular medallion using
--- Blizzard's isolated target portrait atlases (as used in Leatrix Plus).
--- Gold Elite for dungeon bosses, Silver Rare for rare spawns, none for normal/special mobs.
--- @param medallion Frame
--- @param boss table|nil
function SharedWidgets:SetMedallionClassification(medallion, boss)
    if not medallion or not medallion.dragon then
        return
    end
    if not boss then
        medallion.dragon:Hide()
        return
    end

    local isRare = (not boss.isChallenge) and (boss.rare or boss.isRare or (boss.classification == "rare") or (boss.classification == "rareelite"))
    local isMinor = boss.isNormal or boss.normal or boss.special or (boss.isBoss == false) or (boss.classification == "normal")
        or boss.isMinor or (boss.classification == "minor") or (boss.classification == "quest")
        or boss.isTrash or (boss.classification == "trash")

    if isMinor then
        medallion.dragon:Hide()
        return
    end

    local atlas = isRare and "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver" or "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"
    local iconSize = medallion.iconSize or 40
    local tex = medallion.dragon
    local parent = medallion.dragonFrame or medallion
    local applied = false

    -- 1. Query C_Texture for the isolated Blizzard dragon atlas (Leatrix Plus modern style)
    if C_Texture and C_Texture.GetAtlasInfo then
        local info = C_Texture.GetAtlasInfo(atlas)
        if info then
            local file = info.file or info.filename
            if file then
                tex:SetTexture(file)
                -- Mirror horizontally so dragon curls along outer left and top of portrait
                tex:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
                local scale = iconSize / 60
                local w = (info.width or 82) * scale
                local h = (info.height or 72) * scale
                parent:SetSize(w, h)
                parent:ClearAllPoints()
                parent:SetPoint("CENTER", medallion, "CENTER", -2 * scale, 1 * scale)
                tex:Show()
                applied = true
            end
        end
    end

    -- 2. Direct SetAtlas fallback
    if not applied and tex.SetAtlas then
        local ok = pcall(tex.SetAtlas, tex, atlas, false)
        if ok then
            pcall(tex.SetTexCoord, tex, 1, 0, 0, 1)
            local scale = iconSize / 60
            parent:SetSize(82 * scale, 72 * scale)
            parent:ClearAllPoints()
            parent:SetPoint("CENTER", medallion, "CENTER", -2 * scale, 1 * scale)
            tex:Show()
            applied = true
        end
    end

    -- 3. Classic BLP fallback (tight crop on dragon head & body, completely cutting off the bottom level circle)
    if not applied then
        local classicPath = isRare and "Interface\\TargetingFrame\\UI-TargetingFrame-Rare" or "Interface\\TargetingFrame\\UI-TargetingFrame-Elite"
        tex:SetTexture(classicPath)
        tex:SetTexCoord(0.9570, 0.5567, 0.0, 0.5000)
        local scale = iconSize / 40
        parent:SetSize(62 * scale, 44 * scale)
        parent:ClearAllPoints()
        parent:SetPoint("CENTER", medallion, "CENTER", -4 * scale, 4 * scale)
        tex:Show()
    end
end

--- Synchronizes the 4-quadrant circular icon border with `JournalBaseMainFrame`'s top-left portrait ring.
--- @param medallion Frame
function SharedWidgets:SyncWindowPortraitBorder(medallion)
    local quads = medallion and medallion.ringQuads
    if not quads then
        return
    end

    local mainWin = _G.JournalBaseMainFrame
    local nsFrame = mainWin and mainWin.NineSlice
    local tlCorner = (nsFrame and nsFrame.TopLeftCorner) or (mainWin and mainWin.TopLeftCorner)
    local winPortrait = mainWin and (mainWin.portrait or mainWin.Portrait)
    if not winPortrait and mainWin and mainWin.PortraitContainer then
        winPortrait = mainWin.PortraitContainer.portrait
    end

    if tlCorner and winPortrait then
        local tlL, tlT = tlCorner:GetLeft(), tlCorner:GetTop()
        local tlW, tlH = tlCorner:GetWidth(), tlCorner:GetHeight()
        local pL, pR, pT, pB = winPortrait:GetLeft(), winPortrait:GetRight(), winPortrait:GetTop(), winPortrait:GetBottom()

        if tlL and tlT and tlW and tlW > 0 and tlH and tlH > 0 and pL and pR and pT and pB then
            local pCenterX = (pL + pR) * 0.5
            local pCenterY = (pT + pB) * 0.5
            local fX = (pCenterX - tlL) / tlW
            local fY = (tlT - pCenterY) / tlH

            local atlas = tlCorner.GetAtlas and tlCorner:GetAtlas()
            local tex = tlCorner.GetTexture and tlCorner:GetTexture()
            local qList = { quads.TL, quads.TR, quads.BL, quads.BR }

            for _, q in ipairs(qList) do
                if atlas and atlas ~= "" and q.SetAtlas then
                    pcall(q.SetAtlas, q, atlas, false)
                elseif tex then
                    q:SetTexture(tex)
                end
            end

            local uL, uR, vT, vB = 0, 1, 0, 1
            if tlCorner.GetTexCoord then
                local ul, _, _, vb, ur, vt = tlCorner:GetTexCoord()
                if ul and ur and vt and vb then
                    uL, uR, vT, vB = ul, ur, vt, vb
                end
            end

            local uMid = uL + fX * (uR - uL)
            local vMid = vT + fY * (vB - vT)

            quads.TL:SetTexCoord(uL, vT, uL, vMid, uMid, vT, uMid, vMid)
            quads.TR:SetTexCoord(uMid, vT, uMid, vMid, uL, vT, uL, vMid)
            quads.BL:SetTexCoord(uL, vMid, uL, vT, uMid, vMid, uMid, vT)
            quads.BR:SetTexCoord(uMid, vMid, uMid, vT, uL, vMid, uL, vT)

            if medallion.ringHighlightQuads then
                local hQuads = medallion.ringHighlightQuads
                local hList = { hQuads.TL, hQuads.TR, hQuads.BL, hQuads.BR }
                for _, h in ipairs(hList) do
                    if atlas and atlas ~= "" and h.SetAtlas then
                        pcall(h.SetAtlas, h, atlas, false)
                    elseif tex then
                        h:SetTexture(tex)
                    end
                end
                hQuads.TL:SetTexCoord(uL, vT, uL, vMid, uMid, vT, uMid, vMid)
                hQuads.TR:SetTexCoord(uMid, vT, uMid, vMid, uL, vT, uL, vMid)
                hQuads.BL:SetTexCoord(uL, vMid, uL, vT, uMid, vMid, uMid, vT)
                hQuads.BR:SetTexCoord(uMid, vMid, uMid, vT, uL, vMid, uL, vT)
            end
            return
        end
    end
end

--- Applies a beveled metallic border to a grid tile button.
--- @param btn Button
function SharedWidgets:StyleOutwardBulgingButton(btn)
    local ok, templateFrame = pcall(CreateFrame, "Frame", nil, btn, "EncounterInstanceButtonTemplate")
    if ok and templateFrame then
        templateFrame:SetAllPoints(btn)
        templateFrame:EnableMouse(false)
        btn._templateFrame = templateFrame
        return
    end

    local shadow = btn:CreateTexture(nil, "BACKGROUND", nil, -5)
    shadow:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    shadow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    shadow:SetTexture(Constants.ASSETS.WHITE_8X8)
    shadow:SetVertexColor(0.02, 0.02, 0.01, 0.75)
    btn._dropShadow = shadow

    local baseRim = btn:CreateTexture(nil, "BACKGROUND", nil, -4)
    baseRim:SetAllPoints(btn)
    baseRim:SetTexture(Constants.ASSETS.WHITE_8X8)
    baseRim:SetVertexColor(0.12, 0.10, 0.07, 1.0)
    btn._baseRim = baseRim

    local topHi = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    topHi:SetHeight(1)
    topHi:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    topHi:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    topHi:SetTexture(Constants.ASSETS.WHITE_8X8)
    topHi:SetVertexColor(0.56, 0.48, 0.35, 0.95)
    btn._topHi = topHi

    local leftHi = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    leftHi:SetWidth(1)
    leftHi:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    leftHi:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    leftHi:SetTexture(Constants.ASSETS.WHITE_8X8)
    leftHi:SetVertexColor(0.48, 0.42, 0.32, 0.95)
    btn._leftHi = leftHi

    local botSh = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    botSh:SetHeight(1)
    botSh:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    botSh:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    botSh:SetTexture(Constants.ASSETS.WHITE_8X8)
    botSh:SetVertexColor(0.02, 0.02, 0.02, 0.98)
    btn._botSh = botSh

    local rightSh = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    rightSh:SetWidth(1)
    rightSh:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    rightSh:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    rightSh:SetTexture(Constants.ASSETS.WHITE_8X8)
    rightSh:SetVertexColor(0.03, 0.02, 0.02, 0.98)
    btn._rightSh = rightSh

    if btn.SetPushedTextOffset then
        btn:SetPushedTextOffset(1, -1)
    end
end

--- Frames `btn` as a textured warm stone/leather slab with subtle metallic bevels,
--- matching Retail EncounterJournal boss buttons.
--- @param btn Button
function SharedWidgets:StyleBossSlabButton(btn)
    -- 1. Outer subtle drop shadow
    local shadow = btn:CreateTexture(nil, "BACKGROUND", nil, -5)
    shadow:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    shadow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    shadow:SetTexture(Constants.ASSETS.WHITE_8X8)
    shadow:SetVertexColor(0.02, 0.02, 0.01, 0.60)
    btn._dropShadow = shadow

    -- 2. Base dark rim (1px border)
    local baseRim = btn:CreateTexture(nil, "BACKGROUND", nil, -4)
    baseRim:SetAllPoints(btn)
    baseRim:SetTexture(Constants.ASSETS.WHITE_8X8)
    baseRim:SetVertexColor(0.12, 0.09, 0.06, 0.95)
    btn._baseRim = baseRim

    -- 3. Textured Achievement Parchment fill (#9 from DevTools)
    local fill = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    fill:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    fill:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
    fill:SetVertexColor(0.85, 0.75, 0.60, 0.90)
    btn._slabFill = fill

    -- 4. Subtle top/left highlights and bottom/right shadows for embossed 3D feel
    local topHi = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    topHi:SetHeight(1)
    topHi:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    topHi:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    topHi:SetTexture(Constants.ASSETS.WHITE_8X8)
    topHi:SetVertexColor(0.56, 0.44, 0.26, 0.70)

    local leftHi = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    leftHi:SetWidth(1)
    leftHi:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    leftHi:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    leftHi:SetTexture(Constants.ASSETS.WHITE_8X8)
    leftHi:SetVertexColor(0.48, 0.38, 0.22, 0.60)

    local botSh = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    botSh:SetHeight(1)
    botSh:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    botSh:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    botSh:SetTexture(Constants.ASSETS.WHITE_8X8)
    botSh:SetVertexColor(0.04, 0.03, 0.02, 0.95)

    local rightSh = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    rightSh:SetWidth(1)
    rightSh:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    rightSh:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    rightSh:SetTexture(Constants.ASSETS.WHITE_8X8)
    rightSh:SetVertexColor(0.05, 0.04, 0.02, 0.95)

    -- 5. Selection Glow & Accent
    local selectedGlow = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    selectedGlow:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    selectedGlow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    selectedGlow:SetTexture(Constants.ASSETS.WHITE_8X8)
    selectedGlow:SetVertexColor(0.85, 0.62, 0.18, 0.24)
    selectedGlow:Hide()
    btn.selectedGlow = selectedGlow

    -- 6. Hover Highlight
    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    hover:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    hover:SetTexture(Constants.ASSETS.WHITE_8X8)
    hover:SetBlendMode("ADD")
    hover:SetVertexColor(0.95, 0.80, 0.35, 0.18)

    -- 7. Press-in behavior
    if btn.SetPushedTextOffset then
        btn:SetPushedTextOffset(1, -1)
    end
end

--- Applies an InsetFrameTemplate border with a solid background fill.
--- @param container Frame
--- @param r number|nil
--- @param g number|nil
--- @param b number|nil
--- @param a number|nil
function SharedWidgets:StyleSingleBorderContainer(container, r, g, b, a)
    local ok, inset = pcall(CreateFrame, "Frame", nil, container, "InsetFrameTemplate")
    if ok and inset then
        inset:SetAllPoints(container)
        inset:SetFrameLevel(container:GetFrameLevel())
        if inset.Bg then
            inset.Bg:Hide()
        end
        if inset.NineSlice and inset.NineSlice.Center then
            inset.NineSlice.Center:Hide()
        end
        container.insetBorder = inset
    end

    local fill = container:CreateTexture(nil, "ARTWORK", nil, -2)
    fill:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 2)
    fill:SetTexture(Constants.ASSETS.WHITE_8X8)
    fill:SetVertexColor(r or 0.25, g or 0.18, b or 0.10, a or 0.94)
    container.interiorFill = fill
end

--- Sets a circular icon texture on `medallion.icon` using `SetPortraitToTexture`.
--- @param medallion Frame
--- @param iconPath string|number
function SharedWidgets:SetMedallionIcon(medallion, iconPath)
    if not medallion or not medallion.icon then
        return
    end
    local path = iconPath or Constants.ASSETS.ICON
    local tex = medallion.icon

    if medallion.CreateMaskTexture and not medallion.mask then
        local mask = medallion:CreateMaskTexture()
        mask:SetAllPoints(tex)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        tex:AddMaskTexture(mask)
        medallion.mask = mask
    end

    tex:SetTexCoord(0, 1, 0, 1)
    if SetPortraitToTexture then
        local ok = pcall(SetPortraitToTexture, tex, path)
        if not ok then
            tex:SetTexture(path)
        end
    else
        tex:SetTexture(path)
    end
end

--- Sets boss portrait texture on medallion.icon from displayID portrait, boss.icon, or dungeon.icon.
--- @param medallion Frame
--- @param boss table
--- @param dungeon table
function SharedWidgets:SetBossMedallionPortrait(medallion, boss, dungeon)
    if not medallion or not medallion.icon then
        return
    end
    local tex = medallion.icon

    if medallion.CreateMaskTexture and not medallion.mask then
        local mask = medallion:CreateMaskTexture()
        mask:SetAllPoints(tex)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        tex:AddMaskTexture(mask)
        medallion.mask = mask
    end

    tex:SetTexCoord(0, 1, 0, 1)

    -- 1. Custom boss icon override
    if boss and boss.icon then
        if SetPortraitToTexture then
            local ok = pcall(SetPortraitToTexture, tex, boss.icon)
            if not ok then
                tex:SetTexture(boss.icon)
            end
        else
            tex:SetTexture(boss.icon)
        end
        return
    end

    -- 2. Native engine creature display portrait (2D render of creature model)
    local displayID = boss and (boss.displayID or boss.displayId)
    if displayID and type(displayID) == "number" and displayID > 0 then
        if type(SetPortraitTextureFromCreatureDisplayID) == "function" then
            local ok = pcall(SetPortraitTextureFromCreatureDisplayID, tex, displayID)
            if ok then
                tex:SetTexCoord(0, 1, 0, 1)
                return
            end
        end
    end

    -- 3. Legacy ForeverDungeonJournal baked portrait fallback if loaded
    local fdj = _G.ForeverDungeonJournal_NS
    if displayID and fdj and fdj.BAKED_PORTRAITS and fdj.BAKED_PORTRAITS[displayID] then
        local pPath = FDJ_PORTRAIT_PATH .. displayID
        if SetPortraitToTexture then
            local ok = pcall(SetPortraitToTexture, tex, pPath)
            if not ok then
                tex:SetTexture(pPath)
            end
        else
            tex:SetTexture(pPath)
        end
        return
    end

    if displayID and type(GetFileIDFromPath) == "function" then
        local candidate = FDJ_PORTRAIT_PATH .. displayID .. ".tga"
        local ok, fid = pcall(GetFileIDFromPath, candidate)
        if ok and fid and fid > 0 then
            if SetPortraitToTexture then
                local sOk = pcall(SetPortraitToTexture, tex, candidate)
                if not sOk then
                    tex:SetTexture(candidate)
                end
            else
                tex:SetTexture(candidate)
            end
            return
        end
    end

    -- 4. Clean circular dungeon icon fallback
    local fallback = (dungeon and dungeon.icon) or Constants.ASSETS.ICON
    if SetPortraitToTexture then
        local ok = pcall(SetPortraitToTexture, tex, fallback)
        if not ok then
            tex:SetTexture(fallback)
        end
    else
        tex:SetTexture(fallback)
    end
end


local KNOWN_VALID_FILE_IDS = {
    [131824] = true, -- LoadScreenBlackFathomDeeps
    [131825] = true, -- LoadScreenBlackrockDepths
    [131826] = true, -- LoadScreenBlackrockSpire (LBRS / UBRS)
    [131834] = true, -- LoadScreenDeadmines
    [131836] = true, -- LoadScreenDireMaul (East / West / North)
    [131839] = true, -- LoadScreenDungeon (Universal Fallback)
    [131842] = true, -- LoadScreenGnomeregan
    [131851] = true, -- LoadScreenMaraudon
    [131853] = true, -- LoadScreenMonastery (Scarlet Monastery all wings)
    [131863] = true, -- LoadScreenRagefireChasm
    [131865] = true, -- LoadScreenRazorfen / RazorfenDowns (RFK / RFD)
    [131869] = true, -- LoadScreenScholomance
    [131870] = true, -- LoadScreenStockade / LoadScreenShadowFangKeep
    [131871] = true, -- LoadScreenStratholme living / undead
    [131872] = true, -- LoadScreenStratholme undead secondary
    [131873] = true, -- LoadScreenSunkenTemple
    [131877] = true, -- LoadScreenUldaman
    [131883] = true, -- LoadScreenWailingCaverns
    [131886] = true, -- LoadScreenZulFarrak
    [7963734] = true, -- Alcaz Prison (WoW Forever)
    [7963741] = true, -- The Drowned City (WoW Forever)
    [7963775] = true, -- City of Dalaran (WoW Forever)
    [7963777] = true, -- Excavation Site: Wetlands (WoW Forever)
    [7963780] = true, -- Krol'dok Stronghold (WoW Forever)
    [7963781] = true, -- Hall of Thanes (WoW Forever)
    [7963782] = true, -- Ruins of Lordaeron (WoW Forever)
    [7963783] = true, -- Shaper's Terrace (WoW Forever)
    [7963784] = true, -- Blackmaw Hold (WoW Forever)
}

--- Helper function to resolve the best valid loading screen texture for a dungeon.
--- Returns the resolved texture path or FileDataID.
local function ResolveDungeonArtTexture(dungeon)
    if not dungeon then return "Interface\\Glues\\LoadingScreens\\LoadScreenDungeon" end
    for _, candidate in ipairs(dungeon.art or {}) do
        if candidate and candidate ~= "" then
            local isExternal = (type(candidate) == "string" and candidate:find("ForeverDungeonJournal"))
            if not isExternal then
                if type(candidate) == "number" and (KNOWN_VALID_FILE_IDS[candidate] or candidate > 0) then
                    return candidate
                elseif type(candidate) == "string" then
                    return candidate
                end
            end
        end
    end
    return "Interface\\Glues\\LoadingScreens\\LoadScreenDungeon"
end

--- Sets the dungeon circular medallion portrait on the left page header.
--- Standardized to pull from the dungeon's loading screen image cropped in a circle,
--- matching the right-page artwork with clean fallback to dungeon.icon.
--- @param medallion Frame
--- @param dungeon table
function SharedWidgets:SetDungeonMedallionArt(medallion, dungeon)
    if not medallion or not medallion.icon or not dungeon then
        return
    end

    local tex = medallion.icon
    local art = ResolveDungeonArtTexture(dungeon)

    if art then
        tex:SetTexture(art)
        -- Standardized square center crop of the loading screen:
        -- Horizontal center: 0.32 to 0.68 (center 36% of width)
        -- Vertical center: 0.25 to 0.81 (crops out top header and bottom footer)
        -- Masked into a clean circle by medallion.mask (TempPortraitAlphaMask)!
        tex:SetTexCoord(0.32, 0.68, 0.25, 0.81)
        tex:Show()
    else
        self:SetMedallionIcon(medallion, dungeon.icon)
    end
end

--- Applies the best available dungeon artwork to `artTexture` and returns whether
--- a full loading-screen / card image was found.
--- Standardized zoom cuts off top header and bottom footer across all dungeons.
--- @param artTexture Texture
--- @param dungeon table
--- @return boolean hasFullArt
function SharedWidgets:ApplyDungeonArtwork(artTexture, dungeon)
    if not artTexture or not dungeon then
        return false
    end

    local tc = dungeon.texCoord or { 0.02, 0.98, 0.25, 0.81 }
    local art = ResolveDungeonArtTexture(dungeon)

    artTexture:SetTexture(art)
    artTexture:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    artTexture:Show()
    return true
end

--- Parses a level number or range string (e.g. 45, "45", "18-20") into (minLvl, maxLvl).
--- @param levelVal string|number
--- @return number|nil minLvl, number|nil maxLvl
function SharedWidgets:ParseLevelRange(levelVal)
    if type(levelVal) == "number" then
        return levelVal, levelVal
    end
    if type(levelVal) ~= "string" or levelVal == "" then
        return nil, nil
    end
    if levelVal == "??" or string.find(levelVal, "%?%?") then
        return nil, nil
    end
    local minStr, maxStr = string.match(levelVal, "(%d+)%s*-%s*(%d+)")
    if minStr and maxStr then
        return tonumber(minStr), tonumber(maxStr)
    end
    local singleStr = string.match(levelVal, "(%d+)")
    if singleStr then
        local n = tonumber(singleStr)
        return n, n
    end
    return nil, nil
end

--- Calculates the gray level threshold for a given player level according to standard WoW mechanics:
---   Level 1-5: 0 (no gray mobs)
---   Level 6-39: playerLevel - floor(playerLevel / 10) - 5
---   Level 40-59: playerLevel - floor(playerLevel / 5) - 1
---   Level 60+: playerLevel - 9
--- (e.g. at Level 30, gray threshold is 22; levels 23-27 are green, 28-32 are yellow, 33-34 orange, 35+ red).
local function GetGrayThreshold(playerLevel)
    if playerLevel <= 5 then
        return 0
    elseif playerLevel <= 39 then
        return playerLevel - math.floor(playerLevel / 10) - 5
    elseif playerLevel <= 59 then
        return playerLevel - math.floor(playerLevel / 5) - 1
    else
        return playerLevel - 9
    end
end

--- Returns dynamic RGB difficulty color based on mean level vs player level:
---   red: 5 or more levels above player
---   orange: 3 - 4 above player level
---   yellow: + or - 2 levels inclusive around player level
---   green: between yellow bracket down to gray threshold
---   grey: at or below gray threshold
--- @param minLvl number
--- @param maxLvl number|nil
--- @return number r, number g, number b
function SharedWidgets:GetDifficultyColorFromLevel(minLvl, maxLvl)
    if not minLvl then
        return 0.80, 0.72, 0.55
    end
    maxLvl = maxLvl or minLvl
    local targetLevel = (minLvl + maxLvl) * 0.5
    local roundedLevel = math.floor(targetLevel + 0.5)

    -- 1. Check native WoW GetQuestDifficultyColor API
    if _G.GetQuestDifficultyColor then
        local col = _G.GetQuestDifficultyColor(roundedLevel)
        if col and col.r and col.g and col.b then
            return col.r, col.g, col.b
        end
    end

    -- 2. Authentic WoW relative level difficulty formula
    local playerLevel = (UnitLevel and UnitLevel("player")) or 60
    if playerLevel <= 0 then playerLevel = 60 end

    local grayThreshold = GetGrayThreshold(playerLevel)
    local diff = targetLevel - playerLevel

    if diff >= 5 then
        return 1.00, 0.10, 0.10 -- Red (5 or more levels above player)
    elseif diff >= 3 then
        return 1.00, 0.50, 0.25 -- Orange (3 - 4 above player level)
    elseif diff >= -2 then
        return 1.00, 1.00, 0.00 -- Yellow (+ or - 2 levels inclusive around player level)
    elseif targetLevel > grayThreshold then
        return 0.25, 0.75, 0.25 -- Green (below yellow bracket down to gray threshold)
    else
        return 0.50, 0.50, 0.50 -- Grey (at or below gray threshold)
    end
end

--- Returns dynamic RGB difficulty color based on monster level vs player level:
---   red: 5 or more levels above player
---   orange: 3 - 4 above player level
---   yellow: + or - 2 levels inclusive around player level
---   green: between 2 - 4 below player level
---   grey: 5 or more levels below player level
---   ?? / skull: red
--- Evaluates ranges based on the mean of the range.
--- @param bossLevel string|number
--- @return number r, number g, number b
function SharedWidgets:GetCreatureDifficultyColor(bossLevel)
    if not bossLevel then
        return 0.80, 0.72, 0.55
    end
    if bossLevel == "??" or tostring(bossLevel) == "??" or string.find(tostring(bossLevel), "%?%?") then
        return 1.00, 0.10, 0.10 -- Red for ?? / skull level
    end
    local minLvl, maxLvl = self:ParseLevelRange(bossLevel)
    if not minLvl then
        return 1.00, 0.10, 0.10
    end
    return self:GetDifficultyColorFromLevel(minLvl, maxLvl)
end

--- Returns dynamic RGB difficulty color for a dungeon's level bracket vs player level,
--- evaluated strictly based on the mean of the dungeon's level range.
--- @param dungeon table
--- @return number r, number g, number b
function SharedWidgets:GetDungeonDifficultyColor(dungeon)
    if not dungeon then
        return 0.92, 0.86, 0.70
    end

    local minLvl = dungeon.minLevel
    local maxLvl = dungeon.maxLevel
    if not minLvl or not maxLvl then
        minLvl, maxLvl = self:ParseLevelRange(dungeon.level)
    end
    if not minLvl then
        return 0.92, 0.86, 0.70
    end

    return self:GetDifficultyColorFromLevel(minLvl, maxLvl)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.SharedWidgets = SharedWidgets

