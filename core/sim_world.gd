class_name SimWorld
extends RefCounted
## Rdzeń symulacji — spina wszystkie podsystemy i wykonuje tick()
## wg kolejności z docs/02-architektura.md ("Pętla symulacji").
## F1: graf torowy stacji (zwrotnice z czasem przestawiania, zajętości);
## kolejne podsystemy (interlocking, pociągi, blokady...) dojdą w F3–F5.
## Czysta klasa bez zależności od węzłów sceny (testowalna headless w GUT).

## Czas symulacji w sekundach od startu scenariusza.
var sim_time: float = 0.0
## Liczba wykonanych ticków.
var tick_count: int = 0
## Wczytana stacja (null przed load_station_file).
var station: StationData = null


## Wczytuje stację z pliku JSON (walidacja: core/station_loader.gd).
## Zwraca wynik loadera {ok, errors, station}.
func load_station_file(path: String) -> Dictionary:
	var result := StationLoader.load_from_file(path)
	if result["ok"]:
		station = result["station"]
	return result


## Jeden krok symulacji o dt sekund czasu symulacji (wołany przez SimClock).
## Kolejność podsystemów w ticku: pociągi → zwrotnice → interlocking →
## sygnalizatory → blokady → przejazdy/dSAT → EventDirector → NeighbourAI →
## emisja zdarzeń zbiorczo (docs/02). W F1 działa krok „zwrotnice".
func tick(dt: float) -> void:
	sim_time += dt
	tick_count += 1
	if station != null:
		station.graph.tick(dt)


## Snapshot stanu rdzenia do zapisu gry.
func to_dict() -> Dictionary:
	var data := {
		"sim_time": sim_time,
		"tick_count": tick_count,
	}
	if station != null:
		data["graph"] = station.graph.to_dict()
	return data


## Odtworzenie stanu rdzenia z zapisu gry (stacja musi być już wczytana).
func from_dict(data: Dictionary) -> void:
	sim_time = float(data.get("sim_time", 0.0))
	tick_count = int(data.get("tick_count", 0))
	if station != null and data.has("graph"):
		station.graph.from_dict(data["graph"])
