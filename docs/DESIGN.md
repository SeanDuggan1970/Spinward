# Spinward design

Living document. Version 0.1, 3 October 2026. Every number here is a starting value to tune, kept in `data/`, never hard-coded.

## Pitch

The 2060s. Humanity and its AI partners are spreading into the solar system, our own backyard. You start as an independent pilot with a small fusion ship and an AI co-pilot in Earth orbit. You trade between real places (stations, the Moon, Lagrange points, then Mars, the Belt and beyond), using real orbits on a real calendar. Wealth buys better drives. Better drives reach further. Further out, you survey, stake a claim and finally build your own home: a spinning O'Neill cylinder inside a hollowed asteroid or comet.

**Tone:** hopeful near-future. Scarcity is ending, but not evenly or without friction. The dangers are space itself and misunderstanding between people, both human and AI. Combat is the last resort.

## Pillars

1. **Trade → Explore → Build Home.** Each stage funds and motivates the next. The base is the ultimate goal and the biggest money sink.
2. **The real solar system, made playable.** Real bodies and orbits. The AI co-pilot handles orbital mechanics, so the player makes decisions instead of doing calculus.
3. **Hazards over villains.** Radiation, heat, debris, fuel, life support and ice that breaks apart. Respect for physics is the main skill.
4. **Conflict is costly.** Talk, trade, reputation and evasion come first. Weapons disable rather than destroy, and using them always costs something.
5. **Everything is tunable.** Rules and content are data. Balance is an ongoing process, supported by tools.

## Core loops

| Scale | Loop | Example |
|---|---|---|
| Minutes | Fly → dock → deal | Undock from Gateway Station, thread the traffic lane, dock at a Lagrange depot with a tight approach |
| Session (30–60 min) | Find a route → buy → travel → sell → upgrade | Lunar ice to Earth orbit, electronics back up, profit spent on a bigger tank |
| Campaign | Drive tier → new region → new opportunities → claim → build | Torch drive opens the Belt, you survey a carbonaceous rock, file a claim, and start stage 1 of your base |

## Progression

Drive tiers gate regions naturally (travel times in `RESEARCH.md` §2).

| Tier | Drive | Region | New gameplay |
|---|---|---|---|
| 1 | Pathfinder (close to real fusion) | Earth orbit, Moon, Earth–Moon Lagrange points | Trading basics, docking, first contracts |
| 2 | Courier | Near-Earth asteroids, Mars and its moons | Surveying, mining contracts, the first faction politics |
| 3 | Torch | Main belt: Ceres, Vesta, Psyche | Claims, mining drones, **base stages 1–3** |
| 4 | Long Reach | Jupiter and Saturn moons, comets | Radiation hazards, ice-rich claims, **base stages 4–6**, late story |

Other upgrade tracks: cargo, tanks, radiators (heat), shielding (radiation), sensors (survey), drones, co-pilot software (better assist and route planning), and reputation and licences.

## Economy

- **Goods** (first set): water ice, oxygen, propellant, fusion pellets, regolith, refined metals, electronics, food, medical supplies, machine parts, habitat modules, survey data.
- **Places** produce and consume goods through **recipes** (inputs → outputs per day), defined in `data/`.
- **Price** follows stock against the target stock, within a band per good and place. Buying raises local prices and selling lowers them, so a route's profit fades if you farm it.
- **Events** shift supply and demand: a solar storm grounds traffic, a new habitat opens, a comet arrives.
- **Post-scarcity flavour:** basic goods get cheaper over the campaign as automation spreads. Profit moves to rare, distant, time-critical or skilled work. This keeps the frontier attractive and stops early routes from staying optimal.

## Exploration and claims

Scan bodies to reveal their composition, value and hazards. Sell survey data or keep it. To claim a body, file with the relevant authority: costs, rules and politics vary by region. Real named bodies are handmade. The many unnamed small bodies are generated from real orbit-population statistics, so new discoveries are possible.

## Your base: the cylinder in the rock

Stages, each needing specific goods, money and time:

1. **Claim & survey camp**: a beacon, a small pressurised module, a supply depot.
2. **Excavation**: mining drones hollow out the core. The spoil becomes tradeable materials.
3. **Shell works**: seal and armour the cavity. Bearings and a stationary docking hub.
4. **Cylinder**: build the rotating hull, starting small (about 225 m radius, about 2 rpm for 1 g, with a comfort penalty).
5. **Spin-up & biosphere**: soil, water, air and light. Early residents arrive.
6. **Home port**: your own market, shipyard and population. The base generates income and missions. Later expansion grows the cylinder (500 m → 1 km and beyond) for comfort and capacity.

The location choice matters. Comets give water but are fragile and outgas. Metallic bodies are strong but dry. Carbonaceous bodies are a balance.

## Hazards

Solar particle events (shelter or shielding), Jupiter's radiation belts, heat buildup (radiators), debris and micrometeoroids, fuel and reaction-mass margins, life support, outgassing comets, docking-traffic accidents and equipment wear. Each has a data definition: trigger, warning time, effects and counters.

## Conflict ladder

Factions: **Terran Compact** (Earth governments), **Luna Cooperative**, **The Commons** (free AI minds), **Mars Assembly** and **Belt Freeholders**. Working names.

Disputes over claims, cargo, routes or AI autonomy escalate through these steps:
1. **Talk**: dialogue and reputation checks.
2. **Trade**: pay, swap or concede.
3. **Leverage**: legal claims, faction favours, reputation.
4. **Evade**: outrun, hide in shadow, run silent.
5. **Disable**: non-lethal force (jammers, tethers, drive-disabling shots) with real consequences: reputation loss, bounties, legal cases.

Lethal force is not a normal player tool. The ladder, its costs and its outcomes are data.

## The AI co-pilot

A character, not just a feature. It is the in-world reason the flight is playable: it plots transfers, keeps attitude and smooths the controls. The player chooses intent ("take us to L1 depot, arrive by Thursday"), and the co-pilot proposes routes with time, fuel and risk. Its abilities grow with software upgrades and the relationship with it. The story follows humans and AIs learning to share the system.

## Flight model

- **Far:** body positions are on rails (Keplerian elements from real data). The ship follows a planned trajectory under time compression (1x–10,000x, dropping out automatically for events and arrival).
- **Near (within about 50 km of a station or body):** a local Newtonian flight bubble with Jolt collisions. A fly-by-wire assist has tunable levels: Full (arcade-like, holds velocity), Assisted (damps rotation and drift), Manual (pure momentum).
- Docking at rotating stations: match the spin, approach the axis, use guide lights. Tolerances are in data.

## Art direction: workmanlike, not slick

Touchstone: the Eagle Transporter from *Space: 1999*, with ships that look built by and for working people. Kindred references: Apollo's lunar module, the ISS, the Nostromo (*Alien*), *Silent Running*, *Outland*, and real hardware like trusses, tanks and radiators.

- **Function is visible.** Exposed truss spines, tanks, radiator panels, cable runs, handholds, docking collars, landing legs with dampers. If a part exists in the rules, you can see it on the model.
- **Modular by construction.** Ships are a spine plus bolt-on modules: command pod, cargo pod, tanks, drive, radiators, drones. Upgrades physically change the silhouette. One kit of parts builds many ships, so the art and the ship data share one structure (`data/modules/`).
- **Materials:** off-white and grey panels, bare metal, gold foil insulation, rubberised seals. Restrained colour with practical markings: hazard stripes, hull numbers, operator logos, stencilled warnings, rescue-orange handles.
- **Wear and history:** scuffs, sun-bleaching, replaced mismatched panels, patch repairs. Older ships look older, and a second-hand starter ship looks second-hand.
- **Lighting:** hard, single-source sunlight with deep shadows. Working lights, floodlights and blinking navigation beacons. Interiors are cramped and lit by instruments.
- **Stations and habitats** follow the same logic: assembled from modules, under construction at the edges, with scaffolding and cranes. Your own base visibly grows through its stages.
- **UI:** instrument-panel style. Clear labels, monospace readouts, physical-looking switches. Functional, not holographic glamour.
- **Build approach:** low-to-mid poly kitbash parts with simple shared materials and decals, so a small team (or one person) can make many variations. A good fit for the Compatibility renderer and the GTX 960M baseline.

