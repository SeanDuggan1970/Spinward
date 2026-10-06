# Balance report, 6 October 2026 (cloud run)

Written by an unattended cloud session after the Oct 2026 expansion (outer-system traffic, elevators, collisions and insurance, projects and pitches, the Spaceline). **No balance numbers were changed.** Section 6 lists suggested changes for the owner to accept or reject.

The tables here come from `tools/balance_bot.gd` and the new `tools/balance_probe.gd`, run headless on Godot 4.7.2 on the `cloud/tests-balance` branch (the new tests and the two bug fixes are in commits `ea3a9c2`, `bc6131b` and `3a0c1e7`; the bot options and the probe are in the commit after them). Every number can be reproduced with the commands in section 7.

## Headline findings

1. **Income is flat, not compounding.** A stock Mule trading cislunar earns about 1,450 cr/day for the first 60 days, then settles at about 1,000 cr/day (6 seeds, 365 days, no upgrades): 55k at day 30, 95k at day 60, 217k at day 180, 394k at day 365.
2. **Cargo pods and tanks do not pay for themselves.** With 100k credits in hand, two 35 t pods (+164k of modules, net of the pods they replace) added 5k over 90 days (±14k, 10 seeds). A trade of more than about a quarter of a port's stock moves the price against you, so a bigger hold mostly makes you trade worse. The Mk2 drive added about +11k per 90 days (±18k) and the full Mk3 fit (+666k of modules) about +53k per 90 days (±15k). Paybacks run from about 1,000 to more than 2,500 game days.
3. **The upgrade ladder is affordable, but its steps are not worth taking.** A player with no reserve can buy a 30k pod on day 5, a 120k Mk2 on day 78, and a 265k Prospector refit on day 251. At about 1,000 cr/day, the 450k Mk3 arrives near day 420 and the 675k Outer fit near day 650. The outer fits then earn *less* per day than the stock Mule does at home.
4. **Outer-system freight pays less per day than cislunar trade on every route measured.** A Mars or Ceres round trip with a fitted-out ship earns 150 to 860 cr/day (the best, Trojan Yards to Ares Ring, is 1.2 to 1.7 times worse than home; most are 3 to 8 times worse), against about 1,000 to 1,450 cr/day for the 29k stock ship at home. Long-haul courier boards (about 100 to 160k for 100 quick days, 1,000 to 1,550 cr/day) are the one outer income that matches home, and they need the 675k fit to hit their deadlines.
5. **At least five of twelve projects stall for lack of a good that their port does not hold.** After 365 game days with no player help, Ares Greenhouses is at 0% and the Pavonis Line is at 1%, so the Pavonis elevator cannot open. The Concord Pair is stuck at 17%, Lightfoot Sails at 34%, and Kalpana Two at 37%. Each is short of machine parts, habitat modules or oxygen that no NPC brings in.
6. **The bot's plans are 36% too rosy.** Over 482 trade legs, the planned profit was 4,839 cr and the real profit was 3,104 cr. Legs leaving The Kernel, Kalpana One, Trojan Yards and Clarke Exchange lose 2 to 5k against plan; legs leaving Kibo Ring and Halo Depot match their plan. 27% of all legs lose money.
7. **No money loops.** No pair of ports pays both ways on the same good. A same-port buy and sell-back loses at least 5.8% (the spread is 6%). The Luna Line round trip *loses* money. The Piazzi Stalk shuttle earns about 1,230 cr/day for a stock hold: in line with home trade, not a fountain.
8. **The "first upgrade day" statistic is too noisy to steer by.** Across commits since 5 October, with an identical bot, the median swings between day 14 and day 38. It reads 28.7 on this branch (8 seeds), against a documented target of 11 to 17. The same bot with upgrades *off* ends with twice the credits (218k vs 109k at day 180), because its upgrade list does not pay back.
9. **Two real bugs were found by the new tests and fixed** (separate commits): a story favour could become impossible to take after being abandoned, and a pilot could be stranded at the foot of an elevator.

## 1. Earnings curves

### Stock Mule, no upgrades, 6 seeds, 365 days (`upgrade=0`)

