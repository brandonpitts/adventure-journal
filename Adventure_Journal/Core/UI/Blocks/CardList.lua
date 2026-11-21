-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/CardList.lua
-- A scrolling list of picture cards (StoneCard), one per entry, in one of
-- several layouts (columns and card size). A card shows its entry's art, name
-- and a line under it; hovering shows a tooltip the caller fills. Cards can be
-- grouped in sections, each under a header: its title centered between the
-- two halves of the Settings panel's line (Styles.LIST_HEADER).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local floor = math.floor
local ceil = math.ceil
local max = math.max
local abs = math.abs
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local C_Texture = C_Texture

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Blocks = ns.UI.Blocks
local Styles = ns.UI.Styles
local HEADER_HEIGHT = 26 -- a section header: its title with the line on either side
local SECTION_GAP = 10   -- extra space above every header but the first

--- The Settings panel's line across `bar`, fading out evenly at both ends: the atlas fades at its left end only,
--- so the line is that faded half, then the same half mirrored.
local function fadingLine(bar)
    local info = C_Texture.GetAtlasInfo(Styles.ASSETS.SECTION_LINE_ATLAS)
    if not info then
        return
    end
    local file = info.file or info.filename
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local mid = (l + r) / 2
    for i = 1, 2 do
        local piece = bar:CreateTexture(nil, "ARTWORK")
        piece:SetTexture(file)
        piece:SetHeight(info.height or 1)
        if i == 1 then
            piece:SetTexCoord(l, mid, t, b)
            piece:SetPoint("LEFT", bar, "LEFT", 0, 0)
            piece:SetPoint("RIGHT", bar, "CENTER", 0, 0)
        else
            piece:SetTexCoord(mid, l, t, b)
            piece:SetPoint("LEFT", bar, "CENTER", 0, 0)
            piece:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local CardList = {}
CardList.__index = CardList

--- A card list filling `parent`. `options`:
--- - `geometry`: `{ GAP_X, GAP_Y, START_X, START_Y, SCROLL_TOP_Y, SCROLL_BOTTOM_Y, SCROLL_LEFT_X, SCROLL_RIGHT_X }`
--- - `layouts`: layout key -> `{ columns, width, height, centered, noFade }`
--- - `onSelect(entry)`, `onTooltip(entry)` (GameTooltip owned and shown by the list)
function CardList:Create(parent, options)
    local list = setmetatable({ options = options, pools = {} }, CardList)
    local g = options.geometry
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    list.frame = frame

    local scroll = ns.UI.ScrollFrame:Create(frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", g.SCROLL_LEFT_X, g.SCROLL_TOP_Y)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", g.SCROLL_RIGHT_X, g.SCROLL_BOTTOM_Y)
    list.scroll = scroll
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(742, 400)
    scroll:SetScrollChild(child)
    list.child = child
    return list
end

--- A card of `layoutKey`'s size (pooled per layout).
function CardList:Card(index, layoutKey)
    local pool = self.pools[layoutKey] or {}
    self.pools[layoutKey] = pool
    local card = pool[index]
    if card then
        card:Show()
        return card
    end
    local layout = self.options.layouts[layoutKey]
    -- Centered: the name and the line in the middle; otherwise the name in gold on the left, the line under it
    card = Blocks.StoneCard:Create(self.child, layout.width, layout.height,
        { picture = true, noFade = layout.noFade, centered = layout.centered })
    if not layout.centered then
        card.subText:SetPoint("RIGHT", card, "RIGHT", -16, 0)
        card.subText:SetWordWrap(false)
    end
    card:SetScript("OnClick", function(c)
        PlaySound(Styles.SOUNDS.CLICK)
        if c.entry then
            self.options.onSelect(c.entry)
        end
    end)
    -- Hooked, not set: the card's own hover and press visuals are hooks too
    card:HookScript("OnEnter", function(c)
        if c.entry then
            GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
            self.options.onTooltip(c.entry)
            GameTooltip:Show()
        end
    end)
    card:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    pool[index] = card
    return card
end

--- A section header (pooled): its title over the Settings panel's line.
function CardList:Header(index)
    self.headers = self.headers or {}
    local header = self.headers[index]
    if header then
        header:Show()
        return header
    end
    header = CreateFrame("Frame", nil, self.child)
    header:SetHeight(HEADER_HEIGHT)
    -- The title centered on one line, the line split in half on either side of it
    local style = Styles.LIST_HEADER
    local title = header:CreateFontString(nil, "OVERLAY", style.font)
    local path, size = title:GetFont()
    title:SetFont(path, style.size or size, style.flags)
    title:SetPoint("CENTER", header, "CENTER", 0, 0)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    header.title = title
    for _, side in ipairs({ "left", "right" }) do
        local bar = CreateFrame("Frame", nil, header)
        bar:SetHeight(HEADER_HEIGHT)
        if side == "left" then
            bar:SetPoint("LEFT", header, "LEFT", 0, 0)
            bar:SetPoint("RIGHT", title, "LEFT", -style.gap, 0)
        else
            bar:SetPoint("LEFT", title, "RIGHT", style.gap, 0)
            bar:SetPoint("RIGHT", header, "RIGHT", 0, 0)
        end
        fadingLine(bar)
    end
    self.headers[index] = header
    return header
end

--- Draws `sections` (`{ { title, entries } }`, `title` nil for none) in `layoutKey`, each under its header, the
--- cards of each starting a new row. `lineFor(entry, layout)` gives each card's second line; `showMissingArt`
--- false leaves a card without art plain black (no question mark); `cropFor(entry)` gives a card's crop center
--- (StoneCard:CropPicture), nil for the standard crop.
function CardList:Render(sections, layoutKey, lineFor, showMissingArt, cropFor)
    local g = self.options.geometry
    local layout = self.options.layouts[layoutKey]
    for _, pool in pairs(self.pools) do
        for _, card in ipairs(pool) do
            card:Hide()
        end
    end
    for _, header in ipairs(self.headers or {}) do
        header:Hide()
    end
    local cols, index, headers, y = layout.columns, 0, 0, g.START_Y
    local width = cols * layout.width + (cols - 1) * g.GAP_X
    for s, section in ipairs(sections) do
        if section.title and #section.entries > 0 then
            headers = headers + 1
            local header = self:Header(headers)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", self.child, "TOPLEFT", g.START_X, y - (s > 1 and SECTION_GAP or 0))
            header:SetWidth(width)
            header.title:SetText(section.title)
            y = y - HEADER_HEIGHT - (s > 1 and SECTION_GAP or 0) - g.GAP_Y
        end
        for i, entry in ipairs(section.entries) do
            index = index + 1
            local card = self:Card(index, layoutKey)
            card.entry = entry
            local col = (i - 1) % cols
            local row = floor((i - 1) / cols)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", self.child, "TOPLEFT", g.START_X + col * (layout.width + g.GAP_X),
                y - row * (layout.height + g.GAP_Y))
            local name = entry.name or ""
            card.nameText:SetText(card.upperName and name:upper() or name)
            card.subText:SetText(lineFor(entry, layout))
            Blocks.StoneCard:SetInstancePicture(card, entry, showMissingArt ~= false, cropFor and cropFor(entry))
        end
        y = y - ceil(#section.entries / cols) * (layout.height + g.GAP_Y)
    end
    local height = max(abs(g.START_Y) + layout.height + g.GAP_Y, abs(y)) + 12
    self.child:SetHeight(max(1, height))
    ns.UI.ScrollFrame:UpdateBar(self.scroll, height)
end

function CardList:Show()
    self.frame:Show()
end

function CardList:Hide()
    self.frame:Hide()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.CardList = CardList
