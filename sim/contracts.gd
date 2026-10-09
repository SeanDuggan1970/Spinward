## Courier contracts: how an offer is made (data/contracts.json). Pure helpers shared
## by the contract system (station boards, approaches) and the tip system (rumoured
## jobs), so neither has to call the other.
##
## An offer: {id, kind, client (operator), issued_at (place), pickup (place or ""),
## to, item, mass_t, passengers, reward, window_s (time allowed from taking the job;
## deadline_t is set when it is taken), expires_t (offer leaves the board), min_rep,
## rep, channel ("board" | "approach" | "rumour"),
## opener (approach text), hidden (rumours until heard), quick_days}. Satellites and
## secret work add flags copied from their kind (OFFER_FLAGS): payload (rides in the
## lander's payload carrier), release (a satellite, released near `to`), plant (a
## listening device, planted near `to`), watched (`to` belongs to the watcher), lander
## (needs a lander bay), covert (secret work) with watcher (the operator it is hidden
## from). A covert drop goes to a site; an extraction collects at one (pickup).
extends RefCounted

const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const Favours := preload("res://sim/favours.gd")

const DAY := 86400.0


## The operator a place works for (contracts there are its business).
static func client_of(data, place: String) -> String:
	return String(data.places.get(place, {}).get("operator", "Independent"))


static func rep_of(state, operator: String) -> float:
	return float(state.reputation.get(operator, 0.0))


## The tier name for a reputation score.
static func tier(data, rep: float) -> String:
	var name := "Unknown"
	for t in data.contracts.get("reputation_tiers", []):
		if rep >= float(t[0]):
			name = String(t[1])
	return name


## A fully fuelled reference ship of a range class, for setting deadlines.
static func reference_ship(data, range_name: String) -> Dictionary:
	var spec: Dictionary = data.contracts["reference_ships"].get(range_name, data.contracts["reference_ships"]["local"])
	var hull: Dictionary = data.ships[spec["hull"]]
	var ship := {"hull": spec["hull"], "modules": hull["modules"].duplicate(), "cargo": {}, "fuel_t": 0.0}
	ship["modules"].merge(spec.get("modules", {}), true)
	ship["fuel_t"] = ShipStats.fuel_capacity_t(ship, data)
	return ship


## Flags a kind passes on to its offers.
const OFFER_FLAGS := ["covert", "payload", "release", "plant", "watched", "lander"]


## Secret work (and free departures) open to a pilot Reliable with anyone.
static func covert_unlocked(state, data) -> bool:
	var need := float(data.contracts.get("covert", {}).get("unlock_rep", INF))
	for op in state.reputation:
		if float(state.reputation[op]) >= need:
			return true
	return false


## Pick a kind by weight among those allowed (min_rep checked by the caller's rules).
## Secret work is picked only when asked for (covert), and then only it.
static func pick_kind(data, rng: RandomNumberGenerator, allow: Callable, covert: bool = false) -> String:
	var kinds: Dictionary = data.contracts["kinds"]
	var ok := func(k: String) -> bool:
		return bool(kinds[k].get("covert", false)) == covert and allow.call(k)
	var total := 0.0
	for k in kinds:
		if ok.call(k):
			total += float(kinds[k]["weight"])
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for k in kinds:
		if ok.call(k):
			roll -= float(kinds[k]["weight"])
			if roll <= 0.0:
				return k
	return ""


