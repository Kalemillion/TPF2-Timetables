local function init(helper)
    function helper.getVehicleInfo(vehicle)
        return api.engine.getComponent(vehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
    end

    function helper.isVehicleAtTerminal(vehicleInfo)
        return vehicleInfo ~= nil and vehicleInfo.state == api.type.enum.TransportVehicleState.AT_TERMINAL
    end

    function helper.getAllVehicles()
        local res = {}
        for line, vehicles in pairs(api.engine.system.transportVehicleSystem.getLine2VehicleMap()) do
            for _, vehicle in pairs(vehicles) do
                res[vehicle] = line
            end
        end
        return res
    end

    function helper.getTrainLocations(line)
        local res      = {}
        local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(line)
        for _, v in pairs(vehicles) do
            local comp = api.engine.getComponent(v, api.type.ComponentType.TRANSPORT_VEHICLE)
            if comp then
                local atTerm   = comp.state == api.type.enum.TransportVehicleState.AT_TERMINAL
                local si       = comp.stopIndex
                local existing = res[si]
                if existing then
                    res[si] = {
                        stopIndex  = si,
                        vehicle    = v,
                        atTerminal = atTerm or existing.atTerminal,
                        countStr   = "MANY",
                    }
                else
                    res[si] = {
                        stopIndex  = si,
                        vehicle    = v,
                        atTerminal = atTerm,
                        countStr   = "SINGLE",
                    }
                end
            end
        end
        return res
    end

    function helper.getVehiclesOnLine(line)
        return api.engine.system.transportVehicleSystem.getLineVehicles(line)
    end

    function helper.getCurrentStation(vehicle)
        vehicle = helper._toNum(vehicle, "getCurrentStation")
        if not vehicle then return -1 end
        local comp = api.engine.getComponent(vehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
        return comp and comp.stopIndex + 1 or -1
    end

    function helper.getCurrentLine(vehicle)
        vehicle = helper._toNum(vehicle, "getCurrentLine")
        if not vehicle then return -1 end
        local comp = api.engine.getComponent(vehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
        return (comp and comp.line) or -1
    end

    function helper.isInStation(vehicle)
        vehicle = helper._toNum(vehicle, "isInStation")
        if not vehicle then return false end
        local comp = api.engine.getComponent(vehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
        return comp ~= nil and comp.state == api.type.enum.TransportVehicleState.AT_TERMINAL
    end

    function helper.stopAutoVehicleDeparture(vehicle)
        vehicle = helper._toNum(vehicle, "stopAutoVehicleDeparture")
        if not vehicle then return end
        if helper._pendingManualDeparture[vehicle] == true then return end
        helper._pendingManualDeparture[vehicle] = true
        helper._cmdBuffer[#helper._cmdBuffer + 1] = api.cmd.make.setVehicleManualDeparture(vehicle, true)
    end

    function helper.restartAutoVehicleDeparture(vehicle)
        vehicle = helper._toNum(vehicle, "restartAutoVehicleDeparture")
        if not vehicle then return end
        if helper._pendingManualDeparture[vehicle] == false then return end
        helper._pendingManualDeparture[vehicle] = false
        helper._cmdBuffer[#helper._cmdBuffer + 1] = api.cmd.make.setVehicleManualDeparture(vehicle, false)
    end

    function helper.departVehicle(vehicle)
        vehicle = helper._toNum(vehicle, "departVehicle")
        if not vehicle then return end
        if helper._pendingDepartNow[vehicle] then return end
        helper._pendingDepartNow[vehicle] = true
        helper._cmdBuffer[#helper._cmdBuffer + 1] = api.cmd.make.setVehicleShouldDepart(vehicle)
    end

    function helper.getVehiclesAtStop(line, stop)
        return api.engine.system.transportVehicleSystem.getLineStopVehicles(line, stop)
    end

    function helper.getPreviousDepartureTime(stop, vehicles, vehiclesWaiting)
        stop = helper._toNum(stop, "getPreviousDepartureTime")
        if not stop then return 0 end

        local maxDeparture = 0
        for _, v in pairs(vehicles) do
            local comp = api.engine.getComponent(v, api.type.ComponentType.TRANSPORT_VEHICLE)
            if comp and comp.lineStopDepartures and comp.lineStopDepartures[stop] then
                local dep = comp.lineStopDepartures[stop] / 1000000
                if dep > maxDeparture then
                    maxDeparture = dep
                end
            end
        end
        for _, waiting in pairs(vehiclesWaiting or {}) do
            if waiting and waiting.departureTime and waiting.departureTime > maxDeparture then
                maxDeparture = waiting.departureTime
            end
        end
        return maxDeparture
    end

    function helper.getTimeUntilDepartureReady(vehicle)
        vehicle = helper._toNum(vehicle, "getTimeUntilDepartureReady")
        if not vehicle then return -1 end
        local v = api.engine.getComponent(vehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
        return (v and v.timeUntilCloseDoors) or -1
    end

    function helper.isLineOfType(lineType)
        local lines = api.engine.system.lineSystem.getLines()
        local res   = {}
        for _, lineID in pairs(lines) do
            res[lineID] = helper.lineHasType(lineID, lineType)
        end
        return res
    end

    function helper.lineHasType(line, lineType)
        line = tonumber(line)
        if not line then return false end
        local vehicles = api.engine.system.transportVehicleSystem.getLineVehicles(line)
        local firstVehicle = nil
        if vehicles then
            firstVehicle = vehicles[1]
            if not firstVehicle then
                for _, v in pairs(vehicles) do
                    firstVehicle = v
                    break
                end
            end
        end
        if firstVehicle then
            local comp = api.engine.getComponent(firstVehicle, api.type.ComponentType.TRANSPORT_VEHICLE)
            if comp and comp.carrier then
                return comp.carrier == api.type.enum.Carrier[lineType]
            end
        end
        return false
    end

    function helper.getLineColour(line)
        line = helper._toNum(line, "getLineColour")
        if not line then return "default" end
        local colour = api.engine.getComponent(line, api.type.ComponentType.COLOR)
        if colour and colour.color then
            return helper._getColorString(colour.color.x, colour.color.y, colour.color.z)
        end
        return "default"
    end

    function helper.getLineName(line)
        line = helper._toNum(line, "getLineName")
        if not line then return "ERROR" end
        local ok, comp = pcall(api.engine.getComponent, line, api.type.ComponentType.NAME)
        return (ok and comp and comp.name) or "ERROR"
    end

    function helper.getFrequencyString(line)
        local f = helper.getFrequencyMinSec(line)
        if f == -1 then return "ERROR" end
        if f == -2 then return "--" end
        return f.min .. ":" .. string.format("%02d", f.sec)
    end

    function helper.getFrequencyMinSec(line)
        local f = helper.getFrequency(line)
        if f <= 0 then return f end
        return { min = math.floor(f / 60), sec = math.floor(f % 60) }
    end

    function helper.getFrequency(line)
        line = helper._toNum(line, "getFrequency")
        if not line then return -1 end
        local ent = game.interface.getEntity(line)
        if not ent or not ent.frequency then return -2 end
        if ent.frequency == 0 then return -2 end
        return 1 / ent.frequency
    end

    function helper.getAllLines()
        local now = helper.getTime()
        if helper._cache.lines and helper._cache.linesStamp == now then
            return helper._cache.lines
        end
        local ls  = api.engine.system.lineSystem.getLines()
        local res = {}
        for _, l in pairs(ls) do
            local name = api.engine.getComponent(l, api.type.ComponentType.NAME)
            res[#res + 1] = { id = l, name = (name and name.name) or "ERROR" }
        end
        helper._cache.lines      = res
        helper._cache.linesStamp = now
        return res
    end

    function helper.lineExists(lineID)
        lineID = tonumber(lineID)
        local now = helper.getTime()
        if helper._cache.lineSet and helper._cache.lineSetStamp == now then
            return helper._cache.lineSet[lineID] == true
        end
        local s = {}
        for _, id in pairs(api.engine.system.lineSystem.getLines()) do
            s[tonumber(id)] = true
        end
        helper._cache.lineSet      = s
        helper._cache.lineSetStamp = now
        return s[lineID] == true
    end

    function helper.getLegTimes(line)
        line = helper._toNum(line, "getLegTimes")
        if not line then return {} end
        local vmap = api.engine.system.transportVehicleSystem.getLine2VehicleMap()
        if not vmap[line] or not vmap[line][1] then return {} end
        local comp = api.engine.getComponent(vmap[line][1], api.type.ComponentType.TRANSPORT_VEHICLE)
        return (comp and comp.sectionTimes) or {}
    end

    function helper.getStation(station)
        station = helper._toNum(station, "getStation")
        if not station then return { name = "ERROR" } end
        local comp = api.engine.getComponent(station, api.type.ComponentType.NAME)
        return { name = (comp and comp.name) or "ERROR" }
    end

    function helper.getLineInfo(line)
        line = helper._toNum(line, "getLineInfo")
        if not line then return nil end

        local now = helper.getTime()
        if helper._cache.lineInfoStamp ~= now then
            helper._cache.lineInfoStamp = now
            helper._cache.lineInfo = {}
        end

        local cached = helper._cache.lineInfo[line]
        if cached ~= nil then
            if cached == false then return nil end
            return cached
        end

        local comp = api.engine.getComponent(line, api.type.ComponentType.LINE)
        helper._cache.lineInfo[line] = comp or false
        return comp
    end

    function helper.getAllStations(line)
        line = helper._toNum(line, "getAllStations")
        if not line then return {} end
        local comp = helper.getLineInfo(line)
        if not (comp and comp.stops) then return {} end
        local res = {}
        for _, v in pairs(comp.stops) do
            local sid = tonumber(v.stationGroup)
            if sid then res[#res + 1] = sid end
        end
        return res
    end

    function helper.getStationName(station)
        station = helper._toNum(station, "getStationName")
        if not station then return "ERROR" end
        local ok, comp = pcall(api.engine.getComponent, station, api.type.ComponentType.NAME)
        if ok and comp then return comp.name end
        return "ERROR"
    end

    function helper.getStationID(line, stationNumber)
        line = helper._toNum(line, "getStationID")
        if not line then return -1 end
        local stations = helper.getAllStations(line)
        if stations and stations[stationNumber] then
            return tonumber(stations[stationNumber]) or -1
        end
        return -1
    end

    function helper.getAllVehiclesAtTerminal()
        return api.engine.system.transportVehicleSystem.getVehiclesWithState(
            api.type.enum.TransportVehicleState.AT_TERMINAL)
    end
end

return init
