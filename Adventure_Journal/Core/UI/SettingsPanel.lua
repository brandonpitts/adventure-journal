-- ============================================================================
-- Adventure Journal - Core/UI/SettingsPanel.lua
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
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local ReloadUI = ReloadUI or (C_UI and C_UI.Reload)
local C_AddOns = C_AddOns
local Settings = Settings
local InterfaceOptions_AddCategory = InterfaceOptions_AddCategory
local Constants = ns.Constants

local MODULE_ROW_HEIGHT = 38
local MODULE_ROW_GAP = 6
-- Distance between the tops of consecutive General rows
local GENERAL_ROW_SPACING = 28

-- Dungeon setting dropdowns: the setting, its choices, the default, and old saved values that map to a choice
local DUNGEON_DROPDOWNS = {
    sort = {
        key = "dungeonGridSort", default = "level", aliases = { name = "alphabetical" },
        options = {
            { text = "Level Ascending (Default)", value = "level" },
            { text = "Level Descending", value = "levelDesc" },
            { text = "Alphabetical (A-Z)", value = "alphabetical" },
        },
    },
    layout = {
        key = "dungeonGridLayout", default = "four",
        options = {
            { text = "4 per Row (Default)", value = "four" },
            { text = "3 per Row", value = "three" },
            { text = "2 per Row (Large)", value = "two_large" },
            { text = "2 per Row (Compact)", value = "two_compact" },
        },
    },
}

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- A dungeon dropdown's saved value as one of its choices, and that choice's label.
--- @param def table a DUNGEON_DROPDOWNS entry
local function currentChoice(def)
    local raw = ns.Settings and ns.Settings.GetDungeonSetting and ns.Settings:GetDungeonSetting(def.key, def.default)
    raw = def.aliases and def.aliases[raw] or raw
    local fallback
    for _, opt in ipairs(def.options) do
        if opt.value == raw then
            return opt.value, opt.text
        end
        if opt.value == def.default then
            fallback = opt
        end
    end
    return fallback.value, fallback.text
end

--- Applies background and border textures to a module row frame.
local function styleModuleRow(row)
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

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local SettingsPanel = {
    panel = nil,
    category = nil,
    moduleRows = {},
}

--- Creates and registers the Journal Settings panel in WoW's AddOn Options.
function SettingsPanel:Init()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", nil)
    panel.name = Constants.SETTINGS.CATEGORY_NAME
    self.panel = panel
    self.moduleRows = {}

    self:CreateHeader(panel)

    -- Scrollable body container for settings content
    local scrollFrame = ns.UI.ScrollFrame:Create(panel)
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -66)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 4)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(580, 876)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    self:CreateCatalogDisclaimerBanner(scrollChild)
    self:CreateGeneralHeader(scrollChild)
    self:CreateKeybindRow(scrollChild)
    self:CreateMinimapToggleRow(scrollChild)
    self:CreateAddonCompartmentToggleRow(scrollChild)
    self:CreateLockWindowToggleRow(scrollChild)
    self:CreateWindowBackgroundRow(scrollChild)
    self:CreateFiligreeToggleRow(scrollChild)
    self:CreateAdvancedSearchSection(scrollChild)
    self:CreateInstalledModulesSection(scrollChild)
    self:CreateDungeonModuleSection(scrollChild)
    self:CreateBothFactionQuestsRow(scrollChild)
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
    subtitle:SetText("Version " .. Constants.VERSION .. " • Author: |cffffd200" .. (Constants.AUTHOR or "Brandon (Endoria)") .. "|r")
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

--- Builds the prominent Catalog Disclaimer banner at the very top of Settings.
--- Informs players that WoW Forever custom content and loot drops are continuously being cataloged.
--- @param panel Frame
function SettingsPanel:CreateCatalogDisclaimerBanner(panel)
    local banner = CreateFrame("Frame", nil, panel)
    banner:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -8)
    banner:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -8)
    banner:SetHeight(38)

    -- 1. Warm dark amber-bronze background
    local bg = banner:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(banner)
    bg:SetTexture(Constants.ASSETS.WHITE_8X8)
    bg:SetVertexColor(0.18, 0.12, 0.04, 0.94)

    -- 2. Gold / yellow borders on all four sides
    local borderTop = banner:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 0, 0)
    borderTop:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderTop:SetVertexColor(0.95, 0.78, 0.25, 0.95)

    local borderBottom = banner:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderBottom:SetVertexColor(0.95, 0.78, 0.25, 0.95)

    local borderLeft = banner:CreateTexture(nil, "BORDER")
    borderLeft:SetWidth(2)
    borderLeft:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 0, 0)
    borderLeft:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderLeft:SetVertexColor(0.95, 0.78, 0.25, 1.0)

    local borderRight = banner:CreateTexture(nil, "BORDER")
    borderRight:SetWidth(2)
    borderRight:SetPoint("TOPRIGHT", banner, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 0)
    borderRight:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderRight:SetVertexColor(0.95, 0.78, 0.25, 1.0)

    -- 3. Left Alert / Notice Icon
    local icon = banner:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", banner, "LEFT", 10, 0)
    icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")

    -- 4. Informative notice text
    local text = banner:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    text:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
    text:SetJustifyH("LEFT")
    if text.SetWordWrap then
        text:SetWordWrap(true)
    end
    text:SetText("|cffffd200World of Warcraft Forever|r |cffe8ded0introduced a lot of new items. These items will be added to the catalog regularly. Please report any discrepancies you notice to the |cffffd200Author|r.|r")
    banner.text = text

    self.CatalogDisclaimerBanner = banner
