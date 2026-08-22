class_name LeverFrame
extends RefCounted
## Ława dźwigniowa ze skrzynią zależności i blokami stacyjnymi
## (docs/systemy/12 §1–§3, §5). Skrzynia wymusza kolejność czynności:
## zwrotnice → rygiel → (nakaz) → dźwignia sygnałowa; odmowa = „dźwignia
## nie puszcza". Warunki bezpieczeństwa sprawdza ten sam Interlocking.

## Typy dźwigni (docs/systemy/12 §1).
enum LeverType { ZWROTNICOWA, RYGLOWA, SYGNALOWA }

const TYPE_FROM_STRING: Dictionary = {
	"zwrotnicowa": LeverType.ZWROTNICOWA,
	"ryglowa": LeverType.RYGLOWA,
	"sygnalowa": LeverType.SYGNALOWA,
}


## Jedna dźwignia na ławie.
class Lever:
	extends RefCounted
	var id: StringName = &""
	var type: LeverType = LeverType.ZWROTNICOWA
	var label: String = ""
	## Zwrotnica (dźwignia zwrotnicowa).
	var turnout: StringName = &""
	## Zwrotnice ryglowane (dźwignia ryglowa).
	var turnouts: Array[StringName] = []
	## Semafor (dźwignia sygnałowa).
	var signal_id: StringName = &""
	## Położenie przełożone (zasadnicze = false).
	var reversed: bool = false

## Blok stacyjny aparatu blokowego (docs/systemy/12 §2): nakaz dla grupy
## przebiegów albo klawisz zwolnienia przebiegu.
class StationBlock:
	extends RefCounted
	var id: StringName = &""
	var label: String = ""
	## "nakaz" | "zwolnienie".
	var kind: String = "nakaz"
	var routes: Array[StringName] = []
	## Nakaz dany (okienko czerwone).
	var given: bool = false

var levers: Dictionary = {}          # StringName -> Lever
var lever_order: Array[StringName] = []
var station_blocks: Dictionary = {}  # StringName -> StationBlock
var block_order: Array[StringName] = []

var _graph: TrackGraph = null
var _interlocking: Interlocking = null


func _init(panel: Dictionary, graph: TrackGraph, interlocking: Interlocking) -> void:
	_graph = graph
	_interlocking = interlocking
	for item: Variant in (panel.get("levers", []) as Array):
		var def: Dictionary = item
		var lever := Lever.new()
		lever.id = StringName(String(def.get("id", "")))
		lever.type = TYPE_FROM_STRING.get(String(def.get("type", "")), LeverType.ZWROTNICOWA)
		lever.label = String(def.get("label", String(lever.id)))
		lever.turnout = StringName(String(def.get("turnout", "")))
		for turnout_id: Variant in (def.get("turnouts", []) as Array):
			lever.turnouts.append(StringName(String(turnout_id)))
		lever.signal_id = StringName(String(def.get("signal", "")))
		levers[lever.id] = lever
		lever_order.append(lever.id)
	for item: Variant in (panel.get("station_blocks", []) as Array):
		var def: Dictionary = item
		var block := StationBlock.new()
		block.id = StringName(String(def.get("id", "")))
		block.label = String(def.get("label", String(block.id)))
		block.kind = String(def.get("kind", "nakaz"))
		for route_id: Variant in (def.get("routes", []) as Array):
			block.routes.append(StringName(String(route_id)))
		station_blocks[block.id] = block
		block_order.append(block.id)


func get_lever(lever_id: StringName) -> Lever:
	return levers.get(lever_id) as Lever


## Przełożenie dźwigni (toggle). Odmowa = skrzynia zależności nie puszcza.
func move_lever(lever_id: StringName) -> CommandResult:
	var lever := get_lever(lever_id)
	if lever == null:
		return CommandResult.failure("dźwignia %s nie istnieje" % lever_id)
	match lever.type:
		LeverType.ZWROTNICOWA:
			return _move_turnout_lever(lever)
		LeverType.RYGLOWA:
			return _move_lock_lever(lever)
		LeverType.SYGNALOWA:
			return _move_signal_lever(lever)
	return CommandResult.failure("nieznany typ dźwigni")


