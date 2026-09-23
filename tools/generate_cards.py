#!/usr/bin/env python3
"""Generate the original Shadowfetch Blackjack playing-card textures.

Everything is drawn procedurally from vector shapes (suit symbols, court
figures, ornaments) plus the bundled OFL fonts in ``assets/fonts``; no
third-party artwork is used. Drawing happens at ``SS``x supersampling and is
downscaled with Lanczos for clean antialiased edges.

Outputs (all 500 x 700 px, RGBA, full-bleed; the 3D card mesh rounds the
corners itself, so every corner keeps a 30 x 30 px area of plain paper):

* ``assets/cards/classic/{RANK}{SUIT}.png``   -- 52 faces, two-colour deck
  (spades/clubs near-black, hearts/diamonds deep red).
* ``assets/cards/fourcolor/{RANK}{SUIT}.png`` -- 52 faces, four-colour deck
  (spades black, hearts red, diamonds blue, clubs green).
* ``assets/cards/backs/{emerald,onyx,crimson,sapphire}.png`` -- card backs.

RANK is one of A 2 3 4 5 6 7 8 9 10 J Q K and SUIT one of S H D C.

The script also removes the legacy flat textures that used to live directly
in ``assets/cards`` (``AS.png``, ``back.png``, ... and their ``.import``
sidecars). Output is deterministic: the only randomness is the paper grain,
which is seeded from each file name.

Usage (from the repository root)::

    python3 tools/generate_cards.py
"""
from __future__ import annotations

import math
import zlib
from functools import lru_cache
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
CARDS_DIR = ROOT / "assets" / "cards"
FONT_DIRS = [
    ROOT / "assets" / "fonts",
    Path("/usr/share/fonts/truetype/noto"),
    Path("/usr/share/fonts/opentype/inter"),
]

W, H = 500, 700          # final texture size
SS = 4                   # supersampling factor
LANCZOS = Image.Resampling.LANCZOS

SERIF_BOLD = "NotoSerifDisplay-Bold.ttf"
SANS_SEMI = "Inter-SemiBold.otf"


def rgb(hex_code: str) -> tuple[int, int, int]:
    h = hex_code.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


PAPER = rgb("#FBF7EE")
PANEL = rgb("#F5EDDC")
SKIN = rgb("#F8EEDB")
FRAME_GOLD = rgb("#C9A24A")
GOLD = rgb("#D4AF37")
GOLD_DARK = rgb("#8A6A1D")
INK = rgb("#16120F")
RED = rgb("#B3202A")
BLUE = rgb("#1F5FB8")
GREEN = rgb("#1E7A3C")

RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
SUITS = ["S", "H", "D", "C"]
DECKS = {
    "classic": {"S": INK, "H": RED, "D": RED, "C": INK},
    "fourcolor": {"S": INK, "H": RED, "D": BLUE, "C": GREEN},
}
BACKS = {
    "emerald": rgb("#0E4D35"),
    "onyx": rgb("#101010"),
    "crimson": rgb("#6E1420"),
    "sapphire": rgb("#10284F"),
}

# --- layout (final pixels) -------------------------------------------------
FRAME_INSET = 22
FRAME_RADIUS = 32
IDX_CX = 82              # centre of the corner-index column
IDX_TOP = 36             # cap-height top of the rank
RANK_CAP = 105           # cap height of the rank (15 % of card height)
RANK_MAX_W = 100         # index column width; "10" is condensed to fit
RANK_CONDENSE = 0.93     # gentle overall condensing of the index glyphs
IDX_PIP = 62             # suit pip height in the index (~9 % of height)
IDX_PIP_GAP = 19         # gap between baseline and index pip
FIELD_PIP = 62           # centre pips
FIELD_COLS = (180, 250, 320)
FIELD_TOP, FIELD_BOTTOM = 152, 548

# Court panel: a stepped rectangle whose top-left / bottom-right corners are
# notched out around the indices (180-degree symmetric).
PANEL_BOX = (40, 40, 460, 660)
PANEL_NOTCH = (144, 250)

Point = tuple[float, float]


# =============================================================================
# geometry helpers
# =============================================================================
def cubic(p0: Point, p1: Point, p2: Point, p3: Point, n: int = 40) -> list[Point]:
    out = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        a, b, c, d = mt * mt * mt, 3 * mt * mt * t, 3 * mt * t * t, t * t * t
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def chain(start: Point, segs, n: int = 40) -> list[Point]:
    """Poly-bezier: ``segs`` is a list of (c1, c2, end) cubic segments."""
    pts = [start]
    cur = start
    for c1, c2, end in segs:
        pts.extend(cubic(cur, c1, c2, end, n)[1:])
        cur = end
    return pts


def mirror_close(right: list[Point]) -> list[Point]:
    """Close a right-half outline (running top->bottom) by mirroring on x=0."""
    left = [(-x, y) for x, y in reversed(right)]
    return right + left[1:-1]


def circle_pts(cx: float, cy: float, r: float, n: int = 120, a0: float = 0.0) -> list[Point]:
    return [(cx + r * math.cos(a0 + 2 * math.pi * i / n), cy + r * math.sin(a0 + 2 * math.pi * i / n))
            for i in range(n)]


def ellipse_pts(cx, cy, rx, ry, n=120, rot=0.0) -> list[Point]:
    c, s = math.cos(rot), math.sin(rot)
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x, y = rx * math.cos(t), ry * math.sin(t)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def arc_pts(cx, cy, r, a0, a1, n=60) -> list[Point]:
    return [(cx + r * math.cos(a0 + (a1 - a0) * i / n), cy + r * math.sin(a0 + (a1 - a0) * i / n))
            for i in range(n + 1)]


def catmull(points: list[Point], closed: bool = True, n: int = 14) -> list[Point]:
    """Catmull-Rom spline through ``points``."""
    pts = list(points)
    count = len(pts)
    out = []
    rng = range(count) if closed else range(count - 1)
    for i in rng:
        p0 = pts[(i - 1) % count] if closed else pts[max(i - 1, 0)]
        p1 = pts[i]
        p2 = pts[(i + 1) % count] if closed else pts[i + 1]
        p3 = pts[(i + 2) % count] if closed else pts[min(i + 2, count - 1)]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t
                                    + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in range(2)))
    if not closed:
        out.append(pts[-1])
    return out


def xform(polys, cx=0.0, cy=0.0, size=1.0, rot_deg=0.0, sx=1.0, sy=1.0):
    """Scale unit polygons by ``size`` (with extra sx/sy), rotate, translate."""
    a = math.radians(rot_deg)
    c, s = math.cos(a), math.sin(a)
    out = []
    for poly in polys:
        q = []
        for x, y in poly:
            x, y = x * size * sx, y * size * sy
            q.append((cx + x * c - y * s, cy + x * s + y * c))
        out.append(q)
    return out


def rot180(polys, cx=W / 2, cy=H / 2):
    return [[(2 * cx - x, 2 * cy - y) for x, y in p] for p in polys]


LOZENGE = [[(0, -1), (0.66, 0), (0, 1), (-0.66, 0)]]


# =============================================================================
# suit symbols (unit height, centred on the origin, y down)
# =============================================================================
def _stem(top_y: float, top_w: float, bot_w: float, bot_y: float = 0.50) -> list[Point]:
    right = chain((top_w, top_y), [((top_w + 0.012, bot_y - 0.20), (bot_w * 0.55, bot_y - 0.06), (bot_w, bot_y))])
    base = cubic((bot_w, bot_y), (bot_w * 0.4, bot_y - 0.025), (-bot_w * 0.4, bot_y - 0.025), (-bot_w, bot_y), 16)
    left = [(-x, y) for x, y in reversed(right)]
    return right + base[1:-1] + left


