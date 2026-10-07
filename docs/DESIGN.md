# Spinward design

Living document. Version 0.1, 3 October 2026. Every number here is a starting value to tune, kept in `data/`, never hard-coded.

## Pitch

The 2060s. Humanity and its AI partners are spreading into the solar system, our own backyard. You start as an independent pilot with a small fusion ship and an AI co-pilot in Earth orbit. You trade between real places (stations, the Moon, Lagrange points, then Mars, the Belt and beyond), using real orbits on a real calendar. Wealth buys better drives. Better drives reach further. Further out, you survey, stake a claim and finally build your own home: a spinning O'Neill cylinder inside a hollowed asteroid or comet.

**Tone:** hopeful near-future. Scarcity is ending, but not evenly or without friction. The dangers are space itself and misunderstanding between people, both human and AI. Combat is the last resort.

**Where knowledge stands** (Sean, 2026-10-07). The world is past the AI singularity:
- **Largely solved:** mathematics, chemistry, materials science and most physics. Hardware shows it: transparent ceramics for windows, superconducting coils, fusion drives, automated construction.
- **Still being explored, with great progress:** biology.
- **Still to learn:** a great deal at the extremes of physics and chemistry. There are great mysteries left to solve, and some still to find.
- **The universe beyond:** barely explored with anything more than telescopes. That is the frontier the game points at.

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
| Bernal sphere (Island One) | 3 km from The Kernel, L5 | 1–2 | **In** (set piece, then a port) | Habitat-module demand while building; then a food-and-farm market of 10,000 |
| Piazzi Stalk (Ceres elevator) | Ceres equator | 2 | **In** (on the body) | Why ice and volatiles are cheap at Piazzi |
| Pavonis Line (Mars elevator) | Pavonis Mons | 2 | **In** (project, lets down in stages) | Ares Ring output x1.5 when finished |
| Concord Pair (O'Neill cylinders, 8 x 32 km) | Over Ceres, 120 km from Piazzi | 2-3 | **In** (project set piece, then a port) | Piazzi's market x1.8; Concord feeds the Belt and drinks Ceres' ice |
| Landauer Deep (the minds' cold core) | Iapetus | 2 | **In** (port + project) | The Sufficiency's home; electronics and parts |
| Starshade | Valhalla | 2 | **In** (set piece) | Exoplanet science; lore |
| Solar sail freighters | Clarke to Mars | 2 | **In** (project builds the fleet) | Propellant-free bulk freight, slowly |
| Stanford torus (the Tsiolkovsky Wheel) | L4, 12 km from Trojan Yards | 2 | **In** (project, then a port) | A town of 10,000; a big food market |
| Orbital ring (the Selene Ring) | Lunar equator, 52 km up | 3 | **In** (project, built in arcs, then a junction port) | Shackleton output x1.6; the ring's junction smelts regolith to metal |
| Earth–Mars cycler (Aldrin cycler) | Earth–Mars | 2 | Planned | A moving station you catch on its schedule |
| Space farms | Kernel, Belt | 2–3 | Partly in (Kernel food) | Food chain away from Earth |
| Lofstrom loop (launch loop) | Earth equator | 2 | Planned (backdrop) | Cheaper Earth-to-orbit freight |
| Asteroid colonies / hollowed-rock habitats | Belt | 3 | Planned | **The player's own base** |
| O'Neill cylinder | Player base, L5 later | 3–4 | Planned | End-game home; grows in stages |
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
  - **Crew section (front).** Detail parts come from `view/flight/hull_kit.gd`.
    - **Nose and deck:** a faceted cockpit nose and a docking collar on the tip. The flight deck is in the operator's band, with the ship's name, bolted access panels on the flanks and yellow EVA handrails along the shoulders.
    - **Windows** look like windows, not coloured patches:
      - On the nose: three windscreen panes under a brow, a pane in each cheek, and two docking windows under the chin looking down the axis.
      - Each pane sits back in its frame behind a black gasket, with a raised bezel bolted all round.
      - The glass is synthetic sapphire faced over aluminium oxynitride, the transparent ceramic (`view/shaders/glass.gdshader`). It is nearly black looking straight in, mirror-bright at a grazing angle, and glints in the Sun.
      - A lit cabin shows through it with parallax: lamps and clutter, hidden by the reveal at a slant. The windscreen carries a faint gold sun film.
    - **The hab:** behind the deck, a pressure can with a domed aft head. It has two rows of round portholes in heavy bolted rings, some with armoured shutters closed, an EVA hatch with a status lamp, and handrails along its back and belly.
    - **Deep-space kit:** the high-gain dish on a mast, a nav radar, whip aerials, star trackers, floodlights and RCS quads.
    - **Dishes are real reflectors** (`HullKit.reflector`):
      - A paraboloid at f/D 0.38, its face in white petals laid in rings, with a rolled rim.
      - A ribbed back with a hoop, and a foil-wrapped receiver hub.
      - Big dishes are Cassegrain: a feed horn at the vertex and a subreflector at the focus on four struts. Small ones carry a feed box at the focus on three.
      - The steerable one sits on a turntable and yoke.
    - **Dish size follows the job.** A ship built for deep space carries a dish about 7 m across, twice the hab's width, because a weak signal needs a big ear. Deep space means a D-He3 drive (Isp 50,000 s or more), 250 days or more of life support, or `look.deep`. Its medium-gain dish is bigger too. Everyone else carries 2–3 m.
    - Drones get a windowless octagonal bus with a sensor turret and lit "eyes".
    - Passenger cans mount right behind the crew.
  - **Cargo section (middle).** Mostly standard boxes, like shipping on Earth: 2.4 × 2.6 × 6 m, corrugated, with door frames and code panels.
    - Containers: one box or a stack (`containers` = across, high, long).
    - Cages: open frames of half-length boxes.
    - Bulk hoppers.
    - Outsize cradles, an open bed on legs above the keel. The load is a mirror segment, a habitat hull section or netted crates.
    - The hull's `cargo_layout` sets how they sit: in a line, two abreast, or four round the keel, with latch arms out to the keel.
  - **Propulsion section (rear).**
    - Propellant tanks clustered round the keel, with radiators on booms. Cylindrical tanks are gas cylinders: 2:1 ellipsoidal heads, not flat ends, with banded girth welds and a valve boss on each pole (`HullKit.vessel`). Spheres get pole bosses too.
    - A hazard-ringed shadow shield.
    - Then the drives: one, a pair, a triangle or a square, each on its own thrust-frame strut.
    - Each drive is a reactor drum in a cage of longerons, then a magnetic nozzle. At tens of thousands of seconds of Isp no wall can hold the plasma, so a stack of superconducting coils round the throat and upper bell shapes the jet (a heavy throat coil, lighter ones aft, copper windings showing), and the bell is a heat shield and skirt.
    - The bell is a real hollow shell turned on a lathe (`Kit.lathe`): a Rao-style contour (a short arc out of the throat, then a parabola to a shallow exit angle), inner and outer walls with a square lip, the convergent section and throat visible inside. The upper bell is tube-wall and regeneratively cooled, heat-tinted straw and blue (`view/shaders/nozzle.gdshader`), feeding a coolant manifold at the joint; aft of that is a sooty radiation-cooled skirt with stiffening bands and a lip ring. Coolant tubes run forward under the coils to an injector ring, two fat propellant feeds come round from the drum, and two gimbal rams (pitch and yaw) run from clevises on the thrust plate to the last coil.
    - **Firing** (the ship's `DrivePlume`, shown while the drive burns). The exhaust is faint, very hot plasma in vacuum: no shock diamonds (those need air) and no fireball. It is drawn as a volume (`view/shaders/exhaust.gdshader`): a cheap raymarch through two bounds that meet at the exit plane, 12 jittered samples per pixel (the web build is single-threaded), each ray first clipped to where it can meet the jet so the samples land on the glow and rays that miss cost nothing. The glow falls to exactly zero at every bound, so no outline shows from any angle, so it is right from the side, from astern and looking straight up the nozzle, and the bell's walls hide what they should. Brightest where it is squeezed through the throat (white-blue), violet as it widens, fading over a dozen bell lengths, with a faint flicker and striations streaming aft. Faster drives (higher Isp) get a tighter jet. The bell's walls glow while it burns (`view/shaders/heat.gdshader`): the inside dull orange at the throat, the radiation-cooled skirt dull red, as real nozzle extensions do. A soft violet omni light, up in the bell where the jet is brightest, lights the bell's inside and the stern. `ShipBuilder.set_throttle(plume, x)` dims it all if a view wants a throttle. Liberty: the jet fades more gently than flux conservation says, so it carries to the eye.
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
  - **Detail** (`view/flight/station_detail.gd`, the same kit as the ships). A spinning station is two machines.
  - **The rotor** spins and holds everything crewed:
    - **Hub:** frames, and a band of control-room windows just aft of the docking face.
    - **Docking face:** radial ribs and a ring, floodlights trained on the port, two EVA hatches with handrails out to them, access panels, and latch blocks on a bolted flange round the port.
    - **Spokes:** lift tubes inside the trusses, with collars and a lift head where each meets the ring.
    - **Ring:** frames round the tube, running lights on the rim, and two decks of framed windows on each face, four to a bay.
  - **The despun assembly** is held still on a bearing on the axis astern, so dishes keep their link and arrays face the Sun while the rest turns. It carries a truss mast, radiators edge-on, two solar wings of framed cell blankets, and a comm farm at the tip: one big dish, two small ones, whip aerials and a strobe.
  - **The Stanford torus:** its 30 m window panes are framed, and its mirror has a rim, a ribbed back and a mast from the hub.
  - **Kalpana One:** the drum's cap windows are framed glass, its docking nub has a dressed face, and it has a comm farm astern of its fins.
  - **Draw calls:** both halves are merged per material, so a station costs a few dozen draw calls. The docking guide lights stay separate, since the docking computer recolours them.
- **Transit cockpit:** the view from the ship's true position on its transfer. It accelerates along the track, flips at the midpoint and brakes facing back the way it came. There's free look and a telescope, and the system map is on M.
- **Cockpit** (`view/flight/flight_deck.gd`, `view/ui/avionics.gd`, `view/ui/cockpit_pages.gd`): the flight deck of a working hauler, first-person by default. It is a glass cockpit for a crew who have systems to watch, not a fighter's HUD.
  - **The deck is real geometry** round the pilot's eye: a windscreen header and two pillars with rescue-orange grab handles, an anti-glare coaming, the glareshield, and an instrument panel with three displays in bezels with soft keys. The Sun falls across it as the ship turns. A warm flood under the glareshield and the displays' own glow keep the shadow side readable. The head sways a few centimetres against the deck under thrust and in a knock, which gives parallax. In transit, free look turns the head inside the deck. The deck is built from where each edge should sit in the view, so it holds at any window size, and it is rebuilt for a new aspect. The pilot sits looking 10° down, so the nose axis (the gull-wing boresight) is in the middle of the windscreen, not the middle of the screen.
  - **The displays are drawn in 2D over the glass** through a projective map, so the vectors and text stay crisp while the panel is seen in perspective. Colour means one thing everywhere: white is measured, green is within limits or engaged, amber is caution, red is warning, cyan is a target or command, and grey is a label or scale. The soft-key legends along each display's foot are the keys that drive it, with their current state.
  - **Glareshield annunciator panel:** MASTER WARN and MASTER CAUTION, two banks of six lit capsules, the co-pilot's message window (the approach instruction or the burn commentary), and a clock (UTC, time compression, credits). On the approach the banks are PROX, HULL, CONTACT, FUEL LOW, HEAT and DRIVE, then CAPTURE, SPIN MATCH, DOCK COMP, ASSIST, BOOST and BRAKE.
  - **APPROACH display:** range, closing rate, the target closing speed, and the speed, alignment and roll-key errors against their limits. A range against closing-rate chart (log range) shows the co-pilot's profile in cyan, the capture limit in amber and our track in white, as on a real rendezvous. The docking-axis display shows the axis offset (dot), where the axis lies from the nose (diamond), the roll key against its index, and the capture envelope chips.
  - **SCANNER display:** the original Elite's elliptical 3D scanner, modernised. The plane has range rings labelled on a square-root scale, the forward field of view and bearing ticks. Every contact has a height stalk and a shape by type: the station a square, ships a diamond in fleet colour, work pods a triangle, rocks a dot. Contacts on a collision course turn amber, then red, with a closing-contact countdown. A station off the scale gets a chevron on the rim.
  - **SYSTEMS display** (shared with transit): a top-view ship schematic. Each module is coloured by its damage, with radiators as fins and the keel as the spine, and the worst hit is named. Gauges show propellant (% with burn time at full thrust), radiator load (with a throttle-back warning), drive thrust available, keel, hold, life support and mass.
  - **Transit cockpit:** the same deck. BURN shows the phase, velocity, thrust, to-go, ETA and arrival, and the velocity profile of the whole transfer with the turnover marked. NAV is the trip from above, with the track flown and to come, Earth, Moon, origin and destination, ranges, and the one-way light time to Earth. The annunciators show BURN, TURNOVER, COAST, FLYBY, TELESCOPE and PAUSE. Through the telescope the deck is out of the picture and a sight reticle shows.
  - **Chase view:** no deck. The same displays sit in a flat telemetry strip along the bottom. The comms log and notices sit just above whichever panel is showing (a cockpit HUD offers `overlay_slots()` to `main.gd`).
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
    - Pressure hull (`weld`, on every livery's hull paint) shows how it was joined, close in. The long seams are butt-welded: a rippled bead, heat-tinted straw to blue on bare metal. The short seams are riveted, a row either side.
    - A dish face lays its panels round its axis (`mapping` 3).
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

## Riding the elevators (Oct 2026)

Sean's direction (2026-10-05): "make the space elevators rideable".

- **The lines** (`places.json` "elevator" on the anchor port, `sim/systems/elevator_system.gd`):

  | Line | From | Down to | Ride | Fare |
  |---|---|---|---|---|
  | The Luna Line | Halo Depot (L1) | Line Foot, Sinus Medii, under Earth | 56,000 km in 56 h | 150 cr + 20 cr/t |
  | The Piazzi Stalk | Piazzi Station (tender to the anchor) | Stalk Foot, Ceres' equator | 720 km in 7 h | 80 cr + 12 cr/t |
  | The Pavonis Line | Ares Ring (tender to areostationary) | Pavonis Foot, summit of Pavonis Mons | 17,030 km in 5 days | 600 cr + 45 cr/t, once the project finishes |

- **How a ride works:**
  - You ride down with your hold in a climber container; your ship stays docked at the port.
  - Each town has its own market. Ships can't fly there (`foot_of`, `Perks.place_open`), and there's no job board at the bottom.
  - To fly again, ride back up.
- **Where the towns are:** a new location type, `"surface"`. A town either turns with its body's day about its pole, or always faces another body, as the Moon's near side faces Earth.
- **The ride view** (`view/climber_view.gd`):
  - The cab is clamped beside a half-metre tape of the ribbon, drawn at true size, with marker plates every 50 m that smear to a streak under time compression.
  - The traction head sits below the window, a climber passes going the other way, and the world below is at its true angular size.
  - The readouts are real: altitude, speed, ETA, and your weight, which falls to nothing at the anchor (synchronous height on Ceres and Mars, L1 on the Luna Line). Near the bottom of the Luna Line you weigh 0.054 g.
- **Climbers:** NPC climber fleets carry goods between each port and its town without propellant, and talk on the comms channel. The Pavonis climbers enter service when the Pavonis Line is finished.
- **Capture:** `--ride=<dir>` rides each line down and back, shooting the cab and the towns.

## Saturn, rings and shadows (Oct 2026)

Sean: the rings were "very unrealistic and downright ugly"; the planet should cast its shadow on the rings and on moons and ships.

- **Rings** (`rings.gdshaderinc`, `rings.gdshader`): the radial structure follows Cassini's occultation profiles.
  - **D and C rings:** faint; C is a grey-brown veil with plateaus.
  - **B ring:** bright and opaque, butterscotch, densest through its middle.
  - **Cassini division:** dark, with the Huygens gap at its inner edge.
  - **A ring:** greyer, with the Encke and Keeler gaps.
  - **F ring:** a thin thread.
- **Ring lighting:**
  - The lit face reflects as Lommel-Seeliger: thick rings bright, thin ones barely.
  - From the unlit face, thin rings glow with light that came through and the B ring goes dark.
  - Each point hides 1 - exp(-tau/mu) of what is behind it.
- **Shadows on and from the rings:**
  - The planet's shadow cuts across the rings.
  - The rings' shadow bands fall on the planet (gas shader).
- **Saturn itself:** flattened 0.902 (Jupiter 0.935), pale butterscotch with low-contrast bands and a bluer, greyer pole.
- **Eclipses** (`eclipse.gdshaderinc`):
  - **Sky bodies:** each carries its planet's shadow at its own sky scale, so Enceladus can pass into Saturn's shadow.
  - **Ships and stations:** they read a global occluder (`SkyKit.set_eclipse`). The sky copy shades the origin exactly when the real body would, so a station on Earth's night side goes dark, apart from its lights and a little planetshine.
  - **Title shots:** they set their own eclipses.
- **Fix:** notices no longer leave a freed lambda behind when they are pushed out early.

## A torus, a ring, and collisions (Oct 2026)

Sean's direction (2026-10-05): add a Stanford torus and an orbital ring; ships collide with asteroids and other objects, with realistic damage and destruction.

- **The Tsiolkovsky Wheel** (project `tsiolkovsky_wheel` at Trojan Yards, from day 15):
  - **The design:** the 1975 NASA-Stanford study. A ring 1.8 km across with a 130 m tube, six spokes, a hub, and a mirror held still at 45 degrees. It turns once a minute for a gee at the rim.
  - **Building it:** you watch it go up 12 km from the yards: hub and spokes, the tube in 48 sections, regolith shielding (it darkens), then lights and spin.
  - **When finished:** it opens as a port (a "stanford" station model, docked at the hub) with a big food and people market.
  - **Its position:** the location type `lagrange` takes `offset_km` in the turning frame.
- **The Selene Ring** (project `selene_ring` at Shackleton Port, from day 100):
  - **What it is:** an orbital ring 52 km above the Moon's equator (`bodies.json` structure `orbital_ring`).
  - **Building it:** it goes up in arcs, the growing end lit; once closed, twelve tethers come down to lit ground stations.
  - **Drawing it:** it is drawn at least a pixel or so thick, based on the distance to the ring itself rather than to the Moon.
  - **On the title screen:** the low lunar run flies over the equator with the ring arcing up from the horizon.
- **Collisions** (`sim/systems/damage_system.gd`, `balance.json` "damage"; flight scene):
  - **What you can hit:** the station (as before), NPC ships, work pods, the big set pieces (Trojan's captured rock, Island One, the Wheel's ring), and drifting rock fields on some approaches. The fields are at Psyche Claims, Hektor Reach, Trojan Yards and Piazzi (`places.json` "hazards"); the approach corridor is kept clear, and rocks show on the scanner.
  - **Momentum:** contacts trade real momentum. Rocks are pushed and set spinning, small ones shatter when hit hard, and you tumble.
  - **The physics:** above 0.8 m/s, the energy your ship absorbs per kilogram (0.5 v^2 times your share of the reduced mass) over 50 J/kg is the damage to the module hit. The module is chosen by where the blow landed:
    - the nose: command pod or avionics
    - the middle: cargo bays
    - the tail: tanks or drives
    - the flanks: radiators
  - **The keel:** a third of each hit, plus whatever a wrecked module can't absorb, goes into the keel. A 5 m/s knock costs a few per cent; 10 m/s badly damages a module and takes about 30% of the keel; 14 m/s into a station is a lost ship.
  - **Effects:** damage takes its share of what each module gives (`ShipStats._sum`):
    - drives push less
    - holed tanks vent what they can't hold, and broken pods spill cargo
    - radiators reject less, and habs keep you alive for less long
  - **Repairs:** shipyards repair everything; other ports patch the worst back to 25% damage, at a premium.
  - **Destruction:** a flash, debris, and the lifeboat away.
    - The port's tug brings it in after 25 s.
    - The insurance pool finds you a stock Mule for a 3,000 cr excess.
    - Cargo and carried jobs go down with the ship; story favours are offered again.
- **HUD and capture:** the HUD has a HULL row and a proximity alert for rocks on your course. `--crash=<dir>` shoots a rock strike and a wreck.

## Places the projects build (Oct 2026)

Sean's direction (2026-10-07): "when new stations and bases come online they need to be actually selectable in the destinations."

A place with `opens_with: <project>` in `data/places.json` is closed (`Perks.place_open`) until the project is done, then is a normal port. Four more habitats now work this way, each with its own market, built from the project's description:

| Place | Project | Where | Model | Trade it brings |
|---|---|---|---|---|
| Island One | `island_one` | L5, 3 km off The Kernel | cylinder 250 m radius, 500 m long (see below) | Food and oxygen out; water, volatiles, parts and habitat modules in. A second food source at L5 for the Kernel and Trojan. |
| Kalpana Two | `kalpana_two` | Kalpana One's orbit, 760 m ahead | cylinder 250 x 325 m, turning the other way | Food and medicine out; water, oxygen, parts, electronics in. It shares Kalpana One's fuel dock, so no pump. |
| Concord | `concord_pair` | Over Ceres, 10 degrees round from Piazzi (about 120 km) | cylinder 4 km radius, 32 km long, 0.47 rpm | The Belt's first big farm: 10 t/day of food out, 10 t/day of Ceres ice and volatiles, parts and refined metal in. |
| Selene Ring | `selene_ring` | Lunar orbit at 52 km altitude | wheel 400 m radius at lunar gravity | Regolith, refined metal and a little helium-3 out; water, food, parts in. Refined metal from the Moon is new for Clarke, the Kernel and Trojan. |

**Departures from the real thing, on purpose** (kept here because there is no RESEARCH entry for each):
- **Island One is a Bernal sphere, but the station model only has wheel, cylinder and stanford.** It is built as a squat drum (radius 250 m, length 500 m, the same diameter) until a sphere type exists. The unfinished sphere in the sky (`bernal_frame`) is the real shape.
- **Concord is one cylinder.** The pair is two, counter-rotating; the dockable model is the first, and the second is not modelled in the dock scene. The set piece shows both from Piazzi.
- **Kalpana Two's spin is negative** (`spin_rpm: -1.89`): it turns the opposite way to its sister. If the docking scene mishandles a negative rate, make it positive and note it.
- **The Selene Ring is a Keplerian orbit at 52 km.** A real orbital ring's sheath stands still and its cable moves faster than orbit; a ship cannot match that, so the junction co-orbits like any station.
- **Places beside a port sit on its orbit**, a few hundred metres to a few km ahead. Hops between them are very short (Kalpana One to Kalpana Two is 760 m). Trade between them is bounded by the spread, the docking fee and the time to dock, but watch the balance bot for it.

**What honours "open" now** (everything that lists places goes through `Perks.place_open`):
- **Departures** (station screen), the system map and the orbit view's markers and labels.
- **Job boards:** both ends of an offer (`Contracts.make_offer`), and rumours (`tip_system`).
- **NPC traffic:** traders (`_choose_trade`, including the "nothing pays, so drift" fallback, which used to pick from every place, closed or not), and fixed-route fleets. A fleet that serves a project's place sets `commission_project`, so its ships stay out of service until the project is done and then run on their `commission_days`. New fleets: `island_haulers`, `kalpana_two_ferries`, `concord_tenders`, `ring_tankers`. They only carry goods the destination is short of.
- **The Spaceline:** each project's `complete` story says the place is open to visitors.
- **Tips and brokers:** regional brokers' `coverage` lists include the new places (Maisie Tran: Kalpana Two; Auntie Vell: Island One and the Tsiolkovsky Wheel). The old logbook has no board for a place that is not open, so a new place says "No price board on file" until you have seen it. Brokers with `coverage: "all"` pick them up on their own.
- **Markets:** closed places' markets still run from day one, so they open warm. A save from before a place existed grows its market at target on the next tick.
- **Docking:** every place with a `station` block gets a flight scene. `--dock-trial` flies the autopilot into every non-foot place, open or not, so new places are covered automatically.
- **Tools:** `tools/route_clearance.gd` checks every route between every non-foot place, open or not.

To add the next one, copy an entry (`tsiolkovsky_wheel` for a lagrange spot, `kalpana_two` for an orbit), set `opens_with`, give it a `station` block and a market whose flows only name goods on it, add a `complete` story to `data/news.json`, add a `commission_project` fleet if it should have traffic, and add it to a broker's `coverage` if that broker lists places by name. `test_new_habitat_places` shows what to check.

**Considered and not added:**
- **Valhalla science ring** (`valhalla_deep_ring`): Valhalla Station already exists as a place and the ring is its expansion, with a private, invitation-only project, so nothing new to dock at. Visitor passes by reputation are a later job for contracts.
- **Landauer Deep's second core** (`second_core`): Landauer Deep is already open (day 60, `opens_after_days`). The second core is its own interior; a second dock would only repeat it.
- **Tharsis greenhouses** (`ares_greenhouses`): the greenhouses are on Pavonis Mons, which is Pavonis Foot (`opens_with: pavonis_line`, `foot_of: ares_ring`). It already has a food market; ships cannot land there, you ride the ribbon. Ares Ring's produces x1.6 is the project's effect.

## The ship view in transit (Oct 2026)

Sean's direction (2026-10-06): a follow camera with mouse control while the ship travels. Left alone, it should frame cinematic shots of the ship and interesting things nearby, inspiring, and show off the design.

- **`view/follow_view.gd`** is the default transit view. M cycles ship, orbit, cockpit and map.
- **The ship:** the player's ship sits at true size in its burn attitude, rolled to the Sun. The panels track the Sun, the dish holds on the destination, and the plume shows while it burns.
- **The sky:** worlds sit on it at true angular size, dressed with plumes, elevators and rings. In a world's shadow the ship goes dark.
- **Ports:** the ports at either end appear as models while they are within 30 km, placed at the path's own end points. Each is kept clear of the ship (behind it leaving, ahead arriving) with its docking face turned to you.
- **Free camera:** drag with either mouse button to orbit the ship, use the wheel to zoom, or the arrow keys. Taking over starts from wherever the director had the camera.
- **The director:** after 8 s hands-off it takes over, cutting through black every 11 s, never repeating the last set-up. Choices are weighted by the moment:
  - a chase, a slow orbit, a fly-past, and a dolly along the hull
  - into the Sun (backlit), and the drive while burning
  - the hero world behind the ship: the destination if it is a decent size, else the biggest in view. A world filling the sky is framed across its limb, as a horizon.
  - a long lens (7-9 degrees, from 20 ship-lengths back), so the world looms behind a small ship. This is only for worlds small enough to sit whole behind it.
  - the station at either end of the trip
- **Lighting:** a soft fill light rides with the camera, so the design reads on the night side. Sky worlds no longer receive ship shadows.
- **Capture:** `--shipcam=<dir>` shoots every set-up at the moments it suits (leaving, burning, coasting, arriving), and tests real mouse input.

## Sound: heard through the hull (Oct 2026)

Sean's direction (2026-10-06):
- ambient ship noises
- the distant rumble of engines through the structure
- the structure as the ship rotates to the burn vector
- manoeuvring jets vibrating through the frame
- air pumps, and the motors turning radiators, panels and dishes
- positional, by distance from the crew section

- **Synthesised, not recorded** (`tools/make_sounds.py` writes `assets/audio/`, 16-bit mono 32 kHz; Godot imports it as QOA):
  - noise shaped in the frequency domain, so loops repeat seamlessly and carry WAV loop points
  - inharmonic metal modes, stick-slip friction trains for creaks, and sagging-pitch thumps for knocks
  - the result is dark and structure-borne, because in vacuum nothing reaches the crew but what comes through the frame
- **Heard from the crew section** (`view/audio/ship_audio.gd`): the AudioListener3D sits in the cabin whichever camera is in use, and each source sits on its hardware:
  - the drive at the stern: a rumble, with ignition and cut-off
  - each jet cluster (marked by ship_builder in `rig.rcs`): a knock and a valve snap per pulse, firing the clusters that push the way you asked or give the torque
  - a motor at every panel hinge and on the dish's two axes: a servo whine that follows how fast the hinge is turning
  - the pumps behind the cabin, and the cabin air around you
  - the frame: creaks and groans as strain builds from turning, changes of turn and the drive's load
  - knocks and crunches on impact, the alarm, the proximity beep, and the wreck
- **Distance from the cabin** makes a source quieter (inverse distance) and duller (a low-pass that closes with distance). A deep freighter's drive is a long way back.
- **The "Hull" bus** adds a short metallic ring and rolls off the highs.
- **Under time compression** (Sean: "a bit of a mad cacophony"), the ship's sounds and the place ambience duck smoothly: about -11 dB at x10, -16 at x100, -21 at x1000, never below -24. Routine one-shots (jets, creaks) thin out to at most one every 0.3 x (1 + log10 scale) s. Ignition and cut-off thumps don't repeat within 4 s, though the rumble still follows the burn. Impacts, the wreck and docking always play.
- **In transit** (`view/audio/transit_audio.gd`), a hidden copy of your ship carries the sound under every view (ship, orbit, cockpit, map). It turns to its burn attitude at the views' rate (creaks and attitude jets while it swings), burns when the plan does, and tracks the Sun and destination with its panels and dish (motors).
- **Places:**
  - docked: the station's hum and distant clanks, with the docking clamps and pressure hiss as you come in
  - in a town or on a site: the pumps and air
  - riding an elevator: traction wheels over the ribbon's joints
- **Controls:** F2 turns sound on and off.
- **Headless runs** (tests, smoke, docking trial) build every source but play nothing, as there's no audio device. Quits stop all sound first, so nothing is left registered with the audio server.
- **Listening demo:** `tools/make_sound_demo.py` mixes about a minute of a ship's day offline into `build/ship-sounds-demo.wav`, for auditioning without the game.

## The Kestrel: a lander for the inner kid (Oct 2026)

Sean's direction (2026-10-07): the Eagle from *Space: 1999*, "a much loved design... the way the landing legs/pads allow it to safely touch down on solid surfaces of moons and other bodies. if our ship builder can create ships like that too it would be just magical to my inner kid."

- **The Kestrel-class surface transporter** (`view/flight/kestrel.gd`, hull `kestrel` with `look.layout: "frame"`; `ship_builder.gd` hands frame-built hulls to it) is our own design in that spirit:
  - **Spine:** an open box-truss, with service ducts.
  - **Command module:** an octagonal cabin with a faceted nose, windows set into its upper facets, a hatch and docking collar on top, and a steerable dish.
  - **Leg pods:** four, each with a lift thruster firing down (a hollow `small_bell` with its jet under `LiftPlume`), and a sprung leg: outrigger, knee, telescopic shock absorber, ball-jointed footpad, drag brace. `Kestrel.compress()` pushes the pistons in.
  - **Payload pod:** passenger or cargo, slung beneath on clamps.
  - **Service module aft:** four propellant spheres and four short-burn chambers with hollow bells and pale jets.
- **In the data:**
  - spine `kestrel_frame`, with a new `gear` slot
  - modules `kestrel_cmd`, `kestrel_pod`, `kestrel_tanks`, `kestrel_engines` (no reactor heat) and `kestrel_gear`. The gear sets `lander: true`, so a Kestrel can work landing sites itself.
  - a Luna Cooperative pair flying Shackleton Port to Farside Array
- **The lander scene** now flies the Bramble as a small Kestrel (a third size, cargo pod). It descends on its lift jets, and at touchdown the legs take the impact: a soft landing settles onto the springs, a hard one bottoms out.
- **The title** gains a touchdown shot: a Kestrel lowering onto the Moon, legs compressing and rebounding.
- **Capture:** `--kestrel=<dir>` shoots it standing on regolith from all round.

## Scale: giving the giants back their enormity (Oct 2026)

Sean (2026-10-07): a ship passing in front of a gas giant has no depth cues, "this makes the planet look very small or the ship huge... even if it might be actually correct, this is a game so I want the visuals to be inspiring". Space has no haze, so the game borrows the cues the eye uses on Earth:
- **Atmospheres** (`atmosphere.gdshader`, `look.atmosphere` on Earth, Venus, Mars, the giants and Titan): a shell above the surface glowing where the line of sight grazes it, on the sunlit side, warm at the terminator, brighter when backlit.
- **Limb darkening** on gas giants and cloud worlds: the edge darkens through the haze, so a giant reads as a ball.
- **Aerial perspective** (`SkyKit.set_distance`, a `veil` uniform in every body shader): the further a world is, the softer and cooler it is. None within a thousand km, about a third by a tenth of an AU. A crisp ship against a softened giant reads as near against vast.
- **Planetshine** (`SkyKit.planetshine`): the biggest world in view lights the ship's facing side, in its colour, scaled by its size in the sky and how much of its day side faces you.
- **Bloom:** a gentle one in every scene, on bright limbs, beacons and exhausts.
- **Dust** (`SkyKit.dust`): sunlit motes drifting around the ship-view camera, so near and far read apart as the view turns.

## Leaving, arriving and keeping clear (Oct 2026)

**No route through a world.** `tools/route_clearance.gd` plans every pair of ports at several departure dates, both quick plans and the co-pilot's gravity-flown options, and walks each path against every body. The clearance is the body's radius plus the atmosphere the renderer draws (`look.atmosphere.thickness`), and at least 20 km above the ground. Any crossing of Saturn's ring plane inside the main rings also counts. On the first run 154 of 272 quick routes failed. The fixes:
- **Voyages between worlds** (`Interplanetary.dress`). The Sun-centred transfer runs from planet centre to planet centre, the patched-conic shortcut. The flown path now adds a climb-out round it: a spiral from the station, turning the way it orbits, out to a hand-off point clear of the world. The capture is the same in reverse. The transfer eases off and onto the hand-offs along its direction of travel, so the offset can only carry the path further out. Times, distances and propellant are unchanged.
- **Quick trips in a planet's system** keep clear of the frame body, the bodies each end orbits, and the Moon. Each is tracked through the trip at its true position: the Moon's distance swings by tens of thousands of km, and Titan circles Saturn. A run that would cut through one goes round it on an arc (`_around`). The arc swings once it has climbed clear, and keeps the straight run's timing and propellant, so no trip got longer or dearer. Anything still grazing is eased up onto the clearance smoothly (`_clear_of`); the path bends, it doesn't kink.
- **Gravity-flown trips** get the same tracking for the climb-outs and hand-offs either side of the flown part.
- **Two old bugs.** Sun-planet Lagrange stations (Hektor Reach, at Jupiter's L4) were treated as deep in the Sun's well: their trips started at the Sun's centre and came out as NaN. They are now in free solar orbit, as they should be. The conic propagator's last velocity can come out NaN, and samples are now cleaned.

**Navigation lights** (`Kit.nav_light`, `view/flight/lamp.gd`, `view/shaders/halo.gdshader`):
- **Fixtures, not blobs:** a dark housing on the skin, a coloured lens that is dim unlit, and when lit a brighter lens and a glow that faces the camera. The glow never shrinks below a few pixels, so a ship's lights read as points of light a long way off.
- **Patterns:** red to port and green to starboard pulse together; a white anti-collision strobe double-flashes on the keel; a red beacon sweeps on each drive.
- **Blinking:** every flashing light drives itself from the real-time clock. It works in every view, and time compression never speeds it up. Before, only the docking scene and the title drove blinking, so in transit the lights stood still.

**Leaving and arriving like a film.**
- **Time** (`travel_system._time_ramps`, data in `balance.time`):
  - Departure drops to x1 while the ship backs off the port, then steps up (`departure_ramp`: 20 s at x1, then x10 and x100 for a few seconds each, x1000 about 30 s out), unless the pilot picks a scale of their own. After backing out nose-first, the ship turns to point along its first burn and holds there until the drive lights.
  - Coming in, time is capped ever lower as the port nears (`approach_caps`), so the last ten seconds play at x1.
- **The ship view** (`follow_view.gd`) shows the ports at each end for the first and last 20 minutes of the trip.
  - Leaving: the port sits off the nose, docking face toward us, and falls away as we back out nose-first, turn and go.
  - Arriving: it lies ahead and we close on it, slowing, to the point where the approach scene starts us, so the hand-over picks up where the ship view left off.
  - Each corridor runs along the trip's own first or last leg.
  - Screens hand over with a short fade from black.

**Selling:** each Sell All button is green when selling the whole load here makes a profit over what you paid, and red at a loss. The IF SOLD column beside it gives the profit in credits. The whole load is priced together, since your sale moves the price.

## Ship power (Oct 2026)

A ship has an electrical bus, so the SYSTEMS page shows something real instead of a placeholder. Code: `sim/power.gd` (pure functions, shared by the sim and the cockpit), `sim/systems/power_system.gd` (integrates the battery, raises events), module fields in `data/modules.json`, globals in `data/balance.json` under `power`. Units are kW and kWh.

- **Supply.**
  - **Reactor** (`reactor_kw` on the fusion drives): output while lit. Lit in transit and on approach, while a site job runs, or when ordered with the `reactor` command (`{"mode": "on" | "auto"}`). Parked on a site it is cold.
  - **Solar** (`solar_kw` on the command section: its housekeeping wings): output at 1 AU times `1 / au²`, capped by `solar_factor_max` close to the Sun. The distance comes from the ephemeris, or from the transit path.
  - **Shore power** (`shore_kw`): when docked, which also charges the battery.
  - **Battery** (`battery_kwh` on the command section): the buffer.
- **Demand** (`life_kw`, `avionics_kw`, `comms_kw`, `sensor_kw`, `mining_kw` on modules): sensors and the rig idle at `standby_frac` of their load until a job needs them. **Radiator pumps** draw `pump_kw_per_mw` per MW of heat actually rejected: the drives' `heat_mw` times `heat_frac` for the phase, capped by what the radiators can reject. A cold reactor makes no heat, so the pumps stop.
- **Damage** works as in `ShipStats`: it cuts what a module supplies (wings, reactor, battery capacity, radiator rejection) and not what it draws, so a battered ship runs short sooner.
- **Deficit.** Net power is supply minus draw. A deficit drains the battery; a surplus charges it. The bus state is `SHORE`, `NORM`, `CHG` (charging), `BATT` (on battery), `SHED` or `LOW`.
- **Shedding.** Only while in deficit, by battery charge: below `shed_comms_below` comms and sensors go; below `shed_mining_below` the rig too; below `life_warn_below` life support gets its red warning (`LOW`, the POWER lamp turns red, `power_shed` level 3). Life support and avionics are never shed. A shed level is held until charge is `shed_release_margin` above its threshold. A survey or mining job whose module is shed waits for power instead of failing (`SiteSystem` pushes its end time out).
- **The outer-system consideration.** With the reactor cold, solar alone carries a Mule's hotel load only out to about 1.6 AU. Parked at a belt or Trojan site you run on the battery: about three days at Hektor (70 h), four at Psyche. Light the reactor (starting a job does it) or plan for it.
- **Cockpit.** SYSTEMS shows battery % and bar, bus state, net kW, and time to empty or full; the POWER annunciator is amber when the battery is running down (below `power_caution_frac` or within `power_caution_hours` of empty) or loads are shed, and red when life support is next. White is measured, green is fine. All cockpit alert thresholds (fuel, hull, heat, module damage, power) are in `balance.json` under `cockpit`.

Departures from hard physics, on purpose: reactor fuel is free (the fusion burn for a few hundred kW is grams a day); a flat battery never hurts the crew (the warning and the shed loads are the consequence); battery capacity is folded into the command section's mass; the state of the bus is shown as a word rather than a bus voltage; shore power is a flat rate.

## Controls: remapping and gamepads (Oct 2026)

Sean's direction: "we will let players remap in the future and use other control systems". Every gameplay control is now a named Godot InputMap action, so there is one source of truth and views never name a key.

- **Where it lives:** `data/controls.json` lists the actions by section (Anywhere, Flying an approach, In transit, Landing, Riding an elevator, Title screen) with each one's default keyboard (`key`) and gamepad (`pad`) bindings, plus the analog deadzones (`gamepad.deadzone` for sticks, `trigger_deadzone` for triggers) and the reserved bindings (Esc and the pad's Back button cannot be bound; they close or cancel the page). `view/bindings.gd` reads it, applies the player's overrides, and builds the InputMap at startup (`Bindings.install`, called by `main.gd`). The controls page, the HUD key strips and the title prompt all read their text from it.
- **Views** ask `Input.is_action_pressed("flight_boost")` or `event.is_action_pressed("pause")`, never `KEY_*`. A new control means a new row in `controls.json` and nothing else; a test fails if view code names an action the file lacks.
- **Bindings** are specs: `key:W` (a physical key, so WASD stays WASD on other layouts), `pad:a` (a button) or `pad:lx-` (a stick or trigger pushed one way). An action has a keyboard list and a gamepad list. The shipped keyboard defaults are exactly what the views read before remapping existed (a test pins them).
- **Rebinding** (F1, or Back on a pad): click a keyboard or gamepad cell, or move to it with the d-pad and press A, then press the new key, button, or push a stick or trigger. Esc, right-click or Back cancels; Backspace clears. That replaces the action's bindings of that kind. If another action on the same screen already uses it, **the two swap** and the page says so. A swap is **refused** (and nothing changes) if the other action could not take the old binding without a clash of its own, or if the binding is reserved. "Same screen" means the same section, and "Anywhere" counts as every section; flight, transit, landing and the title can reuse a key (A strafes in flight and drifts in the lander). "Reset to defaults" asks twice.
- **Saved** in `user://settings.cfg` (a `ConfigFile`, section `[controls]`, only what differs from the defaults, as `action.key` / `action.pad` lists). It is loaded at startup and saved on every change; other sections in the file are kept. In the web build `user://` is the browser's storage, so it persists per browser profile. Unknown actions and bad specs in the file are ignored.
- **Gamepad defaults:** in flight the left stick strafes (x) and moves up/down (y), the right stick pitches (y) and yaws (x), the right trigger thrusts forward and the left trigger back, the bumpers roll, A boosts, B brakes, X toggles spin match, Y cycles assist, the d-pad does scanner range (up), cockpit/chase (down), docking computer (left) and the key strip (right), a left-stick click calls the tug, and Start pauses. In the lander the right trigger or A fires the main engine and the left stick or d-pad drifts. In transit and on an elevator the bumpers slow and speed time, the right stick looks, A changes the view, X is the telescope and Y looks ahead again. On the title screen A starts and X loads the quick save. Stick up is nose up, as the Up arrow is; invert by rebinding pitch up to the stick pushed down. Labels use Xbox names (A, B, X, Y, LB, RB, LT, RT).
- **Analog flight:** thrust, strafe, pitch, yaw and roll read action strength (0 to 1, after the deadzone), so a half-pushed stick is half a push. Keys give exactly 0 or 1 as before, and two keys on different thrust axes still make a unit vector, so keyboard flight is unchanged. A half-pulled trigger gives half the RCS acceleration.
- **Departures and gaps:** the lander and elevator view are still digital (a stick past its deadzone counts as a full push); lander and flight keys now follow physical key position rather than the typed letter; a mouse is not rebindable (it drives menus and the free camera); and "Anywhere" has no gamepad quick save, load or sound toggle by default (bindable on the page).

## Passengers and hand-carried parcels (Oct 2026)

- **Passenger berths** (6 berths, a cargo-slot module) are sold at five yards: Kibo Ring, Trojan Yards, Ares Ring, Piazzi Station and Hektor Reach. Before, only Kibo Ring sold them, and nothing said where to look. A passenger job you can't take yet now names the yards that sell berths.
- **Small things are carried by hand** (`hand_items` in `data/contracts.json`): letters, papers, a diplomatic pouch, a briefcase, a data cube. They take no hold space, only their few kilograms of mass. Courier, pickup and long-haul jobs draw them alongside freight, and the card says "carried by hand (no hold space)".
- **The cabin.** Passengers ride in their berths and take no hold space either. Cabin loads (`ship.cabin_t`) count toward the ship's mass but not the hold (`ShipStats.cargo_t`). A job remembers where it was stowed, so jobs taken in older saves come off the hold as they went on.

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
