-- ============================================================================
-- Adventure Journal - Core/UI/HeaderBar.lua
-- Top header bar with breadcrumb navigation track, SearchBox, and Settings button.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local max = math.max
local pcall = pcall
local type = type
local unpack = unpack or table.unpack
local CreateFrame = CreateFrame
local Mixin = Mixin
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local InCombatLockdown = InCombatLockdown
local ERR_NOT_IN_COMBAT = ERR_NOT_IN_COMBAT
local NavBar_Initialize = NavBar_Initialize
local NavBar_AddButton = NavBar_AddButton
local NavBar_Reset = NavBar_Reset
local SearchBoxTemplate_OnTextChanged = SearchBoxTemplate_OnTextChanged
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Applies background and border textures to the breadcrumb track.
--- @param frame Frame
local function applyRecessedTrackStyle(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    bg:SetTexture(Constants.ASSETS.WHITE_8X8)
    bg:SetVertexColor(0.13, 0.12, 0.10, 0.92)
    frame.bg = bg

    local innerShadowTop = frame:CreateTexture(nil, "BORDER")
    innerShadowTop:SetHeight(3)
    innerShadowTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    innerShadowTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    innerShadowTop:SetTexture(Constants.ASSETS.WHITE_8X8)
    innerShadowTop:SetVertexColor(0.03, 0.03, 0.03, 0.65)

    local borderTop = frame:CreateTexture(nil, "ARTWORK")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderTop:SetVertexColor(0.28, 0.23, 0.15, 0.95)

    local borderBottom = frame:CreateTexture(nil, "ARTWORK")
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderBottom:SetVertexColor(0.48, 0.39, 0.24, 0.95)

    local borderLeft = frame:CreateTexture(nil, "ARTWORK")
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    borderLeft:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderLeft:SetVertexColor(0.36, 0.29, 0.18, 0.95)

    local borderRight = frame:CreateTexture(nil, "ARTWORK")
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)
    borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
    borderRight:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderRight:SetVertexColor(0.36, 0.29, 0.18, 0.95)
end

--- Hides default background and border regions on a NavBar frame.
--- @param navBar Frame
local function stripNavBarChrome(navBar)
    -- Hide any background/border textures directly on the NavBar frame
    local regions = { navBar:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
            region:Hide()
        end
    end

    -- Hide the inner stone border overlay frame (`InsetBorderTop/Bottom/Left/Right`)
    if navBar.overlay then
        navBar.overlay:SetAlpha(0)
        navBar.overlay:Hide()
    end
end

--- Styles a lightweight, modern native text link breadcrumb and its separator.
--- @param btn Button
--- @param sep FontString
--- @param label string
--- @param isCurrent boolean
--- @param onClick function|nil
local function styleBreadcrumbLink(btn, sep, label, isCurrent, onClick)
    if sep then
        if _G["GameFontNormal"] then
            sep:SetFontObject("GameFontNormal")
        else
            sep:SetFontObject("GameFontNormalSmall")
        end
        sep:SetText("|TInterface\\ChatFrame\\ChatFrameExpandArrow:12:12|t")
        sep:SetTextColor(0.85, 0.72, 0.45, 0.85)
        sep:SetShadowOffset(1, -1)
        sep:SetShadowColor(0, 0, 0, 0.85)
        sep:Show()
    end

    -- 2. Button Label FontString (must set FontObject BEFORE SetText)
    local fs = btn:GetFontString()
    if not fs then
        fs = btn:CreateFontString(nil, "ARTWORK")
        btn:SetFontString(fs)
    end
    if isCurrent then
        if _G["GameFontHighlightMedium"] then
            fs:SetFontObject("GameFontHighlightMedium")
        elseif _G["GameFontNormalMed2"] then
            fs:SetFontObject("GameFontNormalMed2")
        elseif _G["GameFontHighlight"] then
            fs:SetFontObject("GameFontHighlight")
        else
            fs:SetFontObject("GameFontNormal")
        end
    else
        if _G["GameFontNormal"] then
            fs:SetFontObject("GameFontNormal")
        else
            fs:SetFontObject("GameFontNormalSmall")
        end
    end
    if fs.SetWordWrap then
        fs:SetWordWrap(false)
    end
    fs:SetText(label or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.90)

    -- 3. Interactivity & Color Styling:
    if isCurrent then
        fs:SetTextColor(1.0, 0.96, 0.88, 1.0) -- bright bold warm parchment
        btn:Disable()
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
        btn:SetScript("OnClick", nil)
    else
        fs:SetTextColor(1.0, 0.82, 0.0, 1.0) -- Blizzard gold
        btn:Enable()
        btn:SetScript("OnEnter", function(b)
            local fontStr = b:GetFontString()
            if fontStr then
                fontStr:SetTextColor(1.0, 1.0, 1.0, 1.0) -- bright white highlight on hover
            end
        end)
        btn:SetScript("OnLeave", function(b)
            local fontStr = b:GetFontString()
            if fontStr then
                fontStr:SetTextColor(1.0, 0.82, 0.0, 1.0) -- revert to gold
            end
        end)
        btn:SetScript("OnClick", function()
            if PlaySound then
                PlaySound(Constants.SOUNDS.CLICK)
            end
            if type(onClick) == "function" then
                onClick()
            end
        end)
    end

    -- 5. Dynamic Width Sizing based on the larger font width
    local textWidth = (fs and fs.GetStringWidth and fs:GetStringWidth()) or 40
    local textHeight = (fs and fs.GetStringHeight and fs:GetStringHeight()) or 18
    btn:SetSize(textWidth + 6, math.max(22, textHeight + 4))
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)

    btn:Show()
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local HeaderBarMixin = {}

