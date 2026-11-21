-- ============================================================================
-- Journal_Quests - UI/MainView.lua
-- The Quests tab's page: an "Under Construction" notice.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Quests or {} ; parent.Quests = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local MainView = {
    rootFrame = nil,
}

--- Builds the page inside `canvas`.
--- @param canvas Frame
function MainView:Init(canvas)
    if self.rootFrame then
        return
    end
    local root = CreateFrame("Frame", nil, canvas)
    root:SetAllPoints(canvas)

    local notice = root:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    notice:SetPoint("CENTER", root, "CENTER", 0, 0)
    notice:SetText("Under Construction")

    self.rootFrame = root
end

--- Shows the page.
function MainView:Show()
    if self.rootFrame then
        self.rootFrame:Show()
    end
end

--- Hides the page.
function MainView:Hide()
    if self.rootFrame then
        self.rootFrame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.MainView = MainView
