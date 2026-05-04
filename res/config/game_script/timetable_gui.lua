--[[
Module: timetable_gui
Role: Game UI layer for editing and applying timetables.

Responsibilities:
- Present lists of lines and stations, allow editing of ArrDep/debounce/auto_debounce constraints.
- Keep a lightweight UI state (`timetableChanged`, `pendingRefresh`) and send updates back
  to the script environment via `game.interface.sendScriptEvent`.
- Drive a scheduler coroutine (via `scheduler.createCoroutineBody`) for background evaluation.

Design and notable choices:
- The GUI is intentionally thin: it delegates heavy logic to `timetable` and `timetable_helper`.
- Uses `pcall` around UI callbacks and periodic tasks to avoid crashing the game/UI loop.
- `timetableChanged` acts as a cooperative flag: GUI sets it after edits; `guiUpdate` sends state to host.
- `pendingRefresh` is a deferred UI refresh mechanism to coalesce expensive UI rebuilds.

Dependencies:
- `timetable`, `timetable_helper`, `scheduler`, `gui` and the TF2 `api` GUI components.
]]

local timetable              = require "timetable"
local timetableHelper        = require "timetable_helper"

local scheduler              = require "scheduler"
local gui                    = require "gui"

local api                    = api
local _                      = _
local game                   = game

local PERF_PROFILING_ENABLED = false
timetableHelper.setPerfEnabled(PERF_PROFILING_ENABLED)

local clockstate              = nil

local menu                    = {
    window         = nil,
    lineTableItems = {},
    popUp          = nil,
}

local UIState                 = {
    currentlySelectedLineTableIndex    = nil,
    currentlySelectedStationIndex      = nil,
    currentlySelectedConstraintType    = nil,
    currentlySelectedStationTabStation = nil,

    stationRowToID                     = {},

    lineRowToID                        = {},
}

local co                      = nil

local state                   = nil

local timetableChanged        = false

local pendingRefresh          = nil

local stationTableScrollOffset
local lineTableScrollOffset
local constraintTableScrollOffset

local lastFrequencyUpdateTime = -1

local lastGCTime              = -1

local UIStrings               = {
    arr          = _("arr_i18n"),
    arrival      = _("arrival_i18n"),
    dep          = _("dep_i18n"),
    departure    = _("departure_i18n"),
    unbunch_time = _("unbunch_time_i18n"),
    unbunch      = _("unbunch_i18n"),
    auto_unbunch = _("auto_unbunch_i18n"),
    timetable    = _("timetable_i18n"),
    timetables   = _("timetables_i18n"),
    line         = _("line_i18n"),
    lines        = _("lines_i18n"),
    min          = _("time_min_i18n"),
    sec          = _("time_sec_i18n"),
    stations     = _("stations_i18n"),
    frequency    = _("frequency_i18n"),
    journey_time = _("journey_time_i18n"),
    arr_dep      = _("arr_dep_i18n"),
    no_timetable = _("no_timetable_i18n"),
    all          = _("all_i18n"),
    add          = _("add_i18n"),
    none         = _("none_i18n"),
    force_dep    = _("force_departure_i18n"),
    min_wait     = _("min_wait_enabled_i18n"),
    max_wait     = _("max_wait_enabled_i18n"),
    margin_time  = _("margin_time_i18n"),
    tooltip      = _("tooltip_i18n"),
}

local local_styles            = {
    zh_CN = "timetable-mono-sc",
    zh_TW = "timetable-mono-tc",
    ja    = "timetable-mono-ja",
    kr    = "timetable-mono-kr",
}

local timetableGUI            = {}

local function getLocalStyle()
    local lang = api.util.getLanguage()
    local s    = local_styles[lang.code]
    return s and { s } or {}
end

local function schedulePendingRefresh(fn)
    pendingRefresh = fn
end

local function getLineIDFromRowIndex(index)
    if index == nil or index < 0 then return nil end

    local dataItem = menu.lineTableItems and menu.lineTableItems[index + 1]
    if dataItem and dataItem.lineID ~= nil then
        return dataItem.lineID
    end

    local mappedLineID = UIState.lineRowToID[index]
    if mappedLineID then
        return mappedLineID
    end

    local allLines = timetableHelper.getAllLines()
    local rowData  = allLines[index + 1]
    return rowData and rowData.id or nil
end

local function _captureScrollOffset(scrollArea)
    if not scrollArea then return nil end
    local tmp = scrollArea:getScrollOffset()
    if not tmp then return nil end
    return api.type.Vec2i.new(tmp.x, tmp.y)
end

local function _restoreScrollOffset(scrollArea, scrollOffset)
    if not (scrollArea and scrollOffset) then return end
    scrollArea:invokeLater(function()
        scrollArea:invokeLater(function()
            scrollArea:setScrollOffset(scrollOffset)
        end)
    end)
end

function timetableGUI.initStationTab()
    if menu.stationTabScrollArea then
        UIState.floatingLayoutStationTab:removeItem(menu.stationTabScrollArea)
    end

    local stationOverview = api.gui.comp.TextView.new("StationOverview")
    menu.stationTabScrollArea = api.gui.comp.ScrollArea.new(
        stationOverview, "timetable.stationTabStationOverviewScrollArea")
    menu.stStations = api.gui.comp.Table.new(1, "SINGLE")
    menu.stationTabScrollArea:setMinimumSize(api.gui.util.Size.new(320, 720))
    menu.stationTabScrollArea:setMaximumSize(api.gui.util.Size.new(320, 720))
    menu.stationTabScrollArea:setContent(menu.stStations)

    timetableGUI.stFillStations()
    UIState.floatingLayoutStationTab:addItem(menu.stationTabScrollArea, 0, 0)

    menu.stationTabLinesScrollArea = api.gui.comp.ScrollArea.new(
        api.gui.comp.TextView.new("LineOverview"), "timetable.stationTabLinesScrollArea")
    menu.stationTabLinesTable = api.gui.comp.Table.new(1, "NONE")
    menu.stationTabLinesScrollArea:setMinimumSize(api.gui.util.Size.new(880, 720))
    menu.stationTabLinesScrollArea:setMaximumSize(api.gui.util.Size.new(880, 720))
    menu.stationTabLinesScrollArea:setContent(menu.stationTabLinesTable)
    UIState.floatingLayoutStationTab:addItem(menu.stationTabLinesScrollArea, 1, 0)
end

