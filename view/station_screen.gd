## Docked: market, departures and shipyard, with the ship's status alongside.
## Rebuilt from state after every change; it never edits state, only sends commands.
extends Control

const UI := preload("res://view/ui/ui_kit.gd")
const Market := preload("res://sim/market.gd")
const RoutePlanner := preload("res://sim/route_planner.gd")
const Navigation := preload("res://sim/navigation.gd")
const ShipStats := preload("res://sim/ship_stats.gd")
const ShipyardSystem := preload("res://sim/systems/shipyard_system.gd")
const EconomySystem := preload("res://sim/systems/economy_system.gd")
const ProjectSystem := preload("res://sim/systems/project_system.gd")
const ElevatorSystem := preload("res://sim/systems/elevator_system.gd")
const DamageSystem := preload("res://sim/systems/damage_system.gd")
const TipsText := preload("res://view/tips_text.gd")
const TravelSystem := preload("res://sim/systems/travel_system.gd")
const SystemMap := preload("res://view/system_map.gd")
const Comms := preload("res://view/comms.gd")
const Contracts := preload("res://sim/contracts.gd")
const ContractSystem := preload("res://sim/systems/contract_system.gd")
const Perks := preload("res://sim/perks.gd")
const Favours := preload("res://sim/favours.gd")
const Condition := preload("res://sim/condition.gd")
const Fitness := preload("res://sim/fitness.gd")
const Insurance := preload("res://sim/insurance.gd")
const ShipBill := preload("res://sim/ship_bill.gd")
const SiteSystem := preload("res://sim/systems/site_system.gd")
const DAY := 86400.0

var sim
## Asked to fly a landing by hand: (site, activity). The shell runs the descent.
signal landing_requested(site: String, activity: String)
## Recent comms lines, owned by the game shell and shared with this screen.
var comms: Array
var _tabs: TabContainer
var _side: VBoxContainer
var _header: VBoxContainer
var _tab_index := 0
## Buy max leaves enough for the tug at the next port and a full tank here.
static var keep_reserve := true
## Route plotting in progress: {to: {task, box, key, plan_t}}; box.options is filled by the worker.
var _plotting: Dictionary = {}
## Rebuilt lists being held at their old scroll position: [scroll bar, callable, frames left].
var _scroll_holds: Array = []


class _ResultBox:
	var options: Array = []


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
	if _tabs == null or not sim.state.location.get("status") in ["docked", "on_site"]:
		return
	var place_id: String = sim.state.location["place"]
	var on_site: bool = sim.data.sites.has(place_id)
	var place: Dictionary = sim.data.locations[place_id]
	var keep_tab := _tab_index
	for c in _header.get_children():
		c.queue_free()
	_header.add_child(UI.label(place["name"].to_upper(), UI.AMBER, 26))
	var about := UI.label("%s  ·  %s" % [place.get("operator", "On site, no port"), place["description"]], UI.DIM, 14)
	# Wrap, or a long description sets the minimum width of the whole screen.
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size = Vector2(200, 0)
	_header.add_child(about)
	# Rebuilding a tab (as plotting a route does, several times a second) must not throw
	# its list back to the top: note where each list was scrolled, and hold it there.
	var scrolled := {}
	for c in _tabs.get_children():
		if c is ScrollContainer:
			scrolled[String(c.name)] = (c as ScrollContainer).scroll_vertical
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	if on_site:
		_tabs.add_child(_site_tab(place_id))
		_tabs.add_child(_departures_tab(place_id))
	else:
		_tabs.add_child(_market_tab(place_id))
		_tabs.add_child(_departures_tab(place_id))
		_tabs.add_child(_contracts_tab(place_id))
		_tabs.add_child(_traffic_tab(place_id))
		_tabs.add_child(_projects_tab(place_id))
		_tabs.add_child(_news_tab())
		_tabs.add_child(_tips_tab(place_id))
		if "shipyard" in place.get("services", []):
			_tabs.add_child(_shipyard_tab())
	_tab_index = mini(keep_tab, _tabs.get_tab_count() - 1)
	_tabs.current_tab = _tab_index
	for c in _tabs.get_children():
		if c is ScrollContainer and int(scrolled.get(String(c.name), 0)) > 0:
			_hold_scroll(c, int(scrolled[String(c.name)]))
	for c in _side.get_children():
		c.queue_free()
	_side.add_child(_ship_panel(place_id))
	_side.custom_minimum_size = Vector2(300, 0)
	_wrap_long(_tabs)


## Put a rebuilt list back where it was scrolled. The new list has no height until it
## is laid out (later this frame, before it is drawn), so the position is set again
## each time its scroll bar's range changes, for a few frames, then let go.
func _hold_scroll(scroll: ScrollContainer, value: int) -> void:
	var bar := scroll.get_v_scroll_bar()
	var put := _put_scroll.bind(scroll, value)
	bar.changed.connect(put)
	_scroll_holds.append([bar, put, 6])
	scroll.scroll_vertical = value


