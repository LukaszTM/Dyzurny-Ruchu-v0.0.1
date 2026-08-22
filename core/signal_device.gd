class_name SignalDevice
extends RefCounted
## Sygnalizator (semafor, tarcze, powtarzacz) — w F1 tylko przechowywanie
## stanu; wybór obrazu robi Interlocking w F3 wg docs/04-logika-zaleznosci.md
## §6 i tabel z docs/systemy/11-sygnalizacja.md.
## Format danych: docs/03-model-danych.md §2.

var id: StringName = &""
var kind: Const.SignalKind = Const.SignalKind.SEMAFOR
## Kierunek jazdy, dla którego sygnalizator jest ważny: N / P (docs/03 §1).
var dir: StringName = &"N"
## Lokalizacja: przy węźle (semafory) lub na krawędzi z odsunięciem (To itp.).
var at_node: StringName = &""
var on_edge: StringName = &""
var offset_m: float = 0.0

## Możliwości konstrukcyjne (docs/03 §2): liczba komór, paski, Ms2, Sz.
var heads: int = 0
var bar_green: bool = false
var bar_orange: bool = false
var can_ms2: bool = false
var can_sz: bool = false

## Id powiązanej tarczy ostrzegawczej (dla semafora).
var tarcza_ostrzegawcza: StringName = &""
## Id semafora, do którego odnosi się tarcza/powtarzacz.
var for_signal: StringName = &""

## Bieżący obraz sygnałowy (nazwa wg docs/systemy/11-sygnalizacja.md).
var aspect: StringName = &"S1"
## Usterka „ciemny sygnalizator" — traktowany jak „stój" (docs/04 §8).
var failed: bool = false


## Obraz zasadniczy danej konstrukcji (stan spoczynkowy, bez przebiegu):
## semafor S1, tarcza manewrowa Ms1, tarcza ostrzegawcza Os1, powtarzacz Sp1
## (docs/systemy/11-sygnalizacja.md §2–5). Dla pozostałych konstrukcji
## obraz zasadniczy doprecyzuje F3 (w F1 nieużywane — Borki ich nie mają).
static func base_aspect(for_kind: Const.SignalKind) -> StringName:
	match for_kind:
		Const.SignalKind.SEMAFOR:
			return &"S1"
		Const.SignalKind.SEMAFOR_KSZTALTOWY:
			return &"Sr1"
		Const.SignalKind.TARCZA_MANEWROWA:
			return &"Ms1"
		Const.SignalKind.TARCZA_OSTRZEGAWCZA:
			return &"Os1"
		Const.SignalKind.POWTARZACZ:
			return &"Sp1"
	return &""


## Czy sygnalizator nakazuje zatrzymanie (S1/Sr1/Ms1 albo ciemny/wątpliwy
## — docs/04 §8, docs/systemy/11 §7).
func shows_stop() -> bool:
	return failed or aspect == &"S1" or aspect == &"Sr1" or aspect == &"Ms1"


func set_aspect(new_aspect: StringName) -> void:
	aspect = new_aspect


## Snapshot stanu dynamicznego (konfiguracja pochodzi z pliku stacji).
func to_dict() -> Dictionary:
	return {
		"aspect": String(aspect),
		"failed": failed,
	}


func from_dict(data: Dictionary) -> void:
	aspect = StringName(String(data.get("aspect", String(base_aspect(kind)))))
	failed = bool(data.get("failed", false))
