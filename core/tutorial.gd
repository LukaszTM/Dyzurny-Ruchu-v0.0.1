class_name Tutorial
extends RefCounted
## Samouczek (roadmapa F10): skrypt lekcji z sekcji "tutorial" scenariusza —
## kroki z tekstem dla gracza i warunkiem zaliczenia sprawdzanym na stanie
## rdzenia. Czysta klasa RefCounted (testowalna headless); UI tylko
## wyświetla zdarzenia tutorial_step/tutorial_done.

var title: String = ""
var outro: String = ""
## Kroki: {"text": String, "done_when": Dictionary}.
var steps: Array[Dictionary] = []
var current: int = 0
var done: bool = false

var _started: bool = false
## Ostatnie UDANE polecenie gracza: {"name": String, "args": Dictionary}.
var _last_command: Dictionary = {}
## Zdarzenia rdzenia widziane w tym ticku: [{type, text}].
var _seen_events: Array[Dictionary] = []
## Czas symulacji wejścia w bieżący krok.
var _step_started_s: float = 0.0


static func from_scenario(scenario: Dictionary) -> Tutorial:
	var data: Variant = scenario.get("tutorial")
	if data == null or not (data is Dictionary):
		return null
	var config: Dictionary = data
	var tutorial := Tutorial.new()
	tutorial.title = String(config.get("title", "Samouczek"))
	tutorial.outro = String(config.get("outro", "Lekcja ukończona!"))
	for step_variant: Variant in (config.get("steps", []) as Array):
		tutorial.steps.append(step_variant as Dictionary)
	return tutorial


## Rejestruje udane polecenie gracza (woła SimWorld.execute).
func notify_command(name: StringName, args: Dictionary, ok: bool) -> void:
	if ok:
		_last_command = {"name": String(name), "args": args.duplicate(true)}


## Rejestruje zdarzenia rdzenia z bieżącego ticku (przed tick()).
func observe_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		_seen_events.append({
			"type": String(event.get("type", "")),
			"text": String(event.get("text", event.get("reason", ""))),
		})


## Krok samouczka; zwraca zdarzenia dla UI. Wołane co tick rdzenia.
func tick(world: SimWorld) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if done or steps.is_empty():
		_seen_events.clear()
		return out
	if not _started:
		_started = true
		_step_started_s = world.sim_time
		out.append(_step_event())
	while not done and _condition_met(steps[current].get("done_when", {}), world):
		current += 1
		_last_command = {}
		_step_started_s = world.sim_time
		if current >= steps.size():
			done = true
			out.append({"type": &"tutorial_done", "text": outro, "title": title})
		else:
			out.append(_step_event())
	_seen_events.clear()
	return out


func step_text() -> String:
	if done or steps.is_empty():
		return ""
	return String(steps[current].get("text", ""))


func _step_event() -> Dictionary:
	return {"type": &"tutorial_step", "index": current + 1,
		"total": steps.size(), "text": step_text(), "title": title}


## Warunki zaliczenia kroku (typy opisane w docs/07-interfejs-gui.md).
func _condition_met(cond: Dictionary, world: SimWorld) -> bool:
	var graph := world.station.graph
	match String(cond.get("type", "")):
		"command":
			if _last_command.is_empty() \
					or String(_last_command["name"]) != String(cond.get("name", "")):
				return false
			var args: Dictionary = _last_command["args"]
			for key: String in ["id", "value", "nr"]:
				if cond.has(key) and String(args.get(key, "")) != String(cond[key]):
					return false
			if cond.has("phone_type") \
					and String(args.get("type", "")) != String(cond["phone_type"]):
				return false
			return true
		"route_locked":
			var route := world.interlocking.get_route(StringName(String(cond.get("id", ""))))
			return route != null and route.state >= Const.RouteState.LOCKED \
				and route.state != Const.RouteState.CANCELLED
		"turnout_pos":
			var turnout := graph.get_turnout(StringName(String(cond.get("id", ""))))
			if turnout == null or not turnout.has_control():
				return false
			return turnout.is_plus() if String(cond.get("pos", "PLUS")) == "PLUS" \
				else turnout.is_minus()
		"signal_go":
			var signal_go := graph.get_signal(StringName(String(cond.get("id", ""))))
			return signal_go != null and not signal_go.shows_stop()
		"signal_stop":
			var signal_stop := graph.get_signal(StringName(String(cond.get("id", ""))))
			return signal_stop != null and signal_stop.shows_stop()
		"signal_aspect":
			var signal_aspect := graph.get_signal(StringName(String(cond.get("id", ""))))
			return signal_aspect != null \
				and signal_aspect.aspect == StringName(String(cond.get("aspect", "")))
		"train_arrived":
			return world.train_arrived(String(cond.get("nr", "")))
		"train_departed":
			return world.train_departed(String(cond.get("nr", "")))
		"crossing_closed":
			var crossing: LevelCrossing = world.crossings.get(
				StringName(String(cond.get("id", ""))))
			return crossing != null and crossing.is_closed()
		"block":
			var block: BlockLine = world.block_lines.get(
				StringName(String(cond.get("id", ""))))
			if block == null:
				return false
			match String(cond.get("field", "")):
				"po_locked":
					return block.po_locked
				"permission_player":
					return block.permission_at == BlockLine.BlockSide.PLAYER
				"occupied":
					return block.occupied
				"free":
					return not block.occupied
			return false
		"section_occupied":
			var section := graph.get_section(StringName(String(cond.get("id", ""))))
			return section != null and section.occupied
		"event":
			var wanted := String(cond.get("event", ""))
			var contains := String(cond.get("contains", ""))
			for seen: Dictionary in _seen_events:
				if String(seen["type"]) != wanted:
					continue
				if contains.is_empty() or String(seen["text"]).contains(contains):
					return true
			return false
		"confirm_pending":
			return not world.pending_confirm.is_empty()
		"in_step_s":
			return world.sim_time - _step_started_s >= float(cond.get("s", 5.0))
	return false