func _put_scroll(scroll: ScrollContainer, value: int) -> void:
	scroll.scroll_vertical = value


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
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	parts[1].add_child(grid)
	for h in ["GOOD", "STOCK", "BUY", "SELL", "ABOARD", "", "", "", "IF SOLD"]:
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
		var name_label := UI.label(d.goods[good]["name"] + ("  *" if needed_by != "" else ""), UI.HAZARD if needed_by != "" else UI.TEXT)
		name_label.tooltip_text = d.goods[good]["description"] + ("\nNeeded here for %s." % needed_by if needed_by != "" else "")
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(name_label)
		grid.add_child(UI.label("%.1f t" % Market.stock(s, place_id, good), UI.DIM))
		grid.add_child(UI.label("%d" % int(buy), UI.GOOD if buy < base * 0.9 else UI.TEXT))
		grid.add_child(UI.label("%d" % int(sell), UI.AMBER if sell > base * 1.1 else UI.TEXT))
		grid.add_child(UI.label("%.1f t" % aboard if aboard > 0.0 else "—", UI.TEXT if aboard > 0.0 else UI.DIM))
		var max_buy := floorf(Market.affordable_tonnes(s, d, place_id, good, _spendable(place_id), minf(free, Market.stock(s, place_id, good))) * 10.0) / 10.0
		grid.add_child(UI.button("Buy 1", send.bind({"type": "buy", "good": good, "tonnes": 1.0}), max_buy >= 1.0))
		grid.add_child(UI.button("Buy max", _buy_max.bind(good), max_buy >= 0.1))
		# Selling it all: what it fetches here (your sale moves the price, so the whole
		# load is priced together) against what you paid. Green at a profit, red at a loss.
		var sell_all := UI.button("Sell all", send.bind({"type": "sell", "good": good, "tonnes": aboard}), aboard > 0.0)
		grid.add_child(sell_all)
		if aboard > 0.0:
			var income := Market.sell_price(s, d, place_id, good, aboard) * aboard
			var paid := float(s.ship.get("cargo_paid", {}).get(good, 0.0))
			var profit := income - paid
			var colour: Color = UI.GOOD if profit >= 0.0 else UI.WARN
			UI.tint_button(sell_all, colour)
			var gain := UI.label(("+" if profit >= 0.0 else "") + UI.money(profit), colour)
			gain.tooltip_text = "Sells for %s; you paid %s." % [UI.money(income), UI.money(paid)]
			gain.mouse_filter = Control.MOUSE_FILTER_PASS
			sell_all.tooltip_text = gain.tooltip_text
			grid.add_child(gain)
		else:
			grid.add_child(UI.label("", UI.DIM))
	var unsellable := []
	for good in s.ship["cargo"]:
		if not Market.trades(d, place_id, good):
			unsellable.append(d.goods[good]["name"])
	if not unsellable.is_empty():
		parts[1].add_child(UI.label("Not traded here: " + ", ".join(unsellable), UI.DIM, 13))
	parts[1].add_child(UI.label("Green buy prices are below normal; amber sell prices are above normal. Your trades move the price. IF SOLD is the profit on selling the whole load here, after what you paid: green a gain, red a loss.", UI.DIM, 12))
	parts[1].add_child(UI.label("* needed here for a megaproject: deliveries count toward it, and toward your share.", UI.HAZARD, 12))
	var keep := CheckButton.new()
	keep.text = "Buy max keeps a reserve for the tug and a full tank (%s)" % UI.money(_reserve(place_id))
	keep.button_pressed = keep_reserve
	keep.focus_mode = Control.FOCUS_NONE
	keep.toggled.connect(func(on): keep_reserve = on; refresh())
	parts[1].add_child(keep)
	return parts[0]


## Credits held back by the reserve toggle: the next tug fee plus filling the tank here.
func _reserve(place_id: String) -> float:
	var s = sim.state
	var d = sim.data
	var reserve := float(d.balance["docking"]["auto_dock_fee"])
	if "refuel" in d.places[place_id].get("services", []):
		var space := minf(ShipStats.fuel_capacity_t(s.ship, d) - float(s.ship["fuel_t"]), Market.stock(s, place_id, "propellant"))
		if space > 0.01:
			reserve += Market.buy_cost(s, d, place_id, "propellant", space)
	return reserve


func _spendable(place_id: String) -> float:
	return maxf(0.0, sim.state.credits - (_reserve(place_id) if keep_reserve else 0.0))


## Buy as much as fits, adjusting for the price rising as you buy.
func _buy_max(good: String) -> void:
	var s = sim.state
	var d = sim.data
	var place_id: String = s.location["place"]
	var room := minf(ShipStats.cargo_capacity_t(s.ship, d) - ShipStats.cargo_t(s.ship), Market.stock(s, place_id, good))
	var t := floorf(Market.affordable_tonnes(s, d, place_id, good, _spendable(place_id), room) * 10.0) / 10.0
	if t >= 0.1:
		send({"type": "buy", "good": good, "tonnes": t})


