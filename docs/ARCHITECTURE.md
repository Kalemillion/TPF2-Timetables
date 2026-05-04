# Timetables 1.6 — Architecture

This document describes the current module boundaries, runtime responsibilities, and GUI contract for the mod.

## Overview
- The mod is split into four practical layers: GUI, runtime core, scheduler, and helper utilities.
- The GUI in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua) is intentionally thin. It reads and edits state, then delegates the heavy work to [res/scripts/timetable.lua](../res/scripts/timetable.lua), [res/scripts/timetable_helper.lua](../res/scripts/timetable_helper.lua), and [res/scripts/scheduler.lua](../res/scripts/scheduler.lua).
- The current codebase uses canonical top-level module names instead of the old `celmi/timetables` namespace.

## Module Layout

### Runtime core: [res/scripts/timetable.lua](../res/scripts/timetable.lua)
- Owns the timetable data model and all departure evaluation logic.
- Stores the in-memory timetable object and the derived caches used by the GUI and scheduler.
- Handles ArrDep, debounce, auto_debounce, slot math, and vehicle waiting state.
- Normalizes incoming timetable payloads before they enter the runtime state.

Important public functions include:
- `getTimetableObject`
- `setTimetableObject`
- `getCachedTimetableLines`
- `initializeTimetableLinesCache`
- `addLineToTimetableCache`
- `removeLineFromTimetableCache`
- `setConditionType`
- `getConditionType`
- `getConditions`
- `getConstraintsByStation`
- `getAllConditionsOfAllStations`
- `addFrequency`
- `addCondition`
- `insertArrDepCondition`
- `updateArrDep`
- `updateDebounce`
- `removeAllConditions`
- `removeCondition`
- `hasTimetable`
- `setHasTimetable`
- `setForceDepartureEnabled`
- `getForceDepartureEnabled`
- `setMinWaitEnabled`
- `getMinWaitEnabled`
- `setMaxWaitEnabled`
- `getMaxWaitEnabled`
- `restartAutoDepartureForAllLineVehicles`
- `updateForVehicle`
- `departIfReady`
- `readyToDepart`
- `readyToDepartArrDep`
- `readyToDepartDebounce`
- `manualDebounceDepartureTime`
- `autoDebounceDepartureTime`
- `anotherVehicleArrivedEarlier`
- `afterDepartureTime`
- `afterArrivalSlot`
- `afterDepartureSlot`
- `getNextSlot`
- `arrayContainsSlot`
- `slotsEqual`
- `slotToArrivalSlot`
- `slotToDepartureSlot`
- `minToSec`
- `secToMin`
- `minToStr`
- `secToStr`
- `getTimeDifference`
- `shiftTime`
- `shiftSlot`
- `cleanTimetable`

### Helper aggregation: [res/scripts/timetable_helper.lua](../res/scripts/timetable_helper.lua)
- This file is no longer the only helper implementation. It now aggregates smaller modules into a single `timetableHelper` table.
- The composed API is built from:
  - [res/scripts/helper/core.lua](../res/scripts/helper/core.lua)
  - [res/scripts/helper/collections.lua](../res/scripts/helper/collections.lua)
  - [res/scripts/helper/display.lua](../res/scripts/helper/display.lua)
  - [res/scripts/helper/engine.lua](../res/scripts/helper/engine.lua)
- This layout makes it easier to mock individual helper concerns in tests while keeping the runtime API stable.

### Defensive helpers: [res/scripts/guard.lua](../res/scripts/guard.lua)
- Provides lightweight runtime validation and error reporting.
- Current helpers are:
  - `againstNil`
  - `safe`
  - `check`
- The guard module is used where the code needs explicit fail-fast behavior without duplicating boilerplate.

### Scheduler: [res/scripts/scheduler.lua](../res/scripts/scheduler.lua)
- The scheduler drives periodic vehicle processing through a coroutine body.
- It walks the line-to-vehicle map, dispatches timetable vehicles to the core runtime, and keeps non-timetable vehicles on auto-departure when needed.
- It uses a batch-size heuristic to yield cooperatively under heavier loads.
- It also performs periodic calls to `timetable.cleanTimetable()` so stale state is removed even when the GUI is idle.

## Caching Strategy
- `timetableLinesCache` is a lightweight set keyed by line id.
- The cache is populated by `initializeTimetableLinesCache()` and exposed through `getCachedTimetableLines()`.
- Individual lines can be added or removed with `addLineToTimetableCache()` and `removeLineFromTimetableCache()`.
- Derived views built from the timetable object are invalidated whenever the timetable state mutates.
- The cache is designed as a read-optimized helper for GUI and scheduler paths, not as the source of truth.

## Data Model and Migrations
- `setTimetableObject()` normalizes incoming data before storing it.
- Current normalization behavior includes:
  - converting string line ids to numeric keys when possible,
  - converting string station ids to numeric keys when possible,
  - resetting malformed non-table payloads to an empty timetable object,
  - initializing missing `stations` tables,
  - initializing missing `conditions` tables,
  - migrating legacy `conditions.condition` to `conditions.type`,
  - initializing `ArrDep` and `vehiclesWaiting` for ArrDep stations,
  - removing stale `vehiclesWaiting` data from non-ArrDep stations.
- `frequency` is treated as runtime state rather than persisted timetable data.
- The runtime is intentionally defensive so it can load both current and legacy save payloads without crashing.

## GUI Contract
- The GUI updates the timetable through `timetable.setTimetableObject()` and related public APIs.
- `timetableChanged` is the main change flag used by the GUI loop.
- `pendingRefresh` is used to defer expensive UI rebuilds and avoid repeated full redraws.
- `handleEvent()` accepts `timetableUpdate` payloads from the host side and rejects malformed data instead of failing hard.
- `guiUpdate()` sends timetable updates through `game.interface.sendScriptEvent`, clears the change flag after a successful send, and executes any queued refresh callbacks.
- The GUI also preserves scroll position when rebuilding the line and station tables.
- Row-to-id mapping is maintained explicitly so visible ordering does not depend on incidental table iteration order.

## Testing
- The current regression coverage lives in [tests/timetable_fusion_tests.lua](../tests/timetable_fusion_tests.lua).
- The tests use mocked TF2 runtime modules via `package.loaded` to keep runtime dependencies isolated.
- Coverage currently includes:
  - ArrDep departure cleanup,
  - timetable cache initialization,
  - GUI event flow and `guiUpdate` dispatch,
  - load-time cache initialization,
  - malformed payload hardening,
  - legacy condition migration,
  - string-key normalization for line and station ids.

## Implementation Notes
- Avoid adding direct TF2 API calls outside `timetable_helper` unless the code is specifically GUI-facing.
- Keep the GUI reactive and lightweight. When the GUI needs more information, prefer adding a public runtime API over duplicating logic in the UI layer.
- When extending the runtime, make sure cache invalidation and migration logic stay in sync with the new fields.
- When extending the GUI, maintain the existing `timetableChanged` and `pendingRefresh` contract so the event loop remains stable.
