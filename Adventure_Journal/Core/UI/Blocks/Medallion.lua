-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/Medallion.lua
-- The circular medallion: an icon, portrait or piece of art masked to a
-- circle, inside a ring cut from the Journal window's own portrait corner, with
-- a hover glow and an optional classification dragon (elite or rare).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pcall = pcall
local CreateFrame = CreateFrame

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles
local GameApi = ns.GameApi
local QUADS = { "TL", "TR", "BL", "BR" }
local ELITE_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold"
local RARE_ATLAS = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver"

local function addCircleMask(medallion, texture)
    local mask = medallion:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture(Styles.ASSETS.PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    texture:AddMaskTexture(mask)
    return mask
end

--- Four quarter textures filling `ringFrame`, at `sublevel`; the ring art is set later by SyncRing.
local function createQuads(ringFrame, sublevel)
    local quads = {}
    local corners = { TL = { "TOPLEFT", "BOTTOMRIGHT" }, TR = { "TOPRIGHT", "BOTTOMLEFT" },
        BL = { "BOTTOMLEFT", "TOPRIGHT" }, BR = { "BOTTOMRIGHT", "TOPLEFT" } }
    for _, key in ipairs(QUADS) do
        local tex = ringFrame:CreateTexture(nil, "OVERLAY", nil, sublevel)
        tex:SetPoint(corners[key][1], ringFrame, corners[key][1], 0, 0)
        tex:SetPoint(corners[key][2], ringFrame, "CENTER", 0, 0)
        quads[key] = tex
    end
    return quads
end

--- Cuts the window portrait corner's circle into the four quarters (fX, fY: the portrait's center within the
--- corner art).
local function applyRing(quads, atlas, file, uL, uR, vT, vB, fX, fY)
    local uMid = uL + fX * (uR - uL)
    local vMid = vT + fY * (vB - vT)
    for _, key in ipairs(QUADS) do
        if atlas and atlas ~= "" then
            pcall(quads[key].SetAtlas, quads[key], atlas, false)
        elseif file then
            quads[key]:SetTexture(file)
        end
    end
    quads.TL:SetTexCoord(uL, vT, uL, vMid, uMid, vT, uMid, vMid)
    quads.TR:SetTexCoord(uMid, vT, uMid, vMid, uL, vT, uL, vMid)
    quads.BL:SetTexCoord(uL, vMid, uL, vT, uMid, vMid, uMid, vT)
    quads.BR:SetTexCoord(uMid, vMid, uMid, vT, uL, vMid, uL, vT)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local Medallion = {}

--- A medallion with an `iconSize` circle inside a `ringSize` ring.
--- @return Frame
function Medallion:Create(parent, iconSize, ringSize)
    local medallion = CreateFrame("Frame", nil, parent)
    medallion:SetSize(iconSize, iconSize)
    medallion.iconSize = iconSize

    local iconWell = medallion:CreateTexture(nil, "BORDER", nil, 1)
    iconWell:SetAllPoints(medallion)
    iconWell:SetTexture(Styles.ASSETS.WHITE_8X8)
    Styles:Tint(iconWell, "MEDALLION_WELL")

    local icon = medallion:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetAllPoints(medallion)
    medallion.icon = icon
    medallion.mask = addCircleMask(medallion, icon)
    addCircleMask(medallion, iconWell)

    local ringFrame = CreateFrame("Frame", nil, medallion)
    ringFrame:SetSize(ringSize, ringSize)
    ringFrame:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    ringFrame:SetFrameLevel(medallion:GetFrameLevel() + 3)
    medallion.ringQuads = createQuads(ringFrame, 5)

    local glow = medallion:CreateTexture(nil, "OVERLAY", nil, 4)
    glow:SetAllPoints(medallion)
    glow:SetTexture(Styles.ASSETS.WHITE_8X8)
    glow:SetBlendMode("ADD")
    Styles:Tint(glow, "MEDALLION_GLOW")
    glow:AddMaskTexture(medallion.mask)
    glow:Hide()
    medallion.glow = glow

    local ringGlow = createQuads(ringFrame, 6)
    for _, key in ipairs(QUADS) do
        ringGlow[key]:SetBlendMode("ADD")
        Styles:Tint(ringGlow[key], "MEDALLION_RING_GLOW")
        ringGlow[key]:Hide()
    end
    medallion.ringGlow = ringGlow

    local dragonFrame = CreateFrame("Frame", nil, medallion)
    dragonFrame:SetSize(iconSize * 1.8, iconSize * 1.5)
    dragonFrame:SetPoint("CENTER", medallion, "CENTER", 0, 0)
    dragonFrame:SetFrameLevel(ringFrame:GetFrameLevel() + 2)
    medallion.dragonFrame = dragonFrame
    local dragon = dragonFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    dragon:SetAllPoints(dragonFrame)
    dragon:Hide()
    medallion.dragon = dragon

    self:SyncRing(medallion)
    return medallion