--- Initializes the header bar on `parentFrame` (`JournalBaseMainFrame`).
--- @param parentFrame Frame
function HeaderBarMixin:Init(parentFrame)
    self.parentFrame = parentFrame
    self.steps = {}
    self.stepPool = {}
    self.separatorPool = {}
    self.usingNativeNavBar = false

    self:CreateHeaderBand(parentFrame)
    self:CreateSettingsButton(self.HeaderBand)
    self:CreateSearchBox(self.HeaderBand)
    self:CreateBreadcrumbTrack(self.HeaderBand)
    self:ResetBreadcrumbs("Home", function()
        if ns.ModuleRegistry and ns.ModuleRegistry.DeactivateAll then
            ns.ModuleRegistry:DeactivateAll()
        end
    end)

    if parentFrame and parentFrame.HookScript then
        parentFrame:HookScript("OnShow", function()
            self:RefreshBreadcrumbs()
        end)
    end
end

--- Creates the positioning band across the top header zone (`y = -23`, height `33`).
--- @param parentFrame Frame
function HeaderBarMixin:CreateHeaderBand(parentFrame)
    local band = CreateFrame("Frame", nil, parentFrame)
    band:SetFrameLevel(max(1, parentFrame:GetFrameLevel()))
    band:SetHeight(Constants.WINDOW.HEADER_HEIGHT)
    band:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, Constants.WINDOW.HEADER_TOP_Y)
    band:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, Constants.WINDOW.HEADER_TOP_Y)
    self.HeaderBand = band
end

