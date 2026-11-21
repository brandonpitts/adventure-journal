-- ============================================================================
-- Adventure Journal - Core/UI/SettingsSections.lua
-- Lists a settings page's sections under its category in the game's Settings
-- window. Every section is a subcategory showing the same page; picking one
-- scrolls the page to that section's header. A "General" entry leads the list;
-- it and the category itself scroll to the top, and picking the category opens
-- its section list (only the +/- collapses it).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local setmetatable = setmetatable
local C_Timer = C_Timer
local ScrollUtil = ScrollUtil
local EventRegistry = EventRegistry
local Settings = Settings

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Space left above a section header after scrolling to it
local HEADER_MARGIN = 8
-- The first entry under every page: the top of the page
local GENERAL = "General"

--- The game's Settings window's category list (not our ns.UI.SettingsPanel), or nil.
local function categoryList()
    local blizzardPanel = _G.SettingsPanel
    return blizzardPanel and blizzardPanel.GetCategoryList and blizzardPanel:GetCategoryList()
end

--- Calls `onClick` (a frame later, after the list's own click) whenever `category`'s row in the Settings list is
--- left-clicked, even while it is already selected: the list ignores clicks on its selected row, so no
--- "Settings.CategoryChanged" comes then. Rows are pooled and their OnClick is set again on every redraw, so
--- each row gets one OnMouseUp hook instead.
local function hookRowClicks(category, onClick, owner)
    local list = categoryList()
    local scrollBox = list and list.ScrollBox
    if not (scrollBox and scrollBox.ForEachFrame and ScrollUtil and ScrollUtil.AddAcquiredFrameCallback) then
        return
    end
    local hooked = setmetatable({}, { __mode = "k" })
    local function hookRow(row)
        if hooked[row] then
            return
        end
        hooked[row] = true
        row:HookScript("OnMouseUp", function(clicked, button)
            local elementData = clicked.GetElementData and clicked:GetElementData()
            local data = elementData and elementData.data
            if button == "LeftButton" and data and data.category == category then
                C_Timer.After(0, onClick)
            end
        end)
    end
    scrollBox:ForEachFrame(hookRow)
    ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, row) hookRow(row) end, owner)
end

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local SettingsSections = {}

--- Registers `sections` as subcategories of `category`, all showing `panel`.
--- @param category table the page's category (Settings.RegisterCanvasLayoutCategory)
--- @param panel Frame the settings page
--- @param scrollFrame ScrollFrame the page's scroll area
--- @param scrollChild Frame the scroll area's content
--- @param sections table ordered `{ { name = string, header = Region }, ... }`
function SettingsSections:Register(category, panel, scrollFrame, scrollChild, sections)
    if not (Settings.RegisterCanvasLayoutSubcategory and EventRegistry) then
        return
    end
    -- false scrolls to the top. "General" leads the list and does what picking the category itself does, for
    -- players who don't think to click the category's name.
    local headerByCategory = { [category] = false }
    -- Collapsed until the player opens it
    category:SetExpanded(false)
    local general = Settings.RegisterCanvasLayoutSubcategory(category, panel, GENERAL)
    headerByCategory[general] = false
    for _, section in ipairs(sections) do
        local subcategory = Settings.RegisterCanvasLayoutSubcategory(category, panel, section.name)
        headerByCategory[subcategory] = section.header
    end

    -- Picking the category itself always opens its section list; only its +/- toggle collapses it
    local function expand()
        if category:IsExpanded() then
            return
        end
        category:SetExpanded(true)
        local list = categoryList()
        if list and list.SetCurrentCategory then
            list:SetCurrentCategory(category)
        end
    end
    -- EventRegistry keeps one callback per owner, so each registered page gets its own
    local owner = {}
    hookRowClicks(category, expand, owner)

    EventRegistry:RegisterCallback("Settings.CategoryChanged", function(_, selected)
        local header = headerByCategory[selected]
        if header == nil then
            return
        end
        if selected == category then
            expand()
        end
        -- The page is re-parented and laid out when its category is shown; scroll once that has happened
        C_Timer.After(0, function()
            local offset = 0
            local childTop, headerTop = scrollChild:GetTop(), header and header:GetTop()
            if childTop and headerTop then
                offset = childTop - headerTop - HEADER_MARGIN
            end
            local maxOffset = scrollFrame:GetVerticalScrollRange()
            if offset > maxOffset then offset = maxOffset end
            if offset < 0 then offset = 0 end
            scrollFrame:SetVerticalScroll(offset)
        end)
    end, owner)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.SettingsSections = SettingsSections