## Dźwignia zwrotnicowa: nie pod ryglem; resztę (zajętość, utwierdzenie)
## sprawdza graf jak na pulpicie (docs/04 §2).
func _move_turnout_lever(lever: Lever) -> CommandResult:
	var lock := _lock_covering(lever.turnout)
	if lock != null and lock.reversed:
		return CommandResult.failure(
			"dźwignia %s zablokowana — zwrotnica %s zaryglowana (rygiel %s)"
			% [lever.label, lever.turnout, lock.label]
		)
	var result := _graph.throw_turnout(lever.turnout)
	if result.ok:
		_interlocking.update_signals()
	return result


## Dźwignia ryglowa: przełożenie wymaga kontroli położenia wszystkich
## ryglowanych zwrotnic; cofnięcie — położenia zasadniczego dźwigni
## sygnałowych i zwolnienia utwierdzeń (docs/systemy/12 §3).
func _move_lock_lever(lever: Lever) -> CommandResult:
	if not lever.reversed:
		for turnout_id: StringName in lever.turnouts:
			var turnout := _graph.get_turnout(turnout_id)
			if turnout == null or not turnout.has_control():
				return CommandResult.failure(
					"rygiel %s: zwrotnica %s bez kontroli położenia" % [lever.label, turnout_id]
				)
		lever.reversed = true
		return CommandResult.success()
	for other_id: StringName in levers:
		var other := get_lever(other_id)
		if other.type == LeverType.SYGNALOWA and other.reversed:
			return CommandResult.failure(
				"rygiel %s zablokowany — najpierw cofnij dźwignię sygnałową %s"
				% [lever.label, other.label]
			)
	for turnout_id: StringName in lever.turnouts:
		var turnout := _graph.get_turnout(turnout_id)
		if turnout != null and turnout.locked_by != &"":
			return CommandResult.failure(
				"rygiel %s zablokowany — zwrotnica %s utwierdzona w przebiegu %s"
				% [lever.label, turnout_id, turnout.locked_by]
			)
	lever.reversed = false
	return CommandResult.success()


## Dźwignia sygnałowa: przełożenie = utwierdzenie przebiegu (pełna
## checklista docs/04 §3) pod warunkami skrzyni: droga zaryglowana
## i nakaz dany (docs/systemy/12 §3: kolejność 3→4→5→6).
func _move_signal_lever(lever: Lever) -> CommandResult:
	if not lever.reversed:
		var route := _candidate_route(lever.signal_id)
		if route == null:
			return CommandResult.failure(
				"dźwignia %s zablokowana — zwrotnice nie są ułożone dla żadnego przebiegu od %s"
				% [lever.label, lever.signal_id]
			)
		for turnout_id: StringName in route.turnouts_req:
			var lock := _lock_covering(turnout_id)
			if lock == null or not lock.reversed:
				return CommandResult.failure(
					"dźwignia %s zablokowana — najpierw przełóż rygiel (zwrotnica %s niezaryglowana)"
					% [lever.label, turnout_id]
				)
		if not _order_given_for(route.id):
			return CommandResult.failure(
				"dźwignia %s zablokowana — brak nakazu dla przebiegu %s (aparat blokowy)"
				% [lever.label, route.id]
			)
		var result := _interlocking.execute(&"route_start", {"id": String(lever.signal_id)})
		if result.ok:
			lever.reversed = true
		return result
	# Cofnięcie dźwigni sygnałowej: semafor na „stój". Przy utwierdzonym
	# przebiegu z wolnym zbliżaniem = kasowanie; po jeździe — powrót ramienia.
	var active := _interlocking.get_route(&"")
	for route_id: StringName in _interlocking.routes:
		var route: Route = _interlocking.routes[route_id]
		if route.entry_signal == lever.signal_id and route.is_active():
			active = route
			break
	if active != null and active.state == Const.RouteState.LOCKED:
		var cancel := _interlocking.execute(&"signal_cancel", {"id": String(lever.signal_id)})
		if not cancel.ok:
			return cancel
	lever.reversed = false
	_interlocking.update_signals()
	return CommandResult.success()


