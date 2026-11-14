-- ============================================================================
-- Adventure Journal - Core/HolidayManager.lua
-- Detection and scheduling service for in-game seasonal holidays and events.
-- Supports live C_Calendar queries, legacy CalendarGetDayEvent API,
-- and real-world calendar date ranges as a reliable fallback.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Locals
-- ----------------------------------------------------------------------------
local _G = _G
local pairs, ipairs, type, string = pairs, ipairs, type, string
local strlower, strfind = string.lower, string.find
local date, time = os and os.date or date, os and os.time or time
local C_Calendar = _G.C_Calendar
local CreateFrame = CreateFrame
local pcall = pcall

-- ----------------------------------------------------------------------------
-- 2. Module Definition
-- ----------------------------------------------------------------------------
local HolidayManager = {}
ns.HolidayManager = HolidayManager

-- ----------------------------------------------------------------------------
-- 3. Boss to Holiday Mappings
-- ----------------------------------------------------------------------------
-- Boss name to canonical holiday identifier mapping
local BOSS_TO_HOLIDAY = {
    ["crown chemical co."] = "love is in the air",
    ["apothecary hummel"] = "love is in the air",
    ["apothecary hummel <crown chemical co.>"] = "love is in the air",
    ["headless horseman"] = "hallow's end",
    ["coren direbrew"] = "brewfest",
    ["lord ahune"] = "midsummer fire festival",
    ["ahune"] = "midsummer fire festival",
}

-- ----------------------------------------------------------------------------
-- 4. Holiday Activity Detection
-- ----------------------------------------------------------------------------

--- Checks whether a given holiday is currently active on the server.
--- @param holidayName string
--- @return boolean isActive, string reason
function HolidayManager:IsHolidayActive(holidayName)
    if not holidayName or holidayName == "" then
        return false, "No holiday specified"
    end

    local normQuery = strlower(holidayName)

    -- 1. Live Calendar API Query (C_Calendar)
    if C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent then
        local dateInfo = C_Calendar.GetDate and C_Calendar.GetDate()
        local day = dateInfo and (dateInfo.monthDay or dateInfo.day)
        if not day and _G.CalendarGetDate then
            local _, _, d = _G.CalendarGetDate()
            day = d
        end

        if day then
            local numEvents = C_Calendar.GetNumDayEvents(0, day) or 0
            for i = 1, numEvents do
                local event = C_Calendar.GetDayEvent(0, day, i)
                if event and event.title then
                    local eventTitle = strlower(event.title)
                    if strfind(eventTitle, normQuery, 1, true) or strfind(normQuery, eventTitle, 1, true) then
                        return true, "calendar"
                    end
                end
            end
        end
    end

    -- 1b. Legacy Calendar API Fallback (_G.CalendarGetDayEvent)
    if _G.CalendarGetNumDayEvents and _G.CalendarGetDayEvent and _G.CalendarGetDate then
        local _, _, day = _G.CalendarGetDate()
        if day then
            local numEvents = _G.CalendarGetNumDayEvents(0, day) or 0
            for i = 1, numEvents do
                local title, _, _, calendarType = _G.CalendarGetDayEvent(0, day, i)
                if title and (calendarType == "HOLIDAY" or calendarType == 1) then
                    local eventTitle = strlower(title)
                    if strfind(eventTitle, normQuery, 1, true) or strfind(normQuery, eventTitle, 1, true) then
                        return true, "calendar_legacy"
                    end
                end
            end
        end
    end

    -- Strictly relies on in-game server Calendar API. No real-world date fallback.
    return false, "inactive"
end

--- Determines whether an event boss encounter is currently active.
--- @param boss table
--- @return boolean
function HolidayManager:IsBossEventActive(boss)
    if not boss or not boss.isEvent then
        return false
    end

    local holidayName = boss.holiday
    if not holidayName and boss.name then
        holidayName = BOSS_TO_HOLIDAY[strlower(boss.name)]
    end

    if not holidayName then
        return true
    end

    return self:IsHolidayActive(holidayName)
end

--- Evaluates whether an event boss should be displayed given the user's setting.
--- @param boss table
--- @param setting string|"always"|"holiday"|"never"|boolean
--- @return boolean
function HolidayManager:ShouldShowEventBoss(boss, setting)
    local mode = setting
    if mode == nil then
        mode = "holiday"
    elseif mode == true then
        mode = "holiday"
    elseif mode == false then
        mode = "never"
    end

    if mode == "always" then
        return true
    elseif mode == "never" then
        return false
    elseif mode == "holiday" then
        return self:IsBossEventActive(boss)
    end

    return self:IsBossEventActive(boss)
end

-- ----------------------------------------------------------------------------
-- 5. Lifecycle & Calendar Sync Listener
-- ----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if C_Calendar and C_Calendar.OpenCalendar then
            pcall(C_Calendar.OpenCalendar)
        elseif _G.OpenCalendar then
            pcall(_G.OpenCalendar)
        end
    elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
        if _G.JournalBase and _G.JournalBase.OnDungeonSettingChanged then
            _G.JournalBase:OnDungeonSettingChanged("showEventBosses")
        end
    end
end)
