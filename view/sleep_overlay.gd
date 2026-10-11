## Asleep in the hibernation pod (sim/systems/sleep_system.gd): the cabin dark, the
## calendar running, and the ship's mind keeping a log as the ship passes the planets'
## distances from the Sun (balance.sleep.milestones). "Wake now" ends it early.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const Navigation := preload("res://sim/navigation.gd")
const V := preload("res://sim/v3.gd")

const AU := 1.495978707e11
const KEEP_LINES := 7

var sim
var _font: Font
## The ship's log: [text, game time].
var _log: Array = []
var _last_au := -1.0
var _last_year := 0


func _init(owner_sim) -> void:
	sim = owner_sim
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_font = UI.make_theme().default_font
	var where := _where()
	_log.append(["Pod sealed. I have the ship%s. Sleep well." % (", and the long way to %s" % where if where != "" else ""), float(sim.state.sleep.get("start_t", sim.state.time_s))])
	var wake := UI.button("Wake now", func(): sim.apply({"type": "wake"}))
	wake.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	wake.position = Vector2(-70, -90)
	wake.custom_minimum_size = Vector2(140, 0)
	add_child(wake)


func _where() -> String:
	var loc: Dictionary = sim.state.location
	if loc.get("status") == "transit":
		return sim.data.locations[loc["to"]]["name"]
	return ""


func _process(_dt: float) -> void:
	var s = sim.state
	if not bool(s.sleep.get("active", false)):
		return
	# Milestones: crossing a planet's distance from the Sun, either way.
	var au := _sun_distance_au()
	if au > 0.0:
		if _last_au > 0.0:
			for m in sim.data.balance["sleep"]["milestones"]:
				var r := float(m["au"])
				if (_last_au < r) != (au < r):
					_log.append([String(m["text"]), s.time_s])
		_last_au = au
	var years: int = int((s.time_s - float(s.sleep["start_t"])) / (365.25 * 86400.0))
	if years > _last_year:
		_last_year = years
		_log.append(["%s asleep. All well aboard. The system has moved on a little without you." % ("A year" if years == 1 else "%d years" % years), s.time_s])
	while _log.size() > KEEP_LINES:
		_log.pop_front()
	queue_redraw()


func _sun_distance_au() -> float:
	var loc: Dictionary = sim.state.location
	if loc.get("status") != "transit" or loc.get("frame", "") == "":
		return -1.0
	var t: float = sim.state.time_s
	var eph = sim.ephemeris
	var here: Array = V.add(eph.position(loc["frame"], t), Navigation.transit_position(loc, t))
	return V.distance(here, eph.position("sun", t)) / AU


func _draw() -> void:
	var s = sim.state
	if not bool(s.sleep.get("active", false)):
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.035, 0.97))
	var start := float(s.sleep["start_t"])
	var until := float(s.sleep["until_t"])
	var f: float = clampf((s.time_s - start) / maxf(until - start, 1.0), 0.0, 1.0)
	# A slow breathing glow, the pod's own light.
	var breath := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 0.9)
	draw_circle(Vector2(w * 0.5, h * 0.42), 220.0, Color(0.25, 0.45, 0.6, 0.04 + 0.03 * breath))
	_centre("A S L E E P", h * 0.2, 18, UI.AMBER)
	_centre(s.date_string().replace("T", "  ").substr(0, 17) + " UTC", h * 0.3, 40, UI.TEXT)
	var slept_days: float = (s.time_s - start) / 86400.0
	var left_days: float = maxf(0.0, until - s.time_s) / 86400.0
	var where := _where()
	var line := "Day %d of sleep  ·  waking in %s" % [int(slept_days), _days(left_days)]
	if where != "":
		line += ", a few hours out from %s" % where
	_centre(line, h * 0.3 + 40, 15, UI.DIM)
	var bar := Rect2(w * 0.5 - 260, h * 0.3 + 62, 520, 4)
	draw_rect(bar, Color(UI.DIM, 0.3))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), UI.AMBER)
	var y := h * 0.52
	for i in _log.size():
		var entry: Array = _log[i]
		var age := float(_log.size() - 1 - i)
		var colour := Color(UI.TEXT, clampf(1.0 - age * 0.13, 0.25, 1.0))
		var stamp := Time.get_datetime_string_from_unix_time(int(float(entry[1]) + 946728000.0)).substr(0, 10)
		_centre("%s   %s" % [stamp, entry[0]], y, 14, colour)
		y += 26
	var total: float = float(s.sleep.get("total_s", 0.0)) + (s.time_s - start)
	_centre("Asleep all told: %s" % _days(total / 86400.0), h - 120, 12, Color(UI.DIM, 0.8))


func _centre(text: String, y: float, font_size: int, colour: Color) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, Vector2((size.x - tw) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)


static func _days(d: float) -> String:
	if d >= 355.0:
		var years := d / 365.25
		return "a year" if absf(years - 1.0) < 0.05 else "%.1f years" % years
	if d >= 60.0:
		return "%d months" % int(d / 30.44)
	if d >= 2.0:
		return "%d days" % int(d)
	return "%d hours" % int(d * 24.0)
