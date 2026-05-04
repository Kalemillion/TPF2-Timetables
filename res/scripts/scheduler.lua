--[[
Module: scheduler
Role: Background scheduler that iterates vehicles and drives timetable evaluation.

Responsibilities:
- Walk the game's vehicle-line map and call `timetable.updateForVehicle` for lines
  that have timetables, or ensure auto-departure for other vehicles.
- Use a coroutine body to yield frequently so the scheduler does not block the main thread.
- Perform periodic maintenance such as `timetable.cleanTimetable`.

Design notes:
- Uses a dynamic batch size heuristic to adjust work per resume depending on workload.
- Emits performance counters via `timetableHelper.perf*` wrappers to assist profiling.
]]

local timetable          = require "timetable"
local timetableHelper    = require "timetable_helper"

local scheduler          = {}

-- Base number of vehicles processed before yielding when load is low.
local VEHICLES_PER_BATCH = 3

--[[ Function: _computeBatchSize
Params: processedVehicles (number)
Returns: number (batch size)
Purpose: Increase batch size under heavy load to amortize yields.
Notes: Simple heuristic thresholds tuned for the typical mod workload. ]]
local function _computeBatchSize(processedVehicles)
    if processedVehicles >= 800 then return 12 end
    if processedVehicles >= 400 then return 9 end
    if processedVehicles >= 200 then return 6 end
    return VEHICLES_PER_BATCH
end

-- How often (seconds) to run the cleaning pass.
local CLEAN_INTERVAL_SECONDS = 5

local _ttLine, _ttVehicles, _ttAT
local _ntAT

--[[ Function: _processTimetableVehicle
Params: vehicle
Purpose: If vehicle state indicates it is at a stop, forward to `timetable.updateForVehicle`.
Notes: Indirection isolates the scheduler from the exact vehicle state shape. ]]
local function _processTimetableVehicle(vehicle)
    local vehicleState = timetableHelper.getVehicleInfo(vehicle)
    if vehicleState and vehicleState.state == _ttAT then
        timetable.updateForVehicle(vehicle, _ttLine, _ttVehicles, vehicleState)
    end
end

--[[ Function: _processNonTimetableVehicle
Params: vehicle
Purpose: Ensure auto-departure is active for non-timetable vehicles when applicable. ]]
local function _processNonTimetableVehicle(vehicle)
    local vInfo = timetableHelper.getVehicleInfo(vehicle)

    if vInfo and vInfo.state == _ntAT and not vInfo.autoDeparture then
        timetableHelper.restartAutoVehicleDeparture(vehicle)
    end
end

--[[ Function: createCoroutineBody
Returns: function
Purpose: Return a coroutine body that drives the scheduling loop. The returned function
is intended to be `coroutine.create`d and repeatedly resumed by the engine.

Behavior summary:
- Waits until at least 1 second has elapsed between sweeps.
- Iterates `line -> vehicles` map and processes vehicles in small batches, yielding
  to avoid hogging CPU and keep the UI responsive.
- Adjusts batch size based on observed vehicle counts and periodically calls `cleanTimetable`.
]]
function scheduler.createCoroutineBody()
    return function()
        local AT_TERMINAL = api.type.enum.TransportVehicleState.AT_TERMINAL
        _ttAT             = AT_TERMINAL
        _ntAT             = AT_TERMINAL

        local lastUpdate  = -1
        local lastClean   = -1
        local batchCount  = 0
        local batchSize   = VEHICLES_PER_BATCH

        while true do
            local sweepToken = timetableHelper.perfBegin("scheduler.sweep")
            local now = timetableHelper.getTime() or 0

            -- Ensure at least 1 second between full sweeps.
            while now - lastUpdate < 1 do
                coroutine.yield()
                now = timetableHelper.getTime() or 0
            end
            lastUpdate = now

            local vehicleLineMap = api.engine.system.transportVehicleSystem.getLine2VehicleMap()
            local processedThisSweep = 0

            for line, vehicles in pairs(vehicleLineMap) do
                if timetable.hasTimetable(line) then
                    _ttLine     = line
                    _ttVehicles = vehicles

                    for _, vehicle in pairs(vehicles) do
                        _processTimetableVehicle(vehicle)

                        processedThisSweep = processedThisSweep + 1
                        batchCount = batchCount + 1
                        if batchCount >= batchSize then
                            -- Yield cooperatively so other coroutines/UI can run.
                            batchCount = 0
                            coroutine.yield()
                        end
                    end
                else
                    for _, vehicle in pairs(vehicles) do
                        _processNonTimetableVehicle(vehicle)

                        processedThisSweep = processedThisSweep + 1
                        batchCount = batchCount + 1
                        if batchCount >= batchSize then
                            batchCount = 0
                            coroutine.yield()
                        end
                    end
                end

                coroutine.yield()
            end

            batchSize = _computeBatchSize(processedThisSweep)
            timetableHelper.perfCount("scheduler.vehicles", processedThisSweep)

            local cleanNow = timetableHelper.getTime() or 0
            if cleanNow - lastClean >= CLEAN_INTERVAL_SECONDS then
                local cleanToken = timetableHelper.perfBegin("scheduler.clean")
                timetable.cleanTimetable()
                timetableHelper.perfEnd(cleanToken)
                lastClean = cleanNow
            end

            timetableHelper.perfEnd(sweepToken)
            coroutine.yield()
        end
    end
end

return scheduler
