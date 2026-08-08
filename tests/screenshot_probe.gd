extends Node
## Zrzuty ekranów do weryfikacji wizualnej (wymaga okna, np. Xvfb):
##   SCREENSHOT_DIR=/tmp xvfb-run godot --path . res://tests/ScreenshotProbe.tscn
## Osadza ekrany jako własne dzieci (nie podmienia sceny głównej), dzięki
## czemu sonda przeżywa przełączanie ekranów i zapisuje PNG każdego z nich.

var sim: SimCore
var ekran: Node = null
var faza := 0
var t := 0.0
var dir := ""


func _ready() -> void:
	dir = OS.get_environment("SCREENSHOT_DIR")
	if dir == "":
		dir = OS.get_user_data_dir()
	Settings.online_enabled = false
	Settings.event_freq_min = 0.0
	GameState.mode = GameState.MODE_TIMETABLE
	sim = SimCore.new()
	add_child(sim)
	sim.setup(GameState.MODE_TIMETABLE, "warszawa_wschodnia")
	sim.events.freq_min = 0.0
	sim.events.next_at = -1.0
	GameState.sim = sim
	_pokaz(GameState.SCENE_PANEL)
	print("PROBE: start")


func _pokaz(path: String) -> void:
	if ekran != null:
		ekran.queue_free()
	var scena: PackedScene = load(path)
	ekran = scena.instantiate()
	add_child(ekran)


func _process(delta: float) -> void:
	if sim == null:
		return
	t += delta
	match faza:
		0:
			if t > 1.0:
				for c in sim.comms.pending_calls():
					sim.comms.answer_call(int(c["id"]), true)
				sim.time_scale = 10.0
				faza = 1
				t = 0.0
		1:
			if t > 1.5:
				sim.set_cmd_mode(SimCore.CMD_PP)
				sim.click_element("signal", "C")
				sim.click_element("signal", "N5")
				sim.events.force_event(sim.sim_time, "przeszkoda", "")
				sim.time_scale = 2.0
				faza = 2
				t = 0.0
		2:
			# czekaj na utwierdzenie przebiegu (zielona droga jak w LCS)
			var r: Dictionary = sim.inter.route_of_signal("C")
			var utw: bool = not r.is_empty() and str(r["state"]) == Interlocking.ST_UTWIERDZONY
			if (utw and t > 2.5) or t > 12.0:
				_shot("panel")
				_pokaz(GameState.SCENE_TIMETABLE)
				faza = 3
				t = 0.0
		3:
			if t > 1.0:
				_shot("wykaz_jasny" if not Settings.wykaz_ciemny else "wykaz_ciemny")
				Settings.wykaz_ciemny = not Settings.wykaz_ciemny
				_pokaz(GameState.SCENE_TIMETABLE)
				faza = 6
				t = 0.0
		6:
			if t > 1.0:
				_shot("wykaz_ciemny" if Settings.wykaz_ciemny else "wykaz_jasny")
				_pokaz(GameState.SCENE_COMMS)
				faza = 4
				t = 0.0
		4:
			if t > 1.0:
				_shot("lacznosc")
				_pokaz(GameState.SCENE_EDR)
				faza = 5
				t = 0.0
		5:
			if t > 1.0:
				_shot("edr")
				get_tree().quit(0)


func _shot(nazwa: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s/zrzut_%s.png" % [dir, nazwa]
	img.save_png(path)
	print("ZRZUT: ", path)
