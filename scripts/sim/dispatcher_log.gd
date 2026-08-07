class_name DispatcherLog
extends RefCounted
## Dziennik ruchu dyżurnego: wpisy automatyczne (przebiegi, jazdy pociągów,
## zdarzenia) oraz ręczne wpisy dyżurnego. Zapis do pliku w user://.

var entries: Array = []   # {t: float, cat: String, text: String}
var location_name := ""


func _init(p_location_name: String) -> void:
	location_name = p_location_name


func add(sim_time: float, cat: String, text: String) -> void:
	var entry := {"t": sim_time, "cat": cat, "text": text}
	entries.append(entry)
	EventBus.log_added.emit(entry)


func file_path() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "user://dziennik_%04d%02d%02d_%s.txt" % [
		d["year"], d["month"], d["day"],
		location_name.to_lower().replace(" ", "_"),
	]


func save_to_file() -> String:
	var path := file_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_line("DZIENNIK RUCHU — %s" % location_name)
	f.store_line("Zapis: %s" % Time.get_datetime_string_from_system())
	f.store_line("".lpad(72, "-"))
	for e in entries:
		f.store_line("[%s] [%s] %s" % [SimUtil.fmt_time(e["t"]), e["cat"], e["text"]])
	f.close()
	return path