| Day | Mean credits | Min | Max |
|---|---|---|---|
| 0 | 10,000 | | |
| 30 | 55,218 | 45,140 | 75,229 |
| 60 | 95,446 | 86,435 | 110,150 |
| 90 | 131,285 | 97,820 | 151,699 |
| 120 | 152,058 | 112,516 | 178,501 |
| 180 | 217,321 | 171,271 | 259,306 |
| 270 | 302,908 | 271,539 | 370,672 |
| 365 | 393,820 | 346,167 | 464,986 |

| Days | Profit per game day |
|---|---|
| 0–60 | 1,456 |
| 60–120 | 975 |
| 120–180 | 1,119 |
| 180–270 | 986 |
| 270–365 | 997 |

The first 60 days are faster because the economy opens with its margins at the price ceiling (see below). After that the curve is a straight line: more capital earns nothing more.

**Day one.** From Kibo Ring, 20 t of food to Kalpana One earned +16.1k on day 0.6 (10k became 26k, seed 1). The "first profitable trade on day one" target holds, and more than holds: all of the top 12 start-of-game margins are 225 to 227% of base price, about the most the curve allows (`price_max_mult` 3.0 against `price_min_mult` 0.4, less the 6% spread).

### The default bot (upgrades on)

| Run | Mean end credits | Median first upgrade |
|---|---|---|
| 180 days, 8 seeds | 108,583 | day 28.7 |
| 360 days, 5 seeds | 67,630 | day 28.7 |
| 180 days, upgrades off, 5 seeds | 209,189 | none |

At 360 days the credits are *lower*: in seed 1 the bot buys the 120k Mk2 on day 202 (credits fall from 152k to 35k in 9 days) and two more 90k 35 t pods on days 292 and 322, and the curve then climbs at the same ~1,000 cr/day. The module value is not counted as credits, but these are the items measured in section 3 as barely paying back.

### Newer content does not shift cislunar income measurably

Each row removes some fleets (`nofleets=`) or all project demand (`draw_t_per_day` 0, in a scratch copy of `data/`). 180 days, upgrades off, 6 seeds. The standard error is about 12k, so every difference below is within noise.

| Change | Mean end credits |
|---|---|
| Nothing removed (baseline) | 218,291 |
| Outer fleets removed (Accord runners, Belt haulers, Psyche ore, Saturn tender, Lightfoot, Sufficiency tender) | 224,613 |
| Elevator climbers removed (Luna, Stalk, Pavonis) | 226,708 |
| Luna Kestrels removed | 242,256 |
| Compact heavies removed | 237,071 |
| All of the new fleets above removed | 233,276 |
| All project draws set to zero | 202,632 |

The signs are mildly negative for the new fleets (removing them gives +3 to +11%) and mildly positive for projects (their demand is worth about +8%), but none is distinguishable from noise. A commit-by-commit comparison from 5 October to today (same bot from `14af7a1` on) gave mean credits of 96k, 116k, 102k, 109k and about 115k at day 180, with the median first upgrade moving 37.5, 22.6, 27.0, 14.2 and 28.6 days. Nothing there points at one change.

## 2. Routes

Totals are over the 6 seeds of the no-upgrade run (824 legs, 2.39M credits of profit). "Per day" is profit per game day of travel on that route.

### Best routes

| Route (good) | Legs | Total profit | Per leg | Per day |
|---|---|---|---|---|
| Kalpana One → The Kernel (medical supplies) | 46 | 363,718 | 7,906 | 2,532 |
| Kibo Ring → Kalpana One (food) | 56 | 289,882 | 5,176 | 1,761 |
| Kibo Ring → Clarke Exchange (food) | 33 | 238,507 | 7,227 | 2,474 |
| Kibo Ring → Clarke Exchange (machine parts) | 28 | 205,472 | 7,338 | 3,215 |
| Kibo Ring → Trojan Yards (electronics) | 7 | 105,589 | 15,084 | 4,531 |
| Trojan Yards → Farside Array (electronics) | 12 | 100,010 | 8,334 | 3,650 |
| Shackleton Port → Trojan Yards (electronics) | 24 | 91,979 | 3,832 | 1,113 |

The best destinations (The Kernel, Kalpana One, Clarke Exchange) are all project sites (Island One, Kalpana Two, Lightfoot Sails), but zeroing every project's draw moved the bot's income by only -7% (not significant), so project demand is a tailwind, not the driver; see section 5.

