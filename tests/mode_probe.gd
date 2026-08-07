extends Node
## Sonda trybów i ekranów. Tworzy symulację, przyspiesza ją, automatycznie
## odpowiada na rozmowy przychodzące i cyklicznie osadza wszystkie ekrany
## jako własne dzieci (nie podmienia sceny głównej — sonda żyje cały czas),
## aby wychwycić błędy czasu wykonania w interfejsie.
##
##   SIM_MODE=random godot --headless --path . res://tests/ModeProbe.tscn --quit-after 8000

const EKRANY := [
	GameState.SCENE_PANEL, GameState.SCENE_TIMETABLE, GameState.SCENE_EDR,
	GameState.SCENE_EVENTS, GameState.SCENE_COMMS,
]

var sim: SimCore
var ekran: Node = null
var i := 0
var t := 0.0
var cykle := 0


func _ready() -> void:
	var mode := OS.get_environment("SIM_MODE")
	if mode == "":
		mode = GameState.MODE_RANDOM
	Settings.online_enabled = false
	Settings.traffic_intensity = 40.0
	Settings.event_freq_min = 1.0 if mode != GameState.MODE_TUTORIAL else 0.0
	GameState.mode = mode
	sim = SimCore.new()
	add_child(sim)
	sim.setup(mode, "warszawa_wschodnia")
	GameState.sim = sim
	sim.time_scale = 20.0
	if mode != GameState.MODE_TUTORIAL:
		sim.events.freq_min = 1.0
		sim.events.schedule_next(sim.sim_time)
	_pokaz(0)
	print("SONDA TRYBU: ", mode)


func _pokaz(idx: int) -> void:
	if ekran != null:
		ekran.queue_free()
	var scena: PackedScene = load(EKRANY[idx % EKRANY.size()])
	ekran = scena.instantiate()
	add_child(ekran)


func _process(delta: float) -> void:
	if sim == null:
		return
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
		cykle += 1
		_pokaz(i)
		if cykle % EKRANY.size() == 0:
			print("SONDA: pełny cykl ekranów nr %d" % (cykle / EKRANY.size()))
