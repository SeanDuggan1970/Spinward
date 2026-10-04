"""Phase 3 content: refit modules that mount in cargo bays, the Mk3 drive and the big
radiator array, and which yards sell them (re-runnable)."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def save(name, d):
    open(os.path.join(ROOT, "data", name), "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


m = load("modules.json")
m["_note"] = m["_note"].split(" 'look' feeds")[0] + (
    " 'mounts' lists the slot kinds a module fits (default: its own kind), so long-haul refits can trade cargo bays for tanks,"
    " life support, berths, a lander or a rig. life_support_days and berths add up across modules; crewless ships need none."
    " 'look' feeds the kit-bash renderer (view/flight/ship_builder.gd): command shape 'cockpit' or 'drone'; cargo shape 'cage'"
    " (open frame of half-length containers), 'container' (standard 2.4 x 2.6 x 6 m boxes, containers = [across, high, long]),"
    " 'bulk' (hopper), 'cradle' (open flatbed for outsize loads); 'hab' (passenger can or long-duration hab, mounted behind the crew);"
    " 'lander', 'sensor' and 'mining' ride in the cargo section; tanks of any slot cluster ahead of the drives; spine truss_m is the"
    " keel's width; drive coils is the number of field coils on the nozzle.")
for t in ["tank_s", "tank_m"]:
    m[t]["mounts"] = ["tank", "cargo"]
m["passenger_pod"]["berths"] = 24
new = {
    "tank_l": {"name": "20 t long-haul tank", "kind": "tank", "mounts": ["tank", "cargo"], "mass_t": 3.0, "price": 60000, "fuel_t": 20,
               "look": {"shape": "cylinder", "size_m": [4.6, 4.6, 8.0], "colour": "foil"}},
    "hab_extended": {"name": "Long-duration hab (300 days)", "kind": "hab", "mounts": ["cargo"], "mass_t": 3.5, "price": 45000,
                     "life_support_days": 300, "look": {"shape": "hab", "size_m": [4.4, 4.4, 6.5], "colour": "offwhite"}},
    "passenger_berths": {"name": "Passenger berths (6)", "kind": "hab", "mounts": ["cargo"], "mass_t": 2.5, "price": 25000,
                         "berths": 6, "life_support_days": 40, "look": {"shape": "hab", "size_m": [4.0, 4.0, 5.0], "colour": "offwhite"}},
    "lander_bay": {"name": "Lander bay, Bramble-class lander", "kind": "lander", "mounts": ["cargo"], "mass_t": 6.0, "price": 85000,
                   "lander": True, "look": {"shape": "lander", "size_m": [5.0, 4.6, 7.0], "colour": "yellow"}},
    "survey_pod": {"name": "Survey sensor pod", "kind": "sensor", "mounts": ["cargo", "avionics"], "mass_t": 1.2, "price": 30000,
                   "survey": True, "look": {"shape": "sensor", "size_m": [2.4, 2.4, 3.0], "colour": "offwhite"}},
    "mining_rig": {"name": "Prospecting and mining rig", "kind": "mining", "mounts": ["cargo"], "mass_t": 5.0, "price": 70000,
                   "mining": True, "look": {"shape": "mining", "size_m": [4.0, 4.0, 7.0], "colour": "orange"}},
    "pathfinder_mk3": {"name": "Pathfinder Mk3 fusion drive (D-He3)", "kind": "drive", "mass_t": 7.0, "price": 450000,
                       "thrust_n": 2600, "isp_s": 60000, "heat_mw": 9.0, "look": {"shape": "drive", "size_m": [3.8, 3.8, 6.2], "colour": "grey", "coils": 4}},
    "radiator_array": {"name": "6 MW radiator array", "kind": "radiator", "mass_t": 1.8, "price": 30000, "reject_mw": 6.0,
                       "look": {"shape": "panel", "size_m": [0.2, 12.0, 5.0], "colour": "dark"}},
}
out = {}
for k, v in m.items():
    out[k] = v
    if k == "tank_m":
        out["tank_l"] = new["tank_l"]
    if k == "pathfinder_mk2":
        out["pathfinder_mk3"] = new["pathfinder_mk3"]
    if k == "radiator_panel_l":
        out["radiator_array"] = new["radiator_array"]
for k in ["hab_extended", "passenger_berths", "lander_bay", "survey_pod", "mining_rig"]:
    out[k] = new[k]
save("modules.json", out)

p = load("places.json")
def stock(place, extra):
    have = p[place].setdefault("shipyard_stock", [])
    for e in extra:
        if e not in have:
            have.append(e)
    if "shipyard" not in p[place]["services"]:
        p[place]["services"].append("shipyard")
stock("kibo_ring", ["tank_l", "hab_extended", "passenger_berths", "survey_pod"])
stock("trojan_yards", ["tank_l", "pathfinder_mk3", "radiator_array", "lander_bay", "mining_rig", "hab_extended"])
stock("ares_ring", ["tank_l", "hab_extended", "lander_bay", "mining_rig", "survey_pod"])
stock("piazzi_station", ["tank_m", "tank_l", "mining_rig", "lander_bay", "radiator_array"])
save("places.json", p)
print("ok")
