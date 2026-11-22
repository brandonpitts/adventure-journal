-- ============================================================================
-- Adventure Journal - Core/UI/BreadcrumbBar.lua
-- The header's breadcrumb trail: the game's NavBarTemplate inside our recessed
-- bronze track. The red Home button comes first, then one button per step, each
-- fitted to its name and drawn by Core/UI/BreadcrumbStepArt.lua. The last step
-- is the current page (disabled). A step with a menu gets the dropdown arrow,
-- listing the step's alternatives: the other instances, wings, bosses or quests.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local setmetatable = setmetatable
local type = type
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local MenuResponse = MenuResponse
local NavBar_Initialize = NavBar_Initialize
local NavBar_AddButton = NavBar_AddButton
local NavBar_Reset = NavBar_Reset
local NavBar_CheckLength = NavBar_CheckLength
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local HOME_LABEL = "Home"
local MENU_MAX_HEIGHT = 380

--- Draws the recessed track: dark fill, inner top shadow, bronze edges and a faint center rail.
--- @param frame Frame
local function applyRecessedTrackStyle(frame)
    local white = Constants.ASSETS.WHITE_8X8
    local function line(layer, r, g, b, a)
        local tex = frame:CreateTexture(nil, layer)
        tex:SetTexture(white)
        tex:SetVertexColor(r, g, b, a)
        return tex
    end

    local bg = line("BACKGROUND", 0.13, 0.12, 0.10, 0.92)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    local innerShadowTop = line("BORDER", 0.03, 0.03, 0.03, 0.65)
    innerShadowTop:SetHeight(3)
    innerShadowTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    innerShadowTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)

    local centerRail = line("BORDER", 0.32, 0.26, 0.17, 0.42)
    centerRail:SetHeight(1)
    centerRail:SetPoint("LEFT", frame, "LEFT", 6, 0)
    centerRail:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

    local top = line("ARTWORK", 0.28, 0.23, 0.15, 0.95)
    top:SetHeight(1)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    local bottom = line("ARTWORK", 0.48, 0.39, 0.24, 0.95)
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local left = line("ARTWORK", 0.36, 0.29, 0.18, 0.95)
    left:SetWidth(1)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)

    local right = line("ARTWORK", 0.36, 0.29, 0.18, 0.95)
    right:SetWidth(1)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
end

