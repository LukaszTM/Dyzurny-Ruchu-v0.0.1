# 22 — Wygląd nastawni mechanicznej (specyfikacja)

Widok 2D „od wnętrza nastawni": pierwszy plan — ława dźwigni i aparat blokowy,
w tle okno z panoramą torów (tam gracz „patrzy" na pociągi i sprawdza wolność toru).

## 1. Kompozycja ekranu

```
┌──────────────────────────────────────────────────────────────┐
│   OKNO NASTAWNI: panorama torów (przewijana ←→, parallax)     │ 45%
├──────────────────────────────────────────────────────────────┤
│   APARAT BLOKOWY: rząd pól blokowych z klawiszami + induktor │ 20%
├──────────────────────────────────────────────────────────────┤
│   ŁAWA DŹWIGNIOWA: dźwignie nr 1..n (widok z boku/¾)          │ 35%
└──────────────────────────────────────────────────────────────┘
```
Osobne zakładki (klawisze): telefon, dokumentacja, plan poglądowy stacji (tablica).

## 2. Dźwignie

- Rysunek z boku: smukła dźwignia ~140 px wysokości na wspólnej osi, rękojeść
  z zapadką (ciężarkiem). Dwa położenia: pionowe (zasadnicze) i przełożone ~40°.
- Animacja przełożenia 1,5–2 s (gracz przeciąga myszą; zapadka „klika").
- Kolory korpusów `[robocze — DO WERYFIKACJI]`: zwrotnicowe **niebieskie**,
  ryglowe **zielone**, sygnałowe **czerwone**; numer na emaliowanej tabliczce
  (białe tło, czarna cyfra) na osi.
- Dźwignia zablokowana zależnością: przy próbie ruchu drga 2–3 px + głuchy stuk;
  w trybie szkolenia tooltip z przyczyną („najpierw przełóż rygiel 4").

## 3. Aparat blokowy

- Skrzynia drewniano-metalowa (dąb `#6E4F2A` + blacha `#8C8C8C`), na froncie
  **pola blokowe**: okienka 26×36 px w mosiężnych ramkach, nad każdym etykieta
  („Po Lipno", „Ko Lipno", „Poz", „Nakaz wjazd", „Zwol. przeb.").
- Stan pola: okienko **białe** lub **czerwone** (przesuwna przesłona — animacja
  rolety przy zmianie) `[DO WERYFIKACJI: konwencja czerwone=zablokowane]`.
- Pod każdym polem klawisz (przycisk do wciśnięcia dłonią); z boku **korbka
  induktora**: interakcja = przytrzymanie i ruch kołowy myszą 2 s (pasek postępu),
  dźwięk terkotu.
- Dzwonek blokady (czasza na aparacie) — dzwoni przy zgłoszeniach sąsiada.

## 4. Okno / panorama torów

- Sylwetkowa grafika 2D: tory, perony, semafory kształtowe (ramiona animowane
  łukiem 0,8 s + skrzyp), pociągi przesuwające się poziomo, pora doby (świty/noce —
  nocą sygnały świetlne nabierają znaczenia!).
- Zoom x1/x2 i przewijanie — odległe elementy słabo widoczne (lorneta = x3,
  ograniczone pole) — celowy element trudności sprawdzania wolności toru.
- Semafor kształtowy: maszt kratowy, ramię czerwone z białym pasem; w nocy
  latarnie (czerwona/zielona/pomarańczowa) wg `docs/systemy/11 §7`.

## 5. Paleta ogólna

Wnętrze: ściany `#CFC9B8`, lamperia `#7A6A4F`, podłoga deski `#8A6B45`.
Metal dźwigni `#3E434A`, przetarcia jaśniejsze. Oświetlenie ciepłe (żarówka),
nocą lampka nad ławą (winieta). Styl: czytelny półrealizm, grube kontury 2 px.
