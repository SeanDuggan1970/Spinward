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

## 7. Elevator design references (for the look)

- **Climber:** opposed wheel pairs pinching the tether (friction drive, no capstan). Five pairs and ten motors lift a 20 t climber with 9 t of payload. Climbing speeds of 200 to 300 km/h; climbers' Coriolis-driven oscillations of the tether must be damped, or offset by other climbers ([ISEC 2023 study](https://www.isec.org/2023-study); [ISEC climber slides](https://www.isec.org/s/isec-slides-2022-bartoszek-climbers.pdf); [JBIS tether paper](https://www.isec.org/s/JBIS-2-Building-the-Space-Elevator-Tether.pdf)).
- **Ribbon:** Edwards' wide, thin ribbon survives micrometeoroids better than a cable. It tapers, widest at synchronous height: one design runs 0.31 m at the ground to 1.55 m at GEO, 10 µm thick ([Wikipedia](https://en.wikipedia.org/wiki/Space_elevator)).
- **Power:** a laser on the ground beams up to a photocell array under the climber (Edwards).
- **Anchor and counterweight:**
  - Obayashi's 2050 concept has a vertical modular station at GEO with solar power beside it, and a counterweight beyond that doubles as a launch gate for deep space ([Obayashi](https://www.obayashi.co.jp/en/special/space_elevator.html)).
  - ISEC's apex anchor carries reels, thrusters and command modules ([ISEC lexicon](https://isec.org/lexicon)).
  - A captured asteroid as counterweight ([Dezeen](https://www.dezeen.com/2024/01/09/jordan-william-hughes-space-elevator/amp/)).
- **Fiction:** in Red Mars, cars go up and down together; in Clarke's *The Fountains of Paradise*, the elevator rises from a mountain temple ([Space elevators in fiction](https://en.wikipedia.org/wiki/Space_elevators_in_fiction)).

## 8. Comets and the famous small bodies

- **Halley (1P)**: next perihelion 28 July 2061, at about 0.59 AU; next after that, March 2134. Its orbit is retrograde (inclination 162 degrees). The nucleus is 15 x 8 x 8 km, mass about 2.2e14 kg and very dark (albedo 0.04). Giotto passed 596 km from the nucleus at 68 km/s in 1986 and lost its camera to dust; the Vega probes went first and guided it ([ESA Giotto](https://www.esa.int/Science_Exploration/Space_Science/Giotto_overview)). Hydrogen cyanide was found in its coma.
- **67P/Churyumov-Gerasimenko**: a 6.4-year orbit out to 5.7 AU. Rosetta orbited it from 2014 to 2016, often at 10 to 30 km, and backed off to a few hundred km near perihelion when dust confused its star trackers. Philae's harpoons failed to fire and it bounced from Agilkia. Mass 1.0e13 kg.
- **Activity**: water ice sublimates strongly inside about 3 AU; water production near perihelion was about 7e29 molecules/s for Halley in 1986 and about 1e28 for 67P in 2015.
- **Bennu**: OSIRIS-REx sampled it in October 2020; the sampler sank into a surface that behaved like a ball pit. GM 4.892 m^3/s^2, mean radius 245 m. It ejects small particles now and then.
- **Ryugu**: Hayabusa2 made an artificial crater in April 2019 and returned samples rich in hydrated clays. Mass about 4.5e11 kg, mean radius 448 m.
- **Didymos and Dimorphos**: DART hit Dimorphos on 26 September 2022 and shortened its 11 h 55 min orbit by about 33 minutes.

**Bent for play** (`sim/comet.gd`): activity follows sunlight (1/r^2) with a hard onset at 3 AU, where real comets vary a great deal, outburst and switch jets on with the local dawn. The coma is a sphere of fixed radius for its activity. The orbit ignores the push of outgassing (non-gravitational forces), which moves Halley's perihelion date by a few days per orbit; the baked orbit is fitted to Horizons in 2061 and 2063, so the error over the decade is small.

## 9. The Nave: a lava tube at Marius Hills

- **The skylight:** the Marius Hills Hole, found by Kaguya in 2009 and imaged by LRO: nearly circular, 60–70 m across, 80–90 m deep, at about 14.1 N, 303.2 E ([JAXA](https://www.isas.jaxa.jp/e/forefront/2010/haruyama/02.shtml)). Beam theory gives the tube a maximum width of about 370 m, and GRAIL gravity data suggest tubes in the region could be kilometres wide; ESA counts hundreds of such pits ([ESA](https://www.esa.int/ESA_Multimedia/Images/2020/10/Skylight_on_the_Moon)). The game takes 340 m.
- **Sunlight down the shaft:** a 65 m opening over an 85 m drop admits light from within atan(65/85), about 37 degrees, of overhead. At 14 N the noon Sun passes 14 degrees from overhead, and is within 37 degrees for an hour angle of about ±35 degrees: some 5.7 Earth days of each 29.5-day lunar day.
- **Earth's place:** from 14.1 N, 56.8 W, the sub-Earth point is 57.9 degrees away, so Earth stands about 32 degrees above the eastern horizon, too low ever to be seen up the shaft.
- **The hop from Line Foot** (0 N, 0 E): central angle 57.9 degrees, 1,755 km. The minimum-energy ballistic launch for central angle θ on a sphere of radius R and surface gravity g has speed v² = gR · 2 sin(θ/2) / (1 + sin(θ/2)) and flight-path angle (π − θ)/4. For the Moon that is 1,357 m/s at 30.5 degrees, an apex of 312 km and 31.2 minutes of flight: about 2.7 km/s of engine work for the round of launch and landing, within a lunar lander's reach (Apollo's descent and ascent stages together carried about 4.7 km/s).
- **Simplified:** the lander's burns are drawn along the ends of the ellipse rather than as a gravity turn from the pad; the Moon's pole is the ecliptic pole (the real one is 1.5 degrees off), so Earth wobbles about 5 degrees in the lunar sky instead of 6.7, and the Moon doesn't librate in longitude.

## 10. Venus: a city in the clouds

- **The air** (Venus International Reference Atmosphere): about 1.07 bar and 75 °C at 50 km, 0.53 bar and 27 °C at 55 km, falling to 0.45 bar and about 17 °C at 56 km. The game's city floats at 55 km. The main cloud decks run from about 48 to 70 km, so the city sits inside a thin haze, with brighter cloud above and below.
- **Lift:** breathable air (mean molecular mass about 29) floats in carbon dioxide (44): a cubic metre of air displaces about half its own mass again in CO2, so at 0.53 bar each cubic metre lifts roughly 0.3 kg. A city's envelopes are hundreds of metres across for that reason.
- **Winds:** the cloud tops super-rotate, circling the planet in about four Earth days, retrograde like the planet; the city drifts with them, so a day and a night each last about two Earth days.
- **Getting off:** low Venus orbit needs about 7.3 km/s; with gravity and drag losses from 55 km, about 8 km/s. Hence the glider's fare.
- **What it has and lacks:** carbon and oxygen without limit in the CO2 (96.5%), nitrogen (3.5%), sulphur from the acid clouds; almost no water (about 20 parts per million), so hydrogen is the scarce thing. NASA's HAVOC study (2014) sketched airships and an eventual floating city ([coverage](https://www.blimpinfo.com/airships/nasa-study-proposes-airships-cloud-cities-for-venus-exploration/)).
- **Simplified:** the city drifts at one steady rate at one latitude (real winds vary with latitude and time); the glider's flight is always four hours.

## 11. Icebergs from the Belt

- **Where the ice is:** water ice was found on the surface of 24 Themis in 2010 (Rivkin and Emery; Campins and others), and the Themis family is the parent of several main-belt comets: ice survives under a thin dust crust in the outer Belt. Ceres holds a great deal more, but it sits at the bottom of a gravity well.
- **Pushing it:** a pusher that melts the berg's own ice and throws it as reaction mass (a mass driver or a fusion-heated steam rocket) needs no propellant from home. With an exhaust speed of about 5 km/s, moving a berg by 5 km/s costs about 63% of its mass (the rocket equation); the berg pays for its own trip, and what arrives is about a third of what left. The game's berg masses are what arrives.
- **Size:** water ice weighs about 0.92 t a cubic metre, so a 24,000 t berg is some 30 m across.
- **Time:** low-thrust transfers from the outer Belt to the inner system take years. The game has many bergs in the pipeline at once and shows only arrivals.
- **The Slow Tide's path:** drawn as a coasting transfer ellipse from the Themis family (about 3.1 AU) to Earth's orbit: semi-major axis 2.05 AU, eccentricity 0.51, period 2.94 years, so about a year and a half in. At the game's start (mean anomaly 290 degrees) it is 2.21 AU from the Sun, 208 days from perihelion. A real pushed berg follows a slow powered spiral, not a coast; and this one, once past perihelion, coasts back out rather than being parked, which the game doesn't model yet.

## 12. A roof over a canyon

- **Noctis Labyrinthus:** the maze of fault canyons at the western head of Valles Marineris, around 7 S, 100 W, on the Tharsis bulge. Its canyons are a few kilometres wide and up to several kilometres deep, much narrower than the main chasms (Coprates is about 60–100 km across).
- **Roof tension:** for a long roof spanning a canyon, the membrane tension per metre of length is the pressure difference times the roof's radius of curvature (T = p·R). At half a bar (50 kPa), R of 1 to 2 km gives 50 to 100 MN/m. Carbon fibre working at about 2 GPa needs 2.5 to 5 cm. The roof pushes up and must be anchored; Mars's gravity (0.38 g) holds down only about 2 kN/m² of a 25 cm-thick ceramic-and-fibre roof (about 500 kg/m²), against 50 kN/m² of air.
- **Air:** a hall 10 km × 2 km × 1 km holds about 2×10^10 m³; at half a bar that is about 12 million tonnes of air, nitrogen and argon from Mars's own atmosphere plus oxygen from its water and CO2.
- **Simplified:** the flight view draws the roof flat at the rim; the real one would bulge up between them.

## Open research for later passes

- Readable orbit-planning UI patterns (KSP manoeuvre nodes versus one-click "AI plot course").
- Economy models that avoid runaway inflation: production/consumption sinks versus fixed price bands.
- Real radiation environment (solar particle events, Jupiter's belts) as hazard data.
- Name/trademark check before public release. "Spinward" alone is used by other small games; "Spinward Accord" looked clear in a quick web search (not a legal check).