func _departures_tab(place_id: String) -> Control:
	var parts := _scroll("Departures")
	var s = sim.state
	var d = sim.data
	# A ribbon down to the surface (or, at the bottom, back up to your ship).
	if not ElevatorSystem.line_here(d, place_id).is_empty():
		parts[1].add_child(_elevator_panel(place_id))
		if d.places[place_id].has("foot_of"):
			return parts[0]
	parts[1].add_child(UI.label("Plot routes and your co-pilot flies trial courses under real Earth and Moon gravity: Express burns hard, Economy lets gravity do the work, lunar flybys are for the view (and occasionally the fuel). Prices elsewhere are what you last saw there, or what you have been told: buy tips on the Tip Line.", UI.DIM, 13))
	# Local destinations first, then the long hauls across the Sun's domain.
	var dests: Array = d.places.keys().filter(func(to): return to != place_id and Perks.place_open(s, d, to))
	var local: Array = dests.filter(func(to): return Navigation.frame_body(d, place_id, to) != "sun")
	var far: Array = dests.filter(func(to): return Navigation.frame_body(d, place_id, to) == "sun")
	var spots: Array = d.sites.keys().filter(func(to): return to != place_id and SiteSystem.knows(s, to))
	for to in local + far + spots:
		if to == (far[0] if not far.is_empty() else ""):
			parts[1].add_child(UI.label("ACROSS THE SYSTEM  ·  months, not days: tanks, larder and patience", UI.HAZARD, 13))
		if to == (spots[0] if not spots.is_empty() else ""):
			parts[1].add_child(UI.label("POINTS OF INTEREST  ·  no port, no fuel: you go, you work, you come back", UI.HAZARD, 13))
		var plan: Dictionary = _quick(place_id, to)
		var p := UI.panel("")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		p[1].add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UI.label(d.locations[to]["name"], UI.AMBER, 17))
		if plan.has("distance_m"):
			info.add_child(UI.label("%s   ·   quick estimate %s, %.2f t" % [UI.km(plan["distance_m"]), UI.duration(plan["duration_s"]), plan["fuel_t"]]))
		var notes := []
		if not plan["ok"]:
			notes.append([plan["reason"], UI.WARN])
		elif plan["strand_risk"]:
			notes.append(["No fuel sold there, and you would not have enough to come back this way", UI.WARN])
		elif not plan["dest_refuels"]:
			notes.append(["No fuel sold there", UI.HAZARD])
		for note in _intel(place_id, to):
			notes.append(note)
		for job in sim.state.contracts.get("active", []):
			var stop: String = job["pickup"] if job["state"] == "collect" else job["to"]
			if stop == to:
				var verb := "Collect" if job["state"] == "collect" else "Deliver"
				var left: float = float(job["deadline_t"]) - sim.state.time_s
				notes.append(["Contract: %s %s here, due in %s" % [verb.to_lower(), job["item"], UI.duration(maxf(left, 0.0))], UI.GOOD if left > float(plan.get("duration_s", 0.0)) else UI.WARN])
		for n in notes:
			info.add_child(UI.label(n[0], n[1], 13))
		var side := VBoxContainer.new()
		side.custom_minimum_size = Vector2(150, 0)
		row.add_child(side)
		_route_controls(place_id, to, plan, p[1], side)
		parts[1].add_child(p[0])
	return parts[0]


## Riding the elevator from here: where it goes, how long, the fare for what you carry.
func _elevator_panel(place_id: String) -> Control:
	var d = sim.data
	var s = sim.state
	var here := ElevatorSystem.line_here(d, place_id)
	var line: Dictionary = here["line"]
	var to_name: String = d.places[here["to"]]["name"]
	var p := UI.panel("%s  ·  %s" % [String(line["name"]).to_upper(), ("down to " + to_name) if here["down"] else ("up to " + to_name)])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p[1].add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	if here["down"]:
		var town := UI.label(d.places[here["to"]]["description"], UI.DIM, 12)
		town.autowrap_mode = TextServer.AUTOWRAP_WORD
		town.custom_minimum_size = Vector2(200, 0)
		info.add_child(town)
		var via := UI.label(String(line.get("via", "")) + " Your ship stays docked here; your hold rides down with you in a climber container.", UI.TEXT, 12)
		via.autowrap_mode = TextServer.AUTOWRAP_WORD
		via.custom_minimum_size = Vector2(200, 0)
		info.add_child(via)
	else:
		info.add_child(UI.label("Your ship is docked at %s. Your hold rides up with you." % to_name, UI.TEXT, 13))
	var fare := ElevatorSystem.fare(d, s, place_id)
	info.add_child(UI.label("%s ride   ·   %d km   ·   fare %s (a seat, and %d cr a tonne for the %.1f t you carry)" % [
		UI.duration(float(line["hours"]) * 3600.0), int(line["km"]), UI.money(fare), int(line["fare_per_t"]), ShipStats.cargo_t(s.ship)]))
	var why := ElevatorSystem.blocked(d, s, place_id)
	if why != "":
		info.add_child(UI.label(why.capitalize(), UI.WARN, 13))
	row.add_child(UI.button("Ride down" if here["down"] else "Ride up", send.bind({"type": "ride_elevator"}), why == ""))
	return p[0]


## On site: what there is to do here, what it needs, how long it takes, and what it
## might yield. Work passes game time; speed it up with time compression.
func _site_tab(site_id: String) -> Control:
	var parts := _scroll("Site")
	var s = sim.state
	var d = sim.data
	var site: Dictionary = d.sites[site_id]
	var work: Dictionary = s.sites.get("work", {})
	if not work.is_empty():
		var act: Dictionary = site["activities"][work["activity"]]
		var p := UI.panel("At work: " + act["name"])
		var span: float = float(work["end_t"]) - float(work["start_t"])
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = clampf((s.time_s - float(work["start_t"])) / maxf(span, 1.0), 0.0, 1.0)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		p[1].add_child(bar)
		p[1].add_child(UI.label("%s to go. Speed time up with ] ; the crew will call when it is done." % UI.duration(maxf(0.0, float(work["end_t"]) - s.time_s)), UI.AMBER, 13))
		parts[1].add_child(p[0])
	for act_id in site.get("activities", {}):
		var act: Dictionary = site["activities"][act_id]
		var p := UI.panel(act["name"])
		var bits := ["%s of work" % UI.duration(float(act["days"]) * DAY)]
		if float(act.get("risk", 0.0)) > 0.0:
			bits.append("%d%% chance it goes badly" % int(round(float(act["risk"]) * 100.0)))
		var needs: Array = act.get("needs", [])
		if not needs.is_empty():
			bits.append("needs " + ", ".join(needs.map(func(n): return {"survey": "a survey pod", "lander": "a lander", "mining": "a mining rig"}.get(n, n))))
		p[1].add_child(UI.label("  ·  ".join(bits), UI.DIM, 13))
		var gains := []
		for good in act.get("yields", {}):
			var r: Array = act["yields"][good]
			gains.append("%s %.1f-%.1f t" % [String(d.goods[good]["name"]).to_lower(), float(r[0]), float(r[1])])
		if float(act.get("credits", 0.0)) > 0.0:
			gains.append("about %s on completion" % UI.money(float(act["credits"])))
		if not gains.is_empty():
			p[1].add_child(UI.label("Expect: " + ", ".join(gains), UI.TEXT, 13))
		var why := SiteSystem.blocked(s, d, site_id, act_id)
		var row := HBoxContainer.new()
		var hint := UI.label("" if why == "" else why.capitalize(), UI.WARN if why != "" and why != "already done" else UI.DIM, 12)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(hint)
		if "lander" in needs:
			row.add_child(UI.button("Fly the descent", func(): landing_requested.emit(site_id, act_id), why == ""))
			row.add_child(UI.button("Let the co-pilot land", send.bind({"type": "site_work", "activity": act_id}), why == ""))
		else:
			row.add_child(UI.button("Begin", send.bind({"type": "site_work", "activity": act_id}), why == ""))
		p[1].add_child(row)
		parts[1].add_child(p[0])
	return parts[0]