end

--- Builds the "General" section header above the journal-wide rows.
--- @param panel Frame
function SettingsPanel:CreateGeneralHeader(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.CatalogDisclaimerBanner, "BOTTOMLEFT", 0, -18)
    sectionHeader:SetText("General")
    self.GeneralHeader = sectionHeader

    local subNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subNote:SetPoint("LEFT", sectionHeader, "RIGHT", 12, 0)
    subNote:SetText("Keybind, launcher buttons, and the journal window.")
    subNote:SetTextColor(0.68, 0.64, 0.56)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.68, 0.52, 0.20, 0.35)
    self.GeneralDivider = divider
end

--- Places a General row's label: the first just below the General divider, each next one a row below the last.
--- @param label FontString
function SettingsPanel:PlaceGeneralRow(label)
    if self.lastGeneralRow then
        label:SetPoint("TOPLEFT", self.lastGeneralRow, "TOPLEFT", 0, -GENERAL_ROW_SPACING)
    else
        label:SetPoint("TOPLEFT", self.GeneralDivider, "BOTTOMLEFT", 6, -16)
    end
    self.lastGeneralRow = label
end

--- Builds the interactive "Toggle Journal Keybind" row using `ns.UI.KeybindButton`.
--- @param panel Frame
function SettingsPanel:CreateKeybindRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self:PlaceGeneralRow(label)
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
    self:PlaceGeneralRow(label)
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
        ns.Settings:SetMinimapShown(isChecked)
        ns.UI.MinimapButton:RefreshVisibility()
    end)

    self.ShowMinimapCheckbox = checkbox
    self.HideMinimapCheckbox = checkbox
end

--- Builds the "Show in Blizzard Addon Compartment" checkbox row.
--- Placed directly beneath the Minimap icon setting.
--- @param panel Frame
function SettingsPanel:CreateAddonCompartmentToggleRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self:PlaceGeneralRow(label)
    label:SetText("Show in Blizzard Addon Compartment")
    self.AddonCompartmentLabel = label

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)

    checkbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Blizzard Addon Compartment", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled on modern WoW clients, Adventure Journal is listed in the Blizzard Addon Compartment dropdown next to the Minimap.", 1.0, 1.0, 1.0, true)
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
        ns.Settings:SetAddonCompartmentShown(isChecked)
    end)

    self.AddonCompartmentCheckbox = checkbox
end

--- Builds the "Lock Adventure Journal Window (Shift + Click and Drag to Move)" checkbox row.
--- @param panel Frame
function SettingsPanel:CreateLockWindowToggleRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self:PlaceGeneralRow(label)
    label:SetText("Lock Adventure Journal Window (Shift + Click and Drag to Move)")
    self.LockWindowLabel = label

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)

    checkbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Lock Adventure Journal Window", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, the Adventure Journal window cannot be moved by normal dragging.\n\nHold Shift while clicking and dragging the window header to move the window while locked.", 1.0, 1.0, 1.0, true)
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
        ns.Settings:SetWindowLocked(isChecked)
    end)

    self.LockWindowCheckbox = checkbox
end

