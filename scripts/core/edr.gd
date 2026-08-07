class_name EDR
extends RefCounted
## Elektroniczny Dziennik Ruchu — zastępuje papierowy dziennik ruchu.
## Rejestruje zapowiadanie telefoniczne, nastawianie i zwalnianie przebiegów,
## jazdy pociągów i manewry, usterki urządzeń oraz wpisy własne dyżurnego.

const KAT := ["Zapowiedź", "Przebieg", "Ruch", "Manewry", "Usterka", "Dyżurny", "Służba"]

var entries: Array = []     # {lp, t, kat, nr, tor, tresc, dyzurny}
var station := ""
var _lp := 0


func _init(p_station: String) -> void:
	station = p_station


func add(sim_time: float, kat: String, tresc: String, nr := "", tor := "") -> Dictionary:
	_lp += 1
	var e := {
		"lp": _lp, "t": sim_time, "kat": kat, "nr": nr, "tor": tor,
		"tresc": tresc, "dyzurny": Settings.dyzurny_name,
	}
	entries.append(e)
	EventBus.edr_added.emit(e)
	return e


func last(n: int) -> Array:
	var start: int = maxi(0, entries.size() - n)
	return entries.slice(start, entries.size())


func filtered(kat: String, nr_filter: String) -> Array:
	var res: Array = []
	for e in entries:
		if kat != "" and str(e["kat"]) != kat:
			continue
		if nr_filter != "" and not str(e["nr"]).contains(nr_filter):
			continue
		res.append(e)
	return res


func file_path() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "user://EDR_%04d%02d%02d_%s.txt" % [
		d["year"], d["month"], d["day"], station.to_lower().replace(" ", "_")]


func save_to_file() -> String:
	var path := file_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_line("ELEKTRONICZNY DZIENNIK RUCHU — posterunek %s" % station)
	f.store_line("Dyżurny ruchu: %s" % Settings.dyzurny_name)
	f.store_line("Wydruk: %s" % Time.get_datetime_string_from_system())
	f.store_line("".lpad(96, "="))
	f.store_line("%-5s %-9s %-11s %-8s %-5s %s" % ["Lp.", "Godzina", "Rodzaj", "Nr poc.", "Tor", "Treść zapisu"])
	f.store_line("".lpad(96, "-"))
	for e in entries:
		f.store_line("%-5d %-9s %-11s %-8s %-5s %s" % [
			int(e["lp"]), SimUtil.fmt_time(e["t"]), str(e["kat"]),
			str(e["nr"]), str(e["tor"]), str(e["tresc"])])
	f.close()
	return ProjectSettings.globalize_path(path)
