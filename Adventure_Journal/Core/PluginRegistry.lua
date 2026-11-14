-- ============================================================================
-- Journal_Base - PluginRegistry.lua
-- Plugin registration contract, custom ordering, and xpcall sandboxing.
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
--- Pinned utility/development modules always use their static `defaultOrder`.
local function getEffectiveOrder(plugin)
    if not plugin.isUtility and not plugin.pinLast then
        local custom = ns.Database and ns.Database:GetPluginCustomOrder(plugin.id)
        if type(custom) == "number" then
            return custom
        end
    end
    return plugin.defaultOrder or plugin.order or DEFAULT_PLUGIN_ORDER
end

--- Comparator for sorting plugins left-to-right by effective order then `title`.
--- Utility modules (`isUtility == true`) are pinned to the bottom, and `pinLast == true`
--- modules (such as Development) are always pinned as the very last entry.
local function comparePlugins(a, b)
    local aLast = (a.pinLast == true)
    local bLast = (b.pinLast == true)
    if aLast ~= bLast then
        return not aLast
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
    if C_AddOns and C_AddOns.DoesAddOnExist then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, addonName)
        if ok and exists then
            return true
        end
    end
    -- In WoW 3.3.5 / Classic, GetAddOnInfo requires an integer index 1..GetNumAddOns()
    local getNum = (C_AddOns and C_AddOns.GetNumAddOns) or _G.GetNumAddOns
    local getInfo = (C_AddOns and C_AddOns.GetAddOnInfo) or _G.GetAddOnInfo
    if getNum and getInfo then
        local okNum, count = pcall(getNum)
        if okNum and type(count) == "number" then
            for i = 1, count do
                local okInfo, name = pcall(getInfo, i)
                if okInfo and name == addonName then
                    return true
                end
            end
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
    local hasTab = (pluginDef.hasTab == true) or (not isUtility)
    local alignRight = (pluginDef.alignRight == true)
    local pinLast = (pluginDef.pinLast == true)
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
        hasTab = hasTab,
        alignRight = alignRight,
        pinLast = pinLast,
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

