class_name TrafficGenerator
extends RefCounted
## Generator ruchu losowego. Natężenie (pociągi/h) ustawiane w opcjach gry.

const NAZWY := ["Podlasiak", "Sawa", "Hetman", "Kmicic", "Bug", "Narew", "Cukrownik",
	"Żeromski", "Norwid", "Skarga", "Chopin", "Reymont", "Wysoczańska", "Bolesław Prus"]

var sim = null
var rng := RandomNumberGenerator.new()
var enabled := false
var next_spawn := -1.0
var next_shunt := -1.0
var _n := 0


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()


func step(now: float) -> void:
	if not enabled:
		return
	if next_spawn < 0.0:
		next_spawn = now + 20.0
	if next_shunt < 0.0:
		next_shunt = now + rng.randf_range(600.0, 1400.0)
	if now >= next_spawn:
		sim.request_train(_random_spec(now))
		var mean := 3600.0 / maxf(Settings.traffic_intensity, 1.0)
		next_spawn = now + maxf(30.0, -log(1.0 - rng.randf()) * mean)
	if Settings.shunting_enabled and now >= next_shunt:
		_shunt_job(now)
		next_shunt = now + rng.randf_range(800.0, 1600.0)


func _nr(base: int) -> String:
	_n += 1
	return str(base + _n * 2 + rng.randi_range(0, 1))


func _random_spec(now: float) -> Dictionary:
	var spec := {
		"nazwa": "", "arr": now + 200.0, "dep": -1.0, "postoj": 0.0,
		"przelot": false, "koniec": false, "man": false, "tt_index": -1,
		"delay": 0, "podstawienie": false,
	}
	var roll := rng.randf()
	if roll < 0.44:
		# ruch podmiejski (tory 1-4)
		var na_wschod := rng.randf() < 0.5
		spec["kat"] = "AOE" if rng.randf() < 0.55 else "ROJ"
		spec["nr"] = _nr(21000 if spec["kat"] == "AOE" else 91000)
		if na_wschod:
			spec["we"] = "it1P"
			spec["wy"] = "it1W"
			spec["z"] = "W-wa Zachodnia" if spec["kat"] == "ROJ" else "Pruszków"
			spec["do"] = "Otwock" if rng.randf() < 0.6 else "Mińsk Mazowiecki"
			spec["tor"] = ["1", "3"][rng.randi_range(0, 1)]
		else:
			spec["we"] = "it2W"
			spec["wy"] = "it2P"
			spec["z"] = "Otwock" if rng.randf() < 0.6 else "Mińsk Mazowiecki"
			spec["do"] = "W-wa Zachodnia" if spec["kat"] == "ROJ" else "Pruszków"
			spec["tor"] = ["2", "4"][rng.randi_range(0, 1)]
		spec["postoj"] = rng.randf_range(60.0, 150.0)
		spec["dep"] = float(spec["arr"]) + float(spec["postoj"])
	elif roll < 0.80:
		# ruch dalekobieżny (tory 5-8)
		var na_wschod2 := rng.randf() < 0.5
		var r := rng.randf()
		spec["kat"] = "MPE" if r < 0.45 else ("EIE" if r < 0.7 else ("EIP" if r < 0.85 else "MOE"))
		spec["nr"] = _nr(1000 if spec["kat"] == "MPE" else 4000)
		if spec["kat"] in ["EIP", "EIE"] and rng.randf() < 0.7:
			spec["nazwa"] = NAZWY[rng.randi_range(0, NAZWY.size() - 1)]
		if na_wschod2:
			spec["we"] = "it1D"
			var przez_otwock := rng.randf() < 0.35
			spec["wy"] = "it1W" if przez_otwock else "it1R"
			spec["z"] = "W-wa Zachodnia"
			spec["do"] = "Lublin Główny" if przez_otwock else ("Białystok" if rng.randf() < 0.5 else "Terespol")
			spec["tor"] = ["5", "7"][rng.randi_range(0, 1)]
		else:
			var z_otwocka := rng.randf() < 0.35
			spec["we"] = "it2W" if z_otwocka else "it2R"
			spec["wy"] = "it2D"
			spec["z"] = "Lublin Główny" if z_otwocka else ("Białystok" if rng.randf() < 0.5 else "Terespol")
			spec["do"] = "W-wa Zachodnia"
			spec["tor"] = ["6", "8"][rng.randi_range(0, 1)]
			if Settings.shunting_enabled and rng.randf() < 0.14:
				spec["koniec"] = true
				spec["wy"] = "itG"
				spec["do"] = "W-wa Wschodnia"
		spec["postoj"] = rng.randf_range(120.0, 300.0)
		spec["dep"] = float(spec["arr"]) + float(spec["postoj"])
		spec["delay"] = rng.randi_range(1, 12) if rng.randf() < 0.3 else 0
	else:
		# ruch towarowy — przelot
		spec["kat"] = "TME" if rng.randf() < 0.5 else "TDE"
		spec["nr"] = _nr(44000)
		spec["przelot"] = true
		if rng.randf() < 0.5:
			spec["we"] = "it1D"
			spec["wy"] = "it1R"
			spec["z"] = "Pruszków"
			spec["do"] = "Małaszewicze"
			spec["tor"] = "7"
		else:
			spec["we"] = "it2R"
			spec["wy"] = "it2D"
			spec["z"] = "Małaszewicze"
			spec["do"] = "Pruszków"
			spec["tor"] = "8"
	return spec


func _shunt_job(now: float) -> void:
	var tor: String = ["5", "6", "7", "8"][rng.randi_range(0, 3)]
	sim.request_train({
		"nr": "Pm%d" % rng.randi_range(100, 999), "kat": "MAN", "nazwa": "",
		"z": "Grochów", "do": "tor %s" % tor,
		"we": "itG", "wy": "itG", "tor": tor,
		"arr": now, "dep": -1.0, "postoj": 0.0,
		"przelot": false, "koniec": false, "man": true,
		"tt_index": -1, "delay": 0, "podstawienie": true,
	})
