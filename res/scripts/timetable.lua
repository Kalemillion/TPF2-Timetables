--[[
Module: timetable
Role: Core timetable data model and departure logic.

Primary responsibilities:
- Store and normalize timetable objects received from GUI or saved state.
- Provide query APIs and caches used by GUI and scheduler.
- Evaluate departure conditions (ArrDep, debounce, auto_debounce) and manage per-stop vehicle waiting state.
- Utility conversions between slot/time representations.

Dependencies:
- `timetable_helper` — TF2 API wrappers and vehicle/line helpers.
- `guard` — light validation helpers.

Points of vigilance (also noted in docs/ARCHITECTURE.md):
- Cache invalidation: derived caches must be invalidated whenever `timetableObject` mutates.
- Legacy migration: `setTimetableObject` converts string IDs to numbers and migrates legacy `conditions.condition` -> `conditions.type`.
- Vehicles waiting lifecycle: `vehiclesWaiting` entries must be removed on departure to avoid memory growth and incorrect slot assignment.
- Time arithmetic carefully handles 3600-second wrap-around; see `afterArrivalSlot`, `getTimeDifference`, and related helpers.
]]

local timetableHelper            = require "timetable_helper"
local guard                      = require "guard"

local timetable                  = {}
local timetableObject            = {}

-- Per-line runtime frequencies (seconds)
local _lineFrequency             = {}
-- Derived caches (lazily computed)
local _constraintsByStationCache = nil
local _allConditionsCache        = nil
-- Simple set of lines that currently have timetables (populated on init)
local timetableLinesCache        = {}

--[[
Function: invalidateDerivedCaches
Purpose: Clear any cached views derived from `timetableObject`.
Notes:
- Must be called after any mutation to `timetableObject`.
]]
local function invalidateDerivedCaches()
    _constraintsByStationCache = nil
    _allConditionsCache = nil
end

--[[ Function: getCachedTimetableLines
Returns: table (map of line -> true)
Purpose: Expose the lightweight cache of lines that declare a timetable. ]]
function timetable.getCachedTimetableLines()
    return timetableLinesCache
end