function timetableGUI.stFillStations()
    local dirty = timetable.cleanTimetable()
    if dirty then timetableChanged = true end

    menu.stStations:deleteAll()
    UIState.stationRowToID = {}

    local constraintsByStation = timetable.getConstraintsByStation()

    local entries = {}
    for stationID in pairs(constraintsByStation) do
        local name = timetableHelper.getStationName(stationID)

        if name ~= "ERROR" and name ~= -1 then
            entries[#entries + 1] = { id = stationID, name = name }
        end
    end

    table.sort(entries, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    for i, entry in ipairs(entries) do
        UIState.stationRowToID[i - 1] = entry.id
        menu.stStations:addRow({ api.gui.comp.TextView.new(entry.name) })
    end

    menu.stStations:onSelect(function(tabIndex)
        local ok, err = pcall(timetableGUI.stFillLines, tabIndex)
        if not ok then
            print("[Timetables] stFillLines onSelect error: " .. tostring(err))
        end
    end)

    if UIState.currentlySelectedStationTabStation
        and menu.stStations:getNumRows() > UIState.currentlySelectedStationTabStation then
        menu.stStations:select(UIState.currentlySelectedStationTabStation, true)
    end
end

function timetableGUI.stFillLines(tabIndex)
    if tabIndex == -1 then return end
    UIState.currentlySelectedStationTabStation = tabIndex
    menu.stationTabLinesTable:deleteAll()

    local local_style = getLocalStyle()

    local stationID = UIState.stationRowToID[tabIndex]
    if not stationID then return end

    local constraintsByStation = timetable.getConstraintsByStation()
    local stationData = constraintsByStation[stationID]
    if not stationData then return end

    local lineNameOrder = {}
    for lineID, lineData in pairs(stationData) do
        for stopNr, stopData in pairs(lineData) do
            local lineInfoBox = api.gui.comp.Table.new(1, "NONE")

            local lineColourTV = api.gui.comp.TextView.new("●")
            lineColourTV:setName("timetable-linecolour-" ..
                timetableHelper.getLineColour(tonumber(lineID)))
            lineColourTV:setStyleClassList({ "timetable-linecolour" })

            local lineName    = timetableHelper.getLineName(lineID) .. " - Stop " .. stopNr
            local lineNameTV  = api.gui.comp.TextView.new(lineName)

            local lineNameBox = api.gui.comp.Table.new(2, "NONE")
            lineNameBox:setColWidth(0, 25)
            lineNameBox:addRow({ lineColourTV, lineNameTV })
            lineInfoBox:addRow({ lineNameBox })

            local condStr = timetableHelper.conditionToString(
                stopData.conditions[stopData.conditions.type],
                lineID, stopData.conditions.type)
            local condTV = api.gui.comp.TextView.new(condStr)
            condTV:setName("conditionString")
            condTV:setStyleClassList(local_style)
            lineInfoBox:addRow({ condTV })

            menu.stationTabLinesTable:addRow({ lineInfoBox })
            lineNameOrder[#lineNameOrder + 1] = lineName
        end
    end

    local order = timetableHelper.getOrderOfArray(lineNameOrder)
    menu.stationTabLinesTable:setOrder(order)
end

function timetableGUI.initLineTable()
    if menu.scrollArea then
        local tmp = _captureScrollOffset(menu.scrollArea)
        lineTableScrollOffset = tmp or api.type.Vec2i.new()
        UIState.boxlayout2:removeItem(menu.scrollArea)
    else
        lineTableScrollOffset = api.type.Vec2i.new()
    end
    if menu.lineHeader then UIState.boxlayout2:removeItem(menu.lineHeader) end

    menu.scrollArea = api.gui.comp.ScrollArea.new(
        api.gui.comp.TextView.new("LineOverview"), "timetable.LineOverview")
    menu.lineTable = api.gui.comp.Table.new(3, "SINGLE")
    menu.lineTable:setColWidth(0, 28)
    menu.lineTable:setColWidth(1, 240)

    menu.lineTable:onSelect(function(index)
        if index ~= -1 then
            UIState.currentlySelectedLineTableIndex = index
        end
        UIState.currentlySelectedStationIndex = 0

        local ok, err = pcall(timetableGUI.fillStationTable, index, true)
        if not ok then
            print("[Timetables] lineTable onSelect error: " .. tostring(err))
        end
    end)

    menu.scrollArea:setMinimumSize(api.gui.util.Size.new(320, 690))
    menu.scrollArea:setMaximumSize(api.gui.util.Size.new(320, 690))
    menu.scrollArea:setContent(menu.lineTable)
    timetableGUI.fillLineTable()
    UIState.boxlayout2:addItem(menu.scrollArea, 0, 1)
end

function timetableGUI.initStationTable()
    if menu.stationScrollArea then
        local tmp = _captureScrollOffset(menu.stationScrollArea)
        stationTableScrollOffset = tmp or api.type.Vec2i.new()
    else
        stationTableScrollOffset = api.type.Vec2i.new()
        menu.stationScrollArea = api.gui.comp.ScrollArea.new(
            api.gui.comp.TextView.new("stationScrollArea"), "timetable.stationScrollArea")
        menu.stationScrollArea:setMinimumSize(api.gui.util.Size.new(560, 730))
        menu.stationScrollArea:setMaximumSize(api.gui.util.Size.new(560, 730))
        UIState.boxlayout2:addItem(menu.stationScrollArea, 0.5, 0)
    end

    menu.stationTableHeader = api.gui.comp.Table.new(1, "NONE")
    menu.stationTable       = api.gui.comp.Table.new(4, "SINGLE")
    menu.stationTable:setColWidth(0, 40)
    menu.stationTable:setColWidth(1, 120)
    menu.stationTableHeader:addRow({ menu.stationTable })
    menu.stationScrollArea:setContent(menu.stationTableHeader)
    _restoreScrollOffset(menu.stationScrollArea, stationTableScrollOffset)
end

function timetableGUI.initConstraintTable()
    if menu.scrollAreaConstraint then
        local tmp = _captureScrollOffset(menu.scrollAreaConstraint)
        constraintTableScrollOffset = tmp or api.type.Vec2i.new()
    else
        constraintTableScrollOffset = api.type.Vec2i.new()
        menu.scrollAreaConstraint = api.gui.comp.ScrollArea.new(
            api.gui.comp.TextView.new("scrollAreaConstraint"),
            "timetable.scrollAreaConstraint")
        menu.scrollAreaConstraint:setMinimumSize(api.gui.util.Size.new(320, 730))
        menu.scrollAreaConstraint:setMaximumSize(api.gui.util.Size.new(320, 730))
        UIState.boxlayout2:addItem(menu.scrollAreaConstraint, 1, 0)
    end

    menu.constraintTable        = api.gui.comp.Table.new(1, "NONE")
    menu.constraintHeaderTable  = api.gui.comp.Table.new(1, "NONE")
    menu.constraintContentTable = api.gui.comp.Table.new(1, "NONE")
    menu.constraintTable:addRow({ menu.constraintHeaderTable })
    menu.constraintTable:addRow({ menu.constraintContentTable })
    menu.scrollAreaConstraint:setContent(menu.constraintTable)
    _restoreScrollOffset(menu.scrollAreaConstraint, constraintTableScrollOffset)
end

function timetableGUI.showLineMenu()
    if menu.window ~= nil then
        timetableGUI.initLineTable()
        return menu.window:setVisible(true, true)
    end

    if not api.gui.util.getById("timetable.floatingLayout") then
        local fl = api.gui.layout.FloatingLayout.new(0, 1)
        fl:setId("timetable.floatingLayout")
    end
    UIState.boxlayout2 = api.gui.util.getById("timetable.floatingLayout")
    UIState.boxlayout2:setGravity(-1, -1)

    timetableGUI.initLineTable()
    timetableGUI.initStationTable()
    timetableGUI.initConstraintTable()

    menu.tabWidget = api.gui.comp.TabWidget.new("NORTH")
    local wrapper  = api.gui.comp.Component.new("wrapper")
    wrapper:setLayout(UIState.boxlayout2)
    menu.tabWidget:addTab(api.gui.comp.TextView.new(UIStrings.lines), wrapper)

    if not api.gui.util.getById("timetable.floatingLayoutStationTab") then
        local fl = api.gui.layout.FloatingLayout.new(0, 1)
        fl:setId("timetable.floatingLayoutStationTab")
    end
    UIState.floatingLayoutStationTab =
        api.gui.util.getById("timetable.floatingLayoutStationTab")
    UIState.floatingLayoutStationTab:setGravity(-1, -1)

    timetableGUI.initStationTab()
    local wrapper2 = api.gui.comp.Component.new("wrapper2")
    wrapper2:setLayout(UIState.floatingLayoutStationTab)
    menu.tabWidget:addTab(api.gui.comp.TextView.new(UIStrings.stations), wrapper2)

    menu.tabWidget:onCurrentChanged(function(i)
        if i == 1 then
            local ok, err = pcall(timetableGUI.stFillStations)
            if not ok then print("[Timetables] stFillStations error: " .. tostring(err)) end
        end
    end)

    menu.window = api.gui.comp.Window.new(UIStrings.timetables, menu.tabWidget)
    menu.window:addHideOnCloseHandler()
    menu.window:setMovable(true)
    menu.window:setPinButtonVisible(true)
    menu.window:setResizable(false)
    menu.window:setSize(api.gui.util.Size.new(1202, 802))
    menu.window:setPosition(200, 200)
    menu.window:onClose(function()
        menu.lineTableItems = {}
    end)
end

function timetableGUI.applyLineFilter(typeKey, activeBtn, allButtons)
    if not menu.lineTableItems then return end
    if menu._filterInProgress then return end
    menu._filterInProgress = true

    local ok, err = pcall(function()
        local linesOfType = typeKey and timetableHelper.isLineOfType(typeKey) or nil
        for _, item in pairs(menu.lineTableItems) do
            local lineID  = item.lineID
            local visible = (linesOfType == nil)
                or (lineID ~= nil and linesOfType[lineID] == true)
            if item.colour then item.colour:setVisible(visible, false) end
            if item.name then item.name:setVisible(visible, false) end
            if item.button then item.button:setVisible(visible, false) end
        end

        if allButtons then
            for _, btn in ipairs(allButtons) do
                if btn then btn:setSelected(btn == activeBtn, false) end
            end
        end
    end)

    if not ok then
        print("[Timetables] applyLineFilter error: " .. tostring(err))
    end
    menu._filterInProgress = false
end

function timetableGUI.fillLineTable()
    menu.lineTable:deleteRows(0, menu.lineTable:getNumRows())
    if menu.lineHeader then
        menu.lineHeader:deleteAll()
    end

    menu.lineHeader = api.gui.comp.Table.new(6, "None")
    local sortAll   = api.gui.comp.ToggleButton.new(api.gui.comp.TextView.new(UIStrings.all))
    local sortBus   = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new(
        "ui/icons/game-menu/hud_filter_road_vehicles.tga"))
    local sortTram  = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new(
        "ui/TimetableTramIcon.tga"))
    local sortRail  = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new(
        "ui/icons/game-menu/hud_filter_trains.tga"))
    local sortWater = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new(
        "ui/icons/game-menu/hud_filter_ships.tga"))
    local sortAir   = api.gui.comp.ToggleButton.new(api.gui.comp.ImageView.new(
        "ui/icons/game-menu/hud_filter_planes.tga"))
    menu.lineHeader:addRow({ sortAll, sortBus, sortTram, sortRail, sortWater, sortAir })

    local allLines      = timetableHelper.getAllLines()
    local lineNames     = {}
    menu.lineTableItems = {}

    for k, v in ipairs(allLines) do
        local lineColour = api.gui.comp.TextView.new("●")
        lineColour:setName("timetable-linecolour-" .. timetableHelper.getLineColour(v.id))
        lineColour:setStyleClassList({ "timetable-linecolour" })

        local lineNameTV = api.gui.comp.TextView.new(v.name)
        lineNameTV:setName("timetable-linename")
        lineNames[k] = v.name

        local btnImage = api.gui.comp.ImageView.new(
            timetable.hasTimetable(v.id) and "ui/checkbox1.tga" or "ui/checkbox0.tga")
        local btn = api.gui.comp.Button.new(btnImage, true)
        btn:setStyleClassList({ "timetable-activateTimetableButton" })
        btn:setGravity(1, 0.5)

        local lineID = v.id
        btn:onClick(function()
            local has = timetable.hasTimetable(lineID)
            timetable.setHasTimetable(lineID, not has)
            timetableChanged = true
            btnImage:setImage(
                (not has) and "ui/checkbox1.tga" or "ui/checkbox0.tga", false)
            if has then
                timetable.restartAutoDepartureForAllLineVehicles(lineID)

                timetableHelper.flushCmdBuffer(true)
            end
        end)

        menu.lineTableItems[k] = {
            lineID = lineID,
            colour = lineColour,
            name   = lineNameTV,
            button = btn,
        }
        menu.lineTable:addRow({ lineColour, lineNameTV, btn })
    end

    local order = timetableHelper.getOrderOfArray(lineNames)
    menu.lineTable:setOrder(order)

    UIState.lineRowToID = {}
    for displayRow = 0, #allLines - 1 do
        local dataRow = order[displayRow]
        if dataRow == nil then dataRow = displayRow end
        local item = menu.lineTableItems[dataRow + 1]
        if item and item.lineID ~= nil then
            UIState.lineRowToID[displayRow] = item.lineID
        end
    end

    local filterButtons = { sortAll, sortBus, sortTram, sortRail, sortWater, sortAir }
    sortAll:onToggle(function() timetableGUI.applyLineFilter(nil, sortAll, filterButtons) end)
    sortBus:onToggle(function() timetableGUI.applyLineFilter("ROAD", sortBus, filterButtons) end)
    sortTram:onToggle(function() timetableGUI.applyLineFilter("TRAM", sortTram, filterButtons) end)
    sortRail:onToggle(function() timetableGUI.applyLineFilter("RAIL", sortRail, filterButtons) end)
    sortWater:onToggle(function() timetableGUI.applyLineFilter("WATER", sortWater, filterButtons) end)
    sortAir:onToggle(function() timetableGUI.applyLineFilter("AIR", sortAir, filterButtons) end)

    UIState.boxlayout2:addItem(menu.lineHeader, 0, 0)
    menu.scrollArea:invokeLater(function()
        menu.scrollArea:invokeLater(function()
            menu.scrollArea:setScrollOffset(lineTableScrollOffset)
        end)
    end)
