## Awake again: what happened while you slept. How long, the money in and out, the
## Spaceline's headlines from the time you were under, and the messages that came in.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")

const MAX_HEADLINES := 14
const MAX_MESSAGES := 18

signal closed

var sim
var _woke: Dictionary
var _credits_before: float
## Notices that came in while asleep: [text, colour].
var _messages: Array


func _init(owner_sim, woke: Dictionary, credits_before: float, messages: Array) -> void:
	sim = owner_sim
	_woke = woke
	_credits_before = credits_before
	_messages = messages
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	theme = UI.make_theme()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.035, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var p := UI.panel("Awake")
	var box: Control = p[0]
	box.custom_minimum_size = Vector2(860, 0)
	centre.add_child(box)
	var v: VBoxContainer = p[1]
	var days := float(_woke["days"])
	var from := _date(float(_woke["from_t"]))
	var to := _date(float(_woke["to_t"]))
	v.add_child(UI.label("You slept %s. %s to %s." % [_span(days), from, to], UI.TEXT, 17))
	var money: float = sim.state.credits - _credits_before
	v.add_child(UI.label("Credits %s  →  %s  (%s%s while you slept)" % [UI.money(_credits_before), UI.money(sim.state.credits), "+" if money >= 0.0 else "-", UI.money(absf(money))], UI.GOOD if money >= 0.0 else UI.AMBER, 14))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var heads: Array = sim.state.news.get("items", []).filter(func(i): return float(i.get("t", 0.0)) >= float(_woke["from_t"]) and float(i.get("t", 0.0)) <= float(_woke["to_t"]))
	list.add_child(UI.label("THE SPACELINE, WHILE YOU SLEPT", UI.AMBER, 13))
	if heads.is_empty():
		list.add_child(UI.label("Quiet news days. Nothing you missed.", UI.DIM, 13))
	for item in heads.slice(maxi(0, heads.size() - MAX_HEADLINES)):
		var l := UI.label("%s   %s" % [_date(float(item["t"])), item.get("headline", "")], UI.TEXT, 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(l)
	if not _messages.is_empty():
		list.add_child(UI.label(" ", UI.DIM, 6))
		list.add_child(UI.label("MESSAGES AND LOG", UI.AMBER, 13))
		var seen := {}
		var shown := 0
		for i in range(_messages.size() - 1, -1, -1):
			var text: String = _messages[i][0]
			if seen.has(text):
				continue
			seen[text] = true
			var l := UI.label(text, _messages[i][1], 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			list.add_child(l)
			shown += 1
			if shown >= MAX_MESSAGES:
				break
	var back := UI.button("Back to work", func():
		closed.emit()
		queue_free())
	UI.tint_button(back, UI.AMBER)
	v.add_child(back)


func _date(t: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(t + 946728000.0)).substr(0, 10)


static func _span(days: float) -> String:
	if days >= 355.0:
		var years := days / 365.25
		return "a year" if absf(years - 1.0) < 0.05 else "%.1f years" % years
	if days >= 60.0:
		return "%d months" % int(days / 30.44)
	return "%d days" % int(round(days))
