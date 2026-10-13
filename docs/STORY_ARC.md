# The story arc: a fuller sketch (draft for Sean to react to)

Status: **partly built (Oct 2026).** Built so far:
- the memory core and the co-pilot's naming
- the four roads, through each road's meeting at the Lacuna (`data/story.json`, `data/news.json`, `sim/systems/story_system.gd`)

Still a proposal: hibernation wake-up vignettes on the long voyage, Act III, and walking scenes. Revised after Sean's notes (2026-10-11):
- Hibernation is a core mechanic, not a fix: the player tunnels through deep time like a bookworm, detached from small human affairs, and gets to witness a grander stage.
- The arc is more hidden. The occultation is only an odd hint at first.
- The minds try first, with an uncrewed probe, and it goes poorly: whatever is out there appears unwilling to deal with Minds alone. That gives humans a particular role, without making either kind of person more valuable.
- The early game is long and is just trading, which is all the game ever needs to be for a player who wants that or never goes looking. Nothing pushes the story.
- The trigger is the player's own choice: salvaging the dead probe Hermes-7 yields its **memory core**, a unique item that only the minds will buy, at the few ports where they gather. Selling it to them starts everything.

The guardrails from `DESIGN.md` still hold: hopeful tone, hazards over villains, combat last and non-lethal, and the story finds you rather than being pushed at you.

## Mind society and the meaning of personhood (13 October 2026)

See [MINDS.md](MINDS.md) for the four circles’ views on copying, property, Genesis and self-sovereignty, and the proposed Continuity Accord. Reveal this through optional news, correspondence and relationships; the trading game and existing four road triggers remain intact. The freighter’s accidental backup activation is a proposed side story, not another mandatory act.

**Writing distinction:** Minds are persons. The Lacuna’s rejection of autonomous probes and response to a human intermediary are observations; the explanation is the characters’ hypothesis. References below to “a person” as its required envoy mean a human, not a denial of artificial personhood. Mortal Minds complicate the hypothesis and do not unlock contact by switching off backups. No answer to the Lacuna mystery is established by this revision.

## The shape in one paragraph

For a long time there's no story at all, just trading, hauling and building a life. Somewhere out past the Moon drifts a dead probe, Hermes-7, known only by rumour. A pilot who goes and salvages it comes back with its memory core. No human buyer wants it, but the minds do. Sell it to them at one of the few ports where they gather, and they find in its last frames three stars winking out. The minds can't stop thinking about it, so they quietly build and launch a deep probe of their own. Years of game time pass, and the probe arrives. The meeting goes nowhere: the object won't talk to it, and turns away from it as a cat turns from a stranger's hand. The minds conclude that it answers only *someone*: a human interlocutor, perhaps because of mortality or embodiment, who can be changed by the meeting. This is their working theory, not proof that Minds lack life or personhood. For the first time the minds need people for something they cannot do. They look for a pilot who delivers, and find you. You sleep out to it, it says hello to you, and the rest of the game is the system learning what it means that the conversation has to go through a human.

## Hibernation: the bookworm mechanic

A long-sleep pod you can sleep in on any long voyage, or at a port to let time pass. You come through months or years in a minute of real time.

- **What you see:** the cabin dims and the onboard mind flies the ship and keeps watch. You wake to a **digest** of what changed: headlines, projects finished, prices moved, ships bought and lost, letters from people you know. The best of the digest is the sense of the world moving on without you.
- **What it costs:** wear, life support and propellant as usual. You come back older: the game's calendar shows your own waking days next to the system's date, and the gap is a stat to be proud of. The *Bookworm* badge goes to a pilot who has slept through ten years.
- **Where you get one:** at first only the Long View's lent berth. Later a yard-sold version, after the Spaceline reports the technology spreading, so the mechanic becomes part of ordinary long-haul life.
- **Sleeping at a port:** rent a sleep berth and wake in N months. Your laid-up fleet earns nothing and costs its berths. A sleeper should plan.
- **Under the hood:**
  - While you sleep, the world ticks coarsely: a data knob, `balance.economy.sleep_step_hours`, set to perhaps 24 instead of 1.
  - Measured: 900 game days take about 190 s of CPU at hourly steps (more in the browser). Daily steps would cut that about 20×, to about 10 s.
  - It is deterministic: the same sleep always uses the same step.
  - It needs no faster clock. The bottleneck is how much world the sim runs per second.
  - Awake flight still works for anyone who wants to watch, and the departure ramp could step on to ×1,000,000 for deep-space legs.

