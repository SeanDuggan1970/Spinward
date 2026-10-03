# Spinward

A hopeful near-future space trading game set in our real solar system. Trade to build wealth, explore further with better drives, and finally build your own home: a rotating O'Neill cylinder inside a hollowed asteroid or comet.

Inspired by Elite, but not a remake. See [docs/DESIGN.md](docs/DESIGN.md) for the game and its architecture, and [docs/RESEARCH.md](docs/RESEARCH.md) for the sources and reasoning behind it.

**Status: M1, the cislunar trading slice, is playable,** with eight places and megastructures in the sky.
- **Places:** eight real-orbit places around Earth and the Moon, including four Lagrange-point stations and Kalpana One, a 500 m-wide settlement drum.
- **Megastructures** on the approaches:
  - the Kibo skyhook
  - Clarke Exchange's kilometre-wide power satellites
  - the Luna Line lunar elevator rising from Halo Depot
  - Island One, a Bernal sphere under construction beside The Kernel
  - the Farside megatelescope mirrors
- **Trading:** eleven goods with supply, demand and production chains.
- **Ship:** a modular Mule-class hauler with shipyard upgrades.
- **Travel:** routes plotted by the co-pilot under time compression.
- **Docking:** hand-flown at spinning stations, or call a tug for a fee.
- **Saves:** quick save and quick load.

Three megaprojects are under way: Island One, the second Luna Line ribbon and Kalpana Two. Haul what they need, watch them grow in the sky, and see your share on the Projects tab.

Twenty-seven NPC ships share the system: Cooperative ice tankers, Commons drone freighters, independent haulers, Compact couriers and Kernel shuttles. They trade from the same markets you do, chatter on comms, and come and go around the stations.

Placeholder art throughout. See [docs/balance/NOTES.md](docs/balance/NOTES.md) for balance status.

## Play

`Play.cmd` runs the game and `Edit.cmd` opens the Godot editor. The first run downloads the pinned Godot 4.7.2 into `.tools/` and checks its SHA-512.

The game opens on an attract screen: each ship class flies in and turns under a work light, with its caption, in front of Kibo Ring and Earth. Press Space to start, L to load your quick save, or Esc to quit.

You start docked at Kibo Ring in low Earth orbit with 10,000 credits and a second-hand hauler.

1. **Market:** buy low. Green prices are cheap, amber prices are good to sell into.
2. **Departures:** pick a destination. The co-pilot shows distance, time, propellant and the best cargo for that route.
3. **Transit:** you ride in the cockpit. Earth, Moon and Sun are at their true positions and sizes from wherever the ship is.
   - Halfway, the ship flips and brakes tail-first.
   - Arrows look around, C re-centres, and Z is a telescope.
   - M switches to the system map.
   - `[` / `]` change time compression, which drops to ×1 on arrival.
4. **Approach:** fly in and dock, or press **T** for the tug (60 cr).
5. **Tip Line tab:** buy tips about other ports from local info brokers. They aren't all honest or right. Tips are checked when you dock there, and you build a record of whom to trust. Your knowledge of other ports' prices is only as fresh as your last visit (you start with an old logbook).
6. **Traffic tab:** see who's in port, who's inbound and what's on comms. Use time compression while docked to wait for prices to move.
7. **Shipyard** (Kibo Ring, Trojan Yards): bolt on bigger cargo pods, tanks, radiators and drives.

| Keys | Flight |
|---|---|
| W / S | Thrust forward / back |
| A / D, R / F | Strafe left/right, up/down |
| Arrows, Q / E | Pitch/yaw, roll |
| Shift, X | Boost, brake |
| Z | Assist: full (auto-brake) → assisted (damped turning) → manual |
| V | Spin match: co-pilot rolls you with the station's port |
| C | Cockpit (default) / chase camera |
| G | Scanner range: 500 m, 2 km, 8 km, 30 km |
| H | Show / hide key help |
| T | Call the tug |

You fly from the cockpit. The dashboard has the classic Elite 3D scanner: an ellipse for your horizontal plane, with forward up the screen. Each contact sits at its bearing on the ellipse, with a stalk up or down for height: green for the station, fleet colours for ships, yellow for work pods. The compass dot shows the port, solid when it's ahead and hollow when it's behind.

**How to dock by hand.** The co-pilot's prompt above the dashboard walks you through it:
1. Point the nose straight down the station's axis, along the amber corridor lights. Not at the port box: the ALIGN gauge must be under 15°.
2. Strafe (A/D, R/F) onto the axis. Inside 400 m, the AXIS display shows where the axis is; put the dot in the green ring.
3. Close in (W) at the advised speed, which falls as you get near. Brake with S or X.
4. Leave spin match on and it keys the slot for you.

A clean approach from 600 m takes about three minutes. The docking computer (15,000 cr at Kibo Ring or Trojan Yards, then press K) flies it for you, and the tug (T) always comes, on credit if you're broke. In the Market tab, "keep a reserve" makes Buy max leave money for the tug and a full tank.

To dock, bring the ship's nose to the port slowly (under 1.5 m/s). Keep the nose on the axis (within 15°) and key the slot (roll within 20°). The port lights turn green when all three are right.

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
