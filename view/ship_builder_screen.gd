## The ship builder (from the Shipyard tab): plan a refit on screen before paying for it.
##
## Left: the ship in 3D, rebuilt as the plan changes and turning slowly (drag to turn
## it), and below it how she flies now against how she would after.
## Middle: the slots. Pick one to see what this yard has for it.
## Right: the options for that slot, each with what it changes, then the bill: every
## part, its trade-in by condition, the fitting labour, any service or inspection done
## in the same visit, the days in port, what it does to the Warrant of Fitness and the
## insurance, the total and what you'd have left. "Put it together" makes it so.
##
## Prices come from ShipyardSystem.quote over ShipBill.quote: the same bill the refit
## command charges.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const ShipyardSystem := preload("res://sim/systems/shipyard_system.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const Condition := preload("res://sim/condition.gd")
const Favours := preload("res://sim/favours.gd")

## Order and names of the slot kinds, nose to tail.
const KINDS := [["command", "Crew"], ["cargo", "Bays"], ["tank", "Tanks"], ["drive", "Drive"], ["radiator", "Radiators"]]

signal closed

var sim
## Proposed changes: {slot: module_id}.
var plan := {}
## Yard work in the same visit: {service_all: "service" | "overhaul", inspect: true}.
var extra := {}
var selected := ""
var _slots_box: VBoxContainer
var _options_box: VBoxContainer
var _bill_box: VBoxContainer
var _stats_box: GridContainer
var _status: Label
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model_node: Node3D
var _yaw := 0.6
var _pitch := 0.32
var _dragging := false
var _distance := 40.0


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.04, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		# Clear of the status bar along the top of the screen.
		root.add_theme_constant_override("margin_" + side, 50 if side == "top" else 24)
	add_child(root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)
	# Header.
	var head := HBoxContainer.new()
	var place: Dictionary = sim.data.places[sim.state.location["place"]]
	var title := UI.label("SHIPYARD  ·  %s" % String(place["name"]).to_upper(), UI.AMBER, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.label(String(sim.state.ship.get("name", "")).to_upper() + "  ·  " + String(sim.data.ships[sim.state.ship["hull"]]["name"]), UI.DIM, 14))
	var close := UI.button("Close", _close)
	head.add_child(close)
	column.add_child(head)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	# Left: the ship and how she flies.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_stretch_ratio = 1.4
	view.custom_minimum_size = Vector2(320, 220)
	view.gui_input.connect(_on_view_input)
	left.add_child(view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	view.add_child(_viewport)
	_build_stage()
	var stats_panel := UI.panel("How she flies")
	stats_panel[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_box = GridContainer.new()
	_stats_box.columns = 4
	_stats_box.add_theme_constant_override("h_separation", 14)
	stats_panel[1].add_child(_stats_box)
	left.add_child(stats_panel[0])
	# Middle: the slots.
	var mid_panel := UI.panel("Slots")
	mid_panel[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_panel[0].size_flags_stretch_ratio = 0.8
	var mid_scroll := ScrollContainer.new()
	mid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slots_box = VBoxContainer.new()
	_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_box.add_theme_constant_override("separation", 6)
	mid_scroll.add_child(_slots_box)
	mid_panel[1].add_child(mid_scroll)
	mid_panel[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(mid_panel[0])
	# Right: options, then the bill.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var opt_panel := UI.panel("This yard has")
	opt_panel[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	var opt_scroll := ScrollContainer.new()
	opt_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_box = VBoxContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("separation", 6)
	opt_scroll.add_child(_options_box)
	opt_panel[1].add_child(opt_scroll)
	opt_panel[1].size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(opt_panel[0])
	var bill_panel := UI.panel("The bill")
	_bill_box = VBoxContainer.new()
	_bill_box.add_theme_constant_override("separation", 4)
	bill_panel[1].add_child(_bill_box)
	right.add_child(bill_panel[0])
	_status = UI.label("", UI.DIM, 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(200, 0)
	column.add_child(_status)
	var slots := _all_slots()
	selected = slots[0] if not slots.is_empty() else ""
	_refresh()


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


# --- the 3D stage ------------------------------------------------------------------

func _build_stage() -> void:
	_viewport.add_child(SkyKit.environment())
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.6, -0.5, -0.6), Vector3.UP)
	_viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.25
	fill.light_color = Color("9fb4ff")
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.7, 0.3, 0.5), Vector3.UP)
	_viewport.add_child(fill)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.near = 0.1
	_camera.far = 5000.0
	_viewport.add_child(_camera)
	_camera.make_current()


func _show_ship(ship: Dictionary) -> void:
	if _model_node != null:
		_model_node.queue_free()
	var model := Models.ship(ship, sim.data, Livery.for_ship(sim.data, "", String(ship.get("name", "")), true))
	_model_node = model["node"]
	var plume := _model_node.find_child("DrivePlume", true, false)
	if plume:
		plume.visible = false
	var sun_dir := Vector3(0.6, 0.5, 0.6).normalized()
	_model_node.basis = ShipRig.roll_to_sun(Vector3.FORWARD, sun_dir)
	ShipRig.aim(model["rig"], _model_node.basis, sun_dir, Vector3(0.5, 0.4, -1.0), -1.0)
	_pivot.add_child(_model_node)
	_distance = maxf(float(model["length"]) * 1.25, float(model["radius"]) * 2.4) + 6.0


func _process(dt: float) -> void:
	if not _dragging:
		_yaw += dt * 0.12
	if _camera:
		var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
		_camera.look_at_from_position(dir * _distance, Vector3.ZERO, Vector3.UP)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.006, -1.2, 1.2)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_distance *= 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1


# --- slots, options, bill --------------------------------------------------------------

func _all_slots() -> Array:
	var out := []
	for k in KINDS:
		for slot in ShipyardSystem.slot_names(sim.state, sim.data, k[0]):
			if sim.state.ship["modules"].has(slot):
				out.append(slot)
	return out


func _slot_title(slot: String) -> String:
	var kind: String = slot.split(".")[0]
	var name := kind
	for k in KINDS:
		if k[0] == kind:
			name = k[1]
	var count := ShipyardSystem.slot_count(sim.state, sim.data, kind)
	return name.to_upper() + ("" if count <= 1 else " %d" % (int(slot.split(".")[1]) + 1))


func _refresh() -> void:
	var q := ShipyardSystem.quote(sim.state, sim.data, plan, extra)
	_show_ship(q["trial"])
	_fill_stats(sim.state.ship, q["trial"])
	_fill_slots(q)
	_fill_options()
	_fill_bill(q)


func _fill_slots(q: Dictionary) -> void:
	for c in _slots_box.get_children():
		c.queue_free()
	var d = sim.data
	var last_kind := ""
	for slot in _all_slots():
		var kind: String = slot.split(".")[0]
		if kind != last_kind and last_kind != "":
			_slots_box.add_child(HSeparator.new())
		last_kind = kind
		var fitted: String = sim.state.ship["modules"][slot]
		var planned: String = plan.get(slot, fitted)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\n%s" % [_slot_title(slot), d.modules[planned]["name"]]
		var cond := Condition.condition(sim.state.ship, slot)
		if planned != fitted:
			b.text += "\n  replacing %s" % d.modules[fitted]["name"]
			UI.tint_button(b, UI.AMBER)
		else:
			var fault := Condition.fault_loss(sim.state.ship, slot) > 0.0
			b.text += "\n  condition %d%%%s" % [int(round(cond * 100.0)), ", fault" if fault else ""]
			if cond < 0.4 or fault:
				UI.tint_button(b, UI.WARN)
		for t in _tunes_on(slot):
			b.text += "\n  tune: %s" % Favours.tune_name(d, t["id"])
		if slot == selected:
			b.add_theme_stylebox_override("normal", UI.box(Color("343a40"), UI.AMBER, 2, 6))
		b.pressed.connect(func():
			selected = slot
			_refresh())
		_slots_box.add_child(b)


func _fill_options() -> void:
	for c in _options_box.get_children():
		c.queue_free()
	if selected == "":
		return
	var d = sim.data
	var fitted: String = sim.state.ship["modules"][selected]
	var planned: String = plan.get(selected, fitted)
	var stock: Array = ShipyardSystem.yard_stock(sim.state, d)
	var choices := [fitted]
	for m in stock:
		if m != fitted and ShipyardSystem.fits(d.modules[m], selected):
			choices.append(m)
	_options_box.add_child(UI.label("For %s:" % _slot_title(selected).to_lower(), UI.DIM, 13))
	for m in choices:
		var module: Dictionary = d.modules[m]
		# What the ship would be with this in the slot (and the rest of the plan).
		var option_plan := plan.duplicate()
		if m == fitted:
			option_plan.erase(selected)
		else:
			option_plan[selected] = m
		var q := ShipyardSystem.quote(sim.state, d, option_plan)
		var line := {}
		for l in q["lines"]:
			if l["slot"] == selected:
				line = l
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size = Vector2(240, 0)
		var price := "fitted now (condition %d%%)" % int(round(Condition.condition(sim.state.ship, selected) * 100.0))
		if m != fitted:
			price = "%s + %s fitting, less %s trade-in: %s" % [UI.money(float(line.get("part", 0.0))), UI.money(float(line.get("labour", 0.0))), UI.money(float(line.get("trade_in", 0.0))), UI.money(float(line.get("net", 0.0)))]
		b.text = "%s\n%s\n%s" % [module["name"], _module_summary(module), price]
		if m != fitted:
			for t in _tunes_on(selected):
				b.text += "\nloses the tune: %s" % Favours.tune_name(d, t["id"])
		var changes := _deltas(_trial_without(selected), q["trial"])
		if changes != "":
			b.text += "\n" + changes
		if m == planned:
			b.add_theme_stylebox_override("normal", UI.box(Color("343a40"), UI.AMBER, 2, 6))
		if line.get("why", "") != "":
			b.disabled = true
			b.text += "\n" + String(line["why"])
		b.pressed.connect(func():
			if m == fitted:
				plan.erase(selected)
			else:
				plan[selected] = m
			_refresh())
		_options_box.add_child(b)


## The plan's trial ship with this slot left as fitted, to measure one option against.
func _trial_without(slot: String) -> Dictionary:
	var rest := plan.duplicate()
	rest.erase(slot)
	return ShipyardSystem.quote(sim.state, sim.data, rest)["trial"]


## The engine tunes on this slot's fitted module (a tune is lost if the module goes).
func _tunes_on(slot: String) -> Array:
	return ShipStats.active_tunes(sim.state.ship, sim.data).filter(func(t): return t["slot"] == slot)


func _bill_row(text: String, credits: float, colour: Color = UI.TEXT, size: int = 13) -> void:
	var row := HBoxContainer.new()
	var what := UI.label(text, colour, size)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	what.clip_text = true
	row.add_child(what)
	row.add_child(UI.label(("-" if credits < 0.0 else "") + UI.money(absf(credits)), UI.GOOD if credits < 0.0 else colour, size))
	_bill_box.add_child(row)


func _fill_bill(q: Dictionary) -> void:
	for c in _bill_box.get_children():
		c.queue_free()
	var d = sim.data
	var bill: Dictionary = q["bill"]
	if q["lines"].is_empty() and extra.is_empty():
		_bill_box.add_child(UI.label("Nothing planned yet. Pick a slot, then something to put in it, or have her serviced below.", UI.DIM, 13))
	for l in q["lines"]:
		_bill_row("%s: %s" % [_slot_title(l["slot"]), d.modules[l["module"]]["name"]], float(l["part"]))
		if l["why"] != "":
			_bill_box.add_child(UI.label("    " + String(l["why"]), UI.WARN, 12))
			continue
		if float(l["labour"]) > 0.0:
			_bill_row("    fitting labour", float(l["labour"]), UI.DIM, 12)
		if float(l["trade_in"]) > 0.0:
			_bill_row("    trade-in: %s, condition %d%%" % [d.modules[l["replaced"]]["name"], int(round(Condition.condition(sim.state.ship, l["slot"]) * 100.0))], -float(l["trade_in"]), UI.DIM, 12)
	# Yard work in the same visit, as the bill itemises it.
	for b in bill["lines"]:
		var kind := String(b["kind"])
		if kind == "inspection":
			_bill_row(String(b["label"]), float(b["credits"]), UI.TEXT, 12)
		elif kind in ["service", "overhaul"]:
			# "Service: drive, 70% to 92%", short enough for the column.
			var parts := String(b["label"]).split(", condition ")
			_bill_row("%s: %s%s" % [kind.capitalize(), _slot_title(String(b["slot"])).to_lower(), (", " + parts[1]) if parts.size() > 1 else ""], float(b["credits"]), UI.TEXT, 12)
		elif kind == "voucher":
			# A client's repair voucher paying towards the service and overhaul.
			_bill_row("    repair voucher, %s yards" % String(Favours.operator_of(d, String(q["bill"]["place"]))), float(b["credits"]), UI.DIM, 12)
	var total: float = q["total"]
	var sep := ColorRect.new()
	sep.color = UI.PANEL_EDGE
	sep.custom_minimum_size = Vector2(0, 1)
	_bill_box.add_child(sep)
	_bill_row("TOTAL" if total >= 0.0 else "TOTAL (they pay you)", absf(total), UI.AMBER, 15)
	var left := float(sim.state.credits) - total
	var after := HBoxContainer.new()
	var al := UI.label("You'd have", UI.DIM, 13)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	after.add_child(al)
	after.add_child(UI.label(UI.money(left), UI.GOOD if left >= 0.0 else UI.WARN, 13))
	_bill_box.add_child(after)
	if left < -0.5 and (not q["lines"].is_empty() or not extra.is_empty()):
		_bill_box.add_child(UI.label("You are %s short: sell cargo, or plan less." % UI.money(-left), UI.WARN, 12))
	if float(bill["days"]) > 0.0 and (not q["lines"].is_empty() or not extra.is_empty()):
		_bill_box.add_child(UI.label("In the yard for %.1f days: the clock runs while she's in." % float(bill["days"]), UI.DIM, 12))
	# What it does to the warrant and the cover.
	var wof: Dictionary = bill["wof"]
	if bool(wof["voided_by_refit"]):
		_bill_box.add_child(UI.label("This refit voids the Warrant of Fitness until she is inspected: tick the inspection below.", UI.WARN, 12))
	elif bool(extra.get("inspect", false)):
		_bill_box.add_child(UI.label("Inspection: %s" % ("she would pass" if bool(wof["would_pass"]) else "she would fail (" + "; ".join(wof["issues"]) + ")"), UI.GOOD if bool(wof["would_pass"]) else UI.WARN, 12))
	var ins: Dictionary = bill["insurance"]
	if String(ins["plan"]) != "" and absf(float(ins["premium_after"]) - float(ins["premium_before"])) > 0.5:
		_bill_box.add_child(UI.label("Insurance premium %s to %s a period." % [UI.money(float(ins["premium_before"])), UI.money(float(ins["premium_after"]))], UI.AMBER, 12))
	if bool(ins["void_after"]) and String(ins["state_before"]) != "void":
		_bill_box.add_child(UI.label("Your insurance would be void until the warrant is renewed.", UI.WARN, 12))
	for p in q["problems"]:
		_bill_box.add_child(UI.label(String(p), UI.WARN, 12))
	# While she's in: service everything, and an inspection. Two short rows, so the
	# column keeps its width.
	var work := HBoxContainer.new()
	work.add_theme_constant_override("separation", 6)
	var wl := UI.label("While she's in, service:", UI.DIM, 12)
	wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_child(wl)
	for level in ["", "service", "overhaul"]:
		var label := "None" if level == "" else ("All" if level == "service" else "Overhaul")
		var lb := UI.button(label, func():
			if level == "":
				extra.erase("service_all")
			else:
				extra["service_all"] = level
			_refresh())
		if String(extra.get("service_all", "")) == level:
			UI.tint_button(lb, UI.AMBER)
		work.add_child(lb)
	_bill_box.add_child(work)
	var buttons := HBoxContainer.new()
	var check := CheckBox.new()
	check.text = "WoF inspection"
	check.button_pressed = bool(extra.get("inspect", false))
	check.toggled.connect(func(on: bool):
		if on:
			extra["inspect"] = true
		else:
			extra.erase("inspect")
		_refresh())
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(check)
	buttons.add_child(UI.button("Clear", func():
		plan.clear()
		extra.clear()
		_refresh(), not plan.is_empty() or not extra.is_empty()))
	var go := UI.button("Put it together", _commit, bool(q["ok"]))
	if bool(q["ok"]):
		UI.tint_button(go, UI.GOOD)
	buttons.add_child(go)
	_bill_box.add_child(buttons)


## The whole plan as one yard job: the bill shown is the bill charged.
func _commit() -> void:
	var q := ShipyardSystem.quote(sim.state, sim.data, plan, extra)
	var command := extra.duplicate()
	command["type"] = "refit"
	command["swaps"] = q["lines"].map(func(l): return {"slot": l["slot"], "module": l["module"]})
	var total := float(q["total"])
	var days := float(q["bill"]["days"])
	var why: String = sim.apply(command)
	if why != "":
		_status.text = "The yard won't take it on: %s." % why
		_status.add_theme_color_override("font_color", UI.WARN)
	else:
		var n: int = q["lines"].size()
		_status.text = "Put together%s in %.1f days, for %s." % [(": %d change%s" % [n, "" if n == 1 else "s"]) if n > 0 else "", days, UI.money(total)]
		_status.add_theme_color_override("font_color", UI.GOOD)
	plan.clear()
	extra.clear()
	_refresh()


# --- how she flies -------------------------------------------------------------------

## [label, value, higher is better]
func _figures(ship: Dictionary) -> Array:
	var d = sim.data
	var dry := ShipStats.dry_mass_t(ship, d)
	var cargo := ShipStats.cargo_t(ship) + float(ship.get("cabin_t", 0.0))
	var fuel_cap := ShipStats.fuel_capacity_t(ship, d)
	var ve := ShipStats.exhaust_velocity(ship, d)
	var full := ship.duplicate(true)
	full["fuel_t"] = fuel_cap
	var dv := ve * log((dry + cargo + fuel_cap) / maxf(dry + cargo, 1e-6)) / 1000.0 if ve > 0.0 else 0.0
	var heat := ShipStats.heat_ratio(ship, d)
	return [
		["Acceleration, full tanks", "%.2f milli-g" % (ShipStats.accel_mps2(full, d) / 9.80665 * 1000.0), ShipStats.accel_mps2(full, d), true],
		["Delta-v, full tanks", "%.1f km/s" % dv, dv, true],
		["Hold", "%.0f t" % ShipStats.cargo_capacity_t(ship, d), ShipStats.cargo_capacity_t(ship, d), true],
		["Propellant", "%.1f t" % fuel_cap, fuel_cap, true],
		["Heat", "--" if heat == INF else "%d%% of radiators" % int(round(heat * 100.0)), heat, false],
		["Life support", "%d days" % int(ShipStats.life_support_days(ship, d)), ShipStats.life_support_days(ship, d), true],
		["Berths", "%d" % ShipStats.berths(ship, d), float(ShipStats.berths(ship, d)), true],
		["Dry mass", "%.1f t" % dry, dry, false],
	]


func _fill_stats(now: Dictionary, after: Dictionary) -> void:
	for c in _stats_box.get_children():
		c.queue_free()
	for h in ["", "NOW", "", "AFTER"]:
		_stats_box.add_child(UI.label(h, UI.DIM, 11))
	var a := _figures(now)
	var b := _figures(after)
	for i in a.size():
		_stats_box.add_child(UI.label(a[i][0], UI.DIM, 13))
		_stats_box.add_child(UI.label(a[i][1], UI.TEXT, 13))
		var better := _compare(a[i], b[i])
		_stats_box.add_child(UI.label("" if better == 0 else ("▲" if (float(b[i][2]) > float(a[i][2])) else "▼"), UI.GOOD if better > 0 else UI.WARN, 13))
		_stats_box.add_child(UI.label(b[i][1], UI.TEXT if better == 0 else (UI.GOOD if better > 0 else UI.WARN), 13))


## 1 better, -1 worse, 0 the same.
func _compare(a: Array, b: Array) -> int:
	var x := float(a[2])
	var y := float(b[2])
	if absf(x - y) <= maxf(absf(x), 1e-6) * 1e-4:
		return 0
	return 1 if (y > x) == bool(a[3]) else -1


## A short line of what changes, ship against ship: "+15 t hold, -0.3 milli-g".
func _deltas(from: Dictionary, to: Dictionary) -> String:
	var a := _figures(from)
	var b := _figures(to)
	var bits := []
	for i in a.size():
		var c := _compare(a[i], b[i])
		if c != 0:
			bits.append(("better " if c > 0 else "worse ") + String(a[i][0]).to_lower().split(",")[0] + ": " + String(b[i][1]))
	return "; ".join(bits)


func _module_summary(m: Dictionary) -> String:
	var bits := ["%.1f t" % float(m["mass_t"])]
	if m.has("cargo_t"):
		bits.append("%d t hold" % int(m["cargo_t"]))
	if m.has("fuel_t"):
		bits.append("%d t propellant" % int(m["fuel_t"]))
	if m.has("thrust_n"):
		bits.append("%d N, Isp %d s" % [int(m["thrust_n"]), int(m.get("isp_s", 0))])
	if m.has("reject_mw"):
		bits.append("rejects %.1f MW" % float(m["reject_mw"]))
	if m.has("life_support_days"):
		bits.append("+%d days life support" % int(m["life_support_days"]))
	if m.has("berths"):
		bits.append("%d berths" % int(m["berths"]))
	if m.get("lander", false):
		bits.append("lands on surfaces")
	if m.get("survey", false):
		bits.append("surveys")
	if m.get("mining", false):
		bits.append("prospects and mines")
	return ", ".join(bits)
