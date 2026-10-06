## Display pages and panel furniture shared by the approach and transit cockpits:
## the SYSTEMS page (propellant, drive and heat, life support, hull, cargo and a ship
## schematic with per-module damage), the glareshield annunciator panel, and the flat
## layout used when there is no flight deck in view (the chase camera).
extends RefCounted

const AV := preload("res://view/ui/avionics.gd")
const UI := preload("res://view/ui/ui_kit.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")
const Power := preload("res://sim/power.gd")

## Alert thresholds are data (balance.json "cockpit"): they colour lamps; the rules
## live in the sim.

## Schematic order, nose to tail.
const ORDER := ["command", "avionics", "hab", "passenger", "cargo", "tank", "drive"]


## Schematic colour for a module: green sound, amber damaged, red badly damaged.
static func damage_colour(d: float) -> Color:
	if d >= 0.5:
		return AV.RED
	if d >= 0.02:
		return AV.AMBER
	return AV.GREEN


## Nominal (undamaged) total of a module stat.
static func nominal(ship: Dictionary, data, key: String) -> float:
	var total := 0.0
	for m in ShipStats.modules_of(ship, data):
		total += float(m.get(key, 0.0))
	return total


## Alerts every cockpit shares: [legend, level (0 off, 1 caution, 2 warning)].
static func ship_alerts(sim, wrecked: bool = false) -> Dictionary:
	var ship: Dictionary = sim.state.ship
	var data = sim.data
	var hull := 0.0 if wrecked else DamageSystem.integrity(ship)
	var cap := ShipStats.fuel_capacity_t(ship, data)
	var fuel := float(ship.get("fuel_t", 0.0)) / maxf(nominal(ship, data, "fuel_t"), 1e-6)
	var heat := ShipStats.heat_ratio(ship, data)
	var worst_drive := 0.0
	for slot in ship.get("modules", {}):
		if String(slot).begins_with("drive"):
			worst_drive = maxf(worst_drive, DamageSystem.damage_of(ship, slot))
	var tune: Dictionary = data.balance["cockpit"]
	return {
		"HULL": 2 if hull < float(tune["hull_warning"]) else (1 if hull < float(tune["hull_caution"]) else 0),
		"FUEL LOW": 2 if fuel < float(tune["fuel_warning"]) else (1 if fuel < float(tune["fuel_caution"]) or cap < 1e-6 else 0),
		"HEAT": _level(heat, float(tune["heat_caution"]), float(tune["heat_warning"]), true),
		"DRIVE": _level(worst_drive, float(tune["damage_caution"]), float(tune["damage_warning"])),
		"POWER": power_level(Power.now(sim.state, data, sim.ephemeris), tune),
	}


## 2 past `warn`, 1 past `caution`, else 0. `above`: strictly (heat is a ratio that
## is fine at exactly 1.0); otherwise at or beyond (damage).
static func _level(v: float, caution: float, warn: float, above: bool = false) -> int:
	if above:
		return 2 if v > warn else (1 if v > caution else 0)
	return 2 if v >= warn else (1 if v >= caution else 0)


## POWER lamp: red when life support is the next thing to go, amber when loads are
## shed or the battery is running down; off on shore power or a healthy bus.
static func power_level(snap: Dictionary, tune: Dictionary) -> int:
	if snap["mode"] == "docked":
		return 0
	if int(snap["shed"]) >= 3 or snap["flat"]:
		return 2
	if int(snap["shed"]) >= 1:
		return 1
	if float(snap["net_kw"]) < 0.0 and (float(snap["frac"]) < float(tune["power_caution_frac"]) or float(snap["hours_to_empty"]) < float(tune["power_caution_hours"])):
		return 1
	return 0


# --- SYSTEMS page --------------------------------------------------------------------