--[[ Function: initializeTimetableLinesCache
Purpose: Rebuild `timetableLinesCache` from `timetableObject`.
Notes:
- Intended to be called by GUI on load to avoid expensive queries later.
- Does not validate line existence; it's a simple index of entries that report `hasTimetable`. ]]
function timetable.initializeTimetableLinesCache()
    timetableLinesCache = {}
    for line, lineInfo in pairs(timetableObject) do
        if timetable.hasTimetable(line) then
            timetableLinesCache[line] = true
        end
    end
end

--[[ Function: addLineToTimetableCache
Params: line (number)
Purpose: Mark a line as containing a timetable in the lightweight cache. ]]
function timetable.addLineToTimetableCache(line)
    timetableLinesCache[line] = true
end

--[[ Function: removeLineFromTimetableCache
Params: line (number)
Purpose: Remove a line from the lightweight timetable cache. ]]
function timetable.removeLineFromTimetableCache(line)
    timetableLinesCache[line] = nil
end

--[[ Function: getTimetableObject
Returns: table
Purpose: Return the internal `timetableObject` reference (read-only by convention). ]]
function timetable.getTimetableObject()
    return timetableObject
end

--[[ Function: setTimetableObject
Params: t (table)
Purpose:
- Safely replace the stored timetable object with `t`.
- Performs normalization & migration of legacy formats:
  - converts string numeric line IDs to numbers,
  - ensures `stations` is a table,
  - ensures each station has a `conditions` table with `type`,
  - migrates `conditions.condition` -> `conditions.type`,
  - ensures `vehiclesWaiting` exists only for ArrDep and is a table when present.
Returns: none
Notes:
- If input is not a table, resets to an empty timetable.
- Clears derived caches at the end.
]]
function timetable.setTimetableObject(t)
    if type(t) ~= "table" then
        timetableObject = {}
        invalidateDerivedCaches()
        return
    end

    -- Patch string-number keys to numeric keys when possible.
    -- This preserves maps saved or sent with JSON-style string keys.
    local patch = {}
    for lineID, _ in pairs(t) do
        if type(lineID) == "string" and tonumber(lineID) ~= nil then
            patch[#patch + 1] = lineID
        end
    end
    for _, lineID in ipairs(patch) do
        local info = t[lineID]
        t[lineID] = nil
        t[tonumber(lineID)] = info
    end

    -- Per-line normalization and defensive initialization.
    for _, info in pairs(t) do
        if type(info) == "table" then
            -- `frequency` is runtime-only; drop persisted values to avoid surprises.
            info.frequency = nil

            if type(info.stations) ~= "table" then
                info.stations = {}
            end

            if info.hasTimetable == nil then
                info.hasTimetable = false
            end

            for stopNr, stopInfo in pairs(info.stations) do
                -- Normalize numeric station indices stored as strings.
                if type(stopNr) == "string" and tonumber(stopNr) ~= nil then
                    info.stations[tonumber(stopNr)] = stopInfo
                    info.stations[stopNr] = nil
                elseif type(stopInfo) ~= "table" then
                    -- Ensure every station entry is a table; provide a safe default conditions shape.
                    info.stations[stopNr] = { conditions = { type = "None" } }
                    stopInfo = info.stations[stopNr]
                end

                -- Ensure `conditions` exists and is a table.
                if type(stopInfo.conditions) ~= "table" then
                    stopInfo.conditions = { type = "None" }
                end

                -- Migrate legacy `conditions.condition` (string) -> `conditions.type`.
                if stopInfo.conditions.type == nil and type(stopInfo.conditions.condition) == "string" then
                    stopInfo.conditions.type = stopInfo.conditions.condition
                    stopInfo.conditions.condition = nil
                end

                if type(stopInfo.conditions.type) ~= "string" then
                    stopInfo.conditions.type = "None"
                end

                -- For ArrDep, ensure ArrDep slot list and vehiclesWaiting map exist.
                if stopInfo.conditions.type == "ArrDep" then
                    if type(stopInfo.conditions.ArrDep) ~= "table" then
                        stopInfo.conditions.ArrDep = {}
                    end
                    if type(stopInfo.vehiclesWaiting) ~= "table" then
                        stopInfo.vehiclesWaiting = {}
                    end
                else
                    -- For non-ArrDep types, remove vehiclesWaiting to avoid stale structures.
                    stopInfo.vehiclesWaiting = nil
                end
            end
        end
    end

    timetableObject = t
    invalidateDerivedCaches()
end

--[[ Function: setConditionType
Params: line, stationNumber, condType (string)
Purpose:
- Ensure the station entry exists and set `conditions.type`.
- Create `vehiclesWaiting` for ArrDep.
Returns:
- -1 on invalid inputs; otherwise returns nothing.
Notes:
- Also invalidates derived caches to ensure queries are up-to-date.
]]
function timetable.setConditionType(line, stationNumber, condType)
    if not (line and stationNumber) then return -1 end

    local stationID = timetableHelper.getStationID(line, stationNumber)
    if not timetableObject[line] then
        timetableObject[line] = { hasTimetable = false, stations = {} }
    end

    local stations = timetableObject[line].stations
    if not stations[stationNumber] then
        stations[stationNumber] = { stationID = stationID, conditions = {} }
    end

    local stopInfo   = stations[stationNumber]
    local conditions = stopInfo.conditions
    conditions.type  = condType

    if not conditions[condType] then
        conditions[condType] = {}
    end

    if condType == "ArrDep" then
        if not stopInfo.vehiclesWaiting then
            -- vehiclesWaiting stores transient state about vehicles currently claiming slots.
            stopInfo.vehiclesWaiting = {}
        end
    else
        -- Non-ArrDep conditions do not track vehiclesWaiting.
        stopInfo.vehiclesWaiting = nil
    end
    invalidateDerivedCaches()
end

--[[ Function: getConditionType
Params: line, stationNumber
Returns: condition type string (e.g. "ArrDep", "debounce", "None") or "ERROR" for bad args.
Notes: Ensures a default "None" is set when missing. ]]
function timetable.getConditionType(line, stationNumber)
    if not (line and stationNumber) then return "ERROR" end
    local lineData = timetableObject[line]
    if lineData and lineData.stations[stationNumber] then
        local t = lineData.stations[stationNumber].conditions.type
        if not t then
            lineData.stations[stationNumber].conditions.type = "None"
            return "None"
        end
        return t
    end
    return "None"
end

--[[ Function: getConditions
Params: line, stationNumber, condType
Returns: condition table or -1 if not available.
Notes: Read helper for fetching a specific condition object. ]]
function timetable.getConditions(line, stationNumber, condType)
    if not (line and stationNumber) then return -1 end
    local lineData = timetableObject[line]
    if lineData and lineData.stations[stationNumber] then
        local c = lineData.stations[stationNumber].conditions[condType]
        if c ~= nil then return c end
    end
    return -1
end

--[[ Function: getConstraintsByStation
Returns: table indexed by stationID, then lineID, then stopNr (3-level nested structure).
Purpose:
- Provide a "by station" view of all active constraints across all lines and stops.
- Used by GUI to display station-centric lists of lines that have timetables at that station.
- Result is cached to avoid repeated iteration over all conditions.
Note:
- Cache must be invalidated whenever timetable mutations occur (addCondition, removeCondition, etc).
]]
function timetable.getConstraintsByStation()
    if _constraintsByStationCache then
        return _constraintsByStationCache
    end
    local res = {}
    for lineID, lineInfo in pairs(timetableObject) do
        for stopNr, stopInfo in pairs(lineInfo.stations) do
            local ctype = stopInfo.conditions and stopInfo.conditions.type
            if stopInfo.stationID and ctype and ctype ~= "None" then
                local sid                = stopInfo.stationID
                res[sid]                 = res[sid] or {}
                res[sid][lineID]         = res[sid][lineID] or {}
                res[sid][lineID][stopNr] = stopInfo
            end
        end
    end
    _constraintsByStationCache = res
    return res
end

--[[ Function: getAllConditionsOfAllStations
Returns: table indexed by stationID, then lineID; each entry contains { conditions = ... }.
Purpose:
- Provide a station-line mapping for all conditions, simpler than getConstraintsByStation.
- Also cached for performance.
]]
function timetable.getAllConditionsOfAllStations()
    if _allConditionsCache then
        return _allConditionsCache
    end
    local res = {}
    for k, v in pairs(timetableObject) do
        for _, v2 in pairs(v.stations) do
            local ctype = v2.conditions and v2.conditions.type
            if v2.stationID and ctype and ctype ~= "None" then
                res[v2.stationID]    = res[v2.stationID] or {}
                res[v2.stationID][k] = { conditions = v2.conditions }
            end
        end
    end
    _allConditionsCache = res
    return res
end

--[[ Function: addFrequency
Params: line (number), frequency (any)
Purpose:
- Store the computed line frequency (in seconds) for later use in auto_debounce calculations.
- Validates that frequency is a normal, finite number before storing.
- Called by the scheduler during each engine update cycle.
Note:
- Not persisted; frequencies are recalculated each session.
]]
function timetable.addFrequency(line, frequency)
    if not timetableObject[line] then return end
    local f = tonumber(frequency)
    -- Guard against NaN and infinities; only store valid finite frequencies.
    if f and f == f and f ~= math.huge and f ~= -math.huge then
        _lineFrequency[line] = f
    end
end

--[[ Function: addCondition
Params: line, stationNumber, condition (table with type, ArrDep/debounce/auto_debounce)
Purpose:
- Add or update a departure condition at a given line/station.
- Handles three condition types: ArrDep (slots), debounce (manual wait), auto_debounce (smart wait).
- Merges ArrDep slots with existing ones if the condition already exists.
Notes:
- Marks _slotsSorted=false to trigger re-sort on next slot selection.
- Calls invalidateDerivedCaches because the structure of conditions changed.
- Returns early if creating a new station entry; otherwise continues to type-specific logic.
]]
function timetable.addCondition(line, stationNumber, condition)
    if not (line and stationNumber and condition) then return -1 end

    local stationID = timetableHelper.getStationID(line, stationNumber)
    if not timetableObject[line] then
        timetableObject[line] = { hasTimetable = false, stations = {} }
    end

    local stations = timetableObject[line].stations
    if not stations[stationNumber] then
        stations[stationNumber] = {
            stationID  = stationID,
            conditions = condition,
        }
        invalidateDerivedCaches()
        return
    end

    local ctype = condition.type
    if ctype == "ArrDep" then
        timetable.setConditionType(line, stationNumber, "ArrDep")
        local existing = stations[stationNumber].conditions.ArrDep
        -- Merge new slots with any existing ones to preserve earlier user edits.
        stations[stationNumber].conditions.ArrDep =
            timetableHelper.mergeArray(existing, condition.ArrDep)
        stations[stationNumber].conditions._slotsSorted = false
    elseif ctype == "debounce" then
        stations[stationNumber].conditions.type     = "debounce"
        stations[stationNumber].conditions.debounce = condition.debounce
    elseif ctype == "auto_debounce" then
        stations[stationNumber].conditions.type          = "auto_debounce"
        stations[stationNumber].conditions.auto_debounce = condition.auto_debounce
    end
    stations[stationNumber].stationID = stationID
    invalidateDerivedCaches()
end

--[[ Function: insertArrDepCondition
Params: line, station, indexKey (1-based position), condition (slot to insert)
Purpose:
- Insert a new slot into an existing ArrDep slot list at a specific position.
Returns: 0 on success, -1 or -2 on error.
Notes:
- Used by GUI when user clicks "+" to add a new slot inline.
- Marks _slotsSorted=false because insertion breaks sort order.
]]
function timetable.insertArrDepCondition(line, station, indexKey, condition)
    if not (line and station and indexKey and condition) then return -1 end
    local arr = timetableObject[line]
        and timetableObject[line].stations[station]
        and timetableObject[line].stations[station].conditions.ArrDep
    if arr and arr[indexKey] then
        table.insert(arr, indexKey, condition)
        timetableObject[line].stations[station].conditions._slotsSorted = false
        invalidateDerivedCaches()
        return 0
    end
    return -2
end

function timetable.updateArrDep(line, station, indexKey, indexValue, value)
    if line == nil or station == nil or indexKey == nil
        or indexValue == nil or value == nil then
        return -1
    end
    local arr = timetableObject[line]
        and timetableObject[line].stations[station]
        and timetableObject[line].stations[station].conditions.ArrDep
    if arr and arr[indexKey] and arr[indexKey][indexValue] ~= nil then
        arr[indexKey][indexValue] = value
        timetableObject[line].stations[station].conditions._slotsSorted = false
        invalidateDerivedCaches()
        return 0
    end
    print("[Timetables] updateArrDep – index not found (" ..
        tostring(line) .. "/" .. tostring(station) .. "/" ..
        tostring(indexKey) .. "/" .. tostring(indexValue) .. ")")
    return -2
end

function timetable.updateDebounce(line, station, indexKey, value, debounceType)
    if line == nil or station == nil or indexKey == nil or value == nil then
        return -1
    end
    local cond = timetableObject[line]
        and timetableObject[line].stations[station]
        and timetableObject[line].stations[station].conditions[debounceType]
    if cond then
        cond[indexKey] = value
        invalidateDerivedCaches()
        return 0
    end
    return -2
end

function timetable.removeAllConditions(line, station, condType)
    if not (line and station) then return -1 end
    local s = timetableObject[line] and timetableObject[line].stations[station]
    if not s then return -1 end
    s.conditions[condType] = {}
    if condType == "ArrDep" then s.conditions._slotsSorted = false end
    invalidateDerivedCaches()
end

function timetable.removeCondition(line, station, condType, index)
    if not (line and station and index) then return -1 end
    local s = timetableObject[line] and timetableObject[line].stations[station]
    if not s then return -1 end

    if condType == "ArrDep" then
        local arr = s.conditions.ArrDep
        if arr and arr[index] then
            table.remove(arr, index)
            s.conditions._slotsSorted = false
            invalidateDerivedCaches()
            return 0
        end
    else
        s.conditions[condType] = {}
        invalidateDerivedCaches()
        return 0
    end
    return -1
end

function timetable.hasTimetable(line)
    return timetableObject[line] and timetableObject[line].hasTimetable or false
end

function timetable.setHasTimetable(line, bool)
    if timetableObject[line] then
        timetableObject[line].hasTimetable = bool
        if bool == false and timetableObject[line].stations then
            for _, stopInfo in pairs(timetableObject[line].stations) do
                stopInfo.vehiclesWaiting = {}
            end
            _lineFrequency[line] = nil
        end
    else
        timetableObject[line] = { stations = {}, hasTimetable = bool }
    end
    invalidateDerivedCaches()
    return bool
end

local function getLineFlagSafe(line, flag, default)
    if timetableObject[line] then
        if timetableObject[line][flag] == nil then
            timetableObject[line][flag] = default
        end
        return timetableObject[line][flag]
    end
    return default
end

local function setLineFlagSafe(line, flag, value)
    if timetableObject[line] then
        timetableObject[line][flag] = value
    end
end

function timetable.getForceDepartureEnabled(line)
    return getLineFlagSafe(line, "forceDeparture", false)
end

function timetable.setForceDepartureEnabled(line, value)
    setLineFlagSafe(line, "forceDeparture", value)
end

function timetable.getMinWaitEnabled(line)
    local lineData = timetableObject[line]
    if lineData and lineData.minWaitEnabled ~= false then return true end
    return false
end

function timetable.setMinWaitEnabled(line, value)
    setLineFlagSafe(line, "minWaitEnabled", value)
end

function timetable.getMaxWaitEnabled(line)
    local lineData = timetableObject[line]
    if lineData and lineData.maxWaitEnabled then return true end
    return false
end

function timetable.setMaxWaitEnabled(line, value)
    setLineFlagSafe(line, "maxWaitEnabled", value)
end

function timetable.restartAutoDepartureForAllLineVehicles(line)
    for _, vehicle in pairs(timetableHelper.getVehiclesOnLine(line)) do
        timetableHelper.restartAutoVehicleDeparture(vehicle)
    end
end

--[[ Function: updateForVehicle
Params: vehicle, line, vehicles (list), vehicleState
Purpose:
- Entry point called by scheduler for each vehicle on a timetabled line at each engine tick.
- Checks if the stop is timetabled and routes to departIfReady, or restarts auto-departure if not.
Logic:
- Extract current stop from vehicleState (0-indexed stopIndex).
- If the stop has an active condition (not "None"), evaluate readiness.
- Otherwise, resume natural auto-departure behavior.
]]
function timetable.updateForVehicle(vehicle, line, vehicles, vehicleState)
    local stop = vehicleState.stopIndex + 1
    local lineData = timetableObject[line]
    local stopData = lineData and lineData.stations and lineData.stations[stop]
    local condType = stopData and stopData.conditions and stopData.conditions.type

    if condType and condType ~= "None" then
        timetable.departIfReady(vehicle, vehicles, line, stop, vehicleState, stopData)
    elseif not vehicleState.autoDeparture then
        timetableHelper.restartAutoVehicleDeparture(vehicle)
    end
end

--[[ Function: departIfReady
Params: vehicle, vehicles (list of line's vehicles), line, stop, vehicleState, stopData
Purpose:
- Orchestrate departure: check readiness, clear waiting state, and trigger departure or auto-restart.
Logic:
- If autoDeparture is active, stop it (shouldn't happen, but defensive).
- If doors are open:
  - Call readyToDepart to evaluate the condition (ArrDep/debounce/auto_debounce).
  - If ready: clear the vehicle from vehiclesWaiting, then either force-depart or restart auto.
- Vehicles are removed from vehiclesWaiting here to prevent memory growth and incorrect slot re-assignment.
Note:
- The comment "Clear the vehicle from the waiting list upon departure (ArrDep only)" in the code
  applies because vehiclesWaiting only exists for ArrDep; debounce conditions don't use it.
]]
function timetable.departIfReady(vehicle, vehicles, line, stop, vehicleState, stopData)
    if vehicleState.autoDeparture then
        timetableHelper.stopAutoVehicleDeparture(vehicle)
    elseif vehicleState.doorsOpen then
        local arrivalTime = math.floor(vehicleState.doorsTime / 1000000)
        if timetable.readyToDepart(vehicle, arrivalTime, vehicles, line, stop, stopData) then
            -- Clear the vehicle from the waiting list upon departure (ArrDep only)
            local lineData = timetableObject[line]
            if lineData and lineData.stations and lineData.stations[stop] then
                local stopInfo = lineData.stations[stop]
                if stopInfo.conditions and stopInfo.conditions.type == "ArrDep"
                    and stopInfo.vehiclesWaiting then
                    stopInfo.vehiclesWaiting[vehicle] = nil
                end
            end
            if timetable.getForceDepartureEnabled(line) then
                timetableHelper.departVehicle(vehicle)
            else
                timetableHelper.restartAutoVehicleDeparture(vehicle)
            end
        end
    end
end

function timetable.readyToDepart(vehicle, arrivalTime, vehicles, line, stop, stopData)
    if not stopData then
        local lineData = timetableObject[line]
        if not lineData then return true end
        local stations = lineData.stations
        stopData = stations and stations[stop]
    end

    local conditions = stopData and stopData.conditions
    local conditionType = conditions and conditions.type
    if not conditionType then
        return true
    end

    if not stopData.vehiclesWaiting then stopData.vehiclesWaiting = {} end
    local vehiclesWaiting = stopData.vehiclesWaiting
    local time = timetableHelper.getTime()

    if conditionType == "ArrDep" then
        return timetable.readyToDepartArrDep(
            vehicle, arrivalTime, vehicles, time, line, stop, vehiclesWaiting)
    elseif conditionType == "debounce" or conditionType == "auto_debounce" then
        return timetable.readyToDepartDebounce(
            vehicle, arrivalTime, vehicles, time, line, stop, vehiclesWaiting,
            conditionType == "debounce")
    end
    return true
end

--[[ Function: getWaitTime
Params: slot (table {arrMin, arrSec, depMin, depSec}), arrivalTime (seconds, wrapped to 0-3599)
Returns: wait duration in seconds (0-3600)
Purpose:
- Calculate how long a vehicle must wait between arrival and the target departure time in the slot.
Logic (time wraps modulo 3600, like a clock):
- If arrival is BEFORE the arrival slot time, wait includes the gap to arrival slot PLUS arrival-to-departure.
- If arrival is AFTER the arrival slot but BEFORE the departure slot, wait is just departure - arrival (wrapped).
- Otherwise (departure has passed), wait is 0.
Note:
- Slot times are treated as positions on a 1-hour circle; "after" uses circular comparison.
]]
function timetable.getWaitTime(slot, arrivalTime)
    guard.againstNil(slot, "slot")
    local arrSlot = timetable.slotToArrivalSlot(slot)
    local depSlot = timetable.slotToDepartureSlot(slot)
    if not timetable.afterArrivalSlot(arrSlot, arrivalTime) then
        return ((depSlot - arrSlot) % 3600) + ((arrSlot - arrivalTime) % 3600)
    end
    if not timetable.afterDepartureSlot(arrSlot, depSlot, arrivalTime) then
        return (depSlot - arrivalTime) % 3600
    end
    return 0
end

--[[ Function: getDepartureTime
Params: line, stop, arrivalTime, waitTime
Returns: absolute departure time (seconds) = arrivalTime + waitTime (possibly clamped)
Purpose:
- Apply min/max wait constraints if enabled on the line to limit how long vehicles wait.
Logic:
- If neither min nor max is enabled, return passthrough (arrival + wait).
- Otherwise, fetch the stop's TF2 minWaitingTime and maxWaitingTime constraints.
- Clamp waitTime to [minWaitingTime, maxWaitingTime].
Note:
- Min/max are game-provided constraints (e.g., from stop properties); they represent hard limits.
]]
function timetable.getDepartureTime(line, stop, arrivalTime, waitTime)
    if waitTime < 0 then waitTime = 0 end
    if not timetable.getMinWaitEnabled(line) and not timetable.getMaxWaitEnabled(line) then
        return arrivalTime + waitTime
    end
    local lineInfo = timetableHelper.getLineInfo(line)
    local stopInfo = lineInfo and lineInfo.stops and lineInfo.stops[stop]

    if stopInfo then
        if timetable.getMinWaitEnabled(line) and waitTime < stopInfo.minWaitingTime then
            waitTime = stopInfo.minWaitingTime
        end
        if timetable.getMaxWaitEnabled(line) and waitTime > stopInfo.maxWaitingTime then
            waitTime = stopInfo.maxWaitingTime
        end
    end
    return arrivalTime + waitTime
end

--[[ Function: readyToDepartArrDep
Params: vehicle, doorsTime (microseconds), vehicles (list), currentTime (seconds),
  line, stop, vehiclesWaiting (map of vehicle -> {arrivalTime, slot, departureTime})
Returns: true if vehicle may depart, false otherwise
Purpose:
- Evaluate ArrDep condition: find a valid slot and check if the departure time has arrived.
Logic:
1. If no slots exist, clear condition and allow departure.
2. Check if vehicle has a cached assignment (vw); validate and reuse if still valid.
3. If no cached assignment, call getNextSlot to find a suitable slot.
4. Compute wait time and departure time; store as a claim in vehiclesWaiting.
5. Check if the target departure time has passed; if so, allow departure.
Note:
- vehiclesWaiting acts as a coordination map: vehicles hold their assigned slots and expected
  departure times so later vehicles (same stop, same tick) can factor in already-claimed slots
  and avoid collisions.
- The vehicle's claim is NOT removed here; it's removed in departIfReady after actual departure.
]]
function timetable.readyToDepartArrDep(vehicle, doorsTime, vehicles, currentTime,
                                       line, stop, vehiclesWaiting)
    local slots = timetableObject[line].stations[stop].conditions.ArrDep
    if not slots or next(slots) == nil then
        timetableObject[line].stations[stop].conditions.type = "None"
        return true
    end

    local slot, departureTime, validSlot

    local vw = vehiclesWaiting[vehicle]
    if vw then
        -- Vehicle has a previous claim; check if it's stale or still valid.
        if not vw.arrivalTime or vw.arrivalTime < doorsTime then
            vehiclesWaiting[vehicle] = nil
        elseif vw.slot and vw.departureTime then
            slot          = vw.slot
            departureTime = vw.departureTime
            validSlot     = timetable.arrayContainsSlot(slot, slots)
        end
    end

    if not validSlot then
        local conditions = timetableObject[line].stations[stop].conditions
        slot = timetable.getNextSlot(slots, doorsTime, vehiclesWaiting, conditions, currentTime)
        if slot == nil then return true end
        local waitTime           = timetable.getWaitTime(slot, doorsTime)
        departureTime            = timetable.getDepartureTime(line, stop, doorsTime, waitTime)
        vehiclesWaiting[vehicle] = {
            arrivalTime   = doorsTime,
            slot          = slot,
            departureTime = departureTime,
        }
    end

    if timetable.afterDepartureTime(departureTime, currentTime) then
        vehiclesWaiting[vehicle] = nil
        return true
    end
    return false
end

--[[ Function: readyToDepartDebounce
Params: vehicle, arrivalTime (seconds), vehicles (list), time (now), line, stop,
  vehiclesWaiting (map), debounceIsManual (bool)
Returns: true if ready to depart, false otherwise
Purpose:
- Evaluate debounce or auto_debounce condition: hold vehicle until a minimum separation from
  the previous departure on this stop.
Logic:
1. Check if vehicle has a cached departureTime; if so, reuse it.
2. If no cached time, compute one based on the debounce strategy:
   - If only one vehicle on the line: depart immediately.
   - If another vehicle arrived earlier: wait (to avoid bunching).
   - If manual debounce: wait(previous_departure + debounce_time).
   - If auto_debounce: wait(previous_departure + frequency - margin_time).
3. Store the departure time in vehiclesWaiting[vehicle].
4. Check if the time has passed; if so, allow departure and clear the claim.
Note:
- Unlike ArrDep, debounce doesn't assign specific slots; it just enforces inter-departure spacing.
- vehiclesWaiting[vehicle].departureTime is the key; it's a scalar, not a slot.
]]
function timetable.readyToDepartDebounce(vehicle, arrivalTime, vehicles, time,
                                         line, stop, vehiclesWaiting, debounceIsManual)
    local departureTime = vehiclesWaiting[vehicle]
        and vehiclesWaiting[vehicle].departureTime

    if departureTime == nil then
        if #vehicles == 1 then
            departureTime = time
        elseif timetable.anotherVehicleArrivedEarlier(vehicle, arrivalTime, line, stop) then
            return false
        elseif debounceIsManual then
            departureTime = timetable.manualDebounceDepartureTime(
                arrivalTime, vehicles, time, line, stop, vehiclesWaiting)
        else
            departureTime = timetable.autoDebounceDepartureTime(
                arrivalTime, vehicles, time, line, stop, vehiclesWaiting)
        end
        vehiclesWaiting[vehicle] = { departureTime = departureTime }
    end

    if timetable.afterDepartureTime(departureTime, time) then
        vehiclesWaiting[vehicle] = nil
        return true
    end
    return false
end

--[[ Function: manualDebounceDepartureTime
Purpose: Calculate target departure for manual debounce.
Formula: wait = (previous_departure + unbunchTime) - arrivalTime
Note:
- unbunchTime is a fixed parameter set by user (debounce minutes/seconds).
- The wait time is then clamped by getDepartureTime to min/max constraints.
]]
function timetable.manualDebounceDepartureTime(arrivalTime, vehicles, time,
                                               line, stop, vehiclesWaiting)
    local prev                     = timetableHelper.getPreviousDepartureTime(stop, vehicles, vehiclesWaiting)
    local debounceCondition        = timetable.getConditions(line, stop, "debounce")
    local debounceMin, debounceSec = 0, 0
    if type(debounceCondition) == "table" then
        debounceMin = debounceCondition[1] or 0
        debounceSec = debounceCondition[2] or 0
    end
    local unbunchTime = timetable.minToSec(debounceMin, debounceSec)
    return timetable.getDepartureTime(line, stop, arrivalTime,
        (prev + unbunchTime) - arrivalTime)
end

--[[ Function: autoDebounceDepartureTime
Purpose: Calculate target departure for auto_debounce (smart spacing).
Formula: wait = (previous_departure + frequency - marginTime) - arrivalTime
Logic:
- Attempt to space departures evenly (frequency apart).
- Reduce the gap by marginTime (user-controlled) to keep vehicle closer to the ideal schedule.
Note:
- If line frequency is unknown, default to current time (immediate departure).
]]
function timetable.autoDebounceDepartureTime(arrivalTime, vehicles, time,
                                             line, stop, vehiclesWaiting)
    local prev      = timetableHelper.getPreviousDepartureTime(stop, vehicles, vehiclesWaiting)
    local frequency = _lineFrequency[line]
    if not frequency then return time end
    local autoCondition = timetable.getConditions(line, stop, "auto_debounce")
    local marginMin, marginSec = 1, 0
    if type(autoCondition) == "table" then
        marginMin = autoCondition[1] or 1
        marginSec = autoCondition[2] or 0
    end
    local marginTime = timetable.minToSec(marginMin, marginSec)
    return timetable.getDepartureTime(line, stop, arrivalTime,
        (prev + frequency - marginTime) - arrivalTime)
end

function timetable.anotherVehicleArrivedEarlier(vehicle, arrivalTime, line, stop)
    local vehiclesAtStop = timetableHelper.getVehiclesAtStop(line, stop)
    if #vehiclesAtStop <= 1 then return false end
    for _, other in pairs(vehiclesAtStop) do
        if other ~= vehicle then
            local info = timetableHelper.getVehicleInfo(other)
            if info and info.doorsOpen then
                return math.floor(info.doorsTime / 1000000) < arrivalTime
            end
        end
    end
    return false
end

function timetable.afterDepartureTime(departureTime, currentTime)
    return departureTime <= currentTime
end

--[[ Function: afterArrivalSlot
Params: arrivalSlot (0-3599), arrivalTime (0-3599, mod 3600)
Returns: true if arrivalTime falls within the "valid" zone around arrivalSlot
Purpose:
- On a circular 1-hour clock, determine if arrival has passed the arrival slot time.
- Used to check if a vehicle has arrived AFTER a slot's intended arrival time.
Logic (circular comparison, ±30 min from the slot):
- Divide the clock into two halves: [slot, slot+1800) and [slot+1800, slot+3600).
- If arrival is in the first half, we've "passed" the arrival slot (it's valid).
- Otherwise, we haven't reached it yet.
Note:
- The circular nature handles the hour wrap-around: a slot at 23:50 and arrival at 00:10
  correctly identifies that arrival has passed the slot.
]]
function timetable.afterArrivalSlot(arrivalSlot, arrivalTime)
    local half = (arrivalSlot + 1800) % 3600
    arrivalTime = arrivalTime % 3600
    if arrivalSlot < half then
        return arrivalSlot <= arrivalTime and arrivalTime < half
    else
        return not (half <= arrivalTime and arrivalTime < arrivalSlot)
    end
end

--[[ Function: afterDepartureSlot
Params: arrivalSlot, departureSlot (0-3599 each), arrivalTime (0-3599)
Returns: true if departure time has passed on the circular clock
Purpose:
- Determine if current arrival time is past the departure slot's intended time.
- More complex than afterArrivalSlot because it considers both arrival and departure positions.
Logic:
- If arrival <= departure (forward flow): check if arrivalTime < arrival or departure <= arrivalTime.
- If arrival > departure (wrap-around): check if arrivalTime < arrival AND departure <= arrivalTime.
Note:
- This reflects the intended behavior: a slot can wrap around midnight (e.g., arrive 23:45, depart 00:15).
]]
function timetable.afterDepartureSlot(arrivalSlot, departureSlot, arrivalTime)
    arrivalTime = arrivalTime % 3600
    if arrivalSlot <= departureSlot then
        return arrivalTime < arrivalSlot or departureSlot <= arrivalTime
    else
        return arrivalTime < arrivalSlot and departureSlot <= arrivalTime
    end
end

--[[ Function: _classifyWaitingVehicles
Params: vehiclesWaiting (map), arrivalTime, currentTime
Returns: (waitingMap, departedMap)
Purpose: Partition vehicles currently in vehiclesWaiting into two groups:
- waitingMap: vehicles still awaiting departure (arrival <= dep time).
- departedMap: vehicles whose departure time has passed (stale departures).
Note:
- Removes vehicles with missing departureTime or slot data (malformed entries).
- Also removes vehicles whose departure time is past currentTime (housekeeping).
]]
local function _classifyWaitingVehicles(vehiclesWaiting, arrivalTime, currentTime)
    local waitingMap  = {}
    local departedMap = {}
    for vehicle, vw in pairs(vehiclesWaiting) do
        if not (vw.departureTime and vw.slot) then
            vehiclesWaiting[vehicle] = nil
        elseif timetable.afterDepartureTime(vw.departureTime, currentTime) then
            vehiclesWaiting[vehicle] = nil
        elseif arrivalTime <= vw.departureTime then
            waitingMap[vehicle] = vw.slot
        else
            departedMap[vehicle] = vw.slot
        end
    end
    return waitingMap, departedMap
end

--[[ Function: getNextSlot
Params: slots (array of [arrMin, arrSec, depMin, depSec]), arrivalTime, vehiclesWaiting (map),
  conditions (table with _slotsSorted flag), currentTime
Returns: slot (array) or nil
Purpose:
- Find a suitable slot for a newly arrived vehicle using a heuristic algorithm.
- Prefer slots close to arrival time, avoid slots already claimed by other vehicles.
Algorithm (greedy with wraparound fairness):
1. Sort slots by arrival time once (cache sort result in _slotsSorted).
2. Find the best (closest) slot to current arrival time using getTimeDifference.
3. If only one slot exists, clear all waiting vehicles and assign it.
4. Classify other vehicles' waiting and departed slots.
5. Circular scan from best slot:
   a. Skip slots with negative wait (already passed).
   b. If slot is claimed by a waiting vehicle, clear departed entries and continue.
   c. If slot was claimed by a departed vehicle, skip it and clear its entry.
   d. Otherwise, assign this slot immediately.
6. Fallback: return the best (closest) slot if no unclaimed slot found.
Note:
- The algorithm allows overlapping in time, but tries to spread vehicles across different
  slots to distribute load. It's heuristic, not optimal; see ARCHITECTURE.md for details.
- Vehicles holding stale slots are cleared during this process (GC).
]]
function timetable.getNextSlot(slots, arrivalTime, vehiclesWaiting, conditions, currentTime)
    if not slots or #slots == 0 then return nil end

    if not conditions._slotsSorted then
        table.sort(slots, function(a, b)
            return timetable.slotToArrivalSlot(a) < timetable.slotToArrivalSlot(b)
        end)
        conditions._slotsSorted = true
    end

    local best = { diff = 3601, index = nil }
    for i, slot in ipairs(slots) do
        local diff = timetable.getTimeDifference(
            timetable.slotToArrivalSlot(slot), arrivalTime % 3600)
        if diff < best.diff then
            best = { diff = diff, index = i }
        end
    end
    if not best.index then return nil end

    if #slots == 1 then
        for k in pairs(vehiclesWaiting) do vehiclesWaiting[k] = nil end
        return slots[1]
    end

    local waitingMap, departedMap = _classifyWaitingVehicles(vehiclesWaiting, arrivalTime, currentTime)

    for i = best.index, #slots + best.index - 1 do
        local idx  = ((i - 1) % #slots) + 1
        local slot = slots[idx]

        if timetable.getWaitTime(slot, arrivalTime) <= 0 then
            -- Slot is in the past; skip it.
        elseif timetable.arrayContainsSlot(slot, waitingMap) then
            -- Another vehicle is waiting on this slot; clear stale departures and continue.
            for v in pairs(departedMap) do
                vehiclesWaiting[v] = nil
                departedMap[v]     = nil
            end
        else
            -- Slot is either unclaimed or was only claimed by departed vehicles.
            local takenByDeparted = false
            for v, ds in pairs(departedMap) do
                if timetable.slotsEqual(slot, ds) then
                    takenByDeparted = true
                else
                    vehiclesWaiting[v] = nil
                    departedMap[v]     = nil
                end
            end
            if not takenByDeparted then return slot end
        end
    end

    -- Fallback: return the closest slot.
    return slots[best.index]
end

--[[ Function: arrayContainsSlot
Params: slot (table), slotArray (table of slot-like entries, possibly from departedMap)
Returns: true if slot matches any entry in slotArray using slotsEqual
Purpose: Check if a slot is already claimed by searching the array.
]]
function timetable.arrayContainsSlot(slot, slotArray)
    for _, item in pairs(slotArray) do
        if timetable.slotsEqual(item, slot) then return true end
    end
    return false
end

--[[ Function: slotsEqual
Params: a, b (slot tables [arrMin, arrSec, depMin, depSec] or objects)
Returns: true if slots are identical
Purpose: Compare slots by value (all four components must match).
Note: Handles both identity (a == b) and component-wise comparison.
]]
function timetable.slotsEqual(a, b)
    if a == b then return true end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

function timetable.slotToArrivalSlot(slot)
    guard.againstNil(slot, "slot")
    return timetable.minToSec(slot[1], slot[2])
end

function timetable.slotToDepartureSlot(slot)
    guard.againstNil(slot, "slot")
    return timetable.minToSec(slot[3], slot[4])
end

function timetable.minToSec(min, sec)
    return (min or 0) * 60 + (sec or 0)
end

function timetable.secToMin(sec)
    return math.floor(sec / 60) % 60, math.floor(sec % 60)
end

function timetable.minToStr(min, sec)
    return string.format("%02d:%02d", min, sec)
end

function timetable.secToStr(sec)
    local m, s = timetable.secToMin(sec)
    return timetable.minToStr(m, s)
end

--[[ Function: getTimeDifference
Params: a, b (0-3599 each, positions on a circle)
Returns: distance between a and b on a circular clock
Purpose:
- Find the shortest arc between two times on a 1-hour clock.
Logic:
- Compute d = |a - b|.
- If d > 1800 (half circle), the shorter path is the other way: 3600 - d.
Example: 5:50 and 6:10 differs by 20 min; 10:00 and 11:59 differs by 1 min (shorter backward path).
Note:
- Used by slot selection to find the "closest" matching slot to the arrival time.
]]
function timetable.getTimeDifference(a, b)
    local d = a - b
    if d < 0 then d = -d end
    return d > 1800 and (3600 - d) or d
end

--[[ Function: shiftTime
Params: time (seconds 0-3599), offset (seconds, can be negative/positive)
Returns: {min, sec} representing the new time (wrapped to 0-3599)
Purpose: Add an offset to a time and normalize to{minutes, seconds} format.
Used to: Generate recurring slots by shifting a template slot.
]]
function timetable.shiftTime(time, offset)
    local t = (time + offset) % 3600
    return { math.floor(t / 60), t % 60 }
end

--[[ Function: shiftSlot
Params: slot (table [arrMin, arrSec, depMin, depSec]), offset (seconds)
Returns: new slot with both arrival and departure shifted by offset
Purpose: Generate the next slot in a recurring pattern (e.g., every 15 minutes).
Used by: GUI "Generate" button to create multiple slots from a template.
]]
function timetable.shiftSlot(slot, offset)
    local arrS = timetable.shiftTime(timetable.slotToArrivalSlot(slot), offset)
    local depS = timetable.shiftTime(timetable.slotToDepartureSlot(slot), offset)
    return { arrS[1], arrS[2], depS[1], depS[2] }
end

--[[ Function: cleanTimetable
Returns: dirty (bool) — true if any entries were removed
Purpose:
- Remove timetable entries for lines that no longer exist in the game.
- Remove stops from a line's timetable if they're no longer valid stops on that line.
- Detect and handle both 0-indexed and 1-indexed stop indexing from the game.
Logic:
1. For each line in timetableObject:
   - If line no longer exists in the game, remove it entirely and its frequency.
   - Otherwise, check each stop in that line:
     - Query the game for valid stops on the line.
     - Detect if game uses 0- or 1-based indexing (hasZeroBasedIndex).
     - Remove any stop indices not in the valid set.
2. Invalidate caches if anything changed.
Note:
- Called by GUI on periodic cleanup to maintain consistency when routes change in-game.
- Preserves the integrity of the timetable object against game state changes.
]]
function timetable.cleanTimetable()
    local dirty = false
    local ok, err = pcall(function()
        for lineID in pairs(timetableObject) do
            if not timetableHelper.lineExists(lineID) then
                timetableObject[lineID] = nil
                _lineFrequency[lineID] = nil
                dirty = true
            else
                local lineStops = timetableObject[lineID].stations
                if lineStops then
                    local validStopIndex = {}
                    local lineInfo = timetableHelper.getLineInfo(lineID)
                    if lineInfo and lineInfo.stops then
                        local rawIndexes = {}
                        local hasZeroBasedIndex = false
                        for rawIdx, _ in pairs(lineInfo.stops) do
                            local idxNum = tonumber(rawIdx)
                            if idxNum ~= nil then
                                rawIndexes[#rawIndexes + 1] = idxNum
                                if idxNum == 0 then
                                    hasZeroBasedIndex = true
                                end
                            end
                        end

                        for _, idxNum in ipairs(rawIndexes) do
                            local stopIdx = hasZeroBasedIndex and (idxNum + 1) or idxNum
                            validStopIndex[stopIdx] = true
                        end
                    end

                    if next(validStopIndex) ~= nil then
                        for stopIdx in pairs(lineStops) do
                            if validStopIndex[stopIdx] ~= true then
                                lineStops[stopIdx] = nil
                                dirty = true
                            end
                        end
                    end
                end
            end
        end
    end)
    if not ok then
        print("[Timetables] cleanTimetable error: " .. tostring(err))
    end
    if dirty then
        invalidateDerivedCaches()
    end
    return dirty
end

return timetable
