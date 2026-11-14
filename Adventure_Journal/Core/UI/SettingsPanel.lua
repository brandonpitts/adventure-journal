-- ============================================================================
-- Journal_Base - UI/SettingsPanel.lua
-- Interface Options settings panel for Journal configuration.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local math = math
local pcall = pcall
local tostring = tostring
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local ReloadUI = ReloadUI or (C_UI and C_UI.Reload)
local C_AddOns = C_AddOns
local Settings = Settings
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
local Constants = ns.Constants

local PLUGIN_ROW_HEIGHT = 38
local PLUGIN_ROW_GAP = 6

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Applies background and border textures to a plugin row frame.
local function stylePluginRow(row)
    local white = Constants.ASSETS.WHITE_8X8

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    bg:SetTexture(white)
    bg:SetVertexColor(0.12, 0.11, 0.09, 0.88)
    row.bg = bg

    local bTop = row:CreateTexture(nil, "BORDER")
    bTop:SetHeight(1)
    bTop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    bTop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    bTop:SetTexture(white)
    bTop:SetVertexColor(0.45, 0.36, 0.21, 0.78)
    row.bTop = bTop

    local bBottom = row:CreateTexture(nil, "BORDER")
    bBottom:SetHeight(1)
    bBottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    bBottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    bBottom:SetTexture(white)
    bBottom:SetVertexColor(0.26, 0.21, 0.13, 0.78)
    row.bBottom = bBottom

    local bLeft = row:CreateTexture(nil, "BORDER")
    bLeft:SetWidth(1)
    bLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
    bLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
    bLeft:SetTexture(white)
    bLeft:SetVertexColor(0.36, 0.29, 0.17, 0.78)

    local bRight = row:CreateTexture(nil, "BORDER")
    bRight:SetWidth(1)
    bRight:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -1)
    bRight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
    bRight:SetTexture(white)
    bRight:SetVertexColor(0.36, 0.29, 0.17, 0.78)
end

--- Builds a crisp Default Landing Tab icon button (24x24) to the left of the plugin icon.
--- Uses Blizzard's favorite gold star icon so players can designate which tab opens
--- automatically whenever the Journal window is opened.
local function createDefaultLandingButton(parentRow)
    local white = Constants.ASSETS.WHITE_8X8
    local btn = CreateFrame("Button", nil, parentRow)
    btn:SetSize(24, 24)

    -- Button socket background & border
    local socketBg = btn:CreateTexture(nil, "BACKGROUND")
    socketBg:SetAllPoints(btn)
    socketBg:SetTexture(white)
    socketBg:SetVertexColor(0.08, 0.07, 0.06, 0.90)
    btn.socketBg = socketBg

    local socketBorder = btn:CreateTexture(nil, "BORDER")
    socketBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    socketBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    socketBorder:SetTexture(white)
    socketBorder:SetVertexColor(0.35, 0.28, 0.16, 0.45)
    btn.socketBorder = socketBorder

    local star = btn:CreateTexture(nil, "ARTWORK")
    star:SetSize(16, 16)
    star:SetPoint("CENTER", btn, "CENTER", 0, 0)

    local hasAtlas = false
    if star.SetAtlas then
        for _, atlasName in ipairs({ "PetJournal-FavoritesIcon", "common-icon-star", "auctionhouse-icon-favorite" }) do
            local ok = pcall(star.SetAtlas, star, atlasName, false)
            if ok and star:GetAtlas() then
                hasAtlas = true
                break
            end
        end
    end

    if not hasAtlas then
        star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        star:SetTexCoord(0, 0.25, 0, 0.5)
    end
    btn.star = star

    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(btn)
    hover:SetTexture(white)
    hover:SetVertexColor(1.0, 0.85, 0.35, 0.18)

    return btn
end

--- Updates the visual highlight state of the Default Landing Tab star button.
local function setDefaultLandingButtonState(btn, isDefault, isEnabled)
    if isDefault then
        btn.socketBg:SetVertexColor(0.28, 0.20, 0.08, 0.96)
        btn.socketBorder:SetVertexColor(0.95, 0.78, 0.25, 0.85)
        if btn.star.SetDesaturated then
            btn.star:SetDesaturated(false)
        end
        btn.star:SetVertexColor(1.0, 0.85, 0.15, 1.0)
    elseif isEnabled then
        btn.socketBg:SetVertexColor(0.09, 0.08, 0.07, 0.85)
        btn.socketBorder:SetVertexColor(0.32, 0.26, 0.16, 0.45)
        if btn.star.SetDesaturated then
            btn.star:SetDesaturated(true)
        end
        btn.star:SetVertexColor(0.50, 0.46, 0.38, 0.75)
    else
        btn.socketBg:SetVertexColor(0.07, 0.06, 0.06, 0.60)
        btn.socketBorder:SetVertexColor(0.22, 0.19, 0.14, 0.30)
        if btn.star.SetDesaturated then
            btn.star:SetDesaturated(true)
        end
        btn.star:SetVertexColor(0.30, 0.28, 0.26, 0.40)
    end
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local SettingsPanel = {
    panel = nil,
    category = nil,
    pluginRows = {},
    draggingPluginId = nil,
}

