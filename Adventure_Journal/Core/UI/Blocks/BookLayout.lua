-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/BookLayout.lua
-- The open book: a left page with a scrolling list area under its header, a
-- right page, and the spine divider between them. The left page's list area
-- is shared by the encounter, wing and quest lists, with a centered message
-- line for empty results.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local LIST_TOP = -62 -- the list area starts under the left page's header and divider

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local BookLayout = {}

--- The book filling `parent`. `leftWidth`: the left page's width; `listWidth`: the list area's content width.
--- Returns `{ frame, leftPage, rightPage, spine, listScroll, listChild, emptyText }`.
function BookLayout:Create(parent, leftWidth, listWidth)
    local book = {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    book.frame = frame

    local leftPage = CreateFrame("Frame", nil, frame)
    leftPage:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    leftPage:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    leftPage:SetWidth(leftWidth)
    book.leftPage = leftPage

    local listScroll = ns.UI.ScrollFrame:Create(leftPage)
    listScroll:SetPoint("TOPLEFT", leftPage, "TOPLEFT", 2, LIST_TOP)
    listScroll:SetPoint("BOTTOMRIGHT", leftPage, "BOTTOMRIGHT", -22, 6)
    book.listScroll = listScroll
    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(listWidth, 320)
    listScroll:SetScrollChild(listChild)
    book.listChild = listChild

    local emptyText = listChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyText:SetPoint("TOPLEFT", listChild, "TOPLEFT", 16, -40)
    emptyText:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", -16, -40)
    emptyText:SetJustifyH("CENTER")
    emptyText:SetTextColor(0.80, 0.72, 0.55)
    emptyText:Hide()
    book.emptyText = emptyText

    local spine = ns.UI.Blocks.Divider:CreateVertical(frame, 4)
    spine:SetPoint("TOP", leftPage, "TOPRIGHT", 8, -14)
    spine:SetPoint("BOTTOM", leftPage, "BOTTOMRIGHT", 8, 14)
    book.spine = spine

    local rightPage = CreateFrame("Frame", nil, frame)
    rightPage:SetPoint("TOPLEFT", leftPage, "TOPRIGHT", 16, -ns.UI.Styles.SIZES.RIGHT_PAGE_DROP)
    rightPage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 10)
    book.rightPage = rightPage
    return book
end

--- Shows a message in the list area (an empty list) and sizes the area for it.
function BookLayout:ShowEmpty(book, text)
    book.emptyText:SetText(text)
    book.emptyText:Show()
    book.listChild:SetHeight(120)
    ns.UI.ScrollFrame:UpdateBar(book.listScroll, 120)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.BookLayout = BookLayout