--- Creates the compact gear icon button directly on the header (no outer box container).
--- @param headerBand Frame
function HeaderBarMixin:CreateSettingsButton(headerBand)
    local iconSize = Constants.WINDOW.GEAR_ICON_SIZE
    local button = CreateFrame("Button", nil, headerBand)
    button:SetSize(iconSize, iconSize)
    button:SetPoint("RIGHT", headerBand, "RIGHT", Constants.WINDOW.GEAR_OFFSET_X, 0)

    local normalTex = button:CreateTexture(nil, "ARTWORK")
    normalTex:SetAllPoints(button)
    normalTex:SetTexture(Constants.ASSETS.GEAR_ICON)
    button:SetNormalTexture(normalTex)

    local pushedTex = button:CreateTexture(nil, "ARTWORK")
    pushedTex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    pushedTex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    pushedTex:SetTexture(Constants.ASSETS.GEAR_ICON)
    pushedTex:SetVertexColor(0.80, 0.80, 0.80)
    button:SetPushedTexture(pushedTex)

    button:SetHighlightTexture(Constants.ASSETS.BUTTON_HIGHLIGHT, "ADD")

    -- Settings can't be opened in combat: grey out and disable the gear until combat ends
    local function setCombatState(inCombat)
        button:SetEnabled(not inCombat)
        normalTex:SetDesaturated(inCombat)
        normalTex:SetVertexColor(inCombat and 0.55 or 1.0, inCombat and 0.55 or 1.0, inCombat and 0.55 or 1.0)
    end
    button:RegisterEvent("PLAYER_REGEN_DISABLED")
    button:RegisterEvent("PLAYER_REGEN_ENABLED")
    button:SetScript("OnEvent", function(_, event)
        setCombatState(event == "PLAYER_REGEN_DISABLED")
        if GameTooltip and GameTooltip:IsOwned(button) then
            button:GetScript("OnEnter")(button)
        end
    end)
    setCombatState(InCombatLockdown() and true or false)

    button:SetScript("OnEnter", function(btn)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Journal Settings", 1.0, 0.82, 0.0)
        if not btn:IsEnabled() then
            GameTooltip:AddLine(ERR_NOT_IN_COMBAT, 1.0, 0.25, 0.25)
        end
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    button:SetScript("OnClick", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if _G.JournalBase then
            _G.JournalBase:OpenSettings()
        end
    end)

    self.SettingsButton = button
end

--- Creates the native `SearchBoxTemplate` directly on the header (no outer box container).
--- Throttles / debounces live keystroke search dispatch (`0.18s`) so rapid typing does not lag the game,
--- while dispatching immediately when the box is cleared or `Enter` is pressed.
--- @param headerBand Frame
function HeaderBarMixin:CreateSearchBox(headerBand)
    local searchBox = CreateFrame("EditBox", nil, headerBand, "SearchBoxTemplate")
    searchBox:SetSize(Constants.WINDOW.SEARCH_WIDTH, Constants.WINDOW.SEARCH_HEIGHT)
    searchBox:SetPoint("RIGHT", headerBand, "RIGHT", Constants.WINDOW.SEARCH_OFFSET_X, 0)
    searchBox:SetAutoFocus(false)

    local SEARCH_DEBOUNCE_SEC = 0.18
    local pendingDelay = nil
    local lastDispatchedText = ""

    local function flushSearch(text)
        pendingDelay = nil
        searchBox:SetScript("OnUpdate", nil)
        local normalized = text or ""
        if normalized ~= lastDispatchedText then
            lastDispatchedText = normalized
            ns.ModuleRegistry:DispatchSearch(normalized)
        end
    end

    searchBox:SetScript("OnTextChanged", function(editBox)
        if SearchBoxTemplate_OnTextChanged then
            SearchBoxTemplate_OnTextChanged(editBox)
        end
        local text = editBox:GetText() or ""
        if text == "" then
            -- Clearing the search box should feel instantaneous
            flushSearch("")
            return
        end
        if text == lastDispatchedText then
            pendingDelay = nil
            editBox:SetScript("OnUpdate", nil)
            return
        end
        pendingDelay = SEARCH_DEBOUNCE_SEC
        editBox:SetScript("OnUpdate", function(_, elapsed)
            if not pendingDelay then
                editBox:SetScript("OnUpdate", nil)
                return
            end
            pendingDelay = pendingDelay - (elapsed or 0)
            if pendingDelay <= 0 then
                flushSearch(editBox:GetText() or "")
            end
        end)
    end)

    searchBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
    end)

    searchBox:SetScript("OnEnterPressed", function(editBox)
        flushSearch(editBox:GetText() or "")
        editBox:ClearFocus()
    end)

    self.SearchBox = searchBox
end

