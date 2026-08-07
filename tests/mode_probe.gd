extends Node
## Sonda trybów i ekranów. Uruchamia symulację w trybie wskazanym zmienną
## SIM_MODE (timetable/random/tutorial), przyspiesza ją, automatycznie
## odpowiada na rozmowy przychodzące i cyklicznie przełącza wszystkie ekrany,
## aby wychwycić błędy czasu wykonania w interfejsie.
##
##   SIM_MODE=random godot --headless --path . res://tests/ModeProbe.tscn --quit-after 8000

const EKRANY := [
	GameState.SCENE_PANEL, GameState.SCENE_TIMETABLE, GameState.SCENE_EDR,
	GameState.SCENE_EVENTS, GameState.SCENE_COMMS,
]

var i := 0
var t := 0.0


func _ready() -> void:
	var mode := OS.get_environment("SIM_MODE")
	if mode == "":
		mode = GameState.MODE_RANDOM
	Settings.online_enabled = false
	Settings.traffic_intensity = 40.0
	Settings.event_freq_min = 1.0 if mode != GameState.MODE_TUTORIAL else 0.0
	GameState.start_simulation(mode, "warszawa_wschodnia")
	print("SONDA TRYBU: ", mode)


func _process(delta: float) -> void:
	var sim := GameState.sim as SimCore
	if sim == null:
		return
	sim.time_scale = 20.0
	# automatyczna obsługa łączności, aby ruch nie stanął
	for c in sim.comms.pending_calls():
		sim.comms.answer_call(int(c["id"]), true)
	for tr: Train in sim.trains.values():
		if tr.actual_arr >= 0.0 and not tr.manewrowy:
			sim.comms.confirm_arrival(tr)
		if tr.state == Train.State.GOTOWY and sim.comms.permission_status(tr.id) == "":
			sim.comms.ask_permission(tr)
	for ev in sim.events.active:
		if not bool(ev["zgloszona"]):
			sim.comms.report_fault(int(ev["id"]), sim.comms.sluzba_for_event(str(ev["typ"])))
	t += delta
	if t >= 1.2:
		t = 0.0
		i += 1
		GameState.open_scene(EKRANY[i % EKRANY.size()])
