"""Step 1 of 2: adds the rest of the solar system to data/bodies.json (names, GM,
radii, kinds, looks, starting elements). Step 2 is fit_bodies_horizons.py, which
replaces the elements with a fit to JPL Horizons (tests/horizons_reference.json).
Inputs cached in tools/bake_cache/: sbdb_all.json (JPL SBDB API) and sats_all.json
(JPL satellite mean elements page).


Planets: JPL "Approximate Positions of the Planets", Table 2a (3000 BC - 3000 AD),
converted to a, e, i, node, argument of perihelion, mean anomaly at J2000 and rates.
Small bodies: JPL SBDB osculating elements (fetched 2026-10-04), mean anomaly
carried back to J2000 with the listed mean motion.
Moons: JPL planetary satellite mean elements (epoch J2000), referred to the Laplace
plane given by its pole's RA/Dec (ICRF).
"""
import json, os, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bake_cache")
AU = 1.495978707e11
J2000_JD = 2451545.0

bodies = json.load(open(os.path.join(ROOT, "data", "bodies.json"), encoding="utf-8"))

# name: a_AU, e, I, L, long_peri, long_node, and per-century rates (Table 2a)
T2A = {
    "mercury": (0.38709843, 0.20563661, 7.00559432, 252.25166724, 77.45771895, 48.33961819, 0.0, 0.00002123, -0.00590158, 149472.67486623, 0.15940013, -0.12214182),
    "venus": (0.72332102, 0.00676399, 3.39777545, 181.97970850, 131.76755713, 76.67261496, -0.00000026, -0.00005107, 0.00043494, 58517.81560260, 0.05679648, -0.27274174),
    "mars": (1.52371243, 0.09336511, 1.85181869, -4.56813164, -23.91744784, 49.71320984, 0.00000097, 0.00009149, -0.00724757, 19140.29934243, 0.45223625, -0.26852431),
    "jupiter": (5.20248019, 0.04853590, 1.29861416, 34.33479152, 14.27495244, 100.29282654, -0.00002864, 0.00018026, -0.00322699, 3034.90371757, 0.18199196, 0.13024619),
    "saturn": (9.54149883, 0.05550825, 2.49424102, 50.07571329, 92.86136063, 113.63998702, -0.00003065, -0.00032044, 0.00451969, 1222.11494724, 0.54179478, -0.25015002),
    "uranus": (19.18797948, 0.04685740, 0.77298127, 314.20276625, 172.43404441, 73.96250215, -0.00020455, -0.00001550, -0.00180155, 428.49512595, 0.09266985, 0.05739699),
    "neptune": (30.06952752, 0.00895439, 1.77005520, 304.22289287, 46.68158724, 131.78635853, 0.00006447, 0.00000818, 0.00022400, 218.46515314, 0.01009938, -0.00606302),
}
# GM (m^3/s^2), radius (m), IAU pole RA/Dec (deg), kind, look
PLANETS = {
    "mercury": ("Mercury", 2.2032e13, 2.4397e6, (281.01, 61.41), {"shader": "rock", "highland_colour": "#8a8580", "mare_colour": "#5e5b57", "basin_flooding": 0.25}),
    "venus": ("Venus", 3.24859e14, 6.0518e6, (272.76, 67.16), {"shader": "clouds", "colour_a": "#e8d6a8", "colour_b": "#c9ad74", "bands": 3.0, "turbulence": 0.6}),
    "mars": ("Mars", 4.282837e13, 3.3895e6, (317.68, 52.89), {"shader": "rock", "highland_colour": "#b56a3e", "mare_colour": "#7a4630", "basin_flooding": 0.3, "ice_caps": 0.9, "ray_chance": 0.01}),
    "jupiter": ("Jupiter", 1.26686534e17, 6.9911e7, (268.06, 64.50), {"shader": "gas", "colour_a": "#e9dcc4", "colour_b": "#b3825a", "colour_c": "#8a5a3c", "bands": 14.0, "turbulence": 0.7, "storm": 1.0}),
    "saturn": ("Saturn", 3.7931187e16, 5.8232e7, (40.59, 83.54), {"shader": "gas", "colour_a": "#efe2bf", "colour_b": "#d2b47c", "colour_c": "#b8955e", "bands": 18.0, "turbulence": 0.35, "rings": 1.0}),
    "uranus": ("Uranus", 5.793939e15, 2.5362e7, (257.31, -15.18), {"shader": "gas", "colour_a": "#bfe7ea", "colour_b": "#9fd3d8", "colour_c": "#8cc4cc", "bands": 6.0, "turbulence": 0.1}),
    "neptune": ("Neptune", 6.836529e15, 2.4622e7, (299.36, 43.46), {"shader": "gas", "colour_a": "#5b7fe0", "colour_b": "#3d5fc4", "colour_c": "#2c4aa6", "bands": 8.0, "turbulence": 0.4, "storm": 0.6}),
}

