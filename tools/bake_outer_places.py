"""Adds the outer-system ports, goods and liveries (one-off content script; safe to
re-run, it overwrites only the entries it owns)."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def save(name, d):
    open(os.path.join(ROOT, "data", name), "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


goods = load("goods.json")
goods["deuterium"] = {"name": "Deuterium", "base_price": 9000,
    "description": "Heavy hydrogen, the other half of fusion fuel. Martian water is five times richer in it than Earth's."}
goods["volatiles"] = {"name": "Volatiles", "base_price": 160,
    "description": "Ammonia, methane and nitrogen: fertiliser, air buffer and chemical feedstock the inner system is always short of."}
goods["platinum_metals"] = {"name": "Platinum metals", "base_price": 22000,
    "description": "Platinum, iridium, osmium. Catalysts and electrodes; a metal asteroid has more of them than all Earth's mines."}
save("goods.json", goods)


def orbit(parent, alt_m, radius_m, i=0.0, m0=0.0):
    return {"type": "orbit", "parent": parent,
            "elements": {"a_m": radius_m + alt_m, "e": 0.0, "i_deg": i, "node_deg": 0.0, "peri_deg": 0.0, "m0_deg": m0}}


bodies = load("bodies.json")
R = lambda b: float(bodies[b]["radius_m"])
places = load("places.json")
NEW = {
    "ares_ring": {
        "name": "Ares Ring", "operator": "Mars Accord",
        "description": "The Mars up-port, 400 km above Arsia Mons. The settlements below ship up deuterium-rich water and the first Martian produce; they want parts, electronics and medicine more than anything. Fuel, and a yard that will fit long-haul tankage.",
        "location": orbit("mars", 400000.0, R("mars"), 25.0),
        "station": {"hub_radius_m": 16, "hub_length_m": 110, "ring_radius_m": 120, "ring_tube_m": 12, "spokes": 4, "spin_rpm": 2.4, "colour": "rust"},
        "services": ["market", "refuel", "shipyard"],
        "shipyard_stock": ["cargo_pod_m", "tank_m", "radiator_panel_l"],
        "market": {"deuterium": 6, "food": 120, "water_ice": 150, "machine_parts": 30, "electronics": 12, "medical": 6, "habitat_modules": 20, "propellant": 200, "oxygen": 80},
        "produces": {"deuterium": 0.3, "food": 4, "water_ice": 6},
        "consumes": {"machine_parts": 3, "electronics": 0.8, "medical": 0.4, "habitat_modules": 1.5, "oxygen": 2},
        "recipes": [{"inputs": {"water_ice": 3}, "outputs": {"propellant": 2}}],
    },
    "piazzi_station": {
        "name": "Piazzi Station", "operator": "Belt Assembly",
        "description": "The belt's crossroads, in low orbit over Ceres. Ice, salts and ammonia come up from the bright crater fields; everything else comes a very long way in. Named for the monk who found Ceres on New Year's night, 1801.",
        "location": orbit("ceres", 200000.0, R("ceres"), 10.0),
        "station": {"hub_radius_m": 14, "hub_length_m": 90, "ring_radius_m": 100, "ring_tube_m": 10, "spokes": 6, "spin_rpm": 2.8, "colour": "grey"},
        "services": ["market", "refuel"],
        "market": {"water_ice": 600, "volatiles": 300, "propellant": 250, "food": 80, "medical": 6, "electronics": 10, "machine_parts": 40, "oxygen": 60},
        "produces": {"water_ice": 20, "volatiles": 8},
        "consumes": {"food": 3, "medical": 0.3, "electronics": 0.6, "machine_parts": 2},
        "recipes": [{"inputs": {"water_ice": 3}, "outputs": {"propellant": 2}}, {"inputs": {"water_ice": 2}, "outputs": {"oxygen": 1}}],
    },
    "psyche_claims": {
        "name": "Psyche Claims", "operator": "Independent",
        "description": "A prospectors' camp on a world of iron and nickel, 220 km across. Smelters run on the claims day and night; the platinum metals pay for everything. No ice, so no fuel: arrive with enough to leave.",
        "location": orbit("psyche", 60000.0, R("psyche"), 0.0),
        "station": {"hub_radius_m": 9, "hub_length_m": 60, "ring_radius_m": 50, "ring_tube_m": 6, "spokes": 3, "spin_rpm": 3.6, "colour": "steel"},
        "services": ["market"],
        "market": {"refined_metals": 300, "platinum_metals": 3, "food": 40, "oxygen": 40, "machine_parts": 30, "medical": 3, "water_ice": 60},
        "produces": {"refined_metals": 10, "platinum_metals": 0.06},
        "consumes": {"food": 2, "oxygen": 2, "machine_parts": 2.5, "medical": 0.2, "water_ice": 3},
        "recipes": [],
    },
    "valhalla_station": {
        "name": "Valhalla Station", "operator": "Terran Compact Science",
        "description": "Above Callisto's great Valhalla basin, outside the worst of Jupiter's radiation belts. Jupiter hangs in the sky eight times the width of a full Moon. Science crews, ice miners, and a standing rule: nobody lands on Europa.",
        "location": orbit("callisto", 300000.0, R("callisto"), 0.0),
        "station": {"hub_radius_m": 18, "hub_length_m": 120, "ring_radius_m": 140, "ring_tube_m": 12, "spokes": 6, "spin_rpm": 2.0, "colour": "offwhite"},
        "services": ["market", "refuel"],
        "market": {"water_ice": 800, "propellant": 300, "food": 100, "medical": 8, "electronics": 20, "machine_parts": 60, "oxygen": 80},
        "produces": {"water_ice": 18},
        "consumes": {"food": 4, "medical": 0.5, "electronics": 1.2, "machine_parts": 3},
        "recipes": [{"inputs": {"water_ice": 3}, "outputs": {"propellant": 2}}, {"inputs": {"water_ice": 2}, "outputs": {"oxygen": 1}}],
    },
    "huygens_port": {
        "name": "Huygens Port", "operator": "Huygens Trust",
        "description": "High over Titan's orange haze. Below, methane seas and nitrogen air; above, Saturn and its rings. Titan's hydrocarbons crack into propellant and volatiles cheaper here than anywhere in the system.",
        "location": orbit("titan", 1500000.0, R("titan"), 0.0),
        "station": {"hub_radius_m": 16, "hub_length_m": 100, "ring_radius_m": 110, "ring_tube_m": 11, "spokes": 4, "spin_rpm": 2.5, "colour": "orange"},
        "services": ["market", "refuel"],
        "market": {"volatiles": 600, "propellant": 500, "food": 80, "medical": 6, "electronics": 15, "machine_parts": 50, "habitat_modules": 10},
        "produces": {"volatiles": 12, "propellant": 6},
        "consumes": {"food": 3, "medical": 0.4, "electronics": 1.0, "machine_parts": 2.5, "habitat_modules": 0.5},
        "recipes": [],
    },
    "plume_watch": {
        "name": "Plume Watch", "operator": "Terran Compact Science",
        "description": "A research outpost in orbit around Enceladus, sampling the geysers of its hidden ocean from a respectful distance. Eight people, a lot of patience, and questions nobody can answer yet.",
        "location": orbit("enceladus", 100000.0, R("enceladus"), 0.0),
        "station": {"hub_radius_m": 8, "hub_length_m": 50, "ring_radius_m": 40, "ring_tube_m": 5, "spokes": 3, "spin_rpm": 3.8, "colour": "offwhite"},
        "services": ["market"],
        "market": {"food": 30, "medical": 3, "electronics": 8, "machine_parts": 15, "oxygen": 20},
        "produces": {},
        "consumes": {"food": 1, "medical": 0.1, "electronics": 0.4, "machine_parts": 0.6, "oxygen": 0.8},
        "recipes": [],
    },
}
places.update(NEW)
# The inner system buys what the outer system sells.
kibo = places["kibo_ring"]
kibo["market"].update({"deuterium": 4, "platinum_metals": 2, "volatiles": 60})
kibo["consumes"].update({"deuterium": 0.15, "platinum_metals": 0.03, "volatiles": 2})
trojan = places["trojan_yards"]
trojan["market"].update({"platinum_metals": 1, "volatiles": 40})
trojan["consumes"].update({"platinum_metals": 0.02, "volatiles": 1.5})
kernel = places["kernel_l5"]
kernel["market"].update({"volatiles": 50})
kernel["consumes"].update({"volatiles": 2})
save("places.json", places)

liv = load("liveries.json")
liv["operators"]["Mars Accord"] = {"hull": "#c9b8a2", "accent": "#9a3a24", "trim": "#d8b02a", "foil": "#c9a24a", "wear": 0.45, "mismatch": 0.15, "patch": "#8c9196"}
liv["operators"]["Belt Assembly"] = {"hull": "#5d6670", "accent": "#e0a030", "trim": "#d8b02a", "foil": "#cfcfc8", "wear": 0.6, "mismatch": 0.25, "patch": "#7a7f82"}
liv["operators"]["Huygens Trust"] = {"hull": "#e2d6c2", "accent": "#c4762a", "trim": "#2b2f33", "foil": "#c9a24a", "wear": 0.3, "mismatch": 0.08, "patch": "#b9b0a0"}
save("liveries.json", liv)
print("places:", len([k for k in places if not k.startswith("_")]))