static func systems(g, sim, keys: Array, wrecked: bool = false) -> void:
	var ship: Dictionary = sim.state.ship
	var data = sim.data
	var W: float = g.size.x
	g.glass()
	g.title("SYSTEMS", "%s  %.1f t" % [String(ship.get("name", "")).to_upper(), ShipStats.total_mass_t(ship, data)])
	_schematic(g, ship, data, Rect2(10, 22, W - 20, 36), wrecked)
	# The worst-hit module, named.
	var worst := ""
	var worst_d := 0.0
	for slot in ship.get("modules", {}):
		var dd := DamageSystem.damage_of(ship, slot)
		if dd > worst_d:
			worst_d = dd
			worst = String(data.modules[ship["modules"][slot]]["name"])
	if wrecked:
		g.text(Vector2(W * 0.5, 71), "HULL LOST", 10, AV.RED, 0)
	elif worst_d >= 0.02:
		var more := 0
		for slot in ship.get("modules", {}):
			if DamageSystem.damage_of(ship, slot) >= 0.02:
				more += 1
		var label := "DMG  %s %d%%%s" % [worst.to_upper(), int(round(worst_d * 100.0)), ("  +%d MORE" % (more - 1)) if more > 1 else ""]
		g.text(Vector2(W * 0.5, 71), label, 10, damage_colour(worst_d), 0)
	# Gauges in two columns.
	var col_w := (W - 30) * 0.5
	var x0 := 10.0
	var x1 := 20.0 + col_w
	var y := 84.0
	var fuel := float(ship.get("fuel_t", 0.0))
	var fuel_nom := maxf(nominal(ship, data, "fuel_t"), 1e-6)
	var fuel_cap := ShipStats.fuel_capacity_t(ship, data)
	var ff := fuel / fuel_nom
	var thrust := ShipStats.thrust_n(ship, data)
	var ve := ShipStats.exhaust_velocity(ship, data)
	var burn_s := INF if thrust <= 0.0 else fuel * 1000.0 * ve / thrust
	var tune: Dictionary = data.balance["cockpit"]
	var fcol := AV.RED if ff < float(tune["fuel_warning"]) else (AV.AMBER if ff < float(tune["fuel_caution"]) else AV.GREEN)
	g.bar(Vector2(x0, y), col_w, "PROP", ff, "%d%%" % int(round(ff * 100.0)), fcol, fuel_cap / fuel_nom if fuel_cap < fuel_nom - 1e-6 else -1.0)
	g.text(Vector2(x0, y + 13), "%.2f t  BURN %s" % [fuel, "--" if burn_s == INF else _hm(burn_s)], 11, AV.WHITE)
	var heat := ShipStats.heat_ratio(ship, data)
	var hcol := AV.RED if heat > float(tune["heat_warning"]) else (AV.AMBER if heat > float(tune["heat_caution"]) else AV.GREEN)
	g.bar(Vector2(x0, y + 32), col_w, "RAD", minf(heat, 1.0) if heat != INF else 1.0, "--" if heat == INF else "%d%%" % int(round(heat * 100.0)), hcol)
	var thrust_nom := nominal(ship, data, "thrust_n")
	var tf := 0.0 if thrust_nom <= 0.0 else thrust / thrust_nom
	g.bar(Vector2(x0, y + 50), col_w, "DRV", tf, "%d%%" % int(round(tf * 100.0)), AV.GREEN if tf > 0.95 else (AV.AMBER if tf > 0.5 else AV.RED))
	if heat > 1.0:
		g.text(Vector2(x0, y + 63), "THROTTLE BACK  %d%%" % int(round(100.0 / heat)), 11, hcol)
	var hull := 0.0 if wrecked else DamageSystem.integrity(ship)
	var kcol := AV.RED if hull < float(tune["hull_warning"]) else (AV.AMBER if hull < float(tune["hull_caution"]) else AV.GREEN)
	g.bar(Vector2(x1, y), col_w, "KEEL", hull, "LOST" if wrecked else "%d%%" % int(round(hull * 100.0)), kcol)
	var cargo := ShipStats.cargo_t(ship)
	var cargo_cap := ShipStats.cargo_capacity_t(ship, data)
	var cargo_nom := maxf(nominal(ship, data, "cargo_t"), 1e-6)
	g.bar(Vector2(x1, y + 14), col_w, "HOLD", cargo / cargo_nom, "%.0f/%.0f t" % [cargo, cargo_cap], AV.WHITE if cargo_cap >= cargo_nom - 1e-6 else AV.AMBER, cargo_cap / cargo_nom if cargo_cap < cargo_nom - 1e-6 else -1.0)
	_power(g, sim, Vector2(x1, y + 28), col_w, tune)
	var ls := ShipStats.life_support_days(ship, data)
	var ls_nom := nominal(ship, data, "life_support_days")
	g.row(Vector2(x1, y + 63), "L/S", "UNCREWED" if ls == INF else "%d d" % int(ls), AV.WHITE if ls == INF or ls >= ls_nom - 0.5 else AV.AMBER)
	g.soft_keys(keys)


