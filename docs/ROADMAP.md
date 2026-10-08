# Roadmap (agreed October 2026)

Eight steps, in dependency order: each later step builds on the earlier ones. Mark a
step done here when it lands on main.

| # | Step | Depends on | Status |
|---|---|---|---|
| 1 | Turning with inertia | none | done |
| 2 | Smooth rendezvous arrival | 1 | done |
| 3 | Bigger stations, docking bays and doors | 2 | to do |
| 4 | Humpback cargo lander and pod types | none (can run alongside 2 and 3) | to do |
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

## 3. Bigger stations, docking bays and doors

Wheel hubs are only 8 to 20 m across, and their ports a few metres.

- Scale the hubs up to hold a docking bay you fly into: a lit tunnel or hangar, not a
  collar.
- Doors chosen per station in the data: folding or clamshell, sliding, or an iris.
  They open when traffic control clears you and close behind you.
- A door counts as a collider until it is open.
- The new approach from step 2 aims at the bay mouth.
- The docking trial must still pass at every port.

## 4. Humpback cargo lander and pod types

The Bramble (`view/flight/kestrel.gd`) carries its pod slung too low under the spine,
below the lift thrusters' line of thrust.

- Raise the pod on a humpback spine, in line with the lift thrusters' thrust.
- Pod types: cargo container, liquid tank, passenger cabin, open flatbed, payload
  carrier.
- Deploy, drop off and pick up at sites. A dropped pod stays in the saved state until
  it is collected.

## 5. Satellite missions

- A new contract kind: carry a satellite (cargo with real mass, in the payload
  carrier) to a given orbit and release it there.
- Release from the bay, the satellite's panels unfolding as it drifts away.
- Placed satellites persist in the world.
- The covert versions wait for steps 6 and 7.

## 6. Detection model and stealth package

Nothing in the sim detects ships yet.

- A signature for every ship, from:
  - the lit drive
  - heat on the radiators
  - lights and transponder
  - reflectivity
- Sensor ranges for stations and patrols.
- The stealth modules:
  - a low-reflectivity coating, looking dull and dark
  - a heat sink that holds heat for a limited time
  - dark running: lights and transponder off, which may be fined
- Honest physics: you can hide while coasting, never while burning.

## 7. Secret missions (late game)

Unlocked by reputation and the story arc.

- Covert deliveries.
- Planting listening devices.
- Spy satellites into watched orbits.
- Dropping off and extracting people with the lander.

Being caught costs reputation and fines, and impounding is possible for repeat
offences.

**Free departures** (Sean, Oct 2026). Today every departure names a destination. Add
leaving without one: no flight plan filed, just a heading.
- There's no reason to want it before secret missions, so it unlocks with them.
- Leaving a busy port (the main stations, Earth's neighbourhood) without a plan is
  frowned on: a fine or a dent in standing, and traffic control remembers.
- The point is the spy's exit: leave on a dull heading, and once clear of prying eyes
  and radar (step 6's sensor ranges), turn for where you really mean to go.

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

## Open decisions

These are recommended but not yet confirmed by Sean:

- **Stealth strictness:** honest, hiding only while coasting.
- **Docking style:** a bay you fly into.
- **Penalty for being caught:** reputation and fines, impounding only for repeat
  offences.
