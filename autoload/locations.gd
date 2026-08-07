extends Node
## Rejestr lokalizacji (posterunków). Skanuje res://data/locations/ —
## każdy katalog z plikiem location.json staje się dostępną lokalizacją.
## Dzięki temu grę można rozbudowywać o kolejne stacje bez zmian w kodzie.

var locations: Array[Dictionary] = []


func _ready() -> void:
	scan()


func scan() -> void:
	locations.clear()
	var dir := DirAccess.open("res://data/locations")
	if dir == null:
		push_warning("Brak katalogu res://data/locations")
		return
	for d in dir.get_directories():
		var meta_path := "res://data/locations/%s/location.json" % d
		if not FileAccess.file_exists(meta_path):
			continue
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
		if meta is Dictionary:
			meta["dir"] = "res://data/locations/%s" % d
			locations.append(meta)
	locations.sort_custom(func(a, b): return str(a.get("name", "")) < str(b.get("name", "")))


func get_location(id: String) -> Dictionary:
	for loc in locations:
		if str(loc.get("id", "")) == id:
			return loc
	if not locations.is_empty():
		return locations[0]
	return {}
