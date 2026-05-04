local function init(helper)
    function helper.getAutoUnbunchFor(lineID, cond)
        local frequency = helper.getFrequencyMinSec(lineID)
        if type(frequency) == "table" then
            local unbunchTime = (frequency.min - (cond[1] or 0)) * 60
                + frequency.sec - (cond[2] or 0)
            if unbunchTime >= 0 then
                return helper.UIStrings.unbunchTime .. ": "
                    .. string.format("%02d", math.floor(unbunchTime / 60)) .. ":"
                    .. string.format("%02d", math.floor(unbunchTime % 60))
            end
        end
        return helper.UIStrings.unbunchTime .. ": --:--"
    end

    function helper.conditionToString(cond, lineID, condType)
        if not cond or not condType then return "" end
        if condType == "ArrDep" then
            local arr = helper.UIStrings.arr
            local dep = helper.UIStrings.dep
            for _, v in ipairs(cond) do
                arr = arr .. string.format("%02d", v[1]) .. ":" .. string.format("%02d", v[2]) .. "|"
                dep = dep .. string.format("%02d", v[3]) .. ":" .. string.format("%02d", v[4]) .. "|"
            end
            return arr .. "\n" .. dep
        elseif condType == "debounce" then
            local m = cond[1] or 0
            local s = cond[2] or 0
            return helper.UIStrings.unbunchTime .. ": "
                .. string.format("%02d", m) .. ":"
                .. string.format("%02d", s)
        elseif condType == "auto_debounce" then
            local m          = cond[1] or 0
            local s          = cond[2] or 0
            local marginCond = { m, s }
            local margin     = "Margin Time:  " .. string.format("%02d", m) .. ":" .. string.format("%02d", s)
            local unbunch    = helper.getAutoUnbunchFor(lineID, marginCond)
            return margin .. "\n" .. unbunch
        end
        return condType
    end

    function helper.constraintIntToString(i)
        if i == 0 then
            return "None"
        elseif i == 1 then
            return "ArrDep"
        elseif i == 2 then
            return "debounce"
        elseif i == 3 then
            return "auto_debounce"
        end
        return "ERROR"
    end

    function helper.constraintStringToInt(s)
        if s == "None" then
            return 0
        elseif s == "ArrDep" then
            return 1
        elseif s == "debounce" then
            return 2
        elseif s == "auto_debounce" then
            return 3
        end
        return 0
    end
end

return init