## Courier work: your standing, your jobs, and this port's board. Jobs set their
## deadlines from a light courier's fastest trip, so a laden ship may not make it:
## the co-pilot's estimate at your current mass is shown against each.
func _contracts_tab(place_id: String) -> Control:
	var parts := _scroll("Contracts")
	var s = sim.state
	var d = sim.data
	var client := Contracts.client_of(d, place_id)
	var rep := Contracts.rep_of(s, client)
	parts[1].add_child(UI.label("Standing with %s: %s (%d).  Deliver on time to be known; known pilots get the better jobs, and people come to find them." % [client, Contracts.tier(d, rep), int(round(rep))], UI.DIM, 13))
	var known := []
	for op in s.reputation:
		if op != client and absf(float(s.reputation[op])) >= 1.0:
			known.append("%s: %s" % [op, Contracts.tier(d, float(s.reputation[op]))])
	if not known.is_empty():
		parts[1].add_child(UI.label("Elsewhere: " + "  ·  ".join(known), UI.DIM, 12))
	var letters: Array = s.story.get("messages", [])
	if not letters.is_empty():
		var corr := UI.panel("Correspondence")
		for m in letters.slice(maxi(0, letters.size() - 3)):
			var head := UI.label("%s  ·  %s" % [m["from"], TipsText.age(sim, float(m["t"]))], UI.AMBER, 12)
			corr[1].add_child(head)
			var body := UI.label(m["text"], UI.TEXT, 13)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD
			body.custom_minimum_size = Vector2(200, 0)
			corr[1].add_child(body)
		parts[1].add_child(corr[0])
	var active: Array = s.contracts.get("active", [])
	if not active.is_empty():
		var mine := UI.panel("Your jobs  (%d)" % active.size())
		for job in active:
			var row := HBoxContainer.new()
			var left: float = float(job["deadline_t"]) - s.time_s
			var where := ("collect at %s, then " % d.places[job["pickup"]]["name"]) if job["state"] == "collect" else ""
			var text := "%s  ·  %sdeliver to %s  ·  due in %s  ·  %s" % [_cargo_words(job), where, d.places[job["to"]]["name"], UI.duration(maxf(left, 0.0)) if left > 0.0 else "OVERDUE", UI.money(float(job["reward"]))]
			var l := UI.label(text, UI.TEXT if left > 0.0 else UI.WARN, 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(UI.button("Abandon", send.bind({"type": "abandon_contract", "id": job["id"]})))
			mine[1].add_child(row)
		parts[1].add_child(mine[0])
	_favours_panels(parts[1], place_id)
	var board: Array = s.contracts.get("board", {}).get(place_id, [])
	var shown := 0
	var gated := 0
	var gate_tier := ""
	# Approaches first: someone came looking for you.
	var ordered := board.filter(func(o): return o["channel"] == "approach") + board.filter(func(o): return o["channel"] != "approach")
	for offer in ordered:
		if not ContractSystem.visible_to(s, d, offer):
			if not offer.get("hidden", false):
				gated += 1
				gate_tier = Contracts.tier(d, float(offer["min_rep"]))
			continue
		shown += 1
		parts[1].add_child(_offer_card(place_id, offer))
	if shown == 0:
		parts[1].add_child(UI.label("Nothing on the board right now. Check back in a day or two.", UI.DIM, 13))
	if gated > 0:
		parts[1].add_child(UI.label("%d more job%s here for pilots they know (%s)." % [gated, "s" if gated > 1 else "", gate_tier], UI.HAZARD, 13))
	return parts[0]


## Hitchhikers asking for a ride here, those aboard, and the vouchers you hold.
func _favours_panels(into: Control, place_id: String) -> void:
	var s = sim.state
	var d = sim.data
	if d.favours.is_empty():
		return
	var asking: Array = s.favours.get("waiting", {}).get(place_id, [])
	var aboard: Array = s.ship.get("hikers", [])
	if not asking.is_empty() or not aboard.is_empty():
		var pan := UI.panel("Hitchhikers")
		for h in aboard:
			pan[1].add_child(UI.label("Aboard: %s, bound for %s" % [Favours.hiker_blurb(d, h), d.places[h["to"]]["name"]], UI.GOOD, 13))
		for h in asking:
			var row := HBoxContainer.new()
			var l := UI.label("%s, wants to go to %s. Pays %s." % [Favours.hiker_blurb(d, h), d.places[h["to"]]["name"], UI.money(float(h["fare"])) if float(h["fare"]) > 0.0 else "nothing but thanks"], UI.TEXT, 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var free := Favours.free_berths(s, d)
			row.add_child(UI.button("Take aboard" if free > 0 else "No free berth", send.bind({"type": "accept_hitchhiker", "id": h["id"]}), free > 0))
			pan[1].add_child(row)
		into.add_child(pan[0])
	var held: Array = s.favours.get("vouchers", [])
	if not held.is_empty():
		var pan2 := UI.panel("Vouchers and favours owed")
		for v in held:
			var left := UI.duration(maxf(0.0, float(v["expires_t"]) - s.time_s))
			var text := ""
			match v["form"]:
				"yard":
					text = "Repair voucher, %d cr left at %s yards (%s)" % [int(float(v["value_cr"])), v["operator"], ", ".join(Favours.yard_names(d, v["operator"]))]
				"docking":
					text = "Free docking tugs at %s ports" % v["operator"]
				"fuel":
					text = "%d%% off propellant at %s ports" % [int(round(float(v["discount"]) * 100.0)), v["operator"]]
				"refuel":
					text = "%.1f t free propellant at %s ports" % [float(v["tonnes"]), v["operator"]]
			var vrow := HBoxContainer.new()
			var vl := UI.label("%s  ·  expires in %s" % [text, left], UI.TEXT, 13)
			vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vrow.add_child(vl)
			if v["form"] == "yard":
				var usable: bool = Favours.operator_of(d, place_id) == v["operator"] and "shipyard" in d.places[place_id].get("services", []) and DamageSystem.repair_cost(s, d) > 0.5
				vrow.add_child(UI.button("Use for repairs", send.bind({"type": "use_voucher", "id": v["id"]}), usable))
			pan2[1].add_child(vrow)
		pan2[1].add_child(UI.label("Fuel and docking vouchers are used for you when you pay.", UI.DIM, 12))
		into.add_child(pan2[0])


func _cargo_words(job: Dictionary) -> String:
	if int(job["passengers"]) > 0:
		return "%s (%d aboard)" % [job["item"], int(job["passengers"])]
	if bool(job.get("hand", false)):
		return "%s, carried by hand (no hold space)" % job["item"]
	return "%s, %.2f t" % [job["item"], float(job["mass_t"])]


func _offer_card(place_id: String, offer: Dictionary) -> Control:
	var s = sim.state
	var d = sim.data
	var title: String = {"package": "Courier", "passenger": "Passage", "pickup": "Pick up and deliver", "long_haul": "Long-haul courier"}.get(offer["kind"], "Job")
	if offer["channel"] == "rumour":
		title += "  ·  heard through the grapevine"
	var p := UI.panel(title)
	if offer.has("opener"):
		var o := UI.label(offer["opener"], UI.AMBER, 13)
		o.autowrap_mode = TextServer.AUTOWRAP_WORD
		p[1].add_child(o)
	var route: String = d.places[offer["to"]]["name"]
	if offer["pickup"] != "":
		route = "collect at %s, deliver to %s" % [d.places[offer["pickup"]]["name"], route]
	var due: float = float(offer["window_s"])
	p[1].add_child(UI.label("%s  ·  %s" % [_cargo_words(offer), route], UI.TEXT, 14))
	# How the co-pilot rates our chances at the ship's current mass.
	var first: String = offer["pickup"] if offer["pickup"] != "" else offer["to"]
	var plan := Navigation.plan(s.ship, d, sim.ephemeris, place_id, first, s.time_s)
	var est := "co-pilot: no route from here with this ship"
	var colour := UI.WARN
	if plan.get("ok", false):
		var need := float(plan["duration_s"])
		if offer["pickup"] != "":
			var onward := Navigation.plan(s.ship, d, sim.ephemeris, offer["pickup"], offer["to"], s.time_s + need)
			need += float(onward.get("duration_s", INF))
		est = "co-pilot reckons %s at your mass" % UI.duration(need)
		colour = UI.GOOD if need < due * 0.85 else (UI.AMBER if need < due else UI.WARN)
	p[1].add_child(UI.label("Allow %s  ·  %s  ·  pays %s  ·  %s" % [UI.duration(due), est, UI.money(float(offer["reward"])), offer["client"]], colour, 13))
	if offer.has("in_kind"):
		var kind_line := UI.label("Also: " + Favours.describe(d, offer["in_kind"]), UI.GOOD, 13)
		kind_line.autowrap_mode = TextServer.AUTOWRAP_WORD
		p[1].add_child(kind_line)
	var why := ""
	if int(offer["passengers"]) > 0 and ContractSystem.free_berths(s, d) < int(offer["passengers"]):
		var yards := ContractSystem.berth_yards(d)
		why = "needs %d berths: fit passenger berths in a cargo slot%s" % [int(offer["passengers"]), (" (sold at %s)" % ", ".join(yards)) if not yards.is_empty() else ""]
	elif offer["pickup"] == "" and not ContractSystem.in_cabin(offer) and ShipStats.cargo_t(s.ship) + float(offer["mass_t"]) > ShipStats.cargo_capacity_t(s.ship, d) + 1e-9:
		why = "no room in the hold"
	var row := HBoxContainer.new()
	var hint := UI.label(why, UI.WARN, 12)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	row.add_child(UI.button("Take the job", send.bind({"type": "accept_contract", "id": offer["id"]}), why == ""))
	p[1].add_child(row)
	return p[0]


## What you know about a destination: your own last look at its board (with its age)
## and any live tips about it. No perfect information: boards go stale, tips can lie.
func _intel(from: String, to: String) -> Array:
	var s = sim.state
	var d = sim.data
	var out := []
	if d.sites.has(to):
		var jobs: Array = d.sites[to].get("activities", {}).values().map(func(a): return a["name"])
		return [["%s: %s" % [String(d.sites[to].get("kind", "site")).capitalize(), ", ".join(jobs)], UI.DIM]]
	if not d.places.has(from):
		return out
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


## Plot routes / choose a route for one destination card.
func _route_controls(place_id: String, to: String, quick: Dictionary, card: VBoxContainer, side: VBoxContainer) -> void:
	var key: String = sim.route_key(to, _plan_t(to))
	var options: Array = sim.route_cache.get(key, [])
	if sim.state.time_s - _plan_t(to) > TravelSystem.PLAN_VALID_S:
		options = []  # out of date: plot again
	if _plotting.has(to):
		side.add_child(UI.label("Co-pilot plotting\nroutes" + ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3), UI.AMBER, 13))
		return
	if options.is_empty():
		side.add_child(UI.button("Plot routes", _plot.bind(place_id, to), quick.get("ok", false)))
		return
	side.add_child(UI.button("Re-plot", _plot.bind(place_id, to)))
	var economy_fuel := INF
	for want in ["economy", "express"]:
		for o in options:
			if o["id"] == want and economy_fuel == INF:
				economy_fuel = float(o["fuel_t"])
	for o in options:
		var line := HBoxContainer.new()
		var text := "%s   %s   %.2f t" % [o["label"], UI.duration(float(o["duration_s"])), float(o["fuel_t"])]
		var colour := UI.TEXT
		if o["kind"] == "flyby":
			var extra := float(o["fuel_t"]) - economy_fuel
			text += "   " + ("saves %d%%" % int(round(float(o.get("saving", 0.0)) * 100.0)) if extra < 0.0 else "+%.2f t vs Economy" % extra)
			colour = UI.AMBER
		var l := UI.label(text, colour if o["affordable"] else UI.WARN, 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		line.add_child(UI.button("Depart", _depart.bind(to, o["id"]), o["affordable"]))
		card.add_child(line)


func _plan_t(to: String) -> float:
	return float(_plotting.get(to, {}).get("plan_t", _last_plan_t.get(to, sim.state.time_s)))


var _last_plan_t: Dictionary = {}
## Quick plans for the departures board, per destination and hour (interplanetary
## estimates take tens of milliseconds each, and the board redraws often).
var _quick_cache: Dictionary = {}


func _quick(place_id: String, to: String) -> Dictionary:
	var s = sim.state
	var key := "%s>%s|%d|%.3f|%.3f" % [place_id, to, int(s.time_s / 3600.0), ShipStats.total_mass_t(s.ship, sim.data), float(s.ship["fuel_t"])]
	if not _quick_cache.has(key):
		if _quick_cache.size() > 64:
			_quick_cache.clear()
		_quick_cache[key] = Navigation.plan(s.ship, sim.data, sim.ephemeris, place_id, to, s.time_s)
	return _quick_cache[key]


func _plot(place_id: String, to: String) -> void:
	var t: float = sim.state.time_s
	var box := _ResultBox.new()
	# Gather on the main thread (the ephemeris is not thread-safe), fly on a worker.
	var quick: Dictionary = Navigation.plan(sim.state.ship, sim.data, sim.ephemeris, place_id, to, t)
	var job: Dictionary = RoutePlanner.prepare(sim.state.ship, sim.data, sim.ephemeris, place_id, to, t)
	job["hop"] = RoutePlanner.is_orbital_hop(sim.data, sim.ephemeris, place_id, to, t)
	var fly := func(): box.options = RoutePlanner.options_or_quick(job, quick)
	if OS.has_feature("web"):
		# The browser build is single-threaded: fly on the main thread, a couple of
		# frames from now so "plotting" shows first. It pauses for a second or two.
		_plotting[to] = {"sync": fly, "frames": 2, "box": box, "key": sim.route_key(to, t), "plan_t": t}
	else:
		_plotting[to] = {"task": WorkerThreadPool.add_task(fly), "box": box, "key": sim.route_key(to, t), "plan_t": t}
	refresh()


func _process(_dt: float) -> void:
	for hold in _scroll_holds:
		hold[2] -= 1
		if hold[2] <= 0 and is_instance_valid(hold[0]) and (hold[0] as ScrollBar).changed.is_connected(hold[1]):
			(hold[0] as ScrollBar).changed.disconnect(hold[1])
	_scroll_holds = _scroll_holds.filter(func(hold): return hold[2] > 0 and is_instance_valid(hold[0]))
	var done := []
	for to in _plotting:
		var p: Dictionary = _plotting[to]
		var finished := false
		if p.has("sync"):
			p["frames"] -= 1
			if p["frames"] <= 0:
				p["sync"].call()
				finished = true
		elif WorkerThreadPool.is_task_completed(p["task"]):
			WorkerThreadPool.wait_for_task_completion(p["task"])
			finished = true
		if finished:
			sim.store_route_options(p["key"], p["box"].options)
			_last_plan_t[to] = p["plan_t"]
			done.append(to)
	for to in done:
		_plotting.erase(to)
	if not done.is_empty() or (not _plotting.is_empty() and Engine.get_process_frames() % 20 == 0):
		refresh()


func _depart(to: String, route_id: String) -> void:
	var plan_t: float = _last_plan_t.get(to, sim.state.time_s)
	# Time is left to the departure ramp (travel_system): x1 while we back off the
	# port and turn to the burn, then up to the default.
	sim.apply({"type": "depart", "to": to, "route": route_id, "plan_t": plan_t})


func _shipyard_tab() -> Control:
	var parts := _scroll("Shipyard")
	var s = sim.state
	var d = sim.data
	var stock: Array = ShipyardSystem.yard_stock(s, d)
	# The ship builder: plan the whole refit on screen, with the ship and the bill, then
	# put it together. The quick swaps below still work for one change at a time.
	var open := UI.button("Open the ship builder: plan a refit, see her and the bill", _open_builder)
	UI.tint_button(open, UI.AMBER)
	parts[1].add_child(open)
	parts[1].add_child(UI.label("Or swap one module at a time below: parts, fitting labour and days in port, less a trade-in by condition and age. Every price is the bill you will be charged.", UI.DIM, 13))
	parts[1].add_child(_fitness_panel())
	var slots: Array = s.ship["modules"].keys()
	slots.sort()
	for slot in slots:
		var kind: String = slot.split(".")[0]
		var current: Dictionary = d.modules[s.ship["modules"][slot]]
		var p := UI.panel("%s %s" % [kind, int(slot.split(".")[1]) + 1])
		var cond := Condition.condition(s.ship, slot)
		var fault := Condition.fault_loss(s.ship, slot)
		p[1].add_child(UI.label("Fitted: %s  (%s)  condition %d%%%s" % [current["name"], _module_stats(current), int(round(cond * 100.0)), "  FAULT: %s" % s.ship["faults"][slot]["text"] if fault > 0.0 else ""], UI.WARN if cond < 0.4 or fault > 0.0 else UI.TEXT))
		var work := HBoxContainer.new()
		for level in ["service", "overhaul"]:
			var bill := ShipBill.quote(s, d, {"services": [{"slot": slot, "level": level}]})
			if bill["ok"]:
				work.add_child(UI.button("%s %s, %.1f d" % [level.capitalize(), UI.money(bill["total"]), bill["days"]], send.bind({"type": level, "slot": slot}), bill["afford"]))
		p[1].add_child(work)
		for module_id in stock:
			var m: Dictionary = d.modules[module_id]
			if not ShipyardSystem.fits(m, slot) or module_id == s.ship["modules"][slot]:
				continue
			var bill := ShipBill.quote(s, d, {"swaps": [{"slot": slot, "module": module_id}]})
			var row := HBoxContainer.new()
			var l := UI.label("%s  (%s)" % [m["name"], _module_stats(m)], UI.DIM)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(UI.button("Fit for %s, %.1f d" % [UI.money(bill["total"]), bill["days"]], send.bind({"type": "install_module", "slot": slot, "module": module_id}), bill["ok"] and bill["afford"]))
			p[1].add_child(row)
		parts[1].add_child(p[0])
	return parts[0]


func _open_builder() -> void:
	var b := preload("res://view/ship_builder_screen.gd").new(sim)
	b.closed.connect(refresh)
	add_child(b)


## Warrant of Fitness and insurance at the yard, with what each action costs.
func _fitness_panel() -> Control:
	var s = sim.state
	var d = sim.data
	var p := UI.panel("Warrant of Fitness and insurance")
	var w := Fitness.status(s, d)
	var wtext := "Warrant of Fitness: %s" % w["state"]
	if w["state"] in ["valid", "expiring"] and is_finite(w["days_left"]):
		wtext += " (%d days left)" % int(w["days_left"])
	p[1].add_child(UI.label(wtext, UI.GOOD if w["valid"] else UI.WARN))
	for issue in w["issues"]:
		p[1].add_child(UI.label("  to fix: %s" % issue, UI.WARN, 13))
	var inspect := ShipBill.quote(s, d, {"inspect": true})
	var row := HBoxContainer.new()
	row.add_child(UI.button("Inspect for %s" % UI.money(inspect["total"]), send.bind({"type": "inspect"}), inspect["ok"] and inspect["afford"]))
	for level in ["service", "overhaul"]:
		var all := ShipBill.quote(s, d, {"service_all": level})
		if all["ok"]:
			row.add_child(UI.button("%s all %s, %.1f d" % [level.capitalize(), UI.money(all["total"]), all["days"]], send.bind({"type": level, "slot": "all"}), all["afford"]))
	p[1].add_child(row)
	var ins := Insurance.status(s, d)
	var itext := "Insurance: none"
	if ins["state"] != "none":
		itext = "Insurance: %s, %s" % [d.ship_economy["insurance"]["plans"][ins["plan"]]["name"], ins["state"]]
		if ins["state"] == "active":
			itext += " (%d days left, excess %s)" % [int(ins["days_left"]), UI.money(ins["excess"])]
		else:
			itext += ": " + ins["reason"]
	p[1].add_child(UI.label(itext, UI.GOOD if ins["state"] == "active" else UI.WARN))
	if float(s.insurance.get("loan_cr", 0.0)) > 0.0:
		p[1].add_child(UI.label("Commons hull loan outstanding: %s" % UI.money(s.insurance["loan_cr"]), UI.AMBER, 13))
	var plans := HBoxContainer.new()
	for id in d.ship_economy["insurance"]["plans"]:
		var prem := float(Insurance.premium(s, d, id)["per_period"])
		var block := Insurance.buy_block(s, d, id)
		plans.add_child(UI.button("%s: %s / %d d" % [id.capitalize(), UI.money(prem), int(d.ship_economy["insurance"]["period_days"])], send.bind({"type": "buy_insurance", "plan": id}), block == "" and prem <= s.credits))
	p[1].add_child(plans)
	return p[0]


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
	if m.has("life_support_days"):
		bits.append("+%d days life support" % int(m["life_support_days"]))
	if m.has("berths"):
		bits.append("%d berths" % int(m["berths"]))
	if m.get("lander", false):
		bits.append("surface landings")
	if m.get("survey", false):
		bits.append("surveys")
	if m.get("mining", false):
		bits.append("prospecting and mining")
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
	for t in ShipStats.active_tunes(s.ship, d):
		v.add_child(UI.label("  Tune: %s (%s)  ·  %s" % [Favours.tune_name(d, t["id"]), Favours.tune_effects(d, t["id"]), t["source"]], UI.GOOD, 12))
	var heat := ShipStats.heat_ratio(s.ship, d)
	v.add_child(UI.label("Heat    %d%% of radiator capacity%s" % [int(heat * 100.0), "  (drive throttled)" if heat > 1.0 else ""], UI.WARN if heat > 1.0 else UI.TEXT))
	var hull := DamageSystem.integrity(s.ship)
	v.add_child(UI.label("Keel    %d%%" % int(round(hull * 100.0)), UI.GOOD if hull > 0.99 else (UI.TEXT if hull > 0.7 else UI.WARN)))
	for slot in s.ship.get("damage", {}):
		if slot != "keel" and float(s.ship["damage"][slot]) > 0.005:
			v.add_child(UI.label("  %s  %d%% damaged" % [d.modules[s.ship["modules"][slot]]["name"], int(round(float(s.ship["damage"][slot]) * 100.0))], UI.WARN, 13))
	var repair := DamageSystem.repair_cost(s, d)
	if repair > 0.5 and not d.places[place_id].has("foot_of"):
		var at_yard: bool = "shipyard" in d.places[place_id].get("services", [])
		v.add_child(UI.button(("Repair  (%s)" if at_yard else "Patch up  (%s)") % UI.money(repair), send.bind({"type": "repair"}), repair <= s.credits))
	var services: Array = d.locations[place_id].get("services", [])
	if "refuel" in services:
		var need := minf(fuel_cap - float(s.ship["fuel_t"]), Market.stock(s, place_id, "propellant"))
		var terms := Favours.fuel_terms(s, d, place_id)
		var paid_need := maxf(0.0, need - float(terms["free_t"]))
		var cost := Market.buy_cost(s, d, place_id, "propellant", paid_need) * float(terms["mult"]) if paid_need > 0.01 else 0.0
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
		if not preload("res://sim/systems/npc_system.gd").in_service(npc, s.time_s):
			continue
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
		if st.is_empty() or not ProjectSystem.open_to_player(s, d, id):
			continue
		var here: bool = project["place"] == place_id
		var title: String = project["name"] + ("   (here)" if here else "   at " + d.places[project["place"]]["name"])
		if project.has("invite"):
			title += "   ·   by invitation"
		var p := UI.panel(title)
		var v: VBoxContainer = p[1]
		var desc := UI.label(project["description"], UI.DIM, 12)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(200, 0)
		v.add_child(desc)
		# The pitch: why back it, what they plan, what backers get.
		var pitch: Dictionary = project.get("pitch", {})
		for line in [["Why", pitch.get("why", "")], ["Plan", pitch.get("plan", "")], ["On offer", pitch.get("offer", "")]]:
			if line[1] != "":
				var l := UI.label("%s:  %s" % line, UI.TEXT, 12)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD
				l.custom_minimum_size = Vector2(200, 0)
				v.add_child(l)
		var earned: Array = s.perks.get("_earned", [])
		var perks: Array = project.get("perks", [])
		for i in perks.size():
			var perk: Dictionary = perks[i]
			var got: bool = ("%s/%d" % [id, i]) in earned
			v.add_child(UI.label("      %s  %s  (haul %d t)" % ["[x]" if got else "[ ]", perk["text"], int(perk["min_t"])], UI.GOOD if got else UI.DIM, 12))
		var total := ProjectSystem.progress(s, d, id)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = total
		bar.custom_minimum_size = Vector2(0, 10)
		bar.show_percentage = false
		v.add_child(bar)
		var stages: Array = project["stages"]
		for i in stages.size():
			var mark := "[x]" if st["done"] or i < int(st["stage"]) else ("[>]" if i == int(st["stage"]) else "[ ]")
			var colour := UI.GOOD if mark == "[x]" else (UI.AMBER if mark == "[>]" else UI.DIM)
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


## The Spaceline: the system's news, newest first, in Earth Standard Time.
func _news_tab() -> Control:
	var parts := _scroll("Spaceline")
	var s = sim.state
	var d = sim.data
	var items: Array = s.news.get("items", [])
	parts[1].add_child(UI.label("The Spaceline: news from across the system. All times Earth Standard.", UI.DIM, 13))
	if items.is_empty():
		parts[1].add_child(UI.label("Nothing on the wire yet.", UI.DIM, 13))
	for i in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var stamp := Time.get_datetime_dict_from_unix_time(int(float(item["t"]) + preload("res://sim/game_state.gd").J2000_UNIX))
		var months := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
		var when := "%02d %s %d  %02d:%02d EST" % [stamp["day"], months[int(stamp["month"]) - 1], stamp["year"], stamp["hour"], stamp["minute"]]
		var dateline := String(item.get("dateline", "")).to_upper()
		v.add_child(UI.label(when + ("   ·   " + dateline if dateline != "" else ""), UI.DIM, 11))
		var head := UI.label(item["headline"], UI.AMBER, 15)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD
		head.custom_minimum_size = Vector2(200, 0)
		v.add_child(head)
		if String(item.get("body", "")) != "":
			var body := UI.label(item["body"], UI.TEXT, 12)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD
			body.custom_minimum_size = Vector2(200, 0)
			v.add_child(body)
		var pid: String = item.get("project", "")
		if pid != "" and d.projects.has(pid) and ProjectSystem.open_to_player(s, d, pid) and not s.projects.get(pid, {}).get("done", false):
			v.add_child(UI.label("Backers and haulers wanted: see Projects.", UI.GOOD, 12))
		parts[1].add_child(v)
		parts[1].add_child(HSeparator.new())
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
