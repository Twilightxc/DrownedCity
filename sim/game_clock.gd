class_name GameClock
extends RefCounted
## SimCore in-game time. Pure data: the simulation ticks once per in-game hour.

const HOURS_PER_DAY: int = 24

var day: int = 1
var hour: int = 0


func _init(start_day: int = 1, start_hour: int = 0) -> void:
	assert(start_day >= 1, "day starts at 1")
	assert(start_hour >= 0 and start_hour < HOURS_PER_DAY, "hour out of range")
	day = start_day
	hour = start_hour


func advance_hours(hours: int) -> void:
	assert(hours >= 0, "time only moves forward")
	var total: int = hour + hours
	day += total / HOURS_PER_DAY
	hour = total % HOURS_PER_DAY


func total_hours() -> int:
	return (day - 1) * HOURS_PER_DAY + hour
