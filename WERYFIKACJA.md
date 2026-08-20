# WERYFIKACJA

Rejestr elementów zaimplementowanych wg opisów oznaczonych [DO WERYFIKACJI]
w dokumentacji (CLAUDE.md, zasada 2). Każdy wpis: plik/miejsce w kodzie,
czego dotyczy wątpliwość, źródło w docs.

## Otwarte pozycje

1. **Lampki kontroli położenia zwrotnicy** — `ui/pulpit_kostkowy/pulpit_tile.gd`
   (`_draw_position_lamps`). Wg assets-spec/20 §3 w wielu urządzeniach położenie
   pokazuje pojedyncza lampka/podświetlenie kierunku; przyjęto dwie lampki
   (świeci strona, w którą droga zwarta). Docelowo parametr stylu.
2. **Kolory główek przycisków** — `ui/pulpit_kostkowy/pulpit_tile.gd`
   (`_button_color`). Wg assets-spec/20 §4 kolory robocze: zwrotnicowe szare,
   sygnałowe zielone, specjalne czerwone pod plombą — do weryfikacji ze
   zdjęciami pulpitów typu E.
3. **Kolory powtarzaczy semaforów w typie E** — `ui/pulpit_kostkowy/pulpit_tile.gd`
   (`_repeater_color`). Wg docs/systemy/13 §1 przyjęto: zielony = zezwalający,
   czerwony = „stój", biały migający = Sz.
4. **Sygnalizacja braku kontroli zwrotnicy** — `ui/pulpit_kostkowy/pulpit_tile.gd`
   (`_draw_position_lamps`). Wg docs/systemy/13 §1/§5: miganie + brzęczyk;
   przyjęto miganie obu lampek na czerwono (NO_CONTROL/TRAILED), brzęczyk
   dojdzie z dźwiękami (F10).
5. **Mapowanie naciśnij/pociągnij per typ przycisku** —
   `ui/pulpit_kostkowy/pulpit_tile.gd` (`setup`). Wg docs/systemy/13 §1
   konfigurowalne w JSON `panel.tiles[].actions`; w F2 obsługiwane tylko
   naciśnięcie (pociągnięcie — F3, kasowanie przebiegu).

## Zweryfikowane / zamknięte

_(brak)_