## Electrical bus: battery bar, then state and net power, then time to empty or full.
## Colours: white measured, green fine, amber loads shed or battery running down, red
## life support is next.
static func _power(g, sim, at: Vector2, w: float, tune: Dictionary) -> void:
	var snap: Dictionary = Power.now(sim.state, sim.data, sim.ephemeris)
	var level := power_level(snap, tune)
	var col := AV.RED if level == 2 else (AV.AMBER if level == 1 else AV.GREEN)
	var frac: float = snap["frac"]
	g.bar(at, w, "BATT", frac, "%d%%" % int(round(frac * 100.0)), col)
	var net: float = snap["net_kw"]
	g.text(at + Vector2(0, 12), "BUS " + String(snap["state"]), 11, col)
	g.text(at + Vector2(w, 12), "%+.1f kW" % net, 11, AV.WHITE, 1)
	var when := ""
	if snap["mode"] != "docked" and net < 0.0:
		when = "EMPTY " + _hm(float(snap["hours_to_empty"]) * 3600.0)
	elif net > 0.0 and frac < 0.999:
		when = "FULL " + _hm(float(snap["hours_to_full"]) * 3600.0)
	if int(snap["shed"]) >= 3:
		when = "L/S RESERVE"
	elif int(snap["shed"]) >= 1:
		when = "SHED " + ("COMMS" if int(snap["shed"]) == 1 else "COMMS+RIG")
	g.text(at + Vector2(0, 23), when, 11, col if int(snap["shed"]) >= 1 else AV.WHITE)


static func _hm(s: float) -> String:
	if s >= 86400.0 * 2.0:
		return "%.0f d" % (s / 86400.0)
	return "%d h %02d" % [int(s / 3600.0), int(fmod(s, 3600.0) / 60.0)]


