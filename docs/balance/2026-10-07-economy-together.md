# Ship economy, favours and the new ports, balanced together (2026-10-07)

Three systems were balanced alone: the ship economy (wear, service, overhaul, WoF, insurance), favours (rewards in kind, hitchhikers, tunes) and the four habitat ports. This is the first run of them together. Tool: `tools/balance_bot.gd` with new options (below). Branch `cloud/economy-balance`.

## How it was measured

365 game days, seeds 1 to 4 unless stated, the stock part-worn Mule with the balance.json start (10,000 cr), the bot's usual trade loop, plus: it takes any courier or package job bound where it is already going (`jobs=1`), takes any hitchhiker when a berth is free (`hikers=1`, six berths fitted with `fit=cargo.1:passenger_berths` and kept through upgrades), and uses a yard voucher on whatever is tired. Three maintenance strategies (`upkeep=`):

- **careful (1):** services under 55% condition, overhauls under 30%, renews the WoF 14 days ahead.
- **lazy (2):** only overhauls what an inspection would fail, renews the WoF.
- **neglect (0):** never visits a yard for upkeep.

New bot options: `upkeep=2`, `jobs=1`, `hikers=1`, `seed0=N` (run seeds in parallel processes), `tsv=1` (one `ECON_RUN` JSON line per seed). The bot now also lets the sim tick for a minute after docking; before, nothing ticked while docked, so insurance never renewed and no hitchhiker ever asked (the first runs showed 6 lapses a year and 0 hitchhikers: a bot artifact).

## Before tuning: neglect was free

| Strategy (old data) | Gross cr/day | Upkeep + premiums + surcharges | Share of gross | Faults/yr | WoF lapses/yr |
|---|---|---|---|---|---|
| careful (8 seeds) | 1,586 | 30.6k | 5.3% | 0 | 0 |
| lazy | 1,565 | 48.6k | 8.5% | 0 | 0 |
| neglect | 1,548 | 24.3k | 4.3% | 4.8 | 2.0 |

A pilot who never maintained the ship earned within 2.4% of one who did (inside seed noise) and spent less. At condition 0 a drive lost only 12% of its thrust, a trip about 6% longer; faults cost a few per cent. The owner's brief was that upkeep should be about wear and tear, so the incentive was missing.

## After tuning

| Strategy (new data, seeds 1-4) | Gross cr/day | Upkeep + premiums + surcharges | Share | Faults/yr | WoF lapses/yr | Insurance lapses/yr | Yard time | End credits |
|---|---|---|---|---|---|---|---|---|
| careful | 1,650 | 31.1k | 5.2% | 0 | 0 | 1.2 | 2.8% | 319k |
| lazy | 1,598 | 49.0k | 8.4% | 0.5 | 0 | 1.5 | 4.2% | 280k |
| neglect | 1,467 | 24.2k | 4.5% | 4.2 | 1.8 | 2.2 | 1.3% | 257k |
| careful, renewal window 10 d (seeds 1-3) | 1,887 | 33.0k | 4.8% | 0 | 0.3 | 0 | 3.0% | 404k |

- Neglect now costs about 11% of income (about 66k a year) to save about 7k of upkeep, and its drive sits at 0% condition. Lazy costs 60% more upkeep than careful (late overhauls are dear). Care pays, and doing it early pays most.
- "Upkeep" is service, overhaul, inspection fees, premiums and unfit-dock surcharges. Refit labour (about 10k/yr here) is on top, tied to the upgrades the bot buys.
- Careful upkeep is about 5% of gross. That is on the light side of "real but fair"; I did not raise yard prices because the income side is already soft (the cloud report found income flat near 1,000 to 1,500 cr/day), and the new wear-to-speed coupling is what makes upkeep felt. Revisit after human play.
- Caveat: seed noise is large (end credits swing by ±25%), and every data change reshuffles the shared random stream. Compare the gross cr/day and upkeep columns, not end credits.

## Solvency of a starting pilot

No run of any strategy (about 35 seeds) ever went below its 10,000 cr start. By arithmetic a pilot who only sits at the dock pays the Commons basic cover (about 417 cr per 30 days) and one 350 cr inspection a year, and the starter Mule is at condition 0.70 to 0.85 with 120 days of WoF, so nothing needs a yard in the first month. Auto-renew never takes the pilot below the premium (it lapses instead), and a lost ship with no cover still comes back on the 9,000 cr loan.
One gap left alone because it lives in `travel_system.gd`: the unfit-dock surcharge (100 to 300 cr) is charged like the tug fee and can take credits below zero.

## Interactions found and fixed

