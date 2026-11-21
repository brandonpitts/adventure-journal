-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/QuestlineBanner.lua
-- One step's banner in a questline: status marker, title ("Step N: name"), the
-- step's level, and an open / closed sign. The Forever window theme draws it
-- as the Reputation tab's collapsible header with its plus / minus icon; the
-- other themes as a pale slab, lit gold while open.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local CreateFrame = CreateFrame

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles
local Blocks = ns.UI.Blocks
-- The Reputation and Skills tabs' collapsible header bar (Forever theme)
local REPUTATION_HEADER = "common-button-list-collapseExpand"
-- Width kept at its own size at each end of a stretched header; only the part between them stretches
local STRIP_CAP = 12
-- Title colors by step status
local TITLE_COLORS = {
    done = { 0.40, 0.90, 0.45 },
    active = { 0.88, 0.88, 0.88 },
    available = { 1.0, 0.82, 0.0 },
}

--- Draws `atlas` across `parent` in `layer` as three pieces: its two ends at their own width and the middle
--- stretched between them. Returns the pieces (one missing-art texture when the client lacks the atlas).
local function createAtlasStrip(parent, layer, atlas)
    local info, file = ns.GameApi:GetAtlasInfo(atlas)
    if not (info and info.width > 2 * STRIP_CAP) then
        local tex = parent:CreateTexture(nil, layer)
        tex:SetAllPoints()
        tex:SetTexture(Styles.ASSETS.MISSING_ICON)
        return { tex }
    end
    local u = (info.rightTexCoord - info.leftTexCoord) / info.width
    local function piece(x0, x1)
        local tex = parent:CreateTexture(nil, layer)
        tex:SetTexture(file)
        tex:SetTexCoord(info.leftTexCoord + x0 * u, info.leftTexCoord + x1 * u, info.topTexCoord, info.bottomTexCoord)
        return tex
    end
    local left = piece(0, STRIP_CAP)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(STRIP_CAP)
    local right = piece(info.width - STRIP_CAP, info.width)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(STRIP_CAP)
    local middle = piece(STRIP_CAP, info.width - STRIP_CAP)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    return { left, middle, right }
end

local function shadowed(fs)
    fs:SetShadowColor(0, 0, 0, 1.0)
    fs:SetShadowOffset(1, -1)
    return fs
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestlineBanner = {}

--- A questline step banner on `parent`, 30px tall; anchor its left and right edges.
--- @return Button
function QuestlineBanner:Create(parent)
    local banner = CreateFrame("Button", nil, parent)
    banner:SetHeight(30)
    Blocks.SlabButton:Style(banner, "banner")

    local statusIcon = banner:CreateTexture(nil, "ARTWORK")
    statusIcon:SetSize(18, 18)
    statusIcon:SetPoint("LEFT", banner, "LEFT", 8, 0)
    banner.statusIcon = statusIcon

    local arrowText = shadowed(banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    arrowText:SetPoint("RIGHT", banner, "RIGHT", -10, 0)
    arrowText:SetTextColor(0.85, 0.75, 0.50)
    banner.arrowText = arrowText

    local levelText = shadowed(banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    levelText:SetPoint("RIGHT", arrowText, "LEFT", -10, 0)
    banner.levelText = levelText

    local titleText = shadowed(banner:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    titleText:SetPoint("LEFT", statusIcon, "RIGHT", 8, 0)
    titleText:SetPoint("RIGHT", levelText, "LEFT", -8, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    banner.titleText = titleText

    banner.foreverParts = {}
    for _, part in ipairs(createAtlasStrip(banner, "BACKGROUND", REPUTATION_HEADER)) do
        banner.foreverParts[#banner.foreverParts + 1] = part
    end
    for _, part in ipairs(createAtlasStrip(banner, "HIGHLIGHT", REPUTATION_HEADER)) do
        part:SetBlendMode("ADD")
        part:SetAlpha(0.3)
        banner.foreverParts[#banner.foreverParts + 1] = part
    end
    local stateIcon = banner:CreateTexture(nil, "BORDER")
    stateIcon:SetPoint("RIGHT", banner, "RIGHT", -8, -1)
    banner.stateIcon = stateIcon
    banner.foreverParts[#banner.foreverParts + 1] = stateIcon
    return banner
end

--- Fills the banner for one questline step and styles it open or closed for the window theme.
--- @param step table `{ title, level, levelText }` (QuestPage.lua's step model)
--- @param status string "done", "active" or "available" (QuestMarker)
function QuestlineBanner:Set(banner, step, status, isOpen)
    self:SetOpen(banner, isOpen)
    local r, g, b = ns.LevelColors:ForText(step.level)
    banner.levelText:SetText(Blocks.LevelTag:Colorize(step.levelText, r, g, b))
    banner.titleText:SetText(step.title)
    Blocks.QuestMarker:Apply(banner.statusIcon, status, "banner")
    local c = TITLE_COLORS[status]
    banner.titleText:SetTextColor(c[1], c[2], c[3])
end

--- Styles the banner open or closed for the window theme.
function QuestlineBanner:SetOpen(banner, isOpen)
    local forever = ns.UI.WindowBackground:IsForever()
    Blocks.SlabButton:SetShown(banner, not forever)
    for _, part in ipairs(banner.foreverParts) do
        part:SetShown(forever)
    end
    banner.arrowText:SetShown(not forever)
    banner.levelText:ClearAllPoints()
    if forever then
        banner.stateIcon:SetAtlas(isOpen and "common-button-list-minus" or "common-button-list-plus", true)
        banner.levelText:SetPoint("RIGHT", banner.stateIcon, "LEFT", -10, 1)
        return
    end
    banner.arrowText:SetText(isOpen and "[-]" or "[+]")
    banner.levelText:SetPoint("RIGHT", banner.arrowText, "LEFT", -10, 0)
    Blocks.SlabButton:SetSelected(banner, isOpen)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.QuestlineBanner = QuestlineBanner
