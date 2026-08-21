class_name AspectTable
extends RefCounted
## Tabela obrazów sygnałowych z data/signals/aspekty.json (źródło:
## docs/systemy/11-sygnalizacja.md) + algorytm wyboru obrazu i degradacji
## konstrukcyjnej wg docs/04-logika-zaleznosci.md §6/§6.1.

const DEFAULT_PATH := "res://data/signals/aspekty.json"

var aspects: Dictionary = {}      # id -> definicja (opis, info, lampy, wymaga)
var selection: Dictionary = {}    # v_group -> {next_info -> aspekt}
var degradation: Dictionary = {}  # aspekt -> aspekt bardziej restrykcyjny
var to_map: Dictionary = {}       # info -> obraz tarczy ostrzegawczej (Os)
var sp_map: Dictionary = {}       # info -> obraz powtarzacza (Sp)


static func load_default() -> AspectTable:
	return load_from_file(DEFAULT_PATH)


static func load_from_file(path: String) -> AspectTable:
	var table := AspectTable.new()
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_error("AspectTable: nie można wczytać %s" % path)
		return table
	var data: Dictionary = parsed
	table.aspects = data.get("aspects", {})
	table.selection = data.get("wybor", {})
	table.degradation = data.get("degradacja", {})
	table.to_map = data.get("tarcza_ostrzegawcza", {})
	table.sp_map = data.get("powtarzacz", {})
	return table


## Klasa informacji obrazu dla następnego semafora i tarcz (docs/04 §6):
## S1/Sz → STOP, S2–S5 → VMAX, S6–S9 → V100, S10–S13a → V40_60.
## Nieznany/ciemny obraz → ostrożnie STOP.
func info_class(aspect_id: StringName) -> String:
	var def: Dictionary = aspects.get(String(aspect_id), {})
	var info: Variant = def.get("info")
	return String(info) if info != null else "STOP"


## Czy sygnalizator konstrukcyjnie umie wyświetlić obraz (docs/04 §6.1).
func is_available(aspect_id: StringName, signal_device: SignalDevice) -> bool:
	var def: Dictionary = aspects.get(String(aspect_id), {})
	if def.is_empty():
		return false
	var required: Dictionary = def.get("wymaga", {})
	if int(required.get("heads", 0)) > signal_device.heads:
		return false
	if bool(required.get("bar_green", false)) and not signal_device.bar_green:
		return false
	if bool(required.get("bar_orange", false)) and not signal_device.bar_orange:
		return false
	if bool(required.get("ms2", false)) and not signal_device.can_ms2:
		return false
	if bool(required.get("sz", false)) and not signal_device.can_sz:
		return false
	return true


## Wybór obrazu semafora: f(grupa prędkości drogi, informacja o następnym)
## z degradacją do najbliższego bardziej restrykcyjnego dostępnego obrazu;
## ostatecznym fallbackiem jest S1 (docs/04 §6/§6.1).
func pick(v_group: String, next_info: String, signal_device: SignalDevice) -> StringName:
	var row: Dictionary = selection.get(v_group, {})
	var aspect_id := String(row.get(next_info, "S1"))
	while not is_available(StringName(aspect_id), signal_device):
		if not degradation.has(aspect_id):
			return &"S1"
		aspect_id = String(degradation[aspect_id])
	return StringName(aspect_id)


## Obraz tarczy ostrzegawczej dla wskazania semafora (docs/04 §6.3).
func warning_aspect(semaphore_aspect: StringName) -> StringName:
	return StringName(String(to_map.get(info_class(semaphore_aspect), "Os1")))


## Obraz powtarzacza dla wskazania semafora (docs/04 §6.3).
func repeater_aspect(semaphore_aspect: StringName) -> StringName:
	return StringName(String(sp_map.get(info_class(semaphore_aspect), "Sp1")))
