## Price rules, shared by the economy system, the view and the balance bot.
##
## The price multiplier at stock s is clamp((target / s) ^ e, min, max). A trade of
## t tonnes is charged the exact integral of that curve over the stock it moves
## through: buying walks stock down from s to s - t, selling walks it up from s to
## s + t. Because a round trip retraces the same stretch of curve, buying in one go
## and selling back in slices (or the reverse) can never create money; only the
## spread is lost.
extends RefCounted


static func target(data, place: String, good: String) -> float:
	return float(data.places[place]["market"][good])


static func trades(data, place: String, good: String) -> bool:
	return data.places[place].get("market", {}).has(good)


static func _mult(data, place: String, good: String, stock: float) -> float:
	var e: Dictionary = data.balance["economy"]
	var ratio := target(data, place, good) / maxf(stock, 1e-9)
	return clampf(pow(ratio, float(e["price_elasticity"])), float(e["price_min_mult"]), float(e["price_max_mult"]))


## Mid price at a given stock level.
static func mid_price_at(data, place: String, good: String, stock: float) -> float:
	return float(data.goods[good]["base_price"]) * _mult(data, place, good, stock)


## Integral of the price multiplier over stock in [a, b] (tonnes x multiplier).
static func _mult_integral(data, place: String, good: String, a: float, b: float) -> float:
	if b <= a:
		return 0.0
	var e: Dictionary = data.balance["economy"]
	var k := float(e["price_elasticity"])
	var lo := float(e["price_min_mult"])
	var hi := float(e["price_max_mult"])
	var tgt := target(data, place, good)
	# Stock below s_cap sits at the price ceiling; above s_floor, at the floor.
	var s_cap := tgt * pow(hi, -1.0 / k)
	var s_floor := tgt * pow(lo, -1.0 / k)
	var total := 0.0
	total += hi * maxf(0.0, minf(b, s_cap) - a)
	total += lo * maxf(0.0, b - maxf(a, s_floor))
	var c0 := maxf(a, s_cap)
	var c1 := minf(b, s_floor)
	if c1 > c0:
		if absf(k - 1.0) < 1e-9:
			total += tgt * log(c1 / c0)
		else:
			total += pow(tgt, k) * (pow(c1, 1.0 - k) - pow(c0, 1.0 - k)) / (1.0 - k)
	return total


static func stock(state, place: String, good: String) -> float:
	return float(state.markets.get(place, {}).get(good, 0.0))


## Credits per tonne the player pays to buy `tonnes` (average over the trade).
static func buy_price(state, data, place: String, good: String, tonnes: float = 0.0) -> float:
	var spread := 1.0 + float(data.balance["economy"]["spread"]) * 0.5
	var s := stock(state, place, good)
	if tonnes <= 1e-9:
		return mid_price_at(data, place, good, s) * spread
	return float(data.goods[good]["base_price"]) * _mult_integral(data, place, good, s - tonnes, s) / tonnes * spread


## Credits per tonne the player receives for selling `tonnes` (average over the trade).
static func sell_price(state, data, place: String, good: String, tonnes: float = 0.0) -> float:
	var spread := 1.0 - float(data.balance["economy"]["spread"]) * 0.5
	var s := stock(state, place, good)
	if tonnes <= 1e-9:
		return mid_price_at(data, place, good, s) * spread
	return float(data.goods[good]["base_price"]) * _mult_integral(data, place, good, s, s + tonnes) / tonnes * spread


## Total cost of buying `tonnes`.
static func buy_cost(state, data, place: String, good: String, tonnes: float) -> float:
	return buy_price(state, data, place, good, tonnes) * tonnes


## The most tonnes affordable with `credits`, up to `limit` (bisection on the exact cost).
static func affordable_tonnes(state, data, place: String, good: String, credits: float, limit: float) -> float:
	if limit <= 0.0 or credits <= 0.0:
		return 0.0
	if buy_cost(state, data, place, good, limit) <= credits:
		return limit
	var lo := 0.0
	var hi := limit
	for _i in 50:
		var mid := 0.5 * (lo + hi)
		if buy_cost(state, data, place, good, mid) <= credits:
			lo = mid
		else:
			hi = mid
	return lo