## Top view of the ship, nose left: modules in their sections along the keel,
## radiators as fins, each coloured by its damage.
static func _schematic(g, ship: Dictionary, data, r: Rect2, wrecked: bool) -> void:
	var slots: Array = ship.get("modules", {}).keys()
	var body := []
	var fins := []
	for slot in slots:
		var kind := String(slot).split(".")[0]
		if kind == "radiator":
			fins.append(slot)
		else:
			body.append(slot)
	body.sort_custom(func(a, b):
		var ka := ORDER.find(String(a).split(".")[0])
		var kb := ORDER.find(String(b).split(".")[0])
		ka = 3 if ka < 0 else ka
		kb = 3 if kb < 0 else kb
		return ka < kb if ka != kb else String(a) < String(b))
	var keel := 1.0 if wrecked else DamageSystem.damage_of(ship, "keel")
	var cy := r.get_center().y
	g.line(Vector2(r.position.x, cy), Vector2(r.end.x, cy), damage_colour(keel), 2.0)
	var n := body.size()
	if n == 0:
		return
	var gap := 4.0
	var w := (r.size.x - gap * (n - 1)) / n
	var tank_x := []
	for i in n:
		var slot: String = body[i]
		var kind := slot.split(".")[0]
		var d := 1.0 if wrecked else DamageSystem.damage_of(ship, slot)
		var col := damage_colour(d)
		var x := r.position.x + i * (w + gap)
		var hh := r.size.y * (0.34 if kind in ["command", "avionics"] else (0.42 if kind == "cargo" else 0.3))
		var box := Rect2(x, cy - hh, w, hh * 2.0)
		if kind == "command":
			g.poly(PackedVector2Array([Vector2(x, cy - hh * 0.4), Vector2(x + w * 0.35, cy - hh), Vector2(x + w, cy - hh), Vector2(x + w, cy + hh), Vector2(x + w * 0.35, cy + hh), Vector2(x, cy + hh * 0.4)]), Color(col, 0.18))
			g.polyline(PackedVector2Array([Vector2(x, cy - hh * 0.4), Vector2(x + w * 0.35, cy - hh), Vector2(x + w, cy - hh), Vector2(x + w, cy + hh), Vector2(x + w * 0.35, cy + hh), Vector2(x, cy + hh * 0.4), Vector2(x, cy - hh * 0.4)]), col, 1.0)
		elif kind == "drive":
			g.poly(PackedVector2Array([Vector2(x, cy - hh), Vector2(x + w * 0.6, cy - hh), Vector2(x + w, cy - hh * 1.3), Vector2(x + w, cy + hh * 1.3), Vector2(x + w * 0.6, cy + hh), Vector2(x, cy + hh)]), Color(col, 0.18))
			g.polyline(PackedVector2Array([Vector2(x, cy - hh), Vector2(x + w * 0.6, cy - hh), Vector2(x + w, cy - hh * 1.3), Vector2(x + w, cy + hh * 1.3), Vector2(x + w * 0.6, cy + hh), Vector2(x, cy + hh), Vector2(x, cy - hh)]), col, 1.0)
		elif kind == "tank":
			g.ellipse(box.get_center(), w * 0.5, hh, Color(col, 0.18), true, 1.0, 20)
			g.ellipse(box.get_center(), w * 0.5, hh, col, false, 1.0, 20)
			tank_x.append(box.get_center().x)
		else:
			g.rect(box, Color(col, 0.18))
			g.rect(box, col, false, 1.0)
		if d >= 0.999:
			g.line(box.position, box.end, AV.RED, 1.5)
			g.line(Vector2(box.position.x, box.end.y), Vector2(box.end.x, box.position.y), AV.RED, 1.5)
	# Radiator fins on booms, either side of the tanks (or mid-ship).
	var fx: float = tank_x[0] if not tank_x.is_empty() else r.get_center().x
	for i in fins.size():
		var d := 1.0 if wrecked else DamageSystem.damage_of(ship, fins[i])
		var col := damage_colour(d)
		var up := 1.0 if i % 2 == 0 else -1.0
		var x := fx + (int(i / 2) - (fins.size() - 1) / 4.0) * 16.0
		var fin := Rect2(x - 6, cy - r.size.y * 0.5 if up > 0 else cy + r.size.y * 0.5 - 8, 12, 8)
		g.line(Vector2(x, cy), Vector2(x, fin.get_center().y), Color(col, 0.6), 1.0)
		g.rect(fin, Color(col, 0.35))
		g.rect(fin, col, false, 1.0)


# --- Annunciator panel ---------------------------------------------------------------

## The glareshield strip: master warning and caution, two banks of six annunciators
## either side of the co-pilot's message window, and the clock.
## left / right: [[legend, level], ...] with level 0 off, 1 amber caution, 2 red
## warning, or a Color for a lit status (green, cyan).
static func annunciators(g, left: Array, right: Array, message: String, msg_col: Color, clock: Array, t: float) -> void:
	var W: float = g.size.x
	var H: float = g.size.y
	g.rect(Rect2(Vector2.ZERO, g.size), Color("0a0c0d"))
	var warn := false
	var caution := false
	for a in left + right:
		if typeof(a[1]) == TYPE_INT:
			warn = warn or a[1] == 2
			caution = caution or a[1] == 1
	var blink := fmod(t, 0.8) > 0.4
	var cw := 64.0
	_master(g, Rect2(4, 3, cw, H - 6), "MASTER", "WARN", warn, AV.RED, warn and blink)
	_master(g, Rect2(8 + cw, 3, cw, H - 6), "MASTER", "CAUTION", caution, AV.AMBER, false)
	var bank_w := minf(W * 0.21, 290.0)
	var clock_w := 132.0
	var x := 16.0 + cw * 2.0
	_bank(g, Rect2(x, 3, bank_w, H - 6), left, blink)
	var rx := W - 8.0 - clock_w - bank_w
	_bank(g, Rect2(rx, 3, bank_w, H - 6), right, blink)
	# Co-pilot's message window.
	var mw := Rect2(x + bank_w + 8, 3, rx - x - bank_w - 16, H - 6)
	g.rect(mw, Color("040606"))
	g.rect(mw, Color("23292b"), false, 1.0)
	g.text(mw.position + Vector2(5, 11), "CO-PILOT", 9, AV.GREY)
	var lines := _wrap(g, message, 12.0, mw.size.x - 12)
	var ly := mw.position.y + (24.0 if lines.size() > 1 else 30.0)
	for l in lines.slice(0, 2):
		g.text(Vector2(mw.position.x + 6, ly), l, 12, msg_col)
		ly += 14.0
	# Clock: UTC, time compression, credits.
	var cr := Rect2(W - 4 - clock_w, 3, clock_w, H - 6)
	g.rect(cr, Color("040606"))
	g.rect(cr, Color("23292b"), false, 1.0)
	g.text(cr.position + Vector2(6, 17), clock[0], 13, AV.WHITE)
	g.text(cr.position + Vector2(6, 36), clock[1], 11, clock[2])
	g.text(cr.position + Vector2(clock_w - 6, 36), clock[3], 11, AV.GREY, 1)


