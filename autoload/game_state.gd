extends Node
## Właściciel działającej symulacji. Symulacja żyje jako dziecko tego
## autoloadu, dzięki czemu przełączanie scen (pulpit / rozkład / EDR /
## zdarzenia / łączność) nie przerywa prowadzenia ruchu.

const MODE_RANDOM := "random"
const MODE_TIMETABLE := "timetable"
const MODE_TUTORIAL := "tutorial"

const SCENE_MENU := "res://scenes/MainMenu.tscn"
const SCENE_PANEL := "res://scenes/Panel.tscn"
const SCENE_TIMETABLE := "res://scenes/RozkladJazdy.tscn"
const SCENE_EDR := "res://scenes/EDR.tscn"
const SCENE_EVENTS := "res://scenes/Zdarzenia.tscn"
const SCENE_COMMS := "res://scenes/Lacznosc.tscn"

var sim: Node = null
var mode: String = MODE_TIMETABLE
var location_id: String = "warszawa_wschodnia"


func mode_name() -> String:
	match mode:
		MODE_RANDOM:
			return "Ruch losowy"
		MODE_TUTORIAL:
			return "Tryb nauki"
		_:
			return "Realny rozkład jazdy"


func start_simulation(p_mode: String, p_location: String) -> void:
	stop_simulation()
	mode = p_mode
	location_id = p_location
	var core := SimCore.new()
	core.name = "SimCore"
	add_child(core)
	sim = core
	core.setup(p_mode, p_location)
	open_scene(SCENE_PANEL)


func stop_simulation() -> void:
	if sim != null and is_instance_valid(sim):
		if Settings.autosave_edr and sim.edr != null:
			sim.edr.save_to_file()
		sim.queue_free()
	sim = null


func open_scene(path: String) -> void:
	# odroczone — zmiana sceny z wnętrza _ready() albo sygnału jest niebezpieczna
	get_tree().change_scene_to_file.call_deferred(path)


func back_to_panel() -> void:
	open_scene(SCENE_PANEL)


func back_to_menu() -> void:
	stop_simulation()
	open_scene(SCENE_MENU)
