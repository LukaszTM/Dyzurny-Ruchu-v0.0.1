# 12 — Mechaniczne urządzenia srk (scentralizowane)

Poziom 3 gry: nastawnia mechaniczna z dźwigniami i blokami. Najbardziej „fizyczny"
tryb obsługi — gracz ręcznie wykonuje to, co przekaźniki robią same.

## 1. Elementy nastawni

- **Ława dźwigniowa (nastawnica)** — rząd dźwigni ustawionych wzdłuż okna nastawni:
  - **dźwignie zwrotnicowe** — przestawiają zwrotnice pędniami drutowanymi;
    dwa położenia (+ / −); przełożenie dźwigni = fizyczna praca (w grze: przeciągnięcie
    myszą z animacją ~2 s),
  - **dźwignie ryglowe** — ryglują zwrotnice w położeniu dla jazd po ostrzu,
  - **dźwignie sygnałowe** — podają sygnał na semaforze kształtowym (jedno- lub
    dwuramiennym; dźwignia ma położenia dla Sr2/Sr3),
  - kolory dźwigni wg funkcji `[DO WERYFIKACJI: przyjęte robocze — zwrotnicowe
    niebieskie, ryglowe zielone, sygnałowe czerwone; potwierdzić ze zdjęciami
    polskich nastawni]`, na dźwigniach tabliczki z numerami.
- **Skrzynia zależności** — mechanizm liniałowy pod ławą: fizycznie uniemożliwia
  przełożenie dźwigni w złej kolejności (np. sygnałowej przed ułożeniem i
  zaryglowaniem drogi). W grze: rdzeń (`Interlocking`) zwraca odmowę → dźwignia
  „nie puszcza".
- **Aparat blokowy** — skrzynka nad ławą z **blokami elektromechanicznymi**:
  okienka barwne (czerwone/białe) + klawisze naciskane, obsługiwane z induktorem
  (korbką) lub prądem sieciowym. Realizuje **blokadę stacyjną** (zależności między
  nastawnią dysponującą a wykonawczą) i **blokadę liniową** (patrz `15-...md`).
- **Plan świetlny/tablica** — na starych nastawniach zamiast planu świetlnego jest
  tablica poglądowa torów (bez kontroli zajętości!) — dyżurny sprawdza wolność
  toru WZROKIEM przez okno. W grze: widok z okna (prosta panorama torów) jest
  częścią rozgrywki na tym poziomie.

## 2. Blokada stacyjna (dysponująca ↔ wykonawcza)

Typowe pola blokowe (nazwy robocze, funkcja zgodna z praktyką):
- **„Nakaz" (danie/otrzymanie nakazu)** — dyżurny z dysponującej daje nastawni
  wykonawczej nakaz przygotowania drogi dla konkretnej jazdy; wykonawcza nie może
  podać semafora bez otrzymanego nakazu.
- **„Zwolnienie przebiegu"** — po jeździe wykonawcza zwalnia zależność.
W grze na poziomie 3 gracz obsługuje nastawnię dysponującą, a wykonawczą — AI
(gracz daje nakazy blokiem, AI melduje wykonanie). `[DO WERYFIKACJI: dokładne
nazwy pól blokowych w polskich urządzeniach — przyjąć robocze i wyświetlać opisowe
etykiety]`

## 3. Sekwencja nastawienia wjazdu (poziom 3, pełna)

1. Zapowiedź pociągu (telefonogram/blokada liniowa).
2. Sprawdzenie wolności toru — spojrzenie na tor (widok z okna) + ew. zapis.
3. Przestawienie dźwigni zwrotnicowych do właściwych położeń (kolejno).
4. Przełożenie dźwigni ryglowej (rygluje zwrotnice drogi).
5. (Jeśli dotyczy) obsługa bloków: otrzymanie/danie nakazu.
6. Przełożenie dźwigni sygnałowej → semafor kształtowy podaje Sr2/Sr3.
7. Po wjeździe: dźwignia sygnałowa z powrotem (semafor „Stój"), odryglowanie,
   zwolnienie bloków, telefonogramy, wpisy.
Skrzynia zależności wymusza kolejność 3→4→6 i uniemożliwia 6 bez 3–5.

## 4. Awarie charakterystyczne

- **Pęknięcie pędni** — dźwignia przekłada się „lekko", zwrotnica bez kontroli →
  obsługa zwrotnicy na gruncie (zdarzenie czasowe), jazda z ograniczeniem.
- **Brak prądu induktora** — blokada obsługiwana korbką (mini-interakcja).
- Semafor kształtowy nie ustawia ramienia (zamarznięcie) → sygnał wątpliwy = „Stój",
  jazdy na rozkaz pisemny.

## 5. Model w rdzeniu

Ten sam `Interlocking`; różnice: `manual_sequence = true` (warunki sprawdzane przy
każdej dźwigni osobno, z komunikatem „dźwignia zablokowana"), semafory kształtowe
mają tylko obrazy Sr1/Sr2/Sr3 + Od1/Od2 na tarczy, brak kontroli zajętości sekcji
(sekcje istnieją w rdzeniu, ale UI ich nie pokazuje — realizm!), zwalnianie
przebiegu ręczne po obserwacji końca pociągu.
