## Spin gravity in a station (data/places.json station): the felt "gravity" at a
## distance r from the axis is the centripetal acceleration of the floor, omega^2 r.
## Each station is spun for a chosen gravity on its ring (gravity_g): stately lunar
## to Mars-like for most, never more than 1 g (structural strain grows with it). Ships
## berth in cradles off the hub's axis (balance.bays.hall), where it is a few
## hundredths of a g.
extends RefCounted

const G0 := 9.80665


## Spin rate (rad/s; negative turns the other way).
static func rate(geom: Dictionary) -> float:
	return float(geom.get("spin_rpm", 0.0)) * TAU / 60.0


## The radius where people live: the ring for a wheel or torus, the hull for a drum
## or sphere.
static func living_radius(geom: Dictionary) -> float:
	return float(geom["ring_radius_m"]) if geom.get("type", "wheel") in ["wheel", "stanford"] else float(geom["hub_radius_m"])


## Gravity (in g) at radius r.
static func g_at(geom: Dictionary, r: float) -> float:
	var w := rate(geom)
	return w * w * r / G0


static func living_g(geom: Dictionary) -> float:
	return g_at(geom, living_radius(geom))


## Where a ship's centre sits in its cradle: the hall's radius less the cradle's gap and
## the ship's stowed radius (a small ship sits closer to the wall).
static func cradle_radius(data, ship_r: float) -> float:
	var hall: Dictionary = data.balance["bays"]["hall"]
	return float(hall["radius_m"]) - float(hall["cradle_gap_m"]) - ship_r


## "0.38 g (Mars-like)", for messages.
static func describe(g: float) -> String:
	var like := ""
	if absf(g - 1.0) < 0.06:
		like = "Earth-normal"
	elif absf(g - 0.38) < 0.04:
		like = "Mars-like"
	elif absf(g - 0.165) < 0.03:
		like = "Moon-like"
	elif g < 0.05:
		like = "barely there"
	return "%.2f g%s" % [g, (" (%s)" % like) if like != "" else ""]
