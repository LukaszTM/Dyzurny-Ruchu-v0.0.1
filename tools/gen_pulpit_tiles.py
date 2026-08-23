#!/usr/bin/env python3
"""Proceduralny generator kafelków pulpitu kostkowego (assets/pulpit).

Geometria jest liczona, nie malowana: oś toru zawsze w połowie kostki,
ukosy dokładnie 45° od narożnika do narożnika, łuki Béziera styczne do
sąsiadów — kostki łączą się co do piksela. Wygląd: jasna blacha ze
śrubami, grafitowy pas podtorza, metaliczne szyny z rozbłyskiem.

Użycie:  python3 tools/gen_pulpit_tiles.py   (z katalogu głównego repo)
Lampki, kogut i licznik (lamp_*.png, beacon.png, counter.png) pochodzą
z paczek graficznych użytkownika i NIE są nadpisywane.
"""

from PIL import Image, ImageDraw, ImageChops, ImageFilter
import math
import os

OUT = "assets/pulpit"
TILE = 192          # rozmiar wyjściowy kostki 1x1
SS = 2              # supersampling (rysujemy 2x i zmniejszamy)
S = TILE * SS       # płótno robocze

# Paleta dopasowana do plansz użytkownika.
PLATE = (204, 203, 197)
PLATE_HI = (228, 227, 221)
PLATE_LO = (168, 167, 161)
PLATE_EDGE = (128, 127, 122)
BED_OUT = (40, 40, 44)      # obrys podtorza
BED = (58, 58, 63)          # podtorze
BED_IN = (70, 70, 76)       # rozjaśnienie środka podtorza
RAIL_DARK = (84, 85, 90)    # cień szyny
RAIL = (186, 188, 192)      # stal
RAIL_HI = (236, 237, 240)   # rozbłysk
SCREW_BODY = (172, 171, 167)
SCREW_EDGE = (128, 127, 123)
SCREW_HEX = (104, 103, 99)
INSULATOR = (232, 228, 212)

BED_W = int(S * 0.21)       # szerokość podtorza
RAIL_OFF = int(S * 0.062)   # odsunięcie osi szyny od osi toru
RAIL_W = int(S * 0.030)
EXT = 12                    # wyciągnięcie ścieżki poza krawędź (bez szczelin)


# ---------------------------------------------------------------------------
# Płyta kostki
# ---------------------------------------------------------------------------

def plate(width: int = S, height: int = S, screws: bool = True) -> Image.Image:
    img = Image.new("RGBA", (width, height), PLATE + (255,))
    # Delikatny szum blachy.
    noise = Image.effect_noise((width, height), 14).convert("RGB")
    img = Image.composite(
        Image.blend(img.convert("RGB"), noise, 0.05).convert("RGBA"), img,
        Image.new("L", (width, height), 255))
    # Lekki spadek jasności ku dołowi (oświetlenie z góry).
    grad = Image.linear_gradient("L").resize((width, height))
    dark = ImageChops.multiply(
        img.convert("RGB"),
        Image.merge("RGB", [grad.point(lambda v: 255 - v // 14)] * 3))
    img = dark.convert("RGBA")
    d = ImageDraw.Draw(img)
    r = int(S * 0.035)
    # Fazowana krawędź: jasna góra/lewo, ciemny dół/prawo, ciemny obrys.
    d.rounded_rectangle([1, 1, width - 2, height - 2], radius=r,
                        outline=PLATE_EDGE, width=2)
    d.rounded_rectangle([3, 3, width - 4, height - 4], radius=r,
                        outline=PLATE_HI, width=2)
    d.rounded_rectangle([5, 5, width - 6, height - 6], radius=r,
                        outline=PLATE_LO, width=1)
    if screws:
        inset = int(S * 0.115)
        for cx, cy in [(inset, inset), (width - inset, inset),
                       (inset, height - inset), (width - inset, height - inset)]:
            _screw(d, cx, cy, int(S * 0.036))
    return img


def _screw(d: ImageDraw.ImageDraw, cx: int, cy: int, r: int) -> None:
    for i in range(r, 0, -1):
        t = i / r
        c = tuple(int(SCREW_BODY[k] * (0.75 + 0.35 * (1 - t))) for k in range(3))
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=c)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=SCREW_EDGE, width=2)
    hexr = int(r * 0.55)
    pts = [(cx + hexr * math.cos(a), cy + hexr * math.sin(a))
           for a in [math.pi / 6 + k * math.pi / 3 for k in range(6)]]
    d.polygon(pts, fill=SCREW_HEX)
    d.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], 200, 320,
          fill=(255, 255, 255, 90), width=2)


# ---------------------------------------------------------------------------
# Ścieżki torów
# ---------------------------------------------------------------------------

