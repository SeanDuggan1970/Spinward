# Working on Spinward

Read `docs/DESIGN.md` first. It is the source of truth for scope, pillars and architecture.

## Architecture rules

- `sim/` never touches nodes, scenes or rendering. It must run headless.
- Every state change goes through `Sim.apply(command)`. Commands are plain Dictionaries with a `"type"` key. Do not mutate state from `view/`. This keeps saves, replays, balance bots and future co-op possible.
- Systems (`sim/systems/`) extend `system.gd`, register their own command handlers, and never call each other. They communicate through state and `sim.emit(...)` events.
- Gameplay numbers live in `data/`, never in code. When you add a tunable value, put it in `data/balance.json` or a content file.
- New state fields go in `GameState.to_dict` / `load_dict`. Changing the meaning of saved data requires bumping `SCHEMA_VERSION` and adding a migration in `sim/save_io.gd`.
- Positions in the sim are 64-bit metres and seconds in a heliocentric frame. Rendering uses a floating origin. Use the stock Godot build, not a custom double-precision build.
- Scripts are linked with `preload`, not `class_name`, so headless `--script` tests resolve them.

## Design guardrails

- Hopeful tone. Hazards over villains. Combat is the last step of the conflict ladder and is non-lethal by default.
- Hard physics is bent for fun on purpose. Record each departure in `docs/RESEARCH.md` or `docs/DESIGN.md`.
- Real-world data (JPL) is baked into `data/` by tools. The game never needs the internet.
- Third-party assets need a recorded licence and a credits line.

## Checks

Run `./tools/validate.ps1` (PowerShell) before committing. Add tests in `tests/run_tests.gd` for new sim rules.
