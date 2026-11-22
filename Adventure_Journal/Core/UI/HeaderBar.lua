-- ============================================================================
-- Adventure Journal - Core/UI/HeaderBar.lua
-- Top header bar: the breadcrumb trail (Core/UI/BreadcrumbBar.lua), the
-- SearchBox, and the Settings button.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local max = math.max
local CreateFrame = CreateFrame
local Mixin = Mixin
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local InCombatLockdown = InCombatLockdown
local ERR_NOT_IN_COMBAT = ERR_NOT_IN_COMBAT
local SearchBoxTemplate_OnTextChanged = SearchBoxTemplate_OnTextChanged
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local HeaderBarMixin = {}

--- Initializes the header bar on `parentFrame` (`JournalBaseMainFrame`).
--- @param parentFrame Frame
function HeaderBarMixin:Init(parentFrame)
    self.parentFrame = parentFrame

    self:CreateHeaderBand(parentFrame)
    self:CreateSettingsButton(self.HeaderBand)
    self:CreateSearchBox(self.HeaderBand)
    self.Breadcrumbs = ns.UI.BreadcrumbBar:Create(self.HeaderBand,
        (parentFrame:GetName() or "JournalBaseMainFrame") .. "NavBar", function()
            ns.ModuleRegistry:ShowActiveModuleHome()
        end)
    self:ResetBreadcrumbs("Home", function()
        ns.ModuleRegistry:DeactivateAll()
    end)

    parentFrame:HookScript("OnShow", function()
        self:RefreshBreadcrumbs()
    end)
end

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

    -- A shift-clicked item becomes the search while the box has focus
    ns.GameApi:OnItemLinkInserted(function(itemName)
        if searchBox:IsVisible() and searchBox:HasFocus() then
            searchBox:SetText(itemName)
            searchBox:SetCursorPosition(#itemName)
        end
    end)

    self.SearchBox = searchBox
end

--- Sets the whole breadcrumb trail. `crumbList`: `{ { id, label, onClick, menu } }`; the first entry is Home.
function HeaderBarMixin:SetBreadcrumbs(crumbList)
    self.Breadcrumbs:Set(crumbList)
end

--- Resets the trail to Home alone; `onRootClick` becomes Home's callback. Home is always labeled "Home".
--- @param rootLabel string|nil unused
--- @param onRootClick function|nil
function HeaderBarMixin:ResetBreadcrumbs(rootLabel, onRootClick)
    self.Breadcrumbs:Reset(onRootClick)
end

--- Appends a step. `menu()`, when given, returns the step's dropdown sections:
--- `{ { title, entries = { { text, isCurrent, onSelect } } } }`.
function HeaderBarMixin:PushStep(label, onStepClick, id, menu)
    self.Breadcrumbs:Push(label, onStepClick, id, menu)
end

--- Truncates the trail back to `targetIndex`.
function HeaderBarMixin:PopToIndex(targetIndex)
    self.Breadcrumbs:PopToIndex(targetIndex)
end

--- The active breadcrumb steps.
--- @return table[]
function HeaderBarMixin:GetBreadcrumbs()
    return self.Breadcrumbs.steps
end

--- Redraws the trail.
function HeaderBarMixin:RefreshBreadcrumbs()
    self.Breadcrumbs:Refresh()
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
