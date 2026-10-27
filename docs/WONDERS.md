# Wonders: what people build when they can build anything

Draft, 27 October 2026. A companion to *Megastructures: the awe ladder* in [DESIGN.md](DESIGN.md). The ladder is engineering: elevators, cylinders and rings that do a job. This is the next layer: places built because someone dreamed of them.

Owner's brief: *I believe we really will speed-run all possible futures. In a post-scarcity future people will be less concerned about absolute efficiency and will want to see their favourite science fiction come to life. Humans won't want to live in pressurised cubes and tori long term. People will want sky castles and cathedrals, open spaces in huge structures. We need these crazy dreams in the game. It doesn't have to make full sense: many places people live now aren't sensible, but they make sense to those who call them home.*

## The principle

- **Wonder over efficiency.** When energy, materials and labour are cheap and minds can design anything, the scarce thing is meaning. People build big, beautiful, odd places because they can, because they always wanted to, and because the Feed is watching.
- **Every wonder has a reason only its people need.** A monastery in a lava tube makes sense to monks. A city on rails on Mercury makes sense to people who love sunrises. Write the reason, not the justification.
- **Plausible enough, then bend it.** Each entry below starts from real physics or a real proposal, then says where we bend it for fun. Record the bend in [RESEARCH.md](RESEARCH.md) when a wonder enters the game, as with everything else.
- **Built by people and minds together.** Machines and minds do the heavy lifting in a few years; people bring the wanting. Many wonders are unfinished, half-funded, or arguing about their own design. That is part of the charm.
- **Gravity, light and air.** Gravity, light and air are the three things every wonder must answer: where does down come from, where does the light come from, what holds the air in? Answering them differently is what makes each place feel different.

## How wonders appear in the game

Each wonder takes one or more of these forms, reusing systems that already exist:

| Form | What it is | Existing system |
|---|---|---|
| **Port** | Dock, trade, take jobs | `places.json` with a station or `foot_of` |
| **Set piece** | Seen in the sky from a nearby port or the transit view | `set_pieces.gd` |
| **Project** | Built in stages from goods the player and NPCs deliver | `projects.json` |
| **Destination** | Somewhere clients want to go: Feed crews, pilgrims, tourists, Witnesses, Firsts | contracts, passengers |
| **Rumour** | A dream not yet built: news, chatter, a backer looking for haulers | `news.json`, chatter |

Most wonders should start as rumours, become projects, and end as ports or set pieces, so the system visibly fills up as the campaign goes on.

---

## 1. Sky worlds: castles in the air

### Cloud cities of Venus
- **Real basis:** About 50 km above Venus the pressure is near one bar and the temperature near Earth's. Breathable air is a lifting gas in Venus's CO2, so a habitat full of air floats. NASA's HAVOC study (2014) sketched crewed airships there and a floating cloud city as the long-term goal ([coverage](https://www.blimpinfo.com/airships/nasa-study-proposes-airships-cloud-cities-for-venus-exploration/), [Vice](https://www.vice.com/en/article/please-build-a-cloud-city-over-venus)). Gravity is 0.9 g: the most Earth-like anywhere.
- **The dream:** Sky castles for real. Towers and gardens hanging under transparent envelopes kilometres across, sailing round the planet every few days on the super-rotating winds, sunrise every 50 hours, sulphuric clouds below like an endless white sea. Walkways between envelopes; a cathedral whose nave is the gas bag.
- **Bend:** Acid-proof envelopes and cheap ascent vehicles are taken as solved.
- **In game:** Opens Venus as a region (tier 2–3). Port: *Aphrodite's Rest* or similar. Exports: collectibles, "Venus light" art, sulphur chemicals. Imports: everything solid. Feed destination: the first wedding over Venus.

### Titan's sky towns and human flight
- **Real basis:** Titan has a thicker atmosphere than Earth (about 1.5 bar) and gravity of 0.14 g, so a person with strapped-on wings can fly under their own power. No pressure suit needed, only warmth and a mask.
- **The dream:** Towns hung from cliffs and balloons over the methane seas, where everyone flies. Wing-makers are the best-paid artisans. Annual races across Kraken Mare. Orange sky, Saturn invisible behind the haze, a sunset that lasts for days.
- **Bend:** Heat is the real problem (-180 °C); we let insulation and fusion power make it simple.
- **In game:** Huygens Port gains a foot-of town (*Wingfall*) and sells flights to Feed crews. Imports: handmade wings, delicacies. A "First" contract: fly across Ligeia Mare.

## 2. Under the rock: cathedrals of stone