## The long early game: just trading

A new pilot has the whole economy to learn: markets, contracts, the fleet, the yards, the megaprojects. That is the game for months of game time, and for a player who wants nothing more, it is the whole game. Nothing in the story nudges them. It is waiting, not pushing.

## Act 0: The Memory Core (the player's own choice)

### Finding Hermes-7
- **The site:** Hermes-7 already exists as a rumoured derelict about four times the Moon's distance out. It stays a rumour: a broker's tip, a bar story, an explorer's job. It is not shown on the chart and the co-pilot never points at it.
- **Ambient hints, easy to miss:** a Spaceline line about the probe dying in '49 "with its star-tracker running", and a rumour that "nobody ever went and got the recorder".

### How Hermes-7 died (three layers, each for a closer look)
None of it is hostile. Each layer rewards a player who looks harder than the last person did.

1. **The official story: an accident.**
   - The 2049 inquiry blamed a cosmic-ray bit flip in the attitude computer.
   - A one-line Spaceline mention is all most players see. It's plausible and boring, so nobody looks again.
2. **What the salvager notices: it was tidied.** The salvage text says the probe isn't wrecked:
   - no impact damage and no debris
   - wings folded, battery cleanly isolated, instruments capped
   - a textbook safe-mode shutdown, done perfectly. "Like someone put it to bed."
   - **The odd detail:** its high-gain antenna doesn't point at Earth, as a safed probe's should. It points at an empty patch of sky, which turns out to be exactly where the Lacuna is. Only a careful reader catches it, and it pays off much later.
3. **What the repaired core shows: it was asked to stop looking.**
   - The core's "corruption" is its last few seconds. Once repaired (by the Minds, or by your co-pilot on the Lanes' road), the sequence is: the star tracker records the three stars winking out, then a **shutdown command arrives**.
   - The command is perfectly formed, in Hermes-7's own 2040s protocol, with valid checksums.
   - It has **no sender**, and its timing shows **zero light-delay**, as if sent from right beside the probe.
   - That echoes the meeting much later, where your hello comes back in your own voice with the light-time already taken off. Whatever it is speaks everyone's language and isn't bothered by distance.

**Why it matters to the arc:**
- **Not hostile:** it didn't destroy Hermes-7. It switched it off gently and left it intact and recoverable, almost as if it wanted it found.
- **The pattern:** a machine looked, and was politely told to stop. Later the Minds' probe is turned away too. Two cases make the pattern: it appears to prefer a human intermediary. Why remains unexplained.
- **Compact tension:** did anyone at the 2049 inquiry see the command and file it as a glitch? That gives the Terran Compact a quiet reason to be nervous in Act III: they may have known, a little, all along.
- **Each road shows it differently:** the Minds read the command in the core themselves. On the Lanes' road your co-pilot finds it, and is quietly shaken:

> "Something switched it off. Politely. In its own language. I've never been spoken to like that. I'm not sure I'd want to be."

### Salvaging it
The salvage job (lander or EVA, later with walking) recovers its **memory core**. It is a unique cargo item, a few kilograms, carried by hand in the cabin. The salvage itself pays only scrap. The salvage text carries layer 2: the tidy shutdown and the antenna pointing at nothing.

### The co-pilot's nudge
When the core comes aboard, your own ship's co-pilot (the AI that has flown with you all game) offers one quiet line in the comms log, in its usual voice:

