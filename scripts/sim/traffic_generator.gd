class_name TrafficGenerator
extends RefCounted
## Generator ruchu losowego. Natężenie (pociągi/h) regulowane suwakiem.
## Generuje pociągi podmiejskie, dalekobieżne, towarowe oraz zlecenia
## manewrowe (podstawienia składów z zaplecza Grochów).

const IC_NAMES := ["Podlasiak", "Sawa", "Hetman", "Kmicic", "Bug", "Narew", "Cukrownik", "Żeromski", "Norwid", "Skarga"]

var sim = null
var rng := RandomNumberGenerator.new()
var enabled := false
var intensity := 16.0     # pociągi na godzinę
var next_spawn_at := -1.0
var next_shunt_at := -1.0
var _nr_counter := 0


func _init(p_sim) -> void:
	sim = p_sim
	rng.randomize()


func step(now: float) -> void:
	if not enabled:
		return
	if next_spawn_at < 0.0:
		next_spawn_at = now + 8.0
	if next_shunt_at < 0.0:
		next_shunt_at = now + rng.randf_range(600.0, 1200.0)
	if now >= next_spawn_at:
		sim.spawn_from_spec(_random_spec(now))
		var mean := 3600.0 / maxf(intensity, 1.0)
		next_spawn_at = now + maxf(25.0, -log(1.0 - rng.randf()) * mean)
	if now >= next_shunt_at:
		_spawn_shunt_job(now)
		next_shunt_at = now + rng.randf_range(700.0, 1500.0)


func _next_nr(base: int) -> String:
	_nr_counter += 1
	return str(base + _nr_counter * 2 + rng.randi_range(0, 1))


func _random_spec(now: float) -> Dictionary:
	var roll := rng.randf()
	var spec := {
		"nazwa": "", "arr_sec": now + 150.0, "dep_sec": -1.0,
		"przelot": false, "koniec": false, "man": false, "tt_index": -1,
		"delay_min": 0,
	}
	if roll < 0.45:
		# ruch podmiejski
		var east := rng.randf() < 0.5
		spec["kat"] = "SKM" if rng.randf() < 0.55 else "KM"
		spec["nr"] = _next_nr(21000 if spec["kat"] == "SKM" else 91000)
		if east:
			spec["we"] = "WP1"
			spec["wy"] = "EP2" if rng.randf() < 0.5 else "EP1"
			spec["z"] = "Pruszków" if spec["kat"] == "SKM" else "W-wa Zachodnia"
			spec["do"] = "Otwock" if spec["wy"] == "EP2" else "Mińsk Mazowiecki"
			spec["tor"] = ["1", "2"][rng.randi_range(0, 1)]
			if rng.randf() < 0.25:
				spec["wy"] = "WP2"   # kończy bieg i wraca na zachód
				spec["do"] = "W-wa Wschodnia (powrót)"
		else:
			spec["we"] = "EP2" if rng.randf() < 0.5 else "EP1"
			spec["wy"] = "WP2"
			spec["z"] = "Otwock" if spec["we"] == "EP2" else "Mińsk Mazowiecki"
			spec["do"] = "Pruszków" if spec["kat"] == "SKM" else "W-wa Zachodnia"
			spec["tor"] = ["3", "4"][rng.randi_range(0, 1)]
		spec["dep_sec"] = spec["arr_sec"] + rng.randf_range(90.0, 240.0)
	elif roll < 0.80:
		# ruch dalekobieżny
		var east2 := rng.randf() < 0.5
		var kat_roll := rng.randf()
		spec["kat"] = "IC" if kat_roll < 0.5 else ("TLK" if kat_roll < 0.8 else "EIP")
		spec["nr"] = _next_nr(1000 if spec["kat"] == "IC" else (21000 if spec["kat"] == "TLK" else 4000))
		if spec["kat"] != "TLK" and rng.randf() < 0.5:
			spec["nazwa"] = IC_NAMES[rng.randi_range(0, IC_NAMES.size() - 1)]
		if east2:
			spec["we"] = "WD1"
			spec["wy"] = "ED1" if rng.randf() < 0.5 else "ED2"
			spec["z"] = "W-wa Zachodnia"
			spec["do"] = "Białystok" if spec["wy"] == "ED1" else "Lublin Gł."
			spec["tor"] = ["5", "6"][rng.randi_range(0, 1)]
		else:
			spec["we"] = "ED1" if rng.randf() < 0.5 else "ED2"
			spec["wy"] = "WD2"
			spec["z"] = "Białystok" if spec["we"] == "ED1" else "Lublin Gł."
			spec["do"] = "W-wa Zachodnia"
			spec["tor"] = ["7", "8"][rng.randi_range(0, 1)]
			if rng.randf() < 0.15:
				spec["koniec"] = true
				spec["wy"] = "GR"
				spec["do"] = "W-wa Wschodnia"
		spec["dep_sec"] = spec["arr_sec"] + rng.randf_range(150.0, 300.0)
		spec["delay_min"] = rng.randi_range(0, 8) if rng.randf() < 0.3 else 0
	else:
		# ruch towarowy (przelot)
		spec["kat"] = "TME"
		spec["nr"] = _next_nr(44000)
		spec["przelot"] = true
		if rng.randf() < 0.5:
			spec["we"] = "WD2"
			spec["wy"] = "GR" if rng.randf() < 0.35 else "ED1"
			spec["z"] = "Pruszków"
			spec["do"] = "Grochów (bocznica)" if spec["wy"] == "GR" else "Małaszewicze"
			spec["tor"] = "9" if spec["wy"] == "GR" else "8"
		else:
			spec["we"] = "ED1"
			spec["wy"] = "WD2"
			spec["z"] = "Małaszewicze"
			spec["do"] = "Pruszków"
			spec["tor"] = "7"
	return spec


func _spawn_shunt_job(now: float) -> void:
	var target_track: String = ["5", "6", "7", "8"][rng.randi_range(0, 3)]
	var spec := {
		"nr": "M%d" % rng.randi_range(100, 999),
		"kat": "MAN", "nazwa": "",
		"z": "Grochów", "do": "tor %s" % target_track,
		"we": "GR", "wy": "GR",
		"tor": target_track,
		"arr_sec": now, "dep_sec": -1.0,
		"przelot": false, "koniec": false, "man": true, "tt_index": -1,
		"delay_min": 0,
	}
	var t: Train = sim.spawn_from_spec(spec)
	if t != null:
		sim.add_shunt_job("podstawienie",
			"Podstawić skład %s z Grochowa na tor %s (jazda manewrowa)." % [t.nr, target_track],
			t.id)