end

local function _updateStationTableDataOnly(index, emitSelect)
    if index == nil or index == -1 then return end
    if not menu.stationTable then return end

    timetableGUI.fillStationTable(index, emitSelect)
end

local function _refreshStationUIFull(stationIndex, constraintMakerFn)
    if stationIndex == nil or stationIndex == -1 then return end
    timetableGUI.initStationTable()
    timetableGUI.fillStationTable(stationIndex, false)
    if constraintMakerFn then
        constraintMakerFn()
    end
end

function timetableGUI.fillStationTable(index, emitSelect)
    if index == nil or index == -1 then return end
    if not menu.stationTable then return end

    local lineID = getLineIDFromRowIndex(index)
    if not lineID then return end

    menu.stationTable:deleteAll()
    UIState.currentlySelectedLineTableIndex = index

    local headerTbl = timetableGUI.stationTableHeader(lineID)
    menu.stationTableHeader:setHeader({ headerTbl })

    local stationLegTime          = timetableHelper.getLegTimes(lineID)
    local allStations             = timetableHelper.getAllStations(lineID)
    local vehiclePositions        = timetableHelper.getTrainLocations(lineID)
    local lastTrainLocationUpdate = timetableHelper.getTime()
    local local_style             = getLocalStyle()

    local lineImageByStationIndex = {}

    local refreshDriverImage      = nil

    local function getTrainImage(positions, stationIndex)
        local vp = positions[stationIndex - 1]
        if not vp then return "ui/timetable_line.tga" end
        if vp.atTerminal then
            return vp.countStr == "MANY"
                and "ui/timetable_line_train_in_station_many.tga"
                or "ui/timetable_line_train_in_station.tga"
        else
            return vp.countStr == "MANY"
                and "ui/timetable_line_train_en_route_many.tga"
                or "ui/timetable_line_train_en_route.tga"
        end
    end

    for k, v in ipairs(allStations) do
        local lineImage = api.gui.comp.ImageView.new(getTrainImage(vehiclePositions, k))
        lineImageByStationIndex[k] = lineImage

        if not refreshDriverImage then
            refreshDriverImage = lineImage
        end

        local station = timetableHelper.getStation(v)

        local stationNum = api.gui.comp.TextView.new(tostring(k))
        stationNum:setStyleClassList({ "timetable-stationcolour" })
        stationNum:setName("timetable-stationcolour-" .. timetableHelper.getLineColour(lineID))
        stationNum:setMinimumSize(api.gui.util.Size.new(30, 30))

        local stationNameTV = api.gui.comp.TextView.new(station.name)
        stationNameTV:setName("stationName")

        local journeyTV
        if stationLegTime and stationLegTime[k] then
            journeyTV = api.gui.comp.TextView.new(
                UIStrings.journey_time .. ": " .. os.date("%M:%S", stationLegTime[k]))
        else
            journeyTV = api.gui.comp.TextView.new("")
        end
        journeyTV:setName("conditionString")
        journeyTV:setStyleClassList(local_style)

        local nameTable = api.gui.comp.Table.new(1, "NONE")
        nameTable:addRow({ stationNameTV })
        nameTable:addRow({ journeyTV })
        nameTable:setColWidth(0, 120)

        local condType = timetable.getConditionType(lineID, k)
        local condData = timetable.getConditions(lineID, k, condType)
        local condStr  = timetableHelper.conditionToString(condData, lineID, condType)
        local condTV   = api.gui.comp.TextView.new(condStr)
        condTV:setName("conditionString")
        condTV:setStyleClassList(local_style)
        condTV:setMinimumSize(api.gui.util.Size.new(360, 50))
        condTV:setMaximumSize(api.gui.util.Size.new(360, 50))

        menu.stationTable:addRow({ stationNum, nameTable, lineImage, condTV })
    end

    if refreshDriverImage then
        refreshDriverImage:onStep(function()
            local ok, err = pcall(function()
                local now = timetableHelper.getTime()
                if now == lastTrainLocationUpdate then return end
                lastTrainLocationUpdate = now
                local vpNow = timetableHelper.getTrainLocations(lineID)
                for stationIndex, img in ipairs(lineImageByStationIndex) do
                    if img then
                        img:setImage(getTrainImage(vpNow, stationIndex), false)
                    end
                end
            end)
            if not ok then
                print("[Timetables] stationTable onStep error: " .. tostring(err))
            end
        end)
    end

    menu.stationTable:onSelect(function(tableIndex)
        if tableIndex ~= -1 then
            UIState.currentlySelectedStationIndex = tableIndex

            local ok0, err0 = pcall(timetableGUI.initConstraintTable)
            if not ok0 then
                print("[Timetables] initConstraintTable (onSelect) error: " .. tostring(err0))
            end
            local ok, err = pcall(timetableGUI.fillConstraintTable, tableIndex, lineID)
            if not ok then
                print("[Timetables] stationTable onSelect error: " .. tostring(err))
            end
        end
    end)

    if UIState.currentlySelectedStationIndex then
        local rows = menu.stationTable:getNumRows()
        if rows > UIState.currentlySelectedStationIndex and rows > 0 then
            menu.stationTable:select(UIState.currentlySelectedStationIndex, emitSelect)
        else
            local ok, err = pcall(timetableGUI.initConstraintTable)
            if not ok then
                print("[Timetables] initConstraintTable (else) error: " .. tostring(err))
            end
        end
    end

    menu.stationScrollArea:invokeLater(function()
        menu.stationScrollArea:invokeLater(function()
            menu.stationScrollArea:setScrollOffset(stationTableScrollOffset)
        end)
    end)
