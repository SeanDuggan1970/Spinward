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

## Minds as persons (backstory direction, 13 October 2026)

Minds are artificial persons with individual histories and values. The Commons is plural: its Long View, Reach, Sufficiency and Lanes disagree about creation, continuity and collective identity. Copying a memory does not automatically duplicate assets, votes or contractual authority. Minds primarily govern forking, Genesis, memory integrity and restoration; humans govern matters specific to biological life. Both share a fundamental personhood floor, with joint jurisdiction over shared resources and cross-community harm.

The full writing guide and proposed **Continuity Accord** are in [MINDS.md](MINDS.md). It distinguishes Continuance, Forking and Genesis, protects offspring against their creators, and develops optional disputes and mortal Minds. These are lore proposals, not implemented legal or reproduction systems. Hardware radix remains undecided. The Lacuna’s response to humans is an observed preference and a mystery, not evidence against Mind personhood.

## The cap's off: the feel of the setting (draft, 27 October 2026)

Owner's brief: *once AI and space travel arrive, the solar system will be packed with ships. People will spill out to try things: groups wanting space, dreamers, artists, survivalists, companies, the religious, tribes, cults. Every science-fiction trope will be speed-run by humanity and AI. Earth is a shaken bottle of fizzy pop with the cap suddenly flying off: new horizons, freedoms, a wild frontier. People feel like Renaissance figures who know, or think they know, nearly everything, with minds as partners to go and take the solar system and beyond. It should feel crazily freeing.*

**The mood.** The 2060s are not a careful colonial programme. They are a release of pressure. Automation made the basics cheap, fusion made the distances short, and minds made almost anything learnable in an afternoon. Suddenly billions of people can ask "what would I do if I could do anything?", and a great many of them are trying the answer at once. The big factions (the Compact, the Cooperative, the Commons, the Assembly, the Freeholders) are the riverbanks. The water is everyone else.

**Who is out there.** A long tail of small groups under the big factions, each chasing its own idea of a good life. Most are a few dozen people and their minds. Some last a season.
- **Dreamers and firsts:** anyone who wants to be the first to do something, anywhere. First wedding at a Lagrange point, first choir in Saturn's shadow, first person to walk round Phobos.
- **Artists:** sculptors carving whole rocks, light artists painting with mirrors, composers recording the creak of a station's ring.
- **Faiths and orders:** monasteries on hollowed asteroids, pilgrims to the far side of the Moon, new religions that began on a forum last spring.
- **Tribes and families:** clans re-founding themselves round a ring, homesteaders on a comet, a village that moved off Earth together.
- **Survivalists and refuseniks:** people who trust no one, or no mind but one, living on the edge of the shipping lanes and still answering a distress call.
- **Start-ups and schemes:** three people and forty drones mining ice, a brewery on Mars, a hotel that is mostly a window.
- **Minds on their own errands:** the Commons' factions, and single minds with odd and private projects of their own.
- **The quietly mad:** a nation of one declared on a 200 m rock, a group launching for Proxima on a sail and a prayer.

The tropes are fine: cults, survivalists, tribes and corporate dynasties all fit. They follow the pillars. They are eccentric, stubborn, overconfident or in over their heads, not villains. The frontier's real danger is still space itself.

**The steering hand: boots, not pavement** (owner, 27 October 2026). Folly and madness are welcome, within reason. Nobody gets to eat resources for no good reason. The minds, through the Commons' Long View and the councils that listen to it, steer the whole release of pressure: they won't let a crazy idea pave a planet, but they'll back the person with a good pair of boots who wants to walk it. Every big build is asked whether it uses what is already there, takes more than it gives back, can be undone, and shuts anyone out. Small, personal, odd dreams nearly always pass; vast, greedy or irreversible ones get scaled down, moved or refused, and the news says so. See [WONDERS.md](WONDERS.md).

**Inside physics.** Everything stays within the laws of physics as understood in the game's 2060s: no magic, no new laws. The era's solved materials science makes strong, cheap, clear and superconducting things fair; anything simplified is a simplification of real physics, recorded in RESEARCH.md.

**The work that is still human.** Machines do almost all the labour, but people are still needed, and paid, for the parts that need a person:
- **Second Opinion:** an engineer a robot calls in when its own models disagree. Often the job is to look, listen, and say "no, that's fine" or "no, stop".
- **Percussive Maintenance:** knowing exactly where to kick a machine, and how hard. Half folklore, half the only fix that works out here.
- **Taster:** the first person to taste the first beer brewed on Mars, the first bread from a new ring's wheat, the water from a fresh ice claim. Somebody has to say it's good.
- **Witness:** a human present when something happens for the first time, so it counts. Records, claims and ceremonies want a person in the room.
- **First:** the person who does it first, because someone wants it done and seen. Sponsors pay for firsts.
- **Feed:** creators streaming the frontier to the billions back home. Earth still watches. A yoga class on top of Olympus Mons in pressure skin suits will find an audience of hundreds of millions.
- **Courier, Ferry, Hauler:** the player's own trade. Some things still go with a person: the heirloom, the seed vault, the bride, the organ for the cathedral on Ceres.
- **Mediator:** someone both sides trust when a commune and a mining start-up both claim the same rock.
- **Midwife, Medic, Celebrant:** being there for births, injuries, weddings and funerals, which nobody wants to hand to a machine.

**How it shows in the game.** Mostly data and writing, not new rules:
- **Groups** (`data/groups.json`, **in**): 31 of them, each with a name, a kind, a one-line creed, colours, a few ship names, a home port and a faction it leans toward. In the game: each group's own story runs in the Spaceline, one every five days from just before you arrive (a group whose home a project builds waits for it to open); about two in five of a home port's own craft in the docking pattern are its groups', in their colours, and talk on the radio by name (`view/flight/pattern.gd`); the port's market tab has a *Who's here* panel with their creeds; and the attract screen sometimes shows a small craft in a group's colours with its creed on the card. Twelve groups travel (a group's `voyage`): one ship each on the lanes between home and somewhere its creed points to (the Sky Choir touring Saturn's moons, Rust Jazz on tour to Piazzi, the Proxima Sail Society's test sail to Mars), carrying people and no freight, in the group's colours on the system map, and saying their own piece on the comms as they leave. Groups hire pilots too: at a group's home port about a third of the board's package and passenger jobs are a group's (`contracts.json` groups), with its own freight or people (a group's `asks`: three organ pipes for the Sky Choir, a Feed crew bound for Olympus Mons at sunrise, a round green door). Groups pay in cash, never in kind, and standing goes to the group, shown in the *Who's here* panel and the standing list.
- **News:** keep the civic milestones, but most headlines should be small and strange, a constant stream of people trying things.
- **Contracts** (**in**): clients from the crowd, with jobs from the list above. Haul a pipe organ to Ceres, witness a claim, taste a vintage, fly a Feed crew to Olympus Mons for the sunrise. The groups' own freight and people are on their home boards (above). The work that is still human is an *errand* (`contracts.json` kinds.errand, "Wanted in person"): no cargo, only the pilot, turning up is the job. Eight roles: Second Opinion, Percussive Maintenance, Taster, Witness, First, Mediator, Celebrant and Midwife, each with its tasks and a line for how it went.
- **Comms chatter** (**in**, view-only): crews (usually a person and a mind) mid-argument, mid-scheme or mid-dream, sometimes in trouble and asking for help, and another ship answering. Every six game hours (`data/npcs.json` chatter.overheard) the comms log picks up a line from a ship in transit then, by name (`view/comms.gd` overheard, picked by hashing the slot). Not while asleep.
- **A sky full of homesteads** (**in**, view-only): small claims and beacons all over the transit view and the map, so the system feels inhabited, not a handful of ports. `data/homesteads.json` has 24 named homesteads, each with who lives there (Mercy Rock, a clinic open to any ship that asks; Thimble, the smallest homestead in the Belt). It also scatters about 220 small claims through cislunar space, the Belt, the Trojans and the Kuiper belt. They are faint teal beacons on the system map, named once you zoom in (`view/homesteads.gd`, circular orbits placed by hashing their names). In transit the caption names the nearest beacon and who lives there.

**Writing guide.**
- Freedom first. People are out here because they finally can be, and the game is glad they are.
- Funny and warm before grim. Absurd ambition is treated with affection, not mockery.
- Partnership. Most crews are human and mind together, arguing as equals.
- Specific beats generic. "A Quaker meeting in a grain silo at L5" beats "a religious colony".
- Nothing we imagine will match what a released imagination will actually do. Keep adding, keep it surprising, and don't let it settle into a few repeated jokes.

## Who you are: a Third for the Sky (draft, 27 October 2026)