### Worst routes

| Route (good) | Legs | Total profit | Per leg |
|---|---|---|---|
| The Kernel → Trojan Yards (habitat modules) | 5 | -67,594 | -13,518 |
| Trojan Yards → Shackleton Port (machine parts) | 7 | -34,687 | -4,955 |
| Trojan Yards → The Kernel (habitat modules) | 2 | -20,408 | -10,204 |
| Clarke Exchange → Trojan Yards (food) | 4 | -13,871 | -3,467 |
| Kibo Ring → Kalpana One (electronics) | 2 | -13,490 | -6,745 |
| The Kernel → Kalpana One (machine parts) | 4 | -12,645 | -3,161 |
| The Kernel → Shackleton Port (medical supplies) | 4 | -10,706 | -2,676 |

224 of 824 legs (27%) lost money, for -722k in total. Habitat modules are the worst good: planned +5,517, actual -1,335 per leg. Planned vs actual by origin (482 trade legs, 4 seeds):

| Leaving | Legs | Planned | Actual | Gap |
|---|---|---|---|---|
| The Kernel | 31 | 2,683 | -2,448 | -5,132 |
| Kalpana One | 82 | 6,552 | 3,542 | -3,010 |
| Trojan Yards | 78 | 5,905 | 3,080 | -2,825 |
| Clarke Exchange | 75 | 2,762 | 519 | -2,243 |
| Shackleton Port | 62 | 3,566 | 2,873 | -692 |
| Farside Array | 15 | 2,955 | 2,511 | -444 |
| Halo Depot | 39 | 4,059 | 4,031 | -28 |
| Kibo Ring | 100 | 6,204 | 6,295 | +90 |

Between planning and arrival (2.7 game days on average) transient price spikes relax by about 14% (`relaxation_per_day` 0.055), NPC freighters land, and projects draw their stock. The bot trades on perfect live information, so a human working from stale knowledge and paid tips (see DESIGN, Information) should expect worse. Treat the bot as a ceiling for information, and a floor for cleverness.

Other route facts:

- Legs that fill the 20 t hold: 55% (mean load 15.5 t). Electronics (9.9 t) and medical supplies (6.0 t) are limited by stock and cash, not by the hold; food and machine parts fill it (18.6 t and 19.5 t).
- Profit per leg does not rise with load: loads under 10 t average 3,249, 10 to 20 t average 2,538, and 20 t and over average 3,684.
- 103 of 824 legs (12%) were empty repositioning legs at -60 each; Clarke Exchange (39) and The Kernel (39) start three quarters of them.
- The bot's profit by good: food 521k, electronics 316k, machine parts 297k, medical supplies 285k, propellant 62k.

## 3. How quickly can a player afford each drive and refit?

Days until cash on hand reaches the price, if the player buys nothing else (median of 6 seeds, no-upgrade bot, the 29k stock ship). The second column keeps the bot's 15,000 credit reserve.

| Item | Price | Day (no reserve) | Day (+15k reserve) |
|---|---|---|---|
| Docking computer | 15,000 | 0 | 5 |
| Propellant tank M | 18,000 | 0 | 5 |
| Cargo pod M | 30,000 | 5 | 15 |
| Radiator array, survey pod | 30,000 | 5 | 15 |
| Hab, extended | 45,000 | 15 | 36 |
| Propellant tank L, cargo cradle | 60,000 | 36 | 47 |
| Mining rig | 70,000 | 45 | 55 |
| Lander bay | 85,000 | 55 | 65 |
| Cargo pod L | 90,000 | 58 | 71 |
| Pathfinder Mk2 | 120,000 | 78 | 90 |
| Mars runner refit (tank L, pod M, tank M) | 116,000 | 78 | 89 |
| Prospector refit (lander, tank L, Mk2) | 265,000 | 251 | 259 |
| Pathfinder Mk3 | 450,000 | about day 420 (1 of 6 by 365) | |
| Outer refit (Mk3, 2 x tank L, hab, arrays) | 675,000 | about day 650 (0 of 6 by 365) | |
| Freighter refit (2 x pod L, tank L, Mk3, arrays) | 750,000 | about day 720 (0 of 6 by 365) | |

