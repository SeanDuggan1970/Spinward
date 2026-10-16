## Comets: how active a comet is, from its distance to the Sun. Pure functions of data
## and the ephemeris, shared by the site system, the map and anything else that asks.
##
## A comet's ice sublimates once sunlight is strong enough: dormant beyond
## balance.comets.onset_au, then rising roughly with sunlight (1 / r^2) as it falls
## in. Activity 1 is a comet as strong as Halley, at 1 AU. Each comet's own scale is
## its bodies.json "activity.strength". The coma (the gas and dust round the nucleus)
## grows with the square root of activity; inside it, dust wears a ship.
##
## Bent for play (docs/RESEARCH.md): the coma is a sphere, there are no
## outbursts or jets in the sim, and the orbit ignores outgassing's push.
extends RefCounted

const AU := 1.495978707e11


static func is_comet(data, body: String) -> bool:
	return data.bodies.get(body, {}).has("activity")


## Activity at distance r_m from the Sun: 0 when dormant, about `strength` at 1 AU.
static func activity_at(data, body: String, r_m: float) -> float:
	var b: Dictionary = data.bodies.get(body, {})
	if not b.has("activity"):
		return 0.0
	var onset := float(data.balance["comets"]["onset_au"])
	var r_au := maxf(r_m / AU, 0.05)
	var sun := 1.0 / (r_au * r_au) - 1.0 / (onset * onset)
	return maxf(0.0, float(b["activity"]["strength"]) * sun / (1.0 - 1.0 / (onset * onset)))


## Activity now, from where the ephemeris puts the comet.
static func activity(data, eph, body: String, t: float) -> float:
	if not is_comet(data, body):
		return 0.0
	var p: Array = eph.position(body, t)
	return activity_at(data, body, sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]))


## Radius of the dusty inner coma (m). Work inside it wears the ship.
static func coma_m(data, act: float) -> float:
	return float(data.balance["comets"]["coma_km"]) * 1000.0 * sqrt(maxf(act, 0.0))


## "dormant", "stirring" or "active", by the thresholds in balance.comets.
static func state_of(data, act: float) -> String:
	var cfg: Dictionary = data.balance["comets"]
	if act < float(cfg["quiet_below"]):
		return "dormant"
	return "active" if act >= float(cfg["active_from"]) else "stirring"


## Why a comet activity cannot be done at this activity ("" if it can). An activity's
## "comet" is "quiet" (land, drill: only while dormant) or "active" (sample the coma:
## only once it has woken).
static func blocked(data, body: String, need: String, act: float) -> String:
	var state := state_of(data, act)
	var name: String = data.bodies[body]["name"]
	if need == "quiet" and state != "dormant":
		return "%s is outgassing: the jets would throw a lander off. Work it from standoff, or come back when it sleeps" % name
	if need == "active" and state != "active":
		return "%s is %s: there is no coma to sample yet" % [name, "asleep" if state == "dormant" else "only stirring"]
	return ""


## Condition lost by every module for `days` of work inside the coma at `act`.
static func dust_wear(data, act: float, days: float) -> float:
	var cfg: Dictionary = data.balance["comets"]
	return minf(float(cfg["dust_wear_per_day"]) * act * days, float(cfg["dust_wear_max"]))
