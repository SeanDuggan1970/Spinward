## Docked: market, departures and shipyard, with the ship's status alongside.
## Rebuilt from state after every change; it never edits state, only sends commands.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const Market := preload("res://sim/market.gd")
const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const ShipyardSystem := preload("res://sim/systems/shipyard_system.gd")
const EconomySystem := preload("res://sim/systems/economy_system.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const TipsText := preload("res://view/tips_text.gd")
const SystemMap := preload("res://view/system_map.gd")
const Comms := preload("res://view/comms.gd")
const DAY := 86400.0

var sim
## Recent comms lines, owned by the game shell and shared with this screen.
var comms: Array
var _tabs: TabContainer
var _side: VBoxContainer
var _header: VBoxContainer
var _tab_index := 0


func _init(owner_sim, comms_log: Array = []) -> void:
	sim = owner_sim
	comms = comms_log
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_bottom", 70)
	margin.add_theme_constant_override("margin_top", 52)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	_header = VBoxContainer.new()
	root.add_child(_header)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_stretch_ratio = 2.2
	_tabs.tab_changed.connect(func(i): _tab_index = i)
	body.add_child(_tabs)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 10)
	body.add_child(_side)
	refresh()


func send(command: Dictionary) -> void:
	sim.apply(command)
	refresh()


func refresh() -> void:
	if _tabs == null or sim.state.location.get("status") != "docked":
		return
	var place_id: String = sim.state.location["place"]
	var place: Dictionary = sim.data.places[place_id]
	var keep_tab := _tab_index
	for c in _header.get_children():
		c.queue_free()
	_header.add_child(UI.label(place["name"].to_upper(), UI.AMBER, 26))
	var about := UI.label("%s  ·  %s" % [place["operator"], place["description"]], UI.DIM, 14)
	# Wrap, or a long description sets the minimum width of the whole screen.
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size = Vector2(200, 0)
	_header.add_child(about)
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_tabs.add_child(_market_tab(place_id))
	_tabs.add_child(_departures_tab(place_id))
	_tabs.add_child(_traffic_tab(place_id))
	_tabs.add_child(_projects_tab(place_id))
	_tabs.add_child(_tips_tab(place_id))
	if "shipyard" in place.get("services", []):
		_tabs.add_child(_shipyard_tab())
	_tab_index = mini(keep_tab, _tabs.get_tab_count() - 1)
	_tabs.current_tab = _tab_index
	for c in _side.get_children():
		c.queue_free()
	_side.add_child(_ship_panel(place_id))
	_side.custom_minimum_size = Vector2(300, 0)
	_wrap_long(_tabs)


## Long single-line labels set a container's minimum width and push panels off the
## screen; let them wrap instead.
func _wrap_long(node: Node) -> void:
	for child in node.get_children():
		if child is Label and child.text.length() > 60 and child.autowrap_mode == TextServer.AUTOWRAP_OFF:
			child.autowrap_mode = TextServer.AUTOWRAP_WORD
			child.custom_minimum_size.x = 200
		_wrap_long(child)


func _scroll(name_: String) -> Array:
	var scroll := ScrollContainer.new()
	scroll.name = name_
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	return [scroll, v]


