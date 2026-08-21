class_name BlockLine
extends RefCounted
## Blokada półsamoczynna jednego szlaku (docs/systemy/15 §1, §4).
## Pola: Po (początkowe — zablokowanie po wyprawieniu), Ko (końcowe —
## potwierdzenie przyjazdu), Poz (pozwolenie na szlaku jednotorowym).

## Po której stronie szlaku jest pozwolenie wyprawiania.
enum BlockSide { PLAYER, NEIGHBOUR }

var id: StringName = &""
var neighbour_name: String = ""
var entry_signal: StringName = &""
var exit_signals: Array[StringName] = []
## Sekcja zbliżania szlaku po stronie gracza (do detekcji wjazdu/wyjazdu).
var approach_section: StringName = &""

var permission_at: BlockSide = BlockSide.PLAYER
## Odstęp (szlak) zajęty przez pociąg.
var occupied: bool = false
## Pole początkowe zablokowane (gracz wyprawił i zablokował Po).
var po_locked: bool = false
## Nr pociągu na odstępie (jadącego do gracza lub od gracza).
var train_nr: String = ""
## Pociąg przyjechał do gracza w całości — wolno obsłużyć Ko.
var arrival_pending: bool = false
## Pociąg wyprawiony przez gracza jest na odstępie — wolno obsłużyć Po.
var po_pending: bool = false


static func from_def(def: Dictionary, p_approach: StringName) -> BlockLine:
	var block := BlockLine.new()
	block.id = StringName(String(def.get("id", "")))
	block.neighbour_name = String(def.get("neighbour", ""))
	block.entry_signal = StringName(String(def.get("entry_signal", "")))
	for signal_id: Variant in (def.get("exit_signals", []) as Array):
		block.exit_signals.append(StringName(String(signal_id)))
	block.approach_section = p_approach
	return block


## Czy blokada pozwala wyprawić pociąg (warunek 6 checklisty docs/04 §3):
## pozwolenie u gracza i odstęp wolny.
func can_dispatch() -> CommandResult:
	if permission_at != BlockSide.PLAYER:
		return CommandResult.failure(
			"blokada %s: pozwolenie jest u sąsiada (%s)" % [id, neighbour_name]
		)
	if occupied:
		return CommandResult.failure("blokada %s: odstęp zajęty" % id)
	return CommandResult.success()


## Czy sąsiad może wyprawić pociąg do gracza (pozwolenie u niego,
## odstęp wolny).
func can_dispatch_from_neighbour() -> bool:
	return permission_at == BlockSide.NEIGHBOUR and not occupied


## Obsługa pola przez gracza (przyciski Po/Ko/Poz na pulpicie).
func press(field: String) -> CommandResult:
	match field:
		"Po":
			if not po_pending or po_locked:
				return CommandResult.failure(
					"pole Po blokady %s: brak podstaw do zablokowania" % id
				)
			po_locked = true
			po_pending = false
			return CommandResult.success()
		"Ko":
			if not arrival_pending:
				return CommandResult.failure(
					"pole Ko blokady %s: brak pociągu do potwierdzenia" % id
				)
			arrival_pending = false
			occupied = false
			train_nr = ""
			return CommandResult.success()
		"Poz":
			if permission_at != BlockSide.PLAYER:
				return CommandResult.failure("pozwolenie blokady %s jest u sąsiada" % id)
			if occupied:
				return CommandResult.failure(
					"blokada %s: odstęp zajęty — nie można przekazać pozwolenia" % id
				)
			permission_at = BlockSide.NEIGHBOUR
			return CommandResult.success()
	return CommandResult.failure("nieznane pole blokady: %s" % field)


## Sąsiad (AI) przekazuje pozwolenie graczowi.
func give_permission_to_player() -> bool:
	if permission_at == BlockSide.NEIGHBOUR and not occupied:
		permission_at = BlockSide.PLAYER
		return true
	return false


## Pociąg od sąsiada wjechał na odstęp (po oznajmieniu odjazdu).
func train_entered_from_neighbour(nr: String) -> void:
	occupied = true
	train_nr = nr
	arrival_pending = false


## Pociąg od sąsiada przyjechał do gracza w całości → Ko dozwolone.
func train_arrived_at_player() -> void:
	if occupied:
		arrival_pending = true


## Pociąg gracza wyjechał na odstęp → Po dozwolone, odstęp zajęty.
func train_dispatched_by_player(nr: String) -> void:
	occupied = true
	train_nr = nr
	po_pending = true


## Sąsiad potwierdził przyjazd u siebie (jego Ko) → odstęp wolny.
func released_by_neighbour() -> void:
	occupied = false
	po_locked = false
	po_pending = false
	train_nr = ""


func to_dict() -> Dictionary:
	return {
		"permission_at": permission_at,
		"occupied": occupied,
		"po_locked": po_locked,
		"train_nr": train_nr,
		"arrival_pending": arrival_pending,
		"po_pending": po_pending,
	}


func from_dict(data: Dictionary) -> void:
	permission_at = int(data.get("permission_at", BlockSide.PLAYER)) as BlockLine.BlockSide
	occupied = bool(data.get("occupied", false))
	po_locked = bool(data.get("po_locked", false))
	train_nr = String(data.get("train_nr", ""))
	arrival_pending = bool(data.get("arrival_pending", false))
	po_pending = bool(data.get("po_pending", false))
