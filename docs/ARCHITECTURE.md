# Timetables 1.6 — Architecture

Overview
- The mod is organized into three primary layers: GUI (res/config/game_script), Core Logic (res/scripts), and Helpers (res/scripts/helper and timetable_helper).
- The GUI is intentionally thin: it delegates heavy lifting to `timetable` and `timetable_helper` and uses `game.interface.sendScriptEvent` for async UI updates.

Key modules
- `timetable` (res/scripts/timetable.lua)
  - Responsibilities: timetable data model, validation, caching, schedule evaluation (ArrDep), departure logic, and public API used by GUI and tests.
  - Important functions: `setTimetableObject`, `getNextDeparturesForLine`, `deckifyTimetableForLine`, `departIfReady`, `initializeTimetableLinesCache`.
- `timetable_helper` (res/scripts/timetable_helper.lua)
  - TF2 API wrappers, vehicle and line utilities used by `timetable` and tests.
- `guard` (res/scripts/guard.lua)
  - Safety and input validation helpers used by GUI and core logic.

Scheduler pattern
- The scheduler creates coroutine bodies that run periodic work without blocking the GUI. Modules interact by registering jobs with the scheduler and yielding to allow GUI updates.

Caching strategy
- `timetable` maintains an in-memory `timetableLinesCache` keyed by line id. Cache functions exist to `initialize`, `get`, `add`, and `remove`. Clients (GUI) call `initializeTimetableLinesCache()` on load to pre-populate.
- Cache invalidation occurs on `setTimetableObject` and when lines are modified; ensure tests cover invalidation.

Data model and migrations
- Timetable objects are normalized on `setTimetableObject`:
  - IDs coerced to numbers where possible.
  - Legacy `conditions.condition` migrated to `conditions.type`.
  - Station objects are normalized to include `id`, `name`, and default fields.

GUI contract
- GUI code expects the `timetable` public APIs and subscribes to updates via `game.interface.sendScriptEvent`. The GUI sets `timetableChanged = true` to trigger background updates.

Testing
- Tests run using a mock pattern that replaces TF2 runtime modules in `package.loaded` before requiring modules under test. See tests/timetable_fusion_tests.lua for examples.

Notes
- Avoid adding direct TF2 API calls outside `timetable_helper` unless they are GUI-specific. This helps keep core logic testable.
- The project intentionally keeps the GUI reactive and lightweight; prefer adding public APIs to `timetable` when GUI needs more data rather than embedding logic in GUI code.
