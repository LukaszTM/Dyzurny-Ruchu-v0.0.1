class_name Const
extends RefCounted
## Stałe i enumy domenowe rdzenia (konwencje: docs/02-architektura.md).
## Znaczenia stanów: docs/04-logika-zaleznosci.md §2, docs/03-model-danych.md §1–2.


## Położenie zwrotnicy: zasadnicze (PLUS) / zwrotne (MINUS).
enum TurnoutPos { PLUS, MINUS }

## Stan zwrotnicy wg docs/04 §2: położenie z kontrolą, przestawianie bez kontroli,
## usterka (brak kontroli) lub rozprucie.
enum TurnoutState { PLUS, MINUS, MOVING, NO_CONTROL, TRAILED }

## Typ odcinka izolowanego (docs/03 §1): torowy, zwrotnicowy, zbliżania.
enum SectionType { TRACK, TURNOUT, APPROACH }

## Stan przebiegu wg docs/04 §2. SELECTED/SETTING używane przy nastawianiu
## przebiegowym (stacje poziomu 4+); w nastawianiu indywidualnym przebieg
## przechodzi z IDLE wprost do LOCKED.
enum RouteState { IDLE, SELECTED, SETTING, LOCKED, TRAIN_ON, RELEASING, CANCELLED }

## Rodzaj sygnalizatora (docs/03 §2).
enum SignalKind {
	SEMAFOR,
	TARCZA_MANEWROWA,
	TARCZA_OSTRZEGAWCZA,
	POWTARZACZ,
	SEMAFOR_KSZTALTOWY,
	TARCZA_ZAPOROWA,
	TOP,
}

## Mapowania łańcuchów z plików JSON na enumy (docs/03-model-danych.md).
const SECTION_TYPE_FROM_STRING: Dictionary = {
	"track": SectionType.TRACK,
	"turnout": SectionType.TURNOUT,
	"approach": SectionType.APPROACH,
}

const SIGNAL_KIND_FROM_STRING: Dictionary = {
	"semafor": SignalKind.SEMAFOR,
	"tarcza_manewrowa": SignalKind.TARCZA_MANEWROWA,
	"tarcza_ostrzegawcza": SignalKind.TARCZA_OSTRZEGAWCZA,
	"powtarzacz": SignalKind.POWTARZACZ,
	"semafor_ksztaltowy": SignalKind.SEMAFOR_KSZTALTOWY,
	"tarcza_zaporowa": SignalKind.TARCZA_ZAPOROWA,
	"top": SignalKind.TOP,
}

const TURNOUT_POS_FROM_STRING: Dictionary = {
	"PLUS": TurnoutPos.PLUS,
	"MINUS": TurnoutPos.MINUS,
}

## Dozwolone kierunki sygnalizatora i orientacje krawędzi (docs/03 §1).
const DIRECTIONS: Array[String] = ["N", "P"]
