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

6. **Czas ewolucji doraźnego zwolnienia** — `core/interlocking.gd`
   (`EVOLUTION_TIME_S`). Wg docs/04 §2 wartość zależna od typu urządzeń;
   przyjęto 90 s.
7. **Gaszenie sygnału zastępczego** — `core/interlocking.gd` (`SZ_TIME_S`).
   Wg docs/04 §5: Sz świeci przez ustalony czas (np. 90 s) lub do zajęcia
   pierwszej sekcji, zachowanie zależne od typu urządzeń; w F3 sam timer
   90 s (gaszenie zajęciem sekcji dojdzie z pociągami w F4).
8. **Przyciski współpracujące (dZw, zamknięcie zwrotnicy)** —
   `core/interlocking.gd` (`ARM_TIME_S`). Na pulpicie typu E naciskane
   równocześnie z przyciskiem celu; w grze obsługa sekwencyjna z oknem
   10 s (uzbrojenie → wskazanie celu).
9. **Grupa prędkości drogi przebiegu** — `core/interlocking.gd`
   (`_compute_v_group`). docs/04 §6 wskazuje pole `v_route_kmh`, ale
   semafory Borek nie mają pasów świetlnych, a jazda na wprost przy
   100 km/h musi dawać grupę MAX — przyjęto wyliczanie z geometrii
   (min. v_minus_kmh zwrotnic drogi jazdy w położeniu zwrotnym; wszystkie
   na wprost → MAX), pole `v_route_kmh` informacyjne.

10. **Reżim prędkości przy jeździe na Sz** — `core/train.gd` (`SZ_LIMIT_MS`,
    `_sz_approach_limit`). Wg docs/05 §2 i systemy/11 §3 przyjęto: maszynista
    zwalnia tak, by minąć semafor z Sz z prędkością ≤40 km/h, i utrzymuje
    limit 40 do minięcia następnego semafora. Dokładny reżim wg Ir-1 §61
    do weryfikacji.
11. **Miejsce zatrzymania planowego (W4)** — `core/train.gd`
    (`dwell_point_m`). Uproszczenie F4: środek pierwszej sekcji torowej;
    właściwe wskaźniki W4 przy peronach dojdą z danymi stacji.

12. **Brzmienie formuł telefonogramów** — `core/comms.gd` (`format_message`).
    Parafrazy wg docs/systemy/18 §2; przed 1.0 porównać z Dodatkiem 2 Ir-1.
13. **Układ kolumn dziennika ruchu (R-142)** — `core/train_log.gd`,
    `ui/dokumentacja/dziennik_panel.gd`. Układ gry wg docs/systemy/18 §3,
    dokładny układ druku do weryfikacji.
14. **Obsługa pola Po** — `core/block_line.gd`. Wg docs/systemy/15 §1
    u niektórych odmian Po blokuje się samoczynnie od oddziaływania pociągu
    (konfigurowalne per stacja); przyjęto obsługę ręczną przez gracza,
    w scoringu v1 bez kary za brak.

## Zweryfikowane / zamknięte

_(brak)_
