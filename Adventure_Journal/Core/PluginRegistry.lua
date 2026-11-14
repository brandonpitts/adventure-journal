-- ============================================================================
-- Journal_Base - PluginRegistry.lua
-- Plugin registration contract, custom ordering, Home routing, and xpcall sandboxing.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local type = type
local tonumber = tonumber
local tostring = tostring
local table = table
local ipairs = ipairs
local xpcall = xpcall
local CallErrorHandler = CallErrorHandler or geterrorhandler
local CreateFrame = CreateFrame
local Constants = ns.Constants

local DEFAULT_PLUGIN_ORDER = 100

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Returns the effective sort order for a plugin (user's custom drag-and-drop
--- order from `Database`, falling back to `plugin.defaultOrder`).
--- "home" always returns 0 to guarantee it occupies Slot 1.
local function getEffectiveOrder(plugin)
    if plugin.id == "home" then
        return 0
    end
    local custom = ns.Database and ns.Database:GetPluginCustomOrder(plugin.id)
    if type(custom) == "number" then
        return custom
    end
    return plugin.defaultOrder or plugin.order or DEFAULT_PLUGIN_ORDER
end

--- Comparator for sorting plugins left-to-right by effective order then `title`.
--- "home" is always pinned unconditionally to the top (Slot 1).
--- Utility modules (`isUtility == true`) are always pinned to the bottom.
local function comparePlugins(a, b)
    if a.id == "home" then
        return true
    elseif b.id == "home" then
        return false
    end
    local aUtil = (a.isUtility == true)
    local bUtil = (b.isUtility == true)
    if aUtil ~= bUtil then
        return not aUtil
    end
    local orderA = getEffectiveOrder(a)
    local orderB = getEffectiveOrder(b)
    if orderA ~= orderB then
        return orderA < orderB
    end
    return (a.title or "") < (b.title or "")
end

--- Checks whether an addon physically exists on disk in Interface\AddOns,
--- regardless of whether it is currently loaded in memory or enabled.
local function isAddOnInstalledOnDisk(addonName)
    if not addonName or addonName == "" then
        return false
    end
    if addonName == "Journal_Base" then
        return true
    end
    if C_AddOns and C_AddOns.DoesAddOnExist then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, addonName)
        if ok and exists then
            return true
        end
    end
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or _G.GetAddOnInfo
    if getInfo then
        local ok, name = pcall(getInfo, addonName)
        if ok and name then
            return true
        end
    end
    return false
end

--- Safely invokes a method on an external plugin using `xpcall` so that an
--- error in a third-party/separate plugin never breaks `Journal_Base`.
--- @param plugin table
--- @param methodName string
local function safeInvokePlugin(plugin, methodName, ...)
    if type(plugin) ~= "table" then
        return
    end
    local fn = plugin[methodName]
    if type(fn) ~= "function" then
        return
    end

    local errorHandler = (type(CallErrorHandler) == "function" and CallErrorHandler)
        or function(err)
            if _G.JournalBase then
                _G.JournalBase:Print("Plugin error (" .. tostring(plugin.id) .. "." .. methodName .. "): " .. tostring(err))
            end
        end

    xpcall(fn, errorHandler, plugin, ...)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local PluginRegistry = {
    pluginsById = {},
    orderedPlugins = {},
    activePluginId = nil,
}

