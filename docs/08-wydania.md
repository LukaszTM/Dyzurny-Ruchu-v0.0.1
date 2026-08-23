# 08 — Wydania (eksport Windows/Linux)

Presety eksportu są w repo (`export_presets.cfg`): **Linux** (x86_64,
wbudowany PCK) i **Windows** (x86_64, .exe z wbudowanym PCK). Katalog
`tests/`, addon GUT i `tools/` są wykluczone z paczki.

## Wymagania jednorazowe

1. Godot **4.3 stable** (ta sama wersja co projekt).
2. Szablony eksportu 4.3: w edytorze *Editor → Manage Export Templates →
   Download and Install* (albo plik `Godot_v4.3-stable_export_templates.tpz`
   z oficjalnych wydań Godota, instalowany tym samym oknem).

## Eksport z edytora

*Project → Export…* → wybierz preset **Linux** albo **Windows** →
*Export Project*. Ścieżki wyjściowe: `build/linux/…x86_64`,
`build/windows/…exe`.

## Eksport z konsoli (CI / powtarzalny)

```bash
godot --headless --import            # świeży import zasobów
godot --headless --export-release "Linux"   build/linux/symulator-dyzurnego-ruchu.x86_64
godot --headless --export-release "Windows" build/windows/symulator-dyzurnego-ruchu.exe
```

Przed wydaniem: `godot --headless -s addons/gut/gut_cmdln.gd`
(wszystkie testy muszą być zielone) i krótki smoke test każdej paczki.

## Wersjonowanie

`config/version` w `project.godot` + wpis w `CHANGELOG.md`. Zapisy gry
(`user://saves/*.json`) niosą pełny snapshot i wersję formatu w polu
`version` — przy zmianach formatu podbić `GameState.SAVE_VERSION`.

## i18n

Gra jest jednojęzyczna (polski, CLAUDE.md zasada 7). Przygotowanie do
tłumaczeń (ekstrakcja tekstów do `tr()`/CSV) jest ODŁOŻONE — pozycja
w WERYFIKACJA.md; teksty gracza są dziś literałami w UI i danych JSON.
