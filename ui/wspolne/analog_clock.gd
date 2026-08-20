class_name AnalogClock
extends Control
## Zegar wskazówkowy pulpitu (assets-spec/20 §5), rysowany wektorowo.
## Pokazuje czas symulacji z GameState.

const COL_FACE := Color("F4EFE2")
const COL_MARKS := Color("2B2B2B")


func _ready() -> void:
	custom_minimum_size = Vector2(30.0, 30.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(center.x, center.y) - 1.0
	draw_circle(center, radius, COL_MARKS)
	draw_circle(center, radius - 1.5, COL_FACE)
	for i: int in 12:
		var angle := TAU * float(i) / 12.0
		var dir := Vector2.from_angle(angle)
		draw_line(center + dir * (radius - 4.0), center + dir * (radius - 2.5), COL_MARKS, 1.0)
	var seconds_of_day := fmod(GameState.time_of_day_s(), 86400.0)
	var hours := fmod(seconds_of_day / 3600.0, 12.0)
	var minutes := fmod(seconds_of_day / 60.0, 60.0)
	var hour_dir := Vector2.from_angle(TAU * hours / 12.0 - TAU / 4.0)
	var minute_dir := Vector2.from_angle(TAU * minutes / 60.0 - TAU / 4.0)
	draw_line(center, center + hour_dir * (radius * 0.5), COL_MARKS, 2.0)
	draw_line(center, center + minute_dir * (radius * 0.78), COL_MARKS, 1.5)
	draw_circle(center, 1.8, COL_MARKS)