## Architecture

### Layers

```
data/   catalogs and rules (JSON)  ─┐
                                    ▼
sim/    pure game rules, no rendering. Deterministic. Headless-testable.
          state     ← one serialisable GameState (calendar, ship, markets, claims, ...)
          commands  ← every player or AI action is a Command, e.g. BuySell, PlotCourse, Dock
          systems   ← orbits, economy, travel, hazards, factions, base ... each ticks the state
          events    → emitted for the view and audio: Docked, PriceChanged, HazardWarning
                                    ▼
view/   Godot scenes: cockpit, map, station UI, effects. Reads state, sends commands.
```

**Rules.** The view never changes state directly; it only sends commands. Systems talk through state and events, not by calling each other. That gives us:
- **Saves:** serialise `GameState`, with a schema version and migration functions.
- **Testing and balance:** bots send commands headless to run thousands of simulated trade runs and report profit per hour per route.
- **Replays and bug reports:** a seed plus a command log.
- **A co-op path:** later, a host runs the sim and clients send commands over Godot's high-level multiplayer. The shared clock (time compression) is the real design problem; options are crewing one ship or voted time compression. Not built now, but nothing blocks it.

### Precision

The simulation uses 64-bit floats in metres and seconds, in a heliocentric frame. Rendering uses a floating origin centred on the player, plus a scaled "far layer" for planets and the Sun. The stock Godot build is used, with no custom double-precision compile.

### Data

- `data/bodies/` – baked from JPL catalogs by `tools/bake_bodies.py`
- `data/goods.json`, `data/places/*.json`, `data/recipes.json`
- `data/ships/`, `data/modules/`, `data/drives.json`
- `data/hazards.json`, `data/factions.json`, `data/conflict.json`
- `data/base_stages.json`
- `data/balance.json` – global knobs (price elasticity, time-compression limits, assist strength, ...)

Each file has a schema, and a validator runs in tests. New content is mainly new data. Mod folders can override or add files later.

### Folder layout

```
Spinward/
  sim/        state/, commands/, systems/, events.gd, sim.gd
  data/       JSON content and balance
  view/       scenes, UI, shaders, audio
  tools/      setup/play/build scripts, data bakers, balance bots
  tests/      sim unit tests, data validation, balance reports
  docs/       DESIGN.md, RESEARCH.md, decisions/ (ADRs)
```

## Milestones

- **M0 – Foundation:** repo, docs, project boots, sim/data/view skeleton, test runner, save/load of an empty state.
- **M1 – Cislunar slice:** Earth, Moon, L1/L2/L4/L5 and real orbits for the Moon. 5–6 places, about 10 goods, recipes and prices. One Tier-1 ship. Plot course + time compression. Local flight and docking at one rotating station. Saves. Balance bot report. *Gate: is trading fun?*
- **M2 – Hazards & conflict v1:** solar storms, heat, the first disputes and the conflict ladder.
- **M3 – Tier 2:** near-Earth asteroids and Mars, surveying, factions.
- **M4 – Tier 3 & base stages 1–3.**
- **M5 – Tier 4, base stages 4–6, story arc.**
- **Later:** co-op exploration, mod support, art pass.

## Balance knobs (first list)

Drive acceleration and fuel per tier. Price band width and elasticity per good. Recipe rates. Event frequency. Hazard severity and warning times. Assist strength. Docking tolerances. Time-compression limits. Claim costs. Base stage costs. Reputation gains and losses. Conflict step costs.

## Open questions

- Player identity: a custom name and portrait? A fixed backstory?
- How much should the co-pilot speak? Writing and voice budget.
- Should a ship be lost permanently? Leaning to "insurance + setback", not permadeath.
- ~~Art direction~~: decided. Workmanlike modular hardware, see "Art direction".
