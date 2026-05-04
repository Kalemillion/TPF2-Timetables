# Changelog

## ConstasJ's v1.5 => Kalemillion's v1.6

Compared to v1.5, this release is a structural refactor of the mod rather than a narrow feature patch. The runtime now uses canonical module paths, the timetable core is hardened against malformed payloads and legacy data, the GUI contract is safer and more responsive, the helper layer is split into smaller units, and the test suite is consolidated around a single regression file.

### 🚀 Features
- Added a canonical runtime layout under [res/scripts](../res/scripts) and removed the older namespaced `celmi/timetables` path used by the workshop build.
- Introduced [res/scripts/scheduler.lua](../res/scripts/scheduler.lua) as a dedicated scheduler loop for periodic timetable processing and maintenance.
- Added a helper aggregation layer in [res/scripts/timetable_helper.lua](../res/scripts/timetable_helper.lua) so the runtime now composes helper submodules instead of keeping every TF2 wrapper in one file.
- Added the helper submodules under [res/scripts/helper](../res/scripts/helper) for core utilities, display helpers, engine access, and collection helpers.
- Expanded [res/scripts/timetable.lua](../res/scripts/timetable.lua) with explicit cache management, runtime normalization, and structured departure handling.
- Added a richer GUI contract in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua), including deferred refresh handling and safer event processing.
- Added [tests/timetable_fusion_tests.lua](../tests/timetable_fusion_tests.lua) as the new consolidated regression file for the merged runtime and GUI behavior.
- Expanded [strings.lua](../strings.lua) with many additional language entries and regional variants.
- Updated [mod.lua](../mod.lua) so the mod title and description now resolve through `modname_name` and `modname_desc`.

### 🔧 Refactoring / Optimization
- Replaced the old `require "celmi/timetables/..."` namespace with canonical module names such as `timetable`, `timetable_helper`, `guard`, `scheduler`, and `helper.*`.
- Split the previous helper blob into smaller modules so the TF2 API wrappers, engine helpers, and utility functions now have clearer ownership boundaries.
- Added `guard.safe`, `guard.check`, and `guard.againstNil` in [res/scripts/guard.lua](../res/scripts/guard.lua) to centralize defensive checks and runtime error reporting.
- Added derived-cache invalidation in [res/scripts/timetable.lua](../res/scripts/timetable.lua) so cached station views are cleared whenever timetable state changes.
- Reworked line caching in [res/scripts/timetable.lua](../res/scripts/timetable.lua) to expose `initializeTimetableLinesCache`, `getCachedTimetableLines`, `addLineToTimetableCache`, and `removeLineFromTimetableCache`.
- Added scroll-offset preservation in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua) so line and station tables keep their viewport position across rebuilds.
- Added deferred UI rebuilds through `pendingRefresh` in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua) to avoid repeated expensive refreshes during UI churn.
- Added a dynamic batch-size heuristic in [res/scripts/scheduler.lua](../res/scripts/scheduler.lua) so the runtime yields more intelligently under heavier vehicle counts.
- Added periodic cleanup in [res/scripts/scheduler.lua](../res/scripts/scheduler.lua) so `timetable.cleanTimetable()` runs on a timer instead of only from the UI path.
- Refined stylesheet assets in [res/config/style_sheet/timetable_stylesheet.lua](../res/config/style_sheet/timetable_stylesheet.lua) and [res/config/style_sheet/timetable_colors.lua](../res/config/style_sheet/timetable_colors.lua) to support the reorganized UI and multilingual mono fonts.

### 🐛 Bugfixes
- Hardened [res/scripts/timetable.lua](../res/scripts/timetable.lua) so malformed payloads no longer leave the mod in an invalid state.
- Normalized string-based line IDs to numeric keys in [res/scripts/timetable.lua](../res/scripts/timetable.lua), which avoids broken lookups after JSON-style serialization.
- Normalized string-based station IDs in [res/scripts/timetable.lua](../res/scripts/timetable.lua) so station tables can be recovered even when keys arrive as text.
- Migrated legacy `conditions.condition` data to `conditions.type` in [res/scripts/timetable.lua](../res/scripts/timetable.lua) for backward compatibility.
- Ensured `stations`, `ArrDep`, `vehiclesWaiting`, and `hasTimetable` are initialized defensively in [res/scripts/timetable.lua](../res/scripts/timetable.lua).
- Removed stale `vehiclesWaiting` state when a station is not using ArrDep logic, preventing dead vehicle claims from surviving after a condition change.
- Fixed the ArrDep departure flow so `departIfReady` clears the departing vehicle from `vehiclesWaiting` after the actual departure.
- Kept auto-departure behavior consistent by restarting the vehicle departure loop when a non-timetable vehicle is still sitting in terminal state.
- Hardened the GUI event path in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua) so malformed `timetableUpdate` payloads are ignored instead of crashing the UI.
- Ensured `guiUpdate` resets `timetableChanged` after a successful send in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua), avoiding duplicate event spam.
- Guarded line and station table rebuilding with `pcall` in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua) so UI callback failures are logged instead of terminating the UI loop.
- Improved station sorting and row-to-ID mapping in [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua), which reduces row-order bugs when the visible order changes.
- Added explicit logging around `cleanTimetable`, `pendingRefresh`, and `handleEvent` failures to make runtime issues easier to diagnose.

### 📝 Documentation
- Rewrote [README.md](../README.md) and turned it into a cleaner technical overview for users and modders.
- Added [docs/CHANGELOG.md](CHANGELOG.md) as the canonical release note file for this branch.
- Removed the older internal analysis documents from [docs](../docs) in favor of inline module documentation and the new changelog structure.
- Updated inline module headers in [res/scripts/timetable.lua](../res/scripts/timetable.lua), [res/config/game_script/timetable_gui.lua](../res/config/game_script/timetable_gui.lua), and [res/scripts/scheduler.lua](../res/scripts/scheduler.lua) to document responsibilities and design choices directly in code.

### Architecture Notes
- The current architecture is documented in [docs/ARCHITECTURE.md](ARCHITECTURE.md) and serves as the reference for module boundaries.
- The mod follows a canonical layout: GUI in [res/config/game_script](../res/config/game_script), runtime logic in [res/scripts](../res/scripts), and helper composition in [res/scripts/helper](../res/scripts/helper).
- [res/scripts/timetable.lua](../res/scripts/timetable.lua) is the source of truth for timetable state, cache invalidation, payload migration, and departure evaluation.
- [res/scripts/scheduler.lua](../res/scripts/scheduler.lua) owns cooperative periodic processing and cleanup.
- [res/scripts/timetable_helper.lua](../res/scripts/timetable_helper.lua) aggregates helper modules instead of exposing a single monolithic TF2 wrapper file.
- The GUI relies on `timetableChanged` and `pendingRefresh` as part of its event and refresh contract, with `game.interface.sendScriptEvent` as the bridge back to script-side state.
