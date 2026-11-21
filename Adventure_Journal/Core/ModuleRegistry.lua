-- ============================================================================
-- Adventure Journal - Core/ModuleRegistry.lua
-- Module registration contract, ordering, and xpcall sandboxing.
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

local DEFAULT_MODULE_ORDER = 100

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Returns the effective sort order for a module (`module.defaultOrder`).
local function getEffectiveOrder(module)
    return module.defaultOrder or module.order or DEFAULT_MODULE_ORDER
end

--- Comparator for sorting modules left-to-right by effective order then `title`.
--- Utility modules (`isUtility == true`) are pinned to the bottom.
local function compareModules(a, b)
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

--- Returns the method's results after a successful `xpcall`, nothing after an error.
local function successResults(ok, ...)
    if ok then
        return ...
    end
end

--- Safely invokes a method on a module using `xpcall` so that an
--- error in one module never breaks the Journal. Returns the method's results.
--- @param module table
--- @param methodName string
local function safeInvokeModule(module, methodName, ...)
    if type(module) ~= "table" then
        return
    end
    local fn = module[methodName]
    if type(fn) ~= "function" then
        return
    end

    local errorHandler = (type(CallErrorHandler) == "function" and CallErrorHandler)
        or function(err)
            if _G.JournalBase then
                _G.JournalBase:Print("Module error (" .. tostring(module.id) .. "." .. methodName .. "): " .. tostring(err))
            end
        end

    return successResults(xpcall(fn, errorHandler, module, ...))
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local ModuleRegistry = {
    modulesById = {},
    orderedModules = {},
    activeModuleId = nil,
}

