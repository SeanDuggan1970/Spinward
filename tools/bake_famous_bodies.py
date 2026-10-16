"""Adds the famous small bodies to data/bodies.json: Halley's Comet, comet 67P
(Rosetta's comet), Bennu, Ryugu and Didymos. Names, GM, radii, kinds, looks and,
for comets, how active they are. Orbits come from JPL Horizons, as for every other
body:

    python tools/fetch_horizons.py --only halley,comet_67p,bennu,ryugu,didymos
    python tools/bake_famous_bodies.py
    python tools/fit_bodies_horizons.py

Safe to re-run: it keeps any elements, plumes or structures already there.

Sources (mass -> GM with G = 6.674e-11; radius is the volume-equivalent sphere):
  Halley: nucleus 15 x 8 x 8 km, mass ~2.2e14 kg (Giotto/Vega, Sagdeev et al. 1988),
          albedo 0.04.
  67P:    mass 1.0e13 kg, volume 18.8 km^3 (Rosetta, Paetzold et al. 2016;
          Jorda et al. 2016).
  Bennu:  GM 4.892 m^3/s^2, mean radius 245 m (OSIRIS-REx, Scheeres et al. 2019).
  Ryugu:  mass 4.5e11 kg, mean radius 448 m (Hayabusa2, Watanabe et al. 2019).
  Didymos: mass ~5.3e11 kg, diameter 761 m (DART/LICIACube, Daly et al. 2023).
'activity.strength' is how strongly the comet outgasses, relative to Halley, at
1 AU (water production: Halley ~7e29 molecules/s near perihelion in 1986; 67P
~1e28 near perihelion in 2015). sim/comet.gd turns it into activity by distance.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
path = os.path.join(ROOT, "data", "bodies.json")
bodies = json.load(open(path, encoding="utf-8"))

FAMOUS = {
    "bennu": {"name": "Bennu", "kind": "asteroid", "parent": "sun", "gm": 4.892, "radius_m": 245.0,
              "look": {"shader": "rock", "highland_colour": "#46423e", "mare_colour": "#2f2c29", "basin_flooding": 0.0}},
    "ryugu": {"name": "Ryugu", "kind": "asteroid", "parent": "sun", "gm": 30.0, "radius_m": 448.0,
              "look": {"shader": "rock", "highland_colour": "#3f3b37", "mare_colour": "#2c2926", "basin_flooding": 0.0}},
    "didymos": {"name": "Didymos", "kind": "asteroid", "parent": "sun", "gm": 35.5, "radius_m": 380.0,
                "look": {"shader": "rock", "highland_colour": "#8a8175", "mare_colour": "#6a6259", "basin_flooding": 0.0}},
    "halley": {"name": "Halley's Comet", "kind": "comet", "parent": "sun", "gm": 1.47e4, "radius_m": 5500.0,
               "look": {"shader": "rock", "highland_colour": "#34302d", "mare_colour": "#24211f", "basin_flooding": 0.0},
               "activity": {"strength": 1.0}},
    "comet_67p": {"name": "67P/Churyumov-Gerasimenko", "kind": "comet", "parent": "sun", "gm": 667.0, "radius_m": 1650.0,
                  "look": {"shader": "rock", "highland_colour": "#3b3733", "mare_colour": "#2a2724", "basin_flooding": 0.0},
                  "activity": {"strength": 0.15}},
}
# Each goes in after this body, so the map and lists read in a sensible order.
AFTER = {"bennu": "eros", "ryugu": "bennu", "didymos": "ryugu", "halley": "sedna", "comet_67p": "halley"}

for key, entry in FAMOUS.items():
    old = bodies.get(key, {})
    for keep in ["elements", "plumes", "structures"]:
        if keep in old:
            entry[keep] = old[keep]
    bodies[key] = entry

order = [k for k in bodies if k not in FAMOUS]
for key in FAMOUS:
    order.insert(order.index(AFTER[key]) + 1, key)
out = {k: bodies[k] for k in order}
open(path, "w", encoding="utf-8", newline="\n").write(json.dumps(out, indent="\t", ensure_ascii=False) + "\n")
print("famous bodies:", ", ".join(FAMOUS))