func _market_tab(place_id: String) -> Control:
	var parts := _scroll("Market")
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	parts[1].add_child(grid)
	for h in ["GOOD", "STOCK", "BUY", "SELL", "ABOARD", "", "", ""]:
		grid.add_child(UI.label(h, UI.DIM, 12))
	var s = sim.state
	var d = sim.data
	var free := ShipStats.cargo_capacity_t(s.ship, d) - ShipStats.cargo_t(s.ship)
	for good in d.places[place_id]["market"]:
		var base := float(d.goods[good]["base_price"])
		var buy := Market.buy_price(s, d, place_id, good)
		var sell := Market.sell_price(s, d, place_id, good)
		var aboard := float(s.ship["cargo"].get(good, 0.0))
		var needed_by := _local_project_need(place_id, good)
		var name_label := UI.label(d.goods[good]["name"] + ("  ◆" if needed_by != "" else ""), UI.HAZARD if needed_by != "" else UI.TEXT)
		name_label.tooltip_text = d.goods[good]["description"] + ("\nNeeded here for %s." % needed_by if needed_by != "" else "")
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(name_label)
		grid.add_child(UI.label("%.1f t" % Market.stock(s, place_id, good), UI.DIM))
		grid.add_child(UI.label("%d" % int(buy), UI.GOOD if buy < base * 0.9 else UI.TEXT))
		grid.add_child(UI.label("%d" % int(sell), UI.AMBER if sell > base * 1.1 else UI.TEXT))
		grid.add_child(UI.label("%.1f t" % aboard if aboard > 0.0 else "—", UI.TEXT if aboard > 0.0 else UI.DIM))
		var max_buy := floorf(Market.affordable_tonnes(s, d, place_id, good, s.credits, minf(free, Market.stock(s, place_id, good))) * 10.0) / 10.0
		grid.add_child(UI.button("Buy 1", send.bind({"type": "buy", "good": good, "tonnes": 1.0}), max_buy >= 1.0))
		grid.add_child(UI.button("Buy max", _buy_max.bind(good), max_buy >= 0.1))
		grid.add_child(UI.button("Sell all", send.bind({"type": "sell", "good": good, "tonnes": aboard}), aboard > 0.0))
	var unsellable := []
	for good in s.ship["cargo"]:
		if not Market.trades(d, place_id, good):
			unsellable.append(d.goods[good]["name"])
	if not unsellable.is_empty():
		parts[1].add_child(UI.label("Not traded here: " + ", ".join(unsellable), UI.DIM, 13))
	parts[1].add_child(UI.label("Green buy prices are below normal; amber sell prices are above normal. Your trades move the price.", UI.DIM, 12))
	parts[1].add_child(UI.label("◆ needed here for a megaproject: deliveries count toward it, and toward your share.", UI.HAZARD, 12))
	return parts[0]


## Buy as much as fits, adjusting for the price rising as you buy.
func _buy_max(good: String) -> void:
	var s = sim.state
	var d = sim.data
	var place_id: String = s.location["place"]
	var room := minf(ShipStats.cargo_capacity_t(s.ship, d) - ShipStats.cargo_t(s.ship), Market.stock(s, place_id, good))
	var t := floorf(Market.affordable_tonnes(s, d, place_id, good, s.credits, room) * 10.0) / 10.0
	if t >= 0.1:
		send({"type": "buy", "good": good, "tonnes": t})


func _departures_tab(place_id: String) -> Control:
	var parts := _scroll("Departures")
	var s = sim.state
	var d = sim.data
	parts[1].add_child(UI.label("Your co-pilot plots a constant-thrust transfer at the ship's current mass. Prices elsewhere are what you last saw there, or what you have been told: buy tips on the Tip Line.", UI.DIM, 13))
	for to in d.places:
		if to == place_id:
			continue
		var plan: Dictionary = Navigation.plan(s.ship, d, sim.ephemeris, place_id, to, s.time_s)
		var p := UI.panel("")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		p[1].add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UI.label(d.places[to]["name"], UI.AMBER, 17))
		if plan.has("distance_m"):
			info.add_child(UI.label("%s   ·   %s   ·   %.2f t propellant" % [UI.km(plan["distance_m"]), UI.duration(plan["duration_s"]), plan["fuel_t"]]))
		var notes := []
		if not plan["ok"]:
			notes.append([plan["reason"], UI.WARN])
		elif plan["strand_risk"]:
			notes.append(["No fuel sold there, and you would not have enough to come back this way", UI.WARN])
		elif not plan["dest_refuels"]:
			notes.append(["No fuel sold there", UI.HAZARD])
		for note in _intel(place_id, to):
			notes.append(note)
		for n in notes:
			info.add_child(UI.label(n[0], n[1], 13))
		var go := UI.button("Depart", _depart.bind(to), plan["ok"])
		go.custom_minimum_size = Vector2(110, 0)
		row.add_child(go)
		parts[1].add_child(p[0])
	return parts[0]


## What you know about a destination: your own last look at its board (with its age)
## and any live tips about it. No perfect information: boards go stale, tips can lie.
func _intel(from: String, to: String) -> Array:
	var s = sim.state
	var d = sim.data
	var out := []
	var known: Dictionary = s.knowledge.get(to, {})
	if known.is_empty():
		out.append(["No price board on file: you have never been there.", UI.DIM])
	else:
		var best := ""
		var best_margin := 0.0
		for good in d.places[from]["market"]:
			if known["prices"].has(good):
				var m: float = float(known["prices"][good][1]) - Market.buy_price(s, d, from, good)
				if m > best_margin:
					best_margin = m
					best = good
		var when := TipsText.age(sim, float(known["t"])) + (" (old logbook)" if known.get("source") == "logbook" else "")
		if best != "":
			out.append(["Board seen %s: %s sold there for about %d cr/t more than here" % [when, String(d.goods[best]["name"]).to_lower(), int(best_margin)], UI.GOOD])
		else:
			out.append(["Board seen %s: nothing you can buy here sold for more there" % when, UI.DIM])
	for tip in s.tips:
		if tip["place"] == to and tip["verified"] == null and not tip.get("expired", false):
			out.append(["Tip from %s, %s: %s" % [d.brokers[tip["broker"]]["name"], TipsText.age(sim, float(tip["t"])), TipsText.line(sim, tip)], UI.AMBER])
	return out


