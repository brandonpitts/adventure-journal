-- ============================================================================
-- Adventure Journal - Core/UI/BreadcrumbStepArt.lua
-- Draws the breadcrumb's step buttons with the Home button's smooth art
-- instead of the game's tiled strip: grey for a middle step, red-tinted grey
-- for the current one. Used by Core/UI/BreadcrumbBar.lua.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pi = math.pi

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Step buttons are drawn with the Home button's smooth art (NavigationBar.xml, `NavMenu-HomeButton-*` in
-- CS_HelpTextures) instead of the tiled strip: a stretched body slice plus the fixed pointed tip.
local STEP_ART = {
    file = "Interface\\HelpFrame\\CS_HelpTextures",
    width = 512,                   -- the texture's width in pixels
    right = 0.70312500,            -- right edge of the Home cut (its tip)
    bodySlicePx = 64,              -- body pixels stretched to fill the button, taken just left of the tip
    tipPx = 22,                    -- the tip's width, drawn unstretched
    overlapPx = 15,                -- how far the next step tucks under the tip (the Home button's own xoffset)
    rows = {                       -- top/bottom of each state's cut
        normal = { 0.00781250, 0.24218750 },
        pushed = { 0.25781250, 0.49218750 },
        highlight = { 0.50781250, 0.74218750 },
    },
}
-- Middle steps are grey; the current step a red-tinted grey (part-desaturated); the overflow button the Home
-- button's own red. `lift` (0-1) is the alpha of the added copy of the art: 0 leaves it as is, 1 roughly doubles
-- its brightness.
local STEP_TONE = {
    middle = { desaturation = 1.0, brightness = 1.0, lift = 0.3 },
    current = { desaturation = 0.55, brightness = 0.80, lift = 0 },
    overflow = { desaturation = 0, brightness = 1.0, lift = 0 },
}

-- The overflow button: as wide as the game's own, holding the step dropdowns' arrow (NavigationBar.xml,
-- `MenuArrowButton.Art`: an up arrow in SquareButtonTextures) turned to point left
local OVERFLOW_WIDTH = 44
local ARROW = {
    file = "Interface\\Buttons\\SquareButtonTextures",
    left = 0.45312500, right = 0.64062500, top = 0.01562500, bottom = 0.20312500,
    size = 12,
}

--- Texture coordinates of a state's body slice or tip.
local function artCoords(state, part)
    local a = STEP_ART
    local tipLeft = a.right - a.tipPx / a.width
    local top, bottom = a.rows[state][1], a.rows[state][2]
    if part == "tip" then
        return tipLeft, a.right, top, bottom
    end
    return tipLeft - a.bodySlicePx / a.width, tipLeft, top, bottom
end

--- Points `tex` at a state's body or tip of the step art.
local function setArt(tex, state, part)
    tex:SetTexture(STEP_ART.file)
    tex:SetHorizTile(false)
    tex:SetTexCoord(artCoords(state, part))
end

--- Places `tex` over the button's body (everything left of the tip) or its tip.
local function anchorPart(tex, button, part)
    tex:ClearAllPoints()
    if part == "tip" then
        tex:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        tex:SetWidth(STEP_ART.tipPx)
    else
        tex:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -STEP_ART.tipPx, 0)
    end
end

--- Swaps a step button's tiled strip and separate arrow for the Home art. Runs once per button.
--- @param button table a NavButtonTemplate button
local function restyle(button)
    if button.journalTip then
        return
    end
    local normal, pushed, highlight = button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()
    setArt(normal, "normal", "body")
    setArt(pushed, "pushed", "body")
    setArt(highlight, "highlight", "body")
    for _, tex in ipairs({ normal, pushed, highlight }) do
        anchorPart(tex, button, "body")
    end
    normal:SetDrawLayer("BACKGROUND")
    pushed:SetDrawLayer("BACKGROUND")

    local tip = button:CreateTexture(nil, "BACKGROUND")
    setArt(tip, "normal", "tip")
    anchorPart(tip, button, "tip")

    -- A second copy of the art added on top lightens it while keeping its shading
    local liftBody = button:CreateTexture(nil, "BORDER")
    setArt(liftBody, "normal", "body")
    anchorPart(liftBody, button, "body")
    local liftTip = button:CreateTexture(nil, "BORDER")
    setArt(liftTip, "normal", "tip")
    anchorPart(liftTip, button, "tip")
    for _, tex in ipairs({ liftBody, liftTip }) do
        tex:SetBlendMode("ADD")
    end
    button.journalLift = { liftBody, liftTip }
    local tipHighlight = button:CreateTexture(nil, "HIGHLIGHT")
    setArt(tipHighlight, "highlight", "tip")
    tipHighlight:SetBlendMode("ADD")
    anchorPart(tipHighlight, button, "tip")
    button.journalTip, button.journalTipHighlight = tip, tipHighlight

    button:HookScript("OnMouseDown", function(b)
        if b:IsEnabled() then
            setArt(tip, "pushed", "tip")
        end
    end)
    button:HookScript("OnMouseUp", function()
        setArt(tip, "normal", "tip")
    end)

    highlight:SetAlpha(1)
    button.xoffset = -STEP_ART.overlapPx

    -- A step's tip is part of the art now; the template's own arrow and selection box stay hidden
    if button.MenuArrowButton then
        button.arrowUp:SetAlpha(0)
        button.arrowDown:SetAlpha(0)
        button.selected:SetAlpha(0)
        button.MenuArrowButton:ClearAllPoints()
        button.MenuArrowButton:SetPoint("RIGHT", button, "TOPRIGHT", -2 - STEP_ART.tipPx, -15)
    end
end

--- Tints a restyled button with one of `STEP_TONE`'s looks. The hover glow keeps the Home button's gold.
local function tone(button, look)
    local textures = { button:GetNormalTexture(), button:GetPushedTexture(), button.journalTip }
    for _, tex in ipairs(textures) do
        tex:SetDesaturation(look.desaturation)
        tex:SetVertexColor(look.brightness, look.brightness, look.brightness)
    end
    for _, tex in ipairs(button.journalLift) do
        tex:SetDesaturation(look.desaturation)
        tex:SetAlpha(look.lift)
    end
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local BreadcrumbStepArt = {
    -- Extra width a step needs for its tip, on top of what the game gives its name
    TIP_WIDTH = STEP_ART.tipPx,
}

--- Restyles a step button (once) and tints it for its place in the trail.
--- @param button table a NavButtonTemplate button
--- @param isCurrent boolean
function BreadcrumbStepArt:Apply(button, isCurrent)
    restyle(button)
    tone(button, isCurrent and STEP_TONE.current or STEP_TONE.middle)
end

--- Restyles the NavBar's overflow button (it lists the steps that don't fit, Home first) as a short step in the
--- Home button's red, holding a gold left arrow: the step dropdowns' arrow turned to point left.
--- @param button table the NavBar's `overflow` DropdownButton
function BreadcrumbStepArt:ApplyOverflow(button)
    restyle(button)
    tone(button, STEP_TONE.overflow)
    button:SetWidth(OVERFLOW_WIDTH)
    local arrow = button:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(ARROW.file)
    arrow:SetTexCoord(ARROW.left, ARROW.right, ARROW.top, ARROW.bottom)
    arrow:SetRotation(pi / 2)
    arrow:SetSize(ARROW.size, ARROW.size)
    -- Centered on the body, left of the tip
    arrow:SetPoint("CENTER", button, "LEFT", (OVERFLOW_WIDTH - STEP_ART.tipPx) / 2, -1)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.BreadcrumbStepArt = BreadcrumbStepArt
