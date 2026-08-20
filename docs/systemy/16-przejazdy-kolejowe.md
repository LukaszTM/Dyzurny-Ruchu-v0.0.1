# 16 — Przejazdy kolejowo-drogowe

## 1. Kategorie (wg rozporządzenia o skrzyżowaniach)

| Kat. | Zabezpieczenie | Rola w grze |
|---|---|---|
| **A** | rogatki obsługiwane (przez dróżnika lub zdalnie z nastawni) | gracz/AI zamyka przed jazdą |
| **B** | samoczynne: sygnalizacja + rogatki (półrogatki) | ssp, kontrola na pulpicie |
| **C** | samoczynne: tylko sygnalizacja świetlna drogowa | ssp, kontrola na pulpicie |
| **D** | bez urządzeń (znaki drogowe) | tło wizualne, zdarzenia |
| **E** | przejścia dla pieszych | tło |
| **F** | przejazdy użytku niepublicznego | tło |

## 2. Przejazd kategorii A (obsługiwany)

- Zamknięcie rogatek PRZED podaniem sygnału na semaforze osłaniającym przejazd —
  w urządzeniach powiązany z przebiegiem (warunek utwierdzenia, `docs/04 §3.7`),
  na starszych posterunkach: obowiązek proceduralny (gra punktuje).
- Obsługa zdalna z nastawni: przycisk „zamknij/otwórz", lampki położenia drągów,
  kamera/wzrok `[w grze: mini-podgląd przejazdu przy zamykaniu]`, dzwonek ostrzegawczy.
- Dróżnik przejazdowy (AI) na odległych przejazdach: dyżurny **zawiadamia go
  telefonicznie o każdym pociździe** (telefonogram do dróżnika — prosty dialog);
  brak zawiadomienia = zdarzenie niebezpieczne.

## 3. Samoczynna sygnalizacja przejazdowa (ssp) — kat. B/C

- Uruchamiana najazdem pociągu na czujniki oddziaływania przed przejazdem;
  po przejeździe wyłącza się. Sygnalizatory drogowe: dwa czerwone migające +
  dzwonki; przy kat. B dodatkowo napęd półrogatek (zamykają się z opóźnieniem
  po starcie sygnalizacji).
- **Tarcza ostrzegawcza przejazdowa (ToP)** przed przejazdem informuje maszynistę:
  Osp2 = ssp sprawna (jazda normalna), Osp1 = niesprawna → ograniczenie prędkości
  przed przejazdem i jazda z ostrożnością (patrz `11-sygnalizacja.md §9`).
- **Zdalna kontrola na pulpicie dyżurnego:** lampki „ssp sprawna / awaria /
  załączona", brzęczyk awarii, licznikowe przyciski wyłączenia awaryjnego.
- Awaria ssp (zdarzenie): dyżurny powiadamia drużyny **rozkazem pisemnym „O"**
  (jazda z ograniczoną prędkością przed przejazdem, baczność) — do czasu usunięcia.

## 4. Model w rdzeniu (`LevelCrossing`)

`{type, state: OPEN/CLOSING/CLOSED/OPENING/FAILURE, close_time_s, linked_sections,
 remote_controlled}`; kat. B/C: automat od zajętości sekcji najazdowych; kat. A:
polecenia gracza/AI dróżnika. Pociąg AI przed przejazdem w stanie FAILURE lub
otwartym (kat. A) zwalnia do 20 km/h i trąbi `[DO WERYFIKACJI: reżim prędkości]`;
jeśli gracz nie dopełnił procedur — scoring rejestruje zdarzenie.
