## Title lettering, the hero ship's caption plate and the start prompts.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const Bindings := preload("res://view/bindings.gd")

var title
var _font: Font


func _init(owner_title) -> void:
	title = owner_title
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UI.make_theme().default_font


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var t := Time.get_ticks_msec() / 1000.0
	# Title, letter-spaced like a stencil on a hull plate.
	var name := "S  P  I  N  W  A  R  D"
	var title_size := 64
	var tw := _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(_font, Vector2((w - tw) * 0.5 + 3, 98 + 3), name, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(0, 0, 0, 0.6))
	draw_string(_font, Vector2((w - tw) * 0.5, 98), name, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, UI.AMBER)
	var rule_w := tw + 40.0
	draw_rect(Rect2((w - rule_w) * 0.5, 116, rule_w, 4), UI.HAZARD)
	for i in int(rule_w / 20.0):
		var x := (w - rule_w) * 0.5 + i * 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 116), Vector2(x + 8, 116), Vector2(x + 4, 120), Vector2(x - 4, 120)]), UI.BG)
	var sub := "A trading life in our own backyard   ·   2061"
	var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(_font, Vector2((w - sw) * 0.5, 146), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.TEXT)

	# Caption plate for the ship on show.
	var info: Dictionary = title.hero_info()
	if info["showing"]:
		var plate := Rect2(w * 0.5 - 330, h - 210, 660, 104)
		var where: String = info.get("where", "")
		if where != "":
			draw_string(_font, plate.position + Vector2(4, -10), where.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.TEXT, 0.85))
		draw_rect(plate, Color(0.08, 0.09, 0.1, 0.82))
		draw_rect(Rect2(plate.position, Vector2(plate.size.x, 3)), UI.HAZARD)
		draw_string(_font, plate.position + Vector2(18, 30), String(info["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.AMBER)
		var desc: String = info["description"]
		var lines := _wrap(desc, 640.0 - 36.0, 13)
		for i in mini(lines.size(), 2):
			draw_string(_font, plate.position + Vector2(18, 52 + i * 17), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
		var stats := "CARGO %d t    TANK %d t    THRUST %d N    DRY MASS %.1f t" % [int(info["cargo_t"]), int(info["fuel_t"]), int(info["thrust_n"]), info["mass_t"]]
		draw_string(_font, plate.position + Vector2(18, 94), stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.TEXT)

	# Prompts.
	var blink := fposmod(t, 1.4) < 0.95
	var prompt := "PRESS %s TO BEGIN" % Bindings.hint_of("title_start").to_upper()
	var pw := _font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	if blink:
		draw_string(_font, Vector2((w - pw) * 0.5, h - 64), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.GOOD)
	var keys := ("%s  load quick save      " % Bindings.hint_of("title_load") if title.has_save else "") + "%s  controls      %s  quit" % [Bindings.hint_of("controls_page"), Bindings.hint_of("title_quit")]
	var kw := _font.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_font, Vector2((w - kw) * 0.5, h - 38), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	draw_string(_font, Vector2(16, h - 14), "Real orbits from JPL data  ·  in the spirit of Elite (1984)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UI.DIM, 0.7))


func _wrap(text: String, width: float, font_size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
