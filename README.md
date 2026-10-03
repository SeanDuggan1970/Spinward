# Spinward

A hopeful near-future space trading game set in our real solar system. Trade to build wealth, explore further with better drives, and finally build your own home: a rotating O'Neill cylinder inside a hollowed asteroid or comet.

Inspired by Elite, but not a remake. See [docs/DESIGN.md](docs/DESIGN.md) for the game and its architecture, and [docs/RESEARCH.md](docs/RESEARCH.md) for the sources and reasoning behind it.

**Status:** M0 foundation. The sim/data/view skeleton, command system, game clock, time compression and versioned saves work and are tested. There is no gameplay yet. Next is M1, the Earth–Moon trading slice.

## Run

- `Play.cmd` runs the game. `Edit.cmd` opens the Godot editor.
- The first run downloads the pinned Godot 4.7.2 into `.tools/` and verifies its SHA-512 checksum.
- In the M0 screen: Space pauses, and `[` / `]` change time compression.

## Check

```powershell
./tools/validate.ps1
```

This runs the Godot import, the headless sim tests (`tests/run_tests.gd`) and a scene smoke test.

## Layout

| Folder | Purpose |
|---|---|
| `sim/` | Game rules only, no rendering. All changes go through commands. |
| `data/` | Content and balance values (JSON). Tune the game here. |
| `view/` | Godot scenes and UI. Reads state, sends commands. |
| `tools/` | Setup, play and validation scripts. Later: data bakers and balance bots. |
| `tests/` | Headless tests. |
| `docs/` | Design, research, decisions. |
