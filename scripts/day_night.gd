## Tessaris's day: time runs from 0 (dawn) to 1 (next dawn). The last `night_fraction` of each
## day is night: darker and colder (the suit heater drains power outside the ship).
class_name DayNight
extends RefCounted

signal night_ended   ## fired at dawn after a night (a night survived)

var t: GameTuning
## Fraction of the current day, 0..1.
var time: float
## Days since the crash (day 1 = the crash day).
var day := 1


func _init(tuning: GameTuning) -> void:
	t = tuning
	time = t.start_time


func tick(dt: float) -> void:
	time += dt / t.day_length
	if time >= 1.0:
		time -= 1.0
		day += 1
		night_ended.emit()


func is_night() -> bool:
	return time >= 1.0 - t.night_fraction


## Daylight 0..1: 1 at midday, 0 in the dead of night, with smooth dusk and dawn.
func daylight() -> float:
	var dusk := 1.0 - t.night_fraction
	var edge := 0.05
	var up := smoothstep(0.0, edge, time)                       # dawn brightening
	var down := 1.0 - smoothstep(dusk - edge, dusk + edge * 0.5, time)   # dusk darkening
	return clampf(minf(up, down), 0.0, 1.0)


## Light level for the world (CanvasModulate brightness): night_light at night, 1 by day.
func light() -> float:
	return lerpf(t.night_light, 1.0, daylight())


## "Day 3, 14:20"-style clock for the HUD (a Tessaris day is shown as 24 hours, dawn = 06:00).
func clock_text() -> String:
	var hours := fmod(time * 24.0 + 6.0, 24.0)
	return "Day %d  %02d:%02d" % [day, int(hours), int(fmod(hours, 1.0) * 60.0)]