1. **Repair vouchers now pay towards service and overhaul.** `ShipBill.quote` takes `Favours.yard_voucher_balance` off service and overhaul (not parts, labour or the inspection fee) as a line `{kind: "voucher", label: "voucher: -X cr", credits: -X}`, a `voucher` field in the quote and a `use_voucher: false` request switch. The shipyard commands spend it (`spend_yard_vouchers`, soonest expiry first). `use_voucher {id}` still mends collision damage. Bot: careful pilots took about 1.8k to 2.5k a year off their bills this way (1 to 2 uses a year), about 6% of in-kind value.
2. **Hitchhikers need a valid WoF**, like passengers: `accept_hitchhiker` returns the passenger refusal text, and a strict port puts them ashore with no fare if it lapsed in flight (event `hitchhiker_refused`). Without this, a ship that contract passengers were barred from could carry hitchhikers freely.
3. **Insurance lapsed when a 3-day trip straddled the 3-day renewal window** (1 to 2 lapses a year, even for careful pilots). Window 3 to 10 days; a renewal adds a period to the old expiry, so paying early costs nothing. Lapses 0 in the re-check.
4. **Wear did too little.** `performance.max_loss` 0.12 to 0.28 and `faults.rate_per_hour` 0.002 to 0.004 (see the table).
5. **Tunes.** Fuel is cheap (a home Mule trip burns about 0.35 t, 42 cr), so efficiency tunes save almost nothing in credits; time is the currency. At home a tune's worth is its speed: injector retime -1.4% trip time, Overdrive -2.8%, regen retune -1.0%, lean-burn +1.0% (slower), nozzle polish 0. So:
   - `overdrive_map` wear_pct 0.1 to 0.4. At 10% the wear cost was about 600 cr a year against about 10k of time gained; at 40% it costs about 2.3k a year on a Mule and 7k on a Mk2, which is a real trade, but it is still worth it for a trader.
   - `lean_burn_map` wear_pct 0 to -0.15 (it is meant to be gentle; now it also saves drive upkeep), value_cr 2600 to 1000.
   - `nozzle_polish` value_cr 1500 to 500, `regen_retune` 3200 to 2200. Those cards overstated what the tune does (nozzle polish is range, not credits), and since the cash part of an offer drops by value x 0.85, the pilot was losing cash for little. `injector_retime` (1800) and `overdrive_map` (2200) stay. A tune is lost when the drive is swapped, and the bot swaps its Mk1 within about 30 days, so these values are for about 100 days of use.

## Premiums against ship value

Premium per 30 days on `basic` (Mule start 417 cr) is 0.79% of insured value at the start and the same fraction after any refit: 591 after one pod, 759 after two (the owner's 417 to 723 was a two-part refit), 850 with a bigger tank, 1,567 once the Mk2 drive is in, 2,351 with everything upgraded (about 331k insured). The step is fair in that it is proportional to the cover bought (a total loss pays 80% of insured value less the replacement), and as a share of income it stays about 2 to 3% (careful bot: 14k a year on 600k gross). A fresh module counts at 92% of its price against a worn one at about 60%, which is why a new pod adds more than its price share. I kept the rates. If a refit's jump still feels harsh in play, the cheap fix is a no-claims discount (for example -10% after a claim-free year in `insurance`), not a lower rate.

## Favours in the economy

Per bot year: about 50 hitchhiker asks (one every 7 days docked), 16 to 18 boarded (when a berth is free), fares about 2k; about 5 of 31 to 42 jobs taken paid part in kind (about 13% of jobs), worth 8k to 13k of 150k to 220k in cash (6 to 7%), mostly fuel and refuel vouchers (8k), then yard (2.5k), favours (0.6k to 2k) and tunes (1.4k). Help from hitchhikers (engineer wear 0.9, navigator fuel trim) is real but small next to speed and was not isolated.
The cash offset and in-kind odds looked fair here; I changed none of them.

## New habitat ports

Island One, Kalpana Two, Concord and the Selene Ring have markets only: no shipyard, no refuel, no berth stock. They add no yard or inspection demand, take no vouchers, and WoF classes come from their operators (relaxed for the Kernel Settlers and the Belt, standard for Kalpana and Luna). The bot never reaches them (their projects stay shut), so their effect on upkeep is nil by construction. Hitchhikers can ask there as at any port. Nothing to change.

## For the ship builder screen (view/ship_builder_screen.gd), not wired here

`ShipBill.quote` returns a new line kind and field; the developer should show them:
- a bill line `{kind: "voucher", slot: "", label: "voucher: -X cr", credits: -X}` after the service and overhaul lines and before the total, styled like a trade-in credit (a reduction), shown only when `bill.voucher > 0`;
- the total already includes it (`total = parts - trade_in + labour + service + overhaul + inspection - voucher`);
- optionally a hint when `Favours.yard_voucher_balance(state, data, place) > 0` and the bill has no service work: "voucher: X cr good here for service and overhaul".
The shipyard also emits `voucher_used` ({spent, left, place, for: "yard work"}); the existing handler in `view/main.gd` reads `spent`, `left` and `place`, which are all there, so its notice reads "Repair voucher used at X: Y of work done, Z left" with no change. `hitchhiker_refused` ({name, place, text}) is a new event the view ignores until someone puts its `text` on the comms channel.

## Tests added

`test_yard_voucher_on_bill`, `test_hitchhikers_and_wof`, `test_upkeep_bites` in `tests/run_tests.gd`. The suite is 1,448 checks, 0 failures.

## Open

- A bot mode that takes hitchhikers by trade and measures their help.
- A poor-pilot stress run (3,000 cr start, one bad contract) once human play shows how far the first 60 days stretch.
- Outer-system refits (Mk3) have premiums of 3 to 4k per period: not run.