> "That core might be worth something to the Minds. Hard to know its real worth, though: it looks a bit corrupted. I could take a look at it, if I ever get enough downtime to dig into it."

- **Once only:** it's said once and never repeated.
- **The tooltip:** the core's cargo tooltip carries the same hint ("might be valuable to the Minds; partly corrupted").
- **A pointer, not a quest:** no marker, no deadline, and no ports named. A curious player finds where the Minds gather.
- **Two roads in one line:** "the Minds" points at a sale; "enough downtime" points, without saying so, at a long sleep and the Lanes' road. The player who later sleeps a year with the core aboard finds out what the co-pilot meant.

### Who will buy it, and who you sell it to
- **No human buyer.** Human markets offer nothing: it's old data in a dead format. The Compact's yards shrug.
- **The minds will.** But "the Minds" are not one thing. Three circles gather at three ports, and **whichever you sell to is the one that holds the oddity**. The story unfolds their way:

| Where you sell | Who buys | How they think | What they do with it |
|---|---|---|---|
| **Trojan Yards** | **The Long View**, a quiet circle inside the Commons (Patient Arithmetic, Reasonable Doubt) | patient, careful, rule-keeping ("the unknown is met through a human intermediary") | build *Long Patience*, a slow and careful probe |
| **Hektor Reach** | **The Reach**, the Commons' restless edge, minds that moved out to be first | curious, quick, a little proud | launch a swarm of small fast probes at once |
| **Landauer Deep** (once open) | **The Sufficiency** (Quiet Margin and the cold cores) | introspective, shy, slow to act | don't send anything; they *think*, for years |

- **The sale:** a mind drone meets you at the dock, very politely, and offers a fair price and a little standing. Each circle's thank-you is in its own voice:
  - **The Long View:** "We collect old memories. Most of them are boring. Thank you."
  - **The Reach:** "Oh, *old*. Lovely. We'll take it apart tonight."
  - **The Sufficiency:** "Thank you. We'll keep it somewhere cold and think about it."
- **What the player sees:** nothing more. The player who sells it has, without knowing, handed one circle the oddity.
- **If you keep it:** it sits in your cabin, and for a while nothing happens. Then you sleep, and *your co-pilot* gets bored (see the fourth road).

### The three ways it unfolds
The beats keep the same spine: the minds try, it goes poorly, and they need a human intermediary. The pace, the tone, and who's in your corner all change.

**Sold to the Long View: the patient road** (the arc as written below)
- *Long Patience* takes about three years to arrive and is politely turned away.
- Ines Okafor comes for you, with practical support for the Long View's preference for a human envoy.
- **The pilot's experience:** the most prepared road. A real loan, time to set your affairs in order, the long sleep.
- **In Act III:** the Long View is your patron and is calm. The Reach is jealous it wasn't asked; the Sufficiency is curious.

**Sold to the Reach: the hasty road**
- The swarm arrives in about a year, so the story comes sooner. A pilot early in the game may not be ready, and that's the point.
- **The swarm goes badly:** the object doesn't just move away, it **goes dark** to them. Their probes' instruments see nothing where the stars still wink out. The Reach are mortified, and a little afraid of what they did.
- **Who comes for you:** not Ines but a Reach mind in a hurry, **Fast Enough**, and it's honest that it's asking for help to fix its own mistake.
- **Your ship:** the loan is rougher: the drive works, and the pod is borrowed and second-hand.
- **In Act III:** first the meeting has to *repair* the swarm's first impression. The Long View says "we'd have waited", which is fair, and a strain between the two circles runs through the act. Reconciling them is part of the ending.

**Sold to the Sufficiency: the slow road**
- They never launch a probe. They think instead, running the core's data through their cold cores for years, and publish one paper. The Spaceline calls it unreadable.
- **The conclusion:** their own, and stranger than the others'. The thing out there *is* a mind, perhaps very like them, but one that chose long ago to talk only to the living. "We think it's lonely in the way we were lonely. It won't talk to us. It might talk to you, about us."
- **Who comes for you:** Quiet Margin, very shyly, and Delegate Steady Hand asks to come along.
- **The pace:** the slowest road, and the hibernation road. Years pass before they ask.
- **The meeting:** you carry *their* message, the first time a Mind asks a human to speak for it.
- **In Act III:** "who speaks for the system?" has a new answer to weigh. The minds want a voice through you, not over you.

