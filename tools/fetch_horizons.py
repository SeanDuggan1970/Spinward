"""Fetch the reference state vectors the orbit bake and tests use.

Writes tests/horizons_reference.json: position and velocity (km, km/s; ecliptic
J2000; relative to each body's parent) at 2061-03-01 and 2063-03-01 00:00 UT, from
the JPL Horizons API. Then run bake_bodies.py and fit_bodies_horizons.py.
Needs network access; takes a minute or two.
"""
import json, os, time, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATES = ["2061-03-01", "2063-03-01"]
# body: (Horizons command, centre)
TARGETS = {
    "mercury": ("199", "500@10"), "venus": ("299", "500@10"), "mars": ("499", "500@10"), "jupiter": ("599", "500@10"),
    "saturn": ("699", "500@10"), "uranus": ("799", "500@10"), "neptune": ("899", "500@10"), "pluto": ("999", "500@10"),
    "ceres": ("1;", "500@10"), "vesta": ("4;", "500@10"), "pallas": ("2;", "500@10"), "psyche": ("16;", "500@10"),
    "hygiea": ("10;", "500@10"), "eros": ("433;", "500@10"), "hektor": ("624;", "500@10"), "arrokoth": ("486958;", "500@10"),
    "eris": ("136199;", "500@10"), "sedna": ("90377;", "500@10"),
    "phobos": ("401", "500@499"), "deimos": ("402", "500@499"), "io": ("501", "500@599"), "europa": ("502", "500@599"),
    "ganymede": ("503", "500@599"), "callisto": ("504", "500@599"), "enceladus": ("602", "500@699"), "rhea": ("605", "500@699"),
    "titan": ("606", "500@699"), "iapetus": ("608", "500@699"), "miranda": ("705", "500@799"), "titania": ("703", "500@799"),
    "triton": ("801", "500@899"), "charon": ("901", "500@999"), "moon": ("301", "500@399"),
}


def vectors(cmd, centre, date):
    q = {"format": "json", "COMMAND": f"'{cmd}'", "EPHEM_TYPE": "VECTORS", "CENTER": f"'{centre}'",
         "START_TIME": f"'{date}'", "STOP_TIME": f"'{date} 00:01'", "STEP_SIZE": "'1'", "REF_PLANE": "ECLIPTIC",
         "REF_SYSTEM": "J2000", "OUT_UNITS": "KM-S", "VEC_TABLE": "2", "CSV_FORMAT": "YES", "TIME_TYPE": "UT"}
    url = "https://ssd.jpl.nasa.gov/api/horizons.api?" + urllib.parse.urlencode(q)
    for _ in range(3):
        try:
            result = json.load(urllib.request.urlopen(url, timeout=90))["result"]
            row = result.split("$$SOE")[1].split("$$EOE")[0].strip().splitlines()[0]
            f = [x.strip() for x in row.split(",")]
            return {"r": [float(f[2]), float(f[3]), float(f[4])], "v": [float(f[5]), float(f[6]), float(f[7])]}
        except Exception:
            time.sleep(2)
    raise RuntimeError(f"Horizons failed for {cmd} at {date}")


out = {name: {d: vectors(cmd, c, d) for d in DATES} for name, (cmd, c) in TARGETS.items()}
path = os.path.join(ROOT, "tests", "horizons_reference.json")
open(path, "w", encoding="utf-8", newline="\n").write(json.dumps(out, indent=1) + "\n")
print("wrote", path)