--- Builds the "Window Theme" dropdown row (choices from Core/UI/WindowBackground.lua).
--- @param panel Frame
function SettingsPanel:CreateWindowBackgroundRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self:PlaceGeneralRow(label)
    label:SetText("Window Theme")

    local dropdown = CreateFrame("Frame", "AdventureJournalWindowBackgroundDropdown", panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    dropdown:SetPoint("CENTER", label, "CENTER", 0, -2)
    UIDropDownMenu_SetWidth(dropdown, 140)

    local backgrounds = ns.UI.WindowBackground
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local selected = ns.Settings:GetWindowBackground()
        for _, option in ipairs(backgrounds:GetOptions()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            info.value = option.key
            info.checked = (option.key == selected)
            info.func = function(btn)
                UIDropDownMenu_SetSelectedValue(dropdown, btn.value)
                UIDropDownMenu_SetText(dropdown, btn:GetText())
                backgrounds:Select(btn.value)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dropdown:SetScript("OnEnter", function(dd)
        if GameTooltip then
            GameTooltip:SetOwner(dd, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Window Theme", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("The look of every page of the journal:\n\n• Stone: the Collections window's stone (Default).\n• Parchment: the spellbook's parchment page.\n• Forever: the Legacy window's background, with headers styled like the Reputation and Skills tabs.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    dropdown:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.WindowBackgroundDropdown = dropdown
end

--- Builds the "Show Corner Filigree" checkbox row.
--- @param panel Frame
function SettingsPanel:CreateFiligreeToggleRow(panel)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self:PlaceGeneralRow(label)
    label:SetText("Show Corner Filigree")

    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)

    checkbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Corner Filigree", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("The bronze filigree in the window's four corners. It comes with the dark shading along the window's edges (they are one texture), so turning it off removes both.", 1.0, 1.0, 1.0, true)
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
        ns.Settings:SetFiligreeShown(isChecked)
        ns.UI.WindowBackground:Apply()
    end)

    self.FiligreeCheckbox = checkbox
end

--- Builds the compartmentalized "Advanced Searching" section with definition help text
--- and a performance/memory usage warning.
--- @param panel Frame
function SettingsPanel:CreateAdvancedSearchSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.lastGeneralRow, "BOTTOMLEFT", -6, -32)
    sectionHeader:SetText("Advanced Searching")
    self.AdvancedSearchHeader = sectionHeader

    local subNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subNote:SetPoint("LEFT", sectionHeader, "RIGHT", 12, 0)
    subNote:SetText("Multi-tag item filtering, stat indexing, and level requirement queries.")
    subNote:SetTextColor(0.68, 0.64, 0.56)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    divider:SetTexture(Constants.ASSETS.WHITE_8X8)
    divider:SetVertexColor(0.68, 0.52, 0.20, 0.35)

    local container = CreateFrame("Frame", nil, panel)
    container:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -10)
    container:SetPoint("RIGHT", panel, "RIGHT", -18, 0)
    container:SetHeight(98)
    self.AdvancedSearchContainer = container

    -- Subtle bronze-framed compartment box
    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(container)
    bg:SetTexture(Constants.ASSETS.WHITE_8X8)
    bg:SetVertexColor(0.11, 0.09, 0.07, 0.85)

    local borderTop = container:CreateTexture(nil, "BORDER")
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
    borderTop:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderTop:SetVertexColor(0.45, 0.36, 0.21, 0.70)

    local borderBottom = container:CreateTexture(nil, "BORDER")
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetTexture(Constants.ASSETS.WHITE_8X8)
    borderBottom:SetVertexColor(0.28, 0.22, 0.13, 0.70)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", container, "TOPLEFT", 12, -10)
    label:SetText("Enable Advanced Searching")
    self.AdvancedSearchLabel = label

    local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
    checkbox:SetSize(28, 28)
    checkbox:SetPoint("RIGHT", container, "RIGHT", -10, 0)
    checkbox:SetPoint("CENTER", label, "CENTER", 0, 0)

    local helpText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    helpText:SetPoint("RIGHT", container, "RIGHT", -46, 0)
    helpText:SetJustifyH("LEFT")
    if helpText.SetWordWrap then
        helpText:SetWordWrap(true)
    end
    helpText:SetTextColor(0.82, 0.79, 0.72)
    helpText:SetText("What is Advanced Searching? Standard search matches dungeon, boss, and item names only. Advanced Searching indexes the full item catalog so you can filter by multiple tags, equipment slots, weapon/armor types, stats, and required levels (e.g. |cffffd200\"one-hand, sword\"|r, |cffffd200\"cloth, intellect\"|r, or |cffffd200\"lvl 30-40\"|r).")

    local warnIcon = container:CreateTexture(nil, "ARTWORK")
    warnIcon:SetSize(14, 14)
    warnIcon:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 12, 8)
    warnIcon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")

    local warnText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warnText:SetPoint("LEFT", warnIcon, "RIGHT", 6, 0)
    warnText:SetPoint("RIGHT", container, "RIGHT", -12, 0)
    warnText:SetJustifyH("LEFT")
    warnText:SetText("|cffff6060Warning:|r Increases addon memory usage and can cause brief stuttering when searching.")

    checkbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Enable Advanced Searching", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("Unlocks multi-tag and level requirement queries across the item catalog:\n\n• Equipment Slots & Types: \"one-hand, sword\", \"cloth, head\", \"2h, axe\"\n• Combat & Caster Stats: \"intellect\", \"spell power\", \"healing\", \"crit\"\n• Categories & Professions: \"recipe, blacksmithing\", \"quest, key\"\n• Required Character Level: \"lvl 30-40\", \">=45\", \"<=35\"", 1.0, 1.0, 1.0, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Performance & Memory Warning: Building the inverted tag index and scanning item tooltips increases memory usage and may cause brief stuttering while typing in the search bar.", 1.0, 0.40, 0.40, true)
            if not cb:IsEnabled() then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Unavailable: needs the DataStore module. Enable it under Installed Modules, then /reload.", 1.0, 0.40, 0.40, true)
            end
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
        ns.Settings:SetAdvancedSearchEnabled(isChecked)
        local tagRegistry = ns.DataStore and ns.DataStore.TagRegistry
        if tagRegistry then
            tagRegistry:ClearIndex()
        end
        local mainFrame = ns.UI and ns.UI.MainFrame
        local headerBar = mainFrame and mainFrame.GetHeaderBar and mainFrame:GetHeaderBar()
        local searchBox = headerBar and headerBar.SearchBox
        if searchBox and ns.ModuleRegistry and ns.ModuleRegistry.DispatchSearch then
            local curText = searchBox:GetText() or ""
            if curText ~= "" then
                ns.ModuleRegistry:DispatchSearch(curText)
            end
        end
    end)

    -- Keeps the tooltip working while the checkbox is disabled (DataStore off)
    checkbox:SetMotionScriptsWhileDisabled(true)
    self.AdvancedSearchCheckbox = checkbox
end

--- Builds the "Installed Modules" section header, instructions, and module list container.
--- @param panel Frame
function SettingsPanel:CreateInstalledModulesSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.AdvancedSearchContainer, "BOTTOMLEFT", 0, -22)
    sectionHeader:SetText("Installed Modules")
    self.ModuleSectionHeader = sectionHeader

    local subNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subNote:SetPoint("LEFT", sectionHeader, "RIGHT", 12, 0)
    subNote:SetText("Disable modules to unload them (/reload to re-enable).")
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
    self.ModuleListContainer = listContainer

    local emptyText = listContainer:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 6, -8)
    emptyText:SetText("No Journal modules are currently installed.")
    self.NoModulesText = emptyText
end

