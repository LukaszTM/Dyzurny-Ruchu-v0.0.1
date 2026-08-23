class_name LcsWorld
extends RefCounted
## LCS-lite (docs/systemy/14 §5): jedno stanowisko steruje kilkoma
## posterunkami. Każdy posterunek to pełny SimWorld; wspólny szlak łączy
## je MOSTKIEM — pociąg, który odjechał z posterunku A w stronę wspólnego
## sąsiada, po czasie jazdy pojawia się w rozkładzie posterunku B i wchodzi
## normalnym obiegiem zapowiadania. Uproszczenia (WERYFIKACJA): zapowiedzi
## na wspólnym szlaku prowadzi automatyka mostka, awarie łącza nie są
## modelowane, zapis gry w trybie LCS odłożony.

## Posterunki (kolejność = zakładki GUI).
var posts: Array[SimWorld] = []
var names: Array[String] = []
## Mostki: {a, a_neighbour, a_to, a_track, b, b_neighbour, b_to, b_track,
## run_s} — a/b to indeksy posterunków.
var links: Array[Dictionary] = []
var pending_events: Array[Dictionary] = []
## Pociągi już przekazane mostkiem (nr → true) — bez dubli.
var _transferred: Dictionary = {}
var sim_time: float = 0.0


## Wczytuje zestaw LCS: {"posts": [{"scenario": "res://..."}...],
## "links": [...]}. Zwraca {ok, errors}.
func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "errors": ["nie można otworzyć zestawu LCS: %s" % path]}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not (parsed is Dictionary):
		return {"ok": false, "errors": ["zestaw LCS %s nie jest poprawnym JSON" % path]}
	var data: Dictionary = parsed
	var config: Dictionary = data.get("lcs", {})
	var errors: Array[String] = []
	for post_variant: Variant in (config.get("posts", []) as Array):
		var post_def: Dictionary = post_variant
		var world := SimWorld.new()
		var result := world.load_scenario_file(String(post_def.get("scenario", "")))
		if not result["ok"]:
			errors.append_array(result["errors"])
			continue
		posts.append(world)
		names.append(world.station.display_name())
	for link_variant: Variant in (config.get("links", []) as Array):
		links.append(link_variant as Dictionary)
	if posts.size() < 2:
		errors.append("zestaw LCS wymaga co najmniej 2 posterunków")
	return {"ok": errors.is_empty(), "errors": errors, "meta": data.get("meta", {})}


## Wspólny krok: tyka wszystkie posterunki, przekazuje pociągi mostkami
## i zbiera zdarzenia (oznaczone posterunkiem — GUI pokazuje źródło).
func tick(dt: float) -> void:
	sim_time += dt
	for i: int in posts.size():
		posts[i].tick(dt)
	_bridge()
	for i: int in posts.size():
		for event: Dictionary in posts[i].drain_events():
			event["post"] = i
			event["post_name"] = names[i]
			pending_events.append(event)


func drain_events() -> Array[Dictionary]:
	var out := pending_events
	pending_events = []
	return out


## Polecenie gracza do wskazanego posterunku.
func execute(post: int, name: StringName, args: Dictionary) -> CommandResult:
	if post < 0 or post >= posts.size():
		return CommandResult.failure("nie ma posterunku %d" % post)
	return posts[post].execute(name, args)


## Mostek: pociąg, który odjechał w stronę wspólnego sąsiada i zniknął
## ze świata posterunku, po czasie jazdy trafia do rozkładu drugiego.
func _bridge() -> void:
	for link: Dictionary in links:
		_bridge_direction(link, int(link["a"]), String(link["a_neighbour"]),
			int(link["b"]), String(link["b_neighbour"]), String(link.get("b_to", "")),
			String(link.get("b_track", "")))
		_bridge_direction(link, int(link["b"]), String(link["b_neighbour"]),
			int(link["a"]), String(link["a_neighbour"]), String(link.get("a_to", "")),
			String(link.get("a_track", "")))


func _bridge_direction(link: Dictionary, from_post: int, from_neighbour: String,
		to_post: int, to_neighbour: String, far_station: String,
		track: String) -> void:
	var source := posts[from_post]
	var target := posts[to_post]
	for entry: Timetable.Entry in source.timetable.entries:
		if _transferred.has(entry.nr) or not entry.spawned:
			continue
		if not source.train_departed(entry.nr):
			continue
		if source.train_exit_neighbour(entry.nr) != from_neighbour:
			continue
		if _train_still_present(source, entry.nr):
			continue
		_transferred[entry.nr] = true
		var run_s := float(link.get("run_s", 150.0))
		var handed := Timetable.Entry.new()
		handed.nr = entry.nr
		handed.kind = entry.kind
		handed.from_station = to_neighbour
		handed.to_station = far_station if not far_station.is_empty() else entry.to_station
		handed.arr_s = int(target.time_of_day_s() + run_s)
		handed.stop = entry.stop
		handed.dep_s = handed.arr_s + (60 if handed.stop else 0)
		handed.track = track
		handed.len_m = entry.len_m
		handed.vmax_kmh = entry.vmax_kmh
		handed.mass_t = entry.mass_t
		handed.power_class = entry.power_class
		target.timetable.entries.append(handed)
		for ai: NeighbourAI in target.neighbours:
			ai.add_incoming(handed)
		pending_events.append({"type": &"alarm", "post": to_post,
			"post_name": names[to_post],
			"text": "LCS: pociąg %s przekazany na %s (przyjazd ok. %s)" % [
				handed.nr, names[to_post], Comms.format_time(float(handed.arr_s))]})


func _train_still_present(world: SimWorld, nr: String) -> bool:
	for train: Train in world.trains:
		if train.nr == nr:
			return true
	return false
