extends Node
## Stan przejścia między menu a symulacją.

const MODE_RANDOM := "random"
const MODE_TIMETABLE := "timetable"
const MODE_TUTORIAL := "tutorial"

var mode: String = MODE_TIMETABLE
var location_id: String = "warszawa_wschodnia"


func mode_name() -> String:
	match mode:
		MODE_RANDOM:
			return "Ruch losowy"
		MODE_TUTORIAL:
			return "Samouczek"
		_:
			return "Ruch rozkładowy"


func start_simulation(p_mode: String, p_location: String) -> void:
	mode = p_mode
	location_id = p_location
	get_tree().change_scene_to_file("res://scenes/Simulator.tscn")


func back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