def _extend(pts: list) -> list:
    """Wyciąga końce ścieżki poza kostkę, żeby pas dochodził do krawędzi."""
    def push(a, b):
        vx, vy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(vx, vy) or 1.0
        return (b[0] + vx / n * EXT, b[1] + vy / n * EXT)
    out = list(pts)
    out[0] = push(pts[1], pts[0])
    out[-1] = push(pts[-2], pts[-1])
    return out


def _offset(pts: list, dist: float) -> list:
    """Ścieżka równoległa (offset po normalnych)."""
    out = []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        vx, vy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(vx, vy) or 1.0
        out.append((p[0] - vy / n * dist, p[1] + vx / n * dist))
    return out


def _polyline(d: ImageDraw.ImageDraw, pts: list, color, width: int) -> None:
    d.line(pts, fill=color, width=width, joint="curve")
    for p in (pts[0], pts[-1]):
        r = width / 2.0
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def draw_track(img: Image.Image, pts: list, rails_from: float = 0.0,
        bed: bool = True) -> None:
    """Pas toru wzdłuż ścieżki: podtorze + dwie szyny z rozbłyskiem.
    rails_from = ułamek długości, od którego rysować szyny (rozjazd)."""
    d = ImageDraw.Draw(img)
    pts = _extend(pts)
    if bed:
        _polyline(d, pts, BED_OUT, BED_W + 8)
        _polyline(d, pts, BED, BED_W)
        _polyline(d, pts, BED_IN, int(BED_W * 0.55))
    start = int(len(pts) * rails_from)
    seg = pts[start:] if len(pts) - start >= 2 else pts[-2:]
    for side in (-1, 1):
        rail = _offset(seg, side * RAIL_OFF)
        _polyline(d, rail, RAIL_DARK, RAIL_W + 2)
        _polyline(d, rail, RAIL, RAIL_W)
        _polyline(d, rail, RAIL_HI, max(2, RAIL_W // 3))


def bezier(p0, p1, p2, n: int = 80) -> list:
    out = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        out.append((x, y))
    return out


# ---------------------------------------------------------------------------
# Kafelki
# ---------------------------------------------------------------------------

def save(img: Image.Image, name: str) -> None:
    img = img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
    img.save(f"{OUT}/{name}.png", optimize=True)
    print(f"{name}.png {img.size}")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    c = S / 2.0

    save(plate(), "kostka")
    save(plate(S * 3, S * 2), "kostka_wide")

    img = plate()
    draw_track(img, [(0, c), (S, c)])
    save(img, "track_h")

    img = plate()
    draw_track(img, [(c, 0), (c, S)])
    save(img, "track_v")

    img = plate()
    draw_track(img, [(0, S), (S, 0)])
    save(img, "diag_ne")

    img = plate()
    draw_track(img, [(0, 0), (S, S)])
    save(img, "diag_nw")

    # Łuk: narożnik dolny-lewy (styczna 45°) -> środek prawej krawędzi.
    img = plate()
    draw_track(img, bezier((0, S), (c, c), (S, c)))
    save(img, "curve_se")
    img = plate()
    draw_track(img, bezier((S, S), (c, c), (0, c)))
    save(img, "curve_sw")

    # Rozjazd: tor poziomy + odgałęzienie od osi do narożnika (iglice
    # zaczynają się przed środkiem, szyny odgałęzienia od rozwidlenia).
    img = plate()
    draw_track(img, bezier((S * 0.18, c), (c, c), (S, 0)), rails_from=0.22)
    draw_track(img, [(0, c), (S, c)])
    save(img, "turnout_ne")
    img = plate()
    draw_track(img, bezier((S * 0.82, c), (c, c), (0, 0)), rails_from=0.22)
    draw_track(img, [(0, c), (S, c)])
    save(img, "turnout_nw")

    # Skrzyżowanie z ukosem (zapas).
    img = plate()
    draw_track(img, [(0, S), (S, 0)])
    draw_track(img, [(0, c), (S, c)])
    save(img, "crossing_diag")

    # Przerwa izolacyjna: szyny przerwane, biały łubek między nimi.
    img = plate()
    d = ImageDraw.Draw(img)
    gap = int(S * 0.055)
    draw_track(img, [(0, c), (c - gap, c)])
    draw_track(img, [(c + gap, c), (S, c)])
    d.rounded_rectangle(
        [c - gap * 0.55, c - RAIL_OFF - RAIL_W, c + gap * 0.55, c + RAIL_OFF + RAIL_W],
        radius=6, fill=INSULATOR, outline=(120, 116, 100), width=3)
    save(img, "insulation")


if __name__ == "__main__":
    main()