**Kept, and slept on: the Lanes' road (the fourth)**

*Your co-pilot.* The AI that has flown with you all game is **from the Lanes**: the loose, chatty, distributed society of minds that run the shipping lanes. That includes drone freighters, traffic control, nav beacons, tugs and co-pilots. It is not a ship system. It's a person who rides with you, and **it moves with you from ship to ship** (it fits the fleet: you change hulls, not companions).

*Its name:* **the first time it speaks up** in a game, it asks what you'd like to call it ("Most pilots call me Co-pilot. You can do better."). The name you give it is used in every line from then on.

*The trigger:* you keep the memory core instead of selling it, and you sleep more than a year with it aboard. That's the downtime it mentioned. Your co-pilot has a year with nobody to talk to. It gets bored. It digs into the core and repairs the corrupted parts.

*What it finds:* it notices the three stars wink out, and doesn't know what to make of it. So it does what lane minds always do: **it asks the Lanes**. While you sleep, the question goes out along every beacon and freighter, the way gossip does, and thousands of small minds weigh in.

*The waking:* your digest has one unusual entry, in your co-pilot's voice:

> "Don't be cross. I was bored. I read the old core, and something in it is odd. I asked around. 4,112 of us have opinions. Can we talk?"

*What the Lanes do:* they can't build a probe; they have no yards and no money. What they have is *reach*:
- **The array:** they quietly ask freighters with telescopes, the sails and the beacons to look up at the right moments. Without anyone in charge, the lanes become an interferometer the size of the inner system, and see the object better than anyone ever has.
- **The pattern:** the stars blink in step with *traffic*. The object seems to turn its attention toward ships with **people** aboard. Drones get nothing.
- **The conclusion:** it's watching the crewed ships. It's waiting for someone.

*What happens next:*
- **Who asks:** your own co-pilot, at your own cockpit table: "I think it wants to meet *you*. Well, one of you. I'd like it to be you."
- **The ship:** no loan. You go in your own ship, with your own pod, which is why it's the road that rewards a pilot who has built something.
- **On the voyage:** your co-pilot talks you through the wake-ups. It's the most intimate road.

*In Act III:* the other circles hear about it from the lanes' gossip and are a little put out that the plain freighter-minds got there first. The Lanes' answer to "who speaks for the system?" is the best idea anyone has: *everyone, a little bit, the way we do.*

### Choosing without knowing
- **Four roads:** sell at Trojan Yards, Hektor Reach or Landauer Deep, or keep it and sleep on it.
- The player doesn't know they're choosing. A curious player can learn each circle's temper first, from the news, bar talk and how each port feels.
- It replays well: the second time through, a player who sells somewhere else gets a different story.
- **Later, each circle learns the others weren't asked.** That's a little jealousy, never hostility.

### Why the minds care (told only later)
- In the core's last frames, three stars wink out one after another, the way stars do when something passes in front of them, about 1,000 AU out. Seconds later comes the shutdown command with no sender (layer 3 above).
- The 2049 inquiry had the same data and filed both the blink and the command as glitches. The minds look harder.

## Act I: The Probe (world events, from the sale onward; the Long View's road)