for key, t in T2A.items():
    a, e, inc, L, lp, ln, da, de, di, dL, dlp, dln = t
    name, gm, radius, pole, look = PLANETS[key]
    n_deg_day = (dL - dlp) / 36525.0  # mean anomaly rate
    bodies[key] = {
        "name": name, "kind": "planet", "parent": "sun", "gm": gm, "radius_m": radius,
        "pole_ra_deg": pole[0], "pole_dec_deg": pole[1],
        "elements": {
            "a_m": a * AU, "e": e, "i_deg": inc, "node_deg": ln, "peri_deg": lp - ln,
            "m0_deg": (L - lp) % 360.0, "period_days": 360.0 / n_deg_day,
            "node_rate_deg_per_day": dln / 36525.0, "peri_rate_deg_per_day": (dlp - dln) / 36525.0,
        },
        "look": look,
    }

# Small bodies from SBDB.
sb = json.load(open(os.path.join(HERE, "sbdb_all.json")))
SMALL = {
    "1 Ceres (A801 AA)": ("ceres", "Ceres", "dwarf", 4.697e5, {"shader": "rock", "highland_colour": "#6f6b66", "mare_colour": "#55524e", "basin_flooding": 0.0, "bright_spots": 1.0}),
    "4 Vesta (A807 FA)": ("vesta", "Vesta", "asteroid", 2.627e5, {"shader": "rock", "highland_colour": "#8f8a80", "mare_colour": "#6d6860", "basin_flooding": 0.1}),
    "2 Pallas (A802 FA)": ("pallas", "Pallas", "asteroid", 2.56e5, {"shader": "rock", "highland_colour": "#77736d", "mare_colour": "#5d5a55", "basin_flooding": 0.0}),
    "16 Psyche (A852 FA)": ("psyche", "Psyche", "asteroid", 1.11e5, {"shader": "rock", "highland_colour": "#8e8b86", "mare_colour": "#6f6c68", "basin_flooding": 0.0, "metallic": 0.6}),
    "10 Hygiea (A849 GA)": ("hygiea", "Hygiea", "asteroid", 2.035e5, {"shader": "rock", "highland_colour": "#55524d", "mare_colour": "#45423e", "basin_flooding": 0.0}),
    "433 Eros (A898 PA)": ("eros", "Eros", "asteroid", 8.4e3, {"shader": "rock", "highland_colour": "#8d7f6c", "mare_colour": "#6e6355", "basin_flooding": 0.0}),
    "624 Hektor (A907 CF)": ("hektor", "Hektor", "trojan", 1.125e5, {"shader": "rock", "highland_colour": "#4d453f", "mare_colour": "#3b3531", "basin_flooding": 0.0}),
    "134340 Pluto (1930 BM)": ("pluto", "Pluto", "dwarf", 1.1883e6, {"shader": "rock", "highland_colour": "#d9c7a8", "mare_colour": "#8f5e3e", "basin_flooding": 0.4, "ray_chance": 0.0}),
    "136199 Eris (2003 UB313)": ("eris", "Eris", "dwarf", 1.163e6, {"shader": "rock", "highland_colour": "#e8e6e0", "mare_colour": "#c9c4ba", "basin_flooding": 0.1}),
    "486958 Arrokoth (2014 MU69)": ("arrokoth", "Arrokoth", "kbo", 1.8e4, {"shader": "rock", "highland_colour": "#9a5a42", "mare_colour": "#7a4634", "basin_flooding": 0.0}),
    "90377 Sedna (2003 VB12)": ("sedna", "Sedna", "detached", 5.0e5, {"shader": "rock", "highland_colour": "#a3523a", "mare_colour": "#7d3e2c", "basin_flooding": 0.0}),
}
GM_SMALL = {"pluto": 8.6996e11, "eris": 1.108e12, "ceres": 6.26284e10, "vesta": 1.72883e10, "pallas": 1.363e10,
            "psyche": 1.601e9, "hygiea": 7.0e9, "eros": 4.463e5, "hektor": 5.0e8, "arrokoth": 5.0e4, "sedna": 1.0e11}
