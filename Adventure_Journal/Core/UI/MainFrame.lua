-- ============================================================================
-- Journal_Base - UI/MainFrame.lua
-- Top-level 830x596 native bronze ButtonFrameTemplate window and empty state.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local _G = _G
local tinsert = tinsert
local pcall = pcall
local CreateFrame = CreateFrame
local UIParent = UIParent
local UISpecialFrames = UISpecialFrames
local PlaySound = PlaySound
local SetPortraitToTexture = SetPortraitToTexture
local ButtonFrameTemplate_HideButtonBar = ButtonFrameTemplate_HideButtonBar
local C_AddOns = C_AddOns
local UIParentLoadAddOn = UIParentLoadAddOn
local Constants = ns.Constants

local FRAME_NAME = "JournalBaseMainFrame"

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Resolves a texture path that exists in the client, falling back gracefully.
local function resolveIconAsset(preferredPath, fallbackPath)
    if GetFileIDFromPath and preferredPath then
        local ok, fileId = pcall(GetFileIDFromPath, preferredPath)
        if ok and fileId then
            return preferredPath
        end
    end
    return fallbackPath or preferredPath
end

--- Sets the window title text across 16001 / ButtonFrameTemplate variations.
local function setWindowTitle(frame, titleText)
    if frame.SetTitle then
        frame:SetTitle(titleText)
        return
    end
    if frame.TitleContainer and frame.TitleContainer.TitleText then
        frame.TitleContainer.TitleText:SetText(titleText)
        return
    end
    if frame.TitleText then
        frame.TitleText:SetText(titleText)
    end
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local MainFrame = {
    frame = nil,
    hasOpenedOnce = false,
}

--- Initializes the `JournalBaseMainFrame` window.
function MainFrame:Init()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "ButtonFrameTemplate")
    frame:SetSize(Constants.WINDOW.WIDTH, Constants.WINDOW.HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    if ButtonFrameTemplate_HideButtonBar then
        pcall(ButtonFrameTemplate_HideButtonBar, frame)
    end

    setWindowTitle(frame, Constants.TITLE)
    self.frame = frame

    self:SetPortraitIcon(Constants.ASSETS.JOURNAL_PORTRAIT)
    self:RestorePosition()
    self:SetupDragAndLifecycle(frame)
    self:SetupHeaderAndCanvas(frame)
    self:SetupEmptyState(frame.ContentCanvas)

    ns.UI.TabBar:Init(frame)

    if UISpecialFrames then
        tinsert(UISpecialFrames, FRAME_NAME)
    end

    self:OnPluginsChanged()
end

--- @return boolean
function MainFrame:IsInitialized()
    return self.frame ~= nil
end

--- Sets the top-left circular portrait texture on the window frame.
--- @param texturePath string|nil
function MainFrame:SetPortraitIcon(texturePath)
    if not self.frame then
        return
    end

    local iconPath = resolveIconAsset(texturePath, Constants.ASSETS.FALLBACK_ICON)

    if self.frame.SetPortraitToAsset then
        local ok = pcall(self.frame.SetPortraitToAsset, self.frame, iconPath)
        if ok then
            return
        end
    end

    local portraitRegion = self.frame.portrait
        or (self.frame.PortraitContainer and self.frame.PortraitContainer.portrait)

    if portraitRegion then
        if SetPortraitToTexture then
            pcall(SetPortraitToTexture, portraitRegion, iconPath)
        else
            portraitRegion:SetTexture(iconPath)
        end
    end
end

--- Restores the saved window anchor point from `Database`, or centers the window.
function MainFrame:RestorePosition()
    if not self.frame then
        return
    end
    self.frame:ClearAllPoints()
    local saved = ns.Database:GetWindowPoint()
    if saved and saved.point and saved.relativePoint and saved.x and saved.y then
        self.frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", Constants.WINDOW.DEFAULT_OFFSET_X, Constants.WINDOW.DEFAULT_OFFSET_Y)
    end
end

--- Configures drag-to-move persistence and open/close audio scripts.
--- @param frame Frame
function MainFrame:SetupDragAndLifecycle(frame)
    frame:SetScript("OnDragStart", function(f)
        f:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relativePoint, x, y = f:GetPoint(1)
        if point and relativePoint then
            ns.Database:SetWindowPoint({
                point = point,
                relativePoint = relativePoint,
                x = x,
                y = y,
            })
        end
        if self.HeaderBar and self.HeaderBar.RefreshBreadcrumbs then
            self.HeaderBar:RefreshBreadcrumbs()
        end
    end)

    frame:SetScript("OnShow", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.OPEN)
        end
        local defaultLandingId = ns.Database:GetDefaultLandingPluginId()
        if defaultLandingId and ns.PluginRegistry:GetPlugin(defaultLandingId) and not ns.Database:IsPluginDisabled(defaultLandingId) then
            -- Open directly to the configured default landing tab whenever the window opens
            ns.PluginRegistry:ActivatePlugin(defaultLandingId)
        elseif not self.hasOpenedOnce then
            self.hasOpenedOnce = true
            if not ns.PluginRegistry:GetActivePlugin() then
                ns.PluginRegistry:ActivateDefaultPlugin()
            end
        end
    end)

    frame:SetScript("OnHide", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLOSE)
        end
    end)