def suit_heart() -> list[list[Point]]:
    right = chain((0, -0.30), [
        ((0.04, -0.45), (0.15, -0.51), (0.27, -0.51)),
        ((0.43, -0.51), (0.53, -0.39), (0.53, -0.22)),
        ((0.53, 0.02), (0.30, 0.20), (0.0, 0.50)),
    ])
    return [mirror_close(right)]


def suit_spade() -> list[list[Point]]:
    right = chain((0, -0.50), [
        ((0.07, -0.34), (0.52, -0.21), (0.52, 0.04)),
        ((0.52, 0.20), (0.42, 0.29), (0.285, 0.29)),
        ((0.16, 0.29), (0.07, 0.23), (0.025, 0.15)),
    ])
    return [mirror_close(right), _stem(0.10, 0.032, 0.20)]


def suit_club() -> list[list[Point]]:
    r = 0.238
    return [
        circle_pts(0, -0.262, r),
        circle_pts(-0.268, 0.076, r),
        circle_pts(0.268, 0.076, r),
        [(0, -0.20), (-0.21, 0.10), (0.0, 0.17), (0.21, 0.10)],
        _stem(0.10, 0.036, 0.20),
    ]


def suit_diamond() -> list[list[Point]]:
    w = 0.41
    right = chain((0, -0.5), [
        ((w * 0.30, -0.36), (w * 0.62, -0.20), (w, 0)),
        ((w * 0.62, 0.20), (w * 0.30, 0.36), (0, 0.5)),
    ])
    return [mirror_close(right)]


SUIT_SHAPES = {"S": suit_spade, "H": suit_heart, "D": suit_diamond, "C": suit_club}
# optical size compensation (width, height multipliers)
SUIT_OPTICAL = {"S": (1.0, 1.0), "H": (0.97, 0.95), "D": (1.06, 1.07), "C": (1.0, 0.99)}


def suit_polys(suit: str, cx: float, cy: float, size: float, rot: float = 0.0):
    ox, oy = SUIT_OPTICAL[suit]
    return xform(SUIT_SHAPES[suit](), cx, cy, size, rot, ox, oy)


# =============================================================================
# fonts / textures / painter
# =============================================================================
@lru_cache(maxsize=None)
def font(name: str, px: int) -> ImageFont.FreeTypeFont:
    for d in FONT_DIRS:
        p = d / name
        if p.exists():
            return ImageFont.truetype(str(p), px)
    raise FileNotFoundError(f"font {name} not found in {FONT_DIRS}")


@lru_cache(maxsize=None)
def cap_ratio(fontname: str) -> float:
    b = font(fontname, 1000).getbbox("H", anchor="ls")
    return -b[1] / 1000.0


def _ramp(v: np.ndarray, stops) -> np.ndarray:
    xs = [s[0] for s in stops]
    out = np.zeros(v.shape + (3,), np.float32)
    for ch in range(3):
        out[..., ch] = np.interp(v, xs, [s[1][ch] for s in stops])
    return out