--- Validates and registers a standalone plugin with `Journal_Base`.
--- @param pluginDef table `{ id, title, order?, version?, lastUpdated?, description?, apiVersion?, icon?, OnInitialize?, OnActivate?, OnDeactivate?, OnSearch? }`
--- @return boolean success, string|nil errorMessage
function PluginRegistry:Register(pluginDef)
    if type(pluginDef) ~= "table" then
        return false, "RegisterPlugin expected a table."
    end

    local id = pluginDef.id
    local title = pluginDef.title
    if type(id) ~= "string" or id == "" then
        return false, "Plugin definition requires a non-empty string 'id'."
    end
    if type(title) ~= "string" or title == "" then
        return false, "Plugin '" .. id .. "' requires a non-empty string 'title'."
    end
    if self.pluginsById[id] then
        return false, "Plugin '" .. id .. "' is already registered."
    end

    local defaultOrder = tonumber(pluginDef.order) or DEFAULT_PLUGIN_ORDER
    local isUtility = (pluginDef.isUtility == true)
    local plugin = {
        id = id,
        title = title,
        addonName = tostring(pluginDef.addonName or ("Journal_" .. title)),
        version = tostring(pluginDef.version or "0.1.0"),
        lastUpdated = tostring(pluginDef.lastUpdated or "2026-11-11"),
        description = pluginDef.description,
        apiVersion = tonumber(pluginDef.apiVersion) or Constants.PLUGIN_API_VERSION,
        icon = pluginDef.icon or Constants.ASSETS.FALLBACK_ICON,
        defaultOrder = defaultOrder,
        order = defaultOrder,
        isUtility = isUtility,
        OnInitialize = pluginDef.OnInitialize,
        OnActivate = pluginDef.OnActivate,
        OnDeactivate = pluginDef.OnDeactivate,
        OnSearch = pluginDef.OnSearch,
        isInitialized = false,
        canvas = nil,
    }

    self.pluginsById[id] = plugin
    self.orderedPlugins[#self.orderedPlugins + 1] = plugin
    self:ResortPlugins()

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnPluginsChanged()
    end
    if ns.UI.SettingsPanel and ns.UI.SettingsPanel.Refresh then
        ns.UI.SettingsPanel:Refresh()
    end

    return true, nil
end

--- Re-sorts `self.orderedPlugins` using the user's custom drag-and-drop order (if saved)
--- or each plugin's `defaultOrder`.
function PluginRegistry:ResortPlugins()
    table.sort(self.orderedPlugins, comparePlugins)
end

--- @param pluginId string
--- @return table|nil
function PluginRegistry:GetPlugin(pluginId)
    return self.pluginsById[pluginId]
end

--- Returns all installed/registered plugins in their current sort order (including disabled ones).
--- @return table[]
function PluginRegistry:GetAllPlugins()
    self:ResortPlugins()
    return self.orderedPlugins
end

--- Returns only enabled non-utility plugins in their current sort order (used by `TabBar` and `MainFrame`).
--- @return table[]
function PluginRegistry:GetOrderedPlugins()
    self:ResortPlugins()
    local enabled = {}
    for _, plugin in ipairs(self.orderedPlugins) do
        if not ns.Database:IsPluginDisabled(plugin.id) and not plugin.isUtility then
            enabled[#enabled + 1] = plugin
        end
    end
    return enabled
end

--- Returns the full catalog of all possible Journal plugins for the Home page and Settings,
--- merging `Constants.KNOWN_PLUGINS` with live metadata from any installed/registered plugins
--- so descriptions, versions, and update dates always stay 100% consistent.
--- @return table[]
function PluginRegistry:GetCatalogPlugins()
    local catalogById = {}
    local list = {}

    for _, known in ipairs(Constants.KNOWN_PLUGINS or {}) do
        local live = self.pluginsById[known.id]
        local isInstalled = (live ~= nil) or isAddOnInstalledOnDisk(known.addonName)
        local isDisabled = ns.Database:IsPluginDisabled(known.id)
        local entry = {
            id = known.id,
            title = (live and live.title) or known.title,
            addonName = (live and live.addonName) or known.addonName,
            icon = (live and live.icon) or known.icon or Constants.ASSETS.FALLBACK_ICON,
            description = (live and live.description) or known.description or "",
            version = (live and live.version) or known.version or "0.1.0",
            lastUpdated = (live and live.lastUpdated) or known.lastUpdated or "2026-11-11",
            apiVersion = (live and live.apiVersion) or Constants.PLUGIN_API_VERSION,
            defaultOrder = (known.id == "home" and 0) or (live and live.defaultOrder) or known.defaultOrder or DEFAULT_PLUGIN_ORDER,
            isUtility = (live and live.isUtility ~= nil and live.isUtility) or (known.isUtility == true) or false,
            isInstalled = isInstalled,
            isLoaded = (live ~= nil),
            isEnabled = isInstalled and (live ~= nil) and (not isDisabled),
        }
        catalogById[entry.id] = entry
        list[#list + 1] = entry
    end

    -- Include any additional custom plugins not listed in KNOWN_PLUGINS
    for _, live in ipairs(self.orderedPlugins) do
        if not catalogById[live.id] then
            local isDisabled = ns.Database:IsPluginDisabled(live.id)
            local entry = {
                id = live.id,
                title = live.title,
                addonName = live.addonName,
                icon = live.icon or Constants.ASSETS.FALLBACK_ICON,
                description = live.description or "",
                version = live.version or "0.1.0",
                lastUpdated = live.lastUpdated or "2026-11-11",
                apiVersion = live.apiVersion or Constants.PLUGIN_API_VERSION,
                defaultOrder = (live.id == "home" and 0) or live.defaultOrder or DEFAULT_PLUGIN_ORDER,
                isUtility = (live.isUtility == true) or false,
                isInstalled = true,
                isLoaded = true,
                isEnabled = not isDisabled,
            }
            catalogById[entry.id] = entry
            list[#list + 1] = entry
        end
    end

    table.sort(list, comparePlugins)
    return list
end

--- Moves `pluginId` to `targetIndex` in the sorted plugin order, saves the new
--- order to `Database`, and immediately updates bottom tabs, Home cards, and Settings rows.
--- Note: "home" is locked in Slot 1 and cannot be moved or displaced.
--- @param pluginId string
--- @param targetIndex number
function PluginRegistry:MovePluginToIndex(pluginId, targetIndex)
    if pluginId == "home" then
        return -- Home cannot be rearranged
    end
    local movingPlugin = self.pluginsById[pluginId]
    if movingPlugin and movingPlugin.isUtility then
        return -- Utility modules cannot be rearranged
    end

    local all = self:GetCatalogPlugins()
    local currentIndex = nil
    for i, item in ipairs(all) do
        if item.id == pluginId then
            currentIndex = i
            break
        end
    end

    if not currentIndex or currentIndex == targetIndex then
        return
    end

    -- Home permanently occupies index 1; targetIndex cannot be slot 1 or less
    if targetIndex < 2 then
        targetIndex = 2
    end

    -- Target index cannot displace utility modules pinned at the bottom
    local maxNonUtilitySlot = 1
    for i, item in ipairs(all) do
        if not item.isUtility then
            maxNonUtilitySlot = i
        end
    end
    if targetIndex > maxNonUtilitySlot then
        targetIndex = maxNonUtilitySlot
    end

    local moved = table.remove(all, currentIndex)
    table.insert(all, targetIndex, moved)

    -- Ensure Home is always in slot 1
    local homeIdx = nil
    for i, item in ipairs(all) do
        if item.id == "home" then
            homeIdx = i
            break
        end
    end
    if homeIdx and homeIdx ~= 1 then
        local homeItem = table.remove(all, homeIdx)
        table.insert(all, 1, homeItem)
    end

    local orderedIds = {}
    for i, item in ipairs(all) do
        orderedIds[i] = item.id
    end

    ns.Database:SavePluginOrderList(orderedIds)
    self:ResortPlugins()

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnPluginsChanged()
    end
    if ns.UI.SettingsPanel and ns.UI.SettingsPanel.Refresh then
        ns.UI.SettingsPanel:Refresh()
    end
end

--- @return number Count of enabled plugins
function PluginRegistry:GetCount()
    return #self:GetOrderedPlugins()
end

--- Enables or disables an installed plugin dynamically and refreshes the bottom tabs.
--- @param pluginId string
--- @param isEnabled boolean
function PluginRegistry:SetPluginEnabled(pluginId, isEnabled)
    local plugin = self.pluginsById[pluginId]
    if not plugin then
        return
    end

    ns.Database:SetPluginDisabled(pluginId, not isEnabled)

    if not isEnabled and ns.Database:GetDefaultLandingPluginId() == pluginId then
        ns.Database:SetDefaultLandingPluginId(nil)
    end

    if not isEnabled and self.activePluginId == pluginId then
        self:ActivateHome()
    end

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnPluginsChanged()
    end
end

--- Toggles or sets a plugin tab as the user's preferred default opening / landing tab.
--- Passing `nil` or the already-selected `defaultLandingPluginId` clears it so the Journal
--- remembers the last-opened tab instead.
--- @param pluginId string|nil
function PluginRegistry:ToggleDefaultLandingPlugin(pluginId)
    if pluginId then
        local plugin = self.pluginsById[pluginId]
        if plugin and plugin.isUtility then
            return -- Utility modules cannot be set as default landing tab
        end
    end
    local current = ns.Database:GetDefaultLandingPluginId()
    if not pluginId or current == pluginId then
        ns.Database:SetDefaultLandingPluginId(nil)
    else
        ns.Database:SetDefaultLandingPluginId(pluginId)
    end

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnPluginsChanged()
    end
    if ns.UI.SettingsPanel and ns.UI.SettingsPanel.Refresh then
        ns.UI.SettingsPanel:Refresh()
    end
end

--- Backwards-compatibility wrapper for `ToggleDefaultLandingPlugin`.
--- @param pluginId string|nil
function PluginRegistry:ToggleHomePlugin(pluginId)
    self:ToggleDefaultLandingPlugin(pluginId)
end

--- @return table|nil
function PluginRegistry:GetActivePlugin()
    if not self.activePluginId then
        return nil
    end
    return self.pluginsById[self.activePluginId]
end

--- Registers built-in core plugins (such as the Home tab module).
function PluginRegistry:RegisterBuiltInPlugins()
    local homePlugin = {
        id = "home",
        title = "Home",
        addonName = "Journal_Base",
        version = Constants.VERSION,
        lastUpdated = Constants.LAST_UPDATED,
        description = "Browse the module catalog, view installed plugin statuses, and discover ecosystem features.",
        apiVersion = Constants.PLUGIN_API_VERSION,
        order = 0,
        defaultOrder = 0,
        icon = Constants.ASSETS.FALLBACK_ICON,
        OnInitialize = function(plugin, canvas, headerBar)
            if ns.UI.HomeView and not ns.UI.HomeView.rootFrame then
                ns.UI.HomeView:Create(canvas)
            elseif ns.UI.HomeView and ns.UI.HomeView.rootFrame then
                ns.UI.HomeView.rootFrame:SetParent(canvas)
                ns.UI.HomeView.rootFrame:ClearAllPoints()
                ns.UI.HomeView.rootFrame:SetAllPoints(canvas)
            end
        end,
        OnActivate = function(plugin, canvas, headerBar)
            if headerBar then
                headerBar:ResetBreadcrumbs("Home", function()
                    PluginRegistry:ActivatePlugin("home")
                end)
            end
            if ns.UI.HomeView and ns.UI.HomeView.rootFrame then
                ns.UI.HomeView.rootFrame:Show()
                ns.UI.HomeView:Refresh()
            end
        end,
        OnDeactivate = function(plugin)
            if ns.UI.HomeView and ns.UI.HomeView.rootFrame then
                ns.UI.HomeView.rootFrame:Hide()
            end
        end,
    }
    self:Register(homePlugin)
end

--- Navigates to the user's configured default opening / landing destination:
---   * If a valid, enabled `defaultLandingPluginId` is set in Settings, activates that plugin tab directly.
---   * If no default is set, activates the first enabled plugin (e.g. Dungeons).
---   * If all plugins are disabled, displays the base catalog page (`ShowCatalogHome`).
function PluginRegistry:ActivateDefaultPlugin()
    local defaultId = ns.Database:GetDefaultLandingPluginId()
    if defaultId and self.pluginsById[defaultId] and not ns.Database:IsPluginDisabled(defaultId) then
        self:ActivatePlugin(defaultId)
        return
    end

    -- If no default landing plugin is set, activate the first enabled plugin (e.g. Dungeons)
    local ordered = self:GetOrderedPlugins()
    if #ordered > 0 then
        self:ActivatePlugin(ordered[1].id)
        return
    end

    self:ShowCatalogHome()
end

--- Backwards-compatibility alias for `ActivateDefaultPlugin`.
function PluginRegistry:ActivateHome()
    self:ActivateDefaultPlugin()
end

--- Displays the Journal Base Home catalog page (listing all possible plugins on parchment),
--- hiding any active plugin canvas and resetting the breadcrumb bar to `Home`.
function PluginRegistry:ShowCatalogHome()
    local current = self:GetActivePlugin()
    if current then
        safeInvokePlugin(current, "OnDeactivate")
        if current.canvas then
            current.canvas:Hide()
        end
    end

    self.activePluginId = nil
    ns.Database:SetLastPluginId(nil)

    if not ns.UI.MainFrame or not ns.UI.MainFrame:IsInitialized() then
        return
    end

    local mainFrame = ns.UI.MainFrame
    local headerBar = mainFrame:GetHeaderBar()
    if headerBar then
        headerBar:ResetBreadcrumbs("Home", function()
            self:ShowCatalogHome()
        end)
    end

    mainFrame:SetPortraitIcon(Constants.ASSETS.JOURNAL_PORTRAIT)
    mainFrame:SetEmptyStateVisible(true)
    mainFrame:ClearTabSelection()
end

--- Activates the specified plugin tab, lazily initializing its canvas on first view.
--- @param pluginId string
--- @return boolean
function PluginRegistry:ActivatePlugin(pluginId)
    local target = self.pluginsById[pluginId]
    if not target or target.isUtility or ns.Database:IsPluginDisabled(pluginId) or not ns.UI.MainFrame or not ns.UI.MainFrame:IsInitialized() then
        return false
    end

    local current = self:GetActivePlugin()
    if current and current.id ~= target.id then
        safeInvokePlugin(current, "OnDeactivate")
        if current.canvas then
            current.canvas:Hide()
        end
    end

    self.activePluginId = target.id
    ns.Database:SetLastPluginId(target.id)

    local mainFrame = ns.UI.MainFrame
    local headerBar = mainFrame:GetHeaderBar()
    if headerBar then
        headerBar:ResetBreadcrumbs("Home", function()
            safeInvokePlugin(target, "OnActivate", target.canvas, headerBar)
        end)
    end

    mainFrame:SetPortraitIcon(target.icon)
    mainFrame:SetEmptyStateVisible(false)

    if not target.isInitialized then
        local parentCanvas = mainFrame:GetContentCanvas()
        local pluginCanvas = CreateFrame("Frame", nil, parentCanvas)
        pluginCanvas:SetAllPoints(parentCanvas)
        target.canvas = pluginCanvas
        target.isInitialized = true
        safeInvokePlugin(target, "OnInitialize", pluginCanvas, headerBar)
    end

    if target.canvas then
        target.canvas:Show()
    end

    safeInvokePlugin(target, "OnActivate", target.canvas, headerBar)
    mainFrame:SelectTabByPluginId(target.id)
    return true
end

--- Dispatches a search query from the header search box to the active plugin.
--- @param queryText string
function PluginRegistry:DispatchSearch(queryText)
    local active = self:GetActivePlugin()
    if not active then
        return
    end
    safeInvokePlugin(active, "OnSearch", queryText or "")
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.PluginRegistry = PluginRegistry
