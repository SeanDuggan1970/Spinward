## The controls page (F1 anywhere): every control by what you are doing, from
## data/controls.json through the bindings (view/bindings.gd). Pick a keyboard or gamepad
## cell, press the new key or button, and it is rebound and saved. Mouse, d-pad and A all work.
extends CanvasLayer

const UI := preload("res://view/ui/ui_kit.gd")

## Ignore stick and trigger movement for this long after a cell is picked, so the push that
## moved the highlight to it does not bind itself.
const CAPTURE_GRACE_MS := 350

var bindings
## Where changes are saved; a test points it somewhere else.
var settings_path := ""

signal closed

## Whether the game was paused before the page opened, to put it back after.
var was_paused := false

var _cells := {}
var _status: Label
var _reset: Button
var _reset_armed := false
## The action being rebound, and which cell (key or pad) was picked, while waiting for a press.
var _capturing := ""
var _capture_kind := ""
var _capture_from := 0


func _init(binding_store) -> void:
	bindings = binding_store
	settings_path = binding_store.SETTINGS
	layer = 50


## While a cell waits for a press this sees every event first, before the focus-moving keys
## of the menu would, so arrows and Enter can be bound like anything else.
func _input(event: InputEvent) -> void:
	if _capturing == "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_end_capture("Cancelled.", UI.DIM)
		get_viewport().set_input_as_handled()
		return
	var spec: String = bindings.spec_of(event)
	if spec == "":
		return
	if event is InputEventJoypadMotion and Time.get_ticks_msec() - _capture_from < CAPTURE_GRACE_MS:
		return
	get_viewport().set_input_as_handled()
	if spec in ["key:Escape", "pad:back"]:
		_end_capture("Cancelled.", UI.DIM)
	elif spec in ["key:Backspace", "key:Delete"]:
		var id := _capturing
		bindings.clear(id, _capture_kind)
		_changed(id, "%s: %s cleared." % [bindings.actions[id]["label"], "keyboard" if _capture_kind == "key" else "gamepad"], UI.AMBER)
	else:
		var id := _capturing
		var result: Dictionary = bindings.rebind(id, spec)
		if result["ok"]:
			_changed(id, result["message"], UI.GOOD, result["swapped"])
		else:
			_end_capture(result["message"], UI.WARN)


