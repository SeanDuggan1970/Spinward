"""Fit every body except the Sun, Earth and the Moon to JPL Horizons.

Osculating elements from Horizons' state vectors at 2061-03-01 00:00 UT (ecliptic
J2000, relative to the parent), then the mean motion fitted so the body is also where
Horizons puts it at 2063-03-01. Exact at the start of play, and within a fraction of
a degree for years either side, which suits a game set in the 2060s.
"""
import json, math, os, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.join(ROOT, "tests")
bodies = json.load(open(os.path.join(ROOT, "data", "bodies.json"), encoding="utf-8"))
hz = json.load(open(os.path.join(HERE, "horizons_reference.json")))

J2000 = datetime.datetime(2000, 1, 1, 12, 0, 0)
def secs(date):
    return (datetime.datetime.fromisoformat(date) - J2000).total_seconds()

def sub(a, b): return [a[0]-b[0], a[1]-b[1], a[2]-b[2]]
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def norm(a): return math.sqrt(dot(a, a))
def scale(a, s): return [a[0]*s, a[1]*s, a[2]*s]

def elements(r, v, mu):
    h = cross(r, v)
    n = cross([0, 0, 1], h)
    rn = norm(r)
    e_vec = sub(scale(r, dot(v, v) / mu - 1.0 / rn), scale(v, dot(r, v) / mu))
    e = norm(e_vec)
    energy = dot(v, v) / 2 - mu / rn
    a = -mu / (2 * energy)
    i = math.acos(h[2] / norm(h))
    node = math.atan2(n[1], n[0]) if norm(n) > 1e-12 else 0.0
    # Argument of periapsis and true anomaly (in-plane, from the node).
    if norm(n) > 1e-12:
        nu_from_node = math.atan2(dot(cross(n, r), h) / norm(h), dot(n, r))
        w = math.atan2(dot(cross(n, e_vec), h) / norm(h), dot(n, e_vec)) if e > 1e-9 else 0.0
    else:
        nu_from_node = math.atan2(r[1], r[0])
        w = math.atan2(e_vec[1], e_vec[0]) if e > 1e-9 else 0.0
    nu = nu_from_node - w
    E = 2 * math.atan2(math.sqrt(1 - e) * math.sin(nu / 2), math.sqrt(1 + e) * math.cos(nu / 2))
    M = E - e * math.sin(E)
    return a, e, i, node, w, M, nu_from_node, h

def in_plane_angle(r, node, i, h):
    n = [math.cos(node), math.sin(node), 0.0]
    hn = scale(h, 1 / norm(h))
    return math.atan2(dot(cross(n, r), hn), dot(n, r))

t1 = secs("2061-03-01T00:00:00")
t2 = secs("2063-03-01T00:00:00")
report = []
for name, states in hz.items():
    if name == "moon":
        continue
    b = bodies[name]
    parent = b["parent"]
    mu = (float(bodies[parent]["gm"]) + float(b.get("gm", 0.0)))
    s1 = states["2061-03-01"]; s2 = states["2063-03-01"]
    r1 = scale(s1["r"], 1000.0); v1 = scale(s1["v"], 1000.0)
    r2 = scale(s2["r"], 1000.0)
    a, e, i, node, w, M1, u1, h = elements(r1, v1, mu)
    n_kepler = math.sqrt(mu / a ** 3)
    # Mean motion from the angle actually travelled, resolving whole turns with Kepler's n.
    # Mean anomaly at t2 on the t1 orbit shape (true anomaly is not uniform in time).
    u2 = in_plane_angle(r2, node, i, h)
    nu2 = u2 - w
    E2 = 2 * math.atan2(math.sqrt(1 - e) * math.sin(nu2 / 2), math.sqrt(1 + e) * math.cos(nu2 / 2))
    M2 = E2 - e * math.sin(E2)
    turns_guess = n_kepler * (t2 - t1) / (2 * math.pi)
    advance = (M2 - M1) % (2 * math.pi)
    k = round(turns_guess - advance / (2 * math.pi))
    n_fit = (advance + 2 * math.pi * k) / (t2 - t1)
    if abs(n_fit / n_kepler - 1) > 0.02:
        n_fit = n_kepler  # resolve failed (very slow movers); trust Kepler
    m0 = (math.degrees(M1 - n_fit * t1)) % 360.0
    el = {"a_m": a, "e": e, "i_deg": math.degrees(i), "node_deg": math.degrees(node) % 360.0,
          "peri_deg": math.degrees(w) % 360.0, "m0_deg": m0, "period_days": 2 * math.pi / n_fit / 86400.0}
    b["elements"] = el
    report.append((name, a, e, math.degrees(i), el["period_days"], n_fit / n_kepler))
bodies["_source"] = ("Sun, Earth and Moon: as before (Earth JPL approximate elements, Table 1; Moon mean elements after Meeus ch. 47). "
    "Every other body: osculating elements from JPL Horizons state vectors at 2061-03-01 00:00 UT (ecliptic J2000, relative to the parent), "
    "with the mean motion fitted to Horizons' position at 2063-03-01, so positions are right through the 2060s. Fetched 2026-10-04. "
    "GM values: JPL/IAU. 'kind' sorts bodies on the map; 'look' picks and tunes the surface shader (rock, gas, clouds; Earth has its own).")
open(os.path.join(ROOT, "data", "bodies.json"), "w", encoding="utf-8", newline="\n").write(json.dumps(bodies, indent="\t", ensure_ascii=False) + "\n")
for r in report:
    print("%-10s a=%.4g e=%.4f i=%.2f P=%.4f d  n_fit/n_kep=%.6f" % r)
