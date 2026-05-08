# TPF2-Timetables

## Overview
TPF2-Timetables is a Transport Fever 2 script mod that adds a timetable system for vehicles. It lets you control when a vehicle arrives, departs, waits, or stays spaced out from other vehicles on the same line.

The mod introduces a fully integrated timetable system that works directly at stop level, allowing precise control over how vehicles behave throughout a line. It supports multiple vehicles per station while maintaining structured waiting rules, and provides configurable minimum and maximum dwell times to fine-tune flow. The system is designed to remain stable across save/load cycles, ensuring that schedules persist reliably without desynchronization. It also includes robust handling of legacy or incomplete data, reducing edge-case issues when upgrading existing saves.

It is designed for players who want to move beyond basic interval-based line management and achieve a higher level of operational control. It significantly improves the consistency of transport networks by reducing vehicle bunching and stabilizing service frequency, even under heavy network load. At the same time, it removes the need for constant manual intervention, letting you focus on network design rather than micromanaging individual vehicles. The result is a more predictable, efficient, and realistic transport system that scales cleanly with large and complex cities.

For each stop, you can choose between the following modes:
- **None**: Use the vanilla game logic.
- **Arrival/Departure**: Choose a departure slot based on the nearest valid arrival/departure window.
- **Unbunch**: Prevent a vehicle from leaving before the configured delay has passed.
- **AutoUnbunch**: Space vehicles according to the line frequency, with extra slack for delays.

And per line, you can add:
- **Force Departure**: sends the vehicle immediately when conditions are met.
- **Min. wait Enabled**: enforces the station’s in-game minimum waiting time.
- **Max. wait Enabled**: applies the station’s in-game maximum waiting limit to avoid overstaying.

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