Mk3 and later rows extrapolate the 365-day mean of 394k at 1,000 cr/day. A hoarding player who buys nothing before the Outer refit reaches it in the second game year.

### What does each module earn back?

The bot starts with 100,000 credits and a free fit, no upgrades, 90 days, 10 seeds (`credits=100000 fit=...`). End credits, in thousands. The standard error is about 9 to 14k per row, so differences under about 25k are noise.

| Fit (module value added) | Mean end credits | Gain vs stock | Payback |
|---|---|---|---|
| Stock Mule | 230.7k | | |
| 2 x cargo pod L, 35 t each (+164k) | 236.2k | +5k (about +60/day) | more than 2,500 days |
| Mk2 drive (+120k) | 242.0k | +11k (about +120/day) | about 1,000 days |
| Mk3, 2 x pod L, 2 radiator arrays (+666k) | 283.7k | +53k (about +590/day) | about 1,100 days |

With 4 seeds: 2 x pod M 208k, tank M 209k, tank L 204k, all within noise of the stock ship (212k at 4 seeds). The no-reserve 10k start earns less than the 100k start (126k vs 213k end credits at 90 days, 4 seeds), so *early* progress is cash-limited, and later progress is stock-limited.

Pacing against the notes' target (11 to 17 days to the first upgrade): a player with no reserve can buy a pod M on day 5 and a tank L on day 36. The bot's median of 28.7 comes from its 15k reserve rule plus the noise in that statistic (headline 8).

### Why a bigger hold does not help

The price is the exact integral of a curve with elasticity 0.7, so each tonne you buy costs more than the last and each tonne you sell fetches less. How much of a port's stock the bot takes per trade (`take=`) changes its 90-day end credits for the stock ship:

| take | 0.1 | 0.15 | 0.2 | 0.3 | 0.5 (default) | 0.9 |
|---|---|---|---|---|---|---|
| End credits (stock ship) | 260k | 281k | 268k | 273k | 231k | 215k |

At 0.9, the 2 x pod L fit ends at 165k, 50k *behind* the stock ship. The best take is about 0.15 to 0.3, which is 18 to 22% better than the bot's default, and at those loads a 20 t hold is mostly enough. (At take 0.2 the 2 x pod L fit did end 25k ahead of the stock ship, 293k vs 268k, about two standard errors; at 0.3 it was +5k.) This price impact is the mechanism behind the flat curve in section 1.

## 4. Dead ends and exploits

**Money loops: none found.** (`balance_probe.gd` section `loops`.)

- No pair of ports pays on the same good in both directions (0 pairs).
- A buy and an immediate sell-back of 5 t at one port loses at least 5.8%, near the 6% spread.
- The Luna Line round trip with a full hold (550 cr fare) nets -1,100 at day 0 and -272 at day 60: it is tourism, not trade.
- The Piazzi Stalk looks like a fountain on paper (+8,160 net per round trip at day 0, 14 hours), but its foot holds only about 16 t of machine parts. A 60-day shuttle with a stock hold (teleported to Piazzi, 206 rides) earned 1,229 cr/day. That matches cislunar income, so it is no exploit.

**Ports with little to carry out** (paying destination-and-good pairs, best margin, day 0): Psyche Claims 6 (48% of base), Kernel 12 (187%), Clarke Exchange 13 (56%), Huygens Port 17 (201%), Shackleton Port 19 (231%). The Kernel and Clarke Exchange are the dead ends the bot hits most often: they top the list of empty repositioning legs.

**Routes that never pay** (outer freight, day 0 prices, Freighter fit, round trip): Kibo Ring or Trojan Yards to Plume Watch earns -7 to -20 cr/day (a 164 to 171 day trip, with only 3.5k of food out and oxygen worth 16 back). Plume Watch buys five goods and sells none, so every visit is one way. Valhalla Station from Trojan Yards cannot be flown home at all with a 120-day crew, and from Kibo Ring it pays only 290 cr/day over 204 days.

**Small exploits and oddities in the new systems**

