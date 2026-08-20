# 17 — Urządzenia detekcji stanów awaryjnych taboru (dSAT)

Przytorowe urządzenia diagnostyczne na szlaku, mierzące przejeżdżający tabor.
W grze pod nazwą rodzajową „dSAT" (nazwy handlowe konkretnych systemów —
nie używać w grze, patrz `docs/01-podstawy-prawne.md`).

## 1. Co wykrywa

| Kod | Stan | Ryzyko |
|---|---|---|
| **GM** | gorąca maźnica (przegrzane łożysko osi) | zatarcie, wykolejenie |
| **GH** | gorący hamulec (zakleszczone hamulce) | pożar, uszkodzenie kół |
| **PM** | płaskie miejsce na kole (deformacja) | uszkodzenia toru i taboru |

## 2. Stanowisko dyżurnego

Terminal/panel z komunikatami: przy przejeździe pociągu przez czujnik pojawia się
raport („pociąg nr, oś nr, kod, poziom: OSTRZEŻENIE/ALARM"), alarm dźwiękowy
wymagający skwitowania. Poziomy:
- **Ostrzeżenie** — obserwacja, powiadomienie maszynisty przez radio, jazda do
  najbliższej stacji ze zmniejszoną prędkością.
- **Alarm** — **natychmiastowe zatrzymanie pociągu**: dyżurny podaje „stój" na
  najbliższym semaforze przed pociągiem / wywołuje radiostop-owo maszynistę,
  kieruje pociąg na tor, gdzie możliwe oględziny.

## 3. Procedura w grze (zdarzenie `dsat_alarm`)

1. Komunikat + alarm (kwitowanie).
2. Gracz: radiotelefon do maszynisty (formuła „pociąg nr X stój / jazda do toru Y
   ze zmniejszoną prędkością") **lub** przytrzymanie pociągu semaforem.
3. Zatrzymanie na wskazanym torze → oględziny (AI drużyna, czas 5–10 min sym.).
4. Wynik losowany: usterka potwierdzona (wagon wyłączony — pociąg rusza z
   opóźnieniem / wzywana lokomotywa) lub fałszywy alarm.
5. Wpisy do dokumentacji + telefonogram do sąsiada o opóźnieniu.
Scoring: brak reakcji w N minut = zdarzenie niebezpieczne.

## 4. Model w rdzeniu (`Dsat`)

Punkt na krawędzi szlaku; przy przejeździe pociągu losuje/odczytuje z scenariusza
zdarzenie z prawdopodobieństwem; publikuje `dsat_alarm {train, code, level, axle}`.