--- Creates the breadcrumb track and initializes the native NavBar within it.
--- @param headerBand Frame
function HeaderBarMixin:CreateBreadcrumbTrack(headerBand)
    local track = CreateFrame("Frame", nil, headerBand)
    track:SetHeight(Constants.WINDOW.CRUMB_TRACK_HEIGHT)
    track:SetPoint("LEFT", headerBand, "LEFT", Constants.WINDOW.CRUMB_TRACK_LEFT_X, 0)
    track:SetPoint("RIGHT", headerBand, "RIGHT", Constants.WINDOW.CRUMB_TRACK_RIGHT_X, 0)

    applyRecessedTrackStyle(track)
    if track.SetClipsChildren then
        track:SetClipsChildren(true)
    end

    local centerRail = track:CreateTexture(nil, "BORDER")
    centerRail:SetHeight(1)
    centerRail:SetPoint("LEFT", track, "LEFT", 6, 0)
    centerRail:SetPoint("RIGHT", track, "RIGHT", -6, 0)
    centerRail:SetTexture(Constants.ASSETS.WHITE_8X8)
    centerRail:SetVertexColor(0.32, 0.26, 0.17, 0.42)

    self.BreadcrumbContainer = track

    if type(NavBar_Initialize) == "function" and type(NavBar_AddButton) == "function" then
        local navName = (self.parentFrame:GetName() or "JournalBaseMainFrame") .. "NavBar"
        local ok, navBar = pcall(CreateFrame, "Frame", navName, track, "NavBarTemplate")
        if ok and navBar then
            local scale = Constants.WINDOW.NAVBAR_SCALE or 0.86
            navBar:SetScale(scale)
            navBar:ClearAllPoints()
            navBar:SetPoint("TOPLEFT", track, "TOPLEFT", 1 / scale, -1 / scale)
            navBar:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1 / scale, 1 / scale)

            stripNavBarChrome(navBar)

            if navBar.home then
                navBar.home:ClearAllPoints()
                navBar.home:SetPoint("LEFT", navBar, "LEFT", 0, 0)
            end

            local homeData = {
                name = "Home",
                OnClick = function()
                    self:OnRootClicked()
                end,
            }
            local initOk = pcall(NavBar_Initialize, navBar, "NavButtonTemplate", homeData, navBar.home, navBar.overflow)
            if initOk then
                stripNavBarChrome(navBar)
                if navBar.home then
                    if navBar.home.SetText then navBar.home:SetText("Home") end
                    if navBar.home.text and navBar.home.text.SetText then navBar.home.text:SetText("Home") end
                end
                self.NativeNavBar = navBar
                self.usingNativeNavBar = true
            else
                navBar:Hide()
            end
        end
    end
end

--- Invoked when the root breadcrumb button is clicked.
--- Runs the root step's callback, or shows the active module's root page when it has none.
function HeaderBarMixin:OnRootClicked()
    local rootStep = self.steps and self.steps[1]
    local rootCb = rootStep and rootStep.onClick

    self:PopToIndex(1)

    if type(rootCb) == "function" then
        rootCb()
    elseif ns.ModuleRegistry then
        ns.ModuleRegistry:ShowActiveModuleHome()
    end
end

--- Sets the entire breadcrumb stack declaratively.
--- @param crumbList table Array of `{ id, label, onClick }`
function HeaderBarMixin:SetBreadcrumbs(crumbList)
    if not crumbList or #crumbList == 0 then
        self:ResetBreadcrumbs("Home", nil)
        return
    end

    self.steps = {}
    for i, item in ipairs(crumbList) do
        self.steps[i] = {
            id = item.id or item.label,
            label = (i == 1) and "Home" or (item.label or ""),
            onClick = item.onClick,
        }
    end
    self:RefreshBreadcrumbs()
end

--- Resets breadcrumbs to the root "Home" state (1 step).
--- @param rootLabel string|nil
--- @param onRootClick function|nil
function HeaderBarMixin:ResetBreadcrumbs(rootLabel, onRootClick)
    self.steps = {
        {
            id = "root",
            label = "Home",
            onClick = onRootClick,
        },
    }
    self:RefreshBreadcrumbs()
end

--- Appends a new navigation step onto the breadcrumb track.
--- @param label string
--- @param onStepClick function|nil
--- @param id string|nil
function HeaderBarMixin:PushStep(label, onStepClick, id)
    if not label or label == "" then
        return
    end
    self.steps[#self.steps + 1] = {
        id = id or label,
        label = label,
        onClick = onStepClick,
    }
    self:RefreshBreadcrumbs()
end

