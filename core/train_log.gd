class_name TrainLog
extends RefCounted
## Dziennik ruchu posterunku zapowiadawczego — układ wg druku R-142
## (docs/systemy/18 §3). W trybie łatwym (auto_docs) wpisy generuje rdzeń.
## TODO(weryfikacja): dokładny układ kolumn R-142.


## Jeden wiersz dziennika (czasy w sekundach doby, -1 = brak wpisu).
class Entry:
	extends RefCounted
	var nr: String = ""
	var relation: String = ""
	var track: String = ""
	var permission_s: float = -1.0
	var announced_s: float = -1.0
	var departed_s: float = -1.0
	var arrived_s: float = -1.0
	var confirmed_s: float = -1.0
	var remarks: String = ""

var entries: Array[Entry] = []
var _by_nr: Dictionary = {}


func entry_for(nr: String, relation: String = "", track: String = "") -> Entry:
	if _by_nr.has(nr):
		return _by_nr[nr]
	var entry := Entry.new()
	entry.nr = nr
	entry.relation = relation
	entry.track = track
	entries.append(entry)
	_by_nr[nr] = entry
	return entry


func note_permission(nr: String, time_s: float) -> void:
	var entry := entry_for(nr)
	if entry.permission_s < 0.0:
		entry.permission_s = time_s


func note_announced(nr: String, time_s: float) -> void:
	var entry := entry_for(nr)
	if entry.announced_s < 0.0:
		entry.announced_s = time_s


func note_departed(nr: String, time_s: float) -> void:
	var entry := entry_for(nr)
	if entry.departed_s < 0.0:
		entry.departed_s = time_s


func note_arrived(nr: String, time_s: float) -> void:
	var entry := entry_for(nr)
	if entry.arrived_s < 0.0:
		entry.arrived_s = time_s


func note_confirmed(nr: String, time_s: float) -> void:
	var entry := entry_for(nr)
	if entry.confirmed_s < 0.0:
		entry.confirmed_s = time_s


func add_remark(nr: String, remark: String) -> void:
	var entry := entry_for(nr)
	if entry.remarks.is_empty():
		entry.remarks = remark
	elif not entry.remarks.contains(remark):
		entry.remarks += "; " + remark