--- Builds a labeled dropdown row for a dungeon setting (`def`, a DUNGEON_DROPDOWNS entry), its label placed
--- with the given anchor. Choosing an option saves it and tells the Dungeons module. Returns the label.
--- @return FontString
function SettingsPanel:CreateDungeonDropdownRow(panel, def, labelText, frameName, point, relativeTo, relativePoint,
        x, y, tooltipText)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint(point, relativeTo, relativePoint, x, y)
    label:SetText(labelText)

    -- The dropdown template needs a global name
    local dropdown = CreateFrame("Frame", frameName, panel, "UIDropDownMenuTemplate")
    dropdown:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    dropdown:SetPoint("CENTER", label, "CENTER", 0, -2)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, 140)
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(dropdown, function(_, level)
            local selectedValue = currentChoice(def)
            for _, opt in ipairs(def.options) do
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
                    if ns.Settings and ns.Settings.SetDungeonSetting then
                        ns.Settings:SetDungeonSetting(def.key, btn.value)
                    end
                    if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
                        _G.JournalBase:OnDungeonSettingChanged(def.key, btn.value)
                    end
                end
                info.checked = (opt.value == selectedValue)
                if UIDropDownMenu_AddButton then
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)
    end

    dropdown:SetScript("OnEnter", function(dd)
        if GameTooltip then
            GameTooltip:SetOwner(dd, "ANCHOR_RIGHT")
            GameTooltip:AddLine(labelText, 1.0, 0.82, 0.0)
            GameTooltip:AddLine(tooltipText, 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    dropdown:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.dungeonDropdowns = self.dungeonDropdowns or {}
    self.dungeonDropdowns[#self.dungeonDropdowns + 1] = { dropdown = dropdown, def = def }
    return label
end

--- Builds the "Dungeon Module" section: its header and every Dungeons option row.
--- @param panel Frame
function SettingsPanel:CreateDungeonModuleSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.ModuleListContainer, "BOTTOMLEFT", 0, -20)
    sectionHeader:SetText("Dungeon Module")
    self.DungeonModuleHeader = sectionHeader

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

    -- Row 1: "Sort Dungeon Grid by"
    local sortLabel = self:CreateDungeonDropdownRow(panel, DUNGEON_DROPDOWNS.sort, "Sort Dungeon Grid by",
        "AdventureJournalDungeonSortDropdown", "TOPLEFT", divider, "BOTTOMLEFT", 6, -16,
        "Controls how dungeon cards are ordered on the Dungeons tab grid:\n\n• Level Ascending: Lowest level range first, matching official Blizzard Looking For Group brackets (Default).\n• Level Descending: Highest level range first.\n• Alphabetical (A-Z): Sorted alphabetically by dungeon name.")
    self.DungeonSortLabel = sortLabel

    -- Row 2: "Dungeon Grid Layout"
    local layoutLabel = self:CreateDungeonDropdownRow(panel, DUNGEON_DROPDOWNS.layout, "Dungeon Grid Layout",
        "AdventureJournalDungeonLayoutDropdown", "TOPLEFT", sortLabel, "BOTTOMLEFT", 0, -22,
        "How many dungeon cards sit in each row of the Dungeons tab grid:\n\n• 2 per Row (Compact) and (Large): wide cards with the name, levels, and zone.\n• 3 per Row: the name, levels, and zone.\n• 4 per Row: small cards with the name and levels centered (Default).")

    -- Row 3: "Show Levels on Dungeon Grid and Boss List Buttons"
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -22)
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
        ns.Settings:SetDungeonSetting("showBossLevel", isChecked)

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
        ns.Settings:SetDungeonSetting("showBossDifficultyColor", isChecked)

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
        ns.Settings:SetDungeonSetting("showMinorMonsters", isChecked)
        ns.Settings:SetDungeonSetting("hideMinorMonsters", not isChecked)

        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showMinorMonsters", isChecked)
            _G.JournalBase:OnDungeonSettingChanged("hideMinorMonsters", not isChecked)
        end
    end)

    self.MinorMonstersCheckbox = minorCheckbox

    -- Row: "Show Event Bosses and Encounters" (dropdown: "Always", "Only During the Holidays", "Never")
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
        { text = "Only During the Holidays", value = "holiday" },
        { text = "Always", value = "always" },
        { text = "Never", value = "never" },
    }

    local function initializeEventDropdown(selfDD, level)
        local rawVal = ns.Settings and ns.Settings.GetDungeonSetting and ns.Settings:GetDungeonSetting("showEventBosses", "holiday")
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
                if ns.Settings and ns.Settings.SetDungeonSetting then
                    ns.Settings:SetDungeonSetting("showEventBosses", btn.value)
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
            GameTooltip:AddLine("Controls how seasonal holiday encounters (such as Crown Chemical Co., Headless Horseman, and Coren Direbrew) appear in dungeon boss lists.\n\n• Only During the Holidays: Dynamically shows bosses only while their seasonal holiday is active (Recommended).\n• Always: Always shows event bosses regardless of calendar season.\n• Never: Completely hides event bosses.", 1.0, 1.0, 1.0, true)
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
        ns.Settings:SetDungeonSetting("showDungeonSetChallenges", isChecked)

        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showDungeonSetChallenges", isChecked)
        end
    end)

    self.ChallengeBossesCheckbox = challengeCheckbox
    self.ChallengeBossesLabel = challengeLabel
end