for full, (key, name, kind, radius, look) in SMALL.items():
    o = sb[full]
    n = float(o["n"])
    epoch = float(o["epoch"])
    m0 = (float(o["ma"]) - n * (epoch - J2000_JD)) % 360.0
    bodies[key] = {
        "name": name, "kind": kind, "parent": "sun", "gm": GM_SMALL[key], "radius_m": radius,
        "elements": {"a_m": float(o["a"]) * AU, "e": float(o["e"]), "i_deg": float(o["i"]), "node_deg": float(o["om"]),
                     "peri_deg": float(o["w"]), "m0_deg": m0, "period_days": 360.0 / n},
        "look": look,
    }
bodies["pluto"]["pole_ra_deg"] = 132.993
bodies["pluto"]["pole_dec_deg"] = -6.163

sats = json.load(open(os.path.join(HERE, "sats_all.json")))
# key, parent, GM (km^3/s^2), radius (km), look
MOONS = {
    "Phobos": ("phobos", "mars", 7.087e-4, 11.1, {"shader": "rock", "highland_colour": "#6e625a", "mare_colour": "#574d47", "basin_flooding": 0.0}),
    "Deimos": ("deimos", "mars", 9.6e-5, 6.2, {"shader": "rock", "highland_colour": "#7a6e62", "mare_colour": "#62584f", "basin_flooding": 0.0}),
    "Io": ("io", "jupiter", 5959.916, 1821.6, {"shader": "rock", "highland_colour": "#e3cf6e", "mare_colour": "#b0693a", "basin_flooding": 0.5, "ray_chance": 0.0, "largest_km": 13.0}),
    "Europa": ("europa", "jupiter", 3202.739, 1560.8, {"shader": "rock", "highland_colour": "#e9e2d2", "mare_colour": "#b89a78", "basin_flooding": 0.3, "largest_km": 13.0, "lineae": 1.0}),
    "Ganymede": ("ganymede", "jupiter", 9887.834, 2634.1, {"shader": "rock", "highland_colour": "#a9a092", "mare_colour": "#6b6358", "basin_flooding": 0.45}),
    "Callisto": ("callisto", "jupiter", 7179.289, 2410.3, {"shader": "rock", "highland_colour": "#6f675e", "mare_colour": "#4f4943", "basin_flooding": 0.15, "ray_chance": 0.08}),
    "Enceladus": ("enceladus", "saturn", 7.211, 252.1, {"shader": "rock", "highland_colour": "#f2f4f6", "mare_colour": "#d6dde4", "basin_flooding": 0.2, "lineae": 1.0, "lineae_colour": "#8fb0c4"}),
    "Rhea": ("rhea", "saturn", 153.94, 763.8, {"shader": "rock", "highland_colour": "#cfcac2", "mare_colour": "#aaa49b", "basin_flooding": 0.0}),
    "Titan": ("titan", "saturn", 8978.14, 2574.7, {"shader": "clouds", "colour_a": "#d6a35a", "colour_b": "#b88440", "bands": 2.0, "turbulence": 0.2}),
    "Iapetus": ("iapetus", "saturn", 120.51, 734.5, {"shader": "rock", "highland_colour": "#d8d2c6", "mare_colour": "#3a2e26", "basin_flooding": 0.5}),
    "Miranda": ("miranda", "uranus", 4.4, 235.8, {"shader": "rock", "highland_colour": "#b9b9b4", "mare_colour": "#8e8e89", "basin_flooding": 0.3}),
    "Titania": ("titania", "uranus", 228.2, 788.4, {"shader": "rock", "highland_colour": "#a8a39b", "mare_colour": "#86817a", "basin_flooding": 0.1}),
    "Triton": ("triton", "neptune", 1428.495, 1353.4, {"shader": "rock", "highland_colour": "#d9cfc6", "mare_colour": "#b29a8a", "basin_flooding": 0.4}),
    "Charon": ("charon", "pluto", 106.1, 606.0, {"shader": "rock", "highland_colour": "#a7a39c", "mare_colour": "#6e5148", "basin_flooding": 0.2}),
}
POLES = {"uranus": (257.311, -15.175), "pluto": (132.993, -6.163)}
for sname, (key, parent, gm, r_km, look) in MOONS.items():
    s = sats[sname]
    if parent in POLES:
        ra, dec = POLES[parent]
    else:
        ra = float(s["ra"]); dec = float(s["dec"])
    def yr(v):
        try:
            return float(v)
        except ValueError:
            return 0.0
    papsis = yr(s["Papsis_yr"]); pnode = yr(s["Pnode_yr"])
    el = {"a_m": float(s["a_km"]) * 1000.0, "e": float(s["e"]), "i_deg": float(s["i"]), "node_deg": float(s["node"]),
          "peri_deg": float(s["w"]), "m0_deg": float(s["M"]), "period_days": float(s["P_days"]),
          "frame": "laplace", "pole_ra_deg": ra, "pole_dec_deg": dec}
    if papsis > 0.0:
        el["peri_rate_deg_per_day"] = 360.0 / (papsis * 365.25)
    if pnode > 0.0:
        el["node_rate_deg_per_day"] = -360.0 / (pnode * 365.25)
    bodies[key] = {"name": sname, "kind": "moon", "parent": parent, "gm": gm * 1e9, "radius_m": r_km * 1000.0, "elements": el, "look": look}

