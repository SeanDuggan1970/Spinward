# The story arc: a fuller sketch (draft for Sean to react to)

Status: **proposal, nothing built.** Revised after Sean's notes (2026-10-11):
- Hibernation is a core mechanic, not a fix: the player tunnels through deep time like a bookworm, detached from small human affairs, and gets to witness a grander stage.
- The arc is more hidden. The occultation is only an odd hint at first.
- The minds try first, with an uncrewed probe, and it goes poorly: whatever is out there will not deal with minds alone. That is what gives people their value and their role.

The guardrails from `DESIGN.md` still hold: hopeful tone, hazards over villains, combat last and non-lethal, and the story finds you rather than being pushed at you.

## The shape in one paragraph

A dead probe's last data shows three stars winking out. It is an oddity in the news, gossip in bars, and easy to miss. The minds can't stop thinking about it, so they quietly build and launch a deep probe of their own. Years of game time pass, and the probe arrives. The meeting goes nowhere: the object won't talk to it, and turns away from it as a cat turns from a stranger's hand. The minds conclude that it answers only *someone*: a living person, mortal, who can be changed by the meeting. For the first time the minds need people for something they cannot do. They look for a pilot who delivers, and find you. You sleep out to it, it says hello to you, and the rest of the game is the system learning what it means that the conversation has to go through a human.

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

## Act 0: The Oddity (hidden, ambient, easy to miss)

Nothing is offered to the player. It's just there for a curious one to notice:
- **Spaceline, early game:** "Hermes-7 data release: Farside astronomers puzzled by 'three-star blink' in probe's final frames." One line, between a wedding and a price story.
- **Brokers:** now and then a tip comes with a rumour attached, such as "the Farside lot are buying a lot of coffee lately."
- **The jobs board:** the hand-carried items that already exist (*calibration masters for a telescope*, *survey data too big to send*) start pointing at Farside and Valhalla more often.
- **Hermes-7:** the wreck stays a findable site for explorers. Its recorder can be recovered and sold to Farside for a modest fee. A pilot who does this has, without knowing it, handed the minds their first clue.

## Act I: The Probe (world events, on the world's clock)

These are things that happen in the system whether or not the player is paying attention, through the Spaceline and the projects board:
- **Year 1:** "A Commons mind consortium announces *Long Patience*, a deep probe to 'look at something odd', with no further comment." It appears as a project. The player can haul for it (the drive parts and the long-haul tanks), but doesn't have to.
- **Launch:** a set piece at Trojan Yards: a small, fast, beautiful thing leaving on a column of violet light. The news covers it once, then forgets.
- **Years pass.** The probe takes about three years to get there, because it carries no one. A player who hibernates sees the launch and the arrival close together, which is the bookworm's reward.
- **The arrival goes poorly.** The probe reaches the Lacuna and sends greetings, counts and maths. Nothing comes back for months. Then the object **moves**, slowly and deliberately, keeping a few million km between itself and the probe, however the probe approaches. It does nothing hostile; it is simply not interested.
- **The minds go quiet.** Commons traffic is a little slower for a month; the drone freighters you pass say less. A Spaceline columnist notices: "Is something bothering the minds?" The player may feel it before being told.

## Act II: The Approach (the existing beats, retold)

The minds draw their conclusion. Hermes-7 was a machine and saw only a shadow. *Long Patience* was a mind and was turned away. Whatever it is, it answers someone who is alive, who could die, and who would be changed by meeting it. The Long View's old rule, that the unknown is met by a person, was a courtesy. Now it is a fact.

1. **Ines Okafor** (needs three on-time deliveries and Known standing, and now also the probe's failure in the news) buys you a drink. With walking, this is a real scene at a bar table. She's careful: "Some very patient friends have a problem they cannot solve without you, and they are not used to that."
2. **Farside:** Adeyemi plays you both recordings: Hermes-7's three blinking stars, and *Long Patience*'s months of silence and the object sliding away from it. "It can tell the difference between us and them. We don't know how."
3. **The mind in a box** to Trojan Yards, as now.
4. **The loan.** Patient Arithmetic is honest about what it costs them: "We are not used to being the ones who cannot go. We would like to be there through you, if you'll let us listen." You get the drive and the sleep pod, and the choice of which of your ships to take. Before you leave, sort out the rest of your fleet: the Long View offers to pay the berths, but then you owe them.
5. **The long sleep:** about 2.5 years, slept through, with three short wake-ups:
   1. the heliopause, where you look back and find the Sun
   2. Sedna passing, dim and red
   3. a dust strike to patch; with walking, an EVA on the hull
6. **The meeting.** It doesn't move away from you. Two days after your count, one to ten, it comes back in your own voice, from all around the sky. The minds, listening through your ship, are overjoyed and a little hurt.

## Act III: The Interpreter (new)

### What the meeting means
The Lacuna will talk, but only through a person. Anything the minds send direct is ignored; anything you relay is answered. People now matter, as the go-between for the most important conversation in history. The minds have to trust a mortal with it. That is the hopeful note: neither side can do this alone.

### The question
After the greeting it sends one more thing: your count, then a pause, then a blank, as if asking *how many of you are there?* Or is it *which of you is speaking?* The minds and the astronomers argue for years about which.

### Coming home to a changed system
- **The world moved on:** five years have passed and the sim really ran. The digest is long.
- **You're famous:** strangers buy you drinks, and clients ask for you by name.
- **You're needed:** every power wants its words carried, and only a person can carry them.

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
| Spaceline news | Act 0's hints and Act I's world events; the digest on waking |
| Megaprojects | *Long Patience* (Act I) and the Choir (Act III) |
| Fleet and craft jobs | arranging your affairs before a sleep; faction jobs need the right ship |
| Secret work and stealth | carrying the Long View's recordings past Compact sensors |
| Reputation | whose words are in the reply |
| Badges and renown | coming home famous; the Bookworm badge |
| Walking (step 8) | Ines at the bar, Adeyemi's control room, the EVA patch |
| Your base (later) | a quiet place to sleep the years in between voyages |

## What changes in existing content
- `data/story.json` `first_favour`: also waits for the probe's failure, a world beat on the world's clock.
- `the_occultation`: now replays two recordings, and the minds' honesty about the probe.
- `the_meeting`: the minds listening through you; it sets up Act III.
- New: the `long_patience` project, its Spaceline items, the probe's arrival event, and the Commons-quiet month.
- New: hibernation (pod module, sleep command, digest screen, coarse sleep stepping).

## Open questions for Sean
1. How long should *Long Patience* take: 3 years (a hibernation-sized gap), or shorter so a non-sleeper doesn't wait forever?
2. Should the Lacuna's preference stay unexplained (only the minds' theory), or should Act III confirm it?
3. Is the second interpreter the right amount of tension?
4. Should the ordinary yard-sold sleep pod come only after the Lacuna, or earlier?
5. Build order: hibernation first (useful now and to everything after), then Acts 0 and I (mostly data: news, a project, world beats), then walking, then Act III?
