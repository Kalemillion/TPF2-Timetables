# TPF2-Timetables

## Overview
TPF2-Timetables is a Transport Fever 2 script mod that adds a timetable system for vehicles. It lets you control when a vehicle arrives, departs, waits, or stays spaced out from other vehicles on the same line.

On the current rewrite of the mod the runtime is more defensive, the GUI is safer, the helper layer is split into smaller modules, and the project now includes consolidated tests and updated documentation.

For each stop, you can choose between the following modes:
- **None**: Use the vanilla game logic.
- **Arrival/Departure**: Choose a departure slot based on the nearest valid arrival/departure window.
- **Unbunch**: Prevent a vehicle from leaving before the configured delay has passed.
- **AutoUnbunch**: Space vehicles according to the line frequency, with extra slack for delays.

The mod also supports multi-vehicle station handling, minimum and maximum wait times, and save/load-safe timetable state.
Its goal is to improve performance and reliability in-game while having a maintainable, documented stable base for future modders.

Technical details are documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and release notes are tracked in [docs/CHANGELOG.md](docs/CHANGELOG.md).

## Highlights in this Version
- Canonical runtime modules under [res/scripts](res/scripts) instead of the older `celmi/timetables` namespace.
- Dedicated scheduler logic for periodic processing and cleanup.
- Safer timetable normalization for legacy or malformed save data.
- Deferred GUI refresh handling to reduce unnecessary rebuilds.
- Split helper modules for cleaner responsibilities and easier testing.
- Updated localization strings for the current UI and mod title.

## Contributing
Bug reports, feature ideas, documentation improvements, and pull requests are welcome.
