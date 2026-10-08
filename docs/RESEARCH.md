# Spinward research notes

Status: first pass, 3 October 2026. These notes support `DESIGN.md`. Sourced facts carry a link. Calculations are mine and marked as such. Anything else is design opinion.

## 1. Lessons from comparable games

| Game | What to borrow | What to avoid |
|---|---|---|
| **Elite** (1984, Elite Plus 1991) | Simple, legible trade loop. Credits buy upgrades, and upgrades open new routes. One ship you grow attached to. Docking as a skill moment. | Fixed galaxy and arcade flight. Too little to do between trades. |
| **Frontier: Elite II** (1993) | Precedent for exactly this idea: full-size orbiting planets, Newtonian flight and time acceleration of 10–10,000x across realistic distances ([Wikipedia](https://en.wikipedia.org/wiki/Frontier:_Elite_II)). | Pure Newtonian combat was widely found "highly difficult". Hours of real-time cruising without acceleration. **Lesson: realism in travel, assistance in close flight.** |
| **Elite Dangerous** | The joy of the cockpit, and docking at large rotating stations. | Grind, and tedious travel without enough to do on the way. |
| **Terra Invicta** | A real solar system with delta-v budgets. Early engines allow only slow transfer orbits, and better engines open faster, more energy-hungry trajectories. Habitats with mining modules extract water, metals and volatiles ([Turn Based Lovers](https://turnbasedlovers.com/review/terra-invicta-1-0-impressions/), [PC Gamer](https://www.pcgamer.com/games/strategy/terra-invicta-review/)). **Engine tier as the progression gate is exactly what we want.** | Overwhelming detail. Players must not need to understand Hohmann transfers to enjoy it. |
| **Kerbal Space Program** | Making orbits readable: predicted trajectory lines, burn markers, planning nodes. | Requiring orbital mechanics skill to make progress. |
| **X4: Foundations** | Simulated supply and demand, where production chains create real shortages. Station building as a late-game goal. | Spreadsheet overload. Ours stays human-scale, with one player and one ship at first. |
| **Delta-V: Rings of Saturn** | Momentum-based mining flight that feels good, with crew and drones. | (from memory, not re-verified) |
| **Avorion / Space Engineers** | Building into asteroids and rock as a satisfying end-game creative outlet. | Free-form voxel building is a huge engineering effort. Ours is staged and modular. |

**Synthesis.** Spinward's niche is *Elite's* clear trade-and-upgrade loop, set in *Frontier's / Terra Invicta's* real solar system, with *KSP's* readable orbits handled for you by an AI pilot, and *X4's* economy at a human scale. It ends in a home you build rather than a war you win.

## 2. Near-future propulsion (what's real, what we stretch)

- **Direct Fusion Drive (Princeton Satellite Systems):** about 5–10 N of thrust per MW, specific impulse about 10,000 s. A 10 MW unit gives about 35–55 N ([Wikipedia](https://en.wikipedia.org/wiki/Direct_Fusion_Drive), [arXiv 2009.12621](https://arxiv.org/pdf/2009.12621)). A plausible "first fusion drive" for the setting.
- **The problem, by my calculation:** a 20 t ship on 50 N accelerates at about 0.00025 g. That's roughly **9 days** to the Moon and **130 days** to Mars at closest approach, even under constant thrust. That's realistic, but too slow for play.
- **Our approach:** Tier 1 is close to real (cislunar only). Each later tier is an in-world breakthrough with gamified numbers, and the fiction explains it as AI-assisted fusion research. All values live in `data/drives.json`.

Brachistochrone estimates (constant thrust, flip at midpoint, straight line, ignoring gravity), my calculation:

| Drive | Accel | LEO→Moon | Earth→Mars (closest) | Earth→Ceres (~2 AU) | Earth→Jupiter (~4.7 AU) |
|---|---|---|---|---|---|
| Real DFD, 20 t | 0.00025 g | 9.2 d | 130 d | 256 d | 392 d |
| T1 "Pathfinder" | 0.003 g | 2.7 d | 38 d | 74 d | 113 d |
| T2 "Courier" | 0.02 g | 1.0 d | 15 d | 29 d | 44 d |
| T3 "Torch" | 0.1 g | 11 h | 6.5 d | 13 d | 20 d |
| T4 "Long Reach" | 0.3 g | 6 h | 3.8 d | 7.4 d | 11 d |

At 10,000x time compression, 10 game days take about 86 real seconds. The delta-v figures for T3/T4 (hundreds to thousands of km/s) would need exhaust velocities no near-future drive has. Fuel is therefore an abstract, tunable resource ("fusion pellets + reaction mass"), not a strict rocket-equation budget. **This is a deliberate, recorded departure from hard physics.**

## 3. Habitats: the O'Neill cylinder in a rock

- **Spinning a whole asteroid doesn't work.** Studies of hollowed asteroid habitats find no hollowed body survives spin-up unreinforced. Large solid asteroids fracture, and smaller "rubble piles" disperse ([Frontiers in Astronomy and Space Sciences, 2021](https://www.frontiersin.org/journals/astronomy-and-space-sciences/articles/10.3389/fspas.2021.645363/full)). Asteroids over about 200 m are not observed spinning faster than about once every 2.2 hours ([arXiv 1810.01815](https://arxiv.org/pdf/1810.01815)).
- **So the plausible design is a rotating cylinder inside a non-rotating rock shell.** The rock is the radiation and impact shield, and the cylinder spins on bearings inside it. The same paper also proposes wrapping a rubble pile in a containment structure and spinning it. That's a possible late-game alternative.
- **Spin rates for 1 g (my calculation, ω = √(g/r)):** r = 225 m → 2.0 rpm (around the commonly cited comfort limit), 500 m → 1.34 rpm, 1 km → 0.95 rpm, 4 km → 0.47 rpm (O'Neill's "Island Three" scale). **This gives a natural expansion path:** start with a small, fast-spinning cylinder (lower gravity, or a "spin sickness" comfort penalty) and grow to larger, slower, more comfortable ones.
- Comets and icy bodies supply water, which becomes air, propellant and radiation shielding. Metallic and carbonaceous asteroids supply structure and organics. This ties base location choice to resource trade-offs.

## 4. Real data sources

| Need | Source | Notes |
|---|---|---|
| Planets/moons positions | [JPL Horizons API](https://ssd.jpl.nasa.gov/horizons/tutorial.html) | Ephemerides and osculating elements. Bake to a JSON catalog with a tool script; the game never calls the internet. |
| Asteroids & comets | [JPL SBDB API](https://ssd-api.jpl.nasa.gov/doc/sbdb.html) | Orbital elements and physical data (size, albedo, spectral type) for all known small bodies, as JSON. |
| Planet textures | [Solar System Scope](https://ftp.solarsystemscope.com/textures/) | Based on NASA imagery, CC BY 4.0 including commercial use ([Wikimedia Commons](https://commons.wikimedia.org/wiki/Category:Solar_System_Scope)). Needs a credits screen. |
| Other imagery | NASA | Generally public domain. Check each item. |

Plan: a curated catalog of about 30 major bodies plus a hand-picked set of named asteroids and comets (Bennu, Ryugu, Psyche, Vesta, Ceres, 67P…), plus procedurally generated "unnamed" small bodies seeded from real orbit-population statistics. Survey gameplay "discovers" these.

## 5. Engine facts that shape the architecture

- **Precision:** official Godot builds are single-precision, and jitter appears a few thousand units from the origin. Double precision needs a custom engine compile, and rendering shaders still use single precision ([Godot docs](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html)). **Decision:** keep the stock engine. The simulation stores positions as 64-bit floats in its own types (GDScript `float` is already 64-bit). Rendering uses a *floating origin* centred on the player, plus a separate scaled-down "far" layer for distant planets and the Sun.
- **Physics:** since Godot 4.6, Jolt is the default 3D physics engine for new projects ([GDQuest](https://www.gdquest.com/library/godot_4_6_workflow_changes/)). We use it only for local, close-range collisions and docking. Orbits are our own maths.
- **Language:** start in GDScript. The simulation is isolated so hot spots, such as the economy tick or a many-body orbit update, can move to C# (Godot .NET) or GDExtension later without touching gameplay or UI.

## 6. Space elevator counterweights

- **Lunar elevator through L1** (the Luna Line): the ribbon runs from the near side up
  through Earth-Moon L1, about 58,000 km from the Moon. It needs a counterweight
  beyond L1, toward Earth, to stay taut; how far depends on its mass.
  - About 26,000 km past L1 holds 1,000 kg of counterweight per kilogram hung just
    above the surface ([Wikipedia: Lunar space elevator](https://en.wikipedia.org/wiki/Lunar_space_elevator)).
  - Light designs run the ribbon on much further, about 220,000 km by one account
    ([Space Settlement Progress](https://spacesettlementprogress.com/tag/l1-lagrange-point/)).
  - Pearson et al. is the primary source ([record](https://cris.tau.ac.il/en/publications/the-lunar-space-elevator-2/)); not yet read in full.
  - **Our choice:** a heavy counterweight (Ballast Point) 26,000 km past L1.
- **Synchronous elevators** (the Piazzi Stalk on Ceres, the Pavonis Line on Mars):
  the counterweight sits beyond synchronous height. We use the sky dressing's
  `counter_r`: 3.7 Ceres radii, 550 km past the anchor; and 8.2 Mars radii, 7,400 km past.
- **What you weigh there** (the ride view works it out): gravity less the spin, or on
  the Luna Line, less Earth's pull in the turning Earth-Moon frame.
  - Ballast Point: about 0.17 milligee outward. Earth only just out-pulls the Moon, so a dropped spanner drifts slowly to the ceiling.
  - Stalk Top: about 4 milligee outward.
  - Pavonis Ballast: about 9 milligee outward.

## Open research for later passes

- Readable orbit-planning UI patterns (KSP manoeuvre nodes versus one-click "AI plot course").
- Economy models that avoid runaway inflation: production/consumption sinks versus fixed price bands.
- Real radiation environment (solar particle events, Jupiter's belts) as hazard data.
- Name/trademark check before public release. "Spinward" alone is used by other small games; "Spinward Accord" looked clear in a quick web search (not a legal check).
