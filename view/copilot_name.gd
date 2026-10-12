## The first time the co-pilot speaks up, it asks what you'd like to call it. The name
## is used in every line it says after (story_system.gd name_copilot).
extends Control

const UI := preload("res://view/ui/ui_kit.gd")

signal closed

var sim
var _field: LineEdit


func _init(owner_sim) -> void:
	sim = owner_sim
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	theme = UI.make_theme()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.035, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var p := UI.panel("Co-pilot")
	p[0].custom_minimum_size = Vector2(560, 0)
	centre.add_child(p[0])
	var v: VBoxContainer = p[1]
	var line := UI.label("'Before we go any further: most pilots call me Co-pilot. You can do better. What would you like to call me?'", UI.TEXT, 15)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(line)
	_field = LineEdit.new()
	_field.placeholder_text = "Co-pilot"
	_field.max_length = 24
	_field.text_submitted.connect(func(_t): _done())
	v.add_child(_field)
	var row := HBoxContainer.new()
	var ok := UI.button("That's your name", _done)
	UI.tint_button(ok, UI.AMBER)
	row.add_child(ok)
	row.add_child(UI.button("Co-pilot is fine", func():
		_field.text = ""
		_done()))
	v.add_child(row)
	_field.grab_focus.call_deferred()


func _done() -> void:
	sim.apply({"type": "name_copilot", "name": _field.text})
	closed.emit()
	queue_free()