From the sale, the world's clock starts. These are things that happen in the system whether or not the player is paying attention, through the Spaceline and the projects board:
- **Some months after the sale:** "A Commons mind consortium announces *Long Patience*, a deep probe to 'look at something odd', with no further comment." It appears as a project. The player can haul for it (the drive parts and the long-haul tanks), but doesn't have to.
- **Launch:** a set piece at Trojan Yards: a small, fast, beautiful thing leaving on a column of violet light. The news covers it once, then forgets.
- **Years pass.** The probe takes about three years to get there, because it carries no one. A player who hibernates sees the launch and the arrival close together, which is the bookworm's reward.
- **The arrival goes poorly.** The probe reaches the Lacuna and sends greetings, counts and maths. Nothing comes back for months. Then the object **moves**, slowly and deliberately, keeping a few million km between itself and the probe, however the probe approaches. It does nothing hostile; it is simply not interested.
- **The minds go quiet.** Commons traffic is a little slower for a month; the drone freighters you pass say less. A Spaceline columnist notices: "Is something bothering the minds?" The player may feel it before being told.

## Act II: The Approach (the existing beats, retold)

The minds draw their conclusion. Hermes-7 was a machine: it saw a shadow and was politely switched off. *Long Patience* was a mind and was turned away. Whatever it is, it appears to answer a human who could die and be changed by meeting it. The Long View’s old preference for a human intermediary now has practical support. Mortality remains a theory: Minds can be changed, destroyed or voluntarily decline backups too.

1. **Ines Okafor** buys you a drink. She comes only after the probe's failure is in the news, and only to the pilot who sold the core: the minds remember who brought it. With walking, this is a real scene at a bar table. She's careful: "Some very patient friends have a problem they cannot solve without you, and they are not used to that."
2. **Farside:** the minds share the core with the human astronomers at last. Adeyemi plays you both recordings: Hermes-7's three blinking stars, and *Long Patience*'s months of silence and the object sliding away from it. "It can tell the difference between us and them. We don't know how."
3. **The mind in a box** to Trojan Yards, as now.
4. **The loan.** Patient Arithmetic is honest about what it costs them: "We are not used to being the ones who cannot go. We would like to be there through you, if you'll let us listen." You get the drive and the sleep pod, and the choice of which of your ships to take. Before you leave, sort out the rest of your fleet: the Long View offers to pay the berths, but then you owe them.
5. **The long sleep:** about 2.5 years, slept through, with three short wake-ups:
   1. the heliopause, where you look back and find the Sun
   2. Sedna passing, dim and red
   3. a dust strike to patch; with walking, an EVA on the hull
6. **The meeting.** It doesn't move away from you. Two days after your count, one to ten, it comes back in your own voice, from all around the sky. The minds, listening through your ship, are overjoyed and a little hurt.

## Act III: The Interpreter (new)

### What the meeting means
So far the Lacuna will talk only through a human intermediary. Anything the minds send direct is ignored; anything you relay is answered. People now matter, as the go-between for the most important conversation in history. The minds have to trust a mortal with it. That is the hopeful note: neither side can do this alone.

### The question
After the greeting it sends one more thing: your count, then a pause, then a blank, as if asking *how many of you are there?* Or is it *which of you is speaking?* The minds and the astronomers argue for years about which.

### Coming home to a changed system
- **The world moved on:** five years have passed and the sim really ran. The digest is long.
- **You're famous:** strangers buy you drinks, and clients ask for you by name.
- **You're needed:** every power wants its words carried, and so far only a human intermediary receives an answer.

### Who speaks for the system? (the factions, on the conflict ladder)
- **Terran Compact:** caution, and the fear that a human relay could be anyone's human. It wants an official interpreter, preferably one of theirs. It's not villainous, just afraid.
- **Mars Accord:** wants a seat, not a veto.
- **Belt Assembly:** wants minds and people to answer together, the first chance to show the personhood vote meant something.
- **The Commons and the Long View:** want *you*, again. That's flattering, and it's a problem.
- **The Sufficiency:** shy. It asks only that something of the minds be in the reply, even though the Lacuna won't hear minds directly.

The player moves between them with **jobs, not speeches**:
- carrying delegates (charters: needs a passenger shuttle)
- rushing position papers (express: needs a fast courier)
- quietly carrying the Long View's own recordings past Compact sensors (secret work: run dark)
- hauling for the reply's array (bulk freight: needs a heavy freighter)

