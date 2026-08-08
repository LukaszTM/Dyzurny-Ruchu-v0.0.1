extends Node
## Sprawdza, że zadokowane tabele ZDARZENIA/ALARMY na pulpicie wypełniają się
## wpisami EDR i czynnymi usterkami.
##   godot --headless --path . res://tests/DockProbe.tscn --quit-after 12000

var sim: SimCore
var ekran: Node
var t := 0.0
var faza := 0


func _ready() -> void:
	Settings.online_enabled = false
	GameState.mode = GameState.MODE_TIMETABLE
	sim = SimCore.new()
	add_child(sim)
	sim.setup(GameState.MODE_TIMETABLE, "warszawa_wschodnia")
	sim.events.freq_min = 0.0
	sim.events.next_at = -1.0
	GameState.sim = sim
	sim.time_scale = 5.0
	sim.edr.add(sim.sim_time, "Dyżurny", "Wpis testowy dziennika.", "12345", "3")
	sim.events.force_event(sim.sim_time, "rozjazd", "")
	var scena: PackedScene = load(GameState.SCENE_PANEL)
	ekran = scena.instantiate()
	add_child(ekran)


func _process(delta: float) -> void:
	t += delta
	if faza == 0 and t > 2.5:
		faza = 1
		var zd: Tree = ekran.get("tree_zd")
		var al: Tree = ekran.get("tree_al")
		var n_zd: int = zd.get_root().get_child_count() if zd.get_root() != null else 0
		var n_al: int = al.get_root().get_child_count() if al.get_root() != null else 0
		print("DOCK: zdarzenia=%d alarmy=%d (edr=%d, usterki=%d)" % [
			n_zd, n_al, sim.edr.entries.size(), sim.events.active.size()])
		var ok: bool = n_zd >= 1 and n_zd == mini(40, sim.edr.entries.size()) \
			and n_al == sim.events.active.size() and n_al >= 1
		print("TEST DOKU: ", "OK" if ok else "NIEPOWODZENIE")
		get_tree().quit(0 if ok else 1)