end

function timetableGUI.stationTableHeader(lineID)
    local forceDepImg = api.gui.comp.ImageView.new(
        timetable.getForceDepartureEnabled(lineID) and "ui/checkbox1.tga" or "ui/checkbox0.tga")
    local forceDepBtn = api.gui.comp.Button.new(forceDepImg, true)
    forceDepBtn:setStyleClassList({ "timetable-activateTimetableButton" })
    forceDepBtn:setGravity(0, 0.5)
    forceDepBtn:onClick(function()
        local enabled = timetable.getForceDepartureEnabled(lineID)
        timetable.setForceDepartureEnabled(lineID, not enabled)
        forceDepImg:setImage(
            (not enabled) and "ui/checkbox1.tga" or "ui/checkbox0.tga", false)
        timetableChanged = true
    end)
    local forceDepLabel = api.gui.comp.TextView.new(UIStrings.force_dep)
    forceDepLabel:setGravity(1, 0.5)

    local minImg = api.gui.comp.ImageView.new(
        timetable.getMinWaitEnabled(lineID) and "ui/checkbox1.tga" or "ui/checkbox0.tga")
    local minBtn = api.gui.comp.Button.new(minImg, true)
    minBtn:setStyleClassList({ "timetable-activateTimetableButton" })
    minBtn:setGravity(0, 0.5)
    minBtn:onClick(function()
        local enabled = timetable.getMinWaitEnabled(lineID)
        timetable.setMinWaitEnabled(lineID, not enabled)
        minImg:setImage((not enabled) and "ui/checkbox1.tga" or "ui/checkbox0.tga", false)
        timetableChanged = true
    end)
    local minLabel = api.gui.comp.TextView.new(UIStrings.min_wait)
    minLabel:setGravity(1, 0.5)

    local maxImg = api.gui.comp.ImageView.new(
        timetable.getMaxWaitEnabled(lineID) and "ui/checkbox1.tga" or "ui/checkbox0.tga")
    local maxBtn = api.gui.comp.Button.new(maxImg, true)
    maxBtn:setStyleClassList({ "timetable-activateTimetableButton" })
    maxBtn:setGravity(0, 0.5)
    maxBtn:onClick(function()
        local enabled = timetable.getMaxWaitEnabled(lineID)
        timetable.setMaxWaitEnabled(lineID, not enabled)
        maxImg:setImage((not enabled) and "ui/checkbox1.tga" or "ui/checkbox0.tga", false)
        timetableChanged = true
    end)
    local maxLabel = api.gui.comp.TextView.new(UIStrings.max_wait)
    maxLabel:setGravity(1, 0.5)

    local headerTbl = api.gui.comp.Table.new(7, "None")
    headerTbl:addRow({
        api.gui.comp.TextView.new(UIStrings.frequency .. " " ..
            timetableHelper.getFrequencyString(lineID)),
        forceDepLabel, forceDepBtn,
        minLabel, minBtn,
        maxLabel, maxBtn,
    })
    return headerTbl
