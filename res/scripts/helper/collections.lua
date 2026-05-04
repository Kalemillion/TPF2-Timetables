local function init(helper)
    function helper.getOrderOfArray(arr)
        local order = {}
        for i = 1, #arr do
            order[i] = i
        end

        table.sort(order, function(a, b)
            return string.lower(arr[a]) < string.lower(arr[b])
        end)

        local res = {}
        for i = 1, #order do
            res[i - 1] = order[i] - 1
        end
        return res
    end

    function helper.mergeArray(a, b)
        if a == nil then return b end
        if b == nil then return a end
        local ab = {}
        for _, v in pairs(a) do ab[#ab + 1] = v end
        for _, v in pairs(b) do ab[#ab + 1] = v end
        return ab
    end

    function helper.maximumArray(arr)
        if not arr or #arr == 0 then return 0 end
        local max = arr[1]
        for i = 2, #arr do
            if arr[i] > max then max = arr[i] end
        end
        return max
    end

    function helper.hasValue(tab, val)
        for _, v in pairs(tab) do
            if v == val then return true end
        end
        return false
    end

    function helper.dump(o)
        if type(o) == "table" then
            local s = "{ "
            for k, v in pairs(o) do
                if type(k) ~= "number" then k = '"' .. k .. '"' end
                s = s .. "[" .. k .. "]=" .. helper.dump(v) .. ","
            end
            return s .. "} "
        end
        return tostring(o)
    end
end

return init