--- Adds the Dungeons section's last row: "Show Both Factions' Instance Quests".
--- @param panel Frame
function SettingsPanel:CreateBothFactionQuestsRow(panel)
    local bothFactionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bothFactionLabel:SetPoint("TOPLEFT", self.ChallengeBossesLabel, "BOTTOMLEFT", 0, -22)
    bothFactionLabel:SetText("Show Both Factions' Instance Quests")
    self.BothFactionQuestsLabel = bothFactionLabel

    local bothFactionCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    bothFactionCheckbox:SetSize(28, 28)
    bothFactionCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    bothFactionCheckbox:SetPoint("CENTER", bothFactionLabel, "CENTER", 0, 0)

    bothFactionCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Both Factions' Instance Quests", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, quests for both Alliance and Horde will appear in instance quest tabs (with opposing faction quests grouped below a divider). When disabled, only your faction's and neutral quests are shown.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    bothFactionCheckbox:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    bothFactionCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked() and true or false
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        ns.Settings:SetDungeonSetting("showBothFactionData", isChecked)
        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showBothFactionData", isChecked)
        end
    end)

    self.BothFactionQuestsCheckbox = bothFactionCheckbox
end

--- Builds the "Map Icons Module" section with options for world map markers.
--- @param panel Frame
function SettingsPanel:CreateMapIconsModuleSection(panel)
    local sectionHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sectionHeader:SetPoint("TOPLEFT", self.BothFactionQuestsLabel, "BOTTOMLEFT", -6, -26)
    sectionHeader:SetText("Map Icons Module")
    self.MapIconsModuleHeader = sectionHeader

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

    -- Row 1: "Show Zone Levels on World Map"
    local zoneLevelsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneLevelsLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 6, -14)
    zoneLevelsLabel:SetText("Show Zone Levels on World Map")
    self.ZoneLevelsLabel = zoneLevelsLabel

    local zoneLevelsCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    zoneLevelsCheckbox:SetSize(28, 28)
    zoneLevelsCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    zoneLevelsCheckbox:SetPoint("CENTER", zoneLevelsLabel, "CENTER", 0, 0)

    zoneLevelsCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Zone Levels on World Map", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, hovering over a zone on the World Map displays the zone's recommended level bracket dynamically colored by difficulty.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    zoneLevelsCheckbox:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    zoneLevelsCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked()
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        if ns.Settings and ns.Settings.SetMapIconsSetting then
            ns.Settings:SetMapIconsSetting("showZoneLevels", isChecked)
        end
    end)
    self.ZoneLevelsCheckbox = zoneLevelsCheckbox

    -- Row 2: "Show Fishing Levels on World Map"
    local fishingLevelsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fishingLevelsLabel:SetPoint("TOPLEFT", zoneLevelsLabel, "BOTTOMLEFT", 0, -18)
    fishingLevelsLabel:SetText("Show Fishing Levels on World Map")
    self.FishingLevelsLabel = fishingLevelsLabel

    local fishingLevelsCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    fishingLevelsCheckbox:SetSize(28, 28)
    fishingLevelsCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    fishingLevelsCheckbox:SetPoint("CENTER", fishingLevelsLabel, "CENTER", 0, 0)

    fishingLevelsCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Fishing Levels on World Map", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, hovering over a zone on the World Map displays the required fishing skill level below the zone title.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    fishingLevelsCheckbox:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    fishingLevelsCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked()
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        if ns.Settings and ns.Settings.SetMapIconsSetting then
            ns.Settings:SetMapIconsSetting("showFishingLevels", isChecked)
        end
    end)
    self.FishingLevelsCheckbox = fishingLevelsCheckbox

    -- Row 3: "Show Flight Paths on World Map"
    local flightPathsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    flightPathsLabel:SetPoint("TOPLEFT", fishingLevelsLabel, "BOTTOMLEFT", 0, -18)
    flightPathsLabel:SetText("Show Flight Paths on World Map")
    self.FlightPathsLabel = flightPathsLabel

    local flightPathsCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    flightPathsCheckbox:SetSize(28, 28)
    flightPathsCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    flightPathsCheckbox:SetPoint("CENTER", flightPathsLabel, "CENTER", 0, 0)

    flightPathsCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Flight Paths on World Map", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, flight master locations are marked on the World Map with winged boot icons.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    flightPathsCheckbox:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    flightPathsCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked()
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        if ns.Settings and ns.Settings.SetMapIconsSetting then
            ns.Settings:SetMapIconsSetting("showFlightPaths", isChecked)
        end
        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showFlightPaths", isChecked)
        end
        if self.UpdateFlightPathDependencies then
            self:UpdateFlightPathDependencies()
        end
        if ns.MapPinProvider and ns.MapPinProvider.Refresh then
            ns.MapPinProvider:Refresh()
        end
    end)
    self.FlightPathsCheckbox = flightPathsCheckbox

    -- Row 4a: Sub-option "Use Faction Colors for Faction-Specific Flight Paths" (Indented)
    local factionColorsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    factionColorsLabel:SetPoint("TOPLEFT", flightPathsLabel, "BOTTOMLEFT", 18, -16)
    factionColorsLabel:SetText("Use Faction Colors for Faction-Specific Flight Paths")
    self.FactionColorsLabel = factionColorsLabel

    local factionColorsCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    factionColorsCheckbox:SetSize(28, 28)
    factionColorsCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    factionColorsCheckbox:SetPoint("CENTER", factionColorsLabel, "CENTER", 0, 0)

    factionColorsCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Use Faction Colors for Faction-Specific Flight Paths", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, Alliance flight masters appear in blue and Horde in red (neutral in gold). When disabled, all flight paths appear in uniform gold.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    factionColorsCheckbox:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    factionColorsCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked()
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        if ns.Settings and ns.Settings.SetMapIconsSetting then
            ns.Settings:SetMapIconsSetting("useFactionColorsForFlightPaths", isChecked)
        end
        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("useFactionColorsForFlightPaths", isChecked)
        end
        if ns.MapPinProvider and ns.MapPinProvider.Refresh then
            ns.MapPinProvider:Refresh()
        end
    end)
    self.FactionColorsCheckbox = factionColorsCheckbox

    -- Row 4b: Sub-option "Show Enemy Faction Flight Paths" (Indented, default: off)
    local enemyFactionLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enemyFactionLabel:SetPoint("TOPLEFT", factionColorsLabel, "BOTTOMLEFT", 0, -14)
    enemyFactionLabel:SetText("Show Enemy Faction Flight Paths")
    self.EnemyFactionLabel = enemyFactionLabel

    local enemyFactionCheckbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enemyFactionCheckbox:SetSize(28, 28)
    enemyFactionCheckbox:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    enemyFactionCheckbox:SetPoint("CENTER", enemyFactionLabel, "CENTER", 0, 0)

    enemyFactionCheckbox:SetScript("OnEnter", function(cb)
        if GameTooltip then
            GameTooltip:SetOwner(cb, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Show Enemy Faction Flight Paths", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("When enabled, flight master locations for the opposing faction are shown on your map. When disabled, only your faction's and neutral flight paths are displayed.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    enemyFactionCheckbox:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    enemyFactionCheckbox:SetScript("OnClick", function(cb)
        local isChecked = cb:GetChecked()
        if PlaySound then
            PlaySound(isChecked and Constants.SOUNDS.CHECKBOX_ON or Constants.SOUNDS.CHECKBOX_OFF)
        end
        if ns.Settings and ns.Settings.SetMapIconsSetting then
            ns.Settings:SetMapIconsSetting("showEnemyFactionFlightPaths", isChecked)
        end
        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showEnemyFactionFlightPaths", isChecked)
        end
        if ns.MapPinProvider and ns.MapPinProvider.Refresh then
            ns.MapPinProvider:Refresh()
        end
    end)
    self.EnemyFactionCheckbox = enemyFactionCheckbox

    -- Dependency controller for flight path sub-settings
    local function updateFlightPathDependencies()
        local isParentChecked = flightPathsCheckbox:GetChecked() and true or false
        local function setSubControl(cb, lbl)
            if not cb or not lbl then return end
            if isParentChecked then
                cb:Enable()
                lbl:SetFontObject("GameFontNormal")
                lbl:SetTextColor(1.0, 0.82, 0.0)
            else
                cb:Disable()
                lbl:SetFontObject("GameFontDisable")
                lbl:SetTextColor(0.50, 0.50, 0.50)
            end
        end
        setSubControl(factionColorsCheckbox, factionColorsLabel)
        setSubControl(enemyFactionCheckbox, enemyFactionLabel)
    end
    self.UpdateFlightPathDependencies = updateFlightPathDependencies

    -- Row 5: "Dungeon Icons on World Map" (with blue swirl portal icon and dropdown)
    local mapIconsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapIconsLabel:SetPoint("TOPLEFT", enemyFactionLabel, "BOTTOMLEFT", -18, -24)
    mapIconsLabel:SetText("Dungeon Icons on World Map")
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
        { text = "After Minimum Level", value = "min_level" },
        { text = "Only During Level Bracket", value = "bracket" },
        { text = "Always Show", value = "always" },
        { text = "Disabled", value = "disabled" },
    }

    local function initializeDropdown(selfDD, level)
        local selectedValue = (ns.Settings and ns.Settings.GetMapIconsSetting and ns.Settings:GetMapIconsSetting("worldMapDungeonIcons", "min_level"))
            or (ns.Settings and ns.Settings.GetDungeonSetting and ns.Settings:GetDungeonSetting("worldMapDungeonIcons", "min_level"))
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
                if ns.Settings and ns.Settings.SetMapIconsSetting then
                    ns.Settings:SetMapIconsSetting("worldMapDungeonIcons", btn.value)
                elseif ns.Settings and ns.Settings.SetDungeonSetting then
                    ns.Settings:SetDungeonSetting("worldMapDungeonIcons", btn.value)
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
            GameTooltip:AddLine("Controls when dungeon entrance icons (blue swirl portals) appear on the World Map.\n\n• After Minimum Level: Visible once your character reaches the dungeon's minimum level (Default).\n• Only During Level Bracket: Only visible while within the recommended level range.\n• Always Show: Always visible regardless of your character's level.\n• Disabled: Hides all dungeon entrance markers.", 1.0, 1.0, 1.0, true)
            GameTooltip:Show()
        end
    end)
    dropdown:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.WorldMapIconsDropdown = dropdown

    -- Row 6: "Raid Icons on World Map" (with green swirl portal icon, "(Under Construction)" tag, and disabled dropdown)
    local raidIconsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidIconsLabel:SetPoint("TOPLEFT", mapIconsLabel, "BOTTOMLEFT", 0, -28)
    raidIconsLabel:SetText("Raid Icons on World Map")
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

