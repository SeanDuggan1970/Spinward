## Price rules, shared by the economy system, the view and the balance bot.
extends RefCounted


static func target(data, place: String, good: String) -> float:
	return float(data.places[place]["market"][good])


static func trades(data, place: String, good: String) -> bool:
	return data.places[place].get("market", {}).has(good)


## Mid price at a given stock level.
static func mid_price_at(data, place: String, good: String, stock: float) -> float:
	var e: Dictionary = data.balance["economy"]
	var ratio := target(data, place, good) / maxf(stock, 0.01)
	var mult := clampf(pow(ratio, float(e["price_elasticity"])), float(e["price_min_mult"]), float(e["price_max_mult"]))
	return float(data.goods[good]["base_price"]) * mult


static func stock(state, place: String, good: String) -> float:
	return float(state.markets.get(place, {}).get(good, 0.0))


## Credits per tonne the player pays to buy `tonnes` (priced at the mid-trade stock).
static func buy_price(state, data, place: String, good: String, tonnes: float = 0.0) -> float:
	var s := stock(state, place, good) - tonnes * 0.5
	return mid_price_at(data, place, good, s) * (1.0 + float(data.balance["economy"]["spread"]) * 0.5)


## Credits per tonne the player receives for selling `tonnes`.
static func sell_price(state, data, place: String, good: String, tonnes: float = 0.0) -> float:
	var s := stock(state, place, good) + tonnes * 0.5
	return mid_price_at(data, place, good, s) * (1.0 - float(data.balance["economy"]["spread"]) * 0.5)
