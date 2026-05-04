# Timetables 1.6 — CONTRIBUTING

This document explains how to contribute, run tests locally, and follow project conventions.

Project layout (key files)
- mod.lua — mod metadata and `minorVersion`.
- res/config/game_script/timetable_gui.lua — GUI entrypoint and UI logic.
- res/scripts/timetable.lua — core timetable logic (conditions, ArrDep, debounce, cache).
- res/scripts/timetable_helper.lua (and helper/*) — helper utilities and TF2 API wrappers.
- tests/ — unit tests used during development; key file: tests/timetable_fusion_tests.lua.
- docs/CHANGELOG.md — release notes.

Coding conventions
- Language: Lua (follow existing style in res/scripts/*).
- Functions: prefer descriptive names (e.g. `departIfReady`, `readyToDepartArrDep`, `initializeTimetableLinesCache`).
- Modules: export a module table and attach functions as fields (existing pattern used in timetable.lua).
- Variables: prefer clear names; use local scope for internal variables. Avoid single-letter globals.

Require / module paths
- Use canonical module names without legacy namespace prefixes. Examples:
  - use `require "timetable"` instead of `require ".res.scripts.celmi.timetables.timetable"` or `require "celmi/timetables/timetable"`.
  - canonical test mocks should target the canonical keys in `package.loaded` (see tests pattern below).

Tests and mocking pattern
- Tests mock TF2- and helper-level dependencies by setting entries in `package.loaded` before requiring the module under test. Example pattern used across tests:

  package.loaded['timetable_helper'] = mockTimetableHelper
  package.loaded['guard'] = mockGuard
  resetModule('timetable') -- remove timetable from package.loaded to force reload
  local timetable = require('timetable')

- Place new unit tests under `tests/` and follow the existing style: plain Lua functions that assert conditions and are collected by a `test()` runner.
- Keep mocks minimal and explicit: provide only the functions needed by the code under test (e.g. `getTime`, `getVehiclesOnLine`, `departVehicle`, performance stubs).

How to add a test to tests/timetable_fusion_tests.lua
1. Open tests/timetable_fusion_tests.lua.
2. Add a new test entry as `tests[#tests + 1] = function() ... end` following existing examples.
3. Use the helper functions `loadTimetableWithMocks()` or `loadGuiDataWithMocks()` in the file to obtain a mock environment when possible.
4. Keep tests deterministic: set fixed return values for time and vehicle info in mocks.
5. Run the test runner in-game or via an available Lua runtime that can load the mod environment (the project currently expects TF2 runtime for full integration).

Commit guidelines
- Keep changes small and focused per PR.
- Update docs/CHANGELOG.md for user-facing behaviour changes or bug fixes.
- For code changes that affect public API (module names, exported functions), document migration notes in docs/ARCHITECTURE.md and add tests.

Extension points and areas likely to need attention
- Scheduler / coroutine pattern: scheduler.createCoroutineBody and its consumer are central for engine updates — changes must preserve coroutine resume/yield semantics.
- Cache layer: timetableLinesCache and derived caches (`_constraintsByStationCache`, `_allConditionsCache`) must be invalidated when timetable data changes; add tests to protect invalidation logic.
- Helpers: timetable_helper provides wrappers to TF2 API and vehicle/line utilities — extend with caution and include mocks for tests.

Debugging tips
- Use prints in TF2 console to inspect behavior during GUI interactions (GUI code logs failures and sendScriptEvent errors).
- When changing `timetable.setTimetableObject`, ensure legacy payloads (string IDs, legacy `conditions.condition`) remain normalized; tests exist in tests/timetable_fusion_tests.lua.

Contact and workflow
- Fork the repository, implement changes on a feature branch, open a PR with a clear description and reference to tests added/updated.
- Include minimal reproduction steps for any bugfix PR.