--- Validates and registers a module with the Journal.
--- @param moduleDef table `{ id, title, order?, description?, icon?, defaultDisabled?, OnInitialize?, OnActivate?, OnDeactivate?, OnSearch?, OnHome?, WantsWindowFocus?, OnWindowFocus? }`
---   * `OnActivate`: the tab was selected; may restore the page the user left open.
---   * `OnHome`: the Home breadcrumb was clicked; show the module's root page (falls back to `OnActivate`).
---   * `WantsWindowFocus`: return true to become the active tab when the window opens.
---   * `OnWindowFocus`: called after the module was activated because it wanted focus.
--- @return boolean success, string|nil errorMessage
function ModuleRegistry:Register(moduleDef)
    if type(moduleDef) ~= "table" then
        return false, "RegisterModule expected a table."
    end

    local id = moduleDef.id
    local title = moduleDef.title
    if type(id) ~= "string" or id == "" then
        return false, "Module definition requires a non-empty string 'id'."
    end
    if type(title) ~= "string" or title == "" then
        return false, "Module '" .. id .. "' requires a non-empty string 'title'."
    end
    if self.modulesById[id] then
        return false, "Module '" .. id .. "' is already registered."
    end

    local defaultOrder = tonumber(moduleDef.order) or DEFAULT_MODULE_ORDER
    local isUtility = (moduleDef.isUtility == true)
    local hasTab = (moduleDef.hasTab == true) or (not isUtility)
    local module = {
        id = id,
        title = title,
        addonName = tostring(moduleDef.addonName or ("Journal_" .. title)),
        description = moduleDef.description,
        icon = moduleDef.icon or Constants.ASSETS.FALLBACK_ICON,
        defaultOrder = defaultOrder,
        order = defaultOrder,
        isUtility = isUtility,
        hasTab = hasTab,
        OnInitialize = moduleDef.OnInitialize,
        OnActivate = moduleDef.OnActivate,
        OnDeactivate = moduleDef.OnDeactivate,
        OnSearch = moduleDef.OnSearch,
        OnHome = moduleDef.OnHome,
        WantsWindowFocus = moduleDef.WantsWindowFocus,
        OnWindowFocus = moduleDef.OnWindowFocus,
        isInitialized = false,
        canvas = nil,
    }

    if moduleDef.defaultDisabled == true then
        ns.Settings:SetModuleDefaultDisabled(id)
    end

    self.modulesById[id] = module
    self.orderedModules[#self.orderedModules + 1] = module
    self:ResortModules()

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnModulesChanged()
    end
    if ns.UI.SettingsPanel and ns.UI.SettingsPanel.Refresh then
        ns.UI.SettingsPanel:Refresh()
    end

    return true, nil
end

--- Re-sorts `self.orderedModules` by each module's `defaultOrder`.
function ModuleRegistry:ResortModules()
    table.sort(self.orderedModules, compareModules)
end

--- @param moduleId string
--- @return table|nil
function ModuleRegistry:GetModule(moduleId)
    return self.modulesById[moduleId]
end

--- Returns all installed/registered modules in their current sort order (including disabled ones).
--- @return table[]
function ModuleRegistry:GetAllModules()
    self:ResortModules()
    return self.orderedModules
end

--- Returns all enabled tab-bearing modules in their current sort order (including unloaded modules
--- that were just enabled and are awaiting a `/reload` so their tab displays the reload prompt).
--- @return table[]
function ModuleRegistry:GetOrderedModules()
    self:ResortModules()
    local enabled = {}
    for _, module in ipairs(self.orderedModules) do
        if not ns.Settings:IsModuleDisabled(module.id) and (not module.isUtility or module.hasTab) then
            enabled[#enabled + 1] = module
        end
    end
    return enabled
end

--- Immediately unloads a module's data tables, event frames, and UI controllers from memory,
--- marking it as unloaded so re-enabling requires a UI `/reload`.
--- @param moduleId string
--- @param skipGC boolean|nil
function ModuleRegistry:UnloadModule(moduleId, skipGC)
    local module = self.modulesById[moduleId]
    if not module or module.isUnloaded then
        return
    end

    safeInvokeModule(module, "OnUnload")

    if module.canvas then
        module.canvas:Hide()
    end

    module.canvas = nil
    module.isInitialized = false
    module.isUnloaded = true
    module.OnInitialize = nil
    module.OnActivate = nil
    module.OnDeactivate = nil
    module.OnSearch = nil
    module.OnHome = nil
    module.WantsWindowFocus = nil
    module.OnWindowFocus = nil
    module.OnUnload = nil

    if not skipGC and collectgarbage then
        collectgarbage("collect")
    end
end

--- Purges all disabled modules from memory at `ADDON_LOADED` time so disabled modules
--- consume zero runtime memory until the user re-enables them and executes a `/reload`.
function ModuleRegistry:PurgeDisabledModules()
    local purgedAny = false
    for _, module in ipairs(self.orderedModules) do
        if ns.Settings:IsModuleDisabled(module.id) and not module.isUnloaded then
            self:UnloadModule(module.id, true)
            purgedAny = true
        end
    end
    if purgedAny and collectgarbage then
        collectgarbage("collect")
    end
end

--- Returns the catalog of installed and registered Journal modules for Settings,
--- populating strictly from modules present and registered in the modules ecosystem.
--- @return table[]
function ModuleRegistry:GetCatalogModules()
    local list = {}

    for _, live in ipairs(self.orderedModules) do
        local isDisabled = ns.Settings:IsModuleDisabled(live.id)
        local isUnloaded = (live.isUnloaded == true)
        local pendingReload = (isUnloaded and not isDisabled)
        local entry = {
            id = live.id,
            title = live.title,
            addonName = live.addonName,
            icon = live.icon or Constants.ASSETS.FALLBACK_ICON,
            description = live.description or "",
            defaultOrder = live.defaultOrder or DEFAULT_MODULE_ORDER,
            isUtility = (live.isUtility == true) or false,
            hasTab = (live.hasTab == true) or false,
            isInstalled = true,
            isLoaded = not isUnloaded,
            isUnloaded = isUnloaded,
            pendingReload = pendingReload,
            isEnabled = (not isUnloaded) and (not isDisabled),
        }
        list[#list + 1] = entry
    end

    table.sort(list, compareModules)
    return list
end

--- @return number Count of enabled modules
function ModuleRegistry:GetCount()
    return #self:GetOrderedModules()
end

--- Enables or disables an installed module. Disabling a module immediately unloads its data
--- and UI from memory; re-enabling an unloaded module stages it for the next UI `/reload`.
--- @param moduleId string
--- @param isEnabled boolean
function ModuleRegistry:SetModuleEnabled(moduleId, isEnabled)
    local module = self.modulesById[moduleId]
    if not module then
        return
    end

    ns.Settings:SetModuleDisabled(moduleId, not isEnabled)

    if not isEnabled then
        if self.activeModuleId == moduleId then
            self:ActivateDefaultModule()
        end

        self:UnloadModule(moduleId)
    elseif not self.activeModuleId and (not module.isUtility or module.hasTab) then
        self:ActivateModule(moduleId)
    end

    if ns.UI.MainFrame and ns.UI.MainFrame:IsInitialized() then
        ns.UI.MainFrame:OnModulesChanged()
    end
    if ns.UI.SettingsPanel and ns.UI.SettingsPanel.Refresh then
        ns.UI.SettingsPanel:Refresh()
    end
end

--- @return table|nil
function ModuleRegistry:GetActiveModule()
    if not self.activeModuleId then
        return nil
    end
    return self.modulesById[self.activeModuleId]
end

--- Opens the tab the player used last (saved across sessions) while it is still enabled and loaded;
--- otherwise the first enabled module (e.g. Dungeons). With every module disabled, deactivates all views.
function ModuleRegistry:ActivateDefaultModule()
    local lastId = ns.Settings:GetLastModuleId()
    local lastModule = lastId and self.modulesById[lastId]
    if lastModule and not lastModule.isUtility and not lastModule.isUnloaded and not ns.Settings:IsModuleDisabled(lastId) then
        self:ActivateModule(lastId)
        return
    end

    -- The first enabled non-utility module (e.g. Dungeons)
    local ordered = self:GetOrderedModules()
    for _, module in ipairs(ordered) do
        if not module.isUtility then
            self:ActivateModule(module.id)
            return
        end
    end
    if #ordered > 0 then
        self:ActivateModule(ordered[1].id)
        return
    end

    self:DeactivateAll()
end

--- Deactivates all module views and displays the empty state if all modules are disabled.
function ModuleRegistry:DeactivateAll()
    local current = self:GetActiveModule()
    if current then
        safeInvokeModule(current, "OnDeactivate")
        if current.canvas then
            current.canvas:Hide()
        end
    end

    self.activeModuleId = nil
    ns.Settings:SetLastModuleId(nil)

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

--- Activates the specified module tab, lazily initializing its canvas on first view.
--- If the module was unloaded and re-enabled during the current session without a `/reload`,
--- displays the `"Reload Required to Enable This"` prompt on the module page.
--- @param moduleId string
--- @return boolean
function ModuleRegistry:ActivateModule(moduleId)
    local target = self.modulesById[moduleId]
    if not target or (target.isUtility and not target.hasTab) or ns.Settings:IsModuleDisabled(moduleId) or not ns.UI.MainFrame or not ns.UI.MainFrame:IsInitialized() then
        return false
    end

    local current = self:GetActiveModule()
    if current and current.id ~= target.id then
        safeInvokeModule(current, "OnDeactivate")
        if current.canvas then
            current.canvas:Hide()
        end
    end

    self.activeModuleId = target.id
    ns.Settings:SetLastModuleId(target.id)

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
        mainFrame:SelectTabByModuleId(target.id)
        return true
    end

    if mainFrame.SetReloadPromptVisible then
        mainFrame:SetReloadPromptVisible(false)
    end

    if headerBar then
        headerBar:ResetBreadcrumbs("Home", function()
            self:ShowModuleHome(target)
        end)
    end

    if not target.isInitialized then
        local parentCanvas = mainFrame:GetContentCanvas()
        local moduleCanvas = CreateFrame("Frame", nil, parentCanvas)
        moduleCanvas:SetAllPoints(parentCanvas)
        target.canvas = moduleCanvas
        target.isInitialized = true
        safeInvokeModule(target, "OnInitialize", moduleCanvas, headerBar)
    end

    if target.canvas then
        target.canvas:Show()
    end

    safeInvokeModule(target, "OnActivate", target.canvas, headerBar)
    mainFrame:SelectTabByModuleId(target.id)
    return true
end

--- Shows a module's root page (`OnHome`, or `OnActivate` for modules without one).
--- @param module table|nil
function ModuleRegistry:ShowModuleHome(module)
    if not module or not module.isInitialized then
        return
    end
    local headerBar = ns.UI.MainFrame and ns.UI.MainFrame:GetHeaderBar()
    local method = module.OnHome and "OnHome" or "OnActivate"
    safeInvokeModule(module, method, module.canvas, headerBar)
end

--- Shows the active module's root page.
function ModuleRegistry:ShowActiveModuleHome()
    self:ShowModuleHome(self:GetActiveModule())
end

--- Activates the first enabled module that wants focus when the window opens
--- (for example, Dungeons while the player is inside a dungeon).
--- @return boolean focused
function ModuleRegistry:FocusModuleForWindowShow()
    for _, module in ipairs(self:GetOrderedModules()) do
        if not module.isUnloaded and safeInvokeModule(module, "WantsWindowFocus") == true
            and self:ActivateModule(module.id) then
            safeInvokeModule(module, "OnWindowFocus")
            return true
        end
    end
    return false
end

--- Dispatches a search query from the header search box to the active module.
--- @param queryText string
function ModuleRegistry:DispatchSearch(queryText)
    local active = self:GetActiveModule()
    if not active then
        return
    end
    safeInvokeModule(active, "OnSearch", queryText or "")
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.ModuleRegistry = ModuleRegistry