--- Positions `row` at slot `index` within `self.ModuleListContainer`.
local function anchorRowAtSlot(container, row, index)
    local yOffset = -((index - 1) * (MODULE_ROW_HEIGHT + MODULE_ROW_GAP))
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yOffset)
    row:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, yOffset)
end

--- Acquires or creates a pooled row widget for a module in Settings: its icon, name, status, and an
--- Enable/Disable button.
--- @param index number
--- @return Frame
function SettingsPanel:AcquireModuleRow(index)
    local row = self.moduleRows[index]
    if row then
        row:Show()
        return row
    end

    row = CreateFrame("Frame", nil, self.ModuleListContainer)
    row:SetHeight(MODULE_ROW_HEIGHT)
    row:EnableMouse(true)
    styleModuleRow(row)

    -- Module Icon (`24x24`)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", row, "LEFT", 12, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    -- Module Title, Status, and Enable/Disable Button
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    row.nameText = nameText

    local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("RIGHT", row, "RIGHT", -106, 0)
    row.statusText = statusText

    local toggleBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    toggleBtn:SetSize(84, 22)
    toggleBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.toggleBtn = toggleBtn

    toggleBtn:SetScript("OnClick", function(btn)
        if not row.moduleId or not row.isInstalled then
            return
        end
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end

        if row.pendingReload then
            local reload = _G.ReloadUI or (_G.C_UI and _G.C_UI.Reload)
            if reload then
                reload()
            end
            return
        end

        local currentlyDisabled = ns.Settings:IsModuleDisabled(row.moduleId)
        local shouldEnable = currentlyDisabled
        ns.ModuleRegistry:SetModuleEnabled(row.moduleId, shouldEnable)

        self:RefreshModuleRows()
    end)

    toggleBtn:SetScript("OnEnter", function(btn)
        if not GameTooltip or not row.moduleId then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        if row.pendingReload then
            GameTooltip:SetText("Reload UI Required", 1.0, 0.82, 0.0)
            GameTooltip:AddLine(
                (row.moduleTitle or "This module") .. " is enabled and staged to load. Because disabled modules are completely unloaded from memory, click here (or type /rl) to reload your UI and activate it.",
                0.85, 0.85, 0.85, true
            )
        elseif row.isDisabled or row.isUnloaded then
            GameTooltip:SetText("Enable " .. (row.moduleTitle or "Module"), 1.0, 0.82, 0.0)
            GameTooltip:AddLine(
                "This module is currently unloaded from memory to conserve resources. Enabling it will stage it to load on your next UI /reload.",
                0.85, 0.85, 0.85, true
            )
        else
            GameTooltip:SetText("Disable & Unload " .. (row.moduleTitle or "Module"), 1.0, 0.82, 0.0)
            GameTooltip:AddLine(
                "Disables this module and immediately purges its data tables and UI frames from memory. Re-enabling it later will require a UI /reload.",
                0.85, 0.85, 0.85, true
            )
        end
        GameTooltip:Show()
    end)

    toggleBtn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.moduleRows[index] = row
    return row
