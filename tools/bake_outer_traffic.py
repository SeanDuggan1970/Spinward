"""Outer-system NPC traffic: the deep freighter hull and long-haul fleets that are
commissioned over the first months, so the outer system fills in gradually."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def save(name, d):
    open(os.path.join(ROOT, "data", name), "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


ships = load("ships.json")
ships["deep_freighter"] = {
    "name": "Deep freighter",
    "description": "A heavy keel built for months between ports: three boxes of cargo, a long-duration hab, four long-haul tanks and twin Mk3 drives. Crews sign on for a year at a time.",
    "spine": "heavy_spine",
    "modules": {
        "command.0": "cmd_pod_basic", "cargo.0": "cargo_pod_m", "cargo.1": "cargo_pod_m", "cargo.2": "cargo_pod_m",
        "cargo.3": "hab_extended", "cargo.4": "tank_l", "cargo.5": "tank_l", "tank.0": "tank_l", "tank.1": "tank_l",
        "drive.0": "pathfinder_mk3", "drive.1": "pathfinder_mk3",
        "radiator.0": "radiator_array", "radiator.1": "radiator_array", "radiator.2": "radiator_array", "radiator.3": "radiator_array",
    },
    "look": {"cargo_layout": "line"},
}
save("ships.json", ships)

places = load("places.json")
places["piazzi_station"]["market"].setdefault("refined_metals", 120)
places["piazzi_station"]["market"].setdefault("platinum_metals", 2)
places["piazzi_station"]["consumes"].setdefault("refined_metals", 2.0)
places["piazzi_station"]["consumes"].setdefault("platinum_metals", 0.01)
save("places.json", places)

npcs = load("npcs.json")
npcs["_note"] = npcs["_note"].rstrip() + (" 'commission_days' (one per ship) staggers when each ship enters service, in days from the start,"
    " so long-haul traffic builds up as the game goes on; until then a ship is fitting out and out of sight.")
fleets = npcs["fleets"]
fleets["accord_runners"] = {
    "operator": "Mars Accord", "hull": "deep_freighter", "behaviour": "route", "count": 2,
    "names": ["Red Ledger", "Tharsis Dawn"], "commission_days": [0, 120],
    "route": [{"at": "ares_ring", "buy": ["deuterium", "food"], "to": "kibo_ring"},
              {"at": "kibo_ring", "buy": ["machine_parts", "electronics", "medical"], "to": "ares_ring"}],
    "fill": 0.4, "dwell_hours": [48, 120],
}
fleets["belt_haulers"] = {
    "operator": "Belt Assembly", "hull": "deep_freighter", "behaviour": "route", "count": 2,
    "names": ["Salt and Patience", "Long Odds"], "commission_days": [30, 200],
    "route": [{"at": "piazzi_station", "buy": ["volatiles", "water_ice"], "to": "ares_ring"},
              {"at": "ares_ring", "buy": ["food"], "to": "piazzi_station"}],
    "fill": 0.4, "dwell_hours": [48, 120],
}
fleets["psyche_ore"] = {
    "operator": "Belt Assembly", "hull": "deep_freighter", "behaviour": "route", "count": 1,
    "names": ["Iron Rose"], "commission_days": [60],
    "route": [{"at": "psyche_claims", "buy": ["platinum_metals", "refined_metals"], "to": "piazzi_station"},
              {"at": "piazzi_station", "buy": ["food", "oxygen", "water_ice"], "to": "psyche_claims"}],
    "fill": 0.4, "dwell_hours": [72, 160],
}
fleets["saturn_tender"] = {
    "operator": "Huygens Trust", "hull": "deep_freighter", "behaviour": "route", "count": 1,
    "names": ["Cassini's Gap"], "commission_days": [150],
    "route": [{"at": "huygens_port", "buy": ["propellant"], "to": "valhalla_station"},
              {"at": "valhalla_station", "buy": [], "to": "huygens_port"}],
    "fill": 0.3, "dwell_hours": [96, 200],
}
save("npcs.json", npcs)
print("ok")