--- Hides the NavBar's own dark background and stone inset border, so our track shows behind the buttons.
--- @param navBar Frame
local function stripNavBarChrome(navBar)
    for _, region in ipairs({ navBar:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end
    if navBar.overlay then
        navBar.overlay:Hide()
    end
end

--- Fills a dropdown from a step's menu sections: `{ { title, entries = { { text, isCurrent, onSelect } } } }`.
--- Sections without entries are skipped; each section after the first gets a divider above it.
local function fillMenu(rootDescription, sections)
    rootDescription:SetScrollMode(MENU_MAX_HEIGHT)
    local drawnAny = false
    for _, section in ipairs(sections) do
        if #section.entries > 0 then
            if drawnAny then
                rootDescription:CreateDivider()
            end
            if section.title then
                rootDescription:CreateTitle(section.title)
            end
            for _, entry in ipairs(section.entries) do
                rootDescription:CreateRadio(entry.text, function()
                    return entry.isCurrent == true
                end, function()
                    PlaySound(Constants.SOUNDS.CLICK)
                    entry.onSelect()
                    return MenuResponse.CloseAll
                end)
            end
            drawnAny = true
        end
    end
end

--- Points a step button's arrow at our menu. The game re-points it at its flat list each time the button is
--- shown (`NavButtonTemplate_OnShow`), so this also runs after every show.
--- @param button Button a NavButtonTemplate button
local function useJournalMenu(button)
    button.MenuArrowButton:SetupMenu(function(_, rootDescription)
        local step = button.journalStep
        local sections = step and step.menu and step.menu()
        if sections then
            fillMenu(rootDescription, sections)
        end
    end)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local BreadcrumbBar = {}
BreadcrumbBar.__index = BreadcrumbBar

--- The breadcrumb track on `headerBand`. `frameName` names the NavBar (its template names its buttons after it).
--- `onRootFallback()` runs when Home is clicked and the root step has no callback of its own.
--- @return table
function BreadcrumbBar:Create(headerBand, frameName, onRootFallback)
    local bar = setmetatable({ steps = {}, onRootFallback = onRootFallback }, BreadcrumbBar)
    local window = Constants.WINDOW

    local track = CreateFrame("Frame", nil, headerBand)
    track:SetHeight(window.CRUMB_TRACK_HEIGHT)
    track:SetPoint("LEFT", headerBand, "LEFT", window.CRUMB_TRACK_LEFT_X, 0)
    track:SetPoint("RIGHT", headerBand, "RIGHT", window.CRUMB_TRACK_RIGHT_X, 0)
    track:SetClipsChildren(true)
    applyRecessedTrackStyle(track)
    bar.track = track

    local scale = window.NAVBAR_SCALE
    local navBar = CreateFrame("Frame", frameName, track, "NavBarTemplate")
    navBar:SetScale(scale)
    navBar:SetPoint("TOPLEFT", track, "TOPLEFT", 1 / scale, -1 / scale)
    navBar:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1 / scale, 1 / scale)
    NavBar_Initialize(navBar, "NavButtonTemplate", {
        name = HOME_LABEL,
        OnClick = function()
            bar:OnRootClicked()
        end,
    }, navBar.home, navBar.overflow)
    -- Home's template click plays its own sound before ours; OnRootClicked plays the one click sound
    navBar.home.oldClick = nil
    stripNavBarChrome(navBar)
    ns.UI.BreadcrumbStepArt:ApplyOverflow(navBar.overflow)
    bar.navBar = navBar

    bar:Reset(nil)
    return bar
end

--- Runs the root step's callback, or the fallback when it has none.
function BreadcrumbBar:OnRootClicked()
    PlaySound(Constants.SOUNDS.CLICK)
    local rootCb = self.steps[1] and self.steps[1].onClick
    self:PopToIndex(1)
    if type(rootCb) == "function" then
        rootCb()
    elseif self.onRootFallback then
        self.onRootFallback()
    end
end

--- Sets the whole trail. `crumbList`: `{ { id, label, onClick, menu } }`; the first entry is Home.
function BreadcrumbBar:Set(crumbList)
    if not crumbList or #crumbList == 0 then
        self:Reset(nil)
        return
    end
    self.steps = {}
    for i, item in ipairs(crumbList) do
        self.steps[i] = {
            id = item.id or item.label,
            label = (i == 1) and HOME_LABEL or (item.label or ""),
            onClick = item.onClick,
            menu = item.menu,
        }
    end
    self:Refresh()
end

--- Back to Home alone; `onRootClick` becomes Home's callback.
function BreadcrumbBar:Reset(onRootClick)
    self.steps = { { id = "root", label = HOME_LABEL, onClick = onRootClick } }
    self:Refresh()
end

--- Adds a step. `menu()`, when given, returns the step's dropdown sections (see `fillMenu`).
function BreadcrumbBar:Push(label, onClick, id, menu)
    if not label or label == "" then
        return
    end
    self.steps[#self.steps + 1] = { id = id or label, label = label, onClick = onClick, menu = menu }
    self:Refresh()
end

--- Drops every step after `targetIndex`.
function BreadcrumbBar:PopToIndex(targetIndex)
    if type(targetIndex) ~= "number" or targetIndex < 1 then
        return
    end
    for i = #self.steps, targetIndex + 1, -1 do
        self.steps[i] = nil
    end
    self:Refresh()
end

--- Redraws the trail from `self.steps`. The NavBar fits each button to its name and marks the last one current.
function BreadcrumbBar:Refresh()
    local navBar = self.navBar
    NavBar_Reset(navBar)
    for i = 2, #self.steps do
        local step, index = self.steps[i], i
        NavBar_AddButton(navBar, {
            id = index,
            name = step.label,
            OnClick = function()
                PlaySound(Constants.SOUNDS.CLICK)
                self:PopToIndex(index)
                if type(step.onClick) == "function" then
                    step.onClick()
                end
            end,
            -- Only its presence matters: it gives the button the arrow. `useJournalMenu` builds the menu.
            listFunc = step.menu and function() return {} end or nil,
        })
        local button = navBar.navList[#navBar.navList]
        button.journalStep = step
        if not button.journalMenuHooked then
            button.journalMenuHooked = true
            button:HookScript("OnShow", useJournalMenu)
        end
        useJournalMenu(button)
        local StepArt = ns.UI.BreadcrumbStepArt
        StepArt:Apply(button, i == #self.steps)
        -- The tip sits inside the button, so it gets its own width on top of the name's
        button:SetWidth(button:GetWidth() + StepArt.TIP_WIDTH)
    end
    NavBar_CheckLength(navBar)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.BreadcrumbBar = BreadcrumbBar