--- Creates and registers the Journal Settings panel in WoW's AddOn Options.
function SettingsPanel:Init()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", nil)
    panel.name = Constants.SETTINGS.CATEGORY_NAME
    self.panel = panel
    self.pluginRows = {}

    self:CreateHeader(panel)

    -- Scrollable body container for settings content
    local scrollFrame = CreateFrame("ScrollFrame", "AdventureJournalSettingsScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -66)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 4)
    scrollFrame.scrollBarHideable = true
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(sf, delta)
        local cur = sf:GetVerticalScroll()
        local maxScroll = sf:GetVerticalScrollRange()
        local step = 30
        local newScroll = cur - (delta * step)
        if newScroll < 0 then
            newScroll = 0
        elseif newScroll > maxScroll then
            newScroll = maxScroll
        end
        sf:SetVerticalScroll(newScroll)
    end)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(580, 660)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    self:CreateAlertBanner(scrollChild)
    self:CreateKeybindRow(scrollChild)
    self:CreateMinimapToggleRow(scrollChild)
    self:CreateCompareItemsToggleRow(scrollChild)
    self:CreateInstalledPluginsSection(scrollChild)
    self:CreateDungeonModuleSection(scrollChild)
    self:CreateMapIconsModuleSection(scrollChild)

    -- Populate immediately and on OnShow so the first view in 16001 is never blank.
    self:Refresh()
    panel:SetScript("OnShow", function()
        self:Refresh()
    end)

    self:RegisterWithBlizzardSettings(panel)
end

--- Builds the title, version badge, top-right "Reload UI" button, and horizontal divider.
--- @param panel Frame
function SettingsPanel:CreateHeader(panel)
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
    icon:SetTexture(Constants.ASSETS.FALLBACK_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
    title:SetText(Constants.TITLE)

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Version " .. Constants.VERSION .. " — Base Shell & General Settings")
    subtitle:SetTextColor(0.75, 0.72, 0.66)

    local reloadBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reloadBtn:SetSize(110, 24)
    reloadBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -22)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if ReloadUI then
            ReloadUI()
        end
    end)
    self.ReloadButton = reloadBtn

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -64)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -64)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.68, 0.52, 0.20, 0.45)
    self.HeaderDivider = divider
end

--- Builds the alert banner for notifying about out-of-date or mismatched AtlasLoot versions.
--- @param panel Frame
function SettingsPanel:CreateAlertBanner(panel)
    local banner = CreateFrame("Frame", nil, panel)
    banner:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -8)
    banner:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -8)
    banner:SetHeight(28)
    banner:Hide()

    local bg = banner:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(banner)
    bg:SetTexture(Constants.ASSETS.WHITE_8X8)
    bg:SetVertexColor(0.22, 0.12, 0.04, 0.88)

    local borderTop = banner:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 0, 0)
    borderTop:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderTop:SetVertexColor(0.85, 0.55, 0.15, 0.80)

    local borderBottom = banner:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderBottom:SetVertexColor(0.85, 0.55, 0.15, 0.80)

    local icon = banner:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", banner, "LEFT", 8, 0)
    icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")

    local text = banner:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", banner, "RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    banner.text = text

    self.AlertBanner = banner
end

--- Builds the interactive "Toggle Journal Keybind" row using `ns.UI.KeybindButton`.
--- @param panel Frame
function SettingsPanel:CreateKeybindRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -16)
    label:SetText("Toggle Journal Keybind")
    self.KeybindLabel = label

    local button = ns.UI.KeybindButton:Create(panel)
    button:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    button:SetPoint("CENTER", label, "CENTER", 0, 0)
    self.KeybindButton = button
end

--- Builds the "Show Minimap Icon" checkbox row.
--- @param panel Frame
function SettingsPanel:CreateMinimapToggleRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -44)
    label:SetText("Show Minimap Icon")
    self.MinimapLabel = label

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)

    checkbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Minimap Icon", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, the circular Journal launcher icon is displayed on the Minimap perimeter.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    checkbox:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    checkbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        ns.Database:SetMinimapShown(isChecked)
        ns.UI.MinimapButton:RefreshVisibility()
    end)

    self.ShowMinimapCheckbox = checkbox
    self.HideMinimapCheckbox = checkbox
end

--- Builds the "Automatically compare items on mouseover" checkbox row.
--- @param panel Frame
function SettingsPanel:CreateCompareItemsToggleRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -72)
    label:SetText("Automatically compare items on mouseover")
    self.CompareItemsLabel = label

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)

    checkbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Automatically Compare Items", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, comparison tooltips for your equipped gear are displayed automatically whenever you hover an equippable item.\n\nWhen disabled, comparison tooltips only appear while holding Shift.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    checkbox:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    checkbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        if SetCVar then
            SetCVar("alwaysCompareItems", isChecked and "1" or "0")
        end
    end)

    self.CompareItemsCheckbox = checkbox
end

--- Builds the "Installed Modules" section header, instructions, and drag-and-drop list container.
--- @param panel Frame
function SettingsPanel:CreateInstalledPluginsSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -116)
    sectionHeader:SetText("Installed Modules")
    self.PluginSectionHeader = sectionHeader

    local subNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subNote:SetPoint("LEFT", sectionHeader, "RIGHT", 12, 0)
    subNote:SetText("Click the star to set a default landing tab when opening the Journal, or drag rows to reorder tabs.")
    subNote:SetTextColor(0.68, 0.64, 0.56)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.68, 0.52, 0.20, 0.35)

    local listContainer = CreateFrame("Frame", nil, panel)
    listContainer:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -12)
    listContainer:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    listContainer:SetHeight(220)
    self.PluginListContainer = listContainer

    local emptyText = listContainer:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 6, -8)
    emptyText:SetText("No Journal modules are currently installed.")
    self.NoPluginsText = emptyText
end

