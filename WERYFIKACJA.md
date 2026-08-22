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

15. **Prędkość za rozkazem „S"** — `core/train.gd` (`_pass_signal`).
    Przyjęto reżim jak przy Sz: ≤40 km/h do minięcia następnego semafora;
    dokładny reżim wg Ir-1 do weryfikacji.
16. **Zakres obowiązywania rozkazu „O"** — `core/train.gd`
    (`order_speed_cap_ms`). Ograniczenie 20 km/h przyjęto do końca jazdy
    przez stację (realnie dotyczy wskazanego miejsca) — uproszczenie F6.

17. **Kolory korpusów dźwigni** — `ui/nastawnia_mech/mech_view.gd`
    (`COL_LEVER`). Robocze wg docs/systemy/12 §1: zwrotnicowe niebieskie,
    ryglowe zielone, sygnałowe czerwone — potwierdzić ze zdjęciami
    polskich nastawni.
18. **Nazwy pól blokady stacyjnej** — `data/stations/jodlow.json`,
    `core/lever_frame.gd`. Wg docs/systemy/12 §2 przyjęto robocze:
    „Nakaz wjazd", „Nakaz wyjazd", „Zwol. przeb.".
19. **Konwencja barw okienek blokowych** — `ui/nastawnia_mech/mech_view.gd`
    (`_draw_block_apparatus`). Wg docs/systemy/15 §3 przyjęto: czerwone =
    zablokowane / funkcja wykonana / nakaz dany, białe = odblokowane.
20. **Zwalnianie przebiegu na nastawni mechanicznej** — `core/lever_frame.gd`.
    docs/systemy/12 §5 mówi o ręcznym zwalnianiu po obserwacji końca
    pociągu; uproszczenie F7: zwalnianie sekcyjne w rdzeniu pozostaje
    automatyczne, ręcznie cofa się rygiel i zwalnia nakaz (klawisz
    „Zwol. przeb." działa tylko po zakończonej jeździe).

21. **Obraz ostatniego semafora odstępowego sbl** — `core/block_line.gd`
    (`_automatic_aspect`). Przy jednym wolnym odstępie przed stacją
    sąsiada przyjęto S5 (nie znamy obrazu semafora wjazdowego sąsiada);
    realnie sbl podaje obraz wg następnego sygnalizatora — do weryfikacji
    z docs/systemy/15 §2.
22. **Czasy przejazdu kat. A** — `core/level_crossing.gd`. Przyjęto
    zamykanie 25 s (otwieranie ×0,6) i lampkę: białą ciągłą przy
    zamkniętym, migającą przy ruchu rogatek, czerwoną migającą przy
    awarii — konwencję lampek potwierdzić z dokumentacją EOP/pulpitu.
23. **Procedura dSAT** — `core/sim_world.gd` (`_tick_dsat`). Uproszczenie:
    reakcja dyżurnego = kwit + zatrzymanie pociągu ≤180 s, oględziny
    drużyny 300 s, wynik losowy (60% potwierdzenia → rozkaz „O" 20 km/h
    dalej 40 km/h). Rzeczywiste progi GM/GH/PM i procedura Ir-1 do
    weryfikacji (docs/systemy/17 [DO WERYFIKACJI]).
24. **Detekcja „pociąg zatrzymany do oględzin"** — `core/sim_world.gd`
    (`_is_train_held_by_signal`). Uznajemy przytrzymanie radiostopem albo
    zatrzymanie ≤60 m przed semaforem „stój"; realnie miejsce zatrzymania
    wskazuje dyżurny.

25. **Zakres F9 (komputerowe)** — zrealizowano mechaniki rdzenia:
    nastawianie przebiegowe (`route_set`), polecenia dwustopniowe
    (`command_confirm`/`command_cancel`), rejestr zdarzeń. **LCS-lite
    (zdalne sterowanie 2 posterunkami, docs/systemy/14 §5) ODŁOŻONE** —
    wymaga wielu stacji w SimWorld; do osobnej iteracji po zbudowaniu
    docelowego GUI. Konwencja barw planu CBI (docs/14 §2
    [DO WERYFIKACJI]) nie jest implementowana w widoku referencyjnym —
    plan synoptyczny współdzieli renderer pulpitu; docelowe GUI
    użytkownika powinno ją zastosować.
26. **Lista poleceń specjalnych** — `core/sim_world.gd`
    (`SPECIAL_COMMANDS`). Przyjęto: Sz, dZw, zamknięcie zwrotnicy,
    RADIOSTOP, otwarcie przejazdu kat. A, pozwolenie blokady (Poz);
    czas na potwierdzenie 30 s. Zestaw i czas do weryfikacji z docs/14 §3.

27. **Parametry generatora ruchu** — `data/scenarios/brzeziny-swobodny.json`.
    Odstępy 5–13 min, proporcje osobowy/towarowy/pospieszny 6:3:1 dobrane
    zdroworozsądkowo — skalibrować po testach grywalności. Wygenerowany
    pociąg ma stały lead 300 s od utworzenia do planowego przyjazdu.

## Zweryfikowane / zamknięte

_(brak)_