end

--- Refreshes the list of modules and their enabled state.
function SettingsPanel:RefreshModuleRows()
    if not self.ModuleListContainer then
        return
    end

    for _, row in ipairs(self.moduleRows) do
        row:Hide()
    end

    local catalog = ns.ModuleRegistry:GetCatalogModules()
    if #catalog == 0 then
        if self.NoModulesText then
            self.NoModulesText:Show()
        end
        return
    end

    if self.NoModulesText then
        self.NoModulesText:Hide()
    end

    local totalRows = #catalog
    local containerHeight = math.max(60, totalRows * (MODULE_ROW_HEIGHT + MODULE_ROW_GAP) - MODULE_ROW_GAP)
    self.ModuleListContainer:SetHeight(containerHeight)

    for index, entry in ipairs(catalog) do
        local row = self:AcquireModuleRow(index)
        anchorRowAtSlot(self.ModuleListContainer, row, index)

        local isInstalled = entry.isInstalled
        local isDisabled = not entry.isEnabled

        row.moduleId = entry.id
        row.moduleTitle = entry.title
        row.addonName = entry.addonName
        row.isInstalled = isInstalled
        row.isLoaded = entry.isLoaded
        row.isUnloaded = entry.isUnloaded
        row.pendingReload = entry.pendingReload
        row.isDisabled = isDisabled
        row.isUtility = entry.isUtility

        row.bg:SetVertexColor(0.12, 0.11, 0.09, 0.88)
        row.bTop:SetVertexColor(0.45, 0.36, 0.21, 0.78)
        row.bBottom:SetVertexColor(0.26, 0.21, 0.13, 0.78)

        row.icon:SetTexture(entry.icon or Constants.ASSETS.FALLBACK_ICON)
        row.icon:SetDesaturated(not entry.isEnabled)
        row.nameText:SetText(entry.title .. " |cff808080(" .. tostring(entry.addonName) .. ")|r")

        if not isInstalled then
            row.statusText:SetText("|cff808080Not Installed|r")
            row.toggleBtn:SetText("Missing")
            row.toggleBtn:Disable()
        elseif entry.pendingReload then
            row.statusText:SetText("|cffffcc00Reload Required|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText("Reload UI")
        elseif entry.isUnloaded or not entry.isLoaded or isDisabled then
            row.statusText:SetText("|cff808080Unloaded|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText("Enable")
        else
            row.statusText:SetText("|cff40ff40Enabled|r")
            row.toggleBtn:Enable()
            row.toggleBtn:SetText("Disable")
        end
    end
end

--- Refreshes all controls on the Settings panel.
function SettingsPanel:Refresh()
    if self.KeybindButton then
        self.KeybindButton:Refresh()
    end
    if self.ShowMinimapCheckbox then
        self.ShowMinimapCheckbox:SetChecked(ns.Settings:IsMinimapShown())
    elseif self.HideMinimapCheckbox then
        self.HideMinimapCheckbox:SetChecked(ns.Settings:IsMinimapShown())
    end
    if self.AddonCompartmentCheckbox then
        self.AddonCompartmentCheckbox:SetChecked(ns.Settings:IsAddonCompartmentShown())
    end
    if self.LockWindowCheckbox then
        self.LockWindowCheckbox:SetChecked(ns.Settings:IsWindowLocked())
    end
    if self.FiligreeCheckbox then
        self.FiligreeCheckbox:SetChecked(ns.Settings:IsFiligreeShown())
    end
    if self.WindowBackgroundDropdown then
        local selected = ns.Settings:GetWindowBackground()
        for _, option in ipairs(ns.UI.WindowBackground:GetOptions()) do
            if option.key == selected then
                UIDropDownMenu_SetSelectedValue(self.WindowBackgroundDropdown, option.key)
                UIDropDownMenu_SetText(self.WindowBackgroundDropdown, option.label)
            end
        end
    end
    if self.AdvancedSearchCheckbox then
        self.AdvancedSearchCheckbox:SetChecked(ns.Settings:IsAdvancedSearchEnabled())
        -- Advanced Search needs the DataStore; off until it's enabled again and the UI reloads
        local dataStoreOn = ns.DataStore and ns.DataStore.IsEnabled and ns.DataStore:IsEnabled()
        self.AdvancedSearchCheckbox:SetEnabled(dataStoreOn and true or false)
    end
    if self.BossLevelCheckbox then
        self.BossLevelCheckbox:SetChecked(ns.Settings:GetDungeonSetting("showBossLevel", true) == true)
    end
    if self.DifficultyColorCheckbox then
        self.DifficultyColorCheckbox:SetChecked(ns.Settings:GetDungeonSetting("showBossDifficultyColor", true) == true)
    end
    if self.UpdateDifficultyDependency then
        self.UpdateDifficultyDependency()
    end
    if self.MinorMonstersCheckbox then
        self.MinorMonstersCheckbox:SetChecked(ns.Settings:GetDungeonSetting("showMinorMonsters", true) == true)
    end
    if self.EventBossesDropdown then
        local rawVal = ns.Settings and ns.Settings.GetDungeonSetting and ns.Settings:GetDungeonSetting("showEventBosses", "holiday")
        local selectedValue = "holiday"
        local labelText = "Only During the Holidays"
        if rawVal == "always" or rawVal == true then
            selectedValue = (rawVal == true and "holiday" or "always")
            labelText = (rawVal == true and "Only During the Holidays" or "Always")
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
        self.ChallengeBossesCheckbox:SetChecked(ns.Settings:GetDungeonSetting("showDungeonSetChallenges", false) == true)
    end
    for _, entry in ipairs(self.dungeonDropdowns or {}) do
        local selectedValue, labelText = currentChoice(entry.def)
        if UIDropDownMenu_SetSelectedValue then
            UIDropDownMenu_SetSelectedValue(entry.dropdown, selectedValue)
        end
        if UIDropDownMenu_SetText then
            UIDropDownMenu_SetText(entry.dropdown, labelText)
        end
    end
    if self.BothFactionQuestsCheckbox then
        self.BothFactionQuestsCheckbox:SetChecked(ns.Settings:GetDungeonSetting("showBothFactionData", false) == true)
    end
    if self.ZoneLevelsCheckbox then
        self.ZoneLevelsCheckbox:SetChecked(ns.Settings:GetMapIconsSetting("showZoneLevels", true) ~= false)
    end
    if self.FishingLevelsCheckbox then
        self.FishingLevelsCheckbox:SetChecked(ns.Settings:GetMapIconsSetting("showFishingLevels", true) ~= false)
    end
    if self.FlightPathsCheckbox then
        self.FlightPathsCheckbox:SetChecked(ns.Settings:GetMapIconsSetting("showFlightPaths", true) ~= false)
    end
    if self.FactionColorsCheckbox then
        self.FactionColorsCheckbox:SetChecked(ns.Settings:GetMapIconsSetting("useFactionColorsForFlightPaths", true) ~= false)
    end
    if self.EnemyFactionCheckbox then
        self.EnemyFactionCheckbox:SetChecked(ns.Settings:GetMapIconsSetting("showEnemyFactionFlightPaths", false) == true)
    end
    if self.UpdateFlightPathDependencies then
        self:UpdateFlightPathDependencies()
    end
    if self.WorldMapIconsDropdown then
        local val = (ns.Settings and ns.Settings.GetMapIconsSetting and ns.Settings:GetMapIconsSetting("worldMapDungeonIcons", "min_level"))
            or (ns.Settings and ns.Settings.GetDungeonSetting and ns.Settings:GetDungeonSetting("worldMapDungeonIcons", "min_level"))
            or "min_level"
        if UIDropDownMenu_SetSelectedValue then
            UIDropDownMenu_SetSelectedValue(self.WorldMapIconsDropdown, val)
        end
        local labelText = "After Minimum Level"
        if val == "always" then
            labelText = "Always Show"
        elseif val == "bracket" then
            labelText = "Only During Level Bracket"
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
    self:RefreshModuleRows()

    local totalH = 1360
    if status and status.isMismatch then
        totalH = 1400
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
        -- A "General" entry (the top of the page) comes first on its own; list the other sections here, in page order
        ns.UI.SettingsSections:Register(category, panel, self.scrollFrame, self.scrollChild, {
            { name = "Advanced Searching", header = self.AdvancedSearchHeader },
            { name = "Installed Modules", header = self.ModuleSectionHeader },
            { name = "Dungeon Module", header = self.DungeonModuleHeader },
            { name = "Map Icons Module", header = self.MapIconsModuleHeader },
        })
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
        -- Opened from the journal: selected with its section list open (opening to the category rebuilds the list
        -- when the category is expanded, even if it was already the selected page)
        if self.category.SetExpanded then
            self.category:SetExpanded(true)
        end
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
