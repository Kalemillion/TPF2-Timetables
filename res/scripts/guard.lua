local guard = {}

local MOD_PREFIX = "[Timetables]"

function guard.againstNil(parameter, label)
    if parameter == nil then
        local info   = debug.getinfo(2, "n")
        local caller = (info and info.name) or "<?>"
        local lbl    = label and (" '" .. tostring(label) .. "'") or ""
        print(MOD_PREFIX .. " ERROR – nil parameter" .. lbl .. " in " .. caller .. "()")

        print(debug.traceback())
    end
end

function guard.safe(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        print(MOD_PREFIX .. " RUNTIME ERROR: " .. tostring(result))
    end
    return ok and result or nil
end

function guard.check(cond, msg)
    if not cond then
        error(MOD_PREFIX .. " ASSERTION FAILED: " .. tostring(msg), 2)
    end
end

return guard
