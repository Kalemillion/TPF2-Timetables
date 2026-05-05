# Timetables 1.6 — CONTRIBUTING

This document explains how to contribute and follow project conventions.

Project layout (key files)
- mod.lua — mod metadata and `minorVersion`.
- res/config/game_script/timetable_gui.lua — GUI entrypoint and UI logic.
- res/scripts/timetable.lua — core timetable logic (conditions, ArrDep, debounce, cache).
- res/scripts/timetable_helper.lua (and helper/*) — helper utilities and TF2 API wrappers.
- docs/CHANGELOG.md — release notes.

Coding conventions
- Language: Lua (follow existing style in res/scripts/*).
- Functions: prefer descriptive names (e.g. `departIfReady`, `readyToDepartArrDep`, `initializeTimetableLinesCache`).
- Modules: export a module table and attach functions as fields (existing pattern used in timetable.lua).
- Variables: prefer clear names; use local scope for internal variables. Avoid single-letter globals.

Require / module paths
- Use canonical module names without legacy namespace prefixes. Examples:
  - use `require "timetable"` instead of `require ".res.scripts.celmi.timetables.timetable"` or `require "celmi/timetables/timetable"`.

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
- When changing `timetable.setTimetableObject`, ensure legacy payloads (string IDs, legacy `conditions.condition`) remain normalized.

Contact and workflow
- Fork the repository, implement changes on a feature branch, open a PR with a clear description and reference to tests added/updated.
- Include minimal reproduction steps for any bugfix PR.