1. **A patch can cost more than a full repair.** At a port without a yard, `patch_mult` 1.6 is charged on the damage above `patch_max` 0.25, so it exceeds the yard price (`repair_cr_per_point` 0.6 on all the damage) once damage passes 0.67. A 12 m/s knock on the tail: yard 5,063 cr, patch 5,222 cr, and the patch leaves 25% damage.
2. **Ramming a stock Mule is cheaper than repairing it.** `insurance_excess` 3,000 buys a clean stock hull with full tanks. Repairing keel damage above 0.56 at a yard costs more than that. Any hit of about 10 m/s or more on a stock ship costs more to repair (3.1 to 5.7k) than the wreck (3k plus lost cargo). A fitted ship loses its modules on a wreck (326k for the 2 x pod L, Mk2, tank M fit), so the exploit is only for a stock hull.
3. **A wreck dodges the penalty for a late job.** A carried job lost in a wreck is closed as "lost" with no standing cost, while failing the same job costs -8 with the client. Fixing it needs code, not data.
4. **Impact damage ignores ship mass.** `full_j_per_kg` is per kilogram of ship, so a 70 t freighter and a 20 t Mule take the same damage at the same speed, and every zone wrecks at 13.7 m/s. That is simple, but it means a bigger hold has no collision cost.
5. **Story favours.** Fixed on this branch: abandoning one made it permanently untakeable (see the bug commits).

## 5. How the newer content affects progression

### Outer-system traffic

Fleets: Mars Accord runners (Ares Ring to Kibo Ring), Belt Assembly haulers, an ore ship, a Titan to Callisto tender, Lightfoot sails, the Sufficiency's tender. They commission over the first half-year.

- Removing them all moves cislunar income by +15k (n.s.). They hardly touch the home economy.
- They do not supply the places that need goods most. Ares Ring consumes 3 t/day of machine parts and holds nothing above its reserve, so the Accord runners (2 ships) are not enough, and the player is effectively the only supplier for its projects.
- For a player, outer freight (day 0 prices, 20 t Mars runner, 70 t Freighter, 35 t Hauler, round trip):

| Fit (modules) | Route | Days | Profit per run | Per day |
|---|---|---|---|---|
| Hauler (705k) | Trojan Yards ↔ Ares Ring | 68 | 58,460 | 864 |
| Freighter (750k) | Trojan Yards ↔ Ares Ring | 68 | 52,543 | 772 |
| Hauler | Kibo Ring ↔ Ares Ring | 70 | 48,593 | 689 |
| Mars runner (116k) | Trojan Yards ↔ Ares Ring | 115 | 59,709 | 519 |
| Mars runner | Kibo Ring ↔ Ares Ring | 122 | 49,745 | 408 |
| Hauler | Kibo Ring ↔ Valhalla Station | 203 | 67,290 | 331 |
| Freighter | Kibo Ring ↔ Huygens Port | 164 | 50,243 | 306 |
| Hauler | Kibo Ring ↔ Piazzi Station | 136 | 41,757 | 306 |
| Mars runner | Kibo Ring ↔ Piazzi Station | 206 | 33,902 | 164 |

Compare about 1,000 to 1,450 cr/day for the stock Mule at home. Ares Ring is the best outer market (it pays for habitat modules and machine parts, which Trojan Yards and Kibo produce) and the one where the player is most needed.

- **Courier boards** (after 30 days at Kibo Ring, quick-plan days): long-haul jobs pay 157,350 (Huygens Port, 101 d, 1,557 per day), 117,650 (Valhalla Station, 108 d, 1,090 per day) and 106,550 (Plume Watch, 102 d, 1,041 per day). They need standing 12 and a long-haul reference ship (Mk3, tank L, hab, arrays: about 675k of modules). A local package pays 3.3 to 4.7k for 0.5 to 2.8 days (1,700 to 6,600 per day) and a passenger job pays 5.4 to 8k, so **local couriers out-earn outer couriers per day**.
- **Sites:** surveys pay 26k (Eros, 6 d on site), 22k (Phobos, 4 d) and 90k (Hektor, 10 d), each after 100 to 200 days of travel (about 500 cr/day for Hektor). Hermes-7 pays 18k for one day. The Lacuna pays 500k at the end of the Long View arc, once.

### Elevators

