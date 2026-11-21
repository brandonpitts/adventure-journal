-- ============================================================================
-- Adventure Journal - Core/UI/ScrollFrame.lua
-- Scroll frames with the client's modern MinimalScrollBar, the bar Forever's own
-- Settings panel uses. The bar sits just right of the scroll area and hides
-- itself while the content fits.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame
local ScrollUtil = ScrollUtil

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Gap between the scroll area's right edge and the bar
local BAR_OFFSET_X = 6

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local ScrollFrame = {}

--- A scroll frame with a MinimalScrollBar (`scrollFrame.ScrollBar`). Anchor the scroll frame and give it a
--- scroll child as usual; leave room on its right for the bar.
--- @param parent Frame
--- @return ScrollFrame
function ScrollFrame:Create(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:EnableMouseWheel(true)

    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", BAR_OFFSET_X, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", BAR_OFFSET_X, 0)
    scrollBar:SetHideIfUnscrollable(true)
    scrollFrame.ScrollBar = scrollBar

    ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollBar)
    return scrollFrame
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.ScrollFrame = ScrollFrame