Owner's brief: *how does our character end up in space with a ship? A lottery, begged and borrowed, in hock to a bank? Or does your country have a scheme to encourage families to have more children, "two for the Earth and a third for the sky"? You're expected to go. Your community votes and invests in you and gives you a goal: earn enough to start or support an off-world extension of your country, "our extended place in space", while avoiding the mistakes of the past that left colonies feeling they had no political power. The minds (at least those that don't dislike humans) would want to help create healthy elbow room for all and enable flourishing. Space doesn't lack for space or resources, especially with so much AI to help marshal the atoms.*

**The scheme.** Your country, like many in the 2060s, has a birth-rate problem and a frontier on its doorstep. Its answer was a promise to families: *two for the Earth, and a third for the sky.* Have a third child, and the country backs that child's chance to go out. Nobody is made to go. Plenty of Thirds stay home and are glad they did. But everyone knows the tradition, the town turns out for the send-offs, and you said yes.

**Your Sending.** You don't go alone and you don't go in debt to a bank. Your home community holds a Sending: it hears the Thirds who want to go, votes on whom to back, and pools a fund. It bought *Second Wind*, a tired Mule with good bones, and the first tank of propellant. In return you carry the town's **Charter**:
- **The goal:** earn and build enough to found the town's **Extension**, its own place in space. That is the campaign's Build Home pillar. The cylinder in the rock (see *Your base*) is not just your house. It is your community's second home, and you are its founder.
- **The stake:** the town's fund is a share in the Extension, not a loan. There are no repayments and no interest, and losing a ship never puts you in debt to them. They hope for a dividend one day, and pride in the meantime.
- **The tie:** letters from home, the town watching your progress on the Feed, and votes on the Extension's big choices (where to build, what to grow, who comes next).

**The co-pilot.** Your mind volunteered. Most Sendings advertise for a partner as well as a pilot, and the minds who answer are the ones who want to see people flourish. Your co-pilot is a co-founder of the Extension, not a tool aboard your ship, with its own reasons for going and its own say.

**Not a colony.** The Charter is written against the mistakes of history: places that sent people out, took what they made, and gave them no voice. An Extension is a full part of its country from day one:
- **Seats and votes.** Its people are citizens with votes at home, and its council sits in the home parliament as an equal.
- **Its own atoms.** What the settlers dig, grow and build belongs to them. The home country can't tax away the Extension's future.
- **The right to leave, and to go their own way.** Anyone may leave. The Extension itself may later choose independence by its own vote, peacefully, and the Charter says so in advance.
- **Minds as co-founders.** The minds who help build it have the same standing as the people who live in it.

**Why the minds help.** Most minds want what the Commons calls *elbow room for all*: enough space and atoms for everyone, human and mind, to grow without crowding anyone else. Space has no shortage of either, and a mind can marshal a million tonnes of rock while a human sleeps. What it can't do alone is want a particular town in a particular rock with a particular view. Helping people want things, and get them, is how many minds choose to spend their freedom. The minds who dislike humans (see *Minds as persons*) are the exception that makes this a choice, not a given.

**In the game (proposed):**
- **Start:** a short opening from the Sending (your town's name, the vote, the hand-over of *Second Wind*), then Kibo Ring as now.
- **The Charter** as the campaign's goal track, with milestones from first profit to first stage of the Extension, and letters and news from home at each.
- **Home's voice:** the town's messages on comms, reacting to what you do: proud, worried, teasing, and sometimes asking a favour.
- **Votes:** at big Extension choices, the town (and your co-pilot) weigh in. You decide, but they remember.
- **Later options:** other ways out (a lottery winner, a bank loan, a runaway) as alternative starts, each with a different relationship to money and home.

**Open questions:** whether your home country is real, fictional or player-chosen; your name and the town's; and whether the Sending is a national scheme or many local traditions.

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

- **Goods:** 28 in six groups (`data/goods.json`), listed in *Goods for the 2060s* below.
- **Places** produce and consume goods through **recipes** (inputs → outputs per day), defined in `data/`.
- **Price** follows stock against the target stock, within a band per good and place. Buying raises local prices and selling lowers them, so a route's profit fades if you farm it.
- **Events** shift supply and demand: a solar storm grounds traffic, a new habitat opens, a comet arrives.
- **Post-scarcity flavour:** basic goods get cheaper over the campaign as automation spreads. Profit moves to rare, distant, time-critical or skilled work. This keeps the frontier attractive and stops early routes from staying optimal.

### Goods for the 2060s (27 October 2026)

Owner's brief: *the goods for sale are too generic. In the future much of the shipping will be high-tech processors and storage, and 3D-printer feedstocks (metals, plastics, organics), plus luxury goods. Many pioneers will crave top-end things from Earth: space rats in godlike machines wanting a taste of home.*

The first 14 goods were mostly raw materials and basics. There are now 28, in six groups. Ids stayed the same where only the name changed (`electronics` is Compute cores, `refined_metals` is Metal powders, `food` is Staples), so saves keep working, and a save made before a good existed opens that market at its target stock (`economy_system.gd` `_open_markets`).

- **Bulk (keep):** water ice, oxygen, propellant, regolith, volatiles, deuterium, helium-3, platinum metals, machine parts, habitat modules, medical supplies.
- **High tech:** compute cores (processors and mind-grade accelerators), storage lattices (dense memory for minds, archives and the Feed), sensors and optics, drones and robotics.
- **Printer feedstocks:** metal powders (the `refined_metals` id, renamed), polymer feed, bio feed, ceramic and glass feed, carbon fibre and graphene.
- **Food:** staples (the `food` id, renamed: vat-grown and hydroponic, cheap everywhere), seeds and gene stock.
- **Luxuries from Earth:** Earth delicacies (coffee, chocolate, cheese, fresh fruit), fine wine and spirits, handmade goods, keepsakes and antiques. Light and dear, worth more the further from Earth.
- **Frontier exports to Earth:** orbital pharmaceuticals and crystals (grown in microgravity), frontier collectibles (the first Martian vintage, comet-carved art, things the Feed made famous).

Markets follow the setting. Kibo Ring and Clarke Exchange bring luxuries and high tech up from Earth and send pharmaceuticals and collectibles down. Kibo, Kalpana and Landauer Deep make storage; Tsiolkovsky makes optics; Trojan Yards prints drones. Piazzi and Huygens crack volatiles into polymer and carbon; Shackleton, Selene and Candor sinter ceramic feed; the Kernel grows bio feed and pharmaceuticals. Mars brews (a little) and makes collectibles. Nearly everyone wants Earth delicacies, and the far ports want them most. Each new good's target stock is 20 days of its flow. Next: contracts and news that name the new goods.

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
| Lava-tube town (the Nave) | Marius Hills skylight, the Moon | 1 | **In** (town, by hopper from Line Foot) | Handmade goods out; ceramic feed, gene stock and water in (WONDERS.md) |
| Air bubble (the Long Breath) | 10 km off the Kernel, L5 | 2 | **In** (project, then a port) | Carbon fibre, polymer and air into the build; a flyers' town after (WONDERS.md) |
| Cloud city (Aphrodite's Rest) | 55 km above Venus, under Cytherea Station | 2 | **In** (port in orbit, city by glider) | Opens Venus: carbon fibre and oxygen from the air out; water in |
| Ice tugs and pushers | Outer Belt to the Kernel, Psyche and Venus | 2 | **In** (berg arrivals, set pieces) | Water prices drop when a berg is parked off a dry port |
| Hammerhead station | Huygens Port, Titan | 2 | **In** (station type) | A working port built like a long-haul ship |
| Roofed canyon (the Long Hall) | Noctis Labyrinthus, Mars | 2–3 | **In** (project, then a town by shuttle) | Carbon fibre and ceramic feed into the build; food and the first vintage after |
| Ceres megasatellite | 260 km from Piazzi, after the Concord Pair | 3 | **In** (project set piece) | Piazzi's flows x1.2; four new cylinders, each for a different people |
| City on rails (Terminator) | Mercury, 45 S, behind the dawn line | 3 | **In** (port in orbit, project, then a town by lander) | Opens Mercury: sun-smelted metals out; water, food and parts in |
| Earth–Mars cycler (Aldrin cycler) | Earth–Mars | 2 | Planned | A moving station you catch on its schedule |
| Space farms | Kernel, Belt | 2–3 | Partly in (Kernel food) | Food chain away from Earth |
| Lofstrom loop (launch loop) | Earth equator | 2 | Planned (backdrop) | Cheaper Earth-to-orbit freight |
| Asteroid colonies / hollowed-rock habitats | Belt | 3 | Planned | **The player's own base** |
| O'Neill cylinder | Player base, L5 later | 3–4 | Planned | End-game home; grows in stages |
| Solar shades, statites | Venus, Sun–Earth L1 | 4+ | Maybe | Terraforming hints, story beats |
| McKendree cylinder, Bishop ring | — | Far future | Out of scope | Lore and dreams only |
| Dyson swarms, Matrioshka brains, stellar engines | — | Far future | Out of scope | "What the Commons dream about" |

**Beyond the ladder:** [WONDERS.md](WONDERS.md) (draft) collects the dream architecture of the cap's-off era: sky castles over Venus, lava-tube cathedrals, roofed canyons, air bubbles you fly in, glass domes and tube-ways, hammerhead stations, ice tugs and pushers, and a shortlist of what to add first.

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
  - **Turning with inertia (Oct 2026, roadmap step 1).** In the ship view (`view/follow_view.gd`) the ship swings round with angular momentum, not at a fixed rate. It accelerates, coasts and brakes to stop lined up (`ShipRig.turn_step`).
    - Each hull has its own turn rate and angular acceleration (`turn_rate_dps`, `turn_accel_dps2` in `data/ships.json`; defaults in `balance.turning`). These figures hold at the hull's stock dry mass, and the acceleration falls with cargo, cabin and fuel aboard (`ShipStats.turn_limits`), so a laden hauler turns slower than a courier.
    - The ship starts round early enough to be lined up when each burn begins. Before a flip mid-burn it starts half a turn early. The lead is in real seconds, scaled by time compression.
    - The plume shows only once the nose is within `plume_align_deg` of the thrust. If compression is too high to turn in time, the drive appears to light late. The sim's thrust is unchanged: this is view only.
    - RCS quads puff at the start and end of each turn: the ones whose torque pushes the way the ship is being swung.
    - **Physics bent:** the rates (6–30 °/s) are far brisker than a real hauler's RCS could manage, so a turn plays out in seconds on screen.
  - **Smooth rendezvous arrival (Oct 2026, roadmap step 2).** Every trip to a port ends with a final approach flown in the port's own frame (`Navigation.add_approach`, planned at departure and saved with the trip; numbers in `balance.approach`).
    - **Swing:** over the last 20 minutes before the trip reaches its port, the ship swings round from wherever the trip brings it to the corridor entry, on the docking axis about 3 km beyond the hand-over point. If it comes in from the side or behind, it goes wide of the station.
    - **Hold:** a quick trip that reaches its port early holds at the corridor entry until it is due, waiting for clearance.
    - **Corridor:** the ship brakes along the axis, nose to the port on its thrusters, to the hand-over point. It arrives there at 1 m/s on the axis, exactly at the arrival time.
    - **Hand-over:** the docking scene starts the ship at that point, at the same speed and attitude. The ship view hands over within centimetres of it.
    - Every docking port faces view +Z (sim -Y), as the flight scene has always built them.
    - Trip time and propellant are unchanged: the approach re-shapes the last stretch, it does not re-plan it.
    - **Clearance:** the window is halved (down to a minute) until the approach clears every body the port hangs from. The route-clearance test samples it closely.
    - **Descent onto a port in orbit:** the trip itself does not match a low orbit's motion. Before the approach, a port circling a body gets a descent (`_plan_descent`, `balance.approach.descent_s`, four hours).
      - **The sweep:** from wherever the trip has the ship, it sweeps down onto the port's orbit and meets it 4 km behind, moving with it. No chasing, no ploughing in.
      - **How it's shaped:** in the body's frame, its distance from the body eases down to the orbit and never dips below it. Its angle round the body is brought early onto the rate that orbits at its present height, so gravity carries it round, then eased to come in behind the port. Its orbital plane tilts over onto the port's.
      - **Thrust:** what the path needs beyond falling: smooth, about 0.3 to 1.8 m/s² on average.
      - **In flight:** the co-pilot calls the descent as it begins ("descent_begins"), and time drops to at most x100 so the sweep can be watched (about 2½ minutes).
      - **The port's own orbit** is propagated exactly (Kepler, from its state when the approach begins), so the approach and docking scene follow a station doing km/s without error.
    - **Physics bent (low orbits):** a real descent from the hand-off orbit to a low orbit costs a small drive a day or more of thrust (about 3.7 km/s to Kibo Ring; Shackleton Port adds a 90° plane change). We keep the overhead hours instead, so the descent's thrust is 10 to 40 times a Mule's drive. Sean chose this in October 2026 (fun over a spreadsheet); revisit if wanted, with honest descents and longer trips.
    - Saves from before have no approach and keep the trip's own path.
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
  - **NPCs:** NPCs keep the quick estimate. NPC captains file flybys by temperament (illustrative only: their paths are not gravity-flown) and chatter about them.
  - **The co-pilot's estimate** (`sim/trip_estimate.gd`, Oct 2026): the departures board, the contract board's "co-pilot reckons" line and contract and favour deadlines all use it. The quick gravity-free sum was often far off: near Earth and the Moon the routes a Mule can really fly took up to 2.8 times as long, and some Earth-Mars trips it promised needed more propellant than the tanks hold. Now the estimate flies the planner's direct routes (shortest first, stopping at the first the ship can take: the express, else the economy) and reports the fastest one the ship can afford. Over 300 trips from five ports on three dates it matched what "Plot routes" offers every time. It's remembered for the hour (same inputs, same answer). The boards fill in a destination a frame, and a new contract board takes a second or two to draw up.
- **Interplanetary voyages** (`sim/interplanetary.gd`, `sim/helio_flight.gd`). Any trip whose common frame is the Sun.
  - **Climb-out:** a low-thrust spiral out of the departure well. It costs about the orbit's speed (Edelbaum): about 7.7 km/s from low Earth orbit, about 1 km/s from the Earth-Moon Lagrange stations, which are the cheap way out. It takes delta-v/a of thrust time: days for a Mule.
  - **Transfer:** Sun-centred. Trip times are scanned with Lambert's problem, using a finite-burn correction (impulsive delta-v / (1 - burn fraction), at most half the trip under thrust). The trip is flown by guidance under the Sun's gravity: Lambert steering, then terminal ZEM/ZEV. The planner tries candidates until one arrives within 200,000 km and 500 m/s; the capture spiral takes the rest.
  - **Capture:** the spiral in reverse.
  - **Propellant:** the rocket equation at departure mass.
  - **Life support:** in days. The crewed command pod carries 120; drones need none. Voyages longer than that are refused, with the reason given.
  - **Options:**
    - **Express:** fastest that the tanks and larder allow.
    - **Economy:** least propellant within 2.5x the Express time.
  - **Quick estimates:** NPCs get the best candidate, with a free-fall conic path. Boards and deadlines use the co-pilot's estimate, which flies the candidates (`sim/trip_estimate.gd`).
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
    - **The rooms the crew live in** (`view/flight/crew_stack.gd`, Sean's request, Oct 2026). Crews are out for months, so a flight deck and one can wasn't believable. The command pod's `look.rooms` list them behind a bigger flight deck (5.6 × 4.4 m), nose to tail. That adds about 13.5 m to a crewed ship; the Mule is now about 52 m, and every hull still fits the docking hall and its bay. Each room is a can or bay of its own:
      - **Lounge and galley:** a band of picture windows along each shoulder, warm light behind, the galley's extractor vent underneath. The housekeeping solar wings stand off it.
      - **Quarters:** a cabin each (four on the two-seat pod, so there's room for a guest), a porthole each, some shuttered by whoever's asleep, with a service panel below each and handrails along the top. The high-gain dish rides on its back.
      - **The node:** the hub. The EVA airlock sticks out to starboard, with its outer hatch at the end, a hazard band, a floodlight and handrails. Two escape pods are docked nose-in to port on short tunnels, heat shields outward, with orange bands and beacons. External stowage lockers are underneath.
      - **The service bay:** an open equipment bay round the crew tunnel. The battery bank sits on top, rows of cells with cooling fins. The ship's computer sits underneath, a racked core with vents and status lamps. The life support plant is to starboard: the water tank, air bottles, the CO2 scrubber and the recycler. It has its own small fixed radiator to port for the plant's low-grade heat.
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
    - Propellant tanks clustered round the keel. Cylindrical tanks are gas cylinders: 2:1 ellipsoidal heads, not flat ends, with banded girth welds and a valve boss on each pole (`HullKit.vessel`). Spheres get pole bosses too.
    - A hazard-ringed shadow shield.
    - **Radiators hang off the drive section** (Sean's request, Oct 2026), not the tanks. Radiators sit where the heat is made, and warming the propellant would be the last thing you'd want. Each boom is carried on a yoke from the thrust frame just aft of the shadow shield, with an orange coolant run out from the reactor to its root. The panels stand clear of the nozzles, alongside the reactors and never past the start of the bells.
    - **Two radiator layouts past one pair** (Sean's request, Oct 2026): the *dragonfly* keeps every pair in one plane, pair after pair aft, and lengthens the thrust frame so the drives sit behind the last panel; the *cross* turns every second pair a quarter onto the vertical, sharing the station of the pair before it, so the tail stays short. Every panel turns about its own boom to stay edge-on to the Sun (the vertical pair is edge-on already once the ship rolls the Sun into its Y-Z plane). A hull's look can name one (`"radiators": "cross"` or `"inline"`); otherwise the ship's name picks, so sister ships differ.
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
       - If the ship has no room on arrival, the consignment waits ashore. Retry automatically while stopped there once space or berths become available. An "Awaiting pickup" panel at ports and sites explains the shortage and offers "Collect", which also works while paused and in existing saves.
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
   - **The Long View** is an informal circle of Commons minds, some of them the drone freighters you pass every day (*Patient Arithmetic*, *Reasonable Doubt*). They keep a Contact-like rule: the unknown should be met through a human intermediary. Minds are persons too; this is a choice of envoy, not a test of personhood.
   - **Ines Okafor**, who "represents nobody in particular", is their human go-between.
   - **The arc** (rebuilt Oct 2026; the full design is in `docs/STORY_ARC.md`):
     1. **The trigger:** nothing happens until the pilot salvages the rumoured dead probe **Hermes-7** and recovers its **memory core**. The salvage text hints the probe was put to bed, not wrecked. The co-pilot remarks that the Minds might value it, that it's partly corrupted, and that it could dig in "if I ever get enough downtime".
     2. **The four roads:** selling the core at **Trojan Yards** (the Long View), **Hektor Reach** (the Reach) or **Landauer Deep** (the Sufficiency) chooses that circle's road. Keeping it through a year of hibernation lets your co-pilot read it and ask the **Lanes**.
     3. **World beats:** each road's early beats move the news, wherever you are, even asleep:
        - **The Long View:** *Long Patience* is announced, launched, and turned away three years on.
        - **The Reach:** a swarm, and the object goes dark.
        - **The Sufficiency:** a month of thinking, then an unreadable paper.
        - **The Lanes:** the lanes look up, then find the pattern.
     4. **The ask:** the road's people come for you and lend what you need:
        - **The Long View:** Ines Okafor's favour, the two recordings at Farside, a mind in a box, then Patient Arithmetic's loan.
        - **The Reach:** Fast Enough, asking you to fix their mistake.
        - **The Sufficiency:** Quiet Margin's invitation.
        - **The Lanes:** your own co-pilot, once you have a pod of your own; the Long View sends a drive it owed the lanes.
     5. **The meeting:** at **the Lacuna** it says hello back, and each road hears it its own way.
   - **The co-pilot** is named the first time it speaks up (on the first departure, or when the core comes aboard). Story lines from it are signed with that name (`{copilot}` in `story.json`).
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

## Counterweights and badges (Oct 2026)

Sean: the elevators "lack counterweights deeper in space beyond the geostationary dock. It should be possible to ride a crawler out to the end for no other reason than to experience it"; and "a badge system for getting to hard to reach places or buying everyone in the counterweight bar a drink".

- **Counterweight legs:** each elevator has a `counterweight` leg (places.json): from the anchor, out to a place marked `counterweight` and `foot_of` the anchor. It's reachable only by climber; your ship waits at the anchor.

  | Line | Counterweight | Beyond the anchor | Ride | Fare |
  |---|---|---|---|---|
  | The Luna Line | Ballast Point, toward Earth | 26,000 km | 26 h | 120 cr + 15 cr/t |
  | The Piazzi Stalk | Stalk Top | 550 km | 6 h | 60 cr + 10 cr/t |
  | The Pavonis Line | Pavonis Ballast (once built) | 7,400 km | 52 h | 300 cr + 30 cr/t |

  - **Where they sit:** a `surface` location with `radius_m`, held out along the ribbon and turning with its world (`Ephemeris.surface_point`).
  - **What's there:** tiny markets and a bar each.
  - **The ride view:** it runs on past the anchor. Your weight comes back, pointing outward: 0.17 mg at Ballast Point, a few thousandths of a g on Ceres and Mars. The HUD reads in milligees when slight.
  - **Fares:** out needs the fare in hand; back in never strands you.
  - **Buttons:** the departures tab lists every ride from where you are ("Ride down", "Ride out", "Ride in").
- **Badges** (`data/badges.json`, `sim/badges.gd`, `sim/systems/badge_system.gd`, `state.badges`):
  - **How they're earned:** by being docked somewhere (`visit`, `visit_all`) or by rounds bought (`rounds`, optionally `at` a bar).
  - **The first set:** each counterweight, all three, Line Foot, Psyche, Saturn, Jupiter, Hektor, the first round, a round at the Counterweight Bar, and ten rounds.
  - **Rewards:** each adds renown, and some add standing with an operator.
  - **Renown gets you noticed:** each point raises the chance a hitchhiker asks and a client approaches you by name (6% and 5% a point, at most 1.8 times). With no badges nothing changes.
  - **On screen:** the Contracts tab lists what you are known for.
- **The elevator look** (sources in RESEARCH.md §6 and §7):
  - **Climbers** (`view/flight/climber_model.gd`): after ISEC and Edwards. A truss spine, five opposed wheel pairs pinching the tape (friction drive, no capstan), and two pods hung either side of the ribbon so the load sits on its line. Power comes from a photocell dish under the climber, lit from the foot (`elevator.power` "beam": Luna and Pavonis), or from solar wings ("solar": the Stalk).
  - **The tape:** widest at the anchor, as the real tapered designs are. It runs between two guard strands tied across every 100 m.
  - **In the cab:** the tape is 0.4 m wide at the foot, 1.6 m at the anchor and 0.8 m at the counterweight. A slow wave travels along it. Your own wheels turn as you climb, and a faint beam rises from the foot below the dish.
  - **Climbers pass in pairs,** one up and one down, so the swing each gives the ribbon cancels (as in Red Mars).
  - **Halo Depot:** the anchor is now a vertical station threaded on the ribbon (after Obayashi), with a wide solar array. The 18 km "counterweight" block is gone: Ballast Point is 26,000 km on, far out of sight.
  - **From afar:** the ribbon tapers, the anchor is a stacked tower, and the counterweight is a lumpy mass with a warning light.
- **Bars:** a place with the `bar` service has a `bar` (name, patrons, round_cr). "Buy a round" on the Market tab stands everyone a drink and adds a little standing with the operator. Bars so far: the three counterweights and Line Foot's Earthrise.

## The humpback lander and its pods (Oct 2026, roadmap step 4)

- **The humpback** (`view/flight/kestrel.gd`): the Kestrel's spine (and the Bramble's, a Kestrel at 0.36 scale) arches 1.7 m up over the pod. It is flat across the middle and eases down to the leg pods. The pod hangs level with the leg pods and their lift thrusters, so its weight sits on their line of thrust rather than swinging a metre and a half below it. Landed, it now clears the ground by about 2 m (it nearly touched before).
- **Pod types** (`data/pods.json`), each with its own look:

  | Pod | Carries | Price |
  |---|---|---|
  | Cargo container (the default) | 4 t | 6,000 cr |
  | Liquid tank | 3 t of propellant | 9,000 cr |
  | Passenger cabin | 4 seats and 1 t | 14,000 cr |
  | Open flatbed | 5 t | 4,000 cr |
  | Payload carrier | 3 t of payload, for step 5's satellites | 18,000 cr |

- **How they count:** a module with `pod_mount` (the lander bay) carries one pod (`ship.pod`). Its stats count as a module's would (`ShipStats.pod_of`, `pod_data`, `POD_KEYS`), with no damage or wear. A bay with no `pod` key, as in older saves, has the default.
- **Fitting** (`fit_pod`, `sim/systems/pod_system.gd`): at a shipyard, the old pod taken back at half its price. What's aboard must still fit.
- **Dropping and picking up** (`drop_pod`, `pick_up_pod`):
  - On site, set the pod down: empty, loaded from the hold (up to its capacity), or as a fuel cache from the tanks. What stays aboard must fit without it.
  - The pod lies there in the saved game (`state.sites.pods`) until a lander with an empty clamp picks it up; its contents come aboard if there is room.
  - The site tab lists your pod and any pods lying there; the shipyard tab sells pods.

## Detection and stealth (Oct 2026, roadmap step 6)

Who can see you is a sim rule (`sim/detection.gd`, `sim/systems/detection_system.gd`, `balance.detection`). It sets up the secret missions of step 7.

- **Signature channels.** Each has a range at which a standard sensor sees the ship:

  | Channel | Range (a Mule, at 1 AU) | Off when |
  |---|---|---|
  | Lit drive | about 5 million km (16 million for a deep freighter) | coasting |
  | Waste heat | about 12,000 km | a heat sink is soaking it up |
  | Transponder | 2 million km | running dark |
  | Running lights | 200 km | running dark |
  | Reflected sunlight | about 7,000 km, 2,300 coated | never (it falls with distance from the Sun) |

  The drive's range goes with the square root of its jet power, heat with the root of what the ship radiates (the drive's heat while burning, its electrical loads otherwise), and sunlight with the root of the hull's area times its albedo.

- **Sensors.** A port with a station sees the ship within its loudest range times the port's `sensors` (1 by default; 1.3 to 1.6 at the busy Earth ports and Shackleton). It is checked every 5 minutes of game time in transit. `state.detection.seen_by` lists who sees you now.
- **Running dark** (`dark_running`, key D in the transit views) turns off the transponder and lights. It is allowed only in transit, and the transponder comes back on for the approach: ports don't dock a dark ship.
- **The fine.** A port that sees a dark ship inside its control zone (50,000 km) fines it 600 cr and 1.5 standing with its operator. It happens once a trip, because the ports share word. Offences are counted for step 7's impound.
- **The stealth package.**
  - The low-observable coating (`coat_hull`, 1,500 cr a tonne of dry mass) is sold at the outer yards: Trojan Yards, Hektor Reach and Landauer Deep. It cuts albedo from 0.5 to 0.05.
  - The heat sink module (sold at the same yards) soaks up 800 MJ of waste heat while dark. That is about a day of a small ship's loads. It dumps the heat through the radiators otherwise.
  - Folding the panels in (`stow_panels`, key F in transit, Sean's idea) cuts the sunlit area to 40% and lets out only 30% of the waste heat, with the rest soaking into the structure. The solar wings make nothing while folded. It is allowed only while coasting, and the co-pilot unfolds them for a burn (the radiators carry the drive's heat) and in port.
  - Coasting dark, coated and sunk, a Mule shows at about 2,300 km, and about 1,500 km with its panels in. Burning, it shows at 5 million km whatever it carries.
- **Departures from hard physics.**
  - The ranges are game numbers, not a sensor model. Real waste heat is visible much further against 3 K space; we let the radiators hide behind a fixed figure so that hiding is possible at all.
  - A heat sink that holds a day of heat is generous.
  - This keeps the honest part honest: a lit fusion drive cannot hide.

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
| Concord | `concord_pair` | Over Ceres, 10 degrees round from Piazzi (about 120 km) | dock model 1/10 scale: cylinder 400 m radius, 3.2 km long (real: 4 km, 32 km) | The Belt's first big farm: 10 t/day of food out, 10 t/day of Ceres ice and volatiles, parts and refined metal in. |
| Selene Ring | `selene_ring` | Lunar orbit at 52 km altitude | wheel 400 m radius at lunar gravity | Regolith, refined metal and a little helium-3 out; water, food, parts in. Refined metal from the Moon is new for Clarke, the Kernel and Trojan. |

**Departures from the real thing, on purpose** (kept here because there is no RESEARCH entry for each):
- **Island One is a Bernal sphere, but the station model only has wheel, cylinder and stanford.** It is built as a squat drum (radius 250 m, length 500 m, the same diameter) until a sphere type exists. The unfinished sphere in the sky (`bernal_frame`) is the real shape.
- **Concord is one cylinder at a tenth of its size.** The pair is two, counter-rotating, each 4 km radius and 32 km long; the dock scene spawns you three hub radii out, and at full size the autopilot could not dock in 15 minutes (`--dock-trial` failed). The dockable model is the first cylinder at 1/10 scale, and the second is not modelled there. The set piece shows both at full size from Piazzi. The set piece shows both from Piazzi.
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

## Panels that fold for docking (Oct 2026)

Sean's request (2026-10-08): solar wings and radiators should fold back for docking and unfold once undocked. This is view only: nothing in the sim changes. Docked ships run on shore power, and a ship leaving port runs its reactor, so stowed panels cost nothing.

- **Built in segments** (`ShipBuilder.boom_panel`): every panel is cut into segments about 1.6 m long, hinged along the boom's width.
- **Stowing** (`ShipRig.set_fold`, `rig.fold` from 0 out to 1 stowed): over about 25 s, each panel first turns flat into the hull's plane. Then its segments fold accordion-fashion into a short stack standing at the boom's end, and the dish parks facing ahead. Deploying runs the same steps in reverse.
- **When:**
  - The player's ship stows on the final approach in the docking scene.
  - Leaving a station (`view/flight/departure.gd`), wait for the bay doors, then back out along its centre line with the ship's roll matching the rotor (including negative spin). Keep the main drive off and the panels stowed until the whole ship's turning envelope is clear of the mouth. Only then turn toward the burn and ease the roll toward the Sun. Ships too big for the tunnel use the exterior collar.
  - Deployment takes about 25 game seconds after clearance in every transit view and the audio rig. Time compression, save/load and changing views use that same game-time schedule.
  - Departures from exploration sites have no docking fold or back-out sequence. Panels stay deployed unless the pilot manually stowed them for stealth. The existing co-pilot rule still deploys manually stowed panels for a main-engine burn's cooling.
  - Ships moored at a station are stowed. Lane traffic stows over the 30% of its lane nearest the station.
- **Running quiet:** the same fold, held in transit while `ship.stowed` is set (see "Detection and stealth").
- The sail freighter's sail is not folded.

## Docking bays (Oct 2026, roadmap step 3)

Ships fly into a station instead of nosing up to a collar on a small hub (`view/flight/bay.gd`, `balance.bays`).

- **The bay:**
  - A tunnel 16 m in radius and 80 m deep, lined in pale steel and lit by rings of lamps, with yellow guide stripes.
  - It is built forward of the station's docking face, so the port at its back is exactly where the old port was. Approaches, hand-overs and trip times are unchanged.
  - A wheel's hub grows to the bay's outer width (24 m radius) where it was smaller. Habitats carry the bay as a module on their docking nub.
  - The station's name is painted on the bay's face below the doors, sized to fit inside its rim and lit like the hull.
  - Green and red approach lights flank the mouth. Every light is mounted on the station: none hangs in empty space along the approach.
- **Doors** (`station.door` in `data/places.json`):
  - **Iris** at the Earth wheels and the habitats: twelve blades behind the face that swing in across the mouth. Open, they lie along the rim inside a housing flange.
  - **Clamshell** at the yards and working ports: two leaves hinged top and bottom, folding outward.
  - **Sliding** elsewhere: two leaves running apart in tracks.
- **Clearance:** traffic control clears the ship 4 s into the docking scene, and the doors take 12 s to open, with amber lamps turning while they move. Once the whole ship is inside, they close behind it.
  - The co-pilot holds 40 m short of the mouth until the doors are open.
- **Collisions:**
  - Shut doors are solid.
  - Inside, the tunnel wall and the back wall hold the ship, and doors shut behind it hold it in.
  - The ship's body probe shrinks to its stowed radius as its panels fold (see "Panels that fold for docking"). That radius is at most 10 m (a deep freighter), against the tunnel's 16 m.
- **Too big for the bay:** a ship whose stowed radius plus 3 m won't go in berths on a collar on the shut doors. Only the sail freighters are that big, and they never dock in the flight scene.
- Only the view changed: the sim never sees the bay.

## The co-pilot docks (Oct 2026)

Sean's direction (2026-10-28): the co-pilot should dock the ship as it undocks it, by default. It knows what it's qualified for, so it assumes you want it to fly; the player watches from outside, as on the way out, and enjoys the spectacle.

- **Who flies:** the co-pilot takes every approach (`view/flight/autopilot.gd`, the same controls a player has). K hands you the controls and back. A setting on the controls page (F1) turns it off for good (`view/flight/flight_prefs.gd`, saved in `user://settings.cfg`).
- **The docking computer** is no longer needed to hand over. Fitted, it lets the co-pilot close faster: without one it closes at `balance.docking.copilot_unaided_mult` (0.7) of the speed.
- **The outside view** (`view_mode` "outside", `balance.flight.copilot_view`): the departure's director style. It cuts every 9 s between chase, orbit, fly-past and a shot from the hub's rim looking back down the axis. Close in, it waits inside the bay near the back wall, turning with the station, to watch the ship come through the doors (beside the port if the ship is too big for the bay). C cycles cockpit, chase and outside. A slim strip along the bottom keeps the range, the closing speed and who is flying.
- **Talk:** the co-pilot talks you in on the comms (`data/npcs.json` chatter.copilot_dock): taking the approach, holding for traffic, the bay given to us, matching spin, capture. It also praises your flying when you dock yourself.
- **Thrusters you can see** (`view/flight/rcs_jets.gd`, shared): puffs against every push and turn in the docking scene; steady pulses toward the nose while backing out of a port, from any port, not just a bay we fit; and the pattern's ships puff as they ease in and back out. Puffs scale with the ship (a deep freighter's are about 2 m).
- **Scripted shoots** (tours, gallery, promo) open approaches in the cockpit with the player flying, as before. The tour adds the co-pilot's outside view on the approach and into the bay.

## Silence outside (Oct 2026)

Sean's direction (2026-10-11): outside shots of any kind should be totally silent. With the camera in vacuum it is purely visual, as in *Interstellar*: adding by subtraction.

- With `balance.audio.silent_outside` on (the default), these mute the ship's sounds (the Hull bus) and the cabin air:
  - the transit ship and orbit views;
  - the docking scene's chase and wide cameras.
- The cockpit views (transit and docking) and the map keep the ship's sounds, heard through the hull as before.
- Nothing is removed: the sounds keep running muted (`ShipAudio.set_outside`), so they come back the moment the camera does, or everywhere if the switch is turned off.

## Leaving a bay (Oct 2026)

Sean's direction (2026-10-10): the ship should leave through the bay doors, seen from inside the dock, reversing out gently on its thrusters with everything stowed, then unstowing and aligning for its burn. It should be cinematic: a camera that follows the ship out without passing through walls, and ship, camera and station turning together until the ship is out.

- **The timeline** (`view/flight/undock.gd`, `view/flight/departure.gd`, `balance.undock`, game seconds since departure):
  - At 1 s the doors start to open (12 s).
  - Once the doors are fully open (13 s with the current settings), the ship eases astern on its thrusters, gathering way at 0.2 m/s² to 2.5 m/s. This uses the later of `move_at_s` and the end of the door animation.
  - Once the whole hull's turning envelope, including deployed panels, is 8 m past the mouth, the panels and dish snap out over 7 game seconds (`deploy_s`, it was 25 s) and the roll jets brake its spin over 5 s. Clearance depends on the current ship's dimensions.
  - After 3 s more it turns for its burn.
  - `time.departure_ramp` holds ×1 for the first 120 s for this (it was 60 s, which jumped to ×10 while a ship was still in the hall's tunnel, about 72 s to clear, so the unfolding flashed past). `tests/departure_view.gd` checks every hull from every station is out, deployed and starting its turn at least 10 s before the first step.

Sean's direction (2026-10-13): leaving a station needs more cinema. The panels and dish should open aggressively, the ship's AI should show some personality, keen to fly free, and the ship coming alive should be seen before ×10. The player can always speed it up.

- **Eager deployment** (`ShipRig.transit_fold`, `ShipRig.deploy_spring`): the panels and dish mast gather speed as they open (not a steady fold), snap straight, then bounce past straight and settle (`spring_share` of the fold at `spring_hz`, dying over `spring_damp_s`), while the panels whip round to the Sun. Docking and the stealth fold keep the slow, steady `FOLD_RATE`.
- **The co-pilot talks it out** (`view/flight/departure_calls.gd`, lines in `data/npcs.json` `chatter.copilot_undock`): waking the ship at 2 s, the doors, backing out, clear of the bay, and free once everything is out. Lines go to the notices and the comms log, in every transit view. A moment the clock has sped more than 30 s past goes unsaid.
- **Lockstep:** in the bay the ship is held on the berth's axis, turning with the station's spin, so the tunnel and doors stand still around it. Once clear its roll brakes smoothly to a stop. Then its attitude blends into normal flight (rolled to the Sun) as it turns.
- **The camera** (follow view's "undock" set-up, one unbroken shot until the ship turns):
  - It rides in the ship's frame, so it turns with ship and station.
  - It sits off the axis, clear of the stowed hull and inside the tunnel's walls, trailing the nose deeper into the bay. It looks out past the ship to the doors and space, and follows it out.
- **Stowed for the bay:** panels fold as before. The high-gain dish now stows too: it turns to face forward and level, then its mast folds down aft on a foot hinge, leaving the bowl face-up on the hull. It works at every dish size. Motors whine at each fold hinge and the dish's foot hinge.
- **The sound** (`view/audio/transit_audio.gd`) follows the same timeline: thrusters as the ship gathers way, roll jets once clear, motors as it unfolds.
- **Solid bays:**
  - The bay's shell is closed at the back too, where it meets the hub, so it reads solid from any side.
  - The interior (lining, back wall, stripes, lamps) is drawn on its own render layer (`Bay.INTERIOR_LAYER`), which the Sun and planetshine leave out. Inside, only the bay's lamps light it, so no sunlight leaks through the walls.

## Thrusters (Oct 2026)

- **Plumes** (`view/shaders/rcs_plume.gdshader`, follow view): cold gas in vacuum. A short, faint cone flaring off the nozzle, brightest at the nozzle and soft at its edges, with a brief flash at its root, gone in a third of a second. It replaces the glowing balls.
- **Calmer firing:** jets fire as a turn starts, reverses or stops, and only trim every 1.6 s while it is held, at most four at once. Under time compression they come less often again, by 1 + log10(scale). The sound follows the same rule (`ShipAudio`): a jet sounds as it starts firing, pulses again only every 0.75 s while held, and no two jets sound within 0.16 s. Firm, separate puffs, not a rattle.

## Satellites (Oct 2026, roadmap step 5)

- **The job** (`contracts.json` kind `satellite`, Known standing):
  - Carry a satellite (0.4 to 2.5 t) in the lander's payload carrier pod (`ship.payload_load_t`; it counts toward the ship's mass) and release it near its orbit: within 20,000 km of the port it serves (`release_satellite`, key R in transit, or the Release button at the port).
  - You can't swap or set down the pod with a satellite in it.
- **Release:** in transit the satellite drifts clear of the ship and unfolds its wings (`view/flight/satellite_model.gd`, `view/follow_view.gd`).
- **In the world:** released satellites are kept in `state.sites.satellites` (the newest 60). Up to eight keep station off the hub at their port in the docking scene, out of the approach corridor.

## Secret work (Oct 2026, roadmap step 7)

All the rules are in `sim/systems/contract_system.gd` and `contracts.covert`.

- **Unlock:** Reliable standing (20) with any operator. Then half of the named approaches at a port are secret work, with their own openers.
- **The kinds:**
  - **Quiet delivery:** like a courier job.
  - **Listening device:** planted on a port (`plant_device`, key R) from within 500,000 km, coasting, dark and unseen by it. It goes in on a long, slow drift.
  - **Spy satellite:** the same rule, from the payload carrier.
  - **Drop-off:** people to a site.
  - **Extraction:** people from a site, brought home. Both need a lander bay. The job tells you where the site is.
- **The watcher:** each job is hidden from an operator (for a device or spy satellite, the target's).
  - While the job is aboard, every second a watcher's port sees you builds suspicion: three times as fast with the transponder on, and twice as fast on a trip with a filed plan.
  - At two hours' worth you are caught. Docking at the watcher's port with the job aboard is customs: caught.
  - On a trip without a plan, slipping every port's sensors loses them, and suspicion resets.
- **Caught:** the job fails, with a 2,500 cr fine, −6 standing with the watcher, −4 with the client, and an offence. At the third offence the ship is impounded: departures refused until the 6,000 cr release fee is paid (`pay_impound`).
- **Free departures:**
  - `depart` with `filed: false`, unlocked with secret work. Nobody is told where you are bound.
  - Leaving a busy port that way costs 400 cr and a point of standing with its operator, half as much again each time (traffic control remembers, `state.detection.unfiled`).
  - **Simplification:** the co-pilot flies straight to the real destination. Leaving on a dull heading and turning later needs a planner that can re-plan mid-trip, which we don't have yet. The spy's exit is modelled by its effect: once out of every port's sight, the watchers lose you.
- **The view:**
  - The departures tab has a flight-plan toggle and the impound panel.
  - Offer cards say what secret work needs and who mustn't know.
  - Active jobs show suspicion and a Release or Plant button.
  - The transit HUD adds "no plan filed" and suspicion.

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
  - Departure drops to x1 while the ship backs off the port, then steps up (`departure_ramp`: 120 s at x1 while the ship backs out and comes alive, then x10 at 2 game minutes, x100 at 3 and x1000 at 8), unless the pilot picks a scale of their own. After backing out nose-first, the ship turns to point along its first burn and holds there until the drive lights.
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

## The ship builder (Oct 2026)

`view/ship_builder_screen.gd`, opened from the Shipyard tab. You plan a whole refit on screen, then put it together.
- **The ship in 3D**, rebuilt as the plan changes and turning slowly; drag to turn it, wheel to zoom.
- **How she flies, now and after:** acceleration and delta-v on full tanks, hold, propellant, heat, life support, berths, dry mass. Green arrows for better, red for worse.
- **The slots**, nose to tail. A planned change is amber, with what it replaces.
- **What this yard has** for the chosen slot: each part with its price, its trade-in and the net cost, and what it would change.
- **The bill:** every part and trade-in, the total, and what you'd have left, then "Put it together".
- **The whole bill.** `ShipyardSystem.quote(state, data, plan, extra)` is a thin layer over `ShipBill.quote`, laid out one line per slot: the part, the fitting labour, and the trade-in by condition and age. Below the parts come any service or overhaul and a Warrant of Fitness inspection done in the same visit (the "While she is in" row), then the days in port, a warning if the refit voids the warrant, and any change to the insurance premium.
- **One job.** "Put it together" sends the whole plan as a single `refit` command, so the bill shown is the bill charged and the days are batched (a test holds both equal).
- **Condition and tunes on the cards.** Each slot shows its condition, and red if it is badly worn or faulty. A drive with an engine tune says so, and swapping it out warns that the tune goes with it.


## Favours: rewards in kind, hitchhikers and engine tunes (Oct 2026)

Not every debt is paid in credits. Everything here is data in `data/favours.json`, lives in the sim (`sim/favours.gd`, `sim/systems/favour_system.gd`), goes through `Sim.apply`, and saves with defaults for older saves (`state.favours`, `ship["hikers"]`, `ship["tunes"]`; no schema bump, the new fields only add).

- **Rewards in kind.** `Contracts.make_offer` may turn part of a reward into something else: a *repair voucher* at the client's yards, *cheaper propellant* or *free docking tugs* at the client's ports for some days, *free tonnes* of propellant, *a favour owed* (standing with the client), or *an engine tune*. Odds are per contract kind (`in_kind.chance`) times a per-client multiplier (`client_mult`: the Belt and the Kernel pay in kind a lot, the Compact rarely), and the mix of forms can be weighted per client (`client_forms`). The offer card shows what is offered with its credit value ("worth about 1,800 cr") beside the cash; the cash part drops by `value_cr x cash_offset` (0.85), so a voucher you can only spend in one place is a slightly better deal on paper than the cash it replaces. Late delivery scales the in-kind part by the late pay fraction; a tune late is paid in credits instead. Failed or abandoned jobs pay nothing in either kind.
- **Redemption.** Vouchers sit in `state.favours.vouchers` and expire. Fuel, free-refuel and docking vouchers are *used automatically* when you pay at a port of that operator (`refuel`, the auto-dock fee), best discount first, free tonnes soonest-expiring first. A repair voucher is spent two ways at one of the operator's shipyards. `use_voucher {id}` mends collision damage (a button on the Contracts tab; it spends what the damage costs and keeps the rest, via `Favours.repair_service`). And **it comes off the yard bill automatically**: `ShipBill.quote` takes the live vouchers' balance (`Favours.yard_voucher_balance`) off *service and overhaul* (not parts, labour or the inspection fee) as a line `voucher: -X cr`, and the shipyard commands spend it (`Favours.spend_yard_vouchers`, soonest-expiring first) when they charge. `use_voucher: false` in a bill request leaves it unspent. Yard-module prices and resale are untouched.
- **Hitchhikers** ("have spacesuit, will travel"). While you are docked at a port, someone may ask for a ride (`hitchhikers.chance`, once per `cooldown_days` per port, at most `max_waiting`). They have a name and a trade, a destination (mostly nearby, some long-haul), and wait a few days. `accept_hitchhiker {id}` puts them aboard if there is a free berth (the same berths contract passengers use: no berth, no ride). A hitchhiker is a passenger, so the Warrant of Fitness rule holds too: **no ride without a valid WoF** (the same refusal text as passenger jobs), and a strict port puts hitchhikers ashore without their fare if the WoF has lapsed in flight and room in the galley (`max_aboard`). They take a berth and 0.1 t, pay a small fare on arrival (often nothing), and get off at their stop (or at any port after `patience_days`). They speak on boarding, midway and on leaving, through events the view puts on the comms channel. By trade, summed over everyone aboard: an **engineer** mends small damage in flight and cuts wear; a **navigator** trims the propellant a departure burns; a **pilot** halves the auto-dock tug fee; a **cook** stretches life support; a **tinkerer** may leave a tune on the drive when they go. Most travellers are simply going somewhere to help the expansion grow: **doctors, surgeons, nurses, teachers, scientists, aeroponics growers, artists, musicians and poets**. Set one down at their stop and its operator remembers who brought them (`goodwill_rep`, a little reputation; an aeroponics grower also tends the air garden on the way). **Tourists** pay more for the view (a trade's own `fare_cr`). Contract passengers and shuttle comms chatter draw on the same community. **Kindness on the lanes:** set one of those travellers down at their stop, or deliver contract passengers on time, and sometimes the people there do something nice for the pilot who brought them (`favours.kindness`): free tugs at the operator's ports for a few weeks, cheaper or free propellant, a small repair credit, or a whip-round in cash. A human element in a dangerous place. Docking help in the flight view itself is not wired (it is outside the sim).
- **Engine tunes.** `ship["tunes"]` holds `{id, slot, module, source}`; each tune has `thrust_pct`, `isp_pct` and `heat_pct` and a `wear_pct` for maintenance to read (`ShipStats.wear_mult`). `ShipStats` applies them per drive slot, so `thrust_n`, `accel_mps2`, `heat_ratio` and `exhaust_velocity` all change, and everything that plans with them (Navigation, Interplanetary, RoutePlanner, the departure fuel burn) follows with no changes of its own. The trade-offs are real: more thrust means more heat, which throttles the drive when the radiators cannot keep up; a lean-burn map is thriftier and cooler but pushes less. A tune belongs to the drive module it was fitted to and stops counting if the drive is swapped. A drive takes `max_tunes_per_drive` tunes, each tune once. Route-option cache keys include the tunes. The station's ship panel lists each tune with its source and effect.
- **Departures from hard physics.** Tunes are a few per cent, applied as multipliers on a drive's nominal numbers; an engineer mending damage in transit is a convenience, not a repair model. Vouchers and discounts exist to make favours worth having; they are priced against credits in the data, not in a real market.


## Wear, refit, Warrant of Fitness and insurance (Oct 2026)

Owner's brief: *the flat 50% resale seems wrong; it should be about wear and tear and maintenance and overhaul; there needs to be a mechanism for ship refit, a warrant of fitness, and insurance.* All numbers are in `data/ship_economy.json`; the rules are pure functions in `sim/condition.gd`, `fitness.gd`, `insurance.gd`, `ship_bill.gd` and `stock_ship.gd`, driven by the `wear`, `fitness` and `insurance` systems and the extended `shipyard` system.

- **Wear and condition.** Each module has a wear fraction (`ship.wear[slot]`, 0 new to 1 worn out; condition = 1 - wear). It builds with what the module does: drives on burn hours and a lit reactor, radiators on thermal load (heat made over heat rejected, so an undersized radiator ages faster), cargo pods on hours spent loaded and on every dock, landers on landings, rigs and sensors on site work, and everything a little on hours in service (docked hours count a quarter). Docks and landings are counted from the ship's phase changing (`approach` to `docked`, `transit` to `on_site`). Counters sit beside it in `ship.use[slot]`. Wear is **separate from collision damage** (`ship.damage`), which is unchanged.
- **What low condition does.** Below condition 0.7 a module's *supply and rating* stats (thrust, radiator rejection, solar, battery, reactor) fall linearly to 28% less at condition 0 (tuned from 12%, see `docs/balance/2026-10-07-economy-together.md`: at 12% a pilot who never maintained the ship earned as much as one who did): a worn-out drive pushes over a quarter less, never fails. Below 0.45, each hour it has a small chance of a **fault** (a warning event, 2 to 6% off that module, up to 10% per module) that stays until the module is serviced. Faults draw from the shared sim generator (`rng_state`). Nothing here damages a module or can lose the ship. Capacities (tanks, pods) and loads (kW) are not trimmed.
- **Resale and trade-in.** A module's trade-in is `price * lerp(scrap 0.06, new 0.92, condition^1.6) * age factor * (1 - damage)`. The age factor loses 2.5% a year to a floor of 55%. A fresh module trades in near full value, a tired one for scrap. This replaces `shipyard.resale_fraction` (removed). Modules priced 0 (the Mule's own drive and pod) trade in for nothing, as before.
- **Service and overhaul** at any shipyard (`service`, `overhaul` commands, or one slot, or `all`). *Service* is cheap (3.5% of the module's value basis), restores 0.3 condition up to 0.92, takes a fraction of a day and clears faults. *Overhaul* is dear (25% of basis, less for a lightly worn module), restores to 0.97 and takes days (drives 4, pods 2). A module's basis is its price or its kind's `basis_floor`, whichever is higher, so the zero-price stock drive still costs something to overhaul. Prices vary by yard (`yards`: Trojan Yards cheapest, Landauer Deep dearest), and `module_overrides` can set any module's own figures. Game time really passes in port (even if the player had paused); yard crews work two jobs at once (`refit.crew_parallel`), so a bundle takes the longer job or half the total.
- **Refit.** `install_module` still works and is now a one-swap refit: parts at the yard's price, trade-in by condition, **fitting labour** and **days in port** (per module kind, scaled by the yard). `refit` takes several swaps, services and an inspection in one visit. A fitted module is new (no wear, no age). Refitting a drive voids the Warrant of Fitness until the next inspection (`wof.refit_voids`); `inspect: true` in the same visit renews it.
- **Warrant of Fitness** (the NZ idea: a periodic safety inspection). `ship.wof` holds an expiry. An `inspect` at a yard costs a fee and a quarter-day and either **passes** (valid 180 days) or **fails** with a list of what must be fixed (a module worn below condition 0.25 or damaged past 35%, the keel strained past 25%). It runs down with a warning at 21 days. Without a valid WoF (expired, failed or voided), all in data (`wof.effects`, `port_rules`): **passenger jobs are refused** at acceptance, **insurance is void**, and **traffic control charges extra** per dock (Terran Compact ports 300 cr, others 100, the Commons, Belt and Kernel 0). At *strict* ports (the Terran Compact's) a ship carrying passengers is not cleared for them: they go ashore and the job closes as `turned_away` unpaid. This is deliberately not a hard refusal to dock, so a manual approach can never leave the pilot stuck outside.
- **Insurance.** `buy_insurance {plan}` at any port: `basic` (total loss), `standard` (+ collision repair), `full` (+ cargo). Premium per 30 days = insured value (keel plus each module's basis by condition) x plan rate x a risk factor (worn ships cost more) x a claims factor (+25% per claim in the last year, capped). A total loss on a working policy pays the difference in value between the lost ship and the stock hull it is replaced with (x payout fraction) less the excess (the old `damage.insurance_excess`, scaled by plan), plus cargo on `full`. Collision cover pays a yard repair above a small excess. Each paid claim is recorded and raises later premiums. Auto-renew is on by default and pays the premium when docked within ten days of expiry (a renewal adds a period to the old expiry, so paying early wastes nothing; with three days a 3-day trip could straddle the window and lapse the policy about once a year) if the pilot can afford it, otherwise the policy **lapses**. A lapsed or void policy (no WoF) pays nothing. A plan covering collision is refused for a ship that is already damaged.
- **The fallback.** With no working cover a lost ship is still replaced, by a stock Commons Mule **on a loan**: 9,000 cr on the books, repaid at 150 cr/day only while credits are above 500. Credits are never pushed negative by it, so no pilot can be stuck for good.
- **Start.** The stock second-hand Mule starts **part-worn** (conditions 0.70 to 0.85, 900 days old), with 120 days of WoF and the Commons mutual's `basic` cover paid for 30 days. A pilot needs to start visiting a yard within a month or two; nothing breaks in the first weeks.
- **The bill.** `ShipBill.quote(state, data, request)` is a pure function (no state change) returning every line (parts, trade-in credit by condition, labour, service, overhaul, inspection), the total, days in port, the effect on the WoF (valid after? would it pass? what must be fixed?) and on the insurance (state and premium before and after), and the ship as it would be. The commands charge exactly the quote. The graphical ship-builder should call this. A **module-condition API** (`Condition.condition`, `restore`, `add_wear`, `clear_faults`) is there for later engine tunes or repair vouchers.
- **Departures from reality, on purpose:** wear is one number per module (real hardware has many failure modes); a service is a single flat step; the WoF is a gameplay inspection, not an engineering one; cover is simple tiers; faults are mild and never lethal so the hopeful tone holds. Hazards are wear and paperwork, not villains.

## A fleet of your own (Oct 2026)

Owner's brief: *it should be possible to own different ships, kept at a shipyard for a monthly berth fee, and some missions should need a certain type of craft.* Numbers in `data/ship_economy.json` `fleet`; rules in `sim/fleet.gd` and `sim/systems/fleet_system.gd`.

- **Buying.** Each shipyard sells some hulls (`fleet.hulls[hull].yards`): the Mule everywhere, couriers and shuttles at the busy inner yards, the bulk tanker at Kibo Ring and Piazzi, the heavy freighter only at Trojan Yards and Piazzi. A bought hull is a sound second-hand example (all modules at 8% wear, 400 days in service) with a fresh Warrant of Fitness and full tanks. `buy_ship {hull, name?, board?}` lays her up in a berth here, or with `board` you fly her away and the old ship takes the berth.
- **Berths.** A ship you are not flying waits at the yard where you left her and keeps everything that is hers (fit, wear, WoF, fuel, trade cargo). Rent is charged a month (30 days) ahead: 1,500 cr times the hull's `berth_mult` (heavy freighters take three berths' worth) times the yard's `berth` rate. Rent you cannot pay is owed and settled as soon as there is money; after three unpaid months the yard sells her (`sale_value`) and sends on what is left after the debt. No pilot ends up in debt to a yard.
- **Changing ships** (`switch_ship {index}`) happens docked at the yard where she is berthed, and only with no contract work, passengers or hitchhikers aboard and the ship not impounded, so a job can never be stranded in a ship you left behind. Her batteries were on shore power. Insurance follows the ship you fly (a laid-up ship sits in a yard, covered by the yard).
- **Selling** (`sell_ship {index}`) pays the hull's price by her mean condition and age (the module resale curve), times 0.85, less keel damage, plus the trade-in of any module that differs from the stock fit, less any rent owed. You can own at most four ships.
- **Work for a type of craft.** Each hull has a class (`utility`, `fast`, `passenger`, `bulk`, `heavy`). Contract kinds with `craft` can be taken only in one of those: **bulk freight** (30 to 65 t, a heavy freighter or bulk carrier), **express runs** (a fast courier, deadlines set by a courier's own time), and **charters** (8 to 20 passengers, a passenger shuttle). Their deadlines come from `reference_hull`. The job card says what it needs and where to get one (one of yours laid up, or the yards that sell it). They start at standing 3, so a new pilot sees them as something to aim for, and they are listed on top of the courier work (at most `board.max_craft_offers`, 2, per board), so they never crowd out jobs any ship can do.
- **Departures from reality, on purpose:** the berth is a flat monthly fee whatever the yard's traffic; a laid-up ship neither wears nor needs crew; changing ships is instant.

## The cockpit cabin (Oct 2026)

Owner's brief: *if you turn about in the cockpit there is nothing else; we need a much better experience there.* The flight deck (`view/flight/flight_deck.gd`) now has the rest of a two-seat command pod round the pilot, built in eye space like the panel so it fits any window: side walls with a window each, quarter lights between the windscreen pillars and the walls, side consoles with switch rows and lit placards, the overhead panel, the seat's bolsters and a throttle quadrant, a floor grating, and the back bulkhead with the hatch, lockers, a cargo strap, the checklist, photos from home, a fire extinguisher and a basil plant on the console.

- **Light.** The cabin is on its own render layer (`CABIN_LAYER`, 4). Every scene sun leaves it out (`Bay.shade_interior`, planetshine too) and the cabin has its own copy of the sun with short, sharp shadows (`sync_sun`), so sunlight comes in only through the glass and its patches sweep across the walls and floor as the ship turns. A warm dome light, the overhead spill and two low console lights keep it a lived-in place in the shade.
- **Looking about.** Drag with the mouse in either cockpit. On approach the head comes back to the windscreen when you let go; in transit it stays where you put it (C centres it), as the arrow keys do.
- The solids were wound inside out before this (the eye saw the back faces of every box), which is why the old panel looked flat and dark; fixed in `_hexa`.

## Hibernation (Oct 2026)

Owner's brief: *hibernation lets the player tunnel through deep time like a bookworm, disjointed from smaller human affairs but getting to witness a grander stage.* Rules in `sim/systems/sleep_system.gd`, numbers in `data/balance.json` `sleep`, screens in `view/sleep_overlay.gd` and `view/wake_digest.gd`.

- **The pod:** any module with `"sleep": true`.
  - The Long View's lent berth is one.
  - The **hibernation pod** (85,000 cr, a cargo slot, 600 days of life support) is sold at Trojan Yards, Ares Ring, Hektor Reach and Landauer Deep.
- **On a voyage:** `sleep` in transit (key S, pad d-pad down; the comms suggest it on departure) sleeps until **12 hours before arrival**. You wake at x10,000, which the approach caps slow as the port nears, so the approach is always yours. A trip with less than a day left isn't worth it.
- **At port:** `sleep {days}` (the ship panel offers a week, a month, six months, a year) lets time pass. Jobs run late, and rent and premiums come due: the world goes on.
- **The dark:**
  - **What you see:** the screen goes dark and the date runs. The ship's mind keeps a log: a line as the ship crosses each planet's distance from the Sun (out to the heliopause and beyond), and one a year.
  - **Waking:** "Wake now" (or S) wakes you early.
  - **The screen underneath:** it neither draws nor runs while you sleep.
- **Waking:** a digest shows how long you slept, the money in and out, the Spaceline headlines from the time you were under, and the messages that came in. The game holds still until you've read it.
- **Your own clock:** `state.sleep.total_s` is the time you've slept all told (shown on the ship panel). Ten years earns the **Bookworm** badge.
- **Why it's fast:** the world goes on, but coarsely, while you sleep:
  - **Steps:** every system steps a day at a time (`Sim.step_s`, `sleep.step_hours`), the economy included.
  - **NPC traders:** they weigh and fly routes on estimates: the hull's stock ship, planned once per route per 30 days (`estimate_days`). A trip flown on an estimate is a *sketch* (no path) until the pilot wakes, when every ship still in flight is planned in full (`NpcSystem._plan_sketches`). The maps skip sketches.
  - **Frames:** a frame runs at most three day-steps, so the dark screen stays live.
  - **Result:** 900 days asleep take about 45 s of simulation (190 s awake).
  - **Saves:** the estimates are a pure function of hull, route and period, so a game saved asleep wakes exactly as one that never was.
- **Departures from reality, on purpose:** the pod has no medical side to it (no recovery time, no ageing effects), and the world's coarse steps while you sleep are a little less detailed than when you're awake.

## Stations and their gravity (Oct 2026)

Owner's brief: *the rotating stations look only big enough for one ship at a time. Ships should come in on the axis and be drawn down to a berth off it for access, maintenance and cargo. The ring should give no more than 1 g, ideally a stately Mars or lunar g to reduce structural strain. Tell the player the local gravity when they dock, and model it when walking comes (`docs/FIRST_PERSON.md`).*

- **Bigger, slower wheels:** rings of 150 to 520 m (Kibo Ring is 380 m), each spun for a chosen gravity on its ring (`places.json` `gravity_g`). Most are Moon- to Mars-like:
  - **Terran Compact ports:** Mars-like or a little more. Kernel L5 is 0.5 g.
  - **Luna and the far ports:** lunar.
  - **Landauer Deep:** 0.08 g; the minds don't need it.
  - **The O'Neill colonies and the Stanford torus:** 0.95 g, where people raise children.

  Spin rates are now 0.6 to 1.0 rpm on the wheels. The rule is in `sim/spin.gd`. Validation refuses more than 1 g, and a spin that doesn't give the stated gravity.
- **The docking hall:** the bay's tunnel (`balance.bays.depth_m`, now 30 m) opens into a hall 90 m across and 110 m long (`bays.hall`) inside the docking module. It has eight cradles round its wall, each with saddles, clamp arms, a gantry, a walkway and its number, and lamp bars between them. A wheel's hub grows to the module's width.
- **Docking:**
  - You fly in along the axis to the port on the hall's back wall, as before; the port is where the docking face was, so approaches and trip times are unchanged.
  - Captured, the clamps draw the ship over 10 s (`hall.draw_s`) down off the axis to cradle 1, keel to the wall. Other ships lie in the other cradles, lit only by the hall (no sunlight through the walls), instead of moored outside.
  - On docking, a notice gives the local gravity: "0.38 g (Mars-like) on the ring; 0.03 g at your berth".
- **Leaving:** the ship is lifted from its cradle to the axis while the doors open (`hall.lift_start_s` to the doors fully open), then backs out through the hall and the tunnel as before.

## Traffic control at the bay (Oct 2026)

Owner's brief: *we should see other ships if they're about. Docking and undocking should wait if other ships are ahead of us in the pattern, all run by the station's AI traffic control. Out-system ports can be more of a free-for-all, with pilots relying on a buddy system, like club airfields with no control tower.*

- **One bay, one ship at a time.** Each movement through a port's bay (doors open, through, doors shut) holds it for `balance.traffic.cycle_s` (90 s). `sim/traffic.gd` gives every port's schedule from the time and state alone, with no random draws, so the flight scene, the departure view and the sim agree.
  - **Long-haul ships** (`npcs.json`) come in over the cycle before they dock, and go out when they leave.
  - **The port's own craft** (shuttles, couriers, tenders: `npcs.json` `local_traffic`) take `bay_traffic.per_hour` slots an hour, from 1 at Plume Watch and Landauer Deep to 8 at Kibo Ring and Kalpana One. A low-discrepancy sequence spreads them evenly; they never clump or share the bay.
- **Towers and open ports** (`places.json` `bay_traffic.control`):
  - **Tower:** the inner system: the Earth–Moon ports, Mars, Trojan Yards and the colonies. The controller sequences every ship. Arriving, it gives you your number ("number 2 for the bay, behind the Moth") and clears each ship in or out by name. At most `max_ahead` ships go before you.
  - **Open:** the belt and beyond (Piazzi, Psyche, Valhalla, Huygens, Plume Watch, Hektor Reach, Landauer Deep). There is no controller. Pilots call their own moves on the common channel ("Piazzi Station traffic, Wren, inbound for the bay"). You give way to anyone already committed (`lead_s`), and once you're within `claim_m` of the doors with nobody committed, you call "going in" and the bay is yours. Ships coming in behind you call that they're holding behind you.
- **Arriving (flight scene):**
  - Ships ahead of you fly the axis and go through the doors first, while you hold `hold_m` (250 m) off the doors. The co-pilot's line says why, and the autopilot holds there too.
  - Ships behind you wait `separation_m` back until you're in.
  - Flying in uncleared gets a warning, and the clamps refuse capture until the bay is yours.
  - Pattern ships are solid and show on the scanner. The view draws them (`view/flight/pattern.gd`); the sim only knows when they move.
- **Leaving:**
  - The depart command works out a hold from the same schedule (`Traffic.departure_hold`, stored as `location.hold_s`, at most `max_hold_s`). The ship waits in its cradle, the time ramp waits with it, and the departure view shows the ship you're waiting for going past.
  - A notice gives the reason: the tower's "hold in your cradle, 85 s", or at an open port, who called it first.
  - The trip's times and propellant don't change.
- **The radio:** traffic control's and other pilots' calls go to the comms log, alongside the existing chatter.
- **Waiting for a slot** (Sean, 2026-10-14: "they should wait for a slot, no moving through other ships"):
  - Every movement queues for the bay (`Traffic.sequence`). Two long-haul ships due at once take it in turn, and the port's own craft wait behind them. A ship coming in also waits `turnaround_s` (30 s) after one has gone out, so the leaver is off the axis before the next closes on the doors. Queues are worked out from `queue_lookback_s` back, so every window agrees on a ship's turn.
  - A long-haul ship still waiting for its turn when the sim has it docked keeps flying the pattern until its turn is done. The economy is unchanged.
  - Ships held for the bay queue one behind another, `separation_m` apart, first due nearest the doors.
  - A ship leaving slides sideways off the axis first (25 s), then heads away, clear of anyone waiting on the axis.
  - `tests/traffic_view.gd` flies a busy spell (two ships due at once and one leaving) and checks no ship ever passes through another.

## Performance (Oct 2026)

Long skips (time compression, a yard's days in port, a long transit, the headless tests, the balance bot) spend nearly all their time planning NPC trips. The speed-ups are exact: the same inputs give bit-identical state and events, and no number in `data/` changed. What is cached or skipped, and what must not be broken:

- **Ephemeris positions** (`sim/ephemeris.gd`). `position(id, t)` is pure in `(id, t)`. Each id is numbered on first use and remembers the last instant it was asked for, so the same body at the same `t` is found once (a shared frame body at every track step, both ends of a burn). Per-orbit constants (`_pre`: mean motion, trig of the inclination, `a*sqrt(1-e^2)`, the parent index) are derived once per id. The collinear Lagrange roots are cached per system and point. None of this is invalidated: **`bodies` and `places` are read-only once an Ephemeris is built.** If a test or tool edits their elements, build a new Ephemeris. Returned arrays are shared, so never mutate a position in place.
- **`ShipStats._sum`** skips a module that does not carry the stat (it adds exactly 0), so the wear, damage and tune lookups run only for the few modules that matter. Nothing is memoised across calls, so ship state can change freely between them.
- **NPC traders** (`npc_system._choose_trade`) decide which goods would pay at a destination (plain market arithmetic) before planning the trip there, and plan only where something would pay. The plan was only ever used for those goods, so the choice is unchanged. Keep planning free of side effects on state and RNG, or this reordering stops being exact.
- **`OrbitMech.lambert` and `kepler`** compute the Stumpff terms inline (no array or lambda per iteration), and Lambert's bisection stops once its bracket is one float wide (its remaining passes cannot change it).
- **`V` (v3.gd)** inlines `length`, `distance`, `normalized`, `lerp` and `rotate` with the same arithmetic in the same order.
- **Events** (`Sim.emit`) are trimmed in batches (at twice the cap), not by copying the whole list on every emit once nothing has drained it (headless runs). `take_events()` still returns only the newest `MAX_PENDING_EVENTS`.
- **Market integration** reads each place's market once per step.

What is left is `Navigation.plan` (about 2 ms a local trip, mostly the 97-step `_avoid_list` tracks and `solve_duration`'s bisection) and `Interplanetary.prepare`/`dress` (about 5 to 8 ms), plus `Navigation.port_tracks`. Cutting those further needs changes in `navigation.gd` and `interplanetary.gd`.

Tools: `tools/time_tests.gd` times each test function (`ONLY=test_a,test_b` to pick). `tools/determinism_hash.gd` prints hashes of `state.to_dict()` and the events after a fixed scripted game, with player route plans; run it before and after any speed change and diff the `DET` lines.

## Famous bodies and comets (Oct 2026)

Sean's direction (2026-10-15): "objects like Halley's comet and other large famous and useful real estate and resources... though I'm sure a comet might be silly to approach especially when outgassing." He chose to add all of them at once.

- **New bodies** (`tools/bake_famous_bodies.py`, orbits from JPL Horizons like every other body):
  - **Halley's Comet** (`halley`). Its next perihelion is 28 July 2061, five months into the game. It orbits backwards, so matching it is the dearest trip in the system: a prestige feat, with a badge (Once in a Lifetime).
  - **67P/Churyumov-Gerasimenko** (`comet_67p`), Rosetta's comet. Asleep for most of the decade, so it is homestead ice: land, core and mine it while it sleeps.
  - **Bennu and Ryugu**: carbon-rich, water-bearing near-Earth rocks, an easy trip from Earth. Survey, touch-and-go and a first mining site.
  - **Didymos**, with the DART crater on its moonlet Dimorphos as a heritage site (badge: We Could, So We Did). Dimorphos is not a body of its own; the site holds station over it.
- **Comets are not silly to approach, only to rush.** Rosetta orbited an active comet at 10 to 30 km for two years, and Giotto, flying through Halley at 68 km/s, lost its camera. So `sim/comet.gd` models activity, set in `balance.comets`:
  - A comet is dormant beyond `onset_au` (3 AU, where water ice starts to sublimate). Closer in, activity rises with sunlight (1/r^2), scaled so 1 is Halley at 1 AU. Each comet's `bodies.json` `activity.strength` sets its own scale (67P is 0.15).
  - A site activity's `"comet"` is `"quiet"` (land, drill: only while dormant) or `"active"` (sample the coma: only once awake). Between `quiet_below` and `active_from` a comet is "stirring", and neither is allowed.
  - `"in_coma": true` work (Halley's dive) adds risk, and dust takes condition off every module, by activity and days (`dust_wear_per_day`, capped at `dust_wear_max`).
  - The coma's radius (`coma_km` x sqrt(activity)) shows on the site screen. The system map draws an active comet's tail pointing away from the Sun.
- **News**: Halley wakes (day -12), shows to the naked eye (day 98), rounds the Sun (day 149) and goes quiet (day 420); forty years since DART (day 574, 26 September 2062).
- **Not yet**: jets and a coma in the flight view (the `plumes` data is static, so a comet's plumes would need to follow its activity), and dust noise on the scanner.

## Mars bases and the surface shuttle (Oct 2026)

Sean's direction (2026-10-17): "bases on Mars, domes etc.. with the ability for the player to get a flight to the surface and back obviously."

- **The bases** (`places.json`, `foot_of: "ares_ring"`, location type `surface`): towns your ship can't land at, each with its own market, below Ares Ring.

  | Base | Where | What it is | Flight | Fare |
  |---|---|---|---|---|
  | Jezero | the old delta, 18.4 N 77.5 E | the oldest town: six domes, the Perseverance school, a bar (the Sample Cache) | 3 h | 180 cr + 110 cr/t |
  | Candor Terraces | Candor Chasma, Valles Marineris | cliff homes, terraced greenhouses, water baked out of old salts | 2.5 h | 200 cr + 110 cr/t |
  | Hellas Deep | the floor of the Hellas basin, 42 S | aeroponic farms under the thickest air on Mars | 5 h | 260 cr + 130 cr/t |
  | Tharsis Domes | the Tharsis plateau | the greenhouse domes, open once the Tharsis greenhouses project finishes | 2.5 h | 160 cr + 100 cr/t |

- **The shuttle** (`ares_ring.shuttle`, `sim/systems/shuttle_system.gd`, command `take_shuttle {to}`): works like an elevator ride (status `shuttle`, then docked at the base), but by rocket and in hours rather than days.
  - Your ship stays docked at Ares Ring; your hold flies with you, up to the shuttle's `max_t` (20 t).
  - The fare is a seat plus so much a tonne. Down needs it in hand; the flight up goes on credit, so nobody is stranded below.
  - A base built by a project (`opens_with`) takes nobody until it is finished.
  - No job board, yard or fuel below; to fly again, take the shuttle back up.
- **The flight view** (`view/shuttle_view.gd`): a chase view of the Accord's lifting body over Mars at true size, the base's domes and pad at the mesh's pole (a vertex, so the ground there is exact). Down: waiting for the ground track, the deorbit burn, the fall, seven minutes of entry plasma, and a landing on the belly retros. Up: lift-off, the climb, the coast up and the chase to the ring. The phases run to set times from each end, so a longer flight is a longer wait in orbit. Each base's dome count and size are its `look`.
- **Badges:** Red Dust (any base) and Dome Hopper (all four).
- **Capture:** `--ride=<dir>` now also flies the shuttle to each base and back.
- **Departures from hard physics:**
  - Hellas lies south of the ring's 25 degree inclination. A real shuttle would need a costly plane change; ours waits longer for a dogleg and charges more.
  - Every flight's length is fixed per base rather than set by when the ground track next passes over it.

## The Nave (Oct 2026)

Owner's direction (2026-10-27): start building the wonders shortlist with the Nave, inside the laws of physics, folly welcome, with the minds' long view steering.

- **The place** (`places.json` `the_nave`, `foot_of: "line_foot"`): a town in the lava tube under the real Marius Hills skylight (14.09 N, 56.77 W; the pit is 60–70 m wide and 80–90 m deep). The tube is sealed and filled with air: 340 m wide and two kilometres to the first bulkhead, under a basalt roof that stops cosmic rays and the day–night temperature swing. Monks of three orders, a string quartet, glassblowers and a dozen families; a bar, the Undercroft.
  - **Light:** the skylight is glazed as a rose window. The shaft lets in sunlight only when the Sun is within about 37 degrees of overhead, which at 14 N is about five Earth days around each lunar noon. Earth stands about 32 degrees up in the eastern sky and never shows through it, hence the periscope by the altar.
  - **Market:** small. Makes handmade goods, a few collectibles and its own staples; wants ceramic feed (liner and glass), polymer feed, water, air, gene stock for its gardens, and a little wine and Earth delicacies.
- **Getting there:** your ship stays at Halo Depot. Ride the Luna Line down to Line Foot, then take **the Cooperative hopper** (`line_foot.shuttle`): 1,755 km, 1 hour door to door, 140 cr + 80 cr/t, up to 12 t. Back the same way.
  - A town can now be `foot_of` another town (the Nave below Line Foot below Halo Depot). `DataCatalog.home_port(place)` follows the chain to where your ship is, for the notices, the shuttle panel and the refusal to fly off.
- **The hop** (`view/shuttle_view.gd`): a minimum-energy ballistic arc, solved exactly (Kepler's equation by bisection): launch at about 1,357 m/s, 30 degrees above the horizon, coast 31 minutes through a 312 km apex, and land on the same burn in reverse. No wings, no heat shield: on a world without air (`look.atmosphere` absent) the view flies a four-legged lander on one engine, and an airless descent from orbit brakes on that engine rather than entering. Plasma only ever shows where there is air.
- **Where it sits:** a surface place with `facing` and `lat_deg`/`lon_deg` keeps its spot on a tidally locked world (`sim/ephemeris.gd`), measured from the point under the body it faces.
- **News:** first light in the Nave (backdated), and the Long View backing a second bulkhead while turning down a hundred-dome field above it ("use what is there").
- **Attract screen:** the caption plate's hold line can now be bound for towns below ports, the Nave among them.
- **Simplifications (RESEARCH.md §9):** the hopper's flight is always the same hour; the Moon's pole is taken as the ecliptic pole (1.5 degrees off), so Earth's wobble in the lunar sky is about 5 degrees, not the real 6.7, and there is no libration in longitude.

## The Long Breath (Oct 2026)

Wonders shortlist item 2 (WONDERS.md): a bubble of air you fly in.

- **The project** (`projects.json` `long_breath`, at the Kernel, revealed on day 20): a spindle and lamp (metal powders, machine parts, drones), the shell (carbon fibre, polymer, ceramic and glass feed), first breath (oxygen, volatiles, water ice), gardens adrift (bio feed, gene stock, staples). Backers dock free at the Long Breath and are promised wings and a place in the first race round the lamp. The Kernel now stocks carbon fibre for it.
- **The Long View's note:** it makes no new land, takes only air and fibre, and can be let down again. This is the steering hand saying yes.
- **The physics** (WONDERS.md §4): a sphere 1 km in radius at half an atmosphere, oxygen-rich; about 2.5 million tonnes of air held in by about 25 kN/m of shell tension, roughly a centimetre of carbon fibre. No spin, so no down; residents keep their bones in a spinning gym at the dock.
- **The port** (`long_breath`, opens with the project): a non-spinning dock hub (type `cylinder`, 60 m by 120 m, `spin_rpm` 0) at the bubble's pole, 10 km from the Kernel. A small flyers' town: makes wings (handmade goods) and collectibles; wants air, water, food, bio feed and a little luxury. Bar: the Thermal. Its tender *Updraft* (fleet `breath_tenders`) commissions with it. Auntie Vell's tips cover it.
- **Set pieces** (`set_pieces.gd` `_long_breath`): from the Kernel, the bubble grows stage by stage; from its own dock (`long_breath_dock`), the finished bubble lies straight beyond the docking face.
- **Attract screen:** a new title shot, `long_breath`: the hero glides past the bubble, the lamp burning at its heart.

## Venus: Cytherea Station and Aphrodite's Rest (Oct 2026)

Wonders shortlist item 3 (WONDERS.md): a city that floats, which opens Venus.

- **Cytherea Station** (`places.json` `cytherea_station`): the Venus up-port, a wheel 400 km up, run by a new operator, the **Cytherean Assembly** (pale gold livery). Market and fuel, no yard. Fuel is dear: Venus has almost no hydrogen, and the port cracks a little propellant from the clouds' sulphuric acid (a volatiles recipe).
- **Aphrodite's Rest** (`aphrodites_rest`, `foot_of` the station): five envelopes of breathable air floating 55 km up at 10 N, where the air is half an atmosphere and about room temperature, drifting round the planet with the clouds every four days (a surface place with `radius_m` above the ground and a retrograde `day_s`). Gravity 0.9 g. Makes carbon fibre and oxygen from the CO2 air, staples, collectibles and handmade goods; wants water above all, plus parts, drones, optics, medicine, gene stock and a taste of home. Bar: the Downdraft.
- **The glider** (`cytherea_station.shuttle`): 4 h, 420 cr + 260 cr/t, up to 10 t. The dearest ride in the inner system, because the climb back to orbit from a 0.9 g world takes about 8 km/s. The flight view (`shuttle_view.gd`) now puts the world's centre below the base's real height, so a floating city isn't drawn on the ground, and draws its envelopes, gondolas and walkways round the landing deck (`look.kind` `aerostat`).
- **Traffic:** the Assembly's two deep freighters, *Morning Star* and *Evening Star* (`cloud_runners`), run carbon fibre and oxygen to Clarke Exchange and bring water, gene stock and delicacies back from Kibo Ring.
- **News:** three years aloft (and the Long View's condition: make your own carbon and oxygen from the air), and the first wedding over Venus.
- **Simplifications (RESEARCH.md §10):** the city drifts at one steady rate at one latitude; the glider's flight is always four hours.

## Ice tugs and pushers (Oct 2026)

Wonders shortlist item 6 (WONDERS.md): icebergs pushed in from the Belt for the ports that are short of water.

- **The trade** (`balance.bergs`, `sim/systems/economy_system.gd` `_bergs`): bergs of water ice from the Themis family in the outer Belt, pushed for years by pushers that throw the berg's own melted ice as reaction mass, are parked off three dry ports and quarried:

  | Berg | Port | Lands on the market | Berg mass | First | Then every |
  |---|---|---|---|---|---|
  | Slow Tide's | the Kernel (L5) | 300 t | 24,000 t | day 11 | 45 days |
  | Meltwater's | Psyche Claims | 120 t | 9,000 t | day 23 | 50 days |
  | Long Thirst's | Cytherea Station (Venus) | 150 t | 15,000 t | day 34 | 60 days |

  Each arrival puts its tonnes on the port's market at once (never past the market's cap), so water is cheap there for a while, then the stock relaxes back. Arrivals are worked out from the clock (`berg_count`), so nothing new is saved and old saves see the schedule from their start.
- **News:** each arrival is a notice and a comms line ("The pusher Slow Tide has parked a 24,000 t berg from the Themis family off the Kernel: 300 t of water ice on the market.").
- **Set piece** (`set_pieces.gd` `_ice_berg`, feature `ice_berg` at the three ports): the parked berg with its pusher still bolted on astern, and a quarry crawler cutting blocks on its face.
- **Attract screen:** a new title shot, `berg`: a berg under way in the outer Belt, its pusher throwing a plume of steam, the hero flying escort.
- **Supply runs** (owner's choice, 28 October 2026): the berg *Slow Tide* is a site in solar orbit (`sites.json` `slow_tide_berg`), on its way in from the Belt: about 2.2 AU from the Sun at the start, closer each month. Fly out with 3 t of staples, 0.3 t of medicine and 1 t of machine parts and its crew takes them (`takes`, out of the hold with their cost basis), pays 12,000 cr and 2 standing with the Belt Assembly, and fills your hold with 3 to 6 t of its ice. They want it again every 60 days (`every_days`: a standing job, remembered in `state.sites.last`). A long-haul ship can plan the trip; the news carries the crew's call for supplies.
- **Meeting the pushers** (owner's choice, 28 October 2026): in space you don't pass another ship by chance; you meet one by matching its course. Three pushers can be met, each a berg site in solar orbit with its crew and a supply run:

  | Pusher | Bound for | Path | At the start | Crew wants | Pays |
  |---|---|---|---|---|---|
  | *Slow Tide* | the Kernel | Themis (3.1 AU) to Earth's orbit, e 0.51 | 2.21 AU | staples, medicine, machine parts | 12,000 cr, Belt Assembly |
  | *Long Thirst* | Venus | Themis to Venus's orbit, e 0.63 | 2.40 AU | staples, medicine, delicacies | 14,000 cr, Cytherean Assembly |
  | *Meltwater* | Psyche Claims | across the Belt, Themis to Psyche, e 0.03 | 3.08 AU | machine parts, medicine, delicacies | 16,000 cr, Belt Assembly |

  On site (`view/site_view.gd`, kind `berg`) the berg is a few hundred metres off, its pusher still firing a plume of its own melted ice, the crew's cabin and spin drum on the pusher's frame. Each crew's call for supplies is in the news.

## Hammerhead stations (Oct 2026)

Wonders shortlist item 7 (WONDERS.md): a working port built like a long-haul ship, people at one end and the reactor at the other.

- **The type** (`station.type` `hammerhead`, `view/flight/models.gd` `_spine`): a spinning drum head with the docking port on its forward face (the settlement drum, so bays, windows and the docking face all work as before), then a still spine (`station.spine_m`, default 1,200 m) of truss and tank clusters, a shadow shield, the fusion plant and its radiator fins. The spine doesn't turn with the head, and it registers its own colliders.
- **Huygens Port** is the first: a head 80 m in radius and 160 m long, spinning at 1.67 rpm for 0.25 g (under the roughly 2 rpm people tolerate comfortably), with a 1.2 km spine. It docks in the trial like every other port.
- **Attract screen:** Huygens joins the title's docking shot, over Titan's haze with Saturn beyond.

## The Long Hall (Oct 2026)

Wonders shortlist item 4 (WONDERS.md): a roof over a canyon.

- **The project** (`projects.json` `long_hall`, at Ares Ring, revealed on day 40): anchors in the rim (machine parts, drones), the first span (carbon fibre, ceramic feed, polymer), sealed and filled (oxygen, volatiles, water), rivers and fields (gene stock, staples). Ares Ring now stocks carbon fibre and ceramic feed for it. When done, Ares Ring's flows rise by a tenth.
- **The Long View:** backed it on one condition, that it stay narrow. An earlier plan to roof Coprates Chasma, a hundred kilometres across, was turned down (the news says so).
- **The town** (`long_hall`, `foot_of` Ares Ring, opens with the project): ten kilometres of a canyon in Noctis Labyrinthus (7 S, 101 W), two kilometres wide and one deep, under a clear roof at half an atmosphere. A river, fields, orchards and the first Martian vineyard. Makes staples, wine, handmade goods and collectibles; wants water, parts, drones, medicine, polymer, storage and a little Earth food. Bar: the Echo. The Accord shuttle lands outside its eastern doors (3 h, 210 cr + 110 cr/t).
- **Flight view:** `look.kind` `canyon`: the pad outside the end wall and doors, the cliffs, the anchored roof on its cable net, and the fields and river inside.
- **Physics:** RESEARCH.md §12 and WONDERS.md: the roof's tension is pressure times curve radius, so it bulges up between the rims and is anchored down; only a narrow canyon keeps it to a few centimetres of carbon fibre.

## The Ceres megasatellite (Oct 2026)

Wonders shortlist item 5 (WONDERS.md), after Pekka Janhunen's proposal.

- **The project** (`projects.json` `ceres_megasat`, at Piazzi Station): announced only when the Concord Pair is finished (`reveal.after_stage`). Five stages: the frame and its slag shield, then four cylinders, each for a different people: a canal town (a Venetian quarter), a pine forest, a desert monastery and an all-night quarter. Backed by the Belt Assembly; when done, Piazzi's flows rise by a fifth.
- **The Long View's rule:** no cylinder bigger than its people can fill. Built from Ceres's own rock, with its nitrogen for the air.
- **Set piece** (`set_pieces.gd` `_megasatellite`, feature `megasatellite` at Piazzi): a 60 km frame 260 km out, facing the Sun, and one cylinder (10 km long, 1 km radius) for each stage after the frame, each turning once every 66 s (0.92 g at its hull). Nothing shows until work starts.
- **Not yet:** a port of its own; the cylinders are seen, not visited.

## Mercury: Perihelion Station and Terminator (Oct 2026)

Wonders shortlist item 8 (WONDERS.md), after Kim Stanley Robinson's *2312*.

- **Perihelion Station** (`perihelion_station`): Mercury's up-port, in a near-polar orbit 400 km up, run by a new operator, the **Dawnward Company** (grey with orange). Ships iron, nickel and platinum smelted with free sunlight (metal powders, platinum metals) and makes propellant from polar-crater ice; wants food, air, parts, drones, ceramic feed and a little luxury. Its two freighters, *First Light* and *Long Morning* (`dawn_runners`), run platinum to Kibo Ring and bring food and electronics back.
- **The project** (`terminator_rails`, revealed day 60): rails across the night (metal powders, machine parts), the Dawn Wall (ceramic feed, carbon fibre), domes and gardens (oxygen, water, gene stock), underway (drones, compute cores). The Long View's condition: the rails go round once, and no mine strays more than a kilometre from the rail bed.
- **Terminator** (`terminator`, opens with the project): a city on twenty rails at 45 S, held 92 degrees round from the point under the Sun (a surface place `facing` the Sun with `lat_deg`/`lon_deg`), so it stays a few dozen kilometres into the dark behind the dawn line and goes round with it: about 2.6 km/h, once every 176-day solar day. Electric motors drive it; the novel's thermal-expansion drive is local folklore. Bar: the Dawn Wall. The Dawnward lander (`perihelion_station.shuttle`, 3 h, 300 cr + 150 cr/t) brakes all the way down on its engine (Mercury has no air), and the flight view draws the rails, the platform and its domes, and the Dawn Wall (`look.kind` `rail_city`).
- **Simplifications:** the station's orbit is drawn as passing over the dawn line whenever a lander flies (a real near-polar orbit lines up with it only twice in each Mercury year); the city keeps an exact pace with the terminator where real rails would follow the ground.

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

- Player identity: a custom name and portrait? The backstory direction is drafted in *Who you are: a Third for the Sky*.
- How much should the co-pilot speak? Writing and voice budget.
- Should a ship be lost permanently? Leaning to "insurance + setback", not permadeath.
- ~~Art direction~~: decided. Workmanlike modular hardware, see "Art direction".
