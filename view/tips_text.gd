## Words for tips and price knowledge. Presentation only.
extends RefCounted

const UI := preload("res://view/ui/ui_kit.gd")


## The broker's own words for a tip.
static func line(sim, tip: Dictionary) -> String:
	var broker: Dictionary = sim.data.brokers.get(tip["broker"], {})
	var options: Array = broker.get(tip["kind"], ["{good} at {place}: {price}"])
	var template: String = options[int(tip.get("template", 0)) % options.size()]
	return template.format({
		"good": String(sim.data.goods[tip["good"]]["name"]).to_lower(),
		"place": sim.data.places[tip["place"]]["name"],
		"price": "%d" % int(round(float(tip["price"]))),
		"broker": broker.get("name", "?"),
	})


static func age(sim, t: float) -> String:
	var dt: float = sim.state.time_s - t
	if dt < 120.0:
		return "just now"
	return UI.duration(dt) + " ago"


static func status(tip: Dictionary) -> Array:
	if tip["verified"] == true:
		return ["HELD UP", UI.GOOD]
	if tip["verified"] == false:
		return ["WRONG", UI.WARN]
	if tip.get("expired", false):
		return ["EXPIRED", UI.DIM]
	return ["UNCHECKED", UI.AMBER]


static func record_text(sim, broker_id: String) -> String:
	var rec: Dictionary = sim.state.broker_record.get(broker_id, {})
	var good := int(rec.get("good", 0))
	var bad := int(rec.get("bad", 0))
	if good + bad == 0:
		return "no track record with you yet"
	return "with you: %d held up, %d wrong" % [good, bad]
