"""Rideable space elevators: the Luna Line, the Piazzi Stalk and the Pavonis Line.

Each anchor port gets an "elevator" (which body, the foot town, the run in km, the
ride in hours, the fare); each foot is a surface town ("foot_of" its port) that
ships cannot fly to: you ride down with your cargo in a climber container, your
ship left docked above. Climber fleets keep the towns supplied. Idempotent."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def save(name, d):
    open(os.path.join(ROOT, "data", name), "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


places = load("places.json")
places["halo_depot"]["elevator"] = {
    "name": "the Luna Line", "foot": "line_foot", "body": "moon", "km": 56000, "hours": 56, "fare": 150, "fare_per_t": 20,
    "via": "Straight down the ribbon from the depot: 56,000 km, two days and a bit, with the Moon swelling under the floor.",
}
places["piazzi_station"]["elevator"] = {
    "name": "the Piazzi Stalk", "foot": "stalk_foot", "body": "ceres", "km": 720, "hours": 7, "fare": 80, "fare_per_t": 12,
    "via": "A tender takes you across to the Stalk's anchor, 1,190 km out from Ceres' centre, then it is an afternoon down the ribbon.",
}
places["ares_ring"]["elevator"] = {
    "name": "the Pavonis Line", "foot": "pavonis_foot", "body": "mars", "km": 17030, "hours": 120, "fare": 600, "fare_per_t": 45,
    "project": "pavonis_line",
    "via": "The Accord's tender lifts you to the anchor at areostationary, then five days down the ribbon to the summit of Pavonis Mons.",
}
places["line_foot"] = {
    "name": "Line Foot",
    "operator": "Luna Cooperative",
    "foot_of": "halo_depot",
    "description": ("Where the Luna Line touches down, in Sinus Medii at the centre of the Moon's near side, with Earth "
        "hanging overhead and never moving. Regolith trains, a foundry, a hostel for climber crews and a bar "
        "that claims the best view in the system. Ships can't land here: you come down the ribbon."),
    "location": {"type": "surface", "parent": "moon", "facing": "earth"},
    "services": ["market"],
    "market": {"regolith": 500, "refined_metals": 140, "helium3": 2, "oxygen": 60, "water_ice": 40, "food": 30,
               "machine_parts": 20, "medical": 3, "electronics": 6},
    "produces": {"regolith": 20.0, "refined_metals": 3.0, "helium3": 0.04, "oxygen": 2.0},
    "consumes": {"food": 1.5, "machine_parts": 0.6, "medical": 0.08, "electronics": 0.2, "water_ice": 1.0},
    "recipes": [],
}
places["stalk_foot"] = {
    "name": "Stalk Foot",
    "operator": "Belt Assembly",
    "foot_of": "piazzi_station",
    "description": ("The bottom of the Piazzi Stalk: ten thousand people dug into Ceres' equatorial plain, under a "
        "thirtieth of a gee and a sky that turns once every nine hours. Ice and salts by the trainload; everything "
        "else rides down the ribbon. Ships can't land here: you come down the Stalk."),
    "location": {"type": "surface", "parent": "ceres", "lat_deg": 0.0, "lon_deg": 30.0, "day_s": 32667.0},
    "services": ["market"],
    "market": {"water_ice": 900, "volatiles": 400, "regolith": 300, "food": 40, "medical": 4, "electronics": 6,
               "machine_parts": 25, "habitat_modules": 10},
    "produces": {"water_ice": 15.0, "volatiles": 6.0, "regolith": 8.0},
    "consumes": {"food": 1.5, "medical": 0.1, "electronics": 0.2, "machine_parts": 0.5, "habitat_modules": 0.2},
    "recipes": [],
}
places["pavonis_foot"] = {
    "name": "Pavonis Foot",
    "operator": "Mars Accord",
    "foot_of": "ares_ring",
    "opens_with": "pavonis_line",
    "description": ("A town on the summit of Pavonis Mons, fourteen kilometres up, where the Pavonis Line comes down. "
        "The air outside is a hundredth of a breath and the sky is dark at noon; inside, greenhouses and the Accord's "
        "freight yards. Ships can't land here: you come down the ribbon."),
    "location": {"type": "surface", "parent": "mars", "lat_deg": 0.8, "lon_deg": -113.0, "day_s": 88642.0},
    "services": ["market"],
    "market": {"food": 100, "deuterium": 6, "water_ice": 150, "volatiles": 60, "machine_parts": 20, "electronics": 8,
               "medical": 4, "habitat_modules": 15},
    "produces": {"food": 4.0, "deuterium": 0.15, "water_ice": 6.0, "volatiles": 2.0},
    "consumes": {"machine_parts": 1.0, "electronics": 0.4, "medical": 0.15, "habitat_modules": 0.3},
    "recipes": [],
}
save("places.json", places)

modules = load("modules.json")
modules["climber_cab"] = {
    "name": "Climber drive", "kind": "drive", "mass_t": 3.0, "price": 0, "climber": True,
    "description": "Traction wheels on the ribbon, beamed or solar power, and no propellant at all.",
    "look": {"shape": "climber", "size_m": [4.0, 4.0, 4.0], "colour": "yellow"},
}
save("modules.json", modules)
ships = load("ships.json")
ships["climber"] = {
    "name": "Elevator climber",
    "description": "A cab and two containers that ride the ribbon on traction wheels. It goes up and down, and nowhere else.",
    "spine": "mule_spine",
    "modules": {"command.0": "drone_core", "cargo.0": "cargo_pod_l", "cargo.1": "cargo_pod_l", "drive.0": "climber_cab"},
    "look": {"cargo_layout": "pair"},
}
save("ships.json", ships)


def leg_goods(src, dst, wanted):
    return [g for g in wanted if g in places[src]["market"] and g in places[dst]["market"]]


npcs = load("npcs.json")
fleets = npcs["fleets"]
fleets["luna_climbers"] = {
    "operator": "Luna Cooperative", "hull": "climber", "behaviour": "route", "count": 2, "elevator": True,
    "names": ["Climber 14", "Slow Descent"],
    "route": [{"at": "halo_depot", "buy": leg_goods("halo_depot", "line_foot", ["food", "machine_parts", "electronics"]), "to": "line_foot"},
              {"at": "line_foot", "buy": leg_goods("line_foot", "halo_depot", ["regolith", "refined_metals", "oxygen"]), "to": "halo_depot"}],
    "fill": 0.5, "dwell_hours": [6, 20],
}
fleets["stalk_climbers"] = {
    "operator": "Belt Assembly", "hull": "climber", "behaviour": "route", "count": 2, "elevator": True,
    "names": ["Stalk 3", "Stalk 9"],
    "route": [{"at": "piazzi_station", "buy": leg_goods("piazzi_station", "stalk_foot", ["food", "medical", "machine_parts"]), "to": "stalk_foot"},
              {"at": "stalk_foot", "buy": leg_goods("stalk_foot", "piazzi_station", ["water_ice", "volatiles"]), "to": "piazzi_station"}],
    "fill": 0.5, "dwell_hours": [4, 12],
}
fleets["pavonis_climbers"] = {
    "operator": "Mars Accord", "hull": "climber", "behaviour": "route", "count": 2, "elevator": True,
    "names": ["Tharsis Lift", "Olympus Patience"], "commission_project": "pavonis_line", "commission_days": [0, 10],
    "route": [{"at": "ares_ring", "buy": leg_goods("ares_ring", "pavonis_foot", ["machine_parts", "electronics", "medical"]), "to": "pavonis_foot"},
              {"at": "pavonis_foot", "buy": leg_goods("pavonis_foot", "ares_ring", ["food", "deuterium", "water_ice"]), "to": "ares_ring"}],
    "fill": 0.5, "dwell_hours": [12, 40],
}
npcs["chatter"]["climb_depart"] = [
    "{ship}, {operator}: on the ribbon from {from}, bound for {to} with {cargo}.",
    "{ship} clamped on and climbing. {to} in a while. Nobody hurry.",
    "{ship} away from {from} for {to}. Wheels warm, ribbon clean.",
]
save("npcs.json", npcs)

news = load("news.json")
news["stories"] = [s for s in news["stories"] if s["id"] != "line_foot_visitors"]
news["stories"].append({
    "id": "line_foot_visitors", "after_days": 3, "dateline": "The Moon",
    "headline": "Ride the Luna Line, says the Cooperative",
    "body": ("The Luna Cooperative has opened the Luna Line's climbers to paying passengers. Bring your cargo down from Halo "
             "Depot to Line Foot in Sinus Medii, two days down the ribbon, and leave your ship docked above. The bar at the "
             "bottom has, the Cooperative says, 'the only view of Earth that never moves'."),
})
news["stories"].sort(key=lambda st: (0 if "after_beat" not in st else 1, st.get("after_days", 0)))
for st in news["stories"]:
    pass
pl = news["projects"]["pavonis_line"]["complete"]
pl["body"] = ("A climber rode the Pavonis Line from the summit of Pavonis Mons to areostationary orbit today in five days, "
              "carrying fourteen people and a great deal of champagne. Pavonis Foot is open to anyone who rides down from Ares Ring.")
save("news.json", news)
print("ok")