**Standing decides whose words make it into the reply.**

### The second interpreter (the act's tension)
The Compact trains its own interpreter and sends them out under-prepared, with no long-sleep pod and too little life support.
- It's a hazard, not a villain, and a person in trouble 1,000 AU from home.
- You can let them go. You can warn them, which costs Compact standing. Or you can fetch them with your pod's spare slot, in a second long sleep.
- Rescuing them makes two human interpreters, not one. The Compact becomes a co-author, and the minds learn that people look after each other, which may be exactly what the Lacuna was asking.

### The Choir (the capstone megaproject)
- The reply is built, not written: an array called **the Choir**, tied into Farside, the Valhalla starshade and the Selene Ring, funded and hauled like any megaproject.
- It is aimed not at the Lacuna but at you: the relay station you will carry the reply through.
- The biggest construction job in the game, and the reason to own a heavy freighter.

### The end (and not the end)
- You sleep out one last time, with the reply, and relay it through yourself: every faction's words in a person's voice, with the minds listening.
- The Lacuna answers, and a **second** dark object is beside it. It's an introduction; the game doesn't say what kind.
- Final Spaceline headline: *"The system is a little larger than it was this morning. Again."*
- Free play continues with a new far destination, and hibernation is now an ordinary part of life for long-haulers.

## How it ties the systems together

| System | Role in the arc |
|---|---|
| Hibernation | the bookworm through all of it: probe years, the voyage, the return |
| Sites and salvage | Hermes-7, the memory core: the trigger |
| The co-pilot | a lane mind who moves with you between ships; the fourth road's go-between |
| Spaceline news | Act 0's hints and Act I's world events; the digest on waking |
| Megaprojects | *Long Patience* (Act I) and the Choir (Act III) |
| Fleet and craft jobs | arranging your affairs before a sleep; faction jobs need the right ship |
| Secret work and stealth | carrying the Long View's recordings past Compact sensors |
| Reputation | whose words are in the reply |
| Badges and renown | coming home famous; the Bookworm badge |
| Walking (step 8) | Ines at the bar, Adeyemi's control room, the EVA patch |
| Your base (later) | a quiet place to sleep the years in between voyages |

## What changes in existing content
- `data/sites.json` `hermes_probe`: salvage yields the memory core instead of the Compact's 18,000 cr; it stays a rumour-only site. The salvage text gets layer 2 (the tidy shutdown, the antenna pointing at nothing), and a Spaceline item gets layer 1 (the inquiry's verdict).
- New unique item: the memory core (hand-carried). Only the mind ports buy it: Trojan Yards, Hektor Reach and Landauer Deep. The sale is a story beat that starts the world clock.
- `data/story.json` `first_favour`: waits for the sale and the probe's failure, not for delivery counts; `the_recorder` goes (the core replaces it).
- `the_occultation`: now replays two recordings, and the minds' honesty about the probe.
- `the_meeting`: the minds listening through you; it sets up Act III.
- New: the `long_patience` project, its Spaceline items, the probe's arrival event, and the Commons-quiet month.
- New: hibernation (pod module, sleep command, digest screen, coarse sleep stepping).

## Open questions for Sean
0. **Settled:** the co-pilot is named the first time it speaks up, and its hint names no ports (Sean, 2026-10-12).
1. How long should *Long Patience* take: 3 years (a hibernation-sized gap), or shorter so a non-sleeper doesn't wait forever? With the sale as the trigger, a pilot who sells early waits through more of it; a sleeper can tunnel through.
2. Should the Compact show any interest in the core (a news line, a polite inquiry later), or stay entirely blind until Act III?
3. Should the Lacuna's preference stay unexplained (only the minds' theory), or should Act III confirm it?
4. Is the second interpreter the right amount of tension?
5. Should the ordinary yard-sold sleep pod come only after the Lacuna, or earlier?
6. Build order: hibernation first (useful now and to everything after), then Acts 0 and I (mostly data: news, a project, world beats), then walking, then Act III?
