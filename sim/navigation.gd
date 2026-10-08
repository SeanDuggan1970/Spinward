## Route planning: the co-pilot's job.
##
## A transfer is a smooth path from the origin's position and motion to the
## destination's position and motion at the moment of arrival (a cubic Hermite
## curve in the trip frame). Its acceleration is the thrust vector: it varies
## smoothly, pushing toward the target early and braking late, and it bends the path
## to match velocities, so trips to the Moon and the Lagrange stations curve with
## their ~1 km/s motion around Earth. The trip is made as short as possible while
## the thrust needed never exceeds what the drive gives at the ship's current mass;
## propellant is the thrust actually used.
##
## Cislunar trips are planned in the frame that rotates with the Earth-Moon line.
## There the Moon, the Lagrange points and stations orbiting Earth or the Moon all
## sit (nearly) still, so a transfer runs between two fixed points. Seen from
## outside, the path sweeps round with the Moon's motion, about 13 degrees a day,
## giving gentle leading arcs. The frame's rotation is pinned to the Moon's actual
## direction at departure and arrival, so the path lands exactly on the station.
## Gravity is taken to supply the co-rotation; the drive provides only the transfer
## thrust, and that is the vector the ship aligns with.
##
## Deliberate simplifications (see docs/DESIGN.md):
## - Gravity along the way is ignored. The overhead hours cover climbing out of and
##   into each gravity well, so a station's motion is taken as its "anchor" motion:
##   a low-orbit station moves with the body it circles, while a Lagrange station
##   moves with its own point.
## - Positions are relative to the trip's frame body (the lowest common parent
##   body, e.g. Earth for cislunar trips), which is close to inertial over days.
extends RefCounted