| Line | Fare (full 20 t hold) | Ride | Round-trip net, best goods, day 0 / day 60 |
|---|---|---|---|
| Luna Line (Halo Depot ↔ Line Foot) | 150 + 20/t = 550 | 56 h | -1,100 / -272 |
| Piazzi Stalk (Piazzi Station ↔ Stalk Foot) | 80 + 12/t = 320 | 7 h | +8,160 / +8,978 |
| Pavonis Line (Ares Ring ↔ Pavonis Foot) | 600 + 45/t = 1,500 | 120 h | +9,254 / +8,813 (up only) |

- Fares are in a sensible band against the margins on offer: the Stalk's is 4% of its round-trip margin and the Pavonis Line's 24%.
- The foot's stock is small (about 8 t of the best good), so the Stalk's real, sustained gain is 1,229 cr/day (60 days, 20k start, 206 rides). It is fine.
- The Luna Line has no economic use: it is for the view, and the foot's market buys at roughly the port's prices.
- **The Pavonis Line is gated by hauling.** Its first stage needs 50 t of machine parts, 20 t of habitat modules and 2 t of deuterium, and all three stages together need 312 t. A Mars runner carries 20 t per 115-day round trip, so the line cannot open without a long-haul freighter's worth of effort by the player.
- **The stranded-at-the-foot bug** (fixed on this branch) meant a pilot with under 150 cr at Line Foot could never return.

### Collisions and insurance

Damage per impact (`full_j_per_kg` 50, `safe_mps` 0.8, `keel_share` 0.35). A stock Mule, any zone:

| Closing speed | Module damage | Keel damage | Yard repair (module in the nose, tail or side) | Yard repair (cargo pod) | Patch (no yard) |
|---|---|---|---|---|---|
| 2 m/s | 0.01 | 0.01 | 53 to 61 | 96 | 0 |
| 3 m/s | 0.05 | 0.02 | 178 to 207 | 323 | 0 |
| 5 m/s | 0.18 | 0.06 | 650 to 756 | 1,180 | 0 |
| 8 m/s | 0.52 | 0.18 | 1,912 to 2,223 | 3,468 | 772 to 2,061 |
| 10 m/s | 0.85 | 0.30 | 3,123 to 3,631 | 5,662 | 2,117 to 4,979 |
| 12 m/s | 1.25 | 0.60 | 5,063 to 5,663 | 8,063 | 5,222 to 8,822 |
| 14 m/s | 1.74 | wrecked | - | - | - |

- A 5 m/s knock costs a quarter to a third of one trade leg (3.1k average). A 10 m/s hit costs one to two legs. Wrecking takes 13.7 m/s in a single blow, in every zone, for both fits tried (stock, and Mk2 + 2 pod L + tank M).
- Insurance costs a flat 3,000 and a stock hull. That is cheap against a 3 to 8k trade leg, but costs a fitted ship all of its modules, and it should be the thing that deters a careless pilot.
- Collisions do not shift progression numbers while the pilot flies carefully (the docking trial has 0 contacts at all 17 ports). A 5 m/s knock costs about half a day's income for the stock ship.

### Projects and pitches