## Make an offer issued at `place`. Returns {} when no sensible job comes up (no
## reachable destination for the reference ship, say).
static func make_offer(data, eph, state, rng: RandomNumberGenerator, place: String, kind: String, channel: String) -> Dictionary:
	var spec: Dictionary = data.contracts["kinds"][kind]
	var t: float = state.time_s
	var long_haul: bool = spec.get("range", "local") == "long_haul"
	var everywhere: Array = data.places.keys().filter(func(p): return p != place and preload("res://sim/perks.gd").place_open(state, data, p))
	# Long hauls go between worlds; local jobs stay in the issuing port's neighbourhood.
	# A port alone at its world (Mars, Ceres...) has no neighbours: all its work is long haul.
	var local: Array = everywhere.filter(func(p): return Navigation.frame_body(data, place, p) != "sun")
	if local.is_empty():
		long_haul = true
	var others: Array = everywhere.filter(func(p): return (Navigation.frame_body(data, place, p) == "sun") == long_haul)
	if others.is_empty():
		return {}
	var ref := reference_ship(data, "long_haul" if long_haul else "local")
	var pickup := ""
	var client := client_of(data, place)
	var watcher := ""
	if spec.get("watched", false) or spec.get("plant", false):
		# Aimed at someone else's port: its operator is the one watching.
		others = others.filter(func(p): return data.places[p].has("station") and client_of(data, p) != client)
		if others.is_empty():
			return {}
	if spec.get("to_site", false) or spec.get("from_site", false):
		var sites: Array = data.sites.keys().filter(func(p): return not p.begins_with("_") and (Navigation.frame_body(data, place, p) == "sun") == long_haul)
		if sites.is_empty():
			return {}
		others = sites
	var to: String = others[rng.randi() % others.size()]
	if spec.get("from_site", false):
		# Collect at the site, bring them back here.
		pickup = to
		to = place
	if kind == "pickup":
		pickup = to
		var onward: Array = everywhere.filter(func(p): return p != pickup and (Navigation.frame_body(data, pickup, p) == "sun") == long_haul)
		if onward.is_empty():
			return {}
		to = onward[rng.randi() % onward.size()]
	# Deadline from the reference ship's express time for each leg, with slack.
	var legs: Array = [[place, pickup], [pickup, to]] if pickup != "" else [[place, to]]
	var days := 0.0
	for leg in legs:
		var plan: Dictionary = Navigation.plan(ref, data, eph, leg[0], leg[1], t)
		if not plan.get("ok", false):
			return {}
		days += float(plan["duration_s"]) / DAY
	var slack_range: Array = spec["slack"]
	var slack := rng.randf_range(float(slack_range[0]), float(slack_range[1]))
	var pay_mult := 1.0
	if channel == "approach":
		slack *= float(data.contracts["approach"]["slack_mult"])
		pay_mult = float(data.contracts["approach"]["pay_mult"])
	elif channel == "rumour":
		pay_mult = float(data.contracts["rumour"]["pay_mult"])
	var reward_base_override := [float(spec["pay_base"]), float(spec["pay_per_day"])]
	var heads := 0
	var mass := 0.0
	var item := ""
	var hand := false
	if spec.get("per_head", false):
		var c: Array = spec["count"]
		heads = rng.randi_range(int(c[0]), int(c[1]))
		var who: Array = spec["who"]
		item = who[rng.randi() % who.size()]
		mass = 0.1 * heads
	else:
		# Freight for the hold, or something small enough to carry in the cabin (no hold
		# space, a few kilograms), in proportion to how many of each the kind lists.
		var items: Array = spec["items"]
		var hand_items: Array = spec.get("hand_items", [])
		var pick := rng.randi() % (items.size() + hand_items.size())
		if pick < items.size():
			var m: Array = spec["mass_t"]
			mass = snappedf(rng.randf_range(float(m[0]), float(m[1])), 0.05)
			item = items[pick]
		else:
			var hm: Array = spec["hand_mass_t"]
			mass = snappedf(rng.randf_range(float(hm[0]), float(hm[1])), 0.001)
			item = hand_items[pick - items.size()]
			hand = true
	var urgency := 1.0 + float(spec["urgency"]) * maxf(0.0, float(slack_range[1]) - slack)
	# Work that had to go long-haul pays like it.
	if long_haul and spec.get("range", "local") != "long_haul":
		var lh: Dictionary = data.contracts["kinds"]["long_haul"]
		reward_base_override = [float(lh["pay_base"]), float(lh["pay_per_day"])]
	var reward := (float(reward_base_override[0]) + float(reward_base_override[1]) * days) * urgency * pay_mult * float(maxi(heads, 1))
	if spec.get("covert", false):
		reward *= float(data.contracts["covert"]["pay_mult"])
		if spec.get("watched", false) or spec.get("plant", false):
			watcher = client_of(data, to)
		else:
			# Hidden from someone with ports nearby, not the client or the people at the drop.
			var ops := []
			for p in everywhere:
				var op := client_of(data, p)
				if data.places.has(p) and data.places[p].has("station") and op != client and op != client_of(data, to) and not op in ops:
					ops.append(op)
			if ops.is_empty():
				return {}
			ops.sort()
			watcher = ops[rng.randi() % ops.size()]
	var od: Array = data.contracts["board"]["offer_days"]
	var offer := {
		"kind": kind, "client": client, "issued_at": place, "pickup": pickup, "to": to,
		"item": item, "mass_t": mass, "passengers": heads, "hand": hand, "reward": snappedf(reward, 50.0),
		"window_s": days * slack * DAY, "expires_t": t + rng.randf_range(float(od[0]), float(od[1])) * DAY,
		"min_rep": float(spec.get("min_rep", 0.0)), "rep": float(spec["rep"]), "channel": channel,
		"hidden": channel == "rumour", "quick_days": days,
	}
	for flag in OFFER_FLAGS:
		if spec.get(flag, false):
			offer[flag] = true
	if watcher != "":
		offer["watcher"] = watcher
	# Some clients pay part of it in kind (data/favours.json); the cash part drops to match.
	if not spec.get("covert", false):
		Favours.maybe_in_kind(data, rng, offer)
	return offer