@lru_cache(maxsize=None)
def gold_texture(w: int, h: int, bands: float = 2.6) -> Image.Image:
    """Brushed-foil gold with soft diagonal bands (hi-res RGBA)."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (xx + 0.55 * yy) / float(w) * bands
    v = 0.5 + 0.425 * np.sin(2 * math.pi * t) + 0.075 * np.sin(2 * math.pi * t * 3.7 + 1.3)
    arr = _ramp(v, [(0.0, rgb("#94731F")), (0.35, rgb("#BF9A30")), (0.62, GOLD),
                    (0.86, rgb("#E9CF78")), (1.0, rgb("#F6E7B0"))])
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


class Painter:
    """Draws filled shapes / strokes onto an opaque hi-res RGBA canvas.

    Coordinates are given in *final* pixels and multiplied by ``SS``. A paint
    is either an RGB tuple or a texture image the size of the canvas.
    """

    def __init__(self, img: Image.Image):
        self.img = img
        self.w, self.h = img.size

    def _box(self, pts, pad: float):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0 = max(int(math.floor(min(xs) * SS - pad)), 0)
        y0 = max(int(math.floor(min(ys) * SS - pad)), 0)
        x1 = min(int(math.ceil(max(xs) * SS + pad)) + 1, self.w)
        y1 = min(int(math.ceil(max(ys) * SS + pad)) + 1, self.h)
        return x0, y0, max(x1, x0 + 1), max(y1, y0 + 1)

    def poly_mask(self, polys, pad: float = 4):
        x0, y0, x1, y1 = self._box([p for poly in polys for p in poly], pad)
        m = Image.new("L", (x1 - x0, y1 - y0), 0)
        d = ImageDraw.Draw(m)
        for poly in polys:
            if len(poly) >= 3:
                d.polygon([(x * SS - x0, y * SS - y0) for x, y in poly], fill=255)
        return m, (x0, y0)

    def line_mask(self, lines, width: float, closed: bool = False):
        x0, y0, x1, y1 = self._box([p for ln in lines for p in ln], width * SS + 4)
        m = Image.new("L", (x1 - x0, y1 - y0), 0)
        d = ImageDraw.Draw(m)
        wpx = max(1, int(round(width * SS)))
        r = wpx / 2
        for ln in lines:
            pts = [(x * SS - x0, y * SS - y0) for x, y in ln]
            if closed:
                pts = pts + pts[:2]
            d.line(pts, fill=255, width=wpx, joint="curve")
            if not closed:
                for px, py in (pts[0], pts[-1]):
                    d.ellipse((px - r, py - r, px + r, py + r), fill=255)
        return m, (x0, y0)

    def paint(self, mask: Image.Image, origin, paint, alpha: float = 1.0) -> None:
        x0, y0 = origin
        if alpha < 1.0:
            mask = mask.point(lambda v, a=alpha: int(v * a + 0.5))
        box = (x0, y0, x0 + mask.width, y0 + mask.height)
        if isinstance(paint, Image.Image):
            self.img.paste(paint.crop(box), box, mask)
        else:
            self.img.paste(tuple(paint) + (255,), box, mask)

    def paint_clipped(self, mask: Image.Image, origin, paint, alpha: float = 1.0) -> None:
        x0, y0 = origin
        cx0, cy0 = max(x0, 0), max(y0, 0)
        cx1, cy1 = min(x0 + mask.width, self.w), min(y0 + mask.height, self.h)
        if cx1 <= cx0 or cy1 <= cy0:
            return
        self.paint(mask.crop((cx0 - x0, cy0 - y0, cx1 - x0, cy1 - y0)), (cx0, cy0), paint, alpha)

    def fill(self, polys, paint, alpha: float = 1.0) -> None:
        m, o = self.poly_mask(polys)
        self.paint(m, o, paint, alpha)

    def stroke(self, lines, paint, width: float, closed: bool = False, alpha: float = 1.0) -> None:
        m, o = self.line_mask(lines, width, closed)
        self.paint(m, o, paint, alpha)

    def shape(self, polys, fill, outline=None, width: float = 0.0) -> None:
        if fill is not None:
            self.fill(polys, fill)
        if outline is not None and width > 0:
            self.stroke(polys, outline, width, closed=True)

    def ellipse(self, cx, cy, rx, ry, fill, outline=None, width=0.0, rot=0.0) -> None:
        self.shape([ellipse_pts(cx, cy, rx, ry, 160, rot)], fill, outline, width)

    def dot(self, cx, cy, r, paint, alpha: float = 1.0) -> None:
        self.fill([circle_pts(cx, cy, r, max(12, int(r * 6)))], paint, alpha)

    def ring(self, cx, cy, r, width, paint, alpha: float = 1.0) -> None:
        self.stroke([circle_pts(cx, cy, r, 360)], paint, width, closed=True, alpha=alpha)


def new_canvas(color=PAPER) -> tuple[Image.Image, Painter]:
    img = Image.new("RGBA", (W * SS, H * SS), tuple(color) + (255,))
    return img, Painter(img)


def finish(img: Image.Image, seed_name: str, grain: float = 1.0) -> Image.Image:
    """Downscale, add a very soft deterministic paper grain, force opaque.

    The grain is low-frequency mottling plus a few sparse horizontal fibres,
    at most +-3 levels: invisible at play size, and it keeps PNGs compact.
    """
    small = img.resize((W, H), LANCZOS)
    arr = np.asarray(small).astype(np.float32)
    rng = np.random.default_rng(zlib.crc32(seed_name.encode()))
    mottle = ndimage.gaussian_filter(rng.normal(0.0, 1.0, (H, W)).astype(np.float32), 3.0)
    mottle /= mottle.std() + 1e-6
    fib = ndimage.gaussian_filter(rng.normal(0.0, 1.0, (H, W)).astype(np.float32), (0.5, 6.0))
    fib /= fib.std() + 1e-6
    g = np.round(mottle * 1.2 * grain + np.where(np.abs(fib) > 2.2, np.sign(fib), 0.0)).clip(-3, 3)
    arr[..., :3] += g[..., None]
    arr[..., 3] = 255
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


# =============================================================================
# card face building blocks
# =============================================================================
def draw_frame(p: Painter) -> None:
    i = FRAME_INSET * SS
    ImageDraw.Draw(p.img).rounded_rectangle((i, i, W * SS - i - 1, H * SS - i - 1), radius=FRAME_RADIUS * SS,
                                            outline=FRAME_GOLD + (255,), width=int(2.0 * SS))


def draw_corner_ornaments(p: Painter, color=FRAME_GOLD) -> None:
    """Small stepped art-deco brackets in the two corners without an index."""
    x, y = W - FRAME_INSET - 12, FRAME_INSET + 12
    lines = [[(x - 34, y), (x, y), (x, y + 34)], [(x - 22, y + 6), (x - 6, y + 6), (x - 6, y + 22)]]
    p.stroke(lines, color, 1.6)
    p.stroke(rot180(lines), color, 1.6)
    dots = [circle_pts(x - 18, y + 18, 2.4, 24)]
    p.fill(dots, color)
    p.fill(rot180(dots), color)


@lru_cache(maxsize=None)
def rank_glyph(rank: str) -> tuple[Image.Image, int]:
    """Hi-res mask of an index rank and the row of its cap-height top."""
    size = int(round(RANK_CAP * SS / cap_ratio(SERIF_BOLD)))
    f = font(SERIF_BOLD, size)
    stroke = int(round(0.9 * SS))
    parts = ["1", "0"] if rank == "10" else [rank]
    base = int(size * 1.15)
    crops = []
    for ch in parts:
        m = Image.new("L", (int(size * 1.6), int(size * 1.7)), 0)
        ImageDraw.Draw(m).text((int(size * 0.3), base), ch, font=f, fill=255, anchor="ls",
                               stroke_width=stroke, stroke_fill=255)
        bb = m.getbbox()
        crops.append(m.crop((bb[0], 0, bb[2], m.height)))
    gap = int(0.02 * size)
    glyph = Image.new("L", (sum(c.width for c in crops) + gap * (len(crops) - 1), crops[0].height), 0)
    x = 0
    for c in crops:
        glyph.paste(c, (x, 0))
        x += c.width + gap
    # squash descenders (J, Q tails) so the index pip can sit at a fixed spot
    desc_start = base + int(0.035 * size)
    rows = np.nonzero(np.asarray(glyph).max(axis=1) > 0)[0]
    if rows.size and rows[-1] > desc_start + 4:
        top = glyph.crop((0, 0, glyph.width, desc_start))
        tail = glyph.crop((0, desc_start, glyph.width, rows[-1] + 1))
        tail = tail.resize((tail.width, max(1, int(tail.height * 0.42))), LANCZOS)
        g2 = Image.new("L", glyph.size, 0)
        g2.paste(top, (0, 0))
        g2.paste(tail, (0, desc_start))
        glyph = g2
    cap_top = base - int(round(RANK_CAP * SS))
    target = min(glyph.width * RANK_CONDENSE, RANK_MAX_W * SS)
    glyph = glyph.resize((int(round(target)), glyph.height), LANCZOS)
    return glyph, cap_top


def draw_index(p: Painter, rank: str, suit: str, color) -> None:
    glyph, cap_top = rank_glyph(rank)
    ox = int(round(IDX_CX * SS - glyph.width / 2))
    oy = int(round(IDX_TOP * SS - cap_top))
    p.paint_clipped(glyph, (ox, oy), color)
    p.paint_clipped(glyph.rotate(180), (W * SS - ox - glyph.width, H * SS - oy - glyph.height), color)
    pip_cy = IDX_TOP + RANK_CAP + IDX_PIP_GAP + IDX_PIP / 2
    polys = suit_polys(suit, IDX_CX, pip_cy, IDX_PIP)
    p.fill(polys, color)
    p.fill(rot180(polys), color)


PIP_LAYOUTS: dict[int, list[tuple[int, float]]] = {
    # (column 0/1/2 = left/centre/right, fraction from top row to bottom row)
    2: [(1, 0.0), (1, 1.0)],
    3: [(1, 0.0), (1, 0.5), (1, 1.0)],
    4: [(0, 0.0), (2, 0.0), (0, 1.0), (2, 1.0)],
    5: [(0, 0.0), (2, 0.0), (1, 0.5), (0, 1.0), (2, 1.0)],
    6: [(0, 0.0), (2, 0.0), (0, 0.5), (2, 0.5), (0, 1.0), (2, 1.0)],
    7: [(0, 0.0), (2, 0.0), (1, 0.25), (0, 0.5), (2, 0.5), (0, 1.0), (2, 1.0)],
    8: [(0, 0.0), (2, 0.0), (1, 0.25), (0, 0.5), (2, 0.5), (1, 0.75), (0, 1.0), (2, 1.0)],
    9: [(0, 0.0), (2, 0.0), (0, 1 / 3), (2, 1 / 3), (1, 0.5), (0, 2 / 3), (2, 2 / 3), (0, 1.0), (2, 1.0)],
    10: [(0, 0.0), (2, 0.0), (1, 1 / 6), (0, 1 / 3), (2, 1 / 3), (0, 2 / 3), (2, 2 / 3), (1, 5 / 6),
         (0, 1.0), (2, 1.0)],
}


def draw_pips(p: Painter, n: int, suit: str, color) -> None:
    for col, f in PIP_LAYOUTS[n]:
        cy = FIELD_TOP + f * (FIELD_BOTTOM - FIELD_TOP)
        rot = 180.0 if f > 0.5 + 1e-6 else 0.0
        p.fill(suit_polys(suit, FIELD_COLS[col], cy, FIELD_PIP, rot), color)


def inline_band(mask: Image.Image, inset: float, width: float) -> Image.Image:
    """Antialiased band at ``inset``..``inset+width`` (final px) inside a mask."""
    d = ndimage.distance_transform_edt(np.asarray(mask) > 127).astype(np.float32)
    a, b = inset * SS, (inset + width) * SS
    band = np.clip(d - a + 0.5, 0, 1) * np.clip(b - d + 0.5, 0, 1)
    return Image.fromarray((band * 255).astype(np.uint8), "L")


def ornate_pip(p: Painter, suit: str, cx: float, cy: float, size: float, color, gold, rot=0.0) -> None:
    """Large pip with a soft lacquer sheen and an engraved double gold inline."""
    polys = suit_polys(suit, cx, cy, size, rot)
    m, o = p.poly_mask(polys, pad=12)
    hgt, wid = m.height, m.width
    yy, xx = np.mgrid[0:hgt, 0:wid].astype(np.float32)
    t = np.clip((yy / hgt) * 0.8 + (xx / wid) * 0.2, 0, 1)
    top = np.array([min(255, v * 1.16 + 14) for v in color], np.float32)
    bot = np.array([v * 0.82 for v in color], np.float32)
    grad = top[None, None, :] * (1 - t[..., None]) + bot[None, None, :] * t[..., None]
    sheen = Image.fromarray(np.clip(grad, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    p.img.paste(sheen, (o[0], o[1], o[0] + wid, o[1] + hgt), m)
    p.paint(inline_band(m, size * 0.052, 2.2), o, gold)
    p.paint(inline_band(m, size * 0.052 + 5.2, 0.9), o, gold, 0.85)


def arc_text(p: Painter, txt: str, fontname: str, cap_px: float, cx: float, cy: float, r: float,
             paint, tracking: float = 0.0, top: bool = False) -> None:
    """Letters along a circle of radius ``r`` (the baseline for bottom arcs).

    Bottom arcs read left->right with letter tops toward the centre; top arcs
    read left->right with tops pointing outward.
    """
    f = font(fontname, max(4, int(round(cap_px * SS / cap_ratio(fontname)))))
    cap = cap_px * SS
    advs = [f.getlength(ch) + tracking * SS for ch in txt]
    total = sum(advs) - tracking * SS
    rr = (r * SS - cap / 2) if not top else (r * SS + cap / 2)
    pos = -total / 2
    for ch, adv in zip(txt, advs):
        mid = pos + (adv - tracking * SS) / 2
        pos += adv
        if not top:
            theta = math.pi / 2 - mid / rr
            phi = 90.0 - math.degrees(theta)
        else:
            theta = 1.5 * math.pi + mid / rr
            phi = 270.0 - math.degrees(theta)
        size = int(f.size * 1.8)
        m = Image.new("L", (size, size), 0)
        ImageDraw.Draw(m).text((size / 2, size / 2 + cap / 2), ch, font=f, fill=255, anchor="ms")
        m = m.rotate(phi, resample=Image.Resampling.BICUBIC)
        px = cx * SS + rr * math.cos(theta)
        py = cy * SS + rr * math.sin(theta)
        p.paint_clipped(m, (int(round(px - size / 2)), int(round(py - size / 2))), paint)


def star_polys(cx, cy, r_out, r_in, points, rot=-math.pi / 2):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / points
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return [pts]


def draw_ace(p: Painter, suit: str, color) -> None:
    gold = gold_texture(W * SS, H * SS)
    cx, cy = W / 2, H / 2
    if suit != "S":
        # medallion ring with four compass lozenges
        p.ring(cx, cy, 132, 1.4, gold)
        p.ring(cx, cy, 138, 0.7, gold, 0.8)
        for i in range(4):
            a = math.pi / 2 * i
            p.fill(xform(LOZENGE, cx + 135 * math.cos(a), cy + 135 * math.sin(a), 7.5, math.degrees(a) + 90), gold)
        for i in range(4):
            a = math.pi / 4 + math.pi / 2 * i
            p.dot(cx + 135 * math.cos(a), cy + 135 * math.sin(a), 2.6, gold)
        ornate_pip(p, suit, cx, cy, 180 if suit == "D" else 176, color, gold)
        return
    # Ace of Spades: sunburst, filigree rings, maker's mark
    rays = []
    n = 64
    for i in range(n):
        a = 2 * math.pi * i / n - math.pi / 2
        long_ray = i % 2 == 0
        r0, r1 = 124, (166 if long_ray else 150)
        half = math.radians(1.1 if long_ray else 0.8)
        rays.append([(cx + r0 * math.cos(a - half * 0.35), cy + r0 * math.sin(a - half * 0.35)),
                     (cx + r1 * math.cos(a - half), cy + r1 * math.sin(a - half)),
                     (cx + (r1 + 3) * math.cos(a), cy + (r1 + 3) * math.sin(a)),
                     (cx + r1 * math.cos(a + half), cy + r1 * math.sin(a + half)),
                     (cx + r0 * math.cos(a + half * 0.35), cy + r0 * math.sin(a + half * 0.35))])
    p.fill(rays, gold, 0.9)
    p.ring(cx, cy, 120, 2.2, gold)
    p.ring(cx, cy, 113, 0.9, gold)
    p.ring(cx, cy, 176, 1.2, gold)
    for i in range(16):
        if i in (7, 8, 9):
            continue
        a = 2 * math.pi * i / 16 - math.pi / 2
        p.fill(xform(LOZENGE, cx + 176 * math.cos(a), cy + 176 * math.sin(a), 5.5, math.degrees(a) + 90), gold)
    ornate_pip(p, "S", cx, cy + 6, 190, color, gold)
    arc_text(p, "SHADOWFETCH", SANS_SEMI, 11.5, cx, cy, 196, GOLD_DARK, tracking=4.2)


# =============================================================================
# court cards
# =============================================================================
def panel_poly(d: float = 0.0) -> list[Point]:
    x0, y0, x1, y1 = PANEL_BOX
    nx, ny = PANEL_NOTCH
    return [(nx + d, y0 + d), (x1 - d, y0 + d), (x1 - d, H - ny - d), (W - nx - d, H - ny - d),
            (W - nx - d, y1 - d), (x0 + d, y1 - d), (x0 + d, ny + d), (nx + d, ny + d)]


class Court:
    """Draws the top half of a court card; the caller mirrors it by rotation."""

    def __init__(self, p: Painter, suit: str, color):
        self.p = p
        self.suit = suit
        self.c = color
        self.gold = gold_texture(W * SS, H * SS)
        self.c_light = tuple(int(v + (255 - v) * 0.28) for v in color)

    # -- shared pieces -------------------------------------------------------------
    def background(self):
        p = self.p
        cx, cy = W / 2, H / 2
        wedges = []
        n = 48
        for i in range(0, n, 2):
            t0 = math.pi + math.pi * i / n
            t1 = math.pi + math.pi * (i + 1) / n
            wedges.append([(cx, cy), (cx + 520 * math.cos(t0), cy + 520 * math.sin(t0)),
                           (cx + 520 * math.cos(t1), cy + 520 * math.sin(t1))])
        p.fill(wedges, rgb("#EAD9AE"), 0.5)

    def face(self, cx, cy, rx, ry, lashes=False, lips=True):
        p = self.p
        p.ellipse(cx, cy, rx, ry, SKIN, INK, 1.8)
        ey = cy - ry * 0.06
        for sgn in (-1, 1):
            ex = cx + sgn * rx * 0.40
            lid = cubic((ex - rx * 0.20, ey), (ex - rx * 0.08, ey + ry * 0.10), (ex + rx * 0.08, ey + ry * 0.10),
                        (ex + rx * 0.20, ey), 20)
            p.stroke([lid], INK, 1.9)
            if lashes:
                for k in (0.3, 0.55, 0.8):
                    q = lid[int(k * (len(lid) - 1)) if sgn > 0 else int((1 - k) * (len(lid) - 1))]
                    p.stroke([[q, (q[0] + sgn * 2.5, q[1] + 4.0)]], INK, 1.0)
            brow = cubic((ex - rx * 0.24, ey - ry * 0.16), (ex - rx * 0.08, ey - ry * 0.27),
                         (ex + rx * 0.10, ey - ry * 0.27), (ex + rx * 0.24, ey - ry * 0.18), 20)
            p.stroke([brow], INK, 1.5)
        nose = [(cx + rx * 0.02, ey - ry * 0.10), (cx + rx * 0.05, cy + ry * 0.22), (cx - rx * 0.10, cy + ry * 0.27)]
        p.stroke([catmull(nose, closed=False, n=10)], INK, 1.4)
        if lips:
            my = cy + ry * 0.50
            mouth = [(cx - rx * 0.22, my), (cx - rx * 0.08, my - ry * 0.08), (cx, my - ry * 0.04),
                     (cx + rx * 0.08, my - ry * 0.08), (cx + rx * 0.22, my),
                     (cx + rx * 0.08, my + ry * 0.09), (cx - rx * 0.08, my + ry * 0.09)]
            p.fill([catmull(mouth, n=8)], self.c if self.c != INK else rgb("#8E2A2A"))
            p.stroke([[(cx - rx * 0.20, my), (cx + rx * 0.20, my)]], INK, 0.9)

    def pip(self, cx, cy, size, rot=0.0):
        self.p.fill(suit_polys(self.suit, cx, cy, size, rot), self.c)

    def jewel(self, cx, cy, r):
        p = self.p
        p.dot(cx, cy, r + 1.8, self.gold)
        p.dot(cx, cy, r, self.c)
        p.dot(cx - r * 0.35, cy - r * 0.35, r * 0.32, SKIN, 0.85)

    def torso(self, shoulder_half, waist_half, shoulder_y, neck_half, neck_y):
        """Tapered shoulders/torso reaching just past the split line."""
        cx = W / 2
        sh = shoulder_half
        pts = chain((cx - waist_half, 356), [
            ((cx - waist_half - 3, 334), (cx - sh, 316), (cx - sh, shoulder_y + 16)),
            ((cx - sh, shoulder_y - 2), (cx - sh + 18, shoulder_y - 12), (cx - sh + 44, shoulder_y - 14)),
            ((cx - neck_half - 26, neck_y + 3), (cx - neck_half - 8, neck_y), (cx - neck_half, neck_y)),
        ], 30)
        return [pts + [(cx, neck_y)] + [(2 * cx - x, y) for x, y in reversed(pts)]]

    def clipped(self, clip_polys, polys, paint, alpha=1.0, stroke_w=0.0):
        """Fill (or stroke) ``polys`` but only inside ``clip_polys``."""
        m1, (x0, y0) = self.p.poly_mask(clip_polys)
        m2 = Image.new("L", m1.size, 0)
        d = ImageDraw.Draw(m2)
        for poly in polys:
            pts = [(x * SS - x0, y * SS - y0) for x, y in poly]
            if stroke_w > 0:
                d.line(pts, fill=255, width=max(1, int(round(stroke_w * SS))), joint="curve")
            elif len(pts) >= 3:
                d.polygon(pts, fill=255)
        self.p.paint(ImageChops.multiply(m1, m2), (x0, y0), paint, alpha)

    def brocade(self, clip_polys, step=17.0, size=3.6, alpha=0.9):
        """Small gold lozenges on a half-drop grid, clipped to a garment."""
        polys = []
        row = 0
        y = 250.0
        while y < 362:
            off = step / 2 if row % 2 else 0.0
            x = W / 2 - 8 * step + off
            while x < W / 2 + 8 * step:
                polys += xform(LOZENGE, x, y, size)
                x += step
            y += step * 0.62
            row += 1
        self.clipped(clip_polys, polys, self.gold, alpha)

    def hand(self, cx, cy, grip_left=True):
        """Stylised closed hand gripping a vertical pole at ``cx``."""
        p = self.p
        s = -1 if grip_left else 1
        fist = [(cx - 11, cy - 9), (cx + 11, cy - 9), (cx + 12, cy + 9), (cx - 12, cy + 9)]
        p.shape([catmull(fist, n=6)], SKIN, INK, 1.3)
        for k in (-4.5, 0.0, 4.5):
            p.stroke([[(cx - 9, cy + k), (cx + 9, cy + k)]], INK, 0.9)
        p.shape([catmull([(cx + s * 11, cy - 8), (cx + s * 17, cy - 3), (cx + s * 12, cy + 4)], n=6)], SKIN, INK, 1.1)

    def cuff(self, x0, x1, y0, y1):
        self.p.shape([[(x0, y0), (x1, y0), (x1, y1), (x0, y1)]], self.gold, GOLD_DARK, 1.0)

    def ermine_collar(self, cx, cy, rx, ry, thick):
        p = self.p
        outer = arc_pts(cx, cy, rx + thick, math.radians(8), math.radians(172), 60)
        inner = arc_pts(cx, cy, rx, math.radians(172), math.radians(8), 60)
        p.shape([[(x, cy + (y - cy) * ry / rx) for x, y in outer + inner]], SKIN, self.gold, 1.6)
        for i in range(7):
            t = math.radians(20 + i * 140 / 6)
            x = cx + (rx + thick * 0.5) * math.cos(t)
            y = cy + (rx + thick * 0.5) * math.sin(t) * ry / rx
            p.fill(ermine_spot(x, y, 9), INK)

    # -- the three designs ---------------------------------------------------------
    def king(self):
        p, c, g = self.p, self.c, self.gold
        cx = W / 2
        self.background()
        # sceptre topped by a star
        sx = 372
        p.shape([[(sx - 3.5, 356), (sx - 3.5, 124), (sx + 3.5, 124), (sx + 3.5, 356)]], g, GOLD_DARK, 1.2)
        for yy in (150, 214):
            p.shape([[(sx - 7, yy - 4), (sx + 7, yy - 4), (sx + 7, yy + 4), (sx - 7, yy + 4)]], g, GOLD_DARK, 1.0)
        p.shape(star_polys(sx, 104, 29, 9, 8), g, GOLD_DARK, 1.0)
        p.fill(star_polys(sx, 104, 16, 6, 8, rot=-math.pi / 2 + math.pi / 8), g)
        self.jewel(sx, 104, 6.5)
        # mantle with brocade, ermine lapels and a jewelled tunic
        robe = self.torso(124, 100, 282, 30, 256)
        p.fill(robe, c)
        self.brocade(robe)
        p.stroke(robe, g, 2.4, closed=True)
        tunic = [[(cx - 34, 262), (cx + 34, 262), (cx + 40, 356), (cx - 40, 356)]]
        p.shape(tunic, g, GOLD_DARK, 1.2)
        chev = []
        y = 276
        while y < 352:
            chev.append([(cx - 30, y), (cx, y + 16), (cx + 30, y)])
            y += 16
        self.clipped(tunic, chev, c, stroke_w=3.4)
        for sgn in (-1, 1):
            lapel = [[(cx + sgn * 34, 262), (cx + sgn * 52, 262), (cx + sgn * 60, 356), (cx + sgn * 40, 356)]]
            p.shape(lapel, SKIN, g, 1.3)
            for yy in (284, 314, 344):
                p.fill(ermine_spot(cx + sgn * 47.5 + (yy - 262) * 0.09 * sgn, yy, 8), INK)
        # chain of office
        for i in range(-7, 8):
            t = i / 7
            p.dot(cx + t * 98, 300 - 26 * (1 - t * t), 3.2, g)
        self.pip(cx, 322, 24)
        # hand on the sceptre, emerging from the mantle
        self.cuff(344, 358, 307, 329)
        self.hand(sx, 318)
        self.ermine_collar(cx, 248, 42, 22, 18)
        # hair (side locks)
        for sgn in (-1, 1):
            lock = [(cx + sgn * 34, 146), (cx + sgn * 50, 150), (cx + sgn * 52, 214), (cx + sgn * 44, 232),
                    (cx + sgn * 34, 226)]
            p.fill([catmull(lock, n=8)], INK)
            for k in range(3):
                off = 38 + k * 4.5
                p.stroke([[(cx + sgn * off, 158), (cx + sgn * (off + 1), 222 - k * 3)]], g, 1.0, alpha=0.8)
        self.face(cx, 190, 38, 48, lips=False)
        # beard + moustache
        beard = [(cx - 36, 204), (cx - 30, 236), (cx - 14, 262), (cx, 282), (cx + 14, 262), (cx + 30, 236),
                 (cx + 36, 204), (cx + 20, 222), (cx, 226), (cx - 20, 222)]
        p.fill([catmull(beard, n=8)], INK)
        for k in (-2, -1, 0, 1, 2):
            p.stroke([[(cx + k * 7, 230), (cx + k * 4.2, 268 - abs(k) * 8)]], g, 1.1, alpha=0.85)
        mous = chain((cx, 216), [((cx - 8, 211), (cx - 20, 210), (cx - 28, 219)),
                                 ((cx - 22, 214), (cx - 10, 218), (cx, 222)),
                                 ((cx + 10, 218), (cx + 22, 214), (cx + 28, 219)),
                                 ((cx + 20, 210), (cx + 8, 211), (cx, 216))], 16)
        p.fill([mous], INK)
        # crown
        cap = chain((cx - 48, 146), [((cx - 50, 112), (cx - 20, 102), (cx, 102)),
                                     ((cx + 20, 102), (cx + 50, 112), (cx + 48, 146))], 30)
        p.shape([cap], c, g, 1.4)
        tips = [(-50, 108), (-25, 96), (0, 78), (25, 96), (50, 108)]
        spikes = []
        for i, (tx, ty) in enumerate(tips):
            half = 11 if i != 2 else 13
            spikes.append([(cx + tx - half, 134), (cx + tx, ty), (cx + tx + half, 134)])
        p.shape(spikes, g, GOLD_DARK, 1.2)
        for i, (tx, ty) in enumerate(tips):
            if i == 2:
                self.pip(cx, ty - 12, 20)
            else:
                p.shape([circle_pts(cx + tx, ty - 3, 5, 24)], g, GOLD_DARK, 1.0)
        p.shape([[(cx - 60, 132), (cx + 60, 132), (cx + 58, 152), (cx - 58, 152)]], g, GOLD_DARK, 1.4)
        for k in (-40, -20, 0, 20, 40):
            if k == 0:
                self.jewel(cx, 142, 5.5)
            else:
                p.fill(xform(LOZENGE, cx + k, 142, 6), c)

    def queen(self):
        p, c, g = self.p, self.c, self.gold
        cx = W / 2
        self.background()
        # pleated fan halo behind the head
        fcx, fcy, fr = cx, 250, 106
        n = 12
        a0, a1 = math.pi * 1.145, math.pi * 1.855
        for i in range(n):
            t0 = a0 + (a1 - a0) * i / n
            t1 = a0 + (a1 - a0) * (i + 1) / n
            tm = (t0 + t1) / 2
            wedge = [(fcx, fcy), (fcx + fr * math.cos(t0), fcy + fr * math.sin(t0)),
                     (fcx + (fr + 12) * math.cos(tm), fcy + (fr + 12) * math.sin(tm)),
                     (fcx + fr * math.cos(t1), fcy + fr * math.sin(t1))]
            p.shape([wedge], c if i % 2 == 0 else self.c_light, g, 1.6)
        p.fill([arc_pts(fcx, fcy, 58, math.pi, 2 * math.pi, 40) + [(fcx, fcy)]], g)
        for i in range(n + 1):
            t = a0 + (a1 - a0) * i / n
            p.dot(fcx + (fr - 11) * math.cos(t), fcy + (fr - 11) * math.sin(t), 2.4, g)
        # gown: bodice with gold pinstripes, lace yoke and laced stomacher
        gown = self.torso(104, 84, 290, 22, 262)
        p.fill(gown, c)
        stripes = []
        for k in range(-7, 8):
            x = cx + k * 13
            stripes.append([(x, 250), (x + k * 0.9, 360)])
        self.clipped(gown, stripes, g, 0.85, stroke_w=1.3)
        p.stroke(gown, g, 2.4, closed=True)
        stomacher = [[(cx - 26, 292), (cx + 26, 292), (cx + 14, 356), (cx - 14, 356)]]
        p.shape(stomacher, g, GOLD_DARK, 1.2)
        lace = []
        for yy in range(300, 356, 10):
            lace.append([(cx - 16, yy), (cx + 16, yy + 8)])
            lace.append([(cx + 16, yy), (cx - 16, yy + 8)])
        self.clipped(stomacher, lace, c, stroke_w=2.0)
        yoke = chain((cx - 56, 280), [((cx - 44, 306), (cx - 20, 312), (cx, 312)),
                                      ((cx + 20, 312), (cx + 44, 306), (cx + 56, 280))], 20)
        p.shape([[(cx - 22, 262)] + yoke + [(cx + 22, 262)]], SKIN, g, 1.6)
        scal = []
        for i in range(8):
            t = -1 + (i + 0.5) * 2 / 8
            x = cx + t * 48
            y = 296 + 12 * (1 - t * t)
            scal.append(arc_pts(x, y, 5.2, 0, math.pi, 10))
        p.stroke(scal, c, 1.3)
        for i in range(-5, 6):
            t = i / 5
            p.dot(cx + t * 36, 266 + 18 * (1 - t * t), 3.0, g)
        self.jewel(cx, 290, 6)
        # rose held in the left hand
        rx, ry = 104, 282
        p.stroke([cubic((rx + 6, ry + 20), (rx + 12, ry + 34), (rx + 22, ry + 40), (rx + 34, ry + 42), 20)], g, 3.0)
        for sgn, (lx, ly) in ((-1, (rx - 6, ry + 26)), (1, (rx + 16, ry + 30))):
            leaf = [(lx, ly), (lx + sgn * 14, ly - 8), (lx + sgn * 24, ly), (lx + sgn * 12, ly + 8)]
            p.shape([catmull(leaf, n=8)], g, GOLD_DARK, 1.0)
        p.shape([circle_pts(rx, ry, 22, 60)], c, g, 1.8)
        for k, rr in enumerate((16, 10.5, 5)):
            a = math.radians(200 - k * 40)
            p.stroke([arc_pts(rx + (k % 2) * 1.5, ry - k, rr, a, a + math.radians(290), 40)], g, 1.6)
        self.cuff(148, 160, 314, 336)
        self.hand(136, 325, grip_left=False)
        # neck, hair, face
        p.shape([[(cx - 14, 228), (cx + 14, 228), (cx + 16, 268), (cx - 16, 268)]], SKIN, INK, 1.4)
        hair = [(cx, 132), (cx + 44, 146), (cx + 56, 186), (cx + 54, 226), (cx + 44, 244), (cx + 30, 232),
                (cx - 30, 232), (cx - 44, 244), (cx - 54, 226), (cx - 56, 186), (cx - 44, 146)]
        p.fill([catmull(hair, n=10)], INK)
        self.face(cx, 196, 34, 44, lashes=True)
        fringe = [(cx - 38, 176), (cx - 36, 150), (cx - 20, 138), (cx, 134), (cx + 20, 138), (cx + 36, 150),
                  (cx + 38, 176), (cx + 20, 168), (cx, 170), (cx - 20, 168)]
        p.fill([catmull(fringe, n=8)], INK)
        for sgn in (-1, 1):
            for k in range(3):
                off = 42 + k * 4
                p.stroke([catmull([(cx + sgn * (off - 8), 150), (cx + sgn * (off + 2), 190),
                                   (cx + sgn * (off - 2), 232)], closed=False, n=10)], g, 1.0, alpha=0.8)
        for sgn in (-1, 1):
            ex = cx + sgn * 40
            p.dot(ex, 222, 3.2, g)
            p.shape([catmull([(ex, 226), (ex + 4.5, 236), (ex, 242), (ex - 4.5, 236)], n=6)], c, g, 1.0)
        # tiara
        outer = chain((cx - 42, 142), [((cx - 30, 126), (cx + 30, 126), (cx + 42, 142))], 30)
        inner = chain((cx - 36, 134), [((cx - 26, 118), (cx + 26, 118), (cx + 36, 134))], 30)
        p.shape([outer + list(reversed(inner))], g, GOLD_DARK, 1.0)
        spikes = [[(cx - 24, 126), (cx - 18, 108), (cx - 12, 124)], [(cx + 12, 124), (cx + 18, 108), (cx + 24, 126)],
                  [(cx - 9, 123), (cx, 88), (cx + 9, 123)]]
        p.shape(spikes, g, GOLD_DARK, 1.0)
        p.shape([catmull([(cx, 96), (cx + 8, 110), (cx, 122), (cx - 8, 110)], n=6)], c, g, 1.2)
        for sgn in (-1, 1):
            p.dot(cx + sgn * 18, 106, 3.0, g)

    def jack(self):
        p, c, g = self.p, self.c, self.gold
        cx = W / 2
        self.background()
        # halberd on the right
        hx, hy = 376, 16
        p.fill([[(hx - 3, 356), (hx - 3, 92 + hy), (hx + 3, 92 + hy), (hx + 3, 356)]], INK)
        for yy in (184, 254):
            p.shape([[(hx - 6, yy - 3), (hx + 6, yy - 3), (hx + 6, yy + 3), (hx - 6, yy + 3)]], g, GOLD_DARK, 1.0)
        p.shape([[(hx - 6, 96 + hy), (hx, 54 + hy), (hx + 6, 96 + hy)]], g, GOLD_DARK, 1.2)
        blade = chain((hx + 3, 100 + hy), [((hx + 22, 96 + hy), (hx + 38, 88 + hy), (hx + 44, 78 + hy)),
                                           ((hx + 48, 100 + hy), (hx + 48, 130 + hy), (hx + 42, 150 + hy)),
                                           ((hx + 34, 138 + hy), (hx + 20, 134 + hy), (hx + 3, 136 + hy))], 20)
        p.shape([blade], g, GOLD_DARK, 1.4)
        p.stroke([cubic((hx + 10, 104 + hy), (hx + 24, 102 + hy), (hx + 36, 96 + hy), (hx + 40, 90 + hy), 16)],
                 GOLD_DARK, 1.0)
        p.shape([[(hx - 3, 108 + hy), (hx - 22, 118 + hy), (hx - 3, 126 + hy)]], g, GOLD_DARK, 1.0)
        # doublet: paned stripes and a diagonal sash
        tunic = self.torso(114, 92, 288, 24, 258)
        p.fill(tunic, c)
        panes = []
        for k in range(-6, 7, 2):
            x = cx + k * 14
            panes.append([(x - 6, 250), (x + 6, 250), (x + 6 + k * 0.6, 360), (x - 6 + k * 0.6, 360)])
        self.clipped(tunic, panes, self.c_light, 1.0)
        seams = []
        for k in range(-7, 8, 2):
            x = cx + k * 14
            seams.append([(x, 250), (x + k * 0.6, 360)])
        self.clipped(tunic, seams, g, 0.9, stroke_w=1.4)
        sash = [(cx - 112, 300), (cx - 98, 284), (cx + 104, 346), (cx + 96, 364)]
        self.clipped(tunic, [sash], g, 1.0)
        self.clipped(tunic, [[(cx - 104, 296), (cx + 100, 356)]], GOLD_DARK, 1.0, stroke_w=1.0)
        p.stroke(tunic, g, 2.4, closed=True)
        self.jewel(cx - 40, 306, 5.5)
        self.cuff(342, 358, 303, 325)
        self.hand(hx, 314)
        # zig-zag ruff collar
        ruff = []
        n = 16
        for i in range(n + 1):
            t = math.pi * (0.06 + 0.88 * i / n)
            r = 58 if i % 2 == 0 else 44
            ruff.append((cx + r * math.cos(t), 250 + r * 0.45 * math.sin(t)))
        inner = [(x, 250 + (y - 250) * 0.45) for x, y in arc_pts(cx, 250, 30, math.pi * 0.94, math.pi * 0.06, 30)]
        p.shape([ruff + inner], SKIN, g, 1.6)
        p.shape([[(cx - 13, 226), (cx + 13, 226), (cx + 14, 256), (cx - 14, 256)]], SKIN, INK, 1.4)
        hair = [(cx, 140), (cx + 40, 150), (cx + 48, 184), (cx + 46, 222), (cx + 34, 226), (cx - 34, 226),
                (cx - 46, 222), (cx - 48, 184), (cx - 40, 150)]
        p.fill([catmull(hair, n=10)], INK)
        for sgn in (-1, 1):
            for k in range(3):
                off = 38 + k * 3.5
                p.stroke([[(cx + sgn * off, 170), (cx + sgn * (off + 1), 220)]], g, 1.0, alpha=0.8)
        self.face(cx, 196, 34, 44)
        # cap: tilted beret with jewelled band
        capx, capy = cx + 4, 146
        p.shape([ellipse_pts(capx, capy - 12, 50, 26, 120, math.radians(-7))], c, g, 1.6)
        p.shape([ellipse_pts(capx, capy + 4, 56, 12, 120, math.radians(-7))], g, GOLD_DARK, 1.2)
        for k in (-36, -18, 0, 18, 36):
            p.dot(capx + k, capy + 4 - k * math.tan(math.radians(7)), 2.4, c)
        # feather plume sweeping up-left
        spine = catmull([(cx - 26, 136), (cx - 52, 110), (cx - 64, 76), (cx - 58, 52), (cx - 40, 40)],
                        closed=False, n=12)
        left_edge, right_edge = [], []
        for i, (x, y) in enumerate(spine):
            t = i / (len(spine) - 1)
            j, k = min(i + 1, len(spine) - 1), max(i - 1, 0)
            dx, dy = spine[j][0] - spine[k][0], spine[j][1] - spine[k][1]
            ln = math.hypot(dx, dy) or 1
            nx, ny = -dy / ln, dx / ln
            wdt = 15 * math.sin(math.pi * min(1.0, t * 1.1 + 0.05)) + 2
            left_edge.append((x + nx * wdt, y + ny * wdt))
            right_edge.append((x - nx * wdt * 0.8, y - ny * wdt * 0.8))
        p.shape([left_edge + list(reversed(right_edge))], SKIN, g, 1.6)
        barbs = []
        for i in range(2, len(spine) - 2, 3):
            x, y = spine[i]
            for ex, ey in (left_edge[i], right_edge[i]):
                barbs.append([(x, y), (ex + (x - ex) * 0.15, ey + 5)])
        p.stroke(barbs, c, 1.2)
        p.stroke([spine], GOLD_DARK, 1.6)
        self.jewel(cx - 26, 138, 6)


def ermine_spot(x, y, size):
    return xform([[(0, -0.5), (0.28, 0.1), (0.1, 0.5), (0, 0.3), (-0.1, 0.5), (-0.28, 0.1)]], x, y, size)


def draw_court(p: Painter, rank: str, suit: str, color) -> None:
    gold = gold_texture(W * SS, H * SS)
    panel = panel_poly(0)
    p.fill([panel], PANEL)
    snapshot = p.img.copy()        # symmetric background (frame, ornaments, panel)
    court = Court(p, suit, color)
    {"K": court.king, "Q": court.queen, "J": court.jack}[rank]()
    art = p.img
    # keep the panel interior of the top half, then add its 180-degree copy
    clip = Image.new("L", art.size, 0)
    ImageDraw.Draw(clip).polygon([(x * SS, y * SS) for x, y in panel_poly(3.0)], fill=255)
    top = Image.new("L", art.size, 0)
    ImageDraw.Draw(top).rectangle((0, 0, art.width, H * SS // 2 - 1), fill=255)
    top_clip = ImageChops.multiply(clip, top)
    result = snapshot
    result.paste(art, (0, 0), top_clip)
    result.paste(art.transpose(Image.Transpose.ROTATE_180), (0, 0), top_clip.transpose(Image.Transpose.ROTATE_180))
    p.img.paste(result, (0, 0))
    # split rule and panel frame
    y = H / 2
    x0, _, x1, _ = PANEL_BOX
    p.stroke([[(x0 + 4, y), (x1 - 4, y)]], gold, 2.4)
    p.fill(xform(LOZENGE, W / 2, y, 9), gold)
    p.fill(xform(LOZENGE, W / 2, y, 4.5), color)
    p.stroke([panel_poly(0)], gold, 3.0, closed=True)
    p.stroke([panel_poly(6.5)], gold, 1.1, closed=True)
    cp = suit_polys(suit, PANEL_BOX[2] - 30, PANEL_BOX[1] + 32, 34)
    p.fill(cp, color)
    p.fill(rot180(cp), color)


# =============================================================================
# faces & backs
# =============================================================================
def make_face(rank: str, suit: str, color) -> Image.Image:
    img, p = new_canvas()
    draw_frame(p)
    if rank in ("J", "Q", "K"):
        draw_court(p, rank, suit, color)
    else:
        draw_corner_ornaments(p)
        if rank == "A":
            draw_ace(p, suit, color)
        else:
            draw_pips(p, int(rank), suit, color)
    draw_index(p, rank, suit, color)
    return img


def make_back(field) -> Image.Image:
    img, p = new_canvas()
    gold = gold_texture(W * SS, H * SS)
    wS, hS = W * SS, H * SS
    border = 18
    cx, cy = W / 2, H / 2
    yy, xx = np.mgrid[0:hS, 0:wS].astype(np.float32)
    X = xx / SS - cx
    Y = yy / SS - cy
    # field colour with a soft pool of light in the middle
    rr = np.sqrt((X / (W / 2)) ** 2 * 0.9 + (Y / (H / 2)) ** 2 * 0.7)
    light = np.clip(1.18 - 0.38 * rr, 0.72, 1.2)
    base = np.array(field, np.float32) + (12.0 if sum(field) < 60 else 0.0)
    fld = np.clip(base[None, None, :] * light[..., None], 0, 255).astype(np.uint8)
    fmask = Image.new("L", (wS, hS), 0)
    ImageDraw.Draw(fmask).rounded_rectangle((border * SS, border * SS, wS - border * SS - 1, hS - border * SS - 1),
                                            radius=46 * SS, fill=255)
    img.paste(Image.fromarray(fld, "RGB").convert("RGBA"), (0, 0), fmask)

    # art-deco repeat: diamond lattice + nested lozenges + node dots
    cw, ch = 50.0, 70.0
    k = 1.0 / math.hypot(1 / cw, 1 / ch)          # px per lattice unit (perpendicular)
    u = X / cw + Y / ch
    v = X / cw - Y / ch
    d_line = np.minimum(np.abs(u - np.round(u)), np.abs(v - np.round(v))) * k * SS
    lines = np.clip(0.7 * SS - d_line + 0.5, 0, 1)
    lz = np.maximum(np.abs(u - np.floor(u) - 0.5), np.abs(v - np.floor(v) - 0.5))
    lozenge = np.clip(0.5 * SS - np.abs(lz - 0.25) * k * SS + 0.5, 0, 1)
    dot = np.clip((0.085 - lz) * k * SS + 0.5, 0, 1)
    pattern = np.maximum(lines, np.maximum(lozenge * 0.85, dot))
    dist_c = np.sqrt(X * X + Y * Y)
    fade = np.clip((dist_c - 134) / 26.0, 0, 1)
    inner = np.zeros((hS, wS), np.float32)
    ib = 44 * SS
    inner[ib:hS - ib, ib:wS - ib] = 1
    pm = Image.fromarray((pattern * fade * inner * 0.62 * 255).astype(np.uint8), "L")
    p.paint(pm, (0, 0), gold)

    # frames with stepped corners
    def stepped(d, s):
        x0, y0, x1, y1 = d, d, W - d, H - d
        return [(x0 + s, y0), (x1 - s, y0), (x1, y0 + s), (x1, y1 - s), (x1 - s, y1), (x0 + s, y1),
                (x0, y1 - s), (x0, y0 + s)]
    p.stroke([stepped(30, 20)], gold, 2.4, closed=True)
    p.stroke([stepped(38, 16)], gold, 1.0, closed=True)
    for fx, fy, a0 in ((46, 46, 0.0), (W - 46, 46, 90.0), (W - 46, H - 46, 180.0), (46, H - 46, 270.0)):
        rays = []
        for i in range(5):
            a = math.radians(a0 + 10 + i * 17.5)
            rays.append([(fx, fy), (fx + 30 * math.cos(a), fy + 30 * math.sin(a))])
        p.stroke(rays, gold, 1.1)
        p.stroke([arc_pts(fx, fy, 30, math.radians(a0 + 4), math.radians(a0 + 86), 20)], gold, 1.3)
        p.stroke([arc_pts(fx, fy, 18, math.radians(a0 + 4), math.radians(a0 + 86), 20)], gold, 1.0)

    # medallion
    dark = tuple(int(v * 0.62) for v in field) if sum(field) > 60 else (8, 8, 8)
    rays = []
    n = 72
    for i in range(n):
        a = 2 * math.pi * i / n
        r1 = 150 if i % 2 == 0 else 136
        hw = math.radians(1.45)
        rays.append([(cx + 112 * math.cos(a - hw), cy + 112 * math.sin(a - hw)),
                     (cx + r1 * math.cos(a), cy + r1 * math.sin(a)),
                     (cx + 112 * math.cos(a + hw), cy + 112 * math.sin(a + hw))])
    p.fill(rays, gold, 0.85)
    p.fill([circle_pts(cx, cy, 108, 240)], dark)
    p.ring(cx, cy, 108, 3.0, gold)
    p.ring(cx, cy, 99, 1.0, gold)
    for i in range(36):
        a = 2 * math.pi * i / 36
        p.dot(cx + 91 * math.cos(a), cy + 91 * math.sin(a), 1.6, gold)
    size = int(round(112 * SS / cap_ratio(SERIF_BOLD)))
    m = Image.new("L", (int(size * 1.4), int(size * 1.6)), 0)
    ImageDraw.Draw(m).text((m.width // 2, m.height // 2), "S", font=font(SERIF_BOLD, size), fill=255, anchor="mm")
    m = m.crop(m.getbbox())
    p.paint(m, (int(round(cx * SS - m.width / 2)), int(round(cy * SS - m.height / 2))), gold)
    sp = suit_polys("S", cx, cy - 76, 18)
    p.fill(sp, gold)
    p.fill(rot180(sp), gold)
    for sgn in (-1, 1):
        p.fill(xform(LOZENGE, cx + sgn * 76, cy, 6), gold)
    return img


# =============================================================================
# driver
# =============================================================================
def render(kind: str, *args) -> Image.Image:
    if kind == "face":
        deck, rank, suit = args
        return finish(make_face(rank, suit, DECKS[deck][suit]), f"{deck}/{rank}{suit}")
    (name,) = args
    return finish(make_back(BACKS[name]), f"backs/{name}", grain=0.8)


def _job(job) -> str:
    kind, *args = job
    rel = f"{args[0]}/{args[1]}{args[2]}.png" if kind == "face" else f"backs/{args[0]}.png"
    save(render(kind, *args), CARDS_DIR / rel)
    return rel


def remove_legacy() -> int:
    removed = 0
    for path in sorted(CARDS_DIR.glob("*.png")) + sorted(CARDS_DIR.glob("*.png.import")):
        if path.is_file():
            path.unlink()
            removed += 1
    return removed


def main() -> None:
    jobs = [("face", deck, rank, suit) for deck in DECKS for suit in SUITS for rank in RANKS]
    jobs += [("back", name) for name in BACKS]
    with Pool() as pool:
        done = pool.map(_job, jobs, chunksize=2)
    removed = remove_legacy()
    print(f"Wrote {len(done)} textures to {CARDS_DIR} (removed {removed} legacy files)")


if __name__ == "__main__":
    main()