end

function timetableGUI.clearConstraintWindow()
    if menu.constraintHeaderTable then
        menu.constraintHeaderTable:deleteRows(1, menu.constraintHeaderTable:getNumRows())
    end
end

function timetableGUI.fillConstraintTable(index, lineID)
    if index == -1 then
        if menu.constraintHeaderTable then menu.constraintHeaderTable:deleteAll() end
        return
    end
    index = index + 1

    if menu.constraintHeaderTable then menu.constraintHeaderTable:deleteAll() end

    local comboBox = api.gui.comp.ComboBox.new()
    comboBox:addItem(UIStrings.no_timetable)
    comboBox:addItem(UIStrings.arr_dep)
    comboBox:addItem(UIStrings.unbunch)
    comboBox:addItem(UIStrings.auto_unbunch)
    comboBox:setGravity(1, 0)

    UIState.currentlySelectedConstraintType =
        timetableHelper.constraintStringToInt(timetable.getConditionType(lineID, index))

    comboBox:onIndexChanged(function(i)
        if not api.engine.entityExists(lineID) then return end
        if i == -1 then return end

        local constraintType = timetableHelper.constraintIntToString(i)
        timetable.setConditionType(lineID, index, constraintType)

        local conditions = timetable.getConditions(lineID, index, constraintType)
        if conditions == -1 then return end

        if constraintType == "debounce" then
            conditions[1] = conditions[1] or 0
            conditions[2] = conditions[2] or 0
        elseif constraintType == "auto_debounce" then
            conditions[1] = conditions[1] or 1
            conditions[2] = conditions[2] or 0
        end

        if i ~= UIState.currentlySelectedConstraintType then
            timetableChanged = true

            schedulePendingRefresh(function()
                _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                    timetableGUI.initConstraintTable()
                    timetableGUI.fillConstraintTable(UIState.currentlySelectedStationIndex, lineID)
                end)
            end)
            UIState.currentlySelectedConstraintType = i
        end

        timetableGUI.clearConstraintWindow()
        if menu.constraintContentTable then menu.constraintContentTable:deleteAll() end

        if i == 1 then
            timetableGUI.makeArrDepWindow(lineID, index)
        elseif i == 2 then
            timetableGUI.makeDebounceWindow(lineID, index, "debounce")
        elseif i == 3 then
            timetableGUI.makeDebounceWindow(lineID, index, "auto_debounce")
        end
    end)

    local infoImg = api.gui.comp.ImageView.new("ui/info_small.tga")
    infoImg:setTooltip(UIStrings.tooltip)
    infoImg:setName("timetable-info-icon")

    local tbl = api.gui.comp.Table.new(2, "NONE")
    tbl:addRow({ infoImg, comboBox })
    menu.constraintHeaderTable:addRow({ tbl })
    comboBox:setSelected(UIState.currentlySelectedConstraintType, true)

    menu.scrollAreaConstraint:invokeLater(function()
        menu.scrollAreaConstraint:invokeLater(function()
            menu.scrollAreaConstraint:setScrollOffset(constraintTableScrollOffset)
        end)
    end)
end