# Existing bodies: kinds and looks.
bodies["sun"]["kind"] = "star"
bodies["earth"]["kind"] = "planet"
bodies["earth"]["pole_ra_deg"] = 0.0
bodies["earth"]["pole_dec_deg"] = 90.0
bodies["moon"]["kind"] = "moon"
bodies["moon"].setdefault("look", {"shader": "rock"})
bodies["_source"] = ("Earth: JPL 'Approximate Positions of the Planets', Table 1 (EM barycentre, J2000). Moon: mean elements after Meeus ch. 47. "
    "Other planets: JPL Table 2a (3000 BC-3000 AD; Table 2b terms for the giants omitted, < 1 deg). Asteroids, dwarf planets and Kuiper belt objects: "
    "JPL SBDB osculating elements fetched 2026-10-04, mean anomaly carried back to J2000. Moons: JPL planetary satellite mean elements (epoch J2000) "
    "on their Laplace planes (frame 'laplace', pole RA/Dec ICRF). GM values: JPL/IAU. 'kind' sorts bodies on the map; 'look' picks and tunes the "
    "surface shader (rock, gas, clouds; Earth has its own).")
order = ["_source", "sun", "mercury", "venus", "earth", "moon", "mars", "phobos", "deimos", "ceres", "vesta", "pallas", "psyche", "hygiea", "eros",
         "jupiter", "io", "europa", "ganymede", "callisto", "hektor", "saturn", "enceladus", "rhea", "titan", "iapetus",
         "uranus", "miranda", "titania", "neptune", "triton", "pluto", "charon", "arrokoth", "eris", "sedna"]
out = {k: bodies[k] for k in order}
open(os.path.join(ROOT, "data", "bodies.json"), "w", encoding="utf-8", newline="\n").write(json.dumps(out, indent="\t", ensure_ascii=False) + "\n")
print("bodies:", len(out) - 1)