--- Returns all enabled tab-bearing plugins in their current sort order (including unloaded modules
--- that were just enabled and are awaiting a `/reload` so their tab displays the reload prompt).
--- @return table[]
function PluginRegistry:GetOrderedPlugins()
    self:ResortPlugins()
    local enabled = {}
    for _, plugin in ipairs(self.orderedPlugins) do
        if not ns.Database:IsPluginDisabled(plugin.id) and (not plugin.isUtility or plugin.hasTab) then
            enabled[#enabled + 1] = plugin
        end
    end
    return enabled
end

--- Immediately unloads a module's data tables, event frames, and UI controllers from memory,
--- marking it as unloaded so re-enabling requires a UI `/reload`.
--- @param pluginId string
--- @param skipGC boolean|nil
function PluginRegistry:UnloadPlugin(pluginId, skipGC)
    local plugin = self.pluginsById[pluginId]
    if not plugin or plugin.isUnloaded then
        return
    end

    safeInvokePlugin(plugin, "OnUnload")

    if plugin.canvas then
        plugin.canvas:Hide()
    end

    plugin.canvas = nil
    plugin.isInitialized = false
    plugin.isUnloaded = true
    plugin.OnInitialize = nil
    plugin.OnActivate = nil
    plugin.OnDeactivate = nil
    plugin.OnSearch = nil
    plugin.OnUnload = nil

    if not skipGC and collectgarbage then
        collectgarbage("collect")
    end
end

--- Purges all disabled modules from memory at `ADDON_LOADED` time so disabled modules
--- consume zero runtime memory until the user re-enables them and executes a `/reload`.
function PluginRegistry:PurgeDisabledModules()
    local purgedAny = false
    for _, plugin in ipairs(self.orderedPlugins) do
        if ns.Database:IsPluginDisabled(plugin.id) and not plugin.isUnloaded then
            self:UnloadPlugin(plugin.id, true)
            purgedAny = true
        end
    end
    if purgedAny and collectgarbage then
        collectgarbage("collect")
    end
end

--- Returns the full catalog of all possible Journal plugins for Settings,
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
        local isUnloaded = (live == nil) or (live.isUnloaded == true)
        local pendingReload = (live ~= nil and live.isUnloaded == true and not isDisabled)
        local entry = {
            id = known.id,
            title = (live and live.title) or known.title,
            addonName = (live and live.addonName) or known.addonName,
            icon = (live and live.icon) or known.icon or Constants.ASSETS.FALLBACK_ICON,
            description = (live and live.description) or known.description or "",
            version = (live and live.version) or known.version or "0.1.0",
            lastUpdated = (live and live.lastUpdated) or known.lastUpdated or "2026-11-11",
            apiVersion = (live and live.apiVersion) or Constants.PLUGIN_API_VERSION,
            defaultOrder = (live and live.defaultOrder) or known.defaultOrder or DEFAULT_PLUGIN_ORDER,
            isUtility = (live and live.isUtility ~= nil and live.isUtility) or (known.isUtility == true) or false,
            hasTab = (live and live.hasTab ~= nil and live.hasTab) or (known.hasTab == true) or false,
            alignRight = (live and live.alignRight ~= nil and live.alignRight) or (known.alignRight == true) or false,
            pinLast = (live and live.pinLast ~= nil and live.pinLast) or (known.pinLast == true) or false,
            isInstalled = isInstalled,
            isLoaded = (live ~= nil) and not isUnloaded,
            isUnloaded = isUnloaded,
            pendingReload = pendingReload,
            isEnabled = isInstalled and (live ~= nil) and (not isUnloaded) and (not isDisabled),
        }
        catalogById[entry.id] = entry
        list[#list + 1] = entry
    end

    -- Include any additional custom plugins not listed in KNOWN_PLUGINS
    for _, live in ipairs(self.orderedPlugins) do
        if not catalogById[live.id] then
            local isDisabled = ns.Database:IsPluginDisabled(live.id)
            local isUnloaded = (live.isUnloaded == true)
            local pendingReload = (isUnloaded and not isDisabled)
            local entry = {
                id = live.id,
                title = live.title,
                addonName = live.addonName,
                icon = live.icon or Constants.ASSETS.FALLBACK_ICON,
                description = live.description or "",
                version = live.version or "0.1.0",
                lastUpdated = live.lastUpdated or "2026-11-11",
                apiVersion = live.apiVersion or Constants.PLUGIN_API_VERSION,
                defaultOrder = live.defaultOrder or DEFAULT_PLUGIN_ORDER,
                isUtility = (live.isUtility == true) or false,
                hasTab = (live.hasTab == true) or false,
                alignRight = (live.alignRight == true) or false,
                pinLast = (live.pinLast == true) or false,
                isInstalled = true,
                isLoaded = not isUnloaded,
                isUnloaded = isUnloaded,
                pendingReload = pendingReload,
                isEnabled = (not isUnloaded) and (not isDisabled),
            }
            catalogById[entry.id] = entry
            list[#list + 1] = entry
        end
    end

    table.sort(list, comparePlugins)
    return list
end

--- Moves `pluginId` to `targetIndex` in the sorted plugin order, saves the new
--- order to `Database`, and immediately updates bottom tabs and Settings rows.
--- @param pluginId string
--- @param targetIndex number
function PluginRegistry:MovePluginToIndex(pluginId, targetIndex)
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

    if targetIndex < 1 then
        targetIndex = 1
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

--- Resolves the active default landing plugin ID, guaranteeing that one enabled
--- non-utility module is always selected as the default (preferring `"dungeons"`).
--- @return string
function PluginRegistry:GetEffectiveDefaultLandingPluginId()
    local savedId = ns.Database:GetDefaultLandingPluginId()
    local savedPlugin = savedId and self.pluginsById[savedId]
    if savedPlugin and not savedPlugin.isUtility and not savedPlugin.isUnloaded and not ns.Database:IsPluginDisabled(savedId) then
        return savedId
    end

    local dungeonsPlugin = self.pluginsById["dungeons"]
    if dungeonsPlugin and not dungeonsPlugin.isUtility and not dungeonsPlugin.isUnloaded and not ns.Database:IsPluginDisabled("dungeons") then
        ns.Database:SetDefaultLandingPluginId("dungeons")
        return "dungeons"
    end

    for _, plugin in ipairs(self:GetOrderedPlugins()) do
        if not plugin.isUtility then
            ns.Database:SetDefaultLandingPluginId(plugin.id)
            return plugin.id
        end
    end

    return savedId or "dungeons"
end

--- Enables or disables an installed plugin. Disabling a module immediately unloads its data
--- and UI from memory; re-enabling an unloaded module stages it for the next UI `/reload`.
--- @param pluginId string
--- @param isEnabled boolean
function PluginRegistry:SetPluginEnabled(pluginId, isEnabled)
    local plugin = self.pluginsById[pluginId]
    if not plugin then
        return
    end

    ns.Database:SetPluginDisabled(pluginId, not isEnabled)

    if not isEnabled then
        if ns.Database:GetDefaultLandingPluginId() == pluginId then
            -- Reassign default landing tab to another enabled non-utility module so there is always one selected
            self:GetEffectiveDefaultLandingPluginId()
        end

        if self.activePluginId == pluginId then
            self:ActivateDefaultPlugin()
        end

        self:UnloadPlugin(pluginId)
    elseif not self.activePluginId and (not plugin.isUtility or plugin.hasTab) then
        self:ActivatePlugin(pluginId)
    end

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnPluginsChanged()
    end
    if ns.UI.SettingsPanel and ns.UI.SettingsPanel.Refresh then
        ns.UI.SettingsPanel:Refresh()
    end
end

--- Sets `pluginId` as the user's preferred default opening / landing tab using radio-button
--- semantics ("there always must be one" — clicking the active default keeps it selected).
--- @param pluginId string|nil
function PluginRegistry:SetDefaultLandingPlugin(pluginId)
    if not pluginId or pluginId == "" then
        return
    end
    local plugin = self.pluginsById[pluginId]
    if not plugin or plugin.isUtility or plugin.isUnloaded or ns.Database:IsPluginDisabled(pluginId) then
        return -- Only installed, enabled, loaded, non-utility modules can be selected
    end

    ns.Database:SetDefaultLandingPluginId(pluginId)

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnPluginsChanged()
    end
    if ns.UI.SettingsPanel and ns.UI.SettingsPanel.Refresh then
        ns.UI.SettingsPanel:Refresh()
    end
end

--- Radio-button wrapper for `SetDefaultLandingPlugin` (never clears to nil).
--- @param pluginId string|nil
function PluginRegistry:ToggleDefaultLandingPlugin(pluginId)
    self:SetDefaultLandingPlugin(pluginId)
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

--- Registers built-in core plugins (reserved for future built-in extensions).
function PluginRegistry:RegisterBuiltInPlugins()
end

--- Navigates to the user's configured default opening / landing destination:
---   * If a valid, enabled `defaultLandingPluginId` is set in Settings, activates that plugin tab directly.
---   * If no default is set, activates the first enabled plugin (e.g. Dungeons).
---   * If all plugins are disabled, deactivates all views.
function PluginRegistry:ActivateDefaultPlugin()
    local defaultId = ns.Database:GetDefaultLandingPluginId()
    local defaultPlugin = defaultId and self.pluginsById[defaultId]
    if defaultPlugin and not defaultPlugin.isUtility and not defaultPlugin.isUnloaded and not ns.Database:IsPluginDisabled(defaultId) then
        self:ActivatePlugin(defaultId)
        return
    end

    -- If no default landing plugin is set, activate the first enabled non-utility plugin (e.g. Dungeons)
    local ordered = self:GetOrderedPlugins()
    for _, plugin in ipairs(ordered) do
        if not plugin.isUtility then
            self:ActivatePlugin(plugin.id)
            return
        end
    end
    if #ordered > 0 then
        self:ActivatePlugin(ordered[1].id)
        return
    end

    self:DeactivateAll()
end

--- Backwards-compatibility alias for `ActivateDefaultPlugin`.
function PluginRegistry:ActivateHome()
    self:ActivateDefaultPlugin()
end

--- Deactivates all module views and displays the empty state if all plugins are disabled.
function PluginRegistry:DeactivateAll()
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
        headerBar:ResetBreadcrumbs("", nil)
    end

    mainFrame:SetPortraitIcon(Constants.ASSETS.JOURNAL_PORTRAIT)
    if mainFrame.SetReloadPromptVisible then
        mainFrame:SetReloadPromptVisible(false)
    end
    mainFrame:SetEmptyStateVisible(true)
    mainFrame:ClearTabSelection()
end

--- Backwards-compatibility alias for `DeactivateAll`.
function PluginRegistry:ShowCatalogHome()
    self:DeactivateAll()
end

--- Activates the specified plugin tab, lazily initializing its canvas on first view.
--- If the plugin was unloaded and re-enabled during the current session without a `/reload`,
--- displays the `"Required reload to enable this"` prompt on the module page.
--- @param pluginId string
--- @return boolean
function PluginRegistry:ActivatePlugin(pluginId)
    local target = self.pluginsById[pluginId]
    if not target or (target.isUtility and not target.hasTab) or ns.Database:IsPluginDisabled(pluginId) or not ns.UI.MainFrame or not ns.UI.MainFrame:IsInitialized() then
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

    mainFrame:SetPortraitIcon(target.icon)
    mainFrame:SetEmptyStateVisible(false)

    if target.isUnloaded then
        if headerBar then
            headerBar:ResetBreadcrumbs("Home", nil)
        end
        if mainFrame.SetReloadPromptVisible then
            mainFrame:SetReloadPromptVisible(true, target.title)
        end
        mainFrame:SelectTabByPluginId(target.id)
        return true
    end

    if mainFrame.SetReloadPromptVisible then
        mainFrame:SetReloadPromptVisible(false)
    end

    if headerBar then
        headerBar:ResetBreadcrumbs("Home", function()
            safeInvokePlugin(target, "OnActivate", target.canvas, headerBar)
        end)
    end

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
