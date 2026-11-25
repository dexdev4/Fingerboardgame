## The Eldwood's day: time runs from 0 (dawn) to 1 (next dawn); the last `night_fraction` is a
## cold, dark night. You can sleep through it in your bed from `sleep_from` onward.
class_name DayNight
extends RefCounted

signal night_ended   ## dawn after a night (survived awake or slept through)

var t: GameTuning
var time: float
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


func can_sleep() -> bool:
	return time >= t.sleep_from


## Sleep until dawn (only call when can_sleep()). Counts as a night survived.
func sleep() -> void:
	time = t.start_time
	day += 1
	night_ended.emit()


## Daylight 0..1: 1 by day, 0 at night, with smooth dawn and dusk.
func daylight() -> float:
	var dusk := 1.0 - t.night_fraction
	var up := smoothstep(0.0, 0.05, time)
	var down := 1.0 - smoothstep(dusk - 0.05, dusk + 0.025, time)
	return clampf(minf(up, down), 0.0, 1.0)


func light() -> float:
	return lerpf(t.night_light, 1.0, daylight())


## "Day 3 14:20" (a day is shown as 24 hours, dawn = 06:00).
func clock_text() -> String:
	var hours := fmod(time * 24.0 + 6.0, 24.0)
	return "Day %d %02d:%02d" % [day, int(hours), int(fmod(hours, 1.0) * 60.0)]