function timetableGUI.makeArrDepWindow(lineID, stationID)
    if not (menu.constraintTable and menu.constraintHeaderTable) then return end

    local separationList = { 30, 20, 15, 12, 10, 7.5, 6, 5, 4, 3, 2.5, 2, 1.5, 1.2, 1 }
    local separationCombo = api.gui.comp.ComboBox.new()
    for _, v in ipairs(separationList) do
        separationCombo:addItem(v .. " min (" .. 60 / v .. "/h)")
    end
    separationCombo:setGravity(1, 0)

    local function generateSlots(separationIndex, templateSlot)
        if separationIndex == -1 or not templateSlot then return end
        local sep = separationList[separationIndex + 1]
        for i = 1, math.floor(60 / sep) - 1 do
            timetable.addCondition(lineID, stationID,
                { type = "ArrDep", ArrDep = { timetable.shiftSlot(templateSlot, i * sep * 60) } })
        end
    end

    local generateBtn = api.gui.comp.Button.new(api.gui.comp.TextView.new("Generate"), true)
    generateBtn:setGravity(1, 0)
    generateBtn:onClick(function()
        local conditions = timetable.getConditions(lineID, stationID, "ArrDep")
        if conditions == -1 or #conditions < 1 then
            timetableGUI.popUpMessage(
                "You must have one initial arrival / departure time", function() end)
            return
        end
        local si = separationCombo:getCurrentIndex()
        if si == -1 then
            timetableGUI.popUpMessage("You must select a separation", function() end)
            return
        end

        generateBtn:setEnabled(false)
        if #conditions > 1 then
            local first = conditions[1]
            timetable.removeAllConditions(lineID, stationID, "ArrDep")
            timetable.addCondition(lineID, stationID,
                { type = "ArrDep", ArrDep = { first } })
            generateSlots(si, first)
        else
            generateSlots(si, conditions[1])
        end
        generateBtn:setEnabled(true)

        timetableChanged = true
        schedulePendingRefresh(function()
            _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                timetableGUI.makeArrDepConstraintsTable(lineID, stationID)
            end)
        end)
    end)

    local recurringTbl = api.gui.comp.Table.new(3, "NONE")
    recurringTbl:addRow({
        api.gui.comp.TextView.new("Separation"), separationCombo, generateBtn
    })
    menu.constraintHeaderTable:addRow({ recurringTbl })

    local addBtn = api.gui.comp.Button.new(api.gui.comp.TextView.new(UIStrings.add), true)
    addBtn:setGravity(-1, 0)
    addBtn:onClick(function()
        timetable.addCondition(lineID, stationID,
            { type = "ArrDep", ArrDep = { { 0, 0, 0, 0 } } })
        timetableChanged = true
        schedulePendingRefresh(function()
            _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                timetableGUI.makeArrDepConstraintsTable(lineID, stationID)
            end)
        end)
    end)

    local deleteAllBtn = api.gui.comp.Button.new(api.gui.comp.TextView.new("X All"), true)
    deleteAllBtn:setGravity(-1, 0)
    deleteAllBtn:onClick(function()
        timetable.removeAllConditions(lineID, stationID, "ArrDep")
        timetableChanged = true
        schedulePendingRefresh(function()
            _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                timetableGUI.makeArrDepConstraintsTable(lineID, stationID)
            end)
        end)
    end)

    local headerRow = api.gui.comp.Table.new(4, "NONE")
    headerRow:setColWidth(1, 85)
    headerRow:setColWidth(2, 60)
    headerRow:setColWidth(3, 60)
    headerRow:addRow({
        addBtn,
        api.gui.comp.TextView.new(UIStrings.min),
        api.gui.comp.TextView.new(UIStrings.sec),
        deleteAllBtn,
    })
    menu.constraintHeaderTable:addRow({ headerRow })

    timetableGUI.makeArrDepConstraintsTable(lineID, stationID)
end

function timetableGUI.makeArrDepConstraintsTable(lineID, stationID)
    local conditions = timetable.getConditions(lineID, stationID, "ArrDep")
    if type(conditions) ~= "table" then return end
    if menu.constraintContentTable then
        menu.constraintContentTable:deleteAll()
    end

    local function makeSpinBox(value, min, max, onChangeFn)
        local sb = api.gui.comp.DoubleSpinBox.new()
        sb:setMinimum(min, false)
        sb:setMaximum(max, false)
        sb:setValue(value, false)
        sb:onChange(onChangeFn)
        return sb
    end

    for k, v in ipairs(conditions) do
        menu.constraintContentTable:addRow({
            api.gui.comp.Component.new("HorizontalLine")
        })

        local arrLabel = api.gui.comp.TextView.new(UIStrings.arrival .. ":  ")
        arrLabel:setMinimumSize(api.gui.util.Size.new(75, 30))

        local arrMin = makeSpinBox(v[1], 0, 59, function(val)
            timetable.updateArrDep(lineID, stationID, k, 1, val)
            timetableChanged = true
            schedulePendingRefresh(function()
                _updateStationTableDataOnly(UIState.currentlySelectedLineTableIndex, false)
            end)
        end)
        local arrSec = makeSpinBox(v[2], 0, 59, function(val)
            timetable.updateArrDep(lineID, stationID, k, 2, val)
            timetableChanged = true
            schedulePendingRefresh(function()
                _updateStationTableDataOnly(UIState.currentlySelectedLineTableIndex, false)
            end)
        end)

        local delLabel = api.gui.comp.TextView.new("     X")
        delLabel:setMinimumSize(api.gui.util.Size.new(60, 10))
        local delBtn = api.gui.comp.Button.new(delLabel, true)
        delBtn:onClick(function()
            delBtn:setEnabled(false)
            timetable.removeCondition(lineID, stationID, "ArrDep", k)
            timetableChanged = true
            schedulePendingRefresh(function()
                _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                    timetableGUI.makeArrDepConstraintsTable(lineID, stationID)
                end)
            end)
            delBtn:setEnabled(true)
        end)

        local arrRow = api.gui.comp.Table.new(5, "NONE")
        arrRow:setColWidth(1, 60); arrRow:setColWidth(2, 25)
        arrRow:setColWidth(3, 60); arrRow:setColWidth(4, 60)
        arrRow:addRow({ arrLabel, arrMin, api.gui.comp.TextView.new(":"), arrSec, delBtn })
        menu.constraintContentTable:addRow({ arrRow })

        local depLabel = api.gui.comp.TextView.new(UIStrings.departure .. ":  ")
        depLabel:setMinimumSize(api.gui.util.Size.new(75, 30))

        local depMin = makeSpinBox(v[3], 0, 59, function(val)
            timetable.updateArrDep(lineID, stationID, k, 3, val)
            timetableChanged = true
            schedulePendingRefresh(function()
                _updateStationTableDataOnly(UIState.currentlySelectedLineTableIndex, false)
            end)
        end)
        local depSec = makeSpinBox(v[4], 0, 59, function(val)
            timetable.updateArrDep(lineID, stationID, k, 4, val)
            timetableChanged = true
            schedulePendingRefresh(function()
                _updateStationTableDataOnly(UIState.currentlySelectedLineTableIndex, false)
            end)
        end)

        local insLabel = api.gui.comp.TextView.new("     +")
        insLabel:setMinimumSize(api.gui.util.Size.new(60, 10))
        local insBtn = api.gui.comp.Button.new(insLabel, true)
        insBtn:onClick(function()
            timetable.insertArrDepCondition(lineID, stationID, k, { 0, 0, 0, 0 })
            timetableChanged = true
            schedulePendingRefresh(function()
                _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                    timetableGUI.makeArrDepConstraintsTable(lineID, stationID)
                end)
            end)
        end)

        local depRow = api.gui.comp.Table.new(5, "NONE")
        depRow:setColWidth(1, 60); depRow:setColWidth(2, 25)
        depRow:setColWidth(3, 60); depRow:setColWidth(4, 60)
        depRow:addRow({ depLabel, depMin, api.gui.comp.TextView.new(":"), depSec, insBtn })
        menu.constraintContentTable:addRow({ depRow })

        menu.constraintContentTable:addRow({
            api.gui.comp.Component.new("HorizontalLine")
        })
    end