## Klawisz bloku stacyjnego: „nakaz" daje nakaz (okienko czerwone),
## „zwolnienie" cofa nakazy po zakończonych jazdach (docs/systemy/12 §2).
func press_block(block_id: StringName) -> CommandResult:
	var block: StationBlock = station_blocks.get(block_id)
	if block == null:
		return CommandResult.failure("blok %s nie istnieje" % block_id)
	if block.kind == "zwolnienie":
		var released := 0
		for other_id: StringName in station_blocks:
			var other: StationBlock = station_blocks[other_id]
			if other.kind != "nakaz" or not other.given:
				continue
			if _any_route_active(other.routes):
				continue
			other.given = false
			released += 1
		if released == 0:
			return CommandResult.failure(
				"zwolnienie przebiegu: brak nakazów do zwolnienia (jazda w toku?)"
			)
		return CommandResult.success()
	if block.given:
		return CommandResult.failure("blok %s: nakaz już dany" % block.label)
	block.given = true
	return CommandResult.success()


func _any_route_active(route_ids: Array[StringName]) -> bool:
	for route_id: StringName in route_ids:
		var route := _interlocking.get_route(route_id)
		if route != null and route.is_active():
			return true
	return false


## Nakaz dany dla przebiegu: dowolny blok „nakaz" obejmujący ten przebieg.
func _order_given_for(route_id: StringName) -> bool:
	var any_covers := false
	for block_id: StringName in station_blocks:
		var block: StationBlock = station_blocks[block_id]
		if block.kind != "nakaz" or not block.routes.has(route_id):
			continue
		any_covers = true
		if block.given:
			return true
	# Przebieg nieobjęty żadnym blokiem nakazu nie wymaga nakazu.
	return not any_covers


## Dźwignia ryglowa obejmująca zwrotnicę (null = zwrotnica bez rygla).
func _lock_covering(turnout_id: StringName) -> Lever:
	for lever_id: StringName in levers:
		var lever := get_lever(lever_id)
		if lever.type == LeverType.RYGLOWA and lever.turnouts.has(turnout_id):
			return lever
	return null


## Kandydat przebiegu od semafora wg bieżących położeń zwrotnic
## (nastawianie ręczne — jak przycisk sygnałowy na pulpicie).
func _candidate_route(signal_id: StringName) -> Route:
	for route_id: StringName in _interlocking.routes:
		var route: Route = _interlocking.routes[route_id]
		if route.entry_signal != signal_id or route.is_active():
			continue
		var matches := true
		for turnout_id: StringName in route.turnouts_req:
			var turnout := _graph.get_turnout(turnout_id)
			if turnout == null or not turnout.has_control():
				matches = false
				break
			var required: Const.TurnoutPos = route.turnouts_req[turnout_id]
			if (required == Const.TurnoutPos.PLUS) != turnout.is_plus():
				matches = false
				break
		if matches:
			return route
	return null


func to_dict() -> Dictionary:
	var lever_states := {}
	for lever_id: StringName in levers:
		lever_states[String(lever_id)] = (levers[lever_id] as Lever).reversed
	var block_states := {}
	for block_id: StringName in station_blocks:
		block_states[String(block_id)] = (station_blocks[block_id] as StationBlock).given
	return {"levers": lever_states, "blocks": block_states}


func from_dict(data: Dictionary) -> void:
	var lever_states: Dictionary = data.get("levers", {})
	for key: String in lever_states:
		var lever := get_lever(StringName(key))
		if lever != null:
			lever.reversed = bool(lever_states[key])
	var block_states: Dictionary = data.get("blocks", {})
	for key: String in block_states:
		if station_blocks.has(StringName(key)):
			(station_blocks[StringName(key)] as StationBlock).given = bool(block_states[key])