## Closes with F1 (or whatever it is rebound to), Esc, or B on a pad; other keys and
## buttons go nowhere while it is up.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("controls_page") or event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.keycode in [KEY_F1, KEY_ESCAPE]):
		closed.emit()
		queue_free()


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.04, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	for side in ["left", "right", "top", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 48 if side in ["left", "right"] else 36)
	add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	head.custom_minimum_size = Vector2(0, 36)
	var title := UI.label("CONTROLS", UI.AMBER, 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.label("F1, Esc or B to close", UI.DIM, 14))
	# Wrapped: a line this long would otherwise set the page's width and push the second
	# column off the screen.
	var how := UI.label("Pick a key or gamepad cell (click it, or move with the d-pad and press A), then press the new key or button. Esc, right-click or Back cancels; Backspace clears. A control already in use on the same screen swaps places. Changes save at once.", UI.DIM, 13)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD
	how.custom_minimum_size = Vector2(200, 0)
	column.add_child(how)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var grid := GridContainer.new()
	# Two columns of sections where the window is wide enough for two (each needs about
	# 560 px: the label, two cells and the panel's edges), otherwise one.
	grid.columns = 2 if get_viewport().get_visible_rect().size.x >= 1240.0 else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var first: Button = null
	for section in bindings.sections:
		var p := UI.panel(String(section["name"]).to_upper())
		p[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p[0].size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if String(section.get("when", "")) != "":
			p[1].add_child(UI.label(String(section["when"]), UI.DIM, 12))
		var rows := GridContainer.new()
		rows.columns = 3
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("h_separation", 10)
		rows.add_theme_constant_override("v_separation", 4)
		rows.add_child(Control.new())
		rows.add_child(UI.label("KEYBOARD", UI.DIM, 11))
		rows.add_child(UI.label("GAMEPAD", UI.DIM, 11))
		for row in section["rows"]:
			var what := UI.label(String(row.get("label", "")), UI.TEXT, 14)
			what.autowrap_mode = TextServer.AUTOWRAP_WORD
			what.custom_minimum_size = Vector2(160, 0)
			what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rows.add_child(what)
			if not row.has("action"):
				var note := UI.label(String(row["text"]), UI.AMBER, 14)
				note.custom_minimum_size = Vector2(150, 0)
				rows.add_child(note)
				rows.add_child(Control.new())
				continue
			var id := String(row["action"])
			_cells[id] = {}
			for kind in ["key", "pad"]:
				var b := Button.new()
				b.custom_minimum_size = Vector2(150, 0)
				b.clip_text = true
				b.focus_mode = Control.FOCUS_ALL
				b.pressed.connect(_begin.bind(id, kind))
				rows.add_child(b)
				_cells[id][kind] = b
				if first == null:
					first = b
		p[1].add_child(rows)
		grid.add_child(p[0])
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	column.add_child(foot)
	_status = UI.label("", UI.DIM, 14)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	foot.add_child(_status)
	_reset = Button.new()
	_reset.focus_mode = Control.FOCUS_ALL
	_reset.pressed.connect(_on_reset)
	foot.add_child(_reset)
	var done := Button.new()
	done.text = "Close"
	done.focus_mode = Control.FOCUS_ALL
	done.pressed.connect(func():
		closed.emit()
		queue_free())
	foot.add_child(done)
	_refresh()
	if first != null:
		first.grab_focus.call_deferred()


func _refresh() -> void:
	for id in _cells:
		for kind in ["key", "pad"]:
			var b: Button = _cells[id][kind]
			var picked: bool = id == _capturing and kind == _capture_kind
			b.text = "press a %s…" % ("key" if kind == "key" else "button") if picked else bindings.text(id, kind)
			var colour := UI.AMBER if picked or bindings.is_changed(id) else (UI.DIM if bindings.specs(id, kind).is_empty() else UI.TEXT)
			b.add_theme_color_override("font_color", colour)
			b.add_theme_color_override("font_hover_color", UI.AMBER)
			b.add_theme_color_override("font_focus_color", UI.AMBER)
	_reset.text = "Press again to reset all" if _reset_armed else "Reset to defaults"
	_reset.disabled = not bindings.has_changes() and not _reset_armed


func _begin(id: String, kind: String) -> void:
	_capturing = id
	_capture_kind = kind
	_capture_from = Time.get_ticks_msec()
	_reset_armed = false
	_status.text = "%s: press a key or gamepad button.  Esc cancels, Backspace clears." % bindings.actions[id]["label"]
	_status.add_theme_color_override("font_color", UI.AMBER)
	_refresh()


func _end_capture(message: String, colour: Color) -> void:
	var cell: Button = _cells[_capturing][_capture_kind] if _cells.has(_capturing) else null
	_capturing = ""
	_status.text = message
	_status.add_theme_color_override("font_color", colour)
	_refresh()
	if cell != null:
		cell.grab_focus.call_deferred()


## A binding changed: put it in the InputMap now, save, and say what happened.
func _changed(_id: String, message: String, colour: Color, _swapped: Array = []) -> void:
	bindings.apply()
	if bindings.save(settings_path) != OK:
		message += "  (Could not save: changes last until you quit.)"
		colour = UI.WARN
	_end_capture(message, colour)


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_status.text = "This puts every key and gamepad button back as shipped."
		_status.add_theme_color_override("font_color", UI.WARN)
		_refresh()
		return
	_reset_armed = false
	bindings.reset_all()
	bindings.apply()
	_status.text = "All controls are back to their defaults." if bindings.save(settings_path) == OK else "Reset, but could not save."
	_status.add_theme_color_override("font_color", UI.GOOD)
	_refresh()