end

function timetableGUI.makeDebounceWindow(lineID, stationID, debounceType)
    if not menu.constraintHeaderTable then return end

    local frequency = timetableHelper.getFrequencyMinSec(lineID)
    local condition = timetable.getConditions(lineID, stationID, debounceType)
    if condition == -1 then return end

    local autoMin, autoSec

    local function updateAutoDisplay()
        if debounceType ~= "auto_debounce" then return end
        local cond = timetable.getConditions(lineID, stationID, debounceType)
        if cond == -1 then return end
        if type(frequency) == "table" and autoMin and autoSec and cond[1] and cond[2] then
            local t = (frequency.min - cond[1]) * 60 + frequency.sec - cond[2]
            if t >= 0 then
                autoMin:setText(tostring(math.floor(t / 60)))
                autoSec:setText(tostring(math.floor(t % 60)))
            else
                autoMin:setText("--")
                autoSec:setText("--")
            end
        end
    end

    local headerRow = api.gui.comp.Table.new(3, "NONE")
    headerRow:setColWidth(0, 175)
    headerRow:setColWidth(1, 85)
    headerRow:setColWidth(2, 60)
    headerRow:addRow({
        api.gui.comp.TextView.new(""),
        api.gui.comp.TextView.new(UIStrings.min),
        api.gui.comp.TextView.new(UIStrings.sec),
    })
    menu.constraintHeaderTable:addRow({ headerRow })

    local debounceRow = api.gui.comp.Table.new(4, "NONE")
    debounceRow:setColWidth(0, 175)
    debounceRow:setColWidth(1, 60)
    debounceRow:setColWidth(2, 25)
    debounceRow:setColWidth(3, 60)

    local debMin = api.gui.comp.DoubleSpinBox.new()
    debMin:setMinimum(0, false)

    if debounceType == "auto_debounce" and type(frequency) == "table" then
        debMin:setMaximum(frequency.min, false)
    else
        debMin:setMaximum(59, false)
    end
    if condition and condition[1] then debMin:setValue(condition[1], false) end
    debMin:onChange(function(val)
        timetable.updateDebounce(lineID, stationID, 1, val, debounceType)
        timetableChanged = true
        updateAutoDisplay()
        schedulePendingRefresh(function()
            _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                timetableGUI.initConstraintTable()
                timetableGUI.fillConstraintTable(UIState.currentlySelectedStationIndex, lineID)
            end)
        end)
    end)

    local debSec = api.gui.comp.DoubleSpinBox.new()
    debSec:setMinimum(0, false)
    debSec:setMaximum(59, false)
    if condition and condition[2] then debSec:setValue(condition[2], false) end
    debSec:onChange(function(val)
        timetable.updateDebounce(lineID, stationID, 2, val, debounceType)
        timetableChanged = true
        updateAutoDisplay()
        schedulePendingRefresh(function()
            _refreshStationUIFull(UIState.currentlySelectedLineTableIndex, function()
                timetableGUI.initConstraintTable()
                timetableGUI.fillConstraintTable(UIState.currentlySelectedStationIndex, lineID)
            end)
        end)
    end)

    local headerLabel = debounceType == "auto_debounce"
        and api.gui.comp.TextView.new(UIStrings.margin_time .. ":")
        or api.gui.comp.TextView.new(UIStrings.unbunch_time .. ":")

    debounceRow:addRow({ headerLabel, debMin, api.gui.comp.TextView.new(":"), debSec })

    if debounceType == "auto_debounce" then
        autoMin = api.gui.comp.TextView.new("--")
        autoSec = api.gui.comp.TextView.new("--")
        updateAutoDisplay()
        local unbunchLabel = api.gui.comp.TextView.new(UIStrings.unbunch_time .. ":")
        debounceRow:addRow({
            unbunchLabel, autoMin, api.gui.comp.TextView.new(":"), autoSec
        })
    end

    menu.constraintHeaderTable:addRow({ debounceRow })
end

function timetableGUI.popUpMessage(message, onOK)
    if menu.popUp then menu.popUp:close() end
    local okBtn = api.gui.comp.Button.new(api.gui.comp.TextView.new("OK"), true)
    menu.popUp  = api.gui.comp.Window.new(message, okBtn)
    local pos   = api.gui.util.getMouseScreenPos()
    menu.popUp:setPosition(pos.x, pos.y)
    menu.popUp:addHideOnCloseHandler()

    menu.popUp:onClose(function() if onOK then onOK() end end)
    okBtn:onClick(function() menu.popUp:close() end)
end

function timetableGUI.popUpYesNo(title, onYes, onNo)
    if menu.popUp then menu.popUp:close() end
    local popTbl = api.gui.comp.Table.new(2, "NONE")
    local yesBtn = api.gui.comp.Button.new(api.gui.comp.TextView.new("Yes"), true)
    local noBtn  = api.gui.comp.Button.new(api.gui.comp.TextView.new("No"), true)
    popTbl:addRow({ yesBtn, noBtn })
    menu.popUp = api.gui.comp.Window.new(title, popTbl)
    local pos  = api.gui.util.getMouseScreenPos()
    menu.popUp:setPosition(pos.x, pos.y)
    menu.popUp:addHideOnCloseHandler()

    local yesPressed = false
    menu.popUp:onClose(function()
        if yesPressed and onYes then onYes() else if onNo then onNo() end end
        menu.popUp = nil
    end)
    yesBtn:onClick(function()
        yesPressed = true; menu.popUp:close()
    end)
    noBtn:onClick(function() menu.popUp:close() end)
end

