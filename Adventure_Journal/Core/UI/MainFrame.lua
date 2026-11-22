-- ============================================================================
-- Adventure Journal - Core/UI/MainFrame.lua
-- Top-level 800x496 native bronze ButtonFrameTemplate window and empty state.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local _G = _G
local ipairs = ipairs
local tinsert = tinsert
local pcall = pcall
local CreateFrame = CreateFrame
local IsShiftKeyDown = IsShiftKeyDown
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
    -- Counts the window's closes; pages that reset what they remember on each open compare against it
    closeCount = 0,
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
    frame:Hide()

    if ButtonFrameTemplate_HideButtonBar then
        pcall(ButtonFrameTemplate_HideButtonBar, frame)
    end

    setWindowTitle(frame, Constants.TITLE)
    self.frame = frame

    self:SetPortraitIcon(Constants.ASSETS.JOURNAL_PORTRAIT)
    self:RestorePosition()
    self:SetupCloseButton(frame)
    self:SetupDragAndLifecycle(frame)
    self:SetupHeaderAndCanvas(frame)
    self:SetupEmptyState(frame.ContentCanvas)
    self:SetupReloadPromptState(frame.ContentCanvas)

    ns.UI.TabBar:Init(frame)

    if UISpecialFrames then
        tinsert(UISpecialFrames, FRAME_NAME)
    end

    self:OnModulesChanged()
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

--- Restores the saved window anchor point from `Settings`, or centers the window.
function MainFrame:RestorePosition()
    if not self.frame then
        return
    end
    self.frame:ClearAllPoints()
    local saved = ns.Settings:GetWindowPoint()
    if saved and saved.point and saved.relativePoint and saved.x and saved.y then
        self.frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", Constants.WINDOW.DEFAULT_OFFSET_X, Constants.WINDOW.DEFAULT_OFFSET_Y)
    end
end

--- Configures and elevates the window close button so it is always visually crisp and clickable.
--- Matches the exact appearance and layout of CharacterFrameCloseButton (square red button, gold border, yellow 'X').
--- @param frame Frame
function MainFrame:SetupCloseButton(frame)
    local closeBtn = frame.CloseButton
        or (frame.TitleContainer and frame.TitleContainer.CloseButton)
        or _G[frame:GetName() .. "CloseButton"]
        or _G[FRAME_NAME .. "CloseButton"]

    if not closeBtn then
        local ok, btn = pcall(CreateFrame, "Button", FRAME_NAME .. "CloseButton", frame, "UIPanelCloseButton")
        if ok and btn then
            closeBtn = btn
        end
    end

    if not closeBtn then
        return
    end

    frame.CloseButton = closeBtn
    closeBtn:SetParent(frame)
    closeBtn:SetFrameStrata("DIALOG")
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 50)
    closeBtn:ClearAllPoints()

    -- Match exact anchoring and size from CharacterFrameCloseButton if available
    local charClose = _G.CharacterFrameCloseButton
    local anchored = false
    if charClose and charClose.GetPoint then
        local point, _, relPoint, x, y = charClose:GetPoint(1)
        if point and relPoint and x and y then
            closeBtn:SetPoint(point, frame, relPoint, x, y)
            anchored = true
        end
    end
    if not anchored then
        closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    end

    local btnW, btnH = 32, 32
    if charClose and charClose.GetSize then
        local cw, ch = charClose:GetSize()
        if cw and cw > 0 and ch and ch > 0 then
            btnW, btnH = cw, ch
        end
    end
    closeBtn:SetSize(btnW, btnH)
    closeBtn:SetAlpha(1.0)
    closeBtn:Show()

    -- Synchronize textures directly from CharacterFrameCloseButton to guarantee exact visual parity
    if charClose then
        local cNormal = charClose:GetNormalTexture()
        if cNormal then
            local atlas = cNormal.GetAtlas and cNormal:GetAtlas()
            if atlas and atlas ~= "" and closeBtn.SetNormalAtlas then
                closeBtn:SetNormalAtlas(atlas)
            elseif cNormal:GetTexture() then
                closeBtn:SetNormalTexture(cNormal:GetTexture())
            end
            if cNormal.GetTexCoord then
                local ulx, uly, llx, lly, urx, ury, lrx, lry = cNormal:GetTexCoord()
                local myNormal = closeBtn:GetNormalTexture()
                if myNormal and ulx and uly and lrx and lry then
                    myNormal:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
                end
            end
        end

        local cPushed = charClose:GetPushedTexture()
        if cPushed then
            local atlas = cPushed.GetAtlas and cPushed:GetAtlas()
            if atlas and atlas ~= "" and closeBtn.SetPushedAtlas then
                closeBtn:SetPushedAtlas(atlas)
            elseif cPushed:GetTexture() then
                closeBtn:SetPushedTexture(cPushed:GetTexture())
            end
        end

        local cHighlight = charClose:GetHighlightTexture()
        if cHighlight then
            local atlas = cHighlight.GetAtlas and cHighlight:GetAtlas()
            if atlas and atlas ~= "" and closeBtn.SetHighlightAtlas then
                closeBtn:SetHighlightAtlas(atlas)
            elseif cHighlight:GetTexture() then
                closeBtn:SetHighlightTexture(cHighlight:GetTexture(), "ADD")
            end
        end

        local cDisabled = charClose:GetDisabledTexture()
        if cDisabled then
            local atlas = cDisabled.GetAtlas and cDisabled:GetAtlas()
            if atlas and atlas ~= "" and closeBtn.SetDisabledAtlas then
                closeBtn:SetDisabledAtlas(atlas)
            elseif cDisabled:GetTexture() then
                closeBtn:SetDisabledTexture(cDisabled:GetTexture())
            end
        end
    end

    -- Hook click handler to always cleanly hide the main window with close sound
    closeBtn:SetScript("OnClick", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLOSE)
        end
        frame:Hide()
    end)
