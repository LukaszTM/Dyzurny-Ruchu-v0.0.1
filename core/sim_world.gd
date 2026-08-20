class_name SimWorld
extends RefCounted
## Rdzeń symulacji — spina wszystkie podsystemy i wykonuje tick()
## wg kolejności z docs/02-architektura.md ("Pętla symulacji").
## Faza 0: szkielet — tylko licznik ticków i czas; podsystemy (pociągi,
## zwrotnice, interlocking, sygnalizatory, blokady...) dojdą w F1–F5.
## Czysta klasa bez zależności od węzłów sceny (testowalna headless w GUT).

## Czas symulacji w sekundach od startu scenariusza.
var sim_time: float = 0.0
## Liczba wykonanych ticków.
var tick_count: int = 0


## Jeden krok symulacji o dt sekund czasu symulacji (wołany przez SimClock).
## Kolejność podsystemów w ticku: pociągi → zwrotnice → interlocking →
## sygnalizatory → blokady → przejazdy/dSAT → EventDirector → NeighbourAI →
## emisja zdarzeń zbiorczo (docs/02). W F0 podsystemów jeszcze nie ma.
func tick(dt: float) -> void:
	sim_time += dt
	tick_count += 1


## Snapshot stanu rdzenia do zapisu gry.
func to_dict() -> Dictionary:
	return {
		"sim_time": sim_time,
		"tick_count": tick_count,
	}


## Odtworzenie stanu rdzenia z zapisu gry.
func from_dict(data: Dictionary) -> void:
	sim_time = float(data.get("sim_time", 0.0))
	tick_count = int(data.get("tick_count", 0))
