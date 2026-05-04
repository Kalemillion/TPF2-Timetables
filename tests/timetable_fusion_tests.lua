local tests = {}

local function assertEquals(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assertEquals failed") .. " | expected=" .. tostring(expected) .. ", actual=" .. tostring(actual))
    end
end

local function assertTrue(value, msg)
    if not value then
        error(msg or "assertTrue failed")
    end
end

local function resetModule(name)
    package.loaded[name] = nil
end

local function loadTimetableWithMocks()
    local helperCalls = {
        stopAuto = 0,
        restartAuto = 0,
        depart = 0,
    }

    local mockTimetableHelper = {
        stopAutoVehicleDeparture = function(_)
            helperCalls.stopAuto = helperCalls.stopAuto + 1
        end,
        restartAutoVehicleDeparture = function(_)
            helperCalls.restartAuto = helperCalls.restartAuto + 1
        end,
        departVehicle = function(_)
            helperCalls.depart = helperCalls.depart + 1
        end,
        getVehiclesOnLine = function(_)
            return {}
        end,
        getTime = function()
            return 0
        end,
    }

    local mockGuard = {
        againstNil = function() end,
    }

    package.loaded["timetable_helper"] = mockTimetableHelper
    package.loaded["guard"] = mockGuard
    resetModule("timetable")

    local timetable = require("timetable")
    return timetable, helperCalls
end

local function loadGuiDataWithMocks()
    local guiCalls = {
        setTimetableObjectCount = 0,
        initializeCacheCount = 0,
        sendScriptEventCount = 0,
        lastEvent = nil,
    }

    local mockTimetable = {}
    local storedTimetable = {}

    mockTimetable.setTimetableObject = function(t)
        guiCalls.setTimetableObjectCount = guiCalls.setTimetableObjectCount + 1
        storedTimetable = t
    end

    mockTimetable.getTimetableObject = function()
        return storedTimetable
    end

    mockTimetable.initializeTimetableLinesCache = function()
        guiCalls.initializeCacheCount = guiCalls.initializeCacheCount + 1
    end

    local mockTimetableHelper = {
        setPerfEnabled = function(_) end,
        perfBegin = function(_) return {} end,
        perfEnd = function(_) end,
        perfMaybeFlush = function() end,
        getTime = function() return 0 end,
        flushCmdBuffer = function(_) end,
        perfCount = function(_, _) end,
    }

    local mockScheduler = {
        createCoroutineBody = function()
            return function() coroutine.yield() end
        end,
    }

    package.loaded["timetable"] = mockTimetable
    package.loaded["timetable_helper"] = mockTimetableHelper
    package.loaded["scheduler"] = mockScheduler
    package.loaded["gui"] = {}

    _G._ = function(key) return key end
    _G.api = _G.api or {}
    _G.game = {
        interface = {
            sendScriptEvent = function(id, _, payload)
                guiCalls.sendScriptEventCount = guiCalls.sendScriptEventCount + 1
                guiCalls.lastEvent = { id = id, payload = payload }
            end,
        },
    }

    _G.data = nil
    local ok, err = pcall(dofile, "res/config/game_script/timetable_gui.lua")
    if not ok then
        error("Failed to load timetable_gui.lua: " .. tostring(err))
    end
    if type(_G.data) ~= "function" then
        error("data() not exposed by timetable_gui.lua")
    end

    local scriptData = _G.data()
    return scriptData, guiCalls
end

tests[#tests + 1] = function()
    local timetable, helperCalls = loadTimetableWithMocks()
    local vehicle = 101
    local line = 1
    local stop = 1

    timetable.setTimetableObject({
        [line] = {
            hasTimetable = true,
            forceDeparture = false,
            stations = {
                [stop] = {
                    conditions = {
                        type = "ArrDep",
                        ArrDep = { { 0, 0, 0, 0 } },
                    },
                    vehiclesWaiting = {
                        [vehicle] = {
                            arrivalTime = 100,
                            departureTime = 200,
                            slot = { 0, 0, 1, 0 },
                        },
                    },
                },
            },
        },
    })

    local vehicleState = {
        autoDeparture = false,
        doorsOpen = true,
        doorsTime = 0,
    }

    local stopData = timetable.getTimetableObject()[line].stations[stop]
    timetable.departIfReady(vehicle, { vehicle }, line, stop, vehicleState, stopData)

    local waiting = timetable.getTimetableObject()[line].stations[stop].vehiclesWaiting[vehicle]
    assertEquals(waiting, nil, "departIfReady should clear vehiclesWaiting[vehicle] for ArrDep")
    assertEquals(helperCalls.restartAuto, 1, "departIfReady should restart auto departure when forceDeparture is false")
end

tests[#tests + 1] = function()
    local timetable = loadTimetableWithMocks()

    timetable.setTimetableObject({
        [10] = { hasTimetable = true, stations = {} },
        [20] = { hasTimetable = false, stations = {} },
        [30] = { hasTimetable = true, stations = {} },
    })

    timetable.initializeTimetableLinesCache()
    local cache = timetable.getCachedTimetableLines()

    assertTrue(cache[10] == true, "line 10 should be cached")
    assertEquals(cache[20], nil, "line 20 should not be cached")
    assertTrue(cache[30] == true, "line 30 should be cached")
end

tests[#tests + 1] = function()
    local scriptData, guiCalls = loadGuiDataWithMocks()

    local payload = { [1] = { hasTimetable = true, stations = {} } }

    scriptData.handleEvent(nil, "timetableUpdate", nil, payload)
    scriptData.guiUpdate()

    assertEquals(guiCalls.setTimetableObjectCount, 1, "handleEvent should call timetable.setTimetableObject once")
    assertEquals(guiCalls.sendScriptEventCount, 1, "guiUpdate should send timetableUpdate after handleEvent")
    assertEquals(guiCalls.lastEvent.id, "timetableUpdate", "event id should be timetableUpdate")
    assertTrue(guiCalls.lastEvent.payload == payload, "event payload should be the timetable set by handleEvent")

    scriptData.guiUpdate()
    assertEquals(guiCalls.sendScriptEventCount, 1, "timetableChanged should be reset after successful send")
end

tests[#tests + 1] = function()
    local scriptData, guiCalls = loadGuiDataWithMocks()

    scriptData.load({ timetable = { [42] = { hasTimetable = true, stations = {} } } })

    assertEquals(guiCalls.setTimetableObjectCount, 1, "load should call timetable.setTimetableObject")
    assertEquals(guiCalls.initializeCacheCount, 1, "load should call timetable.initializeTimetableLinesCache")
end

tests[#tests + 1] = function()
    local timetable = loadTimetableWithMocks()

    timetable.setTimetableObject("legacy-bad-payload")
    local obj = timetable.getTimetableObject()

    assertTrue(type(obj) == "table", "setTimetableObject should keep a table state on malformed payload")
    assertEquals(next(obj), nil, "setTimetableObject should reset malformed payload to empty table")
end

tests[#tests + 1] = function()
    local timetable = loadTimetableWithMocks()

    timetable.setTimetableObject({
        ["1"] = {
            hasTimetable = true,
            stations = {
                ["1"] = {
                    conditions = {
                        condition = "ArrDep",
                        ArrDep = { { 0, 0, 5, 0 } },
                    },
                },
            },
        },
    })

    local obj = timetable.getTimetableObject()
    assertTrue(obj[1] ~= nil, "line id should be normalized to number")
    assertTrue(obj[1].stations[1] ~= nil, "station id should be normalized to number")
    assertEquals(obj[1].stations[1].conditions.type, "ArrDep",
    "legacy conditions.condition should migrate to conditions.type")
    assertTrue(type(obj[1].stations[1].vehiclesWaiting) == "table", "ArrDep stop should have vehiclesWaiting table")
end

return {
    test = function()
        for k, v in pairs(tests) do
            print("Running fusion test: " .. tostring(k))
            v()
        end
    end,
}
