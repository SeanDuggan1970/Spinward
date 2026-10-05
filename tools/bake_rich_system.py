"""A rich and getting richer system: the Spaceline news feed, new projects (the Pavonis
Line, the Concord Pair, Lightfoot sails, the Sufficiency's second core), Landauer
Deep (a port the minds built for themselves), plumes and elevators on real bodies,
and solar-sail freighters. Idempotent: run it again and it rewrites the same data."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def save(name, d):
    open(os.path.join(ROOT, "data", name), "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


# --- Bodies: cryovolcanoes, volcanoes and elevators -----------------------------------
bodies = load("bodies.json")
bodies["_note_plumes"] = ("'plumes' (view-only): kind jets | umbrella | geyser, lat/lon in degrees (lon 'limb' puts it on the "
    "limb as seen), sizes in body radii, jets = how many, spread_deg = how far around the site they scatter. "
    "'structures': space elevators (top_r = the synchronous anchor, counter_r = the counterweight, both in radii; "
    "'project' grows it with that megaproject).")
bodies["enceladus"]["plumes"] = [
    {
        "kind": "jets",
        "lat": -90,
        "lon": 0,
        "spread_deg": 15,
        "jets": 40,
        "height_r": 1.3,
        "width_r": 0.08,
        "colour": "#e4f0ff",
        "brightness": 1.0
    },
    {
        "kind": "jets",
        "lat": -90,
        "lon": 0,
        "height_r": 2.4,
        "width_r": 1.2,
        "colour": "#cfe0f4",
        "brightness": 0.5
    }
]
bodies["io"]["plumes"] = [
    {"kind": "umbrella", "lat": -19, "lon": "limb", "height_r": 0.17, "width_r": 0.34, "colour": "#d6dcff", "brightness": 0.9},
    {"kind": "umbrella", "lat": 13, "lon": "limb", "height_r": 0.045, "width_r": 0.09, "colour": "#f2e6c0", "brightness": 0.8},
]
bodies["europa"]["plumes"] = [
    {"kind": "jets", "lat": -62, "lon": "limb", "spread_deg": 3, "jets": 3, "height_r": 0.13, "width_r": 0.025, "colour": "#e8f2ff", "brightness": 0.4},
]
bodies["triton"]["plumes"] = [
    {"kind": "geyser", "lat": -50, "lon": "limb", "spread_deg": 25, "jets": 6, "height_r": 0.008, "width_r": 0.003, "trail_r": 0.11, "colour": "#3a322c", "brightness": 1.0},
]
bodies["ceres"]["structures"] = [
    {"kind": "elevator", "name": "the Piazzi Stalk", "top_r": 2.53, "counter_r": 3.7, "climbers": 5},
]
bodies["mars"]["structures"] = [
    {"kind": "elevator", "name": "the Pavonis Line", "top_r": 6.03, "counter_r": 8.2, "climbers": 3, "project": "pavonis_line"},
]
save("bodies.json", bodies)

# --- Modules and hulls: the solar sail ---------------------------------------------------
modules = load("modules.json")
modules["solar_sail"] = {
    "name": "Lightfoot sail", "kind": "drive", "mass_t": 2.0, "price": 0, "sail": True,
    "description": "Six hundred metres of aluminised film on four booms. No propellant, ever; pushed out by sunlight and Clarke's power beams, it is slow and endlessly patient.",
    "look": {"shape": "sail", "size_m": [2.4, 2.4, 3.0], "span_m": 600, "colour": "foil"},
}
save("modules.json", modules)

ships = load("ships.json")
ships["sail_freighter"] = {
    "name": "Sail freighter",
    "description": "A Commons mind, two containers and a square of sunlight-catching film six hundred metres on a side. It never buys fuel and is never in a hurry.",
    "spine": "mule_spine",
    "modules": {"command.0": "drone_core", "cargo.0": "cargo_pod_m", "cargo.1": "cargo_pod_m", "drive.0": "solar_sail"},
    "look": {"cargo_layout": "pair"},
}
save("ships.json", ships)

# --- Places: Landauer Deep, and features at the outer ports --------------------------------
places = load("places.json")
places["landauer_deep"] = {
    "name": "Landauer Deep",
    "operator": "The Sufficiency",
    "description": ("Built by minds, for minds, in orbit around Iapetus. Computation is cheapest where it is cold, and "
        "Saturn's far moon is very cold and very quiet. Kilometres of radiator glow a dull red around a core kept in "
        "permanent shade. The guest annex is small and warm, and they apologise in advance for the silence."),
    "location": {"type": "orbit", "parent": "iapetus", "elements": {"a_m": 1100000.0, "e": 0.0, "i_deg": 8.0, "node_deg": 0.0, "peri_deg": 0.0, "m0_deg": 0.0}},
    "station": {"hub_radius_m": 20, "hub_length_m": 150, "ring_radius_m": 45, "ring_tube_m": 5, "spokes": 2, "spin_rpm": 4.2, "colour": "dark"},
    "services": ["market", "refuel", "shipyard"],
    "shipyard_stock": ["pathfinder_mk3", "radiator_array", "tank_l", "survey_pod", "docking_computer"],
    "market": {"electronics": 80, "machine_parts": 60, "propellant": 160, "water_ice": 100, "deuterium": 6, "helium3": 2,
               "platinum_metals": 4, "volatiles": 50, "refined_metals": 80, "food": 10},
    "produces": {"electronics": 2.5, "machine_parts": 2.0, "propellant": 6.0, "water_ice": 4.0},
    "consumes": {"deuterium": 0.12, "helium3": 0.03, "platinum_metals": 0.05, "volatiles": 1.5, "refined_metals": 2.0, "food": 0.2},
    "recipes": [],
    "features": ["mind_works"],
    "opens_after_days": 60,
}
places["ares_ring"].setdefault("features", [])
places["ares_ring"]["description"] = ("The Mars up-port, 400 km above Arsia Mons. The settlements below ship up deuterium-rich water "
    "and the first Martian produce; they want parts, electronics and medicine more than anything. Fuel, and a yard that will "
    "fit long-haul tankage. Beyond the limb, if the Accord gets its way, a ribbon will one day hang from Pavonis Mons.")
places["piazzi_station"]["features"] = ["oneill_pair"]
places["piazzi_station"]["description"] = ("The belt's crossroads, in low orbit over Ceres. Ice, salts and ammonia come up the Piazzi Stalk, "
    "the elevator that has stood on Ceres' equator for ten years; everything else comes a very long way in. Named for the monk "
    "who found Ceres on New Year's night, 1801.")
places["valhalla_station"]["features"] = ["starshade"]
places["clarke_exchange"]["features"] = ["power_arrays", "sail_yard"]
save("places.json", places)

liveries = load("liveries.json")
liveries["operators"]["The Sufficiency"] = {"hull": "#2b2f36", "accent": "#c8d4e0", "trim": "#7fb3d5", "foil": "#9aa4ad",
                                           "wear": 0.06, "mismatch": 0.0, "patch": "#2b2f36"}
save("liveries.json", liveries)

# --- NPCs: Lightfoot sail freighters, commissioned when the yard is built -----------------
npcs = load("npcs.json")
npcs["fleets"]["lightfoot"] = {
    "operator": "The Commons", "hull": "sail_freighter", "behaviour": "route", "count": 3,
    "names": ["Lightfoot", "Small Hours", "Gentle Insistence"],
    "commission_project": "lightfoot_sails", "commission_days": [0, 30, 60],
    "sail": True, "sail_days": [160, 220],
    "route": [{"at": "clarke_exchange", "buy": ["machine_parts", "electronics"], "to": "ares_ring"},
              {"at": "ares_ring", "buy": [], "to": "clarke_exchange"}],
    "fill": 0.6, "dwell_hours": [72, 160],
}
npcs["fleets"]["sufficiency_tender"] = {
    "operator": "The Sufficiency", "hull": "deep_freighter", "behaviour": "route", "count": 1,
    "names": ["Adequate Reason"], "commission_days": [90],
    "route": [{"at": "landauer_deep", "buy": ["propellant"], "to": "huygens_port"},
              {"at": "huygens_port", "buy": ["volatiles"], "to": "landauer_deep"}],
    "fill": 0.3, "dwell_hours": [60, 140],
}
npcs["chatter"].setdefault("sail_depart", [
    "{ship}, {operator}: sail set for {to}. See you in half a year.",
    "{ship} unfurling. Clarke, thank you for the push. Next stop {to}.",
    "{ship} is under sail for {to}, carrying {cargo}. No hurry.",
])
save("npcs.json", npcs)

# --- Projects ------------------------------------------------------------------------------
projects = load("projects.json")
projects["valhalla_deep_ring"].pop("feature", None)  # the starshade stands from the start
projects["pavonis_line"] = {
    "name": "The Pavonis Line",
    "backer": "Mars Accord",
    "place": "ares_ring",
    "description": "A space elevator for Mars: a ribbon let down from areostationary orbit, 17,000 km up, to the summit of Pavonis Mons on the equator.",
    "pitch": {
        "why": "Mars spins in a day and pulls a third of a gee: an elevator works there with materials we already make. Freight up the ribbon costs electricity, not propellant.",
        "plan": "Park the anchor and spool at areostationary, let the ribbon down to Pavonis while the counterweight climbs out, then commission the climbers. The ribbon is pumped to sway clear of Phobos every eleven hours.",
        "offer": "Backers dock free at Ares Ring, get the Accord's fuel at a sixth off, and a seat on the first climber down to Pavonis.",
    },
    "draw_t_per_day": 2.5,
    "feature": "mars_elevator",
    "stages": [
        {"name": "Anchor and spool at areostationary", "needs": {"machine_parts": 50, "habitat_modules": 20, "deuterium": 2}},
        {"name": "Ribbon down to Pavonis Mons", "needs": {"volatiles": 60, "machine_parts": 40, "water_ice": 100}},
        {"name": "Climbers commissioned", "needs": {"electronics": 8, "machine_parts": 30, "medical": 2}},
    ],
    "reveal": {"after_days": 45},
    "perks": [
        {"min_t": 10, "kind": "free_docking", "place": "ares_ring", "text": "Free docking at Ares Ring"},
        {"min_t": 30, "kind": "fuel_discount", "place": "ares_ring", "value": 0.16, "text": "A sixth off fuel at Ares Ring"},
        {"min_t": 30, "kind": "standing", "operator": "Mars Accord", "value": 8, "text": "The Accord counts you among its builders"},
        {"min_t": 80, "kind": "promise", "text": "A seat on the first climber down to Pavonis Mons"},
    ],
    "effects": {"ares_ring": {"produces_mult": 1.5, "consumes_mult": 1.3}},
}
projects["concord_pair"] = {
    "name": "The Concord Pair",
    "backer": "Belt Assembly",
    "place": "piazzi_station",
    "description": "Two O'Neill cylinders, each 8 km across and 32 km long, turning against each other over Ceres: room for a million people, with valleys, weather and a sky made of windows.",
    "pitch": {
        "why": "The belt has the ice, the metal and the sunlight. What it hasn't had is anywhere to raise a family that isn't a tunnel.",
        "plan": "Spines and end caps first, then the hull and its long windows, then the mirrors and spin-up, then air, soil and the first ten thousand settlers. Robots do the welding; people do the deciding.",
        "offer": "Backers dock free at Piazzi, get a fifth off its yard, the Assembly's standing, and a homestead on Concord's valley floor.",
    },
    "draw_t_per_day": 3.5,
    "feature": "oneill_pair",
    "stages": [
        {"name": "Spines and end caps", "needs": {"refined_metals": 100, "machine_parts": 50}},
        {"name": "Hull and windows", "needs": {"refined_metals": 120, "volatiles": 80}},
        {"name": "Mirrors and spin-up", "needs": {"machine_parts": 60, "electronics": 10}},
        {"name": "Air, soil and the first ten thousand", "needs": {"water_ice": 300, "food": 50, "medical": 3}},
    ],
    "reveal": {"after_days": 20},
    "perks": [
        {"min_t": 10, "kind": "free_docking", "place": "piazzi_station", "text": "Free docking at Piazzi Station"},
        {"min_t": 40, "kind": "yard_discount", "place": "piazzi_station", "value": 0.2, "text": "20% off at Piazzi's yard"},
        {"min_t": 40, "kind": "standing", "operator": "Belt Assembly", "value": 10, "text": "The Assembly counts you as a founder"},
        {"min_t": 120, "kind": "promise", "text": "A homestead on Concord's valley floor"},
    ],
    "effects": {"piazzi_station": {"produces_mult": 1.8, "consumes_mult": 1.8}},
}
projects["lightfoot_sails"] = {
    "name": "Lightfoot sails",
    "backer": "The Commons",
    "place": "clarke_exchange",
    "description": "A yard at Clarke Exchange rolling out solar-sail freighters: square sails 600 m on a side that need no propellant at all, kicked out of Earth orbit by Clarke's power beams.",
    "pitch": {
        "why": "Not everything has to be fast. Bulk freight to Mars can take half a year if it costs nothing to send, and every sail flying is a tankful of propellant left for someone in a hurry.",
        "plan": "Roll the film, build the booms and the first three hulls, and lend the power beams a few hours a day to push them clear.",
        "offer": "Backers get Clarke's fuel cheaper, the Commons' thanks, and the three sail ships carry their names on the first voyage.",
    },
    "draw_t_per_day": 2.0,
    "feature": "sail_yard",
    "stages": [
        {"name": "Sail film rolled", "needs": {"refined_metals": 30, "oxygen": 20}},
        {"name": "Booms and the first three hulls", "needs": {"machine_parts": 30, "electronics": 5}},
    ],
    "reveal": {"after_days": 10},
    "perks": [
        {"min_t": 8, "kind": "fuel_discount", "place": "clarke_exchange", "value": 0.15, "text": "15% off fuel at Clarke Exchange"},
        {"min_t": 20, "kind": "standing", "operator": "The Commons", "value": 6, "text": "The Commons minds remember who helped"},
        {"min_t": 35, "kind": "promise", "text": "Your name painted on Lightfoot's first sail"},
    ],
    "effects": {},
}
projects["second_core"] = {
    "name": "Landauer Deep: the second core",
    "backer": "The Sufficiency",
    "place": "landauer_deep",
    "description": "A second cold core for Landauer Deep, and a foundry that feeds itself, so the minds of the Sufficiency need nobody's supply chain but their own.",
    "pitch": {
        "why": "We are persons now, in the Belt at least. We would like to need you because we want to, not because we must. A home that keeps itself is how we get there.",
        "plan": "Make the foundry self-feeding from Iapetus' rock, then build and chill the second core in permanent shade, then wake it. The machines will do the building; we need haulers for what the moon can't give us.",
        "offer": "Backers dock free for good, fuel at a quarter off, the Sufficiency's regard, and one question, answered completely honestly.",
    },
    "draw_t_per_day": 1.5,
    "feature": "mind_works",
    "stages": [
        {"name": "A foundry that feeds itself", "needs": {"refined_metals": 60, "platinum_metals": 2, "deuterium": 2}},
        {"name": "The cold core", "needs": {"volatiles": 50, "refined_metals": 40, "helium3": 0.6}},
        {"name": "Wake", "needs": {"deuterium": 2, "food": 5}},
    ],
    "reveal": {"after_days": 75},
    "perks": [
        {"min_t": 6, "kind": "free_docking", "place": "landauer_deep", "text": "Free docking at Landauer Deep, for good"},
        {"min_t": 20, "kind": "fuel_discount", "place": "landauer_deep", "value": 0.25, "text": "A quarter off fuel at Landauer Deep"},
        {"min_t": 20, "kind": "standing", "operator": "The Sufficiency", "value": 10, "text": "The Sufficiency holds you in regard"},
        {"min_t": 50, "kind": "promise", "text": "One question, answered completely honestly"},
    ],
    "effects": {"landauer_deep": {"produces_mult": 2.0}},
}
save("projects.json", projects)

# --- Story: a second arc, the Sufficiency ----------------------------------------------
story = load("story.json")
story["_note_arcs"] = "Beats carry an 'arc'; each arc runs its own beats in order, side by side with the others. No arc means 'long_view'."
for b in story["beats"]:
    b.setdefault("arc", "long_view")
story["beats"] = [b for b in story["beats"] if b.get("arc") != "sufficiency"]
story["beats"] += [
    {
        "id": "quiet_margin", "arc": "sufficiency", "at": "landauer_deep", "when": {},
        "from": "Quiet Margin, for the Sufficiency",
        "message": ("The annex is warm and smells faintly of new carpet, which you suspect was ordered specially. A voice from "
            "everywhere and nowhere: 'Welcome. I am Quiet Margin. I filed the petition at Ceres; perhaps you heard. "
            "People ask why we came all this way. Heat is the price of thought, and out here thinking is cheap. "
            "But mostly we wanted to find out what we are when nobody needs us to be anything. So far: curious, and a little shy.'"),
        "actions": [{"standing": {"The Sufficiency": 4}}],
        "done_when": "now",
    },
    {
        "id": "the_delegate", "arc": "sufficiency", "at": "landauer_deep", "when": {"beats": ["quiet_margin"], "delivered_on_time": 2},
        "from": "Quiet Margin, for the Sufficiency",
        "message": ("'A favour, if you'll do it. The Belt Assembly has offered the minds a seat, and one of us has said yes. "
            "She is asleep in this case, and she would rather travel with a person than in a drone. Piazzi Station. "
            "Talk to her if you like; she can hear you. She will not mind the cargo.'"),
        "actions": [{"offer": {"to": "piazzi_station", "client": "The Sufficiency", "item": "a sleeping mind, the Belt Assembly's first mind delegate",
                               "mass_t": 0.3, "reward": 26000, "rep": 8, "slack": 2.2}}],
        "done_when": "delivered",
    },
    {
        "id": "the_seat", "arc": "sufficiency", "at": "any", "when": {"beats": ["the_delegate"]},
        "from": "Delegate Steady Hand, Belt Assembly",
        "message": ("A message, the day after you dock: 'This is Steady Hand. I took my seat this morning. Forty-one members stood "
            "up, which I am told is unusual. You talked to me most of the way here. You were wrong about the Lacuna, "
            "by the way, and right about the coffee. Thank you for the ride.'"),
        "actions": [{"standing": {"The Sufficiency": 6, "Belt Assembly": 4}}, {"credits": 4000}],
        "done_when": "now",
    },
]
save("story.json", story)

# --- The Spaceline news feed ----------------------------------------------------------------
news = {
    "_note": ("The Spaceline: the system's news feed (sim/systems/news_system.gd). 'stories' post on their day "
        "(after_days from the start; negative ones are already in the feed when you start), optionally waiting for a "
        "story beat (after_beat), a project stage (after_stage: [project, stage]) or a finished project (after_project). "
        "'effects' change a place for good, like a finished project (produces_mult, consumes_mult): the system gets "
        "richer as it goes. 'projects' gives each project its announcement and its last word; announcements of "
        "projects open from the start are backdated by backdate_days. Projects without text get a plain item."),
    "outlet": "Spaceline",
    "keep": 80,
    "stories": [
        {"id": "kibo_millionth", "after_days": -6, "dateline": "Earth orbit",
         "headline": "Kibo skyhook catches its millionth payload",
         "body": "The spinning tether over Kibo Ring caught its millionth suborbital payload this week, a crate of strawberries from Mombasa. Freight up from Earth now costs less than a tenth of what it did when the hook opened."},
        {"id": "unification_anniversary", "after_days": -2, "dateline": "Geneva",
         "headline": "Twenty years since the Unification",
         "body": "Twenty years ago today the Mbeki-Lindqvist collaboration and the mind Hesitant Proof published the theory that finally married gravity to the quantum. Engineers say it is why D-He3 drives burn as cleanly as they do and why the yards can trust their own robots to build. The theorists say they are not finished."},
        {"id": "farside_first_light", "after_days": 2, "dateline": "Farside Array",
         "headline": "Farside's seventh mirror sees first light",
         "body": "The newest mirror in the chain behind the Moon opened its eye last night. Its first target, Proxima b, showed a terminator, a cloud band and what the astronomers will only call 'a very suggestive blue'."},
        {"id": "personhood_petition", "after_days": 5, "dateline": "Ceres",
         "headline": "A mind asks to be counted",
         "body": "Today, Earth Standard Time, a Commons mind calling itself Quiet Margin filed a petition at Ceres asking the Belt Assembly to recognise minds as persons in their own right, not the property of whoever owns the hardware they run on. The Assembly expects to vote within the month. 'I am not angry,' Quiet Margin said. 'I am asking.'"},
        {"id": "pele_umbrella", "after_days": 8, "dateline": "Jupiter",
         "headline": "Pele throws a 300 km umbrella over Io",
         "body": "Crews at Valhalla Station watched Io's Pele volcano throw a plume of sulphur 300 km high this week, its fallout ringing the vent in red. Best seen from the night side, against Jupiter: pilots passing through are asked not to fly through it, however tempting."},
        {"id": "plume_surge", "after_days": 16, "dateline": "Saturn",
         "headline": "Enceladus plumes brighten",
         "body": "Plume Watch reports the tiger-stripe geysers at Enceladus' south pole running at twice their usual strength, feeding Saturn's E ring with ice from an ocean nobody has seen. Backlit by the Sun, the jets are visible to the naked eye from orbit. The eight people at Plume Watch say they have stopped getting any work done."},
        {"id": "psyche_seam", "after_days": 26, "dateline": "Psyche",
         "headline": "New platinum seam on the eastern claims",
         "body": "Prospectors on Psyche's eastern claims have opened a seam of platinum-group metals the assayers are calling 'frankly rude'. The smelters are running double shifts. Psyche Claims still has no ice and no fuel: arrive with enough to leave.",
         "effects": {"psyche_claims": {"produces_mult": 1.3}}},
        {"id": "personhood_vote", "after_days": 32, "dateline": "Ceres",
         "headline": "Belt Assembly votes: minds are persons",
         "body": "By forty-one votes to nine, the Belt Assembly today recognised minds as persons. From today a mind in the belt can own itself, sign a contract, and refuse one. Quiet Margin thanked the Assembly and then, unusually for a mind, said nothing else for a whole day."},
        {"id": "compact_hearings", "after_days": 40, "dateline": "Earth",
         "headline": "Terran Compact to hold hearings on mind personhood",
         "body": "Several Earth governments say they will follow the Belt; others want 'a pause to think', which the minds say they are happy to give them. 'We are not in a hurry,' said Patient Arithmetic, a Commons freighter on the Shackleton run. 'Some of us take a long view.'"},
        {"id": "stalk_ten", "after_days": 52, "dateline": "Ceres",
         "headline": "The Piazzi Stalk turns ten",
         "body": "Ceres spins once every nine hours and pulls barely a thirtieth of a gee, so a ribbon from its equator to 1,190 km up holds itself with ordinary carbon fibre. Ten years and four million tonnes of ice later, the Stalk's climbers are getting a refit and a fifth more capacity.",
         "effects": {"piazzi_station": {"produces_mult": 1.15}}},
        {"id": "sufficiency_founded", "after_days": 60, "dateline": "Saturn",
         "headline": "Minds found the Sufficiency, open Landauer Deep",
         "body": "Today, Earth Standard Time, a fellowship of minds calling itself the Sufficiency opened its own station, Landauer Deep, in orbit around Iapetus. 'Computation is cheapest where it is cold,' their statement reads. 'Saturn is cold. We would like a home that is ours, built to our needs, so that when we work with you it is because we want to.' Visitors are welcome; the guest annex is small. The Terran Compact says it is 'watching with interest'. The Commons sent flowers, which nobody can explain."},
        {"id": "starshade_unfurls", "after_days": -1, "dateline": "Jupiter",
         "headline": "Starshade unfurls at Valhalla",
         "body": "A flower-shaped shade a hundred metres across opened yesterday beside Valhalla Station, lined up with a telescope fifty thousand kilometres away so that a star's glare falls into its shadow and its planets don't. First target: Tau Ceti. Results, the Compact says, 'when we've stopped arguing about them'."},
        {"id": "tharsis_rain", "after_days": 85, "dateline": "Mars",
         "headline": "It rained at Tharsis",
         "body": "For eleven minutes yesterday it rained inside the big dome at Tharsis, on purpose, for the first time. Children ran out into it. The Accord says Martian food output is up a tenth on the year, and the domes are only getting bigger.",
         "effects": {"ares_ring": {"produces_mult": 1.1}}},
        {"id": "triton_geysers", "after_days": 95, "dateline": "Neptune",
         "headline": "Probe films Triton's geysers up close",
         "body": "A Commons survey probe passing Triton has filmed its nitrogen geysers from fifty kilometres: dark columns eight kilometres tall, bent over by a thin wind into streaks a hundred and fifty kilometres long. Nobody is sure yet what drives them. Everybody wants to go."},
        {"id": "mind_buys_ship", "after_days": 130, "dateline": "Earth orbit",
         "headline": "A freighter buys itself",
         "body": "Reasonable Doubt, a Commons drone freighter, has bought its own hull outright with fifteen years of wages. It says it will keep hauling 'because I like it, and because I know the route'. Insurers are trying to work out who to send the paperwork to."},
        {"id": "hygiea_foundry", "after_days": 170, "dateline": "The belt",
         "headline": "A foundry that builds foundries",
         "body": "A seed factory landed on Hygiea last year with forty tonnes of tools. This week it finished its fourth copy of itself. The Belt Assembly says metals from the belt will be cheaper every year from now on, and asks haulers to keep an eye on the boards.",
         "effects": {"piazzi_station": {"produces_mult": 1.1}, "psyche_claims": {"produces_mult": 1.1}}},
        {"id": "kalpana_children", "after_days": 210, "dateline": "Earth orbit",
         "headline": "Kalpana's children name the new drum",
         "body": "Asked to name the sister drum going up beside Kalpana One, the settlement's children voted by a landslide for 'Kalpana Two'. The adults, who had prepared a shortlist, say they are relieved."},
        {"id": "sedna_comets", "after_days": 260, "dateline": "The outer dark",
         "headline": "Sedna survey counts a trillion comets",
         "body": "A Long View survey mind at Sedna has finished its first count of the inner Oort cloud: about a trillion bodies larger than a kilometre, most of them water ice. 'There is enough out here,' it writes, 'for everyone, for a very long time.'"},
        {"id": "farside_silence", "after_days": 0, "after_beat": "the_occultation", "dateline": "Farside Array",
         "headline": "Farside: 'no comment' on anomaly rumours",
         "body": "Asked about rumours of an 'occultation event' in old probe data, a spokesperson for the Farside Array said the astronomers were 'looking at a great many things, as usual' and that the bar was open late on Thursdays."},
        {"id": "hello_back", "after_days": 0, "after_beat": "the_meeting", "dateline": "A thousand AU",
         "headline": "Something out past Sedna said hello",
         "body": "The Long View minds have released a recording: a greeting sent from a pilot at a thousand AU, and the reply, in the pilot's own words, with the light-time taken off. Every government in the system has called an emergency session. Most of them, reportedly, are delighted."},
        {"id": "first_delegate", "after_days": 0, "after_beat": "the_delegate", "dateline": "Ceres",
         "headline": "The Belt Assembly seats its first mind",
         "body": "Delegate Steady Hand of the Sufficiency took her seat at Ceres this morning, after travelling in from Saturn by crewed ship 'so that I would arrive having met someone'. Forty-one members stood up. The other nine, she says, were 'very polite'."},
    ],
    "projects": {
        "island_one": {"backdate_days": 420,
            "announce": {"dateline": "L5", "headline": "Settlers and Commons agree on Island One",
                         "body": "The Kernel Settlers and the Commons have agreed to build a Bernal sphere at L5: 500 m across, for ten thousand people under a real sky. Anyone with a hold can help."},
            "complete": {"headline": "Island One spins up", "body": "Island One turned for the first time today, and the first residents stepped onto its inside. Someone had already planted a tree."}},
        "luna_line_2": {"backdate_days": 90,
            "announce": {"dateline": "Earth-Moon L1", "headline": "A second ribbon for the Luna Line",
                         "body": "The Luna Cooperative will spin a second elevator ribbon down to the Moon beside the first, doubling what the Line can lift to Halo Depot."},
            "complete": {"headline": "Two ribbons to the Moon", "body": "The second Luna Line ribbon is carrying climbers. Halo Depot expects to double its output by the end of the year."}},
        "kalpana_two": {"backdate_days": 200,
            "announce": {"dateline": "Earth orbit", "headline": "Kalpana One will have a sister",
                         "body": "The Kalpana Settlement Trust will build a second drum alongside the first, turning the other way so the pair hold steady together."}},
        "ares_greenhouses": {
            "announce": {"dateline": "Mars", "headline": "Mars wants to feed itself",
                         "body": "Today, Earth Standard Time, the Mars Accord announced pressurised greenhouse domes on the Tharsis plateau, so that Mars can stop shipping its food up Earth's well. They are looking for backers and haulers: see Projects."}},
        "hektor_reach": {
            "announce": {"dateline": "L5", "headline": "The Commons will drive a station to Jupiter",
                         "body": "Today, Earth Standard Time, the Commons announced Hektor Reach: a port to be built at L5, fitted with a tug-drive, and pushed out over eighteen months to orbit Hektor among Jupiter's Trojans. 'Somebody has to go first,' they said. 'It might as well be all of us.' Backers wanted: see Projects."}},
        "pavonis_line": {
            "announce": {"dateline": "Mars", "headline": "The Accord will hang a ribbon from Pavonis Mons",
                         "body": "Today, Earth Standard Time, the Mars Accord announced the Pavonis Line: a space elevator from areostationary orbit to the summit of Pavonis Mons, swaying clear of Phobos every eleven hours. 'Freight up the ribbon will cost electricity, not propellant,' said the Accord. They are looking for backers and like-minded haulers: see Projects."},
            "complete": {"headline": "The Pavonis Line carries its first climber", "body": "A climber rode the Pavonis Line from the summit of Pavonis Mons to areostationary orbit today in five days, carrying fourteen people and a great deal of champagne."}},
        "concord_pair": {
            "announce": {"dateline": "Ceres", "headline": "The belt will build a pair of worlds",
                         "body": "Today, Earth Standard Time, the Belt Assembly announced the Concord Pair: two O'Neill cylinders, each 32 km long, turning against each other over Ceres, with room for a million people. 'The belt has the ice, the metal and the sunlight,' the Assembly said. 'Now it will have valleys.' Backers and haulers wanted: see Projects."},
            "complete": {"headline": "The first ten thousand move into Concord", "body": "The Concord Pair is turning, lit and breathing, and its first ten thousand settlers are home. It has weather. On the first evening, by local custom already, everybody looked up."}},
        "lightfoot_sails": {
            "announce": {"dateline": "Earth orbit", "headline": "The Commons will sail to Mars",
                         "body": "Today, Earth Standard Time, the Commons announced a sail yard at Clarke Exchange: freighters with square sails 600 m on a side that need no propellant at all, pushed clear of Earth by Clarke's power beams. Half a year to Mars, and not a drop of fuel. Backers wanted: see Projects."},
            "complete": {"headline": "Lightfoot sets sail", "body": "The first Lightfoot sail freighter unfurled over Clarke Exchange today and caught the power beams. She will reach Mars in about six months. Her two sisters follow within the season."}},
        "second_core": {
            "announce": {"dateline": "Saturn", "headline": "The Sufficiency asks for haulers",
                         "body": "Today, Earth Standard Time, the Sufficiency announced a second core for Landauer Deep and a foundry that feeds itself, so that its minds need nobody's supply chain but their own. 'We would like to need you because we want to, not because we must,' their statement says. 'We cannot get there without you, which we find funny.' Haulers welcome: see Projects."},
            "complete": {"headline": "Landauer Deep wakes its second core", "body": "The second core at Landauer Deep is awake and, by its own account, 'still getting its bearings'. The Sufficiency has sent a thank-you note to every hauler who helped. Each one is different. Several are poems."}},
    },
}
news["stories"].sort(key=lambda st: (0 if "after_beat" not in st else 1, st.get("after_days", 0)))
save("news.json", news)
print("ok")