### The lava-tube cathedrals of the Moon
- **Real basis:** The Marius Hills pit is a skylight 60–70 m wide and 80–90 m deep into a lava tube that gravity data suggest could hold a city ([JAXA](https://www.isas.jaxa.jp/e/forefront/2010/haruyama/02.shtml), [ESA](https://www.esa.int/ESA_Multimedia/Images/2020/10/Skylight_on_the_Moon)). The Mare Ingenii skylight is wider still. Rock overhead stops radiation and micrometeorites, and the temperature inside is steady.
- **The dream:** Seal the tube, fill it with air, and you have a natural nave hundreds of metres wide and kilometres long. In one-sixth gravity, columns can be slender and vaults impossibly high. The skylight becomes a rose window with Earth framed in it. Monasteries, concert halls, and the quietest place in the Earth–Moon system.
- **Bend:** Lunar tubes may be much bigger than Earth's (low gravity lets them stay open); we take the biggest estimates.
- **In game:** Tier 1, close to home. Port at the foot of the Luna Line or a new foot-of at Marius Hills: *The Nave*. Exports: handmade goods, music, collectibles. Wants: ceramic feed, glass, gene stock for its gardens. Pilgrims as passengers.

### The spin cathedral in a hollowed rock
- **Real basis:** A rotating habitat inside a hollowed asteroid (see RESEARCH.md §3 and Kalpana One). Along the spin axis there is no gravity.
- **The dream:** Hollow a rock into a single vast room and spin it. The floor is a curved landscape, and the axis is a column of open air where people fly, swim through floating water globes, and hang lanterns. Build it like a Gothic cathedral turned inside out: flying buttresses holding the rock, stained-glass light pipes from mirrors outside.
- **In game:** The player's own base can aim for this: the Extension's centrepiece. Others exist in the Belt as ports for faiths, artists and families.

### Callisto's ice halls
- **Real basis:** Callisto sits outside Jupiter's worst radiation, which is why NASA's HOPE study picked it for a crewed base. Its crust is ice and rock.
- **The dream:** Halls carved in ancient ice lit from within, glowing blue, with Jupiter hanging huge in the window. Ice sculpture as a whole economy.
- **In game:** Valhalla Station gains a town on the surface, *Blue Hall*. Exports: ice art (collectibles).

## 3. Roofs over landscapes: the open sky indoors

### Crater domes and tented towns
- **Real basis:** Paraterraforming: roof a crater or valley instead of terraforming a planet. Small domes join into larger ones, and may one day become a "worldhouse" roof ([Taylor, JBIS](https://bis-space.com/shop/product/the-mars-atmosphere-problem-paraterraforming-the-worldhouse-solution/); a 2026 arXiv study favours regional paraterraforming as the nearer-term route, [arXiv](https://arxiv.org/pdf/2603.00402)).
- **The dream:** Forests in craters. On the Moon, trees grow tall and spindly in low gravity: imagine a redwood forest 200 m high under a glass sky, with Earth rising over the rim. Tent towns: tension membranes held up by air pressure, not frames.
- **In game:** Many small ports and set pieces. Tharsis Domes and Jezero already start this on Mars.

### The Long Hall: a roof over Valles Marineris
- **Real basis:** Valles Marineris is 4,000 km long and up to 7 km deep. Roofing a short section between canyon walls is the same idea as a crater dome, scaled up. (No serious study covers it; this is our dream.)
- **The dream:** A transparent roof over a stretch of Coprates Chasma, the walls kilometres high on either side, waterfalls down the cliffs, a river along the floor, mist in the mornings. The biggest room ever built.
- **In game:** A Mars megaproject (tier 3), built in segments like the Selene Ring. Huge demand for ceramic feed, carbon fibre and robotics. A port when the first segment holds air.

### Glass-floored wheels
- **The dream:** A spin habitat whose floor is partly window: stand on the rim and look down past your feet at the stars wheeling by. A bad idea for radiation, a wonderful idea for a honeymoon.
- **In game:** A luxury hotel set piece near Kibo Ring. Feed destination.

### Transparent domes and glass tube-ways
- **Real basis:** Transparent ceramics (aluminium oxynitride, sapphire, spinel) are already stronger than glass. In the 2060s they are cheap (DESIGN.md: materials science is largely solved), so "transparent aluminium" is ordinary building stock.
- **The dream:** Domes you can't see the frame of. Glass tubes linking domes, stations and towns, with trams and walkways inside, so you cross a crater floor or a gap between modules with the stars all round you. Whole streets under glass. The retro-future of the 1950s comics, finally built.
- **Bend:** Radiation shielding through clear walls is the honest problem. We let thick ceramic, water layers and magnetic shields handle it, and let people go below to sleep.
- **In game:** The default look of new towns from the cap's-off era, and a strong demand for ceramic and glass feed everywhere.

## 4. Air without walls: flying worlds

### The Long Breath (a bubble of air in space)
- **Real basis:** Dani Eder's "bubbleworld" (1995): a huge shell held up by the air inside it ([yarchive](https://www.yarchive.net/space/exotic/bubbleworld.html)). Karl Schroeder's *Virga* novels imagine a fullerene balloon thousands of kilometres across, with artificial suns and spinning wooden town wheels ([Kirkus](https://www.kirkusreviews.com/book-reviews/karl-schroeder/sun-of-suns/)).
- **The dream:** Start small: a transparent sphere a few kilometres across at a Lagrange point, filled with air, no spin, no down. People fly with wings, sleep in hammocks tethered to floating gardens, swim through drifting lakes. A lamp at the centre for a sun. A city of birds.
- **Bend:** Even a few kilometres of air is a lot of gas, and the shell must stop air leaking and rocks getting in. We call it solved with ceramic and graphene film.
- **In game:** Tier 2–3 project near L4 or L5. A Feed destination with its own sports. Exports: collectibles, handmade wings. A perfect "First" generator: first person to fly round it, first child born there.

### Ring cities with open sky (the Bishop rim)
- **Real basis:** A Bishop ring is a spinning ring 1,000 km across with walls high enough to hold an atmosphere with no roof. Far beyond the 2060s at full size.
- **The dream:** A small version: a ring tens of kilometres across with high walls and a roof of air, open to the stars at the top. The sky is real.
- **Bend:** At small sizes the walls must be absurdly high or the air thin; we let a transparent "lid" do it and call the walls a style choice.
- **In game:** A rumour and Commons dream at first; a late-game project.

## 5. Swarms and stacks: a crowd of cylinders

### The Ceres megasatellite
- **Real basis:** Pekka Janhunen's proposal: thousands of spinning cylinders (about 10 km long, 1 km radius, tens of thousands of people each) held in a disk-shaped frame orbiting Ceres, using Ceres' nitrogen for air ([electric-sailing.fi](https://electric-sailing.fi/ceres), [Space.com](https://www.space.com/megasatellite-colony-ceres-oneill-cylinder)).
- **The dream:** Not one habitat but a city of them, each cylinder a different culture: one a Venetian canal town, one a pine forest, one a desert monastery, one a nightclub that never closes. Commute between them by tram along the frame.
- **In game:** The Concord Pair is the first two. The megasatellite grows behind it across the campaign, one cylinder per project, each commissioned by a different group (see *The cap's off* in DESIGN.md).

## 6. Moving cities

### Terminator, the city on rails (Mercury)
- **Real basis:** Kim Stanley Robinson's *2312*: a city on Mercury riding tracks round the planet, staying just ahead of the sunrise, driven by the rails' own expansion in the heat ([summary](https://en.wikipedia.org/wiki/2312_(novel))). Mercury's slow rotation means the day–night line moves at walking pace.
- **The dream:** Built exactly as the book imagined, because someone loved the book. Every morning the bravest walk out to the Dawn Wall to see the Sun rise.
- **In game:** Opens Mercury (tier 3). Exports: metals, solar power, collectibles. A port that moves round the body.

### Cycler liners
- **Real basis:** Aldrin cyclers loop between Earth and Mars forever (already planned in the awe ladder).
- **The dream:** Make them ocean liners: ballrooms, promenade decks, a six-month crossing as a holiday. Catch one, drop off cargo, buy dinner.

## 7. Ice and ocean worlds

### Hanging towns under Europa's ice
- **Real basis:** Europa has a liquid ocean under kilometres of ice; the surface is drenched in Jupiter's radiation, the ocean is shielded.
- **The dream:** Towns hanging upside down from the underside of the ice like chandeliers, lit windows reflected in black water, submarines for trams. Divers, scientists, and those who simply want to be very far away.
- **Bend:** Drilling through 10–30 km of ice is taken as done.
- **In game:** Late game; a dream and a news thread first (with a strong "don't contaminate the ocean" argument among minds and people).

### The geyser spa at Enceladus
- **Dream:** Hot baths warmed by the plumes' source, a viewing gallery under the tiger stripes. Plume Watch's scientists hate it; everyone else loves it.

## 8. Towers, tethers and halfway houses

- **Climber hotels:** a hotel halfway up the Pavonis Line, where gravity is a third of Mars's own and the planet curves away below.
- **Skyhook gardens:** hanging gardens on the counterweight of a skyhook, swinging through space.
- **Stickney amphitheatre:** Phobos's great crater roofed as an open-air theatre with Mars filling the sky.

## 9. Working giants: hammerheads, tugs and pushers

The frontier's industry has its own grandeur. These are the shapes that make the space between the wonders look busy.

### Hammerhead stations
- **Real basis:** Putting the people far from the reactor and the radiators is good engineering: a long spine with a big head at one end, like *Discovery* in *2001* or the long-haul ships of *The Expanse*.
- **The dream:** Stations built the same way: a habitat "head" (often a spinning drum or ring) at one end of a truss kilometres long, docks and tanks along the spine, a fusion plant and radiator fins at the far end. Big, purposeful, instantly readable from far off.
- **In game:** A new station silhouette for working ports and yards (fuel depots, smelters, ice terminals), alongside wheels, tori and drums.

### Ice tugs and pushers
- **Real basis:** Water is the frontier's most-used resource (air, propellant, shielding, farms). Moving whole blocks of ice from Saturn's rings, the Belt or comets toward the inner system is an old idea. Pusher craft use fusion, mass drivers that throw pieces of the ice itself as reaction mass, or slow solar heating.
- **The dream:** Tugs the size of a town hauling icebergs bigger than mountains, on journeys of years. Pushers bolted to the back of an ice moonlet, plumes of steam going out the far side. Whole crews who live on the berg. An iceberg arriving at Mars is a public holiday.
- **In game:**
  - **Traffic:** a new NPC fleet of ice tugs and pushers on slow, long routes (the Belt and Saturn to Mars and the Earth–Moon system), each towing a visible ice block.
  - **Events:** an iceberg's arrival drops water ice prices for a while; a berg off course is a hazard and a rescue.
  - **Contracts:** carry supplies out to a berg crew in transit.
  - **Set piece:** a berg being parked in orbit and quarried.

### Also in this family
- **Mass drivers:** rails on the Moon and small rocks throwing payloads at the sky every few minutes; a line of glints you can see from orbit.
- **Ore trains:** strings of containers on a single tether, pulled between rocks.
- **Mirror farms and radiator fields:** square kilometres of mirror and fin, glittering as you pass.

## 10. Follies and monuments

The things nobody needs, and everyone remembers:
- **A second moonrise:** a mirror in orbit that a town on Earth paid for, so it rises over their hills every night. (Astronomers object.)
- **The Long Clock on the Moon:** a clock built to run for ten thousand years, ticking once a lunar day.
- **Sculpture in comet ice and asteroid stone:** a face carved on a rock that passes Earth every few years.
- **A cathedral organ played by the solar wind** at a Lagrange point, its pipes kilometres long.
- **A replica of a fictional place:** some fan collective will hollow a rock and build their favourite fantasy city inside it, exactly to the books. The game should have several, under made-up names.
- **Memorial statites:** sails held still by sunlight, carrying names.

## 11. What the minds build

Minds build for themselves too, and it doesn't look like ours:
- **Cold cathedrals:** computing halls in the outer system's cold (Landauer Deep is one), where thought is cheap. Vast, dim, and very quiet.
- **Gardens no one walks:** landscapes designed to be modelled, not visited: a forest grown on a rock simply to see what the forest does.
- **Shared rooms:** some minds build human-scale spaces inside their halls because they like company, and invite people to stay.

## 12. Small dreams: how most people live

Not every wonder is huge. The frontier is mostly homesteads:
- **Hobbit holes in regolith:** round doors, earth-sheltered rooms, a garden under a little dome.
- **Tumbleweed homesteads:** a family's inflatable sphere on a small rock, everything they own inside.
- **Treehouse towns:** in a low-gravity dome, houses built in the branches.
- **Canal streets in a cylinder:** a Venetian quarter in a spinning drum, because someone's grandmother was from Venice.

These belong in the sky full of homesteads in *The cap's off*: beacons, chatter, small markets, and contracts.

---

## Shortlist: what to add first

Chosen for reach (close to where the player already flies), variety (gravity, light and air answered differently each time), and economy (each wants the new goods):

1. **The Nave** (lunar lava-tube cathedral, Marius Hills). Tier 1, close to home, cheap to build as a foot-of town and an underground set piece. Wants ceramic feed and gene stock; exports handmade goods.
2. **The Long Breath** (air bubble at L5, near the Kernel). Tier 2 project, then a port. A showcase for flying people and for Firsts and the Feed.
3. **Cloud city over Venus.** Opens Venus: the most Earth-like gravity and a true sky castle. Bigger work: a new body, region and market.
4. **The Long Hall** (roof over Coprates Chasma). Mars megaproject in segments, like the Selene Ring.
5. **The Ceres megasatellite** grows behind the Concord Pair, one group's cylinder at a time.
6. **Ice tugs and pushers** as an NPC fleet with visible icebergs, plus berg arrivals as market events.
7. **Hammerhead stations** as a new station shape for working ports.
8. **Terminator on Mercury.** Late game, a moving port.

And from the start: news and chatter about all the others as rumours, so the system is always talking about the next impossible thing.