end

--- Lights or unlights the medallion (hover).
function Medallion:SetHighlighted(medallion, isHighlighted)
    local show = isHighlighted and true or false
    medallion.glow:SetShown(show)
    for _, key in ipairs(QUADS) do
        medallion.ringGlow[key]:SetShown(show)
    end
end

--- Matches the ring to the Journal window's portrait corner (it differs by window theme).
function Medallion:SyncRing(medallion)
    local window = ns.UI.MainFrame and ns.UI.MainFrame.frame
    local corner = window and window.NineSlice and window.NineSlice.TopLeftCorner
    local portrait = window and window.PortraitContainer and window.PortraitContainer.portrait
    if not (corner and portrait) then
        return
    end
    local cornerLeft, cornerTop = corner:GetLeft(), corner:GetTop()
    local cornerW, cornerH = corner:GetWidth(), corner:GetHeight()
    local pL, pR, pT, pB = portrait:GetLeft(), portrait:GetRight(), portrait:GetTop(), portrait:GetBottom()
    if not (cornerLeft and cornerTop and cornerW > 0 and cornerH > 0 and pL and pR and pT and pB) then
        return
    end
    local fX = ((pL + pR) * 0.5 - cornerLeft) / cornerW
    local fY = (cornerTop - (pT + pB) * 0.5) / cornerH
    local ul, _, _, vb, ur, vt = corner:GetTexCoord()
    local atlas, file = corner:GetAtlas(), corner:GetTexture()
    applyRing(medallion.ringQuads, atlas, file, ul, ur, vt, vb, fX, fY)
    applyRing(medallion.ringGlow, atlas, file, ul, ur, vt, vb, fX, fY)
end

--- Shows an icon in the circle (the missing-icon question mark when none is given).
function Medallion:SetIcon(medallion, iconPath)
    medallion.icon:SetTexCoord(0, 1, 0, 1)
    medallion.icon:SetTexture(iconPath or Styles.ASSETS.MISSING_ICON)
end

--- Shows an encounter: its creature portrait, else `icon` (the template's encounter.icon slot), else the
--- missing-icon question mark.
--- @param boss table an encounter view
--- @param icon any|nil
function Medallion:SetEncounterPortrait(medallion, boss, icon)
    local tex = medallion.icon
    tex:SetTexCoord(0, 1, 0, 1)
    if boss and GameApi:SetCreaturePortrait(tex, boss.displayID) then
        tex:SetTexCoord(0, 1, 0, 1)
        return
    end
    tex:SetTexture(icon or Styles.ASSETS.MISSING_ICON)
end

--- Shows an instance's loading-screen art cropped to a square, or its icon when it has no art.
function Medallion:SetInstanceArt(medallion, instance)
    if not instance then
        return
    end
    local art = ns.UI.Blocks.InstanceArt:Resolve(instance)
    if art then
        medallion.icon:SetTexture(art)
        medallion.icon:SetTexCoord(0.32, 0.68, 0.25, 0.81)
        medallion.icon:Show()
    else
        self:SetIcon(medallion, instance.icon)
    end
end

--- Shows the classification dragon: gold for bosses, silver for rares, none for minor encounters and Zone Drops.
--- @param boss table|nil an encounter view; nil hides the dragon
function Medallion:SetClassification(medallion, boss)
    local tex = medallion.dragon
    if not boss or boss.isMinor or boss.isZone then
        tex:Hide()
        return
    end
    local isRare = boss.rare and not boss.isChallenge
    local atlas = isRare and RARE_ATLAS or ELITE_ATLAS
    local scale = medallion.iconSize / 60
    local frame = medallion.dragonFrame
    -- Kept as found until the Phase 4c art pass: the rare atlas is missing on Forever, so rares take the
    -- SetAtlas path below.
    local info, file = GameApi:GetAtlasInfo(atlas)
    if info then
        tex:SetTexture(file)
        -- Mirrored so the dragon curls along the portrait's left and top
        tex:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
        frame:SetSize((info.width or 82) * scale, (info.height or 72) * scale)
    elseif pcall(tex.SetAtlas, tex, atlas, false) then
        pcall(tex.SetTexCoord, tex, 1, 0, 0, 1)
        frame:SetSize(82 * scale, 72 * scale)
    else
        return
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", medallion, "CENTER", -2 * scale, 1 * scale)
    tex:Show()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.Medallion = Medallion
