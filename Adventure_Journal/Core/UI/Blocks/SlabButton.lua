-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/SlabButton.lua
-- The slab behind list buttons: drop shadow, dark rim, parchment fill and 1px
-- bevel edges, with a hover light and a selected state. Three variants: the
-- encounter list's warm parchment, the quest list's pale parchment, and the
-- questline banner (pale, no selection glow).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles
local PARCHMENT = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal"
local PALE_PARCHMENT = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal-Desaturated"
local RIM = { 0.12, 0.09, 0.06, 0.95 }
local RIM_SELECTED = { 0.85, 0.65, 0.20, 1.0 }

-- fill: art and tint; fillSelected: tint when selected; rimSelects: the rim turns gold when selected;
-- glow: selection glow color (none for banners); rightShadow: the right bevel edge
local VARIANTS = {
    encounter = {
        fill = PARCHMENT, fillColor = { 0.85, 0.75, 0.60, 0.90 }, fillSelected = { 1.0, 0.92, 0.72, 1.0 },
        rightShadow = { 0.05, 0.04, 0.02, 0.95 }, glow = { 0.85, 0.62, 0.18, 0.24 }, pushText = true,
    },
    quest = {
        fill = PALE_PARCHMENT, fillColor = { 1.0, 1.0, 1.0, 1.0 }, fillUnselected = { 0.88, 0.86, 0.82, 0.95 },
        fillSelected = { 1.0, 0.96, 0.85, 1.0 }, rimSelects = true,
        rightShadow = { 0.04, 0.03, 0.02, 0.95 }, glow = { 0.85, 0.62, 0.18, 0.28 },
    },
    banner = {
        fill = PALE_PARCHMENT, fillColor = { 0.88, 0.86, 0.82, 0.95 }, fillUnselected = { 0.88, 0.86, 0.82, 0.95 },
        fillSelected = { 1.0, 0.96, 0.85, 1.0 }, rimSelects = true,
        rightShadow = { 0.04, 0.03, 0.02, 0.95 },
    },
}

local function tint(tex, c)
    tex:SetVertexColor(c[1], c[2], c[3], c[4])
end

--- A flat-white texture on `btn` in `layer`:`sublevel`, inset by `inset` px (negative reaches outside).
local function flat(btn, layer, sublevel, inset, color)
    local tex = btn:CreateTexture(nil, layer, nil, sublevel)
    tex:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    tex:SetTexture(Styles.ASSETS.WHITE_8X8)
    if color then
        tint(tex, color)
    end
    return tex
end

--- A 1px bevel edge along one side, inset 1px.
local function edge(btn, side, color)
    local tex = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    tex:SetTexture(Styles.ASSETS.WHITE_8X8)
    tint(tex, color)
    if side == "top" or side == "bottom" then
        local y = side == "top" and -1 or 1
        local anchor = side == "top" and "TOP" or "BOTTOM"
        tex:SetHeight(1)
        tex:SetPoint(anchor .. "LEFT", btn, anchor .. "LEFT", 1, y)
        tex:SetPoint(anchor .. "RIGHT", btn, anchor .. "RIGHT", -1, y)
    else
        local x = side == "left" and 1 or -1
        local anchor = side == "left" and "LEFT" or "RIGHT"
        tex:SetWidth(1)
        tex:SetPoint("TOP" .. anchor, btn, "TOP" .. anchor, x, -1)
        tex:SetPoint("BOTTOM" .. anchor, btn, "BOTTOM" .. anchor, x, 1)
    end
    return tex
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local SlabButton = {}

--- Dresses `btn` as a slab of `variant` ("encounter", "quest" or "banner"). Sets `btn.slab`:
--- `{ variant, shadow, rim, fill, glow, hover, parts }`; `parts` lists every texture of the slab.
function SlabButton:Style(btn, variant)
    local v = VARIANTS[variant]
    local slab = { variant = variant }
    slab.shadow = flat(btn, "BACKGROUND", -5, -1, { 0.02, 0.02, 0.01, 0.60 })
    slab.rim = flat(btn, "BACKGROUND", -4, 0, RIM)
    slab.fill = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    slab.fill:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    slab.fill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    slab.fill:SetTexture(v.fill)
    tint(slab.fill, v.fillColor)
    slab.parts = { slab.shadow, slab.rim, slab.fill,
        edge(btn, "top", { 0.56, 0.44, 0.26, 0.70 }), edge(btn, "left", { 0.48, 0.38, 0.22, 0.60 }),
        edge(btn, "bottom", { 0.04, 0.03, 0.02, 0.95 }), edge(btn, "right", v.rightShadow) }
    if v.glow then
        slab.glow = flat(btn, "ARTWORK", 1, 1, v.glow)
        slab.glow:Hide()
    end
    slab.hover = flat(btn, "HIGHLIGHT", nil, 1, { 0.95, 0.80, 0.35, 0.18 })
    slab.hover:SetBlendMode("ADD")
    slab.parts[#slab.parts + 1] = slab.hover
    if v.pushText then
        btn:SetPushedTextOffset(1, -1)
    end
    btn.slab = slab
    return slab
end

--- Shows `btn` selected (or open, for banners) or not.
function SlabButton:SetSelected(btn, isSelected)
    local slab = btn.slab
    local v = VARIANTS[slab.variant]
    if slab.glow then
        slab.glow:SetShown(isSelected)
    end
    if v.rimSelects then
        tint(slab.rim, isSelected and RIM_SELECTED or RIM)
    end
    tint(slab.fill, isSelected and v.fillSelected or (v.fillUnselected or v.fillColor))
end

--- Shows or hides every texture of the slab (a banner swaps it for the Forever theme's header art).
function SlabButton:SetShown(btn, shown)
    for _, tex in ipairs(btn.slab.parts) do
        tex:SetShown(shown)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.SlabButton = SlabButton