end

--- Configures drag-to-move persistence and open/close audio scripts.
--- Window is only movable via the top header bar (portrait to close button).
--- Honors the "Lock Adventure Journal Window" setting (Shift + drag to move when locked).
--- @param frame Frame
function MainFrame:SetupDragAndLifecycle(frame)
    local isMoving = false

    local function canMove()
        local isLocked = ns.Settings and ns.Settings.IsWindowLocked and ns.Settings:IsWindowLocked()
        if isLocked then
            return (IsShiftKeyDown and IsShiftKeyDown()) and true or false
        end
        return true
    end

    local function onDragStart()
        if canMove() then
            isMoving = true
            frame:StartMoving()
        end
    end

    local function onDragStop()
        if isMoving then
            isMoving = false
            frame:StopMovingOrSizing()
            local point, _, relativePoint, x, y = frame:GetPoint(1)
            if point and relativePoint and ns.Settings and ns.Settings.SetWindowPoint then
                ns.Settings:SetWindowPoint({
                    point = point,
                    relativePoint = relativePoint,
                    x = x,
                    y = y,
                })
            end
            if self.HeaderBar and self.HeaderBar.RefreshBreadcrumbs then
                self.HeaderBar:RefreshBreadcrumbs()
            end
        else
            frame:StopMovingOrSizing()
        end
    end

    -- Create dedicated drag header covering the top window header bar.
    -- Spans from the top-left (including portrait) to the top-right (comfortably before CloseButton).
    local dragHeader = CreateFrame("Frame", nil, frame)
    dragHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    dragHeader:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -40, Constants.WINDOW.HEADER_TOP_Y)
    dragHeader:SetFrameLevel(frame:GetFrameLevel() + 2)
    self.dragHeader = dragHeader

    local dragFrames = { dragHeader }
    if frame.TitleContainer then
        tinsert(dragFrames, frame.TitleContainer)
    end

    for _, df in ipairs(dragFrames) do
        df:EnableMouse(true)
        df:RegisterForDrag("LeftButton")
        df:SetScript("OnDragStart", onDragStart)
        df:SetScript("OnDragStop", onDragStop)
    end

    -- Defensively ensure the main frame body does not drag
    if frame.RegisterForDrag then
        frame:RegisterForDrag()
    end
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)

    frame:SetScript("OnShow", function()
        self:SetupCloseButton(frame)
        if frame.CloseButton then
            frame.CloseButton:SetFrameStrata("DIALOG")
            frame.CloseButton:SetFrameLevel(frame:GetFrameLevel() + 50)
            frame.CloseButton:Show()
        end
        if PlaySound then
            PlaySound(Constants.SOUNDS.OPEN)
        end

        -- A module may take focus (the player is inside its content); otherwise the first open of the
        -- session lands on the tab used last (saved across sessions) and later opens keep the tab and page
        -- left open.
        local isFirstOpen = not self.hasOpenedOnce
        self.hasOpenedOnce = true
        if ns.ModuleRegistry:FocusModuleForWindowShow() then
            return
        end
        if isFirstOpen or not ns.ModuleRegistry:GetActiveModule() then
            ns.ModuleRegistry:ActivateDefaultModule()
        end
    end)

    frame:SetScript("OnHide", function()
        self.closeCount = self.closeCount + 1
        if isMoving then
            isMoving = false
            frame:StopMovingOrSizing()
        end
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
        ns.UI.WindowBackground:Init(frame.Inset)
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

--- Initializes the empty state fallback on parentCanvas if no modules are enabled.
--- @param parentCanvas Frame
function MainFrame:SetupEmptyState(parentCanvas)
    local empty = CreateFrame("Frame", nil, parentCanvas)
    empty:SetAllPoints(parentCanvas)
    local text = empty:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    text:SetPoint("CENTER", empty, "CENTER", 0, 0)
    text:SetText("No Journal modules are currently active.")
    empty.text = text
    empty:Hide()
    self.frame.EmptyState = empty
end

--- @param isVisible boolean
function MainFrame:SetEmptyStateVisible(isVisible)
    if not self.frame or not self.frame.EmptyState then
        return
    end
    self.frame.EmptyState:SetShown(isVisible)
end

--- Initializes the reload-required prompt shown when a user enables an unloaded module tab before `/reload`.
--- @param parentCanvas Frame
function MainFrame:SetupReloadPromptState(parentCanvas)
    local prompt = CreateFrame("Frame", nil, parentCanvas)
    prompt:SetAllPoints(parentCanvas)

    local title = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", prompt, "CENTER", 0, 22)
    title:SetTextColor(1.0, 0.82, 0.0)
    title:SetText("Reload Required to Enable This")
    prompt.title = title

    local subText = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subText:SetPoint("TOP", title, "BOTTOM", 0, -10)
    subText:SetWidth(420)
    subText:SetJustifyH("CENTER")
    subText:SetTextColor(0.75, 0.75, 0.75)
    subText:SetText("This module's data is currently unloaded from memory.\nReload your UI to load it and activate this tab.")
    prompt.subText = subText

    local reloadBtn = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120, 26)
    reloadBtn:SetPoint("TOP", subText, "BOTTOM", 0, -18)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        local reload = _G.ReloadUI or (_G.C_UI and _G.C_UI.Reload)
        if reload then
            reload()
        end
    end)
    prompt.reloadBtn = reloadBtn

    prompt:Hide()
    self.frame.ReloadPromptState = prompt