end

--- Applies CollectionsBackgroundTemplate stone background to insetFrame.
local function applyAppearancesStoneBackground(insetFrame)
    if insetFrame.Bg then
        insetFrame.Bg:Hide()
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Collections")
    elseif UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_Collections")
    end

    local ok, bgFrame = pcall(CreateFrame, "Frame", nil, insetFrame, "CollectionsBackgroundTemplate")
    if ok and bgFrame then
        bgFrame:SetAllPoints(insetFrame)
        bgFrame:SetFrameLevel(insetFrame:GetFrameLevel())
        bgFrame:EnableMouse(false)
        insetFrame.CollectionsBg = bgFrame
        return
    end

    -- Fallback: clone `.BackgroundTile` and `.Bg` directly from `WardrobeCollectionFrame.ItemsCollectionFrame`
    local srcFrame = _G.WardrobeCollectionFrame and _G.WardrobeCollectionFrame.ItemsCollectionFrame
    if srcFrame then
        if srcFrame.BackgroundTile then
            local tile = insetFrame:CreateTexture(nil, "BACKGROUND", nil, -2)
            tile:SetAllPoints(insetFrame)
            tile:SetHorizTile(true)
            tile:SetVertTile(true)
            local atlas = srcFrame.BackgroundTile:GetAtlas()
            if atlas then
                tile:SetAtlas(atlas, true)
            else
                tile:SetTexture(srcFrame.BackgroundTile:GetTexture(), "REPEAT", "REPEAT")
            end
        end
        if srcFrame.Bg then
            local bg = insetFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
            bg:SetAllPoints(insetFrame)
            local atlas = srcFrame.Bg:GetAtlas()
            if atlas then
                bg:SetAtlas(atlas, true)
            else
                bg:SetTexture(srcFrame.Bg:GetTexture())
            end
        end
    end
end

--- Positions the header bar (`NavBar` + `SearchBox`) and inner `ContentCanvas`.
--- @param frame Frame
function MainFrame:SetupHeaderAndCanvas(frame)
    frame.HeaderBar = ns.UI.HeaderBar:Create(frame)

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", Constants.WINDOW.INSET_LEFT_OFFSET, Constants.WINDOW.INSET_TOP_OFFSET)
        frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Constants.WINDOW.INSET_RIGHT_OFFSET, Constants.WINDOW.INSET_BOTTOM_OFFSET)
        applyAppearancesStoneBackground(frame.Inset)
    end

    local canvas = CreateFrame("Frame", nil, frame.Inset or frame)
    if frame.Inset then
        canvas:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -4)
        canvas:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -4, 4)
        canvas:SetFrameLevel(frame.Inset:GetFrameLevel() + 10)
    else
        canvas:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, Constants.WINDOW.INSET_TOP_OFFSET - 4)
        canvas:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, Constants.WINDOW.INSET_BOTTOM_OFFSET + 4)
    end

    frame.ContentCanvas = canvas
end

--- Initializes the Home catalog view on parentCanvas.
--- @param parentCanvas Frame
function MainFrame:SetupEmptyState(parentCanvas)
    self.frame.EmptyState = ns.UI.HomeView:Create(parentCanvas)
end

--- @param isVisible boolean
function MainFrame:SetEmptyStateVisible(isVisible)
    if not self.frame or not self.frame.EmptyState then
        return
    end
    if isVisible and ns.UI.HomeView then
        ns.UI.HomeView:Refresh()
    end
    self.frame.EmptyState:SetShown(isVisible)
end

--- @return Frame|nil
function MainFrame:GetHeaderBar()
    return self.frame and self.frame.HeaderBar
end

--- @return Frame|nil
function MainFrame:GetContentCanvas()
    return self.frame and self.frame.ContentCanvas
end

--- Refreshes tabs and the Home view whenever plugins or their sort order change.
function MainFrame:OnPluginsChanged()
    if not self.frame then
        return
    end
    local plugins = ns.PluginRegistry:GetOrderedPlugins()
    ns.UI.TabBar:RefreshTabs(plugins)

    if ns.UI.HomeView then
        ns.UI.HomeView:Refresh()
    end

    local activePlugin = ns.PluginRegistry:GetActivePlugin()
    self:SetEmptyStateVisible(activePlugin == nil)
    if activePlugin then
        self:SelectTabByPluginId(activePlugin.id)
    else
        self:ClearTabSelection()
    end
end

--- @param pluginId string
function MainFrame:SelectTabByPluginId(pluginId)
    ns.UI.TabBar:SelectPlugin(pluginId)
end

--- Clears bottom tab selection when viewing the base `Home` screen.
function MainFrame:ClearTabSelection()
    ns.UI.TabBar:ClearSelection()
end

function MainFrame:Show()
    if not self.frame then
        self:Init()
    end
    self.frame:Show()
end

function MainFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MainFrame:Toggle()
    if not self.frame then
        self:Init()
    end
    self.frame:SetShown(not self.frame:IsShown())
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.MainFrame = MainFrame