static func _master(g, r: Rect2, a: String, b: String, on: bool, col: Color, dim: bool) -> void:
	g.rect(r, Color("0b0d0e"))
	var lit := on and not dim
	g.rect(r.grow(-1.5), Color(col, 0.28) if lit else Color("141819"))
	g.rect(r.grow(-1.5), col if lit else Color("2a3134"), false, 1.0)
	var tc := col.lightened(0.2) if lit else Color("454d50")
	g.text(Vector2(r.get_center().x, r.position.y + r.size.y * 0.44), a, 10, tc, 0)
	g.text(Vector2(r.get_center().x, r.position.y + r.size.y * 0.80), b, 11, tc, 0)


static func _bank(g, r: Rect2, items: Array, blink: bool) -> void:
	var cols := 3
	var w := (r.size.x - 4.0 * (cols - 1)) / cols
	var h := (r.size.y - 3.0) * 0.5
	for i in mini(items.size(), 6):
		var a: Array = items[i]
		var cell := Rect2(r.position.x + (i % cols) * (w + 4.0), r.position.y + (i / cols) * (h + 3.0), w, h)
		var on := false
		var col := AV.GREEN
		var flash := false
		if typeof(a[1]) == TYPE_INT:
			on = a[1] > 0
			col = AV.RED if a[1] == 2 else AV.AMBER
			flash = a[1] == 2 and blink
		elif typeof(a[1]) == TYPE_COLOR:
			on = true
			col = a[1]
		g.capsule(cell, a[0], on, col, flash)


static func _wrap(g, s: String, px: float, width: float) -> Array:
	var out := []
	var line := ""
	for word in s.split(" "):
		var trial := word if line == "" else line + " " + word
		if g.text_width(trial, px) > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


static func clock(sim) -> Array:
	var s = sim.state
	var ts := int(s.time_scale)
	return ["UTC " + s.date_string().substr(11, 8), ("PAUSED" if s.paused else "×%d" % ts), AV.AMBER if s.paused else (AV.CYAN if ts > 1 else AV.GREY), UI.money(s.credits)]


# --- Flat layout ------------------------------------------------------------------------

## Without a flight deck (chase camera): the same displays as a telemetry strip along
## the bottom of the screen. Returns {quads, canvas, top}.
static func flat_layout(view_size: Vector2) -> Dictionary:
	var w := view_size.x
	var h := view_size.y
	var mfd_h := 168.0
	var ann_h := 44.0
	var gap := 10.0
	var top := h - mfd_h - ann_h - gap * 3.0
	var quads := {}
	var canvas := {}
	var inner := w - gap * 2.0
	var ws := PackedFloat32Array([inner * 0.3, inner * 0.34, inner * 0.3])
	var spare := inner - ws[0] - ws[1] - ws[2]
	var x := gap
	var names := ["left", "centre", "right"]
	for i in 3:
		var r := Rect2(x, h - gap - mfd_h, ws[i], mfd_h)
		quads[names[i]] = _rect_quad(r)
		canvas[names[i]] = Vector2(160.0 * r.size.x / r.size.y, 160.0)
		x += ws[i] + spare * 0.5
	var ar := Rect2(gap, top + gap, inner, ann_h)
	quads["annunciator"] = _rect_quad(ar)
	canvas["annunciator"] = Vector2(50.0 * ar.size.x / ar.size.y, 50.0)
	return {"quads": quads, "canvas": canvas, "top": top}


static func _rect_quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