--- Truncates breadcrumbs back to `targetIndex`.
--- @param targetIndex number
function HeaderBarMixin:PopToIndex(targetIndex)
    if type(targetIndex) ~= "number" or targetIndex < 1 then
        return
    end
    while #self.steps > targetIndex do
        self.steps[#self.steps] = nil
    end
    self:RefreshBreadcrumbs()
end

--- Returns the active breadcrumb steps.
--- @return table[]
function HeaderBarMixin:GetBreadcrumbs()
    return self.steps
end

--- Re-renders all active breadcrumb steps along the recessed track.
--- Updates breadcrumb buttons and separators along the track.
function HeaderBarMixin:RefreshBreadcrumbs()
    if not self.usingNativeNavBar or not self.NativeNavBar then
        return
    end

    local navBar = self.NativeNavBar
    local totalSteps = #self.steps
    local homeBtn = navBar.home

    if homeBtn then
        if homeBtn.SetText then
            homeBtn:SetText("Home")
        end
        local homeFs = homeBtn.text or (homeBtn.GetFontString and homeBtn:GetFontString())
        if homeFs and homeFs.SetText then
            homeFs:SetText("Home")
        end
        for _, region in ipairs({ homeBtn:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                region:SetText("Home")
            end
        end

        homeBtn:ClearAllPoints()
        homeBtn:SetPoint("LEFT", navBar, "LEFT", 0, 0)
        homeBtn:Show()
        homeBtn:Enable()
        homeBtn:SetFrameLevel(navBar:GetFrameLevel() + 10)
        homeBtn:RegisterForClicks("LeftButtonUp")
        homeBtn:SetScript("OnClick", function()
            if PlaySound then
                PlaySound(Constants.SOUNDS.CLICK)
            end
            self:OnRootClicked()
        end)
    end

    for idx, childBtn in pairs(self.stepPool) do
        if type(idx) == "number" and idx > totalSteps and childBtn then
            childBtn:Hide()
        end
    end
    if not self.separatorPool then
        self.separatorPool = {}
    end
    for idx, sep in pairs(self.separatorPool) do
        if type(idx) == "number" and idx > totalSteps and sep then
            sep:Hide()
        end
    end

    local prevWidget = homeBtn
    for i = 2, totalSteps do
        local step = self.steps[i]
        local stepIndex = i
        local isCurrent = (i == totalSteps)

        local sep = self.separatorPool[i]
        if not sep then
            sep = navBar:CreateFontString(nil, "ARTWORK")
            self.separatorPool[i] = sep
        end

        -- Clean text button (no XML template baggage)
        local btn = self.stepPool[i]
        if not btn or btn.redFill then
            if btn then
                btn:Hide()
                btn:ClearAllPoints()
            end
            btn = CreateFrame("Button", nil, navBar)
            btn:RegisterForClicks("LeftButtonUp")
            self.stepPool[i] = btn
        end

        btn:SetFrameLevel(navBar:GetFrameLevel() + 5)

        styleBreadcrumbLink(btn, sep, step.label, isCurrent, function()
            self:PopToIndex(stepIndex)
            if type(step.onClick) == "function" then
                step.onClick()
            end
        end)

        -- Sequential positive-offset layout:
        -- prevWidget -> 8px -> sep -> 8px -> btn
        sep:ClearAllPoints()
        sep:SetPoint("LEFT", prevWidget, "RIGHT", 8, 0)

        btn:ClearAllPoints()
        btn:SetPoint("LEFT", sep, "RIGHT", 8, 0)

        prevWidget = btn
    end

    -- 4. Sweep any and all stray/unpooled children of navBar
    local activeButtons = { [homeBtn] = true }
    if navBar.overflow then activeButtons[navBar.overflow] = true end
    for i = 2, totalSteps do
        if self.stepPool[i] then
            activeButtons[self.stepPool[i]] = true
        end
    end
    for _, child in ipairs({ navBar:GetChildren() }) do
        if not activeButtons[child] then
            child:Hide()
            child:ClearAllPoints()
        end
    end
end

--- Clears the search box input text.
function HeaderBarMixin:ClearSearch()
    if self.SearchBox then
        self.SearchBox:SetText("")
    end
end

local HeaderBar = {}

--- Factory method to construct and initialize the HeaderBar controller for `parentFrame`.
--- @param parentFrame Frame
--- @return table
function HeaderBar:Create(parentFrame)
    local controller = {}
    Mixin(controller, HeaderBarMixin)
    controller:Init(parentFrame)
    return controller
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.HeaderBar = HeaderBar
