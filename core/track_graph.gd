class_name TrackGraph
extends RefCounted
## Graf torowy stacji: węzły, krawędzie, odcinki izolowane, zwrotnice,
## sygnalizatory (docs/03-model-danych.md §1–2). Obiekty tworzy StationLoader.
## Czysta klasa bez zależności od węzłów sceny (docs/02-architektura.md).


## Odcinek toru między dwoma węzłami grafu (docs/03 §1: „edge").
class Edge:
	extends RefCounted
	var id: StringName = &""
	var from_node: StringName = &""
	var to_node: StringName = &""
	var len_m: float = 0.0
	var vmax_kmh: int = 0

var node_ids: Array[StringName] = []
var edges: Dictionary = {}    # StringName -> TrackGraph.Edge
var turnouts: Dictionary = {} # StringName -> Turnout
var sections: Dictionary = {} # StringName -> Section
var signals: Dictionary = {}  # StringName -> SignalDevice

## Indeksy odwrotne budowane przy wczytaniu stacji.
var _edge_to_section: Dictionary = {}    # StringName(edge) -> StringName(section)
var _turnout_to_section: Dictionary = {} # StringName(turnout) -> StringName(section)


func has_graph_node(node_id: StringName) -> bool:
	return node_ids.has(node_id)


func get_edge(edge_id: StringName) -> Edge:
	return edges.get(edge_id) as Edge


func get_section(section_id: StringName) -> Section:
	return sections.get(section_id) as Section


func get_turnout(turnout_id: StringName) -> Turnout:
	return turnouts.get(turnout_id) as Turnout


func get_signal(signal_id: StringName) -> SignalDevice:
	return signals.get(signal_id) as SignalDevice


## Odcinek izolowany, do którego należy krawędź (null, gdy poza kontrolą).
func section_for_edge(edge_id: StringName) -> Section:
	var section_id: Variant = _edge_to_section.get(edge_id)
	return null if section_id == null else get_section(section_id)


## Odcinek zwrotnicowy zawierający zwrotnicę (null, gdy zwrotnica poza kontrolą).
func section_for_turnout(turnout_id: StringName) -> Section:
	var section_id: Variant = _turnout_to_section.get(turnout_id)
	return null if section_id == null else get_section(section_id)


## Przebudowa indeksów odwrotnych — woła StationLoader po zbudowaniu obiektów.
func rebuild_indexes() -> void:
	_edge_to_section.clear()
	_turnout_to_section.clear()
	for section_id: StringName in sections:
		var section: Section = sections[section_id]
		for edge_id: StringName in section.edge_ids:
			_edge_to_section[edge_id] = section_id
		if section.turnout_id != &"":
			_turnout_to_section[section.turnout_id] = section_id


## Ręczne ustawienie zajętości odcinka (w F1 — testy i tryb debug;
## od F4 zajętość ustawiają osie pociągu).
func set_section_occupied(section_id: StringName, occupied_value: bool) -> CommandResult:
	var section := get_section(section_id)
	if section == null:
		return CommandResult.failure("sekcja %s nie istnieje" % section_id)
	section.occupied = occupied_value
	return CommandResult.success()


## Przestawienie zwrotnicy z pełnymi warunkami z docs/04 §2: sekcja
## zwrotnicowa wolna i nieutwierdzona, zwrotnica sprawna, nieutwierdzona,
## niezamknięta indywidualnie.
func throw_turnout(turnout_id: StringName) -> CommandResult:
	var turnout := get_turnout(turnout_id)
	if turnout == null:
		return CommandResult.failure("zwrotnica %s nie istnieje" % turnout_id)
	var section := section_for_turnout(turnout_id)
	if section != null:
		if section.occupied:
			return CommandResult.failure(
				"sekcja zwrotnicowa %s zajęta — nie wolno przestawiać pod taborem" % section.id
			)
		if section.is_locked():
			return CommandResult.failure(
				"sekcja %s utwierdzona w przebiegu %s" % [section.id, section.locked_by]
			)
	return turnout.start_throw()


## Krok symulacji grafu (kolejność podsystemów: docs/02 — „zwrotnice").
## Zwraca id zwrotnic, które w tym ticku zakończyły przestawianie.
func tick(dt: float) -> Array[StringName]:
	var finished: Array[StringName] = []
	for turnout_id: StringName in turnouts:
		var turnout: Turnout = turnouts[turnout_id]
		if turnout.tick(dt):
			finished.append(turnout_id)
	return finished


## Snapshot stanu dynamicznego całego grafu (do zapisu gry).
func to_dict() -> Dictionary:
	var sections_state := {}
	for section_id: StringName in sections:
		sections_state[String(section_id)] = (sections[section_id] as Section).to_dict()
	var turnouts_state := {}
	for turnout_id: StringName in turnouts:
		turnouts_state[String(turnout_id)] = (turnouts[turnout_id] as Turnout).to_dict()
	var signals_state := {}
	for signal_id: StringName in signals:
		signals_state[String(signal_id)] = (signals[signal_id] as SignalDevice).to_dict()
	return {
		"sections": sections_state,
		"turnouts": turnouts_state,
		"signals": signals_state,
	}


func from_dict(data: Dictionary) -> void:
	var sections_state: Dictionary = data.get("sections", {})
	for key: String in sections_state:
		var section := get_section(StringName(key))
		if section != null:
			section.from_dict(sections_state[key])
	var turnouts_state: Dictionary = data.get("turnouts", {})
	for key: String in turnouts_state:
		var turnout := get_turnout(StringName(key))
		if turnout != null:
			turnout.from_dict(turnouts_state[key])
	var signals_state: Dictionary = data.get("signals", {})
	for key: String in signals_state:
		var signal_device := get_signal(StringName(key))
		if signal_device != null:
			signal_device.from_dict(signals_state[key])
