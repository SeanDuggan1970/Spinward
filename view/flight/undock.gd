## Leaving a docking bay (balance.undock): the doors open, the ship eases backwards
## out of the bay on its thrusters, turning with the station; once clear it stops the
## roll, unfolds and turns for its burn. Pure timing, shared by the ship view (what
## you see) and the transit audio (what you hear), in game seconds since departure.
extends RefCounted


## How far the ship has backed from its berth (metres) at tau.
static func moved(cfg: Dictionary, tau: float) -> float:
	var x := tau - float(cfg["move_at_s"])
	if x <= 0.0:
		return 0.0
	var a := float(cfg["accel_mps2"])
	var v := float(cfg["speed_mps"])
	var ta := v / a
	if x < ta:
		return 0.5 * a * x * x
	return 0.5 * a * ta * ta + v * (x - ta)


## Is the ship accelerating backwards (its thrusters pushing) at tau?
static func pushing(cfg: Dictionary, tau: float) -> bool:
	var x := tau - float(cfg["move_at_s"])
	return x >= 0.0 and x < float(cfg["speed_mps"]) / float(cfg["accel_mps2"])


## When the nose is clear_m past the mouth, for a bay `depth` deep (the nose starts
## `start_gap` off the port).
static func clear_t(cfg: Dictionary, depth: float, start_gap: float) -> float:
	var need := depth + float(cfg["clear_m"]) - start_gap
	var a := float(cfg["accel_mps2"])
	var v := float(cfg["speed_mps"])
	var ta := v / a
	var s_a := 0.5 * a * ta * ta
	if need <= s_a:
		return float(cfg["move_at_s"]) + sqrt(2.0 * need / a)
	return float(cfg["move_at_s"]) + ta + (need - s_a) / v


## When the ship stops holding its berth's attitude and turns for its burn.
static func turn_t(cfg: Dictionary, clear: float) -> float:
	return clear + float(cfg["roll_stop_s"]) + float(cfg["settle_s"])


## The ship's roll rate as a share of the station's spin at tau: 1 while it is in the
## bay, braking smoothly to 0 over roll_stop_s once clear.
static func roll_share(cfg: Dictionary, tau: float, clear: float) -> float:
	var x := (tau - clear) / float(cfg["roll_stop_s"])
	if x <= 0.0:
		return 1.0
	if x >= 1.0:
		return 0.0
	return 1.0 - x * x * (3.0 - 2.0 * x)


## The roll (radians) the ship has turned through since it cleared, braking from the
## station's spin rate `rate`: the integral of roll_share.
static func roll_after(cfg: Dictionary, tau: float, clear: float, rate: float) -> float:
	var T := float(cfg["roll_stop_s"])
	var x := clampf((tau - clear) / T, 0.0, 1.0)
	# Integral of 1 - (3x^2 - 2x^3) over [0, x], times T.
	return rate * T * (x - x * x * x + 0.5 * x * x * x * x)
