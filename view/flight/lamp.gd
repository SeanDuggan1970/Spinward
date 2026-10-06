## A light that flashes on its own: attached to the lit part of a lamp (Kit.nav_light)
## or to a simple beacon (Kit.beacon). It runs on the real-time clock, not game time,
## so time compression never speeds it up, and every view gets it without asking.
## Lamps with the same period and phase flash together.
##   flash    a soft pulse: a quick rise and a slower fade (red and green positions)
##   strobe   a double white flash (anti-collision)
##   beacon   a rotating beacon's sweep, rising and falling (red, on top of drives)
##   blink    hard on, hard off (simple beacons)
## halo, if set, is scaled with the pulse, so the glow swells and fades with it.
extends Node3D

var period := 1.0
var phase := 0.0
var kind := "blink"
var halo: Node3D


func _process(_dt: float) -> void:
	var f := fposmod(float(Time.get_ticks_msec()) / 1000.0 / maxf(period, 0.05) + phase, 1.0)
	var e := envelope(kind, f)
	visible = e > 0.01
	if halo != null:
		halo.scale = Vector3.ONE * maxf(e, 0.001)


## Brightness 0 to 1 at fraction f of the cycle.
static func envelope(kind: String, f: float) -> float:
	match kind:
		"flash":
			return smoothstep(0.0, 0.03, f) * (1.0 - smoothstep(0.1, 0.32, f))
		"strobe":
			return maxf(1.0 - smoothstep(0.0, 0.035, f), 1.0 - smoothstep(0.0, 0.035, absf(f - 0.14))) if f < 0.2 else 0.0
		"beacon":
			return pow(maxf(sin(TAU * f), 0.0), 3.0)
		"steady":
			return 1.0
	return 1.0 if f < 0.18 else 0.0