--- Builds the "Dungeon Module" section with a clean section header, divider,
--- and module-specific settings (such as toggling boss levels on list buttons).
--- @param panel Frame
function SettingsPanel:CreateDungeonModuleSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.PluginListContainer, "BOTTOMLEFT", 0, -20)
    sectionHeader:SetText("Dungeon Module")

    local subNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subNote:SetPoint("LEFT", sectionHeader, "RIGHT", 12, 0)
    subNote:SetText("Options and display preferences for the Dungeons tab.")
    subNote:SetTextColor(0.68, 0.64, 0.56)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.68, 0.52, 0.20, 0.35)

    -- Row 1: "Sort Dungeon Grid By" (dropdown: "Level Bracket (Default)", "Alphabetical (A-Z)")
    local sortLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sortLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 6, -16)
    sortLabel:SetText("Sort Dungeon Grid By")
    self.DungeonSortLabel = sortLabel

    local sortDropdown = CreateFrame("Frame", "AdventureJournalDungeonSortDropdown", panel, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    sortDropdown:SetPoint("CENTER", sortLabel, "CENTER", 0, -2)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(sortDropdown, 140)
    end

    local DUNGEON_SORT_OPTIONS = {
        { text = "Level Bracket (Default)", value = "level" },
        { text = "Alphabetical (A-Z)", value = "alphabetical" },
    }

    local function initializeSortDropdown(selfDD, level)
        local rawVal = ns.Database and ns.Database.GetDungeonSetting and ns.Database:GetDungeonSetting("dungeonGridSort", "level")
        local selectedValue = (rawVal == "alphabetical" or rawVal == "name") and "alphabetical" or "level"

        for _, opt in ipairs(DUNGEON_SORT_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
            info.text = opt.text
            info.value = opt.value
            info.func = function(btn)
                if UIDropDownMenu_SetSelectedValue then
                    UIDropDownMenu_SetSelectedValue(sortDropdown, btn.value)
                end
                if UIDropDownMenu_SetText then
                    UIDropDownMenu_SetText(sortDropdown, btn:GetText())
                end
                if ns.Database and ns.Database.SetDungeonSetting then
                    ns.Database:SetDungeonSetting("dungeonGridSort", btn.value)
                end
                if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
                    _G.JournalBase:OnDungeonSettingChanged("dungeonGridSort", btn.value)
                end
            end
            info.checked = (opt.value == selectedValue)
            if UIDropDownMenu_AddButton then
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(sortDropdown, initializeSortDropdown)
    end

    sortDropdown:SetScript("OnEnter", function(dd)
        if GameTooltip then
            GameTooltip:SetOwner(dd, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Sort Dungeon Grid By", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("Controls how dungeon cards are ordered on the Dungeons tab grid:\n\n• Level Bracket: Sorted by recommended level range matching official Blizzard Looking For Group brackets (Default).\n• Alphabetical (A-Z): Sorted alphabetically by dungeon name.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    sortDropdown:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.DungeonSortDropdown = sortDropdown

    -- Row 2: "Show Levels on Dungeon Grid and Boss List Buttons"
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", sortLabel, "BOTTOMLEFT", 0, -22)
    label:SetText("Show Levels on Dungeon Grid and Boss List Buttons")

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)

    checkbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Levels on Dungeon Grid and Boss List Buttons", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, recommended levels are displayed on dungeon grid cards and boss list buttons. When disabled, levels are hidden on tiles and list buttons, while remaining visible on the dungeon heading and selected boss overview.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    checkbox:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    checkbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        ns.Database:SetDungeonSetting("showBossLevel", isChecked)

        if self.UpdateDifficultyDependency then
            self.UpdateDifficultyDependency()
        end

        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showBossLevel", isChecked)
        end
    end)

    self.BossLevelCheckbox = checkbox
    self.BossLevelLabel = label

    -- Row: "Show Dungeon Difficulty Color" (nested under Boss Levels)
    local diffLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diffLabel:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 16, -14)
    diffLabel:SetText("Show Dungeon Difficulty Color")
    self.DifficultyColorLabel = diffLabel

    local diffCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    diffCheckbox:SetSize(28, 28)
    diffCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    diffCheckbox:SetPoint("CENTER", diffLabel, "CENTER", 0, 0)

    diffCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Dungeon Difficulty Color", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, boss levels are dynamically colored green, yellow, orange, or red based on your character's current level. When disabled, levels use default neutral colors.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    diffCheckbox:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    diffCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        ns.Database:SetDungeonSetting("showBossDifficultyColor", isChecked)

        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showBossDifficultyColor", isChecked)
        end
    end)

    self.DifficultyColorCheckbox = diffCheckbox

    local function updateDifficultyDependency()
        local isParentChecked = checkbox:GetChecked() and true or false
        if isParentChecked then
            diffCheckbox:Enable()
            diffLabel:SetFontObject("GameFontNormal")
            diffLabel:SetTextColor(1.0, 0.82, 0.0)
        else
            diffCheckbox:Disable()
            diffLabel:SetFontObject("GameFontDisable")
            diffLabel:SetTextColor(0.50, 0.50, 0.50)
        end
    end
    self.UpdateDifficultyDependency = updateDifficultyDependency

    -- Row: "Show Minor / Quest Monsters"
    local minorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minorLabel:SetPoint("TOPLEFT", diffLabel, "BOTTOMLEFT", -16, -14)
    minorLabel:SetText("Show Minor / Quest Monsters")

    local minorCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minorCheckbox:SetSize(28, 28)
    minorCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    minorCheckbox:SetPoint("CENTER", minorLabel, "CENTER", 0, 0)

    minorCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Minor / Quest Monsters", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, minor dungeon encounters and quest targets without dragon borders are shown in the left encounter list. When disabled, only dungeon bosses, rare spawns, and zone drops are displayed.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    minorCheckbox:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    minorCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        ns.Database:SetDungeonSetting("showMinorMonsters", isChecked)
        ns.Database:SetDungeonSetting("hideMinorMonsters", not isChecked)

        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showMinorMonsters", isChecked)
            _G.JournalBase:OnDungeonSettingChanged("hideMinorMonsters", not isChecked)
        end
    end)

    self.MinorMonstersCheckbox = minorCheckbox

    -- Row: "Show Event Bosses and Encounters" (dropdown: "Always", "Only during the Holidays", "Never")
    local eventLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    eventLabel:SetPoint("TOPLEFT", minorLabel, "BOTTOMLEFT", 0, -18)
    eventLabel:SetText("Show Event Bosses and Encounters")
    self.EventBossesLabel = eventLabel

    local eventDropdown = CreateFrame("Frame", "AdventureJournalEventBossesDropdown", panel, "UIDropDownMenuTemplate")
    eventDropdown:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    eventDropdown:SetPoint("CENTER", eventLabel, "CENTER", 0, -2)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(eventDropdown, 140)
    end

    local EVENT_BOSS_OPTIONS = {
        { text = "Only during the Holidays", value = "holiday" },
        { text = "Always", value = "always" },
        { text = "Never", value = "never" },
    }

    local function initializeEventDropdown(selfDD, level)
        local rawVal = ns.Database and ns.Database.GetDungeonSetting and ns.Database:GetDungeonSetting("showEventBosses", "holiday")
        local selectedValue = "holiday"
        if rawVal == "always" or rawVal == true then
            selectedValue = (rawVal == true and "holiday" or "always")
        elseif rawVal == "never" or rawVal == false then
            selectedValue = "never"
        elseif rawVal == "holiday" then
            selectedValue = "holiday"
        end

        for _, opt in ipairs(EVENT_BOSS_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
            info.text = opt.text
            info.value = opt.value
            info.func = function(btn)
                if UIDropDownMenu_SetSelectedValue then
                    UIDropDownMenu_SetSelectedValue(eventDropdown, btn.value)
                end
                if UIDropDownMenu_SetText then
                    UIDropDownMenu_SetText(eventDropdown, btn:GetText())
                end
                if ns.Database and ns.Database.SetDungeonSetting then
                    ns.Database:SetDungeonSetting("showEventBosses", btn.value)
                end
                if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
                    _G.JournalBase:OnDungeonSettingChanged("showEventBosses", btn.value)
                end
            end
            info.checked = (opt.value == selectedValue)
            if UIDropDownMenu_AddButton then
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(eventDropdown, initializeEventDropdown)
    end

    eventDropdown:SetScript("OnEnter", function(dd)
        if GameTooltip then
            GameTooltip:SetOwner(dd, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Event Bosses and Encounters", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("Controls how seasonal holiday encounters (such as Crown Chemical Co., Headless Horseman, and Coren Direbrew) appear in dungeon boss lists.\n\n• Only during the Holidays: Dynamically shows bosses only while their seasonal holiday is active (Recommended).\n• Always: Always shows event bosses regardless of calendar season.\n• Never: Completely hides event bosses.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    eventDropdown:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.EventBossesDropdown = eventDropdown

    -- Row: "Show Dungeon Set Challenges (Tier 0.5)"
    local challengeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    challengeLabel:SetPoint("TOPLEFT", eventLabel, "BOTTOMLEFT", 0, -28)
    challengeLabel:SetText("Show Dungeon Set Challenges (Tier 0.5)")

    local challengeCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    challengeCheckbox:SetSize(28, 28)
    challengeCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    challengeCheckbox:SetPoint("CENTER", challengeLabel, "CENTER", 0, 0)

    challengeCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Dungeon Set Challenges (Tier 0.5)", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, summonable Dungeon Set 2 (Tier 0.5) challenge bosses (such as Lord Valthalak, Mor Grayhoof, Jarien and Sothos, Kormok, Theldren, and Isalien) are displayed in a dedicated challenge section.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    challengeCheckbox:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    challengeCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        ns.Database:SetDungeonSetting("showDungeonSetChallenges", isChecked)

        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showDungeonSetChallenges", isChecked)
        end
    end)

    self.ChallengeBossesCheckbox = challengeCheckbox
    self.ChallengeBossesLabel = challengeLabel
end

--- Builds the "Map Icons Module" section with options for world map markers.
--- @param panel Frame
function SettingsPanel:CreateMapIconsModuleSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.ChallengeBossesLabel, "BOTTOMLEFT", -6, -26)
    sectionHeader:SetText("Map Icons Module")

    local subNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subNote:SetPoint("LEFT", sectionHeader, "RIGHT", 12, 0)
    subNote:SetText("Options and display preferences for world map icons.")
    subNote:SetTextColor(0.68, 0.64, 0.56)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.68, 0.52, 0.20, 0.35)

    -- Row 1: "Dungeon icons on world map" (with blue swirl portal icon and dropdown)
    local mapIconsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapIconsLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 6, -14)
    mapIconsLabel:SetText("Dungeon icons on world map")
    self.WorldMapIconsLabel = mapIconsLabel

    local dungeonSwirl = panel:CreateTexture(nil, "ARTWORK")
    dungeonSwirl:SetSize(18, 18)
    dungeonSwirl:SetPoint("LEFT", mapIconsLabel, "RIGHT", 8, 0)
    dungeonSwirl:SetAtlas("Dungeon")
    self.DungeonSwirlIcon = dungeonSwirl

    local dropdown = CreateFrame("Frame", "AdventureJournalWorldMapIconsDropdown", panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    dropdown:SetPoint("CENTER", mapIconsLabel, "CENTER", 0, -2)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, 140)
    end

    local MAP_ICON_OPTIONS = {
        { text = "After minimum level", value = "min_level" },
        { text = "Only during level bracket", value = "bracket" },
        { text = "Always show", value = "always" },
        { text = "Disabled", value = "disabled" },
    }

    local function initializeDropdown(selfDD, level)
        local selectedValue = (ns.Database and ns.Database.GetMapIconsSetting and ns.Database:GetMapIconsSetting("worldMapDungeonIcons", "min_level"))
            or (ns.Database and ns.Database.GetDungeonSetting and ns.Database:GetDungeonSetting("worldMapDungeonIcons", "min_level"))
            or "min_level"
        for _, opt in ipairs(MAP_ICON_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
            info.text = opt.text
            info.value = opt.value
            info.func = function(btn)
                if UIDropDownMenu_SetSelectedValue then
                    UIDropDownMenu_SetSelectedValue(dropdown, btn.value)
                end
                if UIDropDownMenu_SetText then
                    UIDropDownMenu_SetText(dropdown, btn:GetText())
                end
                if ns.Database and ns.Database.SetMapIconsSetting then
                    ns.Database:SetMapIconsSetting("worldMapDungeonIcons", btn.value)
                elseif ns.Database and ns.Database.SetDungeonSetting then
                    ns.Database:SetDungeonSetting("worldMapDungeonIcons", btn.value)
                end
                if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
                    _G.JournalBase:OnDungeonSettingChanged("worldMapDungeonIcons", btn.value)
                end
                if ns.MapPinProvider and ns.MapPinProvider.Refresh then
                    ns.MapPinProvider:Refresh()
                end
            end
            info.checked = (opt.value == selectedValue)
            if UIDropDownMenu_AddButton then
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(dropdown, initializeDropdown)
    end

    dropdown:SetScript("OnEnter", function(dd)
        if GameTooltip then
            GameTooltip:SetOwner(dd, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Dungeon Icons on World Map", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("Controls when dungeon entrance icons (blue swirl portals) appear on the World Map.\n\n• After minimum level: Visible once your character reaches the dungeon's minimum level (Default).\n• Only during level bracket: Only visible while within the recommended level range.\n• Always show: Always visible regardless of your character's level.\n• Disabled: Hides all dungeon entrance markers.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    dropdown:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.WorldMapIconsDropdown = dropdown

    -- Row 2: "Raid icons on world map" (with green swirl portal icon, "(Under Construction)" tag, and disabled dropdown)
    local raidIconsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidIconsLabel:SetPoint("TOPLEFT", mapIconsLabel, "BOTTOMLEFT", 0, -28)
    raidIconsLabel:SetText("Raid icons on world map")
    raidIconsLabel:SetTextColor(0.60, 0.58, 0.54)
    self.WorldMapRaidIconsLabel = raidIconsLabel

    local raidSwirl = panel:CreateTexture(nil, "ARTWORK")
    raidSwirl:SetSize(18, 18)
    raidSwirl:SetPoint("LEFT", raidIconsLabel, "RIGHT", 8, 0)
    raidSwirl:SetAtlas("Raid")
    self.RaidSwirlIcon = raidSwirl

    local raidTag = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    raidTag:SetPoint("LEFT", raidSwirl, "RIGHT", 8, 0)
    raidTag:SetText("|cff808080(Under Construction)|r")
    self.WorldMapRaidTag = raidTag

    local raidDropdown = CreateFrame("Frame", "AdventureJournalWorldMapRaidIconsDropdown", panel, "UIDropDownMenuTemplate")
    raidDropdown:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    raidDropdown:SetPoint("CENTER", raidIconsLabel, "CENTER", 0, -2)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(raidDropdown, 140)
    end

    local function initializeRaidDropdown(selfDD, level)
        local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
        info.text = "Disabled"
        info.value = "disabled"
        info.checked = true
        info.disabled = true
        if UIDropDownMenu_AddButton then
            UIDropDownMenu_AddButton(info, level)
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(raidDropdown, initializeRaidDropdown)
    end
    if UIDropDownMenu_DisableDropDown then
        UIDropDownMenu_DisableDropDown(raidDropdown)
    end
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(raidDropdown, "Disabled")
    end

    raidDropdown:SetScript("OnEnter", function(dd)
        if GameTooltip then
            GameTooltip:SetOwner(dd, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Raid Icons on World Map (Under Construction)", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("World and zone map indicators for raid entrances (green swirl portals) will be available when the Raids module is released.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
    end)
    raidDropdown:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.WorldMapRaidIconsDropdown = raidDropdown
end

--- Positions `row` at slot `index` within `self.PluginListContainer`.
local function anchorRowAtSlot(container, row, index)
    local yOffset = -((index - 1) * (PLUGIN_ROW_HEIGHT + PLUGIN_ROW_GAP))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOffset)
end

--- Computes which 1-based slot index the mouse cursor is hovering over inside `PluginListContainer`.
function SettingsPanel:GetTargetSlotFromCursor(totalRows)
    if not self.PluginListContainer or totalRows <= 1 then
        return 1
    end
    local _, cursorY = GetCursorPosition()
    local scale = self.PluginListContainer:GetEffectiveScale() or 1
    cursorY = cursorY / scale

    local topY = self.PluginListContainer:GetTop() or cursorY
    local relativeY = topY - cursorY
    local stride = PLUGIN_ROW_HEIGHT + PLUGIN_ROW_GAP
    local slot = math.floor(relativeY / stride) + 1
    if slot < 1 then
        slot = 1
    elseif slot > totalRows then
        slot = totalRows
    end
    return slot
end

--- Acquires or creates a pooled row widget for a plugin in Settings, supporting:
---   * Left house icon toggle (`Set as Home`)
---   * Drag-and-drop row reordering
---   * Version & status inspection + Enable/Disable button
--- @param index number
--- @return Frame
function SettingsPanel:AcquirePluginRow(index)
    local row = self.pluginRows[index]
    if row then
        row:Show()
        return row
    end

    row = CreateFrame("Frame", nil, self.PluginListContainer)
    row:SetHeight(PLUGIN_ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    stylePluginRow(row)

    -- 1. Drag Grip Dots on the far left (`6px`)
    local grip = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    grip:SetPoint("LEFT", row, "LEFT", 8, 0)
    grip:SetText("::")
    row.grip = grip

    -- 2. Default Landing Tab Button (star icon to the left of the plugin icon)
    local defaultBtn = createDefaultLandingButton(row)
    defaultBtn:SetPoint("LEFT", row, "LEFT", 24, 0)
    row.defaultBtn = defaultBtn

    defaultBtn:SetScript("OnEnter", function(btn)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        local isCurrentDefault = (ns.Database:GetDefaultLandingPluginId() == row.pluginId)
        if isCurrentDefault then
            GameTooltip:AddLine("Default Landing Tab (Active)", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("The Journal opens directly to this tab whenever the window is opened.", 0.9, 0.9, 0.9, true)
            GameTooltip:AddLine("Click to clear (will remember last-viewed tab instead).", 0.65, 0.65, 0.65, true)
        else
            GameTooltip:AddLine("Set as Default Landing Tab", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("Click to make the Journal open directly to " .. tostring(row.pluginTitle or "this tab") .. " whenever the window is opened.", 0.9, 0.9, 0.9, true)
        end
        GameTooltip:Show()
    end)

    defaultBtn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    defaultBtn:SetScript("OnClick", function()
        if not row.pluginId or not row.isInstalled or row.isDisabled then
            return
        end
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        ns.PluginRegistry:ToggleDefaultLandingPlugin(row.pluginId)
    end)

    -- 3. Plugin Icon (`24x24`, to the right of the Default Landing button)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", defaultBtn, "RIGHT", 8, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    -- 4. Plugin Title, Version, Status, and Enable/Disable Button
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    row.nameText = nameText

    local versionText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    versionText:SetPoint("LEFT", nameText, "RIGHT", 10, 0)
    row.versionText = versionText

    local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("RIGHT", row, "RIGHT", -106, 0)
    row.statusText = statusText

    local toggleBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    toggleBtn:SetSize(84, 22)
    toggleBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.toggleBtn = toggleBtn

    toggleBtn:SetScript("OnClick", function(btn)
        if not row.pluginId or not row.isInstalled then
            return
        end
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        local currentlyDisabled = ns.Database:IsPluginDisabled(row.pluginId)
        local shouldEnable = (not row.isLoaded) or currentlyDisabled
        ns.PluginRegistry:SetPluginEnabled(row.pluginId, shouldEnable)

        if row.addonName and row.addonName ~= "Journal_Base" then
            if shouldEnable then
                if C_AddOns and C_AddOns.EnableAddOn then
                    pcall(C_AddOns.EnableAddOn, row.addonName)
                elseif _G.EnableAddOn then
                    pcall(_G.EnableAddOn, row.addonName)
                end

                if not row.isLoaded then
                    if C_AddOns and C_AddOns.LoadAddOn then
                        pcall(C_AddOns.LoadAddOn, row.addonName)
                    elseif _G.UIParentLoadAddOn then
                        pcall(_G.UIParentLoadAddOn, row.addonName)
                    elseif _G.LoadAddOn then
                        pcall(_G.LoadAddOn, row.addonName)
                    end
                end
            else
                if C_AddOns and C_AddOns.DisableAddOn then
                    pcall(C_AddOns.DisableAddOn, row.addonName)
                elseif _G.DisableAddOn then
                    pcall(_G.DisableAddOn, row.addonName)
                end
            end
        end

        if row.pluginId == "map_icons" and ns.MapPinProvider then
            if shouldEnable then
                ns.MapPinProvider:Refresh()
            else
                ns.MapPinProvider:ReleaseAllPins()
            end
        end

        self:RefreshPluginRows()
    end)

    -- 5. Click-and-Drag Row Reordering Scripts
    row:SetScript("OnDragStart", function(draggedRow)
        if not draggedRow.pluginId or draggedRow.pluginId == "home" or draggedRow.isUtility then
            return -- Home and Utility modules cannot be dragged
        end
        self.draggingPluginId = draggedRow.pluginId
        draggedRow:SetFrameLevel((self.PluginListContainer:GetFrameLevel() or 2) + 10)
        draggedRow.bg:SetVertexColor(0.24, 0.19, 0.11, 0.96)
        draggedRow.bTop:SetVertexColor(0.95, 0.78, 0.25, 1.0)
        draggedRow.bBottom:SetVertexColor(0.95, 0.78, 0.25, 1.0)

        draggedRow:SetScript("OnUpdate", function()
            local catalog = ns.PluginRegistry:GetCatalogPlugins()
            local maxNonUtilitySlot = 1
            for i, entry in ipairs(catalog) do
                if not entry.isUtility then
                    maxNonUtilitySlot = i
                end
            end
            local rawSlot = self:GetTargetSlotFromCursor(#catalog)
            local targetSlot = math.max(2, math.min(maxNonUtilitySlot, rawSlot))
            if targetSlot ~= draggedRow.slotIndex then
                ns.PluginRegistry:MovePluginToIndex(draggedRow.pluginId, targetSlot)
            end
        end)
    end)

    row:SetScript("OnDragStop", function(draggedRow)
        draggedRow:SetScript("OnUpdate", nil)
        self.draggingPluginId = nil
        draggedRow:SetFrameLevel((self.PluginListContainer:GetFrameLevel() or 2) + 1)
        self:RefreshPluginRows()
    end)

    self.pluginRows[index] = row
    return row
end

--- Refreshes the list of plugins, their House icon state, version numbers, and order.
function SettingsPanel:RefreshPluginRows()
    if not self.PluginListContainer then
        return
    end

    for _, row in ipairs(self.pluginRows) do
        row:Hide()
    end

    local catalog = ns.PluginRegistry:GetCatalogPlugins()
    if #catalog == 0 then
        if self.NoPluginsText then
            self.NoPluginsText:Show()
        end
        return
    end

    if self.NoPluginsText then
        self.NoPluginsText:Hide()
    end

    local totalRows = #catalog
    local containerHeight = math.max(60, totalRows * (PLUGIN_ROW_HEIGHT + PLUGIN_ROW_GAP) - PLUGIN_ROW_GAP)
    self.PluginListContainer:SetHeight(containerHeight)

    local defaultLandingId = ns.Database:GetDefaultLandingPluginId()

    for index, entry in ipairs(catalog) do
        local row = self:AcquirePluginRow(index)
        anchorRowAtSlot(self.PluginListContainer, row, index)

        local isInstalled = entry.isInstalled
        local isDisabled = not entry.isEnabled
        local isApiCompatible = (entry.apiVersion == Constants.PLUGIN_API_VERSION)
        local isDefault = (defaultLandingId == entry.id and entry.isEnabled)
        local isDragging = (self.draggingPluginId == entry.id)

        row.slotIndex = index
        row.pluginId = entry.id
        row.pluginTitle = entry.title
        row.addonName = entry.addonName
        row.isInstalled = isInstalled
        row.isLoaded = entry.isLoaded
        row.isDisabled = isDisabled
        row.isUtility = entry.isUtility

        if isDragging then
            row.bg:SetVertexColor(0.24, 0.19, 0.11, 0.96)
            row.bTop:SetVertexColor(0.95, 0.78, 0.25, 1.0)
            row.bBottom:SetVertexColor(0.95, 0.78, 0.25, 1.0)
        else
            row.bg:SetVertexColor(0.12, 0.11, 0.09, 0.88)
            row.bTop:SetVertexColor(0.45, 0.36, 0.21, 0.78)
            row.bBottom:SetVertexColor(0.26, 0.21, 0.13, 0.78)
        end

        -- "home" is locked in Slot 1; utility modules are pinned to the bottom:
        -- Neither can have drag handles or default landing tab stars.
        if entry.id == "home" or entry.isUtility then
            row.grip:Hide()
            row.defaultBtn:Hide()
        else
            row.grip:Show()
            row.defaultBtn:Show()
            setDefaultLandingButtonState(row.defaultBtn, isDefault, entry.isEnabled)
        end

        row.icon:SetTexture(entry.icon or Constants.ASSETS.FALLBACK_ICON)
        row.icon:SetDesaturated(not entry.isEnabled)
        row.nameText:SetText(entry.title .. " |cff808080(" .. tostring(entry.addonName) .. ")|r")
        row.versionText:SetText("v" .. tostring(entry.version))

        if not isInstalled then
            row.statusText:SetText("|cff808080Not Installed|r")
            row.toggleBtn:SetText("Missing")
            row.toggleBtn:Disable()
        elseif not isApiCompatible then
            row.statusText:SetText("|cffff4040Out of Date (API v" .. tostring(entry.apiVersion) .. ")|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText(isDisabled and "Enable" or "Disable")
        elseif not entry.isLoaded then
            row.statusText:SetText("|cff808080Disabled|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText("Enable")
        elseif isDisabled then
            row.statusText:SetText("|cff808080Disabled|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText("Enable")
        elseif isDefault then
            row.statusText:SetText("|cffffd100Default|r |cff40ff40(Enabled)|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText("Disable")
        else
            row.statusText:SetText("|cff40ff40Enabled|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText("Disable")
        end
    end
end

--- Refreshes all controls on the Settings panel.
function SettingsPanel:Refresh()
    local status
    local itemsMgr = _G.JournalDungeons and _G.JournalDungeons.ItemsManager
    if itemsMgr and itemsMgr.GetAtlasLootVersionStatus then
        status = itemsMgr:GetAtlasLootVersionStatus()
    else
        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local installed = getMeta and getMeta("AtlasLoot", "Version")
        if installed then
            status = {
                isInstalled = true,
                installedVersion = installed,
                syncedVersion = "v8.13.01",
                isMismatch = (installed ~= "v8.13.01"),
            }
        end
    end

    if status and status.isMismatch and self.AlertBanner then
        self.AlertBanner.text:SetText(string.format(
            "|cffffcc00AtlasLoot Version Mismatch:|r Installed v|cffffffff%s|r vs Synced v|cffffffff%s|r. New loot tables may be available. Run |cff80d0ffitem_sync|r to update.",
            status.installedVersion or "Unknown",
            status.syncedVersion or "Unknown"
        ))
        self.AlertBanner:Show()
        if self.KeybindLabel then self.KeybindLabel:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 24, -46) end
        if self.MinimapLabel then self.MinimapLabel:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 24, -74) end
        if self.CompareItemsLabel then self.CompareItemsLabel:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 24, -102) end
        if self.PluginSectionHeader then self.PluginSectionHeader:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 18, -146) end
    else
        if self.AlertBanner then self.AlertBanner:Hide() end
        if self.KeybindLabel then self.KeybindLabel:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 24, -16) end
        if self.MinimapLabel then self.MinimapLabel:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 24, -44) end
        if self.CompareItemsLabel then self.CompareItemsLabel:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 24, -72) end
        if self.PluginSectionHeader then self.PluginSectionHeader:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 18, -116) end
    end

    if self.KeybindButton then
        self.KeybindButton:Refresh()
    end
    if self.ShowMinimapCheckbox then
        self.ShowMinimapCheckbox:SetChecked(ns.Database:IsMinimapShown())
    elseif self.HideMinimapCheckbox then
        self.HideMinimapCheckbox:SetChecked(ns.Database:IsMinimapShown())
    end
    if self.CompareItemsCheckbox then
        local isAutoCompare = false
        if GetCVarBool then
            isAutoCompare = GetCVarBool("alwaysCompareItems")
        elseif GetCVar then
            isAutoCompare = (GetCVar("alwaysCompareItems") == "1")
        end
        self.CompareItemsCheckbox:SetChecked(isAutoCompare == true)
    end
    if self.BossLevelCheckbox then
        self.BossLevelCheckbox:SetChecked(ns.Database:GetDungeonSetting("showBossLevel", true) == true)
    end
    if self.DifficultyColorCheckbox then
        self.DifficultyColorCheckbox:SetChecked(ns.Database:GetDungeonSetting("showBossDifficultyColor", true) == true)
    end
    if self.UpdateDifficultyDependency then
        self.UpdateDifficultyDependency()
    end
    if self.MinorMonstersCheckbox then
        self.MinorMonstersCheckbox:SetChecked(ns.Database:GetDungeonSetting("showMinorMonsters", true) == true)
    end
    if self.EventBossesDropdown then
        local rawVal = ns.Database and ns.Database.GetDungeonSetting and ns.Database:GetDungeonSetting("showEventBosses", "holiday")
        local selectedValue = "holiday"
        local labelText = "Only during the Holidays"
        if rawVal == "always" or rawVal == true then
            selectedValue = (rawVal == true and "holiday" or "always")
            labelText = (rawVal == true and "Only during the Holidays" or "Always")
        elseif rawVal == "never" or rawVal == false then
            selectedValue = "never"
            labelText = "Never"
        end
        if UIDropDownMenu_SetSelectedValue then
            UIDropDownMenu_SetSelectedValue(self.EventBossesDropdown, selectedValue)
        end
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(self.EventBossesDropdown, labelText)
        end
    end
    if self.ChallengeBossesCheckbox then
        self.ChallengeBossesCheckbox:SetChecked(ns.Database:GetDungeonSetting("showDungeonSetChallenges", false) == true)
    end
    if self.DungeonSortDropdown then
        local rawVal = ns.Database and ns.Database.GetDungeonSetting and ns.Database:GetDungeonSetting("dungeonGridSort", "level")
        local selectedValue = (rawVal == "alphabetical" or rawVal == "name") and "alphabetical" or "level"
        local labelText = (selectedValue == "alphabetical") and "Alphabetical (A-Z)" or "Level Bracket (Default)"
        if UIDropDownMenu_SetSelectedValue then
            UIDropDownMenu_SetSelectedValue(self.DungeonSortDropdown, selectedValue)
        end
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(self.DungeonSortDropdown, labelText)
        end
    end
    if self.WorldMapIconsDropdown then
        local val = (ns.Database and ns.Database.GetMapIconsSetting and ns.Database:GetMapIconsSetting("worldMapDungeonIcons", "min_level"))
            or (ns.Database and ns.Database.GetDungeonSetting and ns.Database:GetDungeonSetting("worldMapDungeonIcons", "min_level"))
            or "min_level"
        if UIDropDownMenu_SetSelectedValue then
            UIDropDownMenu_SetSelectedValue(self.WorldMapIconsDropdown, val)
        end
        local labelText = "After minimum level"
        if val == "bracket" then
            labelText = "Only during level bracket"
        elseif val == "always" then
            labelText = "Always show"
        elseif val == "disabled" then
            labelText = "Disabled"
        end
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(self.WorldMapIconsDropdown, labelText)
        end
    end
    if self.WorldMapRaidIconsDropdown and UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(self.WorldMapRaidIconsDropdown, "Disabled")
    end
    self:RefreshPluginRows()

    local totalH = 780
    if status and status.isMismatch then
        totalH = 810
    end
    if self.scrollChild and self.scrollFrame then
        local w = self.scrollFrame:GetWidth()
        self.scrollChild:SetSize(w > 50 and w or 580, totalH)
        if self.scrollFrame.UpdateScrollChildRect then
            self.scrollFrame:UpdateScrollChildRect()
        end
    end
end

--- Registers `panel` with WoW's native `Settings` API.
--- @param panel Frame
function SettingsPanel:RegisterWithBlizzardSettings(panel)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, Constants.SETTINGS.CATEGORY_NAME)
        Settings.RegisterAddOnCategory(category)
        self.category = category
        return
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

--- Opens the native WoW Settings window directly to the Journal category.
function SettingsPanel:Open()
    if InCombatLockdown and InCombatLockdown() then
        if _G.JournalBase then
            _G.JournalBase:Print("Cannot open Journal Settings while in combat.")
        end
        return
    end

    if not self.panel then
        self:Init()
    end
    self:Refresh()

    if Settings and Settings.OpenToCategory and self.category then
        local numericCategoryId = self.category.GetID and self.category:GetID() or self.category.ID
        if numericCategoryId then
            Settings.OpenToCategory(numericCategoryId)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.SettingsPanel = SettingsPanel
