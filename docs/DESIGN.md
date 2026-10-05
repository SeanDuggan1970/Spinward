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

## Megastructures: the awe ladder

The system should feel like a place where big things are being built. Each tier adds structures that are plausible at that point in the story, and each one does a job in the economy, not just in the sky. Inspired by Isaac Arthur's *Megastructure Compendium* (Science & Futurism with Isaac Arthur, [YouTube](https://www.youtube.com/watch?v=1xt13dn74wc)). The descriptions here are our own.

| Structure | Where | Tier | Status | Role |
|---|---|---|---|---|
| Skyhook (rotating launch tether) | Kibo Ring, LEO | 1 | **In** (set piece) | Why Earth goods are cheap at Kibo |
| Solar power satellites / power beamers | Clarke Exchange, GEO | 1 | **In** (set piece) | Clarke's parts demand; salvage exports |
| Lunar space elevator (the Luna Line) | Halo Depot, L1 | 1 | **In** (set piece) | Regolith and ice delivered to L1 |
| Kalpana One (Globus settlement drum) | Equatorial LEO | 1 | **In** (place) | A settlement market of 3,000 people |
| Megatelescope array | Farside Array, L2 | 1 | **In** (place + set piece) | Remote science market, no fuel |
| Bernal sphere (Island One) | Beside The Kernel, L5 | 1–2 | **In** (set piece, under construction) | Habitat-module demand; grows over the campaign |
| Piazzi Stalk (Ceres elevator) | Ceres equator | 2 | **In** (on the body) | Why ice and volatiles are cheap at Piazzi |
| Pavonis Line (Mars elevator) | Pavonis Mons | 2 | **In** (project, lets down in stages) | Ares Ring output x1.5 when finished |
| Concord Pair (O'Neill cylinders, 8 x 32 km) | Over Ceres | 2-3 | **In** (project set piece) | Piazzi's market x1.8 |
| Landauer Deep (the minds' cold core) | Iapetus | 2 | **In** (port + project) | The Sufficiency's home; electronics and parts |
| Starshade | Valhalla | 2 | **In** (set piece) | Exoplanet science; lore |
| Solar sail freighters | Clarke to Mars | 2 | **In** (project builds the fleet) | Propellant-free bulk freight, slowly |
| Stanford torus | L4/L5 | 2 | Planned | A completed habitat; big food and passenger market |
| Earth–Mars cycler (Aldrin cycler) | Earth–Mars | 2 | Planned | A moving station you catch on its schedule |
| Space farms | Kernel, Belt | 2–3 | Partly in (Kernel food) | Food chain away from Earth |
| Lofstrom loop (launch loop) | Earth equator | 2 | Planned (backdrop) | Cheaper Earth-to-orbit freight |
| Asteroid colonies / hollowed-rock habitats | Belt | 3 | Planned | **The player's own base** |
| O'Neill cylinder | Player base, L5 later | 3–4 | Planned | End-game home; grows in stages |
| Orbital ring (lunar) | Moon | 4 | Maybe | Late lunar industry |
| Solar shades, statites | Venus, Sun–Earth L1 | 4+ | Maybe | Terraforming hints, story beats |
| McKendree cylinder, Bishop ring | — | Far future | Out of scope | Lore and dreams only |
| Dyson swarms, Matrioshka brains, stellar engines | — | Far future | Out of scope | "What the Commons dream about" |

Set pieces are built at true scale (kilometres) in `view/flight/set_pieces.gd`, arranged in the sky beyond each station and oriented by the real Sun, Earth and Moon directions. They are view-only; their economic role lives in the place data.

## Megaprojects: building the backyard together

Collective builds (`data/projects.json`, `sim/systems/project_system.gd`) give the hopeful theme something to do. Each project draws its goods, stage by stage, from its station's market stock above a reserve. That creates real demand that traders profit from. Stages complete with news on the comms channel, and the set piece in the sky grows with each stage.

| Project | Station | Stages | Effect when done |
|---|---|---|---|
| Island One (Bernal sphere) | The Kernel | Frame, hull, air/water/soil, spin-up | Kernel consumes ×2.5 and produces ×2. The sphere glows and spins. |
| Luna Line, second ribbon | Halo Depot | Ribbon spun, climbers commissioned | Halo output ×2. A second ribbon carries climbers. |
| Kalpana Two (sister drum) | Kalpana One | Frame, hull and windows, move-in | Kalpana market ×2. A counter-rotating drum appears alongside. |

- **Your share:** the net tonnage of needed goods you import into that market, so wash trading earns nothing. It's shown on the Projects tab and thanked in the news.
- **Without the player** (bot-free sim):
  - Luna Line 2 finishes in about 100 days.
  - Island One reaches about 73% in two years, because the Kernel's farms and residents use up the air, water and food it needs.
  - Kalpana Two reaches about 60% in two years.
- So the world moves on its own, and your hauling clearly speeds it up.

This is also the template for **the player's own base** (M4): the same staged needs, drawn from your own depot, with the same visible growth.

## Other ships (NPC traffic)

The system is shared. NPC fleets live in the sim (`data/npcs.json`, `sim/systems/npc_system.gd`) and buy and sell from the same markets as the player:

| Fleet | Operator | Behaviour |
|---|---|---|
| Ice tankers | Luna Cooperative | Route: Shackleton ice → Halo Depot, food back |
| Ore drones | The Commons | Route: regolith → Trojan Yards, habitat modules → The Kernel |
| Drone freighters | The Commons | Trader: one of the few best trades they can see |
| Independents | Independent haulers | Trader, like the player |
| Couriers | Terran Compact | Route: medical and electronics to the Moon, helium-3 back |
| Shuttles | Kernel Settlers | Passenger shuttle, no freight |

Rules that keep them good neighbours:
- Route fleets deliver only up to what the destination is short of, so they act as supply contracts rather than dumping gluts.
- Traders need a minimum margin.
- Nobody draws a market below its reserve.
- NPCs never strand: their operators refuel them.

They appear in four places:
- on the system map
- on each station's **Traffic** tab (in port, inbound, comms)
- in the comms ticker
- in the approach scene, moored at hub berths or flying the lanes outside the ring

Stations also have view-only work pods and a tug, so a port always looks busy. Later NPC roles: passengers and contracts, rescue calls (hazards), disputes (conflict ladder) and faction reputation.

## Information: knowledge, tips and brokers

There is no free perfect information.
- **Your knowledge:** you know a port's prices from when you were last docked there. The Departures cards show that board with its age.
- **The logbook:** a new pilot starts with the previous owner's logbook, 3-day-old boards for every port, so the start isn't blind.
- **Brokers:** info brokers (`data/brokers.json`, `sim/systems/tip_system.gd`) sell tips about other ports at the station where they work.

| Broker | Works at | Price | Character |
|---|---|---|---|
| Maisie Tran | Kibo Ring | 260 | Retired customs clerk. Good on near-Earth ports. |
| Lamplighter | Halo Depot | 700 | Unregistered AI in the traffic computer. Hears everything. Rarely wrong. |
| Dusty Okafor | Shackleton Port | 70 | Rumour merchant. Cheap and enthusiastic, right about half the time. |
| Auntie Vell | The Kernel | 150 | Noodle bar gossip network. Good on L4/L5 and Farside. |

- **How tips work:**
  - A tip is true with the broker's hidden reliability, give or take some price noise. Otherwise it's invented.
  - When you next dock at the tipped port, the tip is checked against the real board ("held up" or "wrong").
  - The broker's track record with you builds up, so trust is learned, not shown.
  - Tips expire after 5 days.
- **Later ideas:**
  - NPCs acting on the same public tips, which crowds the trade
  - brokers who sell *to* other traders about you
  - a market-data subscription upgrade

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
- **Transfers** (`sim/navigation.gd`):
  - Cislunar trips are planned in the frame that rotates with the Earth–Moon line, where stations sit still. The path is a smooth run between two fixed points, so seen from outside it sweeps round with the Moon: a leading arc of about 50,000–70,000 km.
  - The thrust vector varies smoothly. It pushes toward the target, swings across, then brakes. It never exceeds the drive at the ship's mass, and propellant is the thrust actually used.
  - The ship points along the thrust vector in every view.
  - Gravity is taken to supply the co-rotation, and the departure/arrival overhead covers climbing out of gravity wells (a deliberate simplification).
- **Gravity-flown routes** (`sim/orbit_mech.gd`, `sim/gravity_flight.gd`, `sim/route_planner.gd`). The player's trips are flown under real Earth and Moon point gravity, integrated with RK4 at adaptive steps.
  - **Guidance:** Lambert steering onto the free-fall orbit that reaches the target on time, then coasting, then a terminal phase that matches the destination's motion.
  - **Flybys:** B-plane targeting. Aim at the impact parameter that becomes the chosen periapsis, trim on approach, and go hands-off for the pass.
  - **Cost:** a trip is about 30–300 ms to fly. Plotting a destination flies about 18 trial courses on a worker thread (about 1–4 s).
  - **Route options:**
    - **Express:** shortest trip that arrives.
    - **Economy:** least propellant. Usually about half of Express, because gravity does the work.
    - **Lunar flybys:** 500, 100 and 30 km, labelled honestly with their fuel cost.
  - **Gravity wells:** the climb-out/arrival stays inside the overhead hours, using hand-off orbits in the Moon's plane (50,000 km around Earth, 25,000 km around the Moon).
  - **Honest finding:** with fusion drives, flybys rarely beat a well-timed direct burn in cislunar space; they cost more, apart from roughly break-even to Farside. They're there for the thrill, and the co-pilot says so.
  - **Flyby time:** compression drops for the run-in (×100) and the pass (×10), then restores, and the co-pilot comments by altitude.
  - **NPCs:** NPCs and the departures board keep the quick estimate. NPC captains file flybys by temperament (illustrative only: their paths are not gravity-flown) and chatter about them.
- **Interplanetary voyages** (`sim/interplanetary.gd`, `sim/helio_flight.gd`). Any trip whose common frame is the Sun.
  - **Climb-out:** a low-thrust spiral out of the departure well. It costs about the orbit's speed (Edelbaum): about 7.7 km/s from low Earth orbit, about 1 km/s from the Earth-Moon Lagrange stations, which are the cheap way out. It takes delta-v/a of thrust time: days for a Mule.
  - **Transfer:** Sun-centred. Trip times are scanned with Lambert's problem, using a finite-burn correction (impulsive delta-v / (1 - burn fraction), at most half the trip under thrust). The trip is flown by guidance under the Sun's gravity: Lambert steering, then terminal ZEM/ZEV. The planner tries candidates until one arrives within 200,000 km and 500 m/s; the capture spiral takes the rest.
  - **Capture:** the spiral in reverse.
  - **Propellant:** the rocket equation at departure mass.
  - **Life support:** in days. The crewed command pod carries 120; drones need none. Voyages longer than that are refused, with the reason given.
  - **Options:**
    - **Express:** fastest that the tanks and larder allow.
    - **Economy:** least propellant within 2.5x the Express time.
  - **Quick estimates:** boards and NPCs get the best candidate, with a free-fall conic path.
  - **Time compression:** goes to x1,000,000.
  - **NPC traders** stay in their own planet's neighbourhood unless a fleet is flagged `interplanetary`.
  - **What a Mule can reach** (from Halo Depot):
    - Mars in about 50 days with 18 t of tanks in its cargo bays (~8 t used).
    - Ceres in about 100 days.
    - Psyche at the edge of its 120-day larder.
    - Jupiter and Saturn need better drives and extended life support. This is the refit ladder.
  - **Orbits:** every body is baked from JPL Horizons state vectors (2061-03-01, mean motion fitted to 2063). `tests/horizons_reference.json` holds the reference, and a test keeps every body within a degree.
- **Transit views** (M cycles):
  - a cinematic god's-eye view, the default, framing ship, destination and rendezvous
  - the cockpit
  - the flat map
- **Near (within about 50 km of a station or body):** a local Newtonian flight bubble with Jolt collisions. A fly-by-wire assist has tunable levels: Full (arcade-like, holds velocity), Assisted (damps rotation and drift), Manual (pure momentum).
- Docking at rotating stations: match the spin, approach the axis, use guide lights. Tolerances are in data.

## Art direction: workmanlike, not slick

Touchstone: the Eagle Transporter from *Space: 1999*, with ships that look built by and for working people. Kindred references: Apollo's lunar module, the ISS, the Nostromo (*Alien*), *Silent Running*, *Outland*, and real hardware like trusses, tanks and radiators.

- **Function is visible.** Exposed truss spines, tanks, radiator panels, cable runs, handholds, docking collars, landing legs with dampers. If a part exists in the rules, you can see it on the model.
- **Modular by construction.** Ships are a spine plus bolt-on modules: command pod, cargo pod, tanks, drive, radiators, drones. Upgrades physically change the silhouette. One kit of parts builds many ships, so the art and the ship data share one structure (`data/modules.json`).
- **Ship anatomy** (`view/flight/ship_builder.gd`). Three sections along a keel truss. The cargo sits between the crew and the drive, as protection against drive trouble.
  - **Crew section (front).**
    - Crewed ships: a faceted cockpit nose with a framed windscreen, a docking collar on the tip, and the flight deck in the operator's band and the ship's name.
    - Behind the deck, a hab can with portholes.
    - Deep-space kit: a high-gain dish on a mast, a nav radar, whip aerials, star trackers, floodlights and RCS quads.
    - Drones get a windowless octagonal bus with a sensor turret and lit "eyes".
    - Passenger cans mount right behind the crew.
  - **Cargo section (middle).** Mostly standard boxes, like shipping on Earth: 2.4 × 2.6 × 6 m, corrugated, with door frames and code panels.
    - Containers: one box or a stack (`containers` = across, high, long).
    - Cages: open frames of half-length boxes.
    - Bulk hoppers.
    - Outsize cradles, an open bed on legs above the keel. The load is a mirror segment, a habitat hull section or netted crates.
    - The hull's `cargo_layout` sets how they sit: in a line, two abreast, or four round the keel, with latch arms out to the keel.
  - **Propulsion section (rear).**
    - Propellant tanks clustered round the keel, with radiators on booms.
    - A hazard-ringed shadow shield.
    - Then the drives: one, a pair, a triangle or a square, each on its own thrust-frame strut.
    - Each drive is a reactor drum in a cage of longerons, with field coils and a heat-tinted bell.
  - **Barnacles.** Pumps, gas bottles, pipe runs over the shield to the tanks, and cable trays. They are seeded by the ship's name, as are its dishes and aerials, so sister ships differ in the details.
  - **Draw calls.** Static parts are merged per material after building (`Kit.merge_static`), so a ship of several hundred parts costs a few dozen draw calls.
  - **Moving parts** (`view/flight/ship_rig.gd`). The parts that move are left out of the merge.
    - **Panels:** every panel hangs on a boom along the ship's X axis, all in one plane (never stacked), and turns about that boom.
      - Solar wings on the crew hab, housekeeping power for when the reactor is cold, face the Sun.
      - Radiators turn edge-on to it, so they shed heat rather than absorb sunlight.
      - One hinge can only reach the Sun if it lies in the ship's Y-Z plane. So in transit (orbit view, lane traffic, the attract screen) ships roll about their line of thrust to put it there.
      - While docking the pilot owns the roll, and the panels do the best one hinge can.
    - **High-gain dish:** an azimuth/elevation mount with limited slew rates. It aims at:
      - the destination, in transit
      - the station's traffic control, while docking
      - Earth, while moored
      - the next port, for outbound traffic
    - **Light time** (`sim/light_time.gd`, tested). In transit the dish points ahead to where the destination will be when the signal arrives, at t + tau with tau = |target(t + tau) − ship(t)| / c.
      - The aim is corrected for aberration from the ship's own velocity. A ship and a target moving together need no lead, and the test checks that.
      - The receive solution sees the target where it was, at t − tau.
      - The orbit HUD shows the light time and the point-ahead angle between the two solutions: about 2 arcsec across cislunar space, where both move at about 1 km/s.
- **Materials:** off-white and grey panels, bare metal, gold foil insulation, rubberised seals. Restrained colour with practical markings: hazard stripes, hull numbers, operator logos, stencilled warnings, rescue-orange handles.
- **Wear and history:** scuffs, sun-bleaching, replaced mismatched panels, patch repairs. Older ships look older, and a second-hand starter ship looks second-hand.
- **Lighting:** hard, single-source sunlight with deep shadows. Working lights, floodlights and blinking navigation beacons. Interiors are cramped and lit by instruments.
- **Stations and habitats** follow the same logic: assembled from modules, under construction at the edges, with scaffolding and cranes. Your own base visibly grows through its stages.
- **Transit cockpit:** the view from the ship's true position on its transfer. It accelerates along the track, flips at the midpoint and brakes facing back the way it came. There's free look and a telescope, and the system map is on M.
- **Cockpit:** first-person by default, in the spirit of the original Elite. The canopy frame and hazard-striped dashboard carry the classic elliptical 3D scanner (stalks for height, square-root range scale so close traffic separates), a port compass, and lamp gauges that light green inside docking tolerances. A chase camera is optional.
- **UI:** instrument-panel style. Clear labels, monospace readouts, physical-looking switches. Functional, not holographic glamour.
- **Build approach:** low-to-mid poly kitbash parts with simple shared materials and decals, so a small team (or one person) can make many variations. A good fit for the Compatibility renderer and the GTX 960M baseline.
- **Procedural surfaces, no texture files** (`view/shaders/`). Everything is computed per pixel from position, so it is seamless and keeps its detail at any range. Detail too small for the pixel fades out first, so it doesn't shimmer and stays cheap from far off.
  - **The Moon and rocky bodies** (`moon.gdshader`):
    - lava-flooded basins for maria
    - craters at six scales, from 400 km basins down to kilometre pits; old ones slumped and soft, young ones crisp with bright haloes
    - central peaks in the big craters, a few ray systems, rolling ground and regolith grain
    - lava buries older craters smoothly, so no crater is cut off at a shoreline
    - one shader serves rocks too: Trojan Yards' captured asteroid, 2058 QT, is a lumpy noise mesh with the same shader at rock scale
  - **Earth** (`earth.gdshader`):
    - warped continents with latitude biomes and polar ice
    - oceans with a soft sun glint
    - drifting cloud
    - city lights on the night side, clustered along coasts
    - a blue limb on the day side, with the axial tilt and a sidereal spin from game time
  - **Hulls** (`hull.gdshader`): the kit's materials are panelled plate with fine seams, the odd replacement panel or primer patch, grime streaked along the ship, and chipped edges. There are also bare-metal, crinkled-foil and corrugated-container finishes.
- **Liveries** (`data/liveries.json`, `view/flight/livery.gd`). Each operator's ships and stations wear its colours and band. Each ship then weathers in its own way, seeded by its name, so a fleet reads as one outfit but no two hulls match.
  - Independents pick a scheme from a palette.
  - Cargo pods are whatever containers turned up.
  - Ships carry their names stencilled on the command pod.
  - The starter ship is second-hand and looks it.
- **Art check:** `--art=<dir>` renders the bodies under several lights and one ship from every fleet up close. `--flyby=<dir>` captures a 39 km lunar pass, and `--gallery=<dir>` every approach.

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

### The local flight bubble

The approach-and-dock flight is integrated in `view/flight/`, not in the sim. It is a skill moment whose only effect on game state is the `dock` command it sends. This is a deliberate, contained exception to "all rules live in the sim". If close flight ever needs to matter to the sim (co-op, combat, hazards in the bubble), move its integration into a sim system and keep the view as a renderer.

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

## The wider system (Oct 2026 expansion)

Sean's direction (2026-10-04). It goes beyond trade into opportunities, refits and the powers in the background.

1. **The solar system** (done):
   - the planets
   - 14 major moons
   - Ceres, Vesta, Pallas, Psyche, Hygiea, Eros and Hektor
   - Pluto-Charon, Eris, Arrokoth and Sedna
   - new ports at Mars (Ares Ring), Ceres (Piazzi Station), Psyche (Psyche Claims), Callisto (Valhalla Station), Titan (Huygens Port) and Enceladus (Plume Watch)
   - new goods: deuterium, volatiles and platinum metals
   - surface shaders: rock, ice with lineae and caps, banded gas giants, cloud worlds, and Saturn's rings
2. **Interplanetary flight** (done): see the flight model above.
3. **Refits** (done). Modules declare the slot kinds they fit (`mounts`), so cargo bays can carry:
   - long-haul tanks (`tank_l`, 20 t)
   - a 300-day hab
   - passenger berths
   - a lander bay with a two-seat lander
   - a survey pod
   - a prospecting rig

   The Pathfinder Mk3 (D-He3: 2,600 N, Isp 60,000 s) and a 6 MW radiator array open the outer system.

   | Refit | Reach | Cargo |
   |---|---|---|
   | Mk3, 2 x tank_l, hab, arrays | Jupiter in about 100 days, Saturn and Enceladus in about 90 | none |
   | Mars runner (tank_l + one pod) | Mars in 55 days | 20 t |

   Ships are drawn by what a module is, not where it sits: habs behind the crew, tanks in pairs above and below the keel ahead of the drives, landers and rigs amidships. Yards:
   - **Kibo Ring:** tanks, hab, berths, survey pod
   - **Trojan Yards:** the Mk3, arrays, lander, rig, hab
   - **Ares Ring:** tanks, hab, lander, rig, survey pod
   - **Piazzi Station:** tanks, rig, lander, arrays

   Buying whole hulls (the heavy keel) is still to come.
4. **Reputation and opportunities** (courier work done; survey, salvage and mining next). Being reliable gets you known. Offers come from boards, approaches, and rumours sold as bonus info by the tip line.

   **Done** (`data/contracts.json`, `sim/contracts.gd`, `sim/systems/contract_system.gd`, the Contracts tab):
   - **Boards:** each port keeps a board, refreshed while you are docked there.
   - **Kinds:**
     - packages, light and urgent
     - passengers, who need berths
     - pickups: collect at A, deliver to B
     - long hauls between worlds; a port alone at its world offers only these
   - **Deadlines:** each job allows a window from when it is taken, set from a stock Mule's (or long-haul refit's) fastest trip x slack. A light, direct ship makes it; a laden one may not. The board shows the co-pilot's estimate at your current mass.
   - **Outcomes:**
     - On time pays in full and builds standing with the client operator.
     - Late pays half and costs standing.
     - Past twice the window, or abandoned, the job fails.
   - **Standing tiers:** Unknown, Known, Reliable, Trusted, One of their own. Pickups and long hauls ask for Known or better, and the board says how many jobs are waiting for known pilots.
   - **Approaches:** a Reliable+ pilot docking may be sought out, with an opener and a better-paid, tighter job.
   - **Rumours:** a bought tip sometimes carries word of a real job at another port that nobody else has heard of.

   **Sites** (done; `data/sites.json`, `sim/systems/site_system.gd`, site mode of the station screen over `view/site_view.gd`). Somewhere to go that is not a port: no market, no fuel, no docking. You arrive on site and work.
   - **Kinds of work:**
     - salvage a derelict
     - survey from orbit (needs a survey pod)
     - land and core (needs the lander)
     - mine (lander and rig)
   - **Work** takes days of game time and can go badly: about a third of the yield, and a bad landing burns propellant. Yields go into the hold as room allows, and the rest is left behind. Survey data is sold by radio, with standing for whoever wanted it.
   - **Visibility:** some sites are on the chart from the start; others come by rumour (a broker's tip can put one on your chart) or later by story.
   - **First sites:**
     - the Ishikawa Maru, a lost lunar tanker
     - Hermes-7, a dead probe four lunar distances out, wanted by the Compact
     - surveys of Eros, Phobos and Hektor
     - an unclaimed platinum prospect on Psyche
   - **Places and locations:** `data.locations` merges ports and sites for everything that only needs a position. Ports stay in `data.places`.
   - **Safety:** the emergency tanker reaches sites too, so running dry out there is costly but never a soft-lock.

   Still to come:
   - **Courier contracts:** a package, a passenger or a party, with a deadline. Some are pickups: go and get something or someone and take it on somewhere else. They weigh little but demand a direct, light, fast trip, so less or no other cargo.
   - survey, salvage, prospecting and mining claims
   - derelicts
5. **Projects that pitch** (done). Each megaproject makes its case: why, the plan, and what is on offer. Perks are earned by hauled tonnage over the whole build (`sim/perks.gd`):
   - free docking
   - fuel and yard discounts. These go only on what can't be resold, so no arbitrage loop.
   - standing with the backer
   - promises (a berth, first claim on survey work) for later systems to honour

   Not all projects are there at the start:
   - **Tharsis greenhouses** (Mars Accord): announced after 30 days.
   - **Hektor Reach** (The Commons): announced once Island One's frame is closed. It is built at L5, then driven out to Hektor in Jupiter's leading Trojans. It opens a new port when finished, and until then that port is closed to everyone.
   - **Valhalla science ring:** invitation only. Terran Compact Science asks in pilots it counts as Reliable.

   Projects compete for the same hauling, so which to back is a real choice.
6. **Powers in the background** (first arc done; `data/story.json`, `sim/systems/story_system.gd`). Inspired by Iain M. Banks' Culture: benevolent minds who intervene quietly, Contact and Special Circumstances, the informal Interesting Times Gang, Outside Context Problems. The names are this game's own.
   - **The Long View** is an informal circle of Commons minds, some of them the drone freighters you pass every day (*Patient Arithmetic*, *Reasonable Doubt*). They keep a Contact-like rule: the unknown should be met by a person.
   - **Ines Okafor**, who "represents nobody in particular", is their human go-between.
   - **The arc, in beats:**
     1. After three on-time deliveries and a Known standing anywhere, she approaches you with a favour: a sealed case for Farside Array.
     2. The astronomer puts the dead probe Hermes-7 on your chart. Its recorder shows three stars occulted by something perfectly black at about 1,000 AU.
     3. You carry a Commons mind in a box to Trojan Yards.
     4. Patient Arithmetic lends you a drive no yard sells (6 kN, Isp 1,000,000 s) and a long-sleep berth (2,000 days), and shows you **the Lacuna**: a 2.5-year voyage at about 12 milli-g.
     5. You go and say hello, and it says hello back, in your own words, with the light-time taken off. The outcome is left open and hopeful.
   - **How beats work:** each waits for its conditions and port, writes to your correspondence (Contracts tab), and acts: a favour job on the local board, a site revealed, modules lent, standing, credits. A favour that fails or is never taken is offered again.
   - **Deep space** (beyond 30 AU): the Sun's pull is negligible, so trips use a straight-line accelerate-coast-decelerate plan sized to the propellant aboard. Guided flight can't converge when braking takes most of the voyage, and Lambert's solver can't reach those hyperbolic speeds.
7. **Lander** (done; `view/lander_scene.gd`). Any site job that needs the lander offers a choice:
   - **Fly the descent yourself:** from about 450 m up, already falling and drifting, onto the body's real cratered surface under its real surface gravity (Eros 0.006 m/s^2, Psyche 0.13). A main engine pushes up, and small thrusters kill drift. Touch down under 2.5 m/s down and 1.5 m/s across and the job goes right, with a little more yield (you picked the spot). Harder is a bad landing: a third of the yield and burnt propellant.
   - **Let the co-pilot land:** at the job's usual risk.

   `--landing=<dir>` flies two descents on autopilot for screenshots. A fully flown ascent and surface EVA can come later.

## Outer-system traffic (Oct 2026)

- **Fleets:** long-haul fleets fly the deep freighter: a heavy keel, three containers, a 300-day hab, four long-haul tanks and twin Mk3 drives.
  - **Mars Accord runners:** Ares Ring to Kibo Ring.
  - **Belt Assembly haulers:** Ceres to Mars.
  - **An ore ship:** Psyche Claims to Piazzi Station.
  - **A Huygens Trust tender:** Titan to Callisto.
- **Commissioning:** each ship has a date in `commission_days`. Before it, the ship is fitting out, out of service and out of sight. When it enters service, the comms channel and a notice carry the news.
- **Build-up:** the outer system starts with one ship and fills in over the first half-year, to six, so it never feels busy.
- **Paths:** NPC voyages fly the interplanetary quick plan's sampled path, so they show on the solar map and orbit view.
- **Saves:** fleets added after a save was made are filled in on load.

## The attract screen (Oct 2026)

- **A shot director** (`view/title_screen.gd`): it cuts through black between six set-ups, about 18 s each, picked at random and never the same twice running:
  - Earth orbit at Kibo Ring
  - a chase past Callisto with Jupiter and Io behind
  - crossing in front of Saturn's rings with Titan
  - a low run over the Moon with Earth on the horizon
  - holding station off Phobos with Mars below
  - threading tumbling rocks off Ceres
- **The hero:** each shot flies a random hull in a real fleet's livery and name, and the caption says where you are.
- **Composition:** cameras sit on the far side of the ship from the planet, so the world fills the background.
- **Capture:** `--title=<dir>` shoots every set-up.

## A rich and getting richer system (Oct 2026)

Sean's direction (2026-10-05). Fill the system with:
- moons, megastructures (some under construction), huge habitats
- space elevators where spin and gravity allow them
- cryovolcanoes, space telescopes, solar sails
- a hopeful future: physics solved, construction automated
- AI personhood, with minds who want facilities of their own

These glimpses should be part of the story arc and reported on a space-age news feed: "today, Earth Standard Time, X announced… and hopes to find backers", showing up on Projects. In Sean's words: "a rich and getting richer solar system full of potential for all who are brave and crazy enough".

- **The Spaceline** (`data/news.json`, `sim/systems/news_system.gd`, the Spaceline tab):
  - **On day one:** the feed is already running, with backdated stories and the announcements of projects already under way.
  - **World stories:** they post on their day. Some wait for a story beat (`after_beat`) or a project. Some carry `effects` that leave a place richer for good: a platinum seam on Psyche, the Stalk's refit, a self-copying foundry on Hygiea, rain at Tharsis.
  - **Projects:** revealed projects are announced with a pitch and "see Projects"; stages and completions make the news too. Invitation-only projects stay out of the papers.
  - **Ships:** new ships entering service are reported.
  - **How it runs:** the feed watches state rather than other systems' events, so it also catches up on old saves.
- **New projects:**
  - **The Pavonis Line**, a Mars elevator let down from areostationary orbit (day 45).
  - **The Concord Pair**, two O'Neill cylinders over Ceres (day 20).
  - **Lightfoot sails**, a sail yard at Clarke Exchange (day 10). Finishing it commissions the Lightfoot sail fleet (`commission_project`).
  - **Landauer Deep's second core**, from the Sufficiency (day 75).
- **AI personhood:**
  - **In the news:** a mind petitions the Belt Assembly (day 5), the Belt votes minds persons (day 32), the Compact holds hearings, a freighter buys itself.
  - **Landauer Deep:** the Sufficiency opens Landauer Deep at Iapetus on day 60 (`opens_after_days`). It is cold, quiet and theirs, with a small warm annex for guests.
  - **The Sufficiency's arc** (`story.json`, `arc: "sufficiency"`; arcs now run side by side):
    1. Quiet Margin greets you.
    2. Carry a sleeping mind to Ceres to take the Belt Assembly's first mind seat.
    3. A thank-you from Delegate Steady Hand.
- **Sails:**
  - **The hull:** the sail freighter, a Commons mind with two containers and a 600 m square sail.
  - **Voyages:** sail voyages are 160 to 220 days, Clarke Exchange to Ares Ring. Each is a Sun-centred spiral that sweeps about as far as orbits between the two radii would carry it, with no propellant.
  - **At port:** sails moor at the sail park, not at berths.
- **On the bodies** (`bodies.json` "plumes" and "structures", `SkyKit.dress_body`):
  - **Enceladus:** tiger-stripe jets and a broad haze, forward-scattering so they blaze when backlit.
  - **Elsewhere:** Pele and a smaller plume on Io's limb, faint Europa jets, and Triton's dark geysers with their wind-blown streaks.
  - **Elevators:** the Piazzi Stalk on Ceres (finished), and the Pavonis Line, growing with its project.
  - **Where they stand:** "limb" sites stand where they show against space.
  - **In the flight view:** bodies on the sky shell now use true angular size (sin, not tan), and the camera's far plane reaches an elevator's counterweight.
- **Set pieces:**
  - the Concord Pair at Piazzi, 120 km out: frame, hull and windows, mirrors and spin-up, then lights
  - Landauer Deep's mind works: a collector shading a black core, eight red-glowing radiator vanes, and the second core built by a drone swarm
  - Valhalla's starshade
  - Clarke's sail yard, with a sail under a power beam once finished
- **Capture modes:**
  - `--gallery=<dir> --only=a,b` shoots chosen ports at the start, half built and finished.
  - The title has two new shots: under Enceladus' plumes, and a Lightfoot sail over Earth. The belt shot shows the Concord Pair beyond Ceres and the Stalk.

## Milestones

- **M0 – Foundation:** done.
- **M1 – Cislunar slice:** built (Oct 2026). Six places, at Earth orbits and Earth–Moon L1, L4 and L5. Eleven goods with recipes. A modular Mule hauler and shipyard. Co-pilot routes with time compression. Hand-flown docking at every station's spinning port, or a tug. Quick saves. Balance bot. *Gate: is trading fun? Awaiting Sean's playtest.* Known gap: empty return legs (see `balance/NOTES.md`).
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
