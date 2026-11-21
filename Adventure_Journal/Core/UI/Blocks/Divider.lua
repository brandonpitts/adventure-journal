-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/Divider.lua
-- The signature divider: a 1px bronze highlight
-- line beside a 1px shadow line, each fading out over its last 28px at both
-- ends. Horizontal dividers set their own height; vertical ones their width.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local CreateFrame = CreateFrame
local CreateColor = CreateColor

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles

--- One line of the divider: two fading end pieces and a solid middle, `offset` px in from the bar's edge.
local function createLine(bar, horizontal, sublevel, offset, colorName)
    local fade = Styles.SIZES.DIVIDER_FADE
    local white = Styles.ASSETS.WHITE_8X8
    local r, g, b, a = Styles:Color(colorName)
    local first = bar:CreateTexture(nil, "ARTWORK", nil, sublevel)
    local last = bar:CreateTexture(nil, "ARTWORK", nil, sublevel)
    local middle = bar:CreateTexture(nil, "ARTWORK", nil, sublevel)
    for _, tex in ipairs({ first, last, middle }) do
        tex:SetTexture(white)
    end
    if horizontal then
        first:SetSize(fade, 1)
        first:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -offset)
        last:SetSize(fade, 1)
        last:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -offset)
        middle:SetHeight(1)
        middle:SetPoint("LEFT", first, "RIGHT", 0, 0)
        middle:SetPoint("RIGHT", last, "LEFT", 0, 0)
        first:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a))
        last:SetGradient("HORIZONTAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0))
    else
        first:SetSize(1, fade)
        first:SetPoint("TOPLEFT", bar, "TOPLEFT", offset, 0)
        last:SetSize(1, fade)
        last:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", offset, 0)
        middle:SetWidth(1)
        middle:SetPoint("TOPLEFT", first, "BOTTOMLEFT", 0, 0)
        middle:SetPoint("BOTTOMLEFT", last, "TOPLEFT", 0, 0)
        -- Vertical gradients run bottom (first color) to top
        first:SetGradient("VERTICAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0))
        last:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a))
    end
    middle:SetVertexColor(r, g, b, a)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local Divider = {}

--- A horizontal divider on `parent`; anchor its left and right edges.
--- @param thickness number|nil frame height (default 4)
--- @return Frame
function Divider:CreateHorizontal(parent, thickness)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(thickness or Styles.SIZES.DIVIDER_THICKNESS)
    createLine(bar, true, 3, 1, "DIVIDER_HIGHLIGHT")
    createLine(bar, true, 2, 2, "DIVIDER_SHADOW")
    return bar
end

--- A vertical divider on `parent`; anchor its top and bottom edges.
--- @param thickness number|nil frame width (default 4)
--- @return Frame
function Divider:CreateVertical(parent, thickness)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(thickness or Styles.SIZES.DIVIDER_THICKNESS)
    createLine(bar, false, 3, 1, "DIVIDER_HIGHLIGHT")
    createLine(bar, false, 2, 2, "DIVIDER_SHADOW")
    return bar
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.Divider = Divider
