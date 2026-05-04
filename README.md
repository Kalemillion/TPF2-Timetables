# Timetables 1.6 — README

Overview
- A Transport Fever 2 mod that provides advanced timetable management for lines and vehicles.
- The goal is to offer departure/arrival constraints, debounce and auto-debounce strategies, and a GUI for managing timetables in game.

Requirements and Compatibility
- Transport Fever 2 (a version compatible with scripted mods).
- Install the mod folder into the TF2 mods directory (see Installation Instructions).
- Mod version: v1.6 (minorVersion = 6). Designed to remain backward compatible with legacy timetable formats; back up your saves before testing.

Key Files (References)
- mod.lua — mod metadata and version.
- res/config/game_script/timetable_gui.lua — user interface code and GUI integration.
- res/scripts/timetable.lua — core timetable logic (ArrDep, debounce, cache, etc.).
- tests/timetable_fusion_tests.lua — local unit tests added for regression coverage.
- docs/CHANGELOG.md — release notes for v1.6.


Available Features (Implemented)
- ArrDep: arrival/departure constraints (ArrDep) with support for waiting vehicles.
- Debounce: a delay mechanism used to group or separate departures according to configured rules.
- Auto-debounce: an automatic variant tied to line frequency.
- GUI: interface for viewing/editing timetables, triggering event dispatches, and initializing the timetable line cache.
- Line cache: `timetable.initializeTimetableLinesCache()` and related APIs for internal management of active lines.

Backward Compatibility Notes
- The code normalizes timetable payloads on load:
  - converts IDs provided as strings to numbers (if applicable).
  - automatically migrates the legacy `conditions.condition` field to `conditions.type`.
  - defensively initializes missing fields (`stations`, `ArrDep`, `vehiclesWaiting`).
- Recommendation: back up the mods folder and your saves before testing the update in production.

Quick Usage (Trigger / Verify)
- Open the interface defined in res/config/game_script/timetable_gui.lua to edit and apply timetables.
- Changes in the UI trigger `timetable.setTimetableObject(...)` and set the `timetableChanged` flag for GUI event dispatch.
- Automatic departure cases are handled in res/scripts/timetable.lua (functions `departIfReady`, `readyToDepartArrDep`, `readyToDepartDebounce`, etc.).

Tests and Local Validation
- A unit test file is included: tests/timetable_fusion_tests.lua. It covers regression cases for: vehiclesWaiting cleanup, line cache initialization, basic GUI behavior, and payload hardening.
- The tests are intended to run in the TF2 environment (in game) or through a compatible Lua runtime if you have an out-of-game test environment.

Support / Bug Reports
- Open an issue on the repository/fork you are using, and include: mod version (mod.lua), a short description, reproduction steps, and console logs if possible.