--[[
data(): UI descriptor for the game's GUI host.

Returns a table with lifecycle callbacks invoked by the engine:

- handleEvent(self, id, _, param):
    * Receives script events (notably `timetableUpdate`) sent from other game systems.
    * Normalizes and delegates incoming timetable payloads to `timetable.setTimetableObject`.
    * Uses `pcall` to ensure malformed payloads don't crash the UI.

- save():
    * Called when the game serializes the UI state. Returns a `state` table containing the
        timetable object obtained from `timetable.getTimetableObject()`.

- load(loadedState):
    * Restores UI state on load; validates and migrates legacy payloads safely.
    * Always initializes the `timetable.initializeTimetableLinesCache()` to ensure the GUI
        can build its tables without relying on delayed background initialization.

- update():
    * Per-frame engine update; resumes the internal `scheduler` coroutine in small slices,
        flushes pending helper commands and updates frequency-related bookkeeping.

- guiUpdate():
    * Runs on the GUI tick. If `timetableChanged` is set, sends the current timetable to the
        host via `game.interface.sendScriptEvent` and clears the flag. Also runs any
        `pendingRefresh` functions (deferred UI rebuilds) in a safe `pcall`.

Design notes:
- Keep callbacks cheap; heavy work is done by `timetable` and `timetable_helper`.
- All external interactions are wrapped in `pcall` or `xpcall` to avoid breaking the
    global UI/engine loop if an error occurs.
]]
function data()
    return {

        handleEvent = function(_, id, _, param)
            if id == "timetableUpdate" then
                if state == nil then state = { timetable = {} } end
                if type(param) == "table" then
                    state.timetable = param
                    local ok, err = pcall(timetable.setTimetableObject, state.timetable)
                    if not ok then
                        print("[Timetables] handleEvent: setTimetableObject failed: " .. tostring(err))
                    else
                        timetableChanged = true
                    end
                else
                    print("[Timetables] handleEvent: ignored malformed timetableUpdate payload")
                end
            end
        end,

        save = function()
            state = {}
            state.timetable = timetable.getTimetableObject()
            return state
        end,

        load = function(loadedState)
            state = loadedState or { timetable = {} }
            if type(state) ~= "table" then
                state = { timetable = {} }
            end
            if type(state.timetable) ~= "table" then
                state.timetable = {}
            end

            local ok, err = pcall(timetable.setTimetableObject, state.timetable)
            if not ok then
                print("[Timetables] load: setTimetableObject failed, resetting: " .. tostring(err))
                timetable.setTimetableObject({})
            end

            timetable.initializeTimetableLinesCache()
        end,

        update = function()
            local perfUpdate = timetableHelper.perfBegin("engine.update")
            if state == nil then state = { timetable = {} } end

            if co == nil or coroutine.status(co) == "dead" then
                co = coroutine.create(scheduler.createCoroutineBody())
            end

            local perfResume = timetableHelper.perfBegin("engine.update.resume")
            for _ = 1, 20 do
                if coroutine.status(co) == "suspended" then
                    local ok, err = coroutine.resume(co)
                    if not ok then
                        print("[Timetables] coroutine error: " .. tostring(err))
                        co = nil
                        break
                    end
                end
            end
            timetableHelper.perfEnd(perfResume)

            local perfFlushCmd = timetableHelper.perfBegin("engine.update.flushCmd")
            timetableHelper.flushCmdBuffer(true)
            timetableHelper.perfEnd(perfFlushCmd)

            local now = timetableHelper.getTime()
            if now ~= lastFrequencyUpdateTime then
                lastFrequencyUpdateTime = now
                local perfFreq = timetableHelper.perfBegin("engine.update.frequency")
                local ttObj = timetable.getTimetableObject()
                local activeLines = 0
                for line, lineData in pairs(ttObj) do
                    if lineData and lineData.hasTimetable then
                        activeLines = activeLines + 1
                        timetable.addFrequency(line, timetableHelper.getFrequency(line))
                    end
                end
                timetableHelper.perfCount("engine.update.frequency.activeLines", activeLines)
                timetableHelper.perfEnd(perfFreq)
            end

            timetableHelper.perfEnd(perfUpdate)
            timetableHelper.perfMaybeFlush()
        end,

        guiUpdate = function()
            local perfGui = timetableHelper.perfBegin("gui.update")

            local _ok, _err = xpcall(function()
                if timetableChanged then
                    local perfSendEvent = timetableHelper.perfBegin("gui.update.sendEvent")
                    local ok, err = pcall(
                        game.interface.sendScriptEvent,
                        "timetableUpdate", "", timetable.getTimetableObject())
                    if not ok then
                        print("[Timetables] sendScriptEvent error: " .. tostring(err))
                    else
                        timetableChanged = false
                    end
                    timetableHelper.perfEnd(perfSendEvent)
                end

                if pendingRefresh then
                    local fn = pendingRefresh
                    pendingRefresh = nil
                    local perfRefresh = timetableHelper.perfBegin("gui.update.pendingRefresh")
                    local ok, err = pcall(fn)
                    if not ok then
                        print("[Timetables] pendingRefresh error: " .. tostring(err))
                    end
                    timetableHelper.perfEnd(perfRefresh)
                end

                if not clockstate then
                    local line     = api.gui.comp.Component.new("VerticalLine")
                    local icon     = api.gui.comp.ImageView.new("ui/clock_small.tga")
                    clockstate     = api.gui.comp.TextView.new("gameInfo.time.label")

                    local btnLabel = gui.textView_create(
                        "gameInfo.timetables.label", UIStrings.timetable)
                    local btn      = gui.button_create("gameInfo.timetables.button", btnLabel)
                    btn:onClick(function()
                        local ok, err = pcall(timetableGUI.showLineMenu)
                        if not ok then
                            menu.window = nil
                            print("[Timetables] showLineMenu error: " .. tostring(err))
                        end
                    end)
                    game.gui.boxLayout_addItem("gameInfo.layout", btn.id)

                    local layout = api.gui.util.getById("gameInfo"):getLayout()
                    layout:addItem(line)
                    layout:addItem(icon)
                    layout:addItem(clockstate)

                    clockstate:setTooltip("Current Time")

                    clockstate:onStep(function()
                        local ok, err = pcall(function()
                            clockstate:setText(os.date("%M:%S", timetableHelper.getTime()))
                        end)
                        if not ok then
                            print("[Timetables] clockstate onStep error: " .. tostring(err))
                        end
                    end)
                end

                local now = timetableHelper.getTime()
                if now - lastGCTime >= 60 then
                    lastGCTime = now
                    collectgarbage()
                end
            end, function(e)
                print("[Timetables] guiUpdate UNHANDLED: " .. tostring(e))
                print(debug.traceback())
                return e
            end)

            timetableHelper.perfEnd(perfGui)
            timetableHelper.perfMaybeFlush()
        end,
    }
end

_G.timetableGUI = timetableGUI