func _depart(to: String) -> void:
	if sim.apply({"type": "depart", "to": to}) == "":
		sim.apply({"type": "set_time_scale", "scale": 1000})


func _shipyard_tab() -> Control:
	var parts := _scroll("Shipyard")
	var s = sim.state
	var d = sim.data
	var stock: Array = ShipyardSystem.yard_stock(s, d)
	var resale := float(d.balance["shipyard"]["resale_fraction"])
	parts[1].add_child(UI.label("Swap bolt-on modules. Your old module is taken in part-exchange at %d%% of its price." % int(resale * 100), UI.DIM, 13))
	var slots: Array = s.ship["modules"].keys()
	slots.sort()
	for slot in slots:
		var kind: String = slot.split(".")[0]
		var current: Dictionary = d.modules[s.ship["modules"][slot]]
		var p := UI.panel("%s %s" % [kind, int(slot.split(".")[1]) + 1])
		p[1].add_child(UI.label("Fitted: %s  (%s)" % [current["name"], _module_stats(current)]))
		for module_id in stock:
			var m: Dictionary = d.modules[module_id]
			if m["kind"] != kind or module_id == s.ship["modules"][slot]:
				continue
			var cost := float(m["price"]) - float(current["price"]) * resale
			var row := HBoxContainer.new()
			var l := UI.label("%s  (%s)" % [m["name"], _module_stats(m)], UI.DIM)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(UI.button("Fit for %s" % UI.money(cost), send.bind({"type": "install_module", "slot": slot, "module": module_id}), cost <= s.credits))
			p[1].add_child(row)
		parts[1].add_child(p[0])
	return parts[0]


func _module_stats(m: Dictionary) -> String:
	var bits := ["%.1f t" % float(m["mass_t"])]
	if m.has("cargo_t"):
		bits.append("%d t cargo" % int(m["cargo_t"]))
	if m.has("fuel_t"):
		bits.append("%d t propellant" % int(m["fuel_t"]))
	if m.has("thrust_n"):
		bits.append("%d N, %d MW heat" % [int(m["thrust_n"]), int(m["heat_mw"])])
	if m.has("reject_mw"):
		bits.append("rejects %.1f MW" % float(m["reject_mw"]))
	return ", ".join(bits)


func _ship_panel(place_id: String) -> Control:
	var s = sim.state
	var d = sim.data
	var p := UI.panel(s.ship["name"])
	var v: VBoxContainer = p[1]
	v.add_child(UI.label(d.ships[s.ship["hull"]]["name"], UI.DIM, 13))
	var cap := ShipStats.cargo_capacity_t(s.ship, d)
	var fuel_cap := ShipStats.fuel_capacity_t(s.ship, d)
	v.add_child(UI.label("Cargo   %.1f / %d t" % [ShipStats.cargo_t(s.ship), int(cap)]))
	for good in s.ship["cargo"]:
		v.add_child(UI.label("  %s  %.1f t" % [d.goods[good]["name"], s.ship["cargo"][good]], UI.DIM, 13))
	v.add_child(UI.label("Fuel    %.2f / %d t" % [s.ship["fuel_t"], int(fuel_cap)], UI.WARN if s.ship["fuel_t"] < fuel_cap * 0.25 else UI.TEXT))
	var fuel_bar := ProgressBar.new()
	fuel_bar.max_value = fuel_cap
	fuel_bar.value = s.ship["fuel_t"]
	fuel_bar.show_percentage = false
	fuel_bar.custom_minimum_size = Vector2(0, 8)
	v.add_child(fuel_bar)
	v.add_child(UI.label("Mass    %.1f t" % ShipStats.total_mass_t(s.ship, d)))
	v.add_child(UI.label("Accel   %.2f milli-g" % (ShipStats.accel_mps2(s.ship, d) / 9.80665 * 1000.0)))
	var heat := ShipStats.heat_ratio(s.ship, d)
	v.add_child(UI.label("Heat    %d%% of radiator capacity%s" % [int(heat * 100.0), "  (drive throttled)" if heat > 1.0 else ""], UI.WARN if heat > 1.0 else UI.TEXT))
	var services: Array = d.places[place_id].get("services", [])
	if "refuel" in services:
		var need := minf(fuel_cap - float(s.ship["fuel_t"]), Market.stock(s, place_id, "propellant"))
		var cost := Market.buy_cost(s, d, place_id, "propellant", need) if need > 0.01 else 0.0
		v.add_child(UI.button("Refuel  (%s)" % UI.money(cost), send.bind({"type": "refuel", "fill": true}), need > 0.01 and s.credits > 1.0))
	else:
		v.add_child(UI.label("No fuel sold here.", UI.HAZARD, 13))
	if EconomySystem.emergency_available(s, d) and float(s.ship["fuel_t"]) < fuel_cap - 0.01:
		var price := float(d.goods["propellant"]["base_price"]) * float(d.balance["economy"]["emergency_fuel_price_mult"])
		v.add_child(UI.button("Emergency tanker  (%s/t, on credit if broke)" % UI.money(price), send.bind({"type": "emergency_refuel"})))
	return p[0]


