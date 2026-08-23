class_name StationLoader
extends RefCounted
## Loader i walidacja pliku stacji JSON (docs/03-model-danych.md, §7).
## Waliduje: spójność grafu, kompletność sekcji, istnienie elementów
## przebiegów, symetrię konfliktów. Błąd walidacji = czytelny komunikat
## z id elementu (kluczowe dla moderów). Wynik: {ok, errors, station}.

const REQUIRED_KEYS: Array[String] = [
	"meta", "nodes", "edges", "turnouts", "sections", "signals", "routes",
]


## Wczytuje i waliduje plik stacji. Zwraca {ok: bool, errors: Array[String],
## station: StationData|null}.
static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail(["nie można otworzyć pliku stacji: %s" % path])
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return _fail(["plik %s nie jest poprawnym dokumentem JSON (obiekt)" % path])
	return parse(parsed)


## Waliduje słownik stacji i buduje obiekty rdzenia.
static func parse(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	_validate(data, errors)
	if not errors.is_empty():
		return _fail(errors)
	return {"ok": true, "errors": [] as Array[String], "station": _build(data)}


static func _fail(errors: Array[String]) -> Dictionary:
	return {"ok": false, "errors": errors, "station": null}


# ---------------------------------------------------------------------------
# Walidacja
# ---------------------------------------------------------------------------

static func _validate(data: Dictionary, errors: Array[String]) -> void:
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			errors.append("brak wymaganej sekcji pliku: '%s'" % key)
	if not errors.is_empty():
		return
	if String((data["meta"] as Dictionary).get("id", "")).is_empty():
		errors.append("meta: brak identyfikatora stacji (meta.id)")

	var node_ids := _collect_ids(data["nodes"], "węzeł", errors)
	var edge_ids := _collect_ids(data["edges"], "krawędź", errors)
	var turnout_ids := _collect_ids(data["turnouts"], "zwrotnica", errors)
	var section_ids := _collect_ids(data["sections"], "sekcja", errors)
	var signal_ids := _collect_ids(data["signals"], "sygnalizator", errors)
	var route_ids := _collect_ids(data["routes"], "przebieg", errors)
	var block_ids := _collect_ids(data.get("blocks", []), "blokada", errors)
	var crossing_ids := _collect_ids(data.get("crossings", []), "przejazd", errors)
	var dsat_ids := _collect_ids(data.get("dsat", []), "dSAT", errors)

	_validate_edges(data["edges"], node_ids, errors)
	_validate_turnouts(data["turnouts"], data["edges"], node_ids, edge_ids, errors)
	_validate_sections(data["sections"], edge_ids, turnout_ids, errors)
	_validate_signals(data["signals"], node_ids, edge_ids, signal_ids, errors)
	_validate_routes(
		data["routes"], section_ids, turnout_ids, signal_ids, route_ids, block_ids, errors
	)
	_validate_blocks(data.get("blocks", []), signal_ids, errors)
	_validate_blocks_sections(data.get("blocks", []), section_ids, errors)
	_validate_crossings(data.get("crossings", []), section_ids, errors)
	_validate_dsat(data.get("dsat", []), edge_ids, errors)
	_validate_panel(
		data.get("panel", {}), section_ids, turnout_ids, signal_ids, block_ids,
		route_ids, crossing_ids, dsat_ids, errors
	)


## Zbiera id elementów listy, zgłaszając braki i duplikaty. Zwraca zbiór id
## (Dictionary jako set: id -> true).
static func _collect_ids(items: Variant, label: String, errors: Array[String]) -> Dictionary:
	var ids := {}
	if not (items is Array):
		errors.append("%s: lista elementów musi być tablicą" % label)
		return ids
	for item: Variant in (items as Array):
		if not (item is Dictionary):
			errors.append("%s: element listy nie jest obiektem" % label)
			continue
		var id := String((item as Dictionary).get("id", ""))
		if id.is_empty():
			errors.append("%s: element bez pola 'id'" % label)
		elif ids.has(id):
			errors.append("%s '%s': zduplikowane id" % [label, id])
		else:
			ids[id] = true
	return ids


static func _validate_edges(
	edges: Array, node_ids: Dictionary, errors: Array[String]
) -> void:
	for item: Variant in edges:
		var edge: Dictionary = item
		var id := String(edge.get("id", "?"))
		for endpoint: String in ["from", "to"]:
			var node := String(edge.get(endpoint, ""))
			if not node_ids.has(node):
				errors.append("krawędź '%s': węzeł '%s' (%s) nie istnieje" % [id, node, endpoint])
		if float(edge.get("len_m", 0.0)) <= 0.0:
			errors.append("krawędź '%s': len_m musi być > 0" % id)
		if float(edge.get("vmax_kmh", 0.0)) <= 0.0:
			errors.append("krawędź '%s': vmax_kmh musi być > 0" % id)


static func _validate_turnouts(
	turnouts: Array,
	edges: Array,
	node_ids: Dictionary,
	edge_ids: Dictionary,
	errors: Array[String],
) -> void:
	# Indeks krawędzi po id do sprawdzenia styku z węzłem zwrotnicy.
	var edge_by_id := {}
	for item: Variant in edges:
		edge_by_id[String((item as Dictionary).get("id", ""))] = item
	for item: Variant in turnouts:
		var turnout: Dictionary = item
		var id := String(turnout.get("id", "?"))
		var node := String(turnout.get("node", ""))
		if not node_ids.has(node):
			errors.append("zwrotnica '%s': węzeł '%s' nie istnieje" % [id, node])
		var edge_keys: Array[String] = ["edge_root", "edge_plus", "edge_minus"]
		var seen_edges := {}
		for key: String in edge_keys:
			var edge_id := String(turnout.get(key, ""))
			if not edge_ids.has(edge_id):
				errors.append("zwrotnica '%s': krawędź '%s' (%s) nie istnieje" % [id, edge_id, key])
				continue
			if seen_edges.has(edge_id):
				errors.append("zwrotnica '%s': krawędź '%s' użyta wielokrotnie" % [id, edge_id])
			seen_edges[edge_id] = true
			var edge: Dictionary = edge_by_id[edge_id]
			if String(edge.get("from", "")) != node and String(edge.get("to", "")) != node:
				errors.append(
					"zwrotnica '%s': krawędź '%s' nie styka się z węzłem '%s'" % [id, edge_id, node]
				)
		if float(turnout.get("throw_time_s", 0.0)) <= 0.0:
			errors.append("zwrotnica '%s': throw_time_s musi być > 0" % id)


static func _validate_sections(
	sections: Array, edge_ids: Dictionary, turnout_ids: Dictionary, errors: Array[String]
) -> void:
	var edge_owner := {}    # krawędź -> id sekcji (kompletność: krawędź w ≤1 sekcji)
	var turnout_owner := {} # zwrotnica -> id sekcji
	for item: Variant in sections:
		var section: Dictionary = item
		var id := String(section.get("id", "?"))
		var type := String(section.get("type", ""))
		if not Const.SECTION_TYPE_FROM_STRING.has(type):
			errors.append("sekcja '%s': nieznany typ '%s'" % [id, type])
			continue
		var section_edges: Array = section.get("edges", [])
		for edge_variant: Variant in section_edges:
			var edge_id := String(edge_variant)
			if not edge_ids.has(edge_id):
				errors.append("sekcja '%s': krawędź '%s' nie istnieje" % [id, edge_id])
			elif edge_owner.has(edge_id):
				errors.append(
					"sekcja '%s': krawędź '%s' należy już do sekcji '%s'"
					% [id, edge_id, edge_owner[edge_id]]
				)
			else:
				edge_owner[edge_id] = id
		if type == "turnout":
			var turnout_id := String(section.get("turnout", ""))
			if turnout_id.is_empty():
				errors.append("sekcja '%s': typ 'turnout' wymaga pola 'turnout'" % id)
			elif not turnout_ids.has(turnout_id):
				errors.append("sekcja '%s': zwrotnica '%s' nie istnieje" % [id, turnout_id])
			elif turnout_owner.has(turnout_id):
				errors.append(
					"sekcja '%s': zwrotnica '%s' należy już do sekcji '%s'"
					% [id, turnout_id, turnout_owner[turnout_id]]
				)
			else:
				turnout_owner[turnout_id] = id
		elif section_edges.is_empty():
			errors.append("sekcja '%s': typ '%s' wymaga niepustej listy krawędzi" % [id, type])


static func _validate_signals(
	signals: Array,
	node_ids: Dictionary,
	edge_ids: Dictionary,
	signal_ids: Dictionary,
	errors: Array[String],
) -> void:
	for item: Variant in signals:
		var signal_def: Dictionary = item
		var id := String(signal_def.get("id", "?"))
		var kind := String(signal_def.get("kind", ""))
		if not Const.SIGNAL_KIND_FROM_STRING.has(kind):
			errors.append("sygnalizator '%s': nieznany rodzaj '%s'" % [id, kind])
		var dir := String(signal_def.get("dir", ""))
		if not Const.DIRECTIONS.has(dir):
			errors.append("sygnalizator '%s': kierunek '%s' (dozwolone: N/P)" % [id, dir])
		var at_node := String(signal_def.get("at_node", ""))
		var on_edge := String(signal_def.get("on_edge", ""))
		if at_node.is_empty() and on_edge.is_empty():
			errors.append("sygnalizator '%s': wymagane 'at_node' albo 'on_edge'" % id)
		if not at_node.is_empty() and not node_ids.has(at_node):
			errors.append("sygnalizator '%s': węzeł '%s' nie istnieje" % [id, at_node])
		if not on_edge.is_empty() and not edge_ids.has(on_edge):
			errors.append("sygnalizator '%s': krawędź '%s' nie istnieje" % [id, on_edge])
		var for_signal := String(signal_def.get("for_signal", ""))
		if not for_signal.is_empty() and not signal_ids.has(for_signal):
			errors.append("sygnalizator '%s': semafor '%s' (for_signal) nie istnieje" % [id, for_signal])
		var to_id := String(signal_def.get("tarcza_ostrzegawcza", ""))
		if not to_id.is_empty() and not signal_ids.has(to_id):
			errors.append(
				"sygnalizator '%s': tarcza ostrzegawcza '%s' nie istnieje" % [id, to_id]
			)


static func _validate_routes(
	routes: Array,
	section_ids: Dictionary,
	turnout_ids: Dictionary,
	signal_ids: Dictionary,
	route_ids: Dictionary,
	block_ids: Dictionary,
	errors: Array[String],
) -> void:
	var conflicts_of := {} # id przebiegu -> Dictionary(set) konfliktów
	for item: Variant in routes:
		var route: Dictionary = item
		var id := String(route.get("id", "?"))
		var entry := String(route.get("entry_signal", ""))
		if not signal_ids.has(entry):
			errors.append("przebieg '%s': semafor początkowy '%s' nie istnieje" % [id, entry])
		var exit_value: Variant = route.get("exit_signal")
		if exit_value != null and not String(exit_value).is_empty() \
				and not signal_ids.has(String(exit_value)):
			errors.append("przebieg '%s': semafor końcowy '%s' nie istnieje" % [id, exit_value])
		var route_sections: Array = route.get("sections", [])
		if route_sections.is_empty():
			errors.append("przebieg '%s': pusta lista sekcji" % id)
		for section_variant: Variant in route_sections:
			if not section_ids.has(String(section_variant)):
				errors.append("przebieg '%s': sekcja '%s' nie istnieje" % [id, section_variant])
		_validate_turnout_positions(route.get("turnouts", {}), id, "turnouts", turnout_ids, errors)
		var flank: Dictionary = route.get("flank", {}) if route.get("flank") != null else {}
		for flank_key: Variant in flank:
			var key := String(flank_key)
			if key == "signals_at_stop":
				for signal_variant: Variant in (flank[flank_key] as Array):
					if not signal_ids.has(String(signal_variant)):
						errors.append(
							"przebieg '%s': sygnalizator osłaniający '%s' nie istnieje"
							% [id, signal_variant]
						)
			else:
				_validate_turnout_positions({key: flank[flank_key]}, id, "flank", turnout_ids, errors)
		var overlap: Variant = route.get("overlap")
		if overlap != null and overlap is Dictionary:
			for section_variant: Variant in ((overlap as Dictionary).get("sections", []) as Array):
				if not section_ids.has(String(section_variant)):
					errors.append(
						"przebieg '%s': sekcja drogi ochronnej '%s' nie istnieje" % [id, section_variant]
					)
			_validate_turnout_positions(
				(overlap as Dictionary).get("turnouts", {}), id, "overlap", turnout_ids, errors
			)
		var block := String(route.get("block", ""))
		if not block.is_empty() and not block_ids.has(block):
			errors.append("przebieg '%s': blokada '%s' nie istnieje" % [id, block])
		var conflict_set := {}
		for conflict_variant: Variant in (route.get("conflicts", []) as Array):
			var conflict := String(conflict_variant)
			if conflict == id:
				errors.append("przebieg '%s': konflikt z samym sobą" % id)
			elif not route_ids.has(conflict):
				errors.append("przebieg '%s': konfliktowy przebieg '%s' nie istnieje" % [id, conflict])
			conflict_set[conflict] = true
		conflicts_of[id] = conflict_set
	# Symetria konfliktów (docs/03 §7): jeśli A wymienia B, to B wymienia A.
	for route_id: Variant in conflicts_of:
		for conflict_id: Variant in (conflicts_of[route_id] as Dictionary):
			if conflicts_of.has(conflict_id) \
					and not (conflicts_of[conflict_id] as Dictionary).has(route_id):
				errors.append(
					"przebiegi '%s' i '%s': konflikty niesymetryczne ('%s' nie wymienia '%s')"
					% [route_id, conflict_id, conflict_id, route_id]
				)


static func _validate_turnout_positions(
	positions: Dictionary,
	route_id: String,
	field: String,
	turnout_ids: Dictionary,
	errors: Array[String],
) -> void:
	for turnout_variant: Variant in positions:
		var turnout_id := String(turnout_variant)
		if not turnout_ids.has(turnout_id):
			errors.append(
				"przebieg '%s' (%s): zwrotnica '%s' nie istnieje" % [route_id, field, turnout_id]
			)
		var position := String(positions[turnout_variant])
		if not Const.TURNOUT_POS_FROM_STRING.has(position):
			errors.append(
				"przebieg '%s' (%s): niepoprawne położenie '%s' zwrotnicy '%s' (PLUS/MINUS)"
				% [route_id, field, position, turnout_id]
			)


static func _validate_blocks(
	blocks: Array, signal_ids: Dictionary, errors: Array[String]
) -> void:
	for item: Variant in blocks:
		var block: Dictionary = item
		var id := String(block.get("id", "?"))
		var entry := String(block.get("entry_signal", ""))
		if not entry.is_empty() and not signal_ids.has(entry):
			errors.append("blokada '%s': semafor '%s' (entry_signal) nie istnieje" % [id, entry])
		for signal_variant: Variant in (block.get("exit_signals", []) as Array):
			if not signal_ids.has(String(signal_variant)):
				errors.append(
					"blokada '%s': semafor '%s' (exit_signals) nie istnieje" % [id, signal_variant]
				)
		for signal_variant: Variant in (block.get("signals", []) as Array):
			var line_signal := String(signal_variant)
			if not line_signal.is_empty() and not signal_ids.has(line_signal):
				errors.append(
					"blokada '%s': semafor odstępowy '%s' nie istnieje" % [id, line_signal]
				)


static func _validate_blocks_sections(
	blocks: Array, section_ids: Dictionary, errors: Array[String]
) -> void:
	for item: Variant in blocks:
		var block: Dictionary = item
		var id := String(block.get("id", "?"))
		for section_variant: Variant in (block.get("odstepy", []) as Array):
			if not section_ids.has(String(section_variant)):
				errors.append("blokada '%s': odstęp '%s' nie istnieje" % [id, section_variant])


static func _validate_crossings(
	crossings: Array, section_ids: Dictionary, errors: Array[String]
) -> void:
	for item: Variant in crossings:
		var crossing: Dictionary = item
		var id := String(crossing.get("id", "?"))
		for section_variant: Variant in (crossing.get("on_sections", []) as Array):
			if not section_ids.has(String(section_variant)):
				errors.append("przejazd '%s': sekcja '%s' nie istnieje" % [id, section_variant])


static func _validate_dsat(
	dsat: Array, edge_ids: Dictionary, errors: Array[String]
) -> void:
	for item: Variant in dsat:
		var device: Dictionary = item
		var id := String(device.get("id", "?"))
		var edge := String(device.get("on_edge", ""))
		if not edge_ids.has(edge):
			errors.append("dSAT '%s': krawędź '%s' nie istnieje" % [id, edge])


## Lekka walidacja opisu pulpitu: odwołania kafelków do obiektów rdzenia.
## Pełna walidacja układu graficznego — w F2 (widok pulpitu).
static func _validate_panel(
	panel: Dictionary,
	section_ids: Dictionary,
	turnout_ids: Dictionary,
	signal_ids: Dictionary,
	block_ids: Dictionary,
	route_ids: Dictionary,
	crossing_ids: Dictionary,
	dsat_ids: Dictionary,
	errors: Array[String],
) -> void:
	if panel.is_empty():
		return
	# Panel mechaniczny (docs/systemy/12): dźwignie i bloki stacyjne.
	var lever_ids := {}
	for lever_variant: Variant in (panel.get("levers", []) as Array):
		var lever: Dictionary = lever_variant
		var lever_id := String(lever.get("id", "?"))
		if lever_ids.has(lever_id):
			errors.append("dźwignia '%s': zduplikowane id" % lever_id)
		lever_ids[lever_id] = true
		var lever_type := String(lever.get("type", ""))
		if not LeverFrame.TYPE_FROM_STRING.has(lever_type):
			errors.append("dźwignia '%s': nieznany typ '%s'" % [lever_id, lever_type])
			continue
		match lever_type:
			"zwrotnicowa":
				if not turnout_ids.has(String(lever.get("turnout", ""))):
					errors.append("dźwignia '%s': zwrotnica '%s' nie istnieje"
						% [lever_id, lever.get("turnout", "")])
			"ryglowa":
				for turnout_variant: Variant in (lever.get("turnouts", []) as Array):
					if not turnout_ids.has(String(turnout_variant)):
						errors.append("dźwignia '%s': zwrotnica '%s' nie istnieje"
							% [lever_id, turnout_variant])
			"sygnalowa":
				if not signal_ids.has(String(lever.get("signal", ""))):
					errors.append("dźwignia '%s': sygnalizator '%s' nie istnieje"
						% [lever_id, lever.get("signal", "")])
	for block_variant: Variant in (panel.get("station_blocks", []) as Array):
		var station_block: Dictionary = block_variant
		var sb_id := String(station_block.get("id", "?"))
		for route_variant: Variant in (station_block.get("routes", []) as Array):
			if not route_ids.has(String(route_variant)):
				errors.append("blok '%s': przebieg '%s' nie istnieje" % [sb_id, route_variant])
	var tile_index: int = 0
	for tile_variant: Variant in (panel.get("tiles", []) as Array):
		var tile: Dictionary = tile_variant
		var where := "panel.tiles[%d]" % tile_index
		tile_index += 1
		# Pusta sekcja = kostka ozdobna (tor biegnie poza plan, bez lampki).
		if tile.has("section") and not String(tile["section"]).is_empty() \
				and not section_ids.has(String(tile["section"])):
			errors.append("%s: sekcja '%s' nie istnieje" % [where, tile["section"]])
		if tile.has("turnout") and not turnout_ids.has(String(tile["turnout"])):
			errors.append("%s: zwrotnica '%s' nie istnieje" % [where, tile["turnout"]])
		if tile.has("signal") and not signal_ids.has(String(tile["signal"])):
			errors.append("%s: sygnalizator '%s' nie istnieje" % [where, tile["signal"]])
		if tile.has("block") and not block_ids.has(String(tile["block"])):
			errors.append("%s: blokada '%s' nie istnieje" % [where, tile["block"]])
		if tile.has("crossing") and not crossing_ids.has(String(tile["crossing"])):
			errors.append("%s: przejazd '%s' nie istnieje" % [where, tile["crossing"]])
		if tile.has("dsat") and not dsat_ids.has(String(tile["dsat"])):
			errors.append("%s: dSAT '%s' nie istnieje" % [where, tile["dsat"]])


# ---------------------------------------------------------------------------
# Budowa obiektów (wołana tylko po bezbłędnej walidacji)
# ---------------------------------------------------------------------------

static func _build(data: Dictionary) -> StationData:
	var station := StationData.new()
	station.meta = data["meta"]
	station.routes.assign(data["routes"])
	station.blocks.assign(data.get("blocks", []))
	station.crossings.assign(data.get("crossings", []))
	station.dsat.assign(data.get("dsat", []))
	station.panel = data.get("panel", {})

	var graph := station.graph
	for item: Variant in (data["nodes"] as Array):
		graph.node_ids.append(StringName(String((item as Dictionary)["id"])))

	for item: Variant in (data["edges"] as Array):
		var edge_def: Dictionary = item
		var edge := TrackGraph.Edge.new()
		edge.id = StringName(String(edge_def["id"]))
		edge.from_node = StringName(String(edge_def["from"]))
		edge.to_node = StringName(String(edge_def["to"]))
		edge.len_m = float(edge_def["len_m"])
		edge.vmax_kmh = int(edge_def["vmax_kmh"])
		graph.edges[edge.id] = edge

	for item: Variant in (data["turnouts"] as Array):
		var turnout_def: Dictionary = item
		var turnout := Turnout.new()
		turnout.id = StringName(String(turnout_def["id"]))
		turnout.node_id = StringName(String(turnout_def["node"]))
		turnout.edge_root = StringName(String(turnout_def["edge_root"]))
		turnout.edge_plus = StringName(String(turnout_def["edge_plus"]))
		turnout.edge_minus = StringName(String(turnout_def["edge_minus"]))
		turnout.throw_time_s = float(turnout_def.get("throw_time_s", 5.0))
		turnout.v_minus_kmh = int(turnout_def.get("v_minus_kmh", 40))
		graph.turnouts[turnout.id] = turnout

	for item: Variant in (data["sections"] as Array):
		var section_def: Dictionary = item
		var section := Section.new()
		section.id = StringName(String(section_def["id"]))
		section.type = Const.SECTION_TYPE_FROM_STRING[String(section_def["type"])]
		for edge_variant: Variant in (section_def.get("edges", []) as Array):
			section.edge_ids.append(StringName(String(edge_variant)))
		section.turnout_id = StringName(String(section_def.get("turnout", "")))
		section.len_m = float(section_def.get("len_m", 0.0))
		graph.sections[section.id] = section

	for item: Variant in (data["signals"] as Array):
		var signal_def: Dictionary = item
		var signal_device := SignalDevice.new()
		signal_device.id = StringName(String(signal_def["id"]))
		signal_device.kind = Const.SIGNAL_KIND_FROM_STRING[String(signal_def["kind"])]
		signal_device.dir = StringName(String(signal_def.get("dir", "N")))
		signal_device.at_node = StringName(String(signal_def.get("at_node", "")))
		signal_device.on_edge = StringName(String(signal_def.get("on_edge", "")))
		signal_device.offset_m = float(signal_def.get("offset_m", 0.0))
		signal_device.heads = int(signal_def.get("heads", 0))
		signal_device.bar_green = bool(signal_def.get("bar_green", false))
		signal_device.bar_orange = bool(signal_def.get("bar_orange", false))
		signal_device.can_ms2 = bool(signal_def.get("can_ms2", false))
		signal_device.can_sz = bool(signal_def.get("can_sz", false))
		signal_device.tarcza_ostrzegawcza = StringName(
			String(signal_def.get("tarcza_ostrzegawcza", ""))
		)
		signal_device.for_signal = StringName(String(signal_def.get("for_signal", "")))
		signal_device.sbl = bool(signal_def.get("sbl", false))
		signal_device.aspect = SignalDevice.base_aspect(signal_device.kind)
		graph.signals[signal_device.id] = signal_device

	graph.rebuild_indexes()
	return station
