class_name StationData
extends RefCounted
## Kompletna definicja stacji wczytana z JSON (docs/03-model-danych.md).
## Graf torowy jako obiekty rdzenia; tabela przebiegów, blokady, przejazdy,
## dSAT i opis pulpitu jako surowe słowniki — ich obiekty powstają w kolejnych
## fazach (przebiegi F3, blokady F5, pulpit F2).

var meta: Dictionary = {}
var graph: TrackGraph = TrackGraph.new()
var routes: Array[Dictionary] = []
var blocks: Array[Dictionary] = []
var crossings: Array[Dictionary] = []
var dsat: Array[Dictionary] = []
var panel: Dictionary = {}


func id() -> StringName:
	return StringName(String(meta.get("id", "")))


func display_name() -> String:
	return String(meta.get("name", String(id())))