## Who else is about: ships in port, ships inbound, and the comms channel.
func _traffic_tab(place_id: String) -> Control:
	var s = sim.state
	var d = sim.data
	var row := HBoxContainer.new()
	row.name = "Traffic"
	row.add_theme_constant_override("separation", 12)
	var map := SystemMap.new(sim)
	map.custom_minimum_size = Vector2(360, 360)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_stretch_ratio = 1.1
	map.show_npc_labels = false
	row.add_child(map)
	var parts := _scroll("TrafficLists")
	parts[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(parts[0])
	var lists: VBoxContainer = parts[1]
	var in_port := []
	var inbound := []
	for npc in s.npcs:
		var loc: Dictionary = npc["location"]
		if loc["status"] == "docked" and loc["place"] == place_id:
			in_port.append(npc)
		elif loc["status"] == "transit" and loc["to"] == place_id:
			inbound.append(npc)
	inbound.sort_custom(func(a, b): return a["location"]["arrive_t"] < b["location"]["arrive_t"])
	lists.add_child(UI.label("IN PORT", UI.AMBER, 13))
	if in_port.is_empty():
		lists.add_child(UI.label("Nobody else docked.", UI.DIM, 13))
	for npc in in_port:
		var fleet: Dictionary = d.npcs["fleets"][npc["fleet"]]
		lists.add_child(UI.label("%s  ·  %s" % [npc["name"], fleet["operator"]], SystemMap.fleet_colour(sim, npc), 14))
		lists.add_child(UI.label("   %s, leaving in about %s" % [d.ships[npc["ship"]["hull"]]["name"], UI.duration(maxf(0.0, float(npc["next_t"]) - s.time_s))], UI.DIM, 12))
	lists.add_child(UI.label("INBOUND", UI.AMBER, 13))
	if inbound.is_empty():
		lists.add_child(UI.label("Nothing on the board.", UI.DIM, 13))
	for npc in inbound:
		var cargo := Comms.cargo_text(sim, npc["ship"]["cargo"])
		lists.add_child(UI.label("%s  ·  in %s" % [npc["name"], UI.duration(float(npc["location"]["arrive_t"]) - s.time_s)], SystemMap.fleet_colour(sim, npc), 14))
		lists.add_child(UI.label("   from %s%s" % [d.places[npc["location"]["from"]]["name"], ", carrying " + cargo if cargo != "" else ", empty"], UI.DIM, 12))
	lists.add_child(UI.label("COMMS", UI.AMBER, 13))
	if comms.is_empty():
		lists.add_child(UI.label("Quiet on the channel. Time compression ([ ]) passes the time while docked.", UI.DIM, 13))
	for i in range(comms.size() - 1, maxi(-1, comms.size() - 13), -1):
		var l := UI.label(comms[i], UI.TEXT, 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		lists.add_child(l)
	return row


## The name of the open project at this place that still needs `good`, or "".
func _local_project_need(place_id: String, good: String) -> String:
	for id in sim.data.projects:
		var project: Dictionary = sim.data.projects[id]
		var st: Dictionary = sim.state.projects.get(id, {})
		if project["place"] != place_id or st.is_empty() or st["done"]:
			continue
		var needs: Dictionary = project["stages"][int(st["stage"])]["needs"]
		if needs.has(good) and float(st["delivered"].get(good, 0.0)) < float(needs[good]):
			return project["name"]
	return ""


## Megaprojects across the system: stages, what the open stage still needs, your share.
func _projects_tab(place_id: String) -> Control:
	var parts := _scroll("Projects")
	var s = sim.state
	var d = sim.data
	parts[1].add_child(UI.label("Everyone is building something. Haul what a project needs to its station: it is drawn from the market, and your deliveries are credited.", UI.DIM, 13))
	for id in d.projects:
		var project: Dictionary = d.projects[id]
		var st: Dictionary = s.projects.get(id, {})
		if st.is_empty():
			continue
		var here: bool = project["place"] == place_id
		var p := UI.panel(project["name"] + ("   (here)" if here else "   at " + d.places[project["place"]]["name"]))
		var v: VBoxContainer = p[1]
		var desc := UI.label(project["description"], UI.DIM, 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(200, 0)
		v.add_child(desc)
		var total := ProjectSystem.progress(s, d, id)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = total
		bar.custom_minimum_size = Vector2(0, 10)
		bar.show_percentage = false
		v.add_child(bar)
		var stages: Array = project["stages"]
		for i in stages.size():
			var mark := "■" if st["done"] or i < int(st["stage"]) else ("▶" if i == int(st["stage"]) else "□")
			var colour := UI.GOOD if mark == "■" else (UI.AMBER if mark == "▶" else UI.DIM)
			v.add_child(UI.label("%s  %s" % [mark, stages[i]["name"]], colour, 13))
			if i == int(st["stage"]) and not st["done"]:
				var needs: Dictionary = stages[i]["needs"]
				for good in needs:
					var got := minf(float(st["delivered"].get(good, 0.0)), float(needs[good]))
					v.add_child(UI.label("      %-18s %6.1f / %d t" % [d.goods[good]["name"], got, int(needs[good])], UI.TEXT if got < float(needs[good]) else UI.GOOD, 12))
				if float(st["player_t"]) > 0.0:
					v.add_child(UI.label("      Your haulage this stage: %.1f t" % st["player_t"], UI.GOOD, 12))
		if st["done"]:
			v.add_child(UI.label("Complete. Your haulage over the whole build: %.1f t" % st["player_total_t"], UI.GOOD, 13))
		parts[1].add_child(p[0])
	return parts[0]


## The Tip Line: brokers working this station, and your book of tips.
func _tips_tab(place_id: String) -> Control:
	var parts := _scroll("Tip Line")
	var s = sim.state
	var d = sim.data
	parts[1].add_child(UI.label("Information has a price, and not all of it is true. Brokers sell what they hear about other ports. Tips are checked when you dock where they point, and you learn whom to trust.", UI.DIM, 13))
	var here := []
	for id in d.brokers:
		if d.brokers[id]["place"] == place_id:
			here.append(id)
	if here.is_empty():
		parts[1].add_child(UI.label("No brokers work this station.", UI.DIM, 13))
	for id in here:
		var b: Dictionary = d.brokers[id]
		var p := UI.panel(b["name"])
		p[1].add_child(UI.label(b["style"], UI.DIM, 12))
		var row := HBoxContainer.new()
		var rec := UI.label(TipsText.record_text(sim, id), UI.TEXT, 13)
		rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rec)
		row.add_child(UI.button("Buy a tip  (%s)" % UI.money(float(b["price"])), send.bind({"type": "buy_tip", "broker": id}), s.credits >= float(b["price"])))
		p[1].add_child(row)
		parts[1].add_child(p[0])
	var book := UI.panel("Your tip book")
	if s.tips.is_empty():
		book[1].add_child(UI.label("Empty.", UI.DIM, 13))
	for i in range(s.tips.size() - 1, -1, -1):
		var tip: Dictionary = s.tips[i]
		var st: Array = TipsText.status(tip)
		var head := UI.label("%-10s %s  ·  %s  ·  about %s" % [st[0], d.brokers[tip["broker"]]["name"], TipsText.age(sim, float(tip["t"])), d.places[tip["place"]]["name"]], st[1], 12)
		book[1].add_child(head)
		book[1].add_child(UI.label("    " + TipsText.line(sim, tip), UI.TEXT, 12))
		if tip.has("actual"):
			book[1].add_child(UI.label("    Board when you got there: %d cr/t" % int(tip["actual"]), UI.DIM, 12))
	parts[1].add_child(book[0])
	return parts[0]
