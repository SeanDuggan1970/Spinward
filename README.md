# Spinward

A hopeful near-future space trading game set in our real solar system. Trade to build wealth, explore further with better drives, and finally build your own home: a rotating O'Neill cylinder inside a hollowed asteroid or comet.

Inspired by Elite, but not a remake. See [docs/DESIGN.md](docs/DESIGN.md) for the game and its architecture, and [docs/RESEARCH.md](docs/RESEARCH.md) for the sources and reasoning behind it.

**Status: M1, the cislunar trading slice, is playable.**
- **Places:** six real-orbit places around Earth and the Moon, including three Lagrange-point stations.
- **Trading:** eleven goods with supply, demand and production chains.
- **Ship:** a modular Mule-class hauler with shipyard upgrades.
- **Travel:** routes plotted by the co-pilot under time compression.
- **Docking:** hand-flown at spinning stations, or call a tug for a fee.
- **Saves:** quick save and quick load.

Twenty-two NPC ships share the system: Cooperative ice tankers, Commons drone freighters, independent haulers, Compact couriers and Kernel shuttles. They trade from the same markets you do, chatter on comms, and come and go around the stations.

Placeholder art throughout. See [docs/balance/NOTES.md](docs/balance/NOTES.md) for balance status.

## Play

`Play.cmd` runs the game and `Edit.cmd` opens the Godot editor. The first run downloads the pinned Godot 4.7.2 into `.tools/` and checks its SHA-512.

You start docked at Kibo Ring in low Earth orbit with 5,000 credits and a second-hand hauler.

1. **Market:** buy low. Green prices are cheap, amber prices are good to sell into.
2. **Departures:** pick a destination. The co-pilot shows distance, time, propellant and the best cargo for that route.
3. **Transit:** watch the map. `[` / `]` change time compression, and it drops to ×1 on arrival.
4. **Approach:** fly in and dock, or press **T** for the tug (60 cr).
5. **Traffic tab:** see who's in port, who's inbound and what's on comms. Use time compression while docked to wait for prices to move.
6. **Shipyard** (Kibo Ring, Trojan Yards): bolt on bigger cargo pods, tanks, radiators and drives.

| Keys | Flight |
|---|---|
| W / S | Thrust forward / back |
| A / D, R / F | Strafe left/right, up/down |
| Arrows, Q / E | Pitch/yaw, roll |
| Shift, X | Boost, brake |
| Z | Assist: full (auto-brake) → assisted (damped turning) → manual |
| V | Spin match: co-pilot rolls you with the station's port |
| C | Chase / nose camera |
| T | Call the tug |

To dock, bring the ship's nose to the port slowly (under 1.2 m/s). Keep the nose on the axis (within 12°) and key the slot (roll within 15°). The port lights turn green when all three are right.

Everywhere: P pauses, F5 quick saves, F9 quick loads.

## Check and tune

```powershell
./tools/validate.ps1
```

This runs the import, 81 headless sim checks and an end-to-end smoke test. The smoke test buys, departs, arrives, gets refused on a fast approach, then flies a slow approach and docks.

To regenerate [docs/balance/report.md](docs/balance/report.md) after changing anything in `data/`, run the balance bot:

```powershell
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/balance_bot.gd -- days=180 upgrade=1
```

To capture screenshots of every screen into a folder (needs a window):

```powershell
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . -- --tour=C:/temp/spinward-tour
```

## Layout

| Folder | Purpose |
|---|---|
| `sim/` | Game rules only, no rendering. All changes go through commands. |
| `data/` | Content and balance values (JSON). Tune the game here. |
| `view/` | Godot scenes and UI. Reads state, sends commands. |
| `tools/` | Setup, play, validation and the balance bot. |
| `tests/` | Headless tests. |
| `docs/` | Design, research, balance reports and notes. |

## Credits

The orbital elements are approximate. Earth's come from JPL's "Approximate Positions of the Planets", and the Moon's are mean elements after Meeus, *Astronomical Algorithms*. See `data/bodies.json`. No third-party art assets yet.
