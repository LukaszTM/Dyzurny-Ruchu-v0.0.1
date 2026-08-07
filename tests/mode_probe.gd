extends Node
## Sonda trybów: uruchamia symulator w trybie z zmiennej środowiskowej
## SIM_MODE (random/timetable/tutorial) w przyspieszeniu, do wychwycenia
## błędów runtime. Uruchomienie:
##   SIM_MODE=random godot --headless --path . res://tests/ModeProbe.tscn --quit-after 4000

var sim = null


func _ready() -> void:
	var mode := OS.get_environment("SIM_MODE")
	if mode == "":
		mode = GameState.MODE_RANDOM
	GameState.mode = mode
	GameState.location_id = "warszawa_wschodnia"
	var scene: PackedScene = load("res://scenes/Simulator.tscn")
	sim = scene.instantiate()
	add_child(sim)
	print("MODE PROBE: ", mode)


func _process(_delta: float) -> void:
	if sim == null:
		return
	sim.time_scale = 20.0
	if sim.gen.enabled:
		sim.gen.intensity = 40.0
	if sim.events.freq_min > 0.0:
		sim.events.freq_min = 1.0