Passive progress with no player help (the player's hauling is the only way to move the rest). Day 365:

| Project | Place | Needs | Passive result |
|---|---|---|---|
| Luna Line, second ribbon | Halo Depot | 124 t | done by day 180 |
| Landauer Deep, second core | Landauer Deep | 161 t | done by day 365 |
| Selene Ring | Shackleton Port | 752 t | done by day 365 |
| Tsiolkovsky Wheel | Trojan Yards | 788 t | stage 2 of 4 (68%): short of regolith (288/400) |
| Island One | The Kernel | 733 t | stage 2 of 4 (62%): short of water ice and oxygen |
| Hektor Reach | The Kernel | 574 t | stage 1 of 3 (66%): short of water ice (115/120) |
| Valhalla Deep Ring | Valhalla Station | 303 t | stage 1 of 3 (52%): short of machine parts (0/40) |
| Kalpana Two | Kalpana One | 356 t | stage 1 of 3 (37%): short of habitat modules (0/90) |
| Lightfoot Sails | Clarke Exchange | 85 t | stage 0 of 2 (34%): short of oxygen (4/20) |
| Concord Pair | Piazzi Station | 773 t | stage 0 of 4 (17%): short of machine parts (0/50) |
| Pavonis Line | Ares Ring | 312 t | stage 0 of 3 (1%): short of machine parts (0/50), habitat modules (0/20) |
| Ares Greenhouses | Ares Ring | 238 t | stage 0 of 3 (0%): short of habitat modules (0/40), machine parts (0/30) |

- The goods a project needs reach up to 2.9 times base price at its place (Island One, Hektor Reach, Pavonis, Concord and others), so hauling for projects pays well and also earns the backer perks. But removing all project draw moved the bot's income by only -7% (n.s.).
- **The perks are small in credits.** Free docking saves 60 cr per dock (a leg earns 3k). A 15 to 25% fuel discount at one port saves tens of credits per refuel for a stock Mule. The first perk needs 6 to 15 t hauled, which is one run. Standing and invitations matter more than the credits, which suits the design.
- The Spaceline's world stories raise output at Psyche Claims (1.3x, then 1.1x), Piazzi Station (1.15x, then 1.1x) and Ares Ring (1.1x). The cislunar economy is untouched.
- The Spaceline itself has no measurable effect on progression.

## 6. Tuning suggestions (data only)

Nothing here has been applied. "Tested" means the effect was measured by the bot in a scratch copy of `data/` and not committed; "untested" is reasoning from the tables above.

| # | File | Key | Current | Suggested | Reasoning |
|---|---|---|---|---|---|
| 1 | `data/modules.json` | `cargo_pod_m.price` | 30,000 | 15,000 | Pods earned back nothing in 10 seeds (section 3): 2 x pod M at 4 seeds gave 208k vs 212k stock. Half the price puts the payback within reach if the owner wants a hold to be a first purchase. Skip this if suggestion 2 is taken instead. |
| 2 | `data/places.json` | `produces` of `food`, `machine_parts`, `electronics`, `medical` at every port that makes them | e.g. food at Kalpana, machine parts at Trojan | x2 | **Tested.** Gives deeper supply, so a bigger hold can be used: with `take=0.3`, the 2 x pod L fit ended at 368k against 303k for the stock ship (+65k per 90 days, about +720 cr/day, 4 sigma; payback about 250 days), where before it was +5k. The cost: the stock ship's 90-day gain rises about 48% (131k to 194k, end credits 231k to 294k), so pair it with suggestion 6. Doubling market *targets* instead was tested and made income worse (168k stock, 126k pod L), as did lowering `economy.price_elasticity` to 0.5 (188k). Do neither. |
| 3 | `data/modules.json` | `pathfinder_mk2.price` | 120,000 | 70,000 | Measured +120 cr/day (+11k per 90 days, n.s.), payback about 1,000 days. A 70k price brings it to about 600 days. Speed is the only benefit, so the price is the lever. Low confidence. |
| 4 | `data/contracts.json` | `kinds.long_haul.pay_per_day` | 900 | 1,800 | Long-haul jobs pay 1,040 to 1,560 per quick day, no better than the 29k stock ship at home, and need a 675k fit. At 1,800 the same job pays about 2,000 to 2,900 per day and the Outer refit would pay back in about 300 to 350 days if the player could take one such job per trip (the boards hold at most four offers, and long hauls are 2 of 12 weight points, so they will not always be there). Untested. |
| 5 | `data/contracts.json` | `kinds.long_haul.pay_base` | 8,000 | 12,000 | Same reason, a flat top-up so short outer jobs also pay. Untested. |
| 6 | `data/balance.json` | `economy.relaxation_per_day` | 0.055 | 0.06, only if suggestion 2 is taken | Offsets the extra income from suggestion 2. The notes record about -7% credits for this step on the earlier economy (0.065 was about -30%), so the combination should be re-measured with `seeds=20`. Untested. |
| 7 | `data/projects.json` | `pavonis_line.stages[0].needs` | machine_parts 50, habitat_modules 20, deuterium 2 | machine_parts 25, habitat_modules 10, deuterium 2 | Ares Ring holds 0 t of machine parts and 0 t of habitat modules above its reserve, so the project sits at 1% after a year and the Pavonis ride never opens. Halving the need puts stage 0 (37 t in all) within one 70 t Freighter run. Untested. |
| 8 | `data/projects.json` | `pavonis_line.stages[1].needs.machine_parts`, `stages[2].needs.machine_parts` | 40, 30 | 20, 15 | Same reason: the later stages need another 70 t of machine parts that only the player can bring. Untested. |
| 9 | `data/projects.json` | `ares_greenhouses.stages[0].needs` | habitat_modules 40, machine_parts 30 | habitat_modules 20, machine_parts 15 | 0% after a year, same cause. Untested. |
| 10 | `data/projects.json` | `concord_pair.stages[0].needs.machine_parts` | 50 | 25 | Piazzi Station has 0 t spare machine parts; stalled at 17% from day 90. Untested. |
| 11 | `data/projects.json` | `kalpana_two.stages[1].needs.habitat_modules` | 90 | 60 | 0 of 90 in stock after a year at stage 1; Kalpana One makes no habitat modules and the Trojan Yards ships go elsewhere. Untested. |
| 12 | `data/balance.json` | `damage.patch_mult` | 1.6 | 1.25 | At 1.6, a patch costs more than a yard repair once damage passes 0.67 (12 m/s: patch 5,222, yard 5,063) and still leaves 25% damage. At 1.25 a patch is never dearer than the yard and stays a premium per point repaired. |
| 13 | `data/balance.json` | `damage.insurance_excess` | 3,000 | 4,500 | At 3,000 a wreck is cheaper than repairing a stock hull above keel damage 0.56 (a hit of about 10 m/s). 4,500 keeps the wreck at the price of a yard repair at that speed (3.1 to 5.7k), so ramming is never the cheap option. |
| 14 | `tools/balance_bot.gd` (not data) | `UPGRADES`, `UPGRADE_RESERVE` | pods and tanks first, 15k reserve | Drop the pods, or set `seeds=20` and report medians with the interquartile range | The bot's own upgrades cost it half its credits at day 180 (109k vs 218k) and the first-upgrade median moves 14 to 38 between near-identical builds. It is not a pacing measure. |

## 7. How to reproduce

All commands run from the repository root; replace the Godot path as needed (here, the Linux build unzipped into `.tools/godot/`).

```
G=.tools/godot/Godot_v4.7.2-stable_linux.x86_64
# Baseline curves and routes (6 seeds, 365 days, no upgrades; every leg printed):
$G --headless --path . --script res://tools/balance_bot.gd -- days=365 upgrade=0 seeds=6 legs=1 out=/tmp/noup.md
# Default bot: 8 seeds, 180 days; and 5 seeds, 360 days:
$G --headless --path . --script res://tools/balance_bot.gd -- days=180 upgrade=1 seeds=8 out=/tmp/up.md
# What a module is worth (100k start, 90 days, 10 seeds):
$G --headless --path . --script res://tools/balance_bot.gd -- days=90 upgrade=0 seeds=10 credits=100000 fit=cargo.0:cargo_pod_l,cargo.1:cargo_pod_l out=/tmp/podl.md
# Market depth: how much of a port's stock to buy:
$G --headless --path . --script res://tools/balance_bot.gd -- days=90 upgrade=0 seeds=10 credits=100000 take=0.2 out=/tmp/take.md
# What fleets do to the player:
$G --headless --path . --script res://tools/balance_bot.gd -- days=180 upgrade=0 seeds=6 nofleets=luna_climbers,stalk_climbers,pavonis_climbers out=/tmp/fl.md
# Everything else:
$G --headless --path . --script res://tools/balance_probe.gd -- sections=modules,elevators,shuttle,collisions,projects,outer,loops
```

Use `out=` so `docs/balance/report.md` is not overwritten; that file is the bot's own report and was left as it was.

### Limits

- The bot is greedy, single-good, trades only its own neighbourhood and sees live prices. The spread across seeds is large: standard deviations of 25 to 45k at 90 days, so single-seed comparisons mean nothing.
- Scratch-data experiments (suggestions 2, doubling targets, `price_elasticity` 0.5, zero project draw) were run in throwaway copies of the repository; nothing in `data/` changed.
- The outer-freight table is day-0 prices, one hold of the best single good out and one back, no stock depletion. It is an upper bound for each fit.
- The mid-game bisect compared commits that changed more than data (new code, art, scenes). It rules out nothing smaller than a 10-day swing.
- Not measured: courier income actually earned by a player, survey and salvage income including travel, the value of tips, and anything that depends on hand-flying.