end

--- Shows or hides the reload-required prompt on the active module page.
--- @param isVisible boolean
--- @param moduleTitle string|nil
function MainFrame:SetReloadPromptVisible(isVisible, moduleTitle)
    if not self.frame or not self.frame.ReloadPromptState then
        return
    end
    local prompt = self.frame.ReloadPromptState
    if isVisible then
        prompt.title:SetText("Reload Required to Enable This")
        if moduleTitle and moduleTitle ~= "" then
            prompt.subText:SetText(moduleTitle .. " is currently unloaded from memory.\nReload your UI (/rl) to load this module.")
        else
            prompt.subText:SetText("This module's data is currently unloaded from memory.\nReload your UI (/rl) to load this module.")
        end
    end
    prompt:SetShown(isVisible)
end

--- @return Frame|nil
function MainFrame:GetHeaderBar()
    return self.frame and self.frame.HeaderBar
end

--- @return Frame|nil
function MainFrame:GetContentCanvas()
    return self.frame and self.frame.ContentCanvas
end

--- Refreshes tabs whenever modules or their sort order change.
function MainFrame:OnModulesChanged()
    if not self.frame then
        return
    end
    local modules = ns.ModuleRegistry:GetOrderedModules()
    ns.UI.TabBar:RefreshTabs(modules)

    local activeModule = ns.ModuleRegistry:GetActiveModule()
    if activeModule then
        self:SetEmptyStateVisible(false)
        self:SetReloadPromptVisible(activeModule.isUnloaded == true, activeModule.title)
        self:SelectTabByModuleId(activeModule.id)
    else
        self:SetReloadPromptVisible(false)
        self:SetEmptyStateVisible(true)
        self:ClearTabSelection()
    end
end

--- @param moduleId string
function MainFrame:SelectTabByModuleId(moduleId)
    ns.UI.TabBar:SelectModule(moduleId)
end

--- Clears bottom tab selection when no module tab is active.
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

