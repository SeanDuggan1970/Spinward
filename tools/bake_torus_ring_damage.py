"""A Stanford torus (the Tsiolkovsky Wheel at L4), a lunar orbital ring (the Selene
Ring), hazard fields of rocks on some approaches, and the damage model's numbers.
Run after bake_rich_system.py and bake_elevators.py. Idempotent."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def save(name, d):
    open(os.path.join(ROOT, "data", name), "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


places = load("places.json")
places["tsiolkovsky_wheel"] = {
    "name": "Tsiolkovsky Wheel",
    "operator": "Terran Compact",
    "opens_with": "tsiolkovsky_wheel",
    "description": ("A Stanford torus 1.8 km across, built at L4, 12 km from Trojan Yards: ten thousand people in a ring "
        "130 m thick, turning once a minute for a full gee at the rim, with sunlight brought in by a great mirror over "
        "the hub. Farms, schools, a university and a waiting list. Named for the schoolteacher who saw it first."),
    "location": {"type": "lagrange", "system": ["earth", "moon"], "point": "L4", "offset_km": [12.0, 0.0, 2.0]},
    "station": {"type": "stanford", "hub_radius_m": 60, "hub_length_m": 240, "ring_radius_m": 900, "ring_tube_m": 65,
                "spokes": 6, "spin_rpm": 1.0, "colour": "offwhite", "port_radius_m": 10},
    "services": ["market", "refuel"],
    "market": {"food": 200, "medical": 14, "electronics": 30, "water_ice": 160, "oxygen": 100, "machine_parts": 40,
               "habitat_modules": 20, "propellant": 80},
    "produces": {"food": 6.0, "electronics": 1.0, "medical": 0.3},
    "consumes": {"water_ice": 6.0, "oxygen": 3.0, "machine_parts": 1.0, "habitat_modules": 0.3, "propellant": 2.0},
    "recipes": [],
}
places["trojan_yards"]["features"] = ["captured_rock", "stanford_torus"]
places["shackleton_port"]["description"] = ("Polar orbit port above Shackleton crater. Surface crews and their AI rovers "
    "lift ice, regolith and helium-3 to it. Below, if the Cooperative has its way, a ring will one day girdle the Moon.")
# Rocks on the approach: mining tailings, rubble and ice chunks. View-side hazards.
places["psyche_claims"]["hazards"] = {"rocks": 36, "radius_m": [1.5, 26.0], "field_m": [250.0, 4000.0], "drift_mps": 0.08,
                                      "look": "metal", "note": "tailings from the smelters, drifting"}
places["hektor_reach"]["hazards"] = {"rocks": 28, "radius_m": [2.0, 40.0], "field_m": [300.0, 5000.0], "drift_mps": 0.05,
                                     "look": "rubble", "note": "rubble shed by Hektor's two lobes"}
places["trojan_yards"]["hazards"] = {"rocks": 18, "radius_m": [1.0, 12.0], "field_m": [250.0, 2500.0], "drift_mps": 0.1,
                                     "look": "rubble", "note": "spoil from the captured rock"}
places["piazzi_station"]["hazards"] = {"rocks": 10, "radius_m": [1.0, 8.0], "field_m": [400.0, 3000.0], "drift_mps": 0.04,
                                       "look": "ice", "note": "ice chunks off the Stalk's loading yard"}
save("places.json", places)

bodies = load("bodies.json")
bodies["moon"]["structures"] = [s for s in bodies["moon"].get("structures", []) if s.get("kind") != "orbital_ring"]
bodies["moon"]["structures"].append({"kind": "orbital_ring", "name": "the Selene Ring", "radius_r": 1.03, "tethers": 12,
                                     "project": "selene_ring"})
bodies["_note_orbital_ring"] = ("'orbital_ring': a ring round the equator at radius_r body radii, moving faster than orbit "
    "inside a stationary sheath, with tethers to the ground; built in arcs with its project.")
save("bodies.json", bodies)

projects = load("projects.json")
projects["tsiolkovsky_wheel"] = {
    "name": "The Tsiolkovsky Wheel",
    "backer": "Terran Compact",
    "place": "trojan_yards",
    "description": "A Stanford torus at L4: a ring 1.8 km across and 130 m thick, home for ten thousand, turning once a minute.",
    "pitch": {
        "why": "Kalpana One proved people can live in orbit. The Wheel is where they raise children, run farms and grow old: a town, not a posting.",
        "plan": "Hub and spokes, then the ring tube in sections, then regolith shielding packed round it, then the mirrors, air and soil. Trojan Yards builds it; the robots weld; the settlers argue about street names.",
        "offer": "Backers dock free at the Wheel, get the Compact's standing, and a flat on the rim with Earth in the window.",
    },
    "draw_t_per_day": 3.0,
    "feature": "stanford_torus",
    "stages": [
        {"name": "Hub and spokes", "needs": {"refined_metals": 80, "machine_parts": 40}},
        {"name": "The ring tube", "needs": {"refined_metals": 100, "habitat_modules": 60}},
        {"name": "Regolith shielding", "needs": {"regolith": 400}},
        {"name": "Mirrors, air, soil and the first ten thousand", "needs": {"oxygen": 60, "food": 40, "electronics": 8}},
    ],
    "reveal": {"after_days": 15},
    "perks": [
        {"min_t": 10, "kind": "free_docking", "place": "tsiolkovsky_wheel", "text": "Free docking at the Tsiolkovsky Wheel"},
        {"min_t": 40, "kind": "standing", "operator": "Terran Compact", "value": 8, "text": "The Compact counts you among the Wheel's builders"},
        {"min_t": 120, "kind": "promise", "text": "A flat on the rim with Earth in the window"},
    ],
    "effects": {"trojan_yards": {"produces_mult": 1.2}},
}
projects["selene_ring"] = {
    "name": "The Selene Ring",
    "backer": "Luna Cooperative",
    "place": "shackleton_port",
    "description": "An orbital ring round the Moon's equator, 52 km up: a cable moving faster than orbit inside a sheath that stands still, with tethers to the ground.",
    "pitch": {
        "why": "An elevator touches the Moon in one place. A ring touches it everywhere: freight up and down from anywhere on the equator, launched by magnets instead of rockets.",
        "plan": "Spin the first arc, close the ring, then let the tethers down to the surface stations. The Moon has no air to fight, so it can sit lower than any ring ever could round Earth.",
        "offer": "Backers get the Cooperative's fuel at a fifth off at Shackleton, its standing, and a launch slot on the ring's first mass driver.",
    },
    "draw_t_per_day": 2.5,
    "stages": [
        {"name": "The first arc", "needs": {"machine_parts": 50, "regolith": 200}},
        {"name": "The ring closed", "needs": {"machine_parts": 60, "electronics": 10, "regolith": 250}},
        {"name": "Tethers to the ground", "needs": {"water_ice": 150, "machine_parts": 30, "medical": 2}},
    ],
    "reveal": {"after_days": 100},
    "perks": [
        {"min_t": 10, "kind": "fuel_discount", "place": "shackleton_port", "value": 0.2, "text": "20% off fuel at Shackleton Port"},
        {"min_t": 40, "kind": "standing", "operator": "Luna Cooperative", "value": 10, "text": "The Cooperative counts you as one of the Ring's builders"},
        {"min_t": 100, "kind": "promise", "text": "A launch slot on the Ring's first mass driver"},
    ],
    "effects": {"shackleton_port": {"produces_mult": 1.6}},
}
save("projects.json", projects)

news = load("news.json")
news["projects"]["tsiolkovsky_wheel"] = {
    "announce": {"dateline": "L4", "headline": "A wheel for ten thousand at L4",
                 "body": ("Today, Earth Standard Time, the Terran Compact announced the Tsiolkovsky Wheel: a Stanford torus 1.8 km "
                          "across, to be built beside Trojan Yards, turning once a minute for a full gee. 'A town, not a posting,' "
                          "said the Compact. Backers and haulers wanted: see Projects.")},
    "complete": {"headline": "The Tsiolkovsky Wheel turns", "body": "The Tsiolkovsky Wheel is spun up, lit and breathing, and open to visitors at L4. Its first school opened this morning. The children were, the teachers report, unimpressed by the view within a week."},
}
news["projects"]["selene_ring"] = {
    "announce": {"dateline": "The Moon", "headline": "The Cooperative will put a ring round the Moon",
                 "body": ("Today, Earth Standard Time, the Luna Cooperative announced the Selene Ring: an orbital ring 52 km above "
                          "the Moon's equator, a cable running faster than orbit inside a sheath that stands still, with tethers "
                          "to the ground. 'An elevator touches the Moon in one place,' they said. 'A ring touches it everywhere.' "
                          "Backers wanted: see Projects.")},
    "complete": {"headline": "The Moon has a ring", "body": "The last tether of the Selene Ring reached the ground at Mare Smythii this morning. The Moon is now, officially, a ringed world. Earth's night side can see it as a thin bright line."},
}
save("news.json", news)

balance = load("balance.json")
balance["damage"] = {
    "_note": ("Collisions (sim/systems/damage_system.gd). Below safe_mps a bump does nothing. Above it, the energy "
              "absorbed per kilogram of ship (0.5 v^2, times the share the other body takes) over full_j_per_kg is the damage "
              "to the module hit (1 = wrecked); keel_share of that goes to the keel, and a wrecked keel is a lost ship. "
              "Damaged drives lose thrust, tanks and pods lose capacity (venting and spilling what no longer fits), "
              "radiators reject less heat, habs keep you alive for less long."),
    "safe_mps": 0.8, "full_j_per_kg": 50.0, "keel_share": 0.35,
    "repair_cr_per_point": 0.6, "keel_value": 9000.0, "min_module_value": 3000.0,
    "patch_max": 0.25, "patch_mult": 1.6,
    "insurance_excess": 3000.0, "lifeboat_s": 25.0,
}
save("balance.json", balance)
print("ok")
