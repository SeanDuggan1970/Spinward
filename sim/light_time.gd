## Where to point a dish. Light takes time to cross space, and everything moves
## meanwhile, so the antenna has two answers:
##   receive   the target is seen where it was when the signal left it, at t - tau,
##             with tau = |target(t - tau) - ship(t)| / c
##   transmit  aim where the target will be when the signal arrives, at t + tau,
##             with tau = |target(t + tau) - ship(t)| / c
## Both are then corrected for aberration from the ship's own velocity (first order
## in v/c), which turns an inertial direction into the one seen aboard. The gap between
## the two is the point-ahead angle. Positions are 64-bit [x, y, z] in metres in the
## ephemeris' inertial frame; velocities in m/s.
extends RefCounted

const V := preload("res://sim/v3.gd")
const C := 299792458.0


## {tau_s, dir (unit, as aimed aboard), pos (target where the light meets it)}.
## lead +1 transmits, -1 receives.
static func solve(eph, target: String, ship_pos: Array, ship_vel: Array, t: float, lead: float) -> Dictionary:
	var tau := 0.0
	var p: Array = eph.position(target, t)
	# Fixed-point iteration converges by a factor of v/c each pass; three is plenty.
	for _i in 3:
		tau = V.distance(p, ship_pos) / C
		p = eph.position(target, t + lead * tau)
	var d := V.normalized(V.sub(p, ship_pos))
	# Aberration: received light arrives tilted toward the direction of motion; to
	# send a beam along d, aim slightly against it.
	var beta := V.scale(ship_vel, 1.0 / C)
	var aim := V.normalized(V.add(d, V.scale(beta, -lead)))
	return {"tau_s": tau, "dir": aim, "pos": p}


## Both solutions and the angle between them (radians).
static func pointing(eph, target: String, ship_pos: Array, ship_vel: Array, t: float) -> Dictionary:
	var tx := solve(eph, target, ship_pos, ship_vel, t, 1.0)
	var rx := solve(eph, target, ship_pos, ship_vel, t, -1.0)
	# 2 asin(chord / 2) keeps precision for the micro-radian angles involved.
	var chord := V.distance(tx["dir"], rx["dir"])
	return {"transmit": tx, "receive": rx, "tau_s": tx["tau_s"], "point_ahead_rad": 2.0 * asin(clampf(chord * 0.5, 0.0, 1.0))}
