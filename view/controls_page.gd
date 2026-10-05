## The controls page (F1 anywhere): every key, by what you are doing, from
## data/controls.json. Read-only for now; remapping comes later.
extends CanvasLayer

const UI := preload("res://view/ui/ui_kit.gd")

var data


signal closed

## Whether the game was paused before the page opened, to put it back after.
var was_paused := false


func _init(catalog) -> void:
	data = catalog
	layer = 50


## F1 or Esc closes the page; other keys go nowhere while it is up.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode in [KEY_F1, KEY_ESCAPE]:
		closed.emit()
		queue_free()


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 48 if side in ["left", "right"] else 36)
	add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	root.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	head.custom_minimum_size = Vector2(0, 36)
	var title := UI.label("CONTROLS", UI.AMBER, 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.label("F1 or Esc to close", UI.DIM, 14))
	column.add_child(UI.label("Keyboard for now. Remapping, gamepads and other control schemes are on the way.", UI.DIM, 13))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)
	for section in data.controls.get("sections", []):
		var p := UI.panel(String(section["name"]).to_upper())
		p[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if String(section.get("when", "")) != "":
			p[1].add_child(UI.label(String(section["when"]), UI.DIM, 12))
		var rows := GridContainer.new()
		rows.columns = 2
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("h_separation", 14)
		for row in section["keys"]:
			var key := UI.label(String(row[0]), UI.AMBER, 14)
			key.custom_minimum_size = Vector2(130, 0)
			key.autowrap_mode = TextServer.AUTOWRAP_WORD
			rows.add_child(key)
			var what := UI.label(String(row[1]), UI.TEXT, 14)
			what.autowrap_mode = TextServer.AUTOWRAP_WORD
			what.custom_minimum_size = Vector2(200, 0)
			what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_child(what)
		p[1].add_child(rows)
		grid.add_child(p[0])