const V := preload("res://sim/v3.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const Interplanetary := preload("res://sim/interplanetary.gd")

const SOLVE_STEPS := 48
## Positions recorded along a trip for each body it keeps clear of (fine enough that
## a straight line between two of the Moon's misses its orbit by under 2 km).
const TRACK_STEPS := 96
## Positions recorded for a port while the ship waits on it before the burn or after.
const PORT_STEPS := 24
const TRACK_MARGIN_M := 3000.0
const FUEL_SAMPLES := 24
## Steps at which a straight run is tested against the bodies it must avoid.
const AROUND_STEPS := 256


## The chain of bodies a place hangs from, nearest first.
static func body_chain(data, place: String) -> Array:
	var loc: Dictionary = data.locations[place]["location"]
	var body: String = loc["parent"] if loc["type"] in ["orbit", "surface"] else loc["system"][0]
	var chain := []
	while body != "":
		chain.append(body)
		body = data.bodies[body].get("parent", "")
	return chain


static func frame_body(data, a: String, b: String) -> String:
	var chain_b := body_chain(data, b)
	for body in body_chain(data, a):
		if body in chain_b:
			return body
	return "sun"


## The motion a ship must match at a place, relative to the trip frame.
static func anchor_velocity(data, eph, place: String, frame: String, t: float) -> Array:
	var loc: Dictionary = data.locations[place]["location"]
	var mover: String = loc["parent"] if loc["type"] == "orbit" else place
	if mover == frame:
		return [0.0, 0.0, 0.0]
	return V.sub(eph.velocity(mover, t), eph.velocity(frame, t))


## Acceleration at the start and end of a Hermite transfer of duration T.
## (It is linear in time between the two, so these are its extremes.)
static func end_accels(p0: Array, v0: Array, p1: Array, v1: Array, T: float) -> Array:
	var d := V.sub(p1, p0)
	var a0 := V.scale(V.sub(V.scale(d, 6.0), V.scale(V.add(V.scale(v0, 4.0), V.scale(v1, 2.0)), T)), 1.0 / (T * T))
	var a1 := V.scale(V.add(V.scale(d, -6.0), V.scale(V.add(V.scale(v0, 2.0), V.scale(v1, 4.0)), T)), 1.0 / (T * T))
	return [a0, a1]


## Shortest duration whose peak acceleration fits within `accel`.
static func solve_duration(p0: Array, v0: Array, p1: Array, v1: Array, accel: float) -> float:
	var dist := maxf(V.distance(p0, p1), 1.0)
	var hi := sqrt(6.0 * dist / accel) * 2.0
	for _i in 60:
		var e := end_accels(p0, v0, p1, v1, hi)
		if maxf(V.length(e[0]), V.length(e[1])) <= accel:
			break
		hi *= 1.5
	var lo := hi / 64.0
	for _i in SOLVE_STEPS:
		var mid := 0.5 * (lo + hi)
		var e := end_accels(p0, v0, p1, v1, mid)
		if maxf(V.length(e[0]), V.length(e[1])) <= accel:
			hi = mid
		else:
			lo = mid
	return hi


## The body whose motion defines the rotating frame for trips in `frame` ("" for none).
static func rotating_body(data, frame: String) -> String:
	# Only planet-and-moon systems rotate: a Sun-centred trip has no single dominant
	# companion, and Jupiter's year is no frame for a voyage to Mars.
	if frame == "sun" or not data.bodies.has(frame):
		return ""
	var best := ""
	var best_gm := 0.0
	for body in data.bodies:
		if data.bodies[body].get("parent", "") == frame and float(data.bodies[body].get("gm", 0.0)) > best_gm:
			best = body
			best_gm = float(data.bodies[body]["gm"])
	return best


## Signed angle (rad) from a to b about unit axis k.
static func _angle_about(a: Array, b: Array, k: Array) -> float:
	var ua := V.normalized(a)
	var ub := V.normalized(b)
	return atan2(V.dot(k, V.cross(ua, ub)), V.dot(ua, ub))


## The angle (rad, signed about axis) the rotating body sweeps between two times: the
## sum of short steps, so a burn that spans more than half its orbit counts the extra
## turns (a single atan2 wraps, and the "rotating" frame then turned at the wrong rate
## and the body swept past a ship that was meant to stay put beside it).
static func _swept_angle(data, eph, body: String, frame: String, t0: float, t1: float, m0: Array, axis: Array) -> float:
	var period_s := float(data.bodies[body].get("elements", {}).get("period_days", 0.0)) * 86400.0
	var steps := 1
	if period_s > 0.0:
		steps = clampi(ceili((t1 - t0) / (0.25 * period_s)), 1, 64)
	var total := 0.0
	var prev := m0
	for k in range(1, steps + 1):
		var cur: Array = eph.relative(body, frame, lerpf(t0, t1, float(k) / float(steps)))
		total += _angle_about(prev, cur, axis)
		prev = cur
	return total


## Returns {ok, reason, distance_m, duration_s, burn_s, fuel_t, arrive_t, from_pos,
## from_vel, to_pos, to_vel, frame, ...}. Works for any ship dict (player or NPC).
## from_pos/to_pos are trip-frame positions at the start and end of the burn; in a
## rotating plan, from_rot/to_rot, rot_axis and rot_angle describe the path itself.
static func plan(ship: Dictionary, data, eph, from_place: String, to_place: String, t: float) -> Dictionary:
	var result := {"ok": false, "reason": ""}
	if from_place == to_place:
		result["reason"] = "already here"
		return result
	var accel := ShipStats.accel_mps2(ship, data)
	var ve := ShipStats.exhaust_velocity(ship, data)
	if accel <= 0.0 or ve <= 0.0:
		result["reason"] = "no working drive"
		return result
	var frame := frame_body(data, from_place, to_place)
	if frame == "sun":
		return Interplanetary.quick(ship, data, eph, from_place, to_place, t)
	var travel: Dictionary = data.balance["travel"]
	var overhead := float(travel["overhead_hours"]) * 3600.0
	var depart := t + overhead * 0.5
	var rot_body := rotating_body(data, frame)
	var from_pos: Array = eph.relative(from_place, frame, depart)
	var from_vel: Array
	var to_pos: Array = []
	var to_vel: Array = []
	var burn: float
	var e: Array
	var extra := {}
	if rot_body != "":
		var m0: Array = eph.relative(rot_body, frame, depart)
		var axis := V.normalized(V.cross(m0, V.sub(eph.velocity(rot_body, depart), eph.velocity(frame, depart))))
		var to_rot: Array = []
		var angle := 0.0
		# One pass (a loop only so the straight case can stop early).
		for _pass in 1:
			# Try a duration, aim where the station will be then, and accept it only if
			# the drive can fly it (a = 6d/T^2 at the ends); otherwise lengthen and retry.
			burn = sqrt(6.0 * V.distance(from_pos, eph.relative(to_place, frame, t)) / accel)
			for _i in 40:
				var arrive := depart + burn
				to_pos = eph.relative(to_place, frame, arrive)
				angle = _swept_angle(data, eph, rot_body, frame, depart, arrive, m0, axis)
				to_rot = V.rotate(to_pos, axis, -angle)
				var need := sqrt(6.0 * maxf(V.distance(from_pos, to_rot), 1.0) / accel)
				if need <= burn:
					break
				burn = need * 1.02
			extra = {"from_rot": from_pos, "to_rot": to_rot, "rot_axis": axis, "rot_angle": angle}
			extra["avoid"] = _avoid_list(data, eph, from_place, to_place, frame, depart, burn, axis, angle)
			# In the rotating frame the run is a straight line. If that would cut through
			# a body (or its air), fly round it instead (_around).
			for i in extra["avoid"].size():
				var a: Array = extra["avoid"][i]
				# Fine steps: near the start the smoothstep creeps, so a run that leaves from
				# the far side of a body must be caught within its first few kilometres.
				for k in range(1, AROUND_STEPS):
					var s := float(k) / float(AROUND_STEPS)
					var h := s * s * (3.0 - 2.0 * s)
					if V.distance(V.lerp(from_pos, to_rot, h), _track(a, s)) < float(a[1]) * 1.15:
						extra["around"] = i
						extra["around_r"] = float(a[1])
						break
				if extra.has("around"):
					break
			# A run round a body keeps the straight run's time and propellant: the arc is
			# the shape of the path (clear of the body), and the overhead hours stand for
			# the climb out of orbit, as they always have. So no trip got longer or dearer.
		var omega := V.scale(axis, angle / burn)
		from_vel = V.cross(omega, from_pos)
		to_vel = V.cross(omega, to_pos)
		e = end_accels(from_pos, [0.0, 0.0, 0.0], to_rot, [0.0, 0.0, 0.0], burn)
	else:
		from_vel = anchor_velocity(data, eph, from_place, frame, depart)
		burn = sqrt(6.0 * V.distance(from_pos, eph.relative(to_place, frame, t)) / accel)
		for _i in 40:
			var arrive := depart + burn
			to_pos = eph.relative(to_place, frame, arrive)
			to_vel = anchor_velocity(data, eph, to_place, frame, arrive)
			var need := solve_duration(from_pos, from_vel, to_pos, to_vel, accel)
			if need <= burn:
				break
			burn = need * 1.02
		e = end_accels(from_pos, from_vel, to_pos, to_vel, burn)
		extra["avoid"] = _avoid_list(data, eph, from_place, to_place, frame, depart, burn, [], 0.0)
	# Propellant: thrust is throttled to what the path needs, so integrate |a|.
	var used := 0.0
	for k in FUEL_SAMPLES:
		var f := (float(k) + 0.5) / float(FUEL_SAMPLES)
		used += V.length(V.lerp(e[0], e[1], f)) / accel
	var throttle := used / float(FUEL_SAMPLES)
	var fuel_t := ShipStats.thrust_n(ship, data) / ve * burn * throttle / 1000.0
	var distance := V.distance(from_pos, extra.get("to_rot", to_pos))
	var fuel_after := float(ship.get("fuel_t", 0.0)) - fuel_t
	var dest_refuels: bool = "refuel" in data.locations[to_place].get("services", [])
	result.merge({
		"distance_m": distance, "burn_s": burn, "duration_s": burn + overhead, "fuel_t": fuel_t,
		"arrive_t": t + burn + overhead, "from_pos": from_pos, "from_vel": from_vel,
		"to_pos": to_pos, "to_vel": to_vel, "frame": frame, "throttle": throttle,
		"fuel_after_t": fuel_after, "dest_refuels": dest_refuels,
		# No fuel at the destination and not enough left to come back the same way.
		"strand_risk": not dest_refuels and fuel_after < fuel_t,
	}, true)
	result.merge(extra, true)
	if fuel_t > float(ship.get("fuel_t", 0.0)) + 1e-9:
		result["reason"] = "not enough propellant: need %.2f t, have %.2f t" % [fuel_t, ship["fuel_t"]]
		return result
	result["ok"] = true
	return result


## The bodies a quick trip must keep clear of, each [track, clearance, width]:
##   - the frame body, the body each end orbits, and the frame's rotating body
##   - track: its position in the trip frame at 33 even steps of the burn, in the
##     rotating coordinates when the trip uses them (axis, angle). Bodies move
##     (Titan round Saturn, the Moon nearer and farther), and the path is kept
##     clear of where each one actually is.
##   - width: the softening (_clear_of), never more than either end's height above
##     the clearance, so the ends stay put.
static func _avoid_list(data, eph, from_place: String, to_place: String, frame: String, depart: float, burn: float, axis: Array, angle: float) -> Array:
	var ids := [frame]
	for place in [from_place, to_place]:
		var loc: Dictionary = data.locations[place]["location"]
		if loc["type"] in ["orbit", "surface"] and not loc["parent"] in ids:
			ids.append(loc["parent"])
	var rb := rotating_body(data, frame)
	if rb != "" and not rb in ids:
		ids.append(rb)
	var out := []
	for id in ids:
		if not data.bodies.has(id):
			continue
		var track := []
		for k in TRACK_STEPS + 1:
			var s := float(k) / float(TRACK_STEPS)
			var c: Array = eph.relative(id, frame, depart + burn * s)
			if not axis.is_empty():
				c = V.rotate(c, axis, -angle * s)
			track.append(c)
		# A few km to spare for the track's own straight-line steps.
		var clear := Interplanetary.clearance(data, id) + TRACK_MARGIN_M
		var p0: Array = eph.relative(from_place, frame, depart)
		var p1: Array = eph.relative(to_place, frame, depart + burn)
		var room := minf(V.distance(p0, eph.relative(id, frame, depart)), V.distance(p1, eph.relative(id, frame, depart + burn))) - clear
		out.append([track, clear, clampf(room, 1000.0, clear * 0.05)])
	return out


## A port's positions from t0 to t1 (PORT_STEPS + 1 of them, even steps), for the
## waits either side of a quick trip's burn: [before, after], each null if the trip
## has none. Positions are in the trip frame.
static func port_tracks(eph, from_place: String, to_place: String, frame: String, depart_t: float, burn_start: float, burn_end: float, arrive_t: float) -> Array:
	var out := []
	for leg in [[from_place, depart_t, burn_start], [to_place, burn_end, arrive_t]]:
		if float(leg[2]) - float(leg[1]) < 1.0:
			out.append(null)
			continue
		var track := []
		for k in PORT_STEPS + 1:
			track.append(eph.relative(leg[0], frame, lerpf(float(leg[1]), float(leg[2]), float(k) / float(PORT_STEPS))))
		out.append(track)
	return out


static func _port_track(track: Array, t0: float, t1: float, t: float) -> Array:
	var x := clampf((t - t0) / maxf(t1 - t0, 1e-6), 0.0, 1.0) * float(track.size() - 1)
	var i := mini(int(x), track.size() - 2)
	return V.lerp(track[i], track[i + 1], x - float(i))


## Where an avoided body is at fraction s of the burn: a Catmull-Rom curve through its
## track. (Straight chords between steps cut inside a moon's orbit by hundreds of km
## when the burn spans a good part of it, and that is where the path must stay clear.)
static func _track(a: Array, s: float) -> Array:
	var track: Array = a[0]
	var last := track.size() - 1
	var x := clampf(s, 0.0, 1.0) * float(last)
	var i := mini(int(x), last - 1)
	var u := x - float(i)
	var p1: Array = track[i]
	var p2: Array = track[i + 1]
	var p0: Array = track[i - 1] if i > 0 else V.sub(V.scale(p1, 2.0), p2)
	var p3: Array = track[i + 2] if i + 2 <= last else V.sub(V.scale(p2, 2.0), p1)
	var u2 := u * u
	var u3 := u2 * u
	var out := []
	for k in 3:
		out.append(0.5 * (2.0 * float(p1[k]) + (float(p2[k]) - float(p0[k])) * u
			+ (2.0 * float(p0[k]) - 5.0 * float(p1[k]) + 4.0 * float(p2[k]) - float(p3[k])) * u2
			+ (3.0 * float(p1[k]) - float(p0[k]) - 3.0 * float(p2[k]) + float(p3[k])) * u3))
	return out


## A run round a body in the rotating frame, at fraction s of the burn: the direction
## from the body swings from the start to the end, and the distance runs from one
## end's to the other's with a gentle lift between. It is never nearer than the
## nearer end, and stays clear of the body's air.
static func _around(location: Dictionary, s: float) -> Array:
	var a: Array = location["avoid"][int(location["around"])]
	var q0 := V.sub(location["from_rot"], _track(a, 0.0))
	var q1 := V.sub(location["to_rot"], _track(a, 1.0))
	var r0 := V.length(q0)
	var r1 := V.length(q1)
	var n0 := V.normalized(q0)
	var n1 := V.normalized(q1)
	var axis := V.cross(n0, n1)
	if V.length(axis) < 1e-6:
		axis = location["rot_axis"]
	axis = V.normalized(axis)
	var total := acos(clampf(V.dot(n0, n1), -1.0, 1.0))
	var h := s * s * (3.0 - 2.0 * s)
	var low := minf(r0, r1)
	var lift := maxf(float(location.get("around_r", 0.0)) * 1.2 - low, 0.0) + low * 0.1
	var r := lerpf(r0, r1, h) + lift * sin(PI * h)
	# The swing round it waits for the climb (a smoothstep of the smoothstep), so the
	# turning happens farther out, where it costs less thrust.
	var swing := h * h * (3.0 - 2.0 * h)
	return V.add(_track(a, s), V.scale(V.rotate(n0, axis, total * swing), r))


## The thrust (rotating frame) a run round a body needs at fraction s of a burn of
## `burn` seconds: the path's curvature, taken numerically.
static func _around_accel(location: Dictionary, s: float, burn: float) -> Array:
	var ds := 2e-3
	var sa := clampf(s - ds, 0.0, 1.0)
	var sb := clampf(s + ds, 0.0, 1.0)
	var sm := (sa + sb) * 0.5
	var span := maxf((sb - sa) * 0.5 * burn, 1e-6)
	return V.scale(V.add(V.sub(_around(location, sb), V.scale(_around(location, sm), 2.0)), _around(location, sa)), 1.0 / (span * span))


## Keep a point (at fraction s of the burn) clear of each body in location.avoid:
## within `width` above the clearance the distance is eased up onto it (C1, so the
## path bends rather than kinks), and below it held at the clearance.
static func _clear_of(location: Dictionary, p: Array, s: float) -> Array:
	var avoid = location.get("avoid")
	if avoid == null:
		return p
	for a in avoid:
		var c := _track(a, s)
		var clear := float(a[1])
		var w := float(a[2])
		var q := V.sub(p, c)
		var d := V.length(q)
		if d >= clear + w or d < 1.0:
			continue
		var x := clampf((d - clear) / w, -1.0, 1.0)
		p = V.add(c, V.scale(q, (clear + w * (x + 1.0) * (x + 1.0) * 0.25) / d))
	return p


## Where in the burn we are: [start time, fraction 0..1, burn seconds].
static func _burn_phase(location: Dictionary, t: float) -> Array:
	var duration := float(location["arrive_t"]) - float(location["depart_t"])
	var burn := float(location["burn_s"])
	var start := float(location["depart_t"]) + (duration - burn) * 0.5
	var s := clampf((t - start) / burn, 0.0, 1.0) if burn > 0.0 else 1.0
	return [start, s, burn]


static func _vel(location: Dictionary, key: String) -> Array:
	return location.get(key, [0.0, 0.0, 0.0])


static func _hermite(p0: Array, v0: Array, p1: Array, v1: Array, s: float, T: float) -> Array:
	var s2 := s * s
	var s3 := s2 * s
	var p := V.scale(p0, 2.0 * s3 - 3.0 * s2 + 1.0)
	p = V.add(p, V.scale(v0, (s3 - 2.0 * s2 + s) * T))
	p = V.add(p, V.scale(p1, -2.0 * s3 + 3.0 * s2))
	return V.add(p, V.scale(v1, (s3 - s2) * T))


static func _hermite_vel(p0: Array, v0: Array, p1: Array, v1: Array, s: float, T: float) -> Array:
	var s2 := s * s
	var v := V.scale(p0, (6.0 * s2 - 6.0 * s) / T)
	v = V.add(v, V.scale(v0, 3.0 * s2 - 4.0 * s + 1.0))
	v = V.add(v, V.scale(p1, (-6.0 * s2 + 6.0 * s) / T))
	return V.add(v, V.scale(v1, 3.0 * s2 - 2.0 * s))


static func _rotating(location: Dictionary) -> bool:
	return location.get("rot_axis") != null


# --- Gravity-flown trips: replayed from recorded samples ---------------------------
#
# A sampled trip stores [t, pos, vel, thrust] points from gravity_flight.gd in the
# Earth frame. Between samples the path is a cubic Hermite in position and velocity.
# Before the first sample and after the last, the co-pilot is climbing out of or
# down into a gravity well: the ship slides between the station and the hand-off.

static func _sampled(location: Dictionary) -> bool:
	return location.get("samples") != null


## Index i with samples[i].t <= t < samples[i+1].t (clamped).
static func _seg(samples: Array, t: float) -> int:
	var lo := 0
	var hi := samples.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if float(samples[mid][0]) <= t:
			lo = mid
		else:
			hi = mid
	return lo


static func _sampled_position(location: Dictionary, t: float) -> Array:
	var p := _sampled_raw(location, t)
	if location.get("avoid") == null:
		return p
	var span := maxf(float(location["arrive_t"]) - float(location["depart_t"]), 1.0)
	return _clear_of(location, p, clampf((t - float(location["depart_t"])) / span, 0.0, 1.0))


## The bodies a gravity-flown trip inside a planet's system keeps clear of, tracked
## over the whole trip (see _avoid_list): its recorded samples come from a flight that
## knows of the Moon, but the climb-outs and hand-offs either side of them do not.
static func sampled_avoid(data, eph, from_place: String, to_place: String, frame: String, t_dep: float, t_arr: float) -> Array:
	return _avoid_list(data, eph, from_place, to_place, frame, t_dep, t_arr - t_dep, [], 0.0)


static func _sampled_raw(location: Dictionary, t: float) -> Array:
	var samples: Array = location["samples"]
	var first: Array = samples[0]
	var last: Array = samples[-1]
	if t <= float(first[0]):
		var span := maxf(float(first[0]) - float(location["depart_t"]), 1.0)
		return V.lerp(location["from_pos"], first[1], clampf((t - float(location["depart_t"])) / span, 0.0, 1.0))
	if t >= float(last[0]):
		var span := maxf(float(location["arrive_t"]) - float(last[0]), 1.0)
		return V.lerp(last[1], location["to_pos"], clampf((t - float(last[0])) / span, 0.0, 1.0))
	var i := _seg(samples, t)
	var a: Array = samples[i]
	var b: Array = samples[i + 1]
	var T := float(b[0]) - float(a[0])
	return _hermite(a[1], a[2], b[1], b[2], (t - float(a[0])) / T, T)


static func _sampled_velocity(location: Dictionary, t: float) -> Array:
	var samples: Array = location["samples"]
	var first: Array = samples[0]
	var last: Array = samples[-1]
	if t <= float(first[0]):
		return V.scale(V.sub(first[1], location["from_pos"]), 1.0 / maxf(float(first[0]) - float(location["depart_t"]), 1.0))
	if t >= float(last[0]):
		return V.scale(V.sub(location["to_pos"], last[1]), 1.0 / maxf(float(location["arrive_t"]) - float(last[0]), 1.0))
	var i := _seg(samples, t)
	var a: Array = samples[i]
	var b: Array = samples[i + 1]
	var T := float(b[0]) - float(a[0])
	return _hermite_vel(a[1], a[2], b[1], b[2], (t - float(a[0])) / T, T)


static func _sampled_accel(location: Dictionary, t: float) -> Array:
	var samples: Array = location["samples"]
	if t <= float(samples[0][0]) or t >= float(samples[-1][0]):
		return [0.0, 0.0, 0.0]
	var i := _seg(samples, t)
	var a: Array = samples[i]
	var b: Array = samples[i + 1]
	return V.lerp(a[3], b[3], (t - float(a[0])) / (float(b[0]) - float(a[0])))


## Ship position in the trip frame during transit.
static func transit_position(location: Dictionary, t: float) -> Array:
	var app = location.get("approach")
	if app != null and t >= float(app["t0"]):
		return V.add(_approach_port(app, t), approach_state(location, t)[0])
	return _raw_position(location, t)


static func _raw_position(location: Dictionary, t: float) -> Array:
	if _sampled(location):
		return _sampled_position(location, t)
	var ph := _burn_phase(location, t)
	# Before the burn and after it the ship keeps station on its port, which orbits
	# (and whose world moves): ride along with it rather than wait at a fixed point.
	if location.get("pre_track") != null and t < float(ph[0]):
		return _port_track(location["pre_track"], float(location["depart_t"]), float(ph[0]), t)
	if location.get("post_track") != null and t > float(ph[0]) + float(ph[2]):
		return _port_track(location["post_track"], float(ph[0]) + float(ph[2]), float(location["arrive_t"]), t)
	var s: float = ph[1]
	var T: float = ph[2]
	if _rotating(location):
		var zero := [0.0, 0.0, 0.0]
		var p := _around(location, s) if location.get("around") != null else _hermite(location["from_rot"], zero, location["to_rot"], zero, s, T)
		return V.rotate(_clear_of(location, p, s), location["rot_axis"], float(location["rot_angle"]) * s)
	return _clear_of(location, _hermite(location["from_pos"], _vel(location, "from_vel"), location["to_pos"], _vel(location, "to_vel"), s, T), s)


## Ship velocity in the trip frame during transit (m/s).
static func transit_velocity(location: Dictionary, t: float) -> Array:
	var app = location.get("approach")
	if app != null and t >= float(app["t0"]):
		return V.add(_approach_port_vel(app, t), approach_state(location, t)[1])
	return _raw_velocity(location, t)


static func _raw_velocity(location: Dictionary, t: float) -> Array:
	if _sampled(location):
		return _sampled_velocity(location, t)
	var ph := _burn_phase(location, t)
	var s: float = ph[1]
	var T: float = ph[2]
	if T <= 0.0:
		return _vel(location, "to_vel")
	if location.get("around") != null:
		# Round a body: the derivative of the path, taken numerically (one-sided at the
		# ends of the burn, where the path stops).
		var h := maxf(T * 1e-4, 1.0)
		var a_t := maxf(t - h, float(ph[0]))
		var b_t := minf(t + h, float(ph[0]) + T)
		# At either end the path is at rest in the rotating frame: only the frame turns.
		if t <= float(ph[0]) + 1e-3 or t >= float(ph[0]) + T - 1e-3 or b_t - a_t < 1e-3:
			return V.cross(V.scale(location["rot_axis"], float(location["rot_angle"]) / T), _raw_position(location, t))
		return V.scale(V.sub(_raw_position(location, b_t), _raw_position(location, a_t)), 1.0 / (b_t - a_t))
	if _rotating(location):
		var zero := [0.0, 0.0, 0.0]
		var axis: Array = location["rot_axis"]
		var angle := float(location["rot_angle"]) * s
		var v_rot := _hermite_vel(location["from_rot"], zero, location["to_rot"], zero, s, T)
		var p := _raw_position(location, t)
		return V.add(V.rotate(v_rot, axis, angle), V.cross(V.scale(axis, float(location["rot_angle"]) / T), p))
	return _hermite_vel(location["from_pos"], _vel(location, "from_vel"), location["to_pos"], _vel(location, "to_vel"), s, T)


## The thrust (acceleration) vector during transit (m/s^2); zero outside the burn.
static func transit_accel(location: Dictionary, t: float) -> Array:
	var app = location.get("approach")
	if app != null and t >= float(app["t0"]):
		return approach_state(location, t)[2]
	return _raw_accel(location, t)


static func _raw_accel(location: Dictionary, t: float) -> Array:
	if _sampled(location):
		return _sampled_accel(location, t)
	var ph := _burn_phase(location, t)
	var T: float = ph[2]
	if T <= 0.0 or t < float(ph[0]) or t > float(ph[0]) + T:
		return [0.0, 0.0, 0.0]
	if location.get("around") != null:
		# Round a body: the thrust is the path's curvature in the rotating frame.
		var s0 := float(ph[1])
		return V.rotate(_around_accel(location, s0, T), location["rot_axis"], float(location["rot_angle"]) * s0)
	if _rotating(location):
		var zero := [0.0, 0.0, 0.0]
		var e := end_accels(location["from_rot"], zero, location["to_rot"], zero, T)
		return V.rotate(V.lerp(e[0], e[1], float(ph[1])), location["rot_axis"], float(location["rot_angle"]) * float(ph[1]))
	var e := end_accels(location["from_pos"], _vel(location, "from_vel"), location["to_pos"], _vel(location, "to_vel"), T)
	return V.lerp(e[0], e[1], float(ph[1]))


## What to draw as a destination's track in the trip frame: a station in orbit is
## shown by the body it circles (its own orbit is too fast to draw), a Lagrange
## station by itself; "" when that is the frame body (nothing moves on the map).
static func track_id(data, place: String, frame: String) -> String:
	var loc: Dictionary = data.locations[place]["location"]
	var id: String = loc["parent"] if loc["type"] == "orbit" else place
	return "" if id == frame else id


# --- The final approach: flown in the port's own frame ------------------------------
#
# Over the last minutes before the ship reaches its port (balance.approach), the path
# is set relative to the port rather than taken from the trip: a swing round from
# wherever the trip brings the ship to the corridor entry on the docking axis (wide of
# the station if it comes in from behind), then a straight run along the corridor,
# braking, to the handover point where the docking scene takes over. A quick trip
# that reaches its port early holds there until its arrival time. Trip time and
# propellant are not changed: this re-shapes the last stretch, it does not re-plan it.
#
# Every docking port faces sim -Y (view +Z), as the flight scene builds them.

const DOCK_AXIS := [0.0, -1.0, 0.0]
const APPROACH_STEPS := 48


## The docking scene's starting distance from the port face (metres).
static func handover_m(data, geom: Dictionary) -> float:
	return maxf(float(data.balance["docking"]["spawn_distance_m"]), float(geom["hub_radius_m"]) * 3.0)


## The handover point's distance from the station's centre along the docking axis.
static func handover_from_centre(data, geom: Dictionary) -> float:
	return float(geom["hub_length_m"]) * 0.5 + handover_m(data, geom)


## Plan the final approach for a trip just departed (location as travel_system builds
## it) and store it in location["approach"]. Trips to sites (no port) have none.
static func add_approach(location: Dictionary, data, eph) -> void:
	var to: String = location["to"]
	if not data.places.has(to) or not data.places[to].has("station"):
		return
	var cfg: Dictionary = data.balance["approach"]
	var geom: Dictionary = data.places[to]["station"]
	var frame: String = location["frame"]
	var t_end := float(location["arrive_t"])
	# When the trip reaches the port: a quick trip at the end of its burn (it then waits
	# on the port), any other at its arrival.
	var t_reach := t_end
	var earliest := float(location["depart_t"])
	if not _sampled(location):
		var ph := _burn_phase(location, t_end)
		t_reach = float(ph[0]) + float(ph[2])
		earliest = float(ph[0])
	# The longest window (halving from window_s) whose path clears the bodies the port
	# hangs from: the trip does not match a low orbit's motion, so the further out the
	# approach starts, the further round its world the port may be.
	var bodies := []
	for body in body_chain(data, to):
		if body != "sun":
			bodies.append(body)
	var window := float(cfg["window_s"])
	while window >= 60.0:
		var t0 := maxf(t_reach - window, (earliest + t_reach) * 0.5)
		window *= 0.5
		if t_reach - t0 < 60.0:
			return
		var track := []
		for k in APPROACH_STEPS + 1:
			track.append(eph.relative(to, frame, lerpf(t0, t_end, float(k) / float(APPROACH_STEPS))))
		var port_v0 := V.scale(V.sub(eph.relative(to, frame, t0 + 1.0), eph.relative(to, frame, t0 - 1.0)), 0.5)
		var r0 := V.sub(_raw_position(location, t0), track[0])
		var v0 := V.sub(_raw_velocity(location, t0), port_v0)
		var app := {"t0": t0, "t_reach": t_reach, "t_end": t_end, "track": track,
			"legs": _approach_legs(r0, v0, t0, t_reach, t_end, geom, data)}
		if _approach_clear(app, bodies, data, eph, frame):
			location["approach"] = app
			return


## Whether an approach keeps out of each body's clearance (Interplanetary.clearance),
## unless the port itself is inside it (a surface port).
static func _approach_clear(app: Dictionary, bodies: Array, data, eph, frame: String) -> bool:
	var loc := {"approach": app}
	var t1 := float(app["t_end"])
	for body in bodies:
		var need := Interplanetary.clearance(data, body)
		if V.distance(_approach_port(app, t1), eph.relative(body, frame, t1)) < need * 1.01:
			continue
		for leg in app["legs"]:
			for k in 41:
				var t := lerpf(float(leg[0]), float(leg[1]), float(k) / 40.0)
				var here := V.add(_approach_port(app, t), approach_state(loc, t)[0])
				if V.distance(here, eph.relative(body, frame, t)) < need:
					return false
	return true


## [[t_a, t_b, p_a, v_a, p_b, v_b, phase]] relative to the port: "swing" legs to the
## corridor entry, a "hold" there if the trip reaches its port early (a quick trip
## waiting on it), then the "corridor" run to the hand-over point, ending at arrival.
static func _approach_legs(r0: Array, v0: Array, t0: float, t_reach: float, t_end: float, geom: Dictionary, data) -> Array:
	var cfg: Dictionary = data.balance["approach"]
	var n: Array = DOCK_AXIS
	var zero := [0.0, 0.0, 0.0]
	var v_h := float(cfg["handover_speed_mps"])
	var v_c := float(cfg["corridor_speed_mps"])
	var d_h := handover_from_centre(data, geom)
	var bound := maxf(maxf(float(geom.get("ring_radius_m", 0.0)) + float(geom.get("ring_tube_m", 0.0)), float(geom["hub_radius_m"])), float(geom["hub_length_m"]) * 0.5) + float(cfg["clear_margin_m"])
	var d_c := maxf(d_h + float(cfg["corridor_m"]), bound * 2.0)
	var handover := V.scale(n, d_h)
	var entry := V.scale(n, d_c)
	# A steady braking run along the corridor, unless the window is too short for it.
	var t_c := t_end - minf(2.0 * (d_c - d_h) / (v_c + v_h), (t_reach - t0) * 0.6)
	var waits := t_reach < t_c
	var swing_end := t_reach if waits else t_c
	var v_entry := zero if waits else V.scale(n, -v_c)
	var legs := []
	var dist := V.length(r0)
	var cos_in := V.dot(r0, n) / maxf(dist, 1e-6)
	if cos_in >= float(cfg["swing_cos"]) or dist < bound:
		legs.append([t0, swing_end, r0, v0, entry, v_entry, "swing"])
	else:
		# Coming in from the side or behind: go round wide of the station.
		var perp := V.sub(r0, V.scale(n, V.dot(r0, n)))
		if V.length(perp) < 1.0:
			perp = [0.0, 0.0, -1.0]
		var wide := V.add(V.scale(V.normalized(perp), maxf(bound * 2.0, float(cfg["corridor_m"]))), V.scale(n, d_c * 0.5))
		var t_s := lerpf(t0, swing_end, 0.6)
		var v_s := V.scale(V.sub(entry, wide), 1.0 / maxf(swing_end - t_s, 1.0))
		legs.append([t0, t_s, r0, v0, wide, v_s, "swing"])
		legs.append([t_s, swing_end, wide, v_s, entry, v_entry, "swing"])
	if waits:
		legs.append([t_reach, t_c, entry, zero, entry, zero, "hold"])
	legs.append([t_c, t_end, entry, v_entry, handover, V.scale(n, -v_h), "corridor"])
	return legs


## Where the ship is relative to its port on the final approach (trip frame axes):
## [position, velocity, thrust, phase], phase "swing", "hold" or "corridor". Phase ""
## (and zeros) outside the approach.
static func approach_state(location: Dictionary, t: float) -> Array:
	var zero := [0.0, 0.0, 0.0]
	var app = location.get("approach")
	if app == null or t < float(app["t0"]):
		return [zero, zero, zero, ""]
	var legs: Array = app["legs"]
	for leg in legs:
		var ta := float(leg[0])
		var tb := float(leg[1])
		if t <= tb:
			var T := maxf(tb - ta, 1e-6)
			var s := clampf((t - ta) / T, 0.0, 1.0)
			return [_hermite(leg[2], leg[3], leg[4], leg[5], s, T), _hermite_vel(leg[2], leg[3], leg[4], leg[5], s, T),
				_hermite_acc(leg[2], leg[3], leg[4], leg[5], s, T), leg[6]]
	return [legs[-1][4], zero, zero, "corridor"]


static func _hermite_acc(p0: Array, v0: Array, p1: Array, v1: Array, s: float, T: float) -> Array:
	var a := V.scale(p0, (12.0 * s - 6.0) / (T * T))
	a = V.add(a, V.scale(v0, (6.0 * s - 4.0) / T))
	a = V.add(a, V.scale(p1, (6.0 - 12.0 * s) / (T * T)))
	return V.add(a, V.scale(v1, (6.0 * s - 2.0) / T))


static func _approach_port(app: Dictionary, t: float) -> Array:
	var s := clampf((t - float(app["t0"])) / maxf(float(app["t_end"]) - float(app["t0"]), 1.0), 0.0, 1.0)
	return _track([app["track"]], s)


static func _approach_port_vel(app: Dictionary, t: float) -> Array:
	# Differenced within the track (one-sided at its ends, where it is clamped).
	var ta := maxf(t - 1.0, float(app["t0"]))
	var tb := minf(t + 1.0, float(app["t_end"]))
	if tb - ta < 1e-3:
		ta = tb - 1.0
	return V.scale(V.sub(_approach_port(app, tb), _approach_port(app, ta)), 1.0 / (tb - ta))
