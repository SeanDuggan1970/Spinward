# Walking about, first person: design notes

Status: **design notes, nothing built.** For roadmap step 8 (`docs/ROADMAP.md`). Collected as decisions come up, so the walking code starts from them.

## Spin gravity is the floor (Sean, Oct 2026)

Every station is a spinning wheel or drum. The gravity you feel is not gravity at all: it's the floor pushing you round the circle. Movement in first person has to come from that, not from a fixed downward pull.

- **How much:** at a distance r from the axis, the felt weight is `omega^2 * r` (`sim/spin.gd` `g_at`). It's highest on the ring and falls to nothing at the axis. Each station's spin is set for its ring's gravity (`places.json` `gravity_g`): mostly Moon- to Mars-like, never more than 1 g. Some figures:

  | Where | Felt gravity |
  |---|---|
  | Kibo Ring's ring | 0.38 g |
  | Kibo Ring's ship cradles | ≈0.03 g |
  | Kibo Ring's hub, on the axis | 0 |
  | Kalpana One's hull | 0.95 g |

- **Which way is down:** always straight out from the axis, so "down" turns as you walk round the ring. The floor curves up ahead and behind you, and a long corridor visibly rises.
- **Climbing toward the axis gets lighter:** going up a spoke by ladder or lift, your weight falls in proportion to your distance from the axis. Halfway up a spoke you weigh half as much, and at the hub you float. The controller blends from walking to drifting: handholds and push-offs below about 0.05 g, magnetic boots or a tether line in the docking hall.
- **Coriolis:** the floor moves sideways under you as you move toward or away from the axis, so:
  - **Climbing toward the axis**, a ladder seems to lean spinward.
  - **A dropped object** lands a little antispinward of the point below it.
  - **Running** changes your weight. Run spinward (with the spin) and you feel heavier, because you are going round faster. Run antispinward and you feel lighter. At Kibo Ring's ring (0.38 g, 380 m, 0.1 rad/s) a 5 m/s run changes your weight by about ±27%. That's playable, and a lovely thing to notice.
  - **Jumps** follow straight lines in the non-rotating frame, so seen from the floor they curve. On a small, fast station a long jump lands noticeably off. Simulate jumps in the inertial frame and draw them in the rotating one, and it comes out right with no special cases.
- **Model it, then tune it:** do the motion in the station's inertial frame (positions and velocities as in `sim/`, 64-bit), with the floor as a moving constraint. Render in the rotating frame. Expose two tuning knobs in `data/`: a Coriolis strength (1 is real) and a jump-height cap. Players can then be given the real thing or a gentler one, and both are honest about which way down is.
- **The HUD:** a small readout of local gravity ("0.38 g, Mars-like") when it changes noticeably. The same wording as the docking notice (`Spin.describe`).

## The docking hall is where you step off

Ships berth in cradles round the docking hall's wall (`view/flight/bay.gd`), just off the axis. That puts the first steps in first person at near zero g:
1. Out of the hatch onto the cradle's service walkway.
2. Along the gantry, holding the rail, to a lift.
3. Down a spoke, getting heavier all the way, to the ring's concourse, the bar and the market.

The hall's numbers on the wall, the yellow walkway and the clamp arms are already there to walk past.

## Other notes
- **The cockpit cabin** (`view/flight/flight_deck.gd`) is the first room you stand up in. The hatch on its back bulkhead leads to the rest of the ship.
- **Hibernation pods:** ships with a pod have one to walk past. A good place for the co-pilot's voice to greet you on waking.
- **The sim stays out of it:** walking is a view. What you do while walking (the bar, the market, a contact) still goes through the same commands (CLAUDE.md).
