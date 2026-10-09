## Instrument-panel look shared by every screen: dark painted metal, warm off-white
## stencil text, amber highlights, monospace readouts. Workmanlike, not glossy.
extends RefCounted

const BG := Color("15181b")
const PANEL := Color("1f2327")
const PANEL_EDGE := Color("454b52")
const TEXT := Color("e6dcc4")
const DIM := Color("8f8a7e")
const AMBER := Color("f0a030")
const GOOD := Color("7cc96f")
const WARN := Color("e0563f")
const HAZARD := Color("d8b02a")


static func make_theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])
	theme.default_font = font
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", AMBER)
	theme.set_color("font_pressed_color", "Button", BG)
	theme.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	theme.set_stylebox("normal", "Button", box(Color("2a2f34"), PANEL_EDGE, 1, 6))
	theme.set_stylebox("hover", "Button", box(Color("343a40"), AMBER, 1, 6))
	theme.set_stylebox("pressed", "Button", box(AMBER, AMBER, 1, 6))
	theme.set_stylebox("disabled", "Button", box(Color("202428"), Color("33373b"), 1, 6))
	theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), AMBER, 1, 6))
	theme.set_stylebox("panel", "PanelContainer", box(PANEL, PANEL_EDGE, 1, 10))
	theme.set_stylebox("panel", "TabContainer", box(PANEL, PANEL_EDGE, 1, 8))
	theme.set_color("font_selected_color", "TabContainer", AMBER)
	theme.set_color("font_unselected_color", "TabContainer", DIM)
	theme.set_stylebox("tab_selected", "TabContainer", box(PANEL, AMBER, 1, 6))
	theme.set_stylebox("tab_unselected", "TabContainer", box(BG, PANEL_EDGE, 1, 6))
	theme.set_stylebox("tab_hovered", "TabContainer", box(PANEL, PANEL_EDGE, 1, 6))
	return theme


static func box(fill: Color, edge: Color, width: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_content_margin_all(pad)
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	return s


static func label(text: String, colour: Color = TEXT, size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


static func button(text: String, on_press: Callable, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	return b


## Colour a button for what it does: text and edge in `colour`, the face a shade of it
## (a sale at a profit green, at a loss red).
static func tint_button(b: Button, colour: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(state, colour.lightened(0.15) if state == "font_hover_color" else colour)
	b.add_theme_stylebox_override("normal", box(Color("2a2f34").lerp(colour, 0.18), colour, 1, 6))
	b.add_theme_stylebox_override("hover", box(Color("343a40").lerp(colour, 0.28), colour.lightened(0.15), 1, 6))


static func panel(title: String) -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	if title != "":
		v.add_child(label(title.to_upper(), AMBER, 13))
		var rule := ColorRect.new()
		rule.color = HAZARD
		rule.custom_minimum_size = Vector2(0, 2)
		v.add_child(rule)
	return [p, v]


static func money(credits: float) -> String:
	var n := int(round(credits))
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out + " cr"


static func duration(seconds: float) -> String:
	if seconds < 3600.0:
		return "%d min" % int(seconds / 60.0)
	if seconds < 2.0 * 86400.0:
		return "%.1f h" % (seconds / 3600.0)
	return "%.1f d" % (seconds / 86400.0)


## One line on who can see the ship in transit (state.detection): running dark or
## not, how far it shows and on what, and the ports that see it now.
static func signature(sim) -> String:
	var det: Dictionary = sim.state.detection
	if det.is_empty():
		return ""
	var seen: Array = det.get("seen_by", [])
	var names := []
	for p in seen.slice(0, 3):
		names.append(sim.data.places[p]["name"])
	var who := "no port sees us" if seen.is_empty() else "seen by " + ", ".join(names) + (" +%d" % (seen.size() - 3) if seen.size() > 3 else "")
	var mode := "RUNNING DARK" if det.get("dark", false) else "Transponder on"
	if sim.state.ship.get("stowed", false):
		mode += ", panels in"
	var line := "%s  ·  shows %s on %s  ·  %s" % [mode, km(float(det.get("range_m", 0.0))), det.get("loudest", ""), who]
	if not bool(sim.state.location.get("filed", true)):
		line += "  ·  no plan filed"
	# Secret work aboard: how close they are to putting it together.
	var worst := 0.0
	for job in sim.state.contracts.get("active", []):
		if job.get("covert", false) and job["state"] == "carried":
			worst = maxf(worst, float(job.get("suspicion_s", 0.0)) / float(sim.data.contracts["covert"]["suspicion_s"]))
	if worst > 0.0:
		line += "  ·  suspicion %d%%" % int(worst * 100.0)
	return line


static func km(metres: float) -> String:
	return "%s km" % money(metres / 1000.0).trim_suffix(" cr")
