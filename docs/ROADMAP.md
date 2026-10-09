# Roadmap (agreed October 2026)

Eight steps, in dependency order: each later step builds on the earlier ones. Mark a
step done here when it lands on main.

| # | Step | Depends on | Status |
|---|---|---|---|
| 1 | Turning with inertia | none | done |
| 2 | Smooth rendezvous arrival | 1 | done |
| 3 | Bigger stations, docking bays and doors | 2 | to do |
| 4 | Humpback cargo lander and pod types | none (can run alongside 2 and 3) | done |
| 5 | Satellite missions | 4 | to do |
| 6 | Detection model and stealth package | 1 | to do |
| 7 | Secret missions (late game), with free departures | 4, 5, 6 | to do |
| 8 | Walking about, first person | 3 | to do |

Do visual and feel work locally, where it can be checked by eye. Send sim-heavy work
(the maths in step 2, the mechanics in step 4, the model in step 6) to cloud jobs on
separate files.

## 1. Turning with inertia

The transit view (`view/follow_view.gd`) turns the ship at a fixed `TURN_RATE` (0.9
rad/s), with a slerp that starts and stops instantly. Hand-flying
(`view/flight/flight_scene.gd`) already has inertia (`turn_accel_dps2` 70 in
`data/balance.json`).

- Give the transit view the same model: accelerate, coast and decelerate.
- A turn rate per hull, so a laden hauler turns slower than a courier.
- A puff of the RCS thrusters at the start and end of each turn.
- Start the turn early enough that the ship is lined up before each burn.

## 2. Smooth rendezvous arrival

The trip ends at the port's orbit, and the docking scene then spawns the ship at a
fixed spot (`spawn_distance_m` and `spawn_offset_m` in the docking settings). The
result is an unrealistic turn and chase.

- A final approach phase in the port's own frame: come up from behind or below, brake
  along the docking corridor, and arrive slow and lined up.
- The docking scene starts exactly where the transit view left the ship: the same
  position, speed and attitude.
- Trip time and fuel stay close to today's. The route-clearance test
  (`test_routes_clear_of_bodies`, `tools/route_clearance.gd`) must stay green.

## 3. Bigger stations, docking bays and doors (done)

Built in October 2026: see "Docking bays" in `docs/DESIGN.md`.

- Every station has a docking bay you fly into: a lit tunnel 32 m across and 80 m deep,
  built forward of the docking face, with the port at its back. Wheel hubs grow to the
  bay's width.
- Doors are chosen per station in the data (`station.door`): iris at the big Earth
  wheels and habitats, clamshell at the yards and working ports, sliding elsewhere.
  They open when traffic control clears you, and close once you are inside.
- Shut doors count as a collider; inside, the tunnel's walls do.
- The port did not move, so step 2's approach and every trip are unchanged.
- The docking trial passes at every port in a Mule and in a deep freighter, the
  biggest ship a player flies.

## 4. Humpback cargo lander and pod types

The Bramble (`view/flight/kestrel.gd`) carries its pod slung too low under the spine,
below the lift thrusters' line of thrust.

- Raise the pod on a humpback spine, in line with the lift thrusters' thrust.
- Pod types: cargo container, liquid tank, passenger cabin, open flatbed, payload
  carrier.
- Deploy, drop off and pick up at sites. A dropped pod stays in the saved state until
  it is collected.

## 5. Satellite missions (done)

Built in October 2026: see "Satellites" in `docs/DESIGN.md`.

- A new board job: carry a satellite in the lander's payload carrier and release it
  near its orbit (`release_satellite`, key R in transit, or from the bay at the port).
- In transit you see it drift clear of the ship and unfold its wings.
- Placed satellites stay in the world (`state.sites.satellites`) and keep station off
  the hub when you next visit.
- The covert version, a spy satellite, is one of step 7's jobs.

## 6. Detection model and stealth package (done)

Built in October 2026: see "Detection and stealth" in `docs/DESIGN.md`.

- A signature for every ship (`sim/detection.gd`), from:
  - the lit drive
  - waste heat
  - lights and transponder
  - reflected sunlight
- Sensor ranges for stations (`places.json` `sensors`). Patrols wait for ships that
  patrol.
- The stealth modules:
  - a low-observable coating (`coat_hull`, at the three outer yards)
  - a heat sink module that holds heat for about a day
  - dark running (`dark_running`, key D in transit): lights and transponder off, fined
    near ports
  - panels folded in (`stow_panels`, key F) while coasting: less sunlit area and
    radiated heat, no solar power
- Honest physics: you can hide while coasting, never while burning.
- Offences are counted (`state.detection.offences`), ready for step 7's impound for
  repeat offenders.

## 7. Secret missions (late game) (done)

Built in October 2026: see "Secret work" in `docs/DESIGN.md`.

- It unlocks at Reliable standing with any operator, and comes as quiet approaches.
  The story arc doesn't gate it yet.
- Five kinds: covert deliveries, listening devices, spy satellites, and drop-offs and
  extractions at sites with the lander.
- Each job is hidden from a watcher, whose ports seeing you build suspicion, fast with
  the transponder on. Docking at its port with the work aboard means customs.
- Being caught fails the job and costs a fine, standing and an offence. The third
  offence impounds the ship until you pay.
- **Free departures:** leave without filing a plan. Busy ports fine you, more each
  time. With no plan filed, slipping every port's sensors loses whoever is watching.
  Simplification: the co-pilot still flies straight to the real destination. There
  is no decoy heading and turn yet, because the planner can't re-plan mid-trip.

## 8. Walking about, first person

Sean, Oct 2026: walk around the places you visit, FPS style.

- A character controller and interiors: the docking bays (step 3), station
  concourses, the bars, the elevator towns and counterweights.
- It's a big view-side job. It comes after step 3, which gives you somewhere to walk.
- In the sim it's only a view: what you do while walking (the bar, the market, a
  contact) still goes through the same commands.

## Done alongside the steps

- **Counterweight rides** (Oct 2026): every elevator goes on past its anchor to a
  counterweight you can ride out to, just to have been there. Ballast Point is
  26,000 km past L1, Stalk Top is on Ceres and Pavonis Ballast is on Mars, each with a
  bar.
- **Badges** (Oct 2026): one-off marks for going where few go or standing the bar a
  round. They add renown, which gets you noticed by hitchhikers and by clients asking
  for you by name.
- **Folding panels** (Oct 2026): solar wings and radiators fold accordion-fashion for
  docking and unfold once clear of the port (`view/flight/ship_rig.gd`), ready for
  step 3's bays.

## Decisions (confirmed by Sean, Oct 2026)

- **Stealth strictness:** honest, hiding only while coasting.
- **Docking style:** a bay you fly into.
- **Penalty for being caught:** reputation and fines, impounding only for repeat
  offences.
