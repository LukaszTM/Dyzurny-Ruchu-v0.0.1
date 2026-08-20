# 19 — Źródła oficjalne i weryfikacja

## 1. Akty prawne (art. 4 pr. aut. — wolne od praw autorskich)

- **Rozporządzenie Ministra Infrastruktury z 18.07.2005 r. w sprawie ogólnych
  warunków prowadzenia ruchu kolejowego i sygnalizacji** (Dz.U. 2005 nr 172 poz.
  1444, z późn. zm.; tekst jednolity w ISAP: isap.sejm.gov.pl). Zawiera opisy
  sygnałów i zasad ruchu — pierwotne źródło dla `11-sygnalizacja.md`.
- Rozporządzenie w sprawie warunków technicznych, jakim powinny odpowiadać
  skrzyżowania linii kolejowych z drogami (kategorie przejazdów A–F).

## 2. Instrukcje PKP PLK (publicznie udostępniane na plk-sa.pl → Akty prawne i przepisy → Instrukcje)

- **Ie-1 (E-1)** — Instrukcja sygnalizacji (wyd. 2020, z późn. zm.). Załącznik 1:
  zestawienie obrazów sygnałowych semaforów świetlnych.
  Znany URL wydruku: `https://www.plk-sa.pl/files/public/user_upload/pdf/Akty_prawne_i_przepisy/Instrukcje/Wydruk/Ie/Ie-1__E-1__2020_WCAG_.PDF`
- **Ir-1 (R-1)** — Instrukcja o prowadzeniu ruchu pociągów (tekst po zm. 19,
  obowiązujący od 01.07.2026): §23–26 zapowiadanie, §28–29 blokady, §58 rozkazy
  pisemne, Dodatek 2 wzory telefonogramów, załączniki: Dziennik ruchu (1a),
  Książka przebiegów (2), rozkazy „O"/„S"/„N" (3–5).
  Znany URL: `https://www.plk-sa.pl/files/public/user_upload/pdf/Akty_prawne_i_przepisy/Instrukcje/Wydruk/Ir/Instrukcja_Ir-1_po_zm_19__od_01_07_26.pdf`
- **Ir-2** — Instrukcja dla personelu obsługi urządzeń srk (obsługa urządzeń
  z perspektywy pracownika — cenna do weryfikacji procedur obsługi pulpitu).
- **Ie-4 (WTB-E10)** — Wytyczne techniczne budowy urządzeń srk (szczegóły
  techniczne urządzeń, symbole planów).
- **Ir-7** — o postępowaniu w razie wypadków/wydarzeń (dla zdarzeń w grze, opcjonalnie).

Uwaga: URL-e mogą się zmieniać wraz z nowelizacjami — szukaj po nazwie instrukcji
na plk-sa.pl.

## 3. Procedura weryfikacji znaczników [DO WERYFIKACJI]

1. Pobierz PDF-y Ie-1 i Ir-1, umieść w `docs/zrodla-pdf/` projektu.
2. Poleć Claude Code: „Przejdź po wszystkich znacznikach [DO WERYFIKACJI] w docs/
   i WERYFIKACJA.md, porównaj z PDF-ami w docs/zrodla-pdf/ i popraw dokumentację
   oraz dane JSON; wypisz różnice."
3. Elementy wizualne (kolory lampek, dźwigni, wygląd tarcz) weryfikuj dodatkowo
   z własnymi zdjęciami/nagraniami z przestrzeni publicznej — do dokumentacji
   wpisuj opis słowny (zdjęć nie commituj, jeśli nie są Twoje).

## 4. Hierarchia źródeł przy sprzecznościach

Rozporządzenie > aktualna instrukcja PKP PLK > niniejsza dokumentacja > wiedza
potoczna. Gra odwzorowuje stan przepisów na dzień weryfikacji (zapisz datę w
`WERYFIKACJA.md`).
