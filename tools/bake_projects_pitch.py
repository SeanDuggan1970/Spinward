"""Projects that pitch: why to back them, what's planned, what backers get (perks by
tonnage hauled), and when they appear (reveal conditions, invitation-only builds).
Adds three later projects and Hektor Reach, the station that moves out. Re-runnable."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    return json.load(open(os.path.join(ROOT, "data", name), encoding="utf-8"))


def save(name, d):
    open(os.path.join(ROOT, "data", name), "w", encoding="utf-8", newline="\n").write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")


pr = load("projects.json")
pr["_note"] = ("Megaprojects: collective builds that draw goods from their place's market (above reserve_fraction of target) at up to "
    "draw_t_per_day per good, stage by stage. Completing the last stage applies 'effects' to place flows and opens any place whose "
    "'opens_with' names it. 'pitch' is the backers' case (why, plan, offer). 'perks' reward the player's hauled tonnage over the "
    "whole build (min_t): free_docking, fuel_discount and yard_discount (fractions) at a place, standing (one-off reputation with an "
    "operator), or a promise (text only, honoured by later systems). 'reveal': a project is hidden until after_days have passed, or "
    "after_stage [project, stage] is reached; 'invite': only pilots with that standing with the backer are asked in. Progress drives "
    "the matching set piece in the approach view.")

pr["island_one"].update({
    "backer": "Kernel Settlers",
    "pitch": {
        "why": "Ten thousand people under real sky at L5: proof that we can live out here, not just work.",
        "plan": "Frame, hull, air and soil, then spin-up. The Commons drew it; settlers, drones and anyone with a hold are building it.",
        "offer": "Backers dock free at the Kernel, refuel cheaper, and when the sphere opens, a berth is kept for your crew.",
    },
    "perks": [
        {"min_t": 10, "kind": "free_docking", "place": "kernel_l5", "text": "Free docking at the Kernel"},
        {"min_t": 40, "kind": "fuel_discount", "place": "kernel_l5", "value": 0.2, "text": "20% off fuel at the Kernel"},
        {"min_t": 40, "kind": "standing", "operator": "Kernel Settlers", "value": 8, "text": "The settlers count you as one of their builders"},
        {"min_t": 100, "kind": "promise", "text": "A crew berth on Island One, yours for life"},
    ],
})
pr["luna_line_2"].update({
    "backer": "Luna Cooperative",
    "pitch": {
        "why": "One ribbon is a bottleneck. Two double the Moon's lift to L1 and halve what you pay for ice.",
        "plan": "Spin the second Zylon ribbon, then commission its climbers.",
        "offer": "Backers get the Cooperative's yard prices and its gratitude, which goes a long way on the Moon.",
    },
    "perks": [
        {"min_t": 8, "kind": "free_docking", "place": "halo_depot", "text": "Free docking at Halo Depot"},
        {"min_t": 25, "kind": "standing", "operator": "Luna Cooperative", "value": 6, "text": "Friends of the Cooperative"},
        {"min_t": 25, "kind": "free_docking", "place": "shackleton_port", "text": "Free docking at Shackleton Port"},
    ],
})
pr["kalpana_two"].update({
    "backer": "Kalpana Settlement Trust",
    "pitch": {
        "why": "A paired drum can face the Sun, and three thousand more people get Earth's magnetic shelter.",
        "plan": "Drum frame, hull and windows, then move-in day.",
        "offer": "The Trust remembers its haulers: cheaper fuel at Kalpana, and an invitation to the opening.",
    },
    "perks": [
        {"min_t": 10, "kind": "fuel_discount", "place": "kalpana_one", "value": 0.15, "text": "15% off fuel at Kalpana One"},
        {"min_t": 30, "kind": "standing", "operator": "Kalpana Settlement Trust", "value": 8, "text": "An honoured name on the Trust's roll"},
    ],
})
pr["hektor_reach"] = {
    "name": "Hektor Reach",
    "backer": "The Commons",
    "place": "kernel_l5",
    "description": "A station built at L5 and then driven out to Hektor, the great Trojan asteroid at Jupiter's leading point: the first port between the belt and the giants.",
    "pitch": {
        "why": "Jupiter is a year away for most ships. A port among the Trojans halves the hard part and opens a whole new neighbourhood.",
        "plan": "Build the hub at L5, fit a tug-drive to it, and push it out over eighteen months to orbit Hektor.",
        "offer": "Backers dock free at the Reach forever, get a fifth off its yard, and first claim on the Trojan survey work it opens up.",
    },
    "draw_t_per_day": 2.5,
    "stages": [
        {"name": "Hub assembled at L5", "needs": {"refined_metals": 80, "habitat_modules": 30, "machine_parts": 40}},
        {"name": "Tug-drive fitted", "needs": {"machine_parts": 60, "water_ice": 120}},
        {"name": "Out to Hektor", "needs": {"water_ice": 200, "food": 40, "medical": 4}},
    ],
    "reveal": {"after_stage": ["island_one", 1]},
    "perks": [
        {"min_t": 15, "kind": "free_docking", "place": "hektor_reach", "text": "Free docking at Hektor Reach, for good"},
        {"min_t": 40, "kind": "yard_discount", "place": "hektor_reach", "value": 0.2, "text": "20% off at the Reach's yard"},
        {"min_t": 40, "kind": "standing", "operator": "The Commons", "value": 10, "text": "The Commons minds take note of you"},
        {"min_t": 100, "kind": "promise", "text": "First claim on Trojan survey contracts"},
    ],
    "effects": {},
}
pr["ares_greenhouses"] = {
    "name": "Tharsis greenhouses",
    "backer": "Mars Accord",
    "place": "ares_ring",
    "description": "Pressurised greenhouse domes on the Tharsis plateau, so Mars can feed itself and stop shipping food up from Earth's well.",
    "pitch": {
        "why": "Every tonne of food Mars grows is a tonne nobody has to haul for three months.",
        "plan": "Domes and glazing, then soil and water, then the first harvest.",
        "offer": "Backers get the Accord's best fuel price at Ares Ring and its standing; the first harvest has your name on a crate.",
    },
    "draw_t_per_day": 2.0,
    "stages": [
        {"name": "Domes raised", "needs": {"habitat_modules": 40, "machine_parts": 30}},
        {"name": "Soil and water", "needs": {"water_ice": 120, "volatiles": 40}},
        {"name": "First harvest", "needs": {"electronics": 6, "medical": 2}},
    ],
    "reveal": {"after_days": 30},
    "perks": [
        {"min_t": 10, "kind": "fuel_discount", "place": "ares_ring", "value": 0.25, "text": "25% off fuel at Ares Ring"},
        {"min_t": 30, "kind": "standing", "operator": "Mars Accord", "value": 10, "text": "A friend of the Accord"},
        {"min_t": 30, "kind": "yard_discount", "place": "ares_ring", "value": 0.15, "text": "15% off at Ares Ring's yard"},
    ],
    "effects": {"ares_ring": {"produces_mult": 1.6}},
}
pr["valhalla_deep_ring"] = {
    "name": "Valhalla science ring",
    "backer": "Terran Compact Science",
    "place": "valhalla_station",
    "description": "A shielded science ring for long-term work on the Jovian moons, closed to the public until it is built.",
    "pitch": {
        "why": "What is under Europa's ice matters more than anything else out here, and nobody may land there. This is how we look properly.",
        "plan": "Shielding, the ring, then the instruments. Quietly: the Compact would rather the press didn't hear yet.",
        "offer": "Backers are first in line when the Compact needs pilots it trusts in the Jovian system.",
    },
    "draw_t_per_day": 1.5,
    "stages": [
        {"name": "Radiation shielding", "needs": {"water_ice": 150, "refined_metals": 40}},
        {"name": "The ring", "needs": {"habitat_modules": 50, "machine_parts": 40}},
        {"name": "Instruments", "needs": {"electronics": 20, "medical": 3}},
    ],
    "reveal": {"after_days": 0},
    "invite": {"operator": "Terran Compact Science", "min_rep": 20},
    "perks": [
        {"min_t": 10, "kind": "free_docking", "place": "valhalla_station", "text": "Free docking at Valhalla"},
        {"min_t": 40, "kind": "standing", "operator": "Terran Compact Science", "value": 12, "text": "The Compact's science office trusts you"},
        {"min_t": 80, "kind": "promise", "text": "First call for the Compact's Jovian work"},
    ],
    "effects": {},
}
save("projects.json", pr)

p = load("places.json")
p["hektor_reach"] = {
    "name": "Hektor Reach", "operator": "The Commons", "opens_with": "hektor_reach",
    "description": "The first port among Jupiter's Trojans, driven out from L5 and parked in orbit around Hektor, a 225 km double-lobed asteroid. Fuel, a yard, and a long view of Jupiter from sixty degrees ahead of it.",
    "location": {"type": "orbit", "parent": "hektor", "elements": {"a_m": 112500.0 + 80000.0, "e": 0.0, "i_deg": 0.0, "node_deg": 0.0, "peri_deg": 0.0, "m0_deg": 0.0}},
    "station": {"hub_radius_m": 14, "hub_length_m": 90, "ring_radius_m": 95, "ring_tube_m": 9, "spokes": 4, "spin_rpm": 2.6, "colour": "grey"},
    "services": ["market", "refuel", "shipyard"],
    "shipyard_stock": ["tank_l", "hab_extended", "lander_bay", "mining_rig", "survey_pod", "radiator_array"],
    "market": {"water_ice": 300, "propellant": 300, "refined_metals": 150, "food": 60, "medical": 5, "machine_parts": 40, "electronics": 10, "volatiles": 80},
    "produces": {"refined_metals": 4, "volatiles": 3},
    "consumes": {"food": 2.5, "medical": 0.3, "machine_parts": 2, "electronics": 0.6, "water_ice": 3},
    "recipes": [{"inputs": {"water_ice": 3}, "outputs": {"propellant": 2}}],
}
# Markets the new builds draw from must trade what they need.
p["ares_ring"]["market"].setdefault("volatiles", 40)
p["valhalla_station"]["market"].setdefault("refined_metals", 60)
p["valhalla_station"]["market"].setdefault("habitat_modules", 15)
save("places.json", p)
print("ok")
