local function init(helper)
    local PERF_ENABLED_BY_DEFAULT = false
    local PERF_FLUSH_INTERVAL_SECONDS = 30
    local CMD_BUFFER_WARN_THRESHOLD = 200
    local CMD_BUFFER_HARD_CAP = 500
    local CMD_BUFFER_FLUSH_CHUNK = 100

    local api = api
    local _ = _

    helper._cmdBuffer = helper._cmdBuffer or {}
    helper._pendingManualDeparture = helper._pendingManualDeparture or {}
    helper._pendingDepartNow = helper._pendingDepartNow or {}
    helper._cache = helper._cache or {
        world         = nil,
        timeComponent = nil,
        time          = nil,
        timeRaw       = -1,
        lines         = nil,
        lineSet       = nil,
        lineSetStamp  = -1,
        linesStamp    = -1,
        lineInfo      = nil,
        lineInfoStamp = -1,
    }
    helper._perf = helper._perf or {
        enabled = PERF_ENABLED_BY_DEFAULT,
        nextFlush = 0,
        counters = {},
    }

    helper.UIStrings = helper.UIStrings or {
        arr         = _("arr_i18n"),
        dep         = _("dep_i18n"),
        unbunchTime = _("unbunch_time_i18n"),
    }

    function helper.getCommandBufferSize()
        return #(helper._cmdBuffer or {})
    end

    function helper.getCommandBufferHardCap()
        return CMD_BUFFER_HARD_CAP
    end

    function helper._toNum(v, fname)
        if type(v) == "string" then v = tonumber(v) end
        if type(v) ~= "number" then
            print("[Timetables] " .. (fname or "?") .. " expected number, got " .. type(v))
            return nil
        end
        return v
    end

    function helper._getColorString(r, g, b)
        return string.format("%03.0f%03.0f%03.0f", r * 100, g * 100, b * 100)
    end

    function helper.flushCmdBuffer(forceFull)
        local cmdBuffer = helper._cmdBuffer
        if #cmdBuffer == 0 then return end

        if #cmdBuffer >= CMD_BUFFER_WARN_THRESHOLD then
            print("[Timetables] flushCmdBuffer: " ..
            #cmdBuffer .. " commands queued (threshold: " .. CMD_BUFFER_WARN_THRESHOLD .. ")")
        end

        for i = 1, #cmdBuffer do
            local ok, err = pcall(api.cmd.sendCommand, cmdBuffer[i])
            if not ok then
                print("[Timetables] cmd flush error: " .. tostring(err))
            end
            cmdBuffer[i] = nil
        end

        helper._pendingManualDeparture = {}
        helper._pendingDepartNow = {}
    end

    function helper.getTime()
        local world = api.engine.util.getWorld()
        if world ~= helper._cache.world then
            helper._cache.world = world
            helper._cache.timeComponent = nil
        end

        local comp = nil
        if world ~= nil then
            comp = api.engine.getComponent(world, api.type.ComponentType.GAME_TIME)
        end

        if comp and comp.gameTime then
            local raw = comp.gameTime
            if raw ~= helper._cache.timeRaw then
                helper._cache.timeRaw = raw
                helper._cache.time    = math.floor(raw / 1000)
            end
            return helper._cache.time
        end
        return 0
    end

    function helper.setPerfEnabled(enabled)
        helper._perf.enabled = enabled == true
    end

    function helper.perfIsEnabled()
        return helper._perf.enabled == true
    end

    function helper.perfBegin(name)
        if helper._perf.enabled ~= true then return nil end
        return { name = name, t0 = os.clock() }
    end

    function helper.perfCount(name, value)
        if helper._perf.enabled ~= true then return end
        local counters = helper._perf.counters
        local c = counters[name]
        if not c then
            c = { count = 0, total = 0, max = 0 }
            counters[name] = c
        end
        local v = value or 0
        c.count = c.count + 1
        c.total = c.total + v
        if v > c.max then c.max = v end
    end

    function helper.perfEnd(token)
        if helper._perf.enabled ~= true then return end
        if not token or not token.name or not token.t0 then return end
        helper.perfCount(token.name, os.clock() - token.t0)
    end

    function helper.perfMaybeFlush()
        if helper._perf.enabled ~= true then return end

        local now = helper.getTime()
        if now < helper._perf.nextFlush then return end
        helper._perf.nextFlush = now + PERF_FLUSH_INTERVAL_SECONDS

        local counters = helper._perf.counters
        if next(counters) == nil then return end

        print("[Timetables][Perf] Snapshot")
        for key, data in pairs(counters) do
            local avg = 0
            if data.count > 0 then avg = data.total / data.count end
            print("[Timetables][Perf] " .. tostring(key)
                .. " count=" .. tostring(data.count)
                .. " total=" .. string.format("%.6f", data.total)
                .. " avg=" .. string.format("%.6f", avg)
                .. " max=" .. string.format("%.6f", data.max))
            counters[key] = nil
        end
    end
end

return init
