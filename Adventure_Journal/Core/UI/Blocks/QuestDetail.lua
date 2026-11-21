-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/QuestDetail.lua
-- A quest's page: a header (title, meta line, faction crest, divider) over a
-- scrolling body, drawn from QuestPage.lua's models. A questline shows each step
-- as a banner that opens to its sections (the first unfinished step starts
-- open; Questline.lua); a single quest shows its sections directly. Also the
-- writer the sections draw through: pooled texts, dividers, rewards, banners
-- and pins.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local max = math.max
local setmetatable = setmetatable
local CreateFrame = CreateFrame

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks
local Styles = ns.UI.Styles
local CREST = { Horde = "Interface\\Timer\\Horde-Logo", Alliance = "Interface\\Timer\\Alliance-Logo" }
local DEFAULT_WIDTH = 340

local function acquire(pools, kind, index, create)
    local widget = pools[kind][index]
    if not widget then
        widget = create()
        pools[kind][index] = widget
    end
    widget:ClearAllPoints()
    widget:Show()
    return widget
end

local function shadowed(fs)
    fs:SetShadowColor(0, 0, 0, 1.0)
    fs:SetShadowOffset(1, -1)
    return fs
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestDetail = {}
QuestDetail.__index = QuestDetail

--- A quest page filling `container` (the right page). Its header lines up with the left page's header through
--- the shared header sizes (Styles.SIZES).
function QuestDetail:Create(container, contentWidth)
    local detail = setmetatable({ container = container, counts = {},
        pools = { text = {}, reward = {}, banner = {}, pin = {}, logButton = {}, divider = {} } }, QuestDetail)
    local sizes = Styles.SIZES
    local drop = sizes.RIGHT_PAGE_DROP
    detail.titleY = sizes.HEADER_MEDALLION_Y - sizes.HEADER_TITLE_DROP + drop
    local centerY = sizes.HEADER_MEDALLION_Y - sizes.HEADER_MEDALLION / 2 + drop

    local divider = Blocks.Divider:CreateHorizontal(container, 4)
    divider:SetPoint("TOPLEFT", container, "TOPLEFT", 6, sizes.HEADER_DIVIDER_Y + drop)
    divider:SetPoint("TOPRIGHT", container, "TOPRIGHT", -12, sizes.HEADER_DIVIDER_Y + drop)

    local crest = container:CreateTexture(nil, "OVERLAY", nil, 6)
    crest:SetSize(38, 38)
    crest:SetPoint("RIGHT", container, "TOPRIGHT", -12, centerY)
    crest:Hide()
    detail.crest = crest

    local title = shadowed(container:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"))
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    title:SetSpacing(2)
    title:SetTextColor(1.0, 0.82, 0.0)
    detail.title = title

    local meta = shadowed(container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
    meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    meta:SetJustifyH("LEFT")
    meta:SetWordWrap(false)
    meta:SetTextColor(0.82, 0.72, 0.52)
    detail.meta = meta
    detail:AnchorHeader()

    local scroll = ns.UI.ScrollFrame:Create(container)
    scroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 10)
    detail.scroll = scroll
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(contentWidth or DEFAULT_WIDTH)
    child:SetHeight(100)
    scroll:SetScrollChild(child)
    detail.child = child
    return detail
end

--- Title and meta run to the crest when it shows, else to the page's edge.
function QuestDetail:AnchorHeader()
    local right = self.crest:IsShown() and self.crest or self.container
    local point, x = self.crest:IsShown() and "LEFT" or "RIGHT", self.crest:IsShown() and -6 or -12
    self.title:ClearAllPoints()
    self.title:SetPoint("TOPLEFT", self.container, "TOPLEFT", 6, self.titleY)
    self.title:SetPoint("RIGHT", right, point, x, 0)
    self.meta:SetPoint("RIGHT", right, point, x, 0)
end

--- Fills the header from `header` (`{ title, meta, faction }`; the faction picks the crest).
function QuestDetail:SetHeader(header)
    self.title:SetText(header.title)
    local crest = CREST[header.faction]
    if crest then
        self.crest:SetTexture(crest)
        self.crest:SetTexCoord(0, 1, 0, 1)
        self.crest:SetSize(38, 38)
        self.crest:Show()
    else
        self.crest:Hide()
    end
    self:AnchorHeader()
    self.meta:SetText(header.meta)
end

--- Empties the page.
function QuestDetail:Clear()
    self.title:SetText("")
    self.meta:SetText("")
    self.crest:Hide()
    self:Begin()
end

-- Writer -------------------------------------------------------------------------

function QuestDetail:Begin()
    for kind, pool in pairs(self.pools) do
        self.counts[kind] = 0
        for _, widget in ipairs(pool) do
            widget:Hide()
        end
    end
end

function QuestDetail:Next(kind)
    self.counts[kind] = self.counts[kind] + 1
    return self.counts[kind]
end

--- A pooled font string in `font`, colored r, g, b (body text follows the window theme's ink), `width` wide
--- (default: the body's text width), wrapping unless `wrap` is false.
function QuestDetail:Text(font, r, g, b, wrap, width)
    local fs = self.pools.text[self:Next("text")]
    if not fs then
        fs = self.child:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
        self.pools.text[self.counts.text] = fs
    else
        fs:SetFontObject(font or "GameFontNormal")
    end
    fs:ClearAllPoints()
    fs:SetWidth(width or self.textWidth)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(wrap ~= false)
    if font == "GameFontHighlightSmall" then
        ns.UI.WindowBackground:ColorBodyText(fs, r or 1.0, g or 1.0, b or 1.0)
    else
        fs:SetTextColor(r or 1.0, g or 1.0, b or 1.0)
        fs:SetShadowOffset(1, -1)
    end
    fs:Show()
    return fs
end

function QuestDetail:Reward()
    return acquire(self.pools, "reward", self:Next("reward"), function()
        return Blocks.RewardGrid:CreateButton(self.child)
    end)
end

function QuestDetail:Banner()
    return acquire(self.pools, "banner", self:Next("banner"), function()
        return Blocks.QuestlineBanner:Create(self.child)
    end)
end

function QuestDetail:Pin()
    return acquire(self.pools, "pin", self:Next("pin"), function()
        return Blocks.MapPinButton:Create(self.child)
    end)
end

function QuestDetail:LogButton()
    return acquire(self.pools, "logButton", self:Next("logButton"), function()
        return Blocks.QuestLogButton:Create(self.child)
    end)
end

function QuestDetail:Divider()
    local bar = acquire(self.pools, "divider", self:Next("divider"), function()
        return Blocks.Divider:CreateHorizontal(self.child, 4)
    end)
    bar:SetHeight(4)
    return bar
end

-- Body ---------------------------------------------------------------------------

--- Draws `page` (QuestPage.lua's model): a questline's steps, or a single quest's sections.
function QuestDetail:Render(page)
    self.page = page
    local width = self.scroll:GetWidth() or DEFAULT_WIDTH
    if width <= 20 then
        width = DEFAULT_WIDTH
    end
    self.contentWidth, self.textWidth = width, width - 8
    self.child:SetWidth(width)
    self:Begin()

    local y
    if page.steps then
        y = self:RenderQuestline(page)
    else
        y = self:RenderSingle(page)
    end
    local height = max(1, -y + 20)
    self.child:SetHeight(height)
    ns.UI.ScrollFrame:UpdateBar(self.scroll, height)
end

--- A single quest's sections, full width.
function QuestDetail:RenderSingle(page)
    local Sections = Blocks.QuestSections
    local pinX, textX = 14, 58
    local y = -4
    for _, section in ipairs(page.sections) do
        if section.kind == "objectives" then
            y = Sections:Objectives(self, section, 4, y)
        elseif section.kind == "giver" then
            y = Sections:GiverRow(self, section, page.pinText, pinX, textX, y, self.textWidth - textX,
                section.role == "source" and 12 or 16)
        elseif section.kind == "requirements" then
            y = Sections:Requirements(self, section, 4, y)
        elseif section.kind == "rewards" then
            y = Sections:Rewards(self, section, 4, y, 4, nil, self.contentWidth - 8)
        end
    end
    return y
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.QuestDetail = QuestDetail
