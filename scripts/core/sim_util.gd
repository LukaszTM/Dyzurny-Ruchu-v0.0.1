class_name SimUtil
extends RefCounted
## Funkcje pomocnicze — formatowanie czasu i opóźnień.


static func fmt_time(sec: float) -> String:
	var t := int(sec)
	@warning_ignore("integer_division")
	var h := (t / 3600) % 24
	@warning_ignore("integer_division")
	var m := (t / 60) % 60
	var s := t % 60
	return "%02d:%02d:%02d" % [h, m, s]


static func fmt_hm(sec: float) -> String:
	if sec < 0:
		return "—"
	var t := int(round(sec))
	@warning_ignore("integer_division")
	var h := (t / 3600) % 24
	@warning_ignore("integer_division")
	var m := (t / 60) % 60
	return "%02d:%02d" % [h, m]


static func parse_hhmm(txt: String) -> float:
	var parts := txt.split(":")
	if parts.size() < 2:
		return -1.0
	return float(int(parts[0]) * 3600 + int(parts[1]) * 60)


static func fmt_delay(minutes: int) -> String:
	if minutes <= 0:
		return ""
	return " (+%d min)" % minutes


static func fmt_signed(minutes: int) -> String:
	if minutes == 0:
		return "0"
	return "%+d" % minutes
