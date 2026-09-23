#!/usr/bin/env python3
"""Generate the original Shadowfetch Blackjack casino-chip textures.

All artwork is procedural (polar-coordinate shapes rendered with
supersampling) plus the bundled OFL fonts in ``assets/fonts``.

For every denomination (value in cents -> label)::

    100 "$1"   500 "$5"   2500 "$25"   10000 "$100"   50000 "$500"   100000 "$1K"

the script writes:

* ``assets/chips/face_{cents}.png`` -- 512 x 512 RGBA top view of the chip,
  transparent outside the disc: base colour, 8 rectangular edge inserts
  centred at 22.5 + k * 45 degrees (screen angles, measured clockwise from
  +x), a thin inner ring, a dashed ring, and an ivory inlay carrying the
  denomination plus a small arced "SHADOWFETCH" maker's mark.
* ``assets/chips/edge_{cents}.png`` -- 1024 x 48 RGB side band that tiles
  seamlessly left/right. The 8 insert stripes are centred at
  x = (k + 0.5) * 128, i.e. u = angle / 360 lines up with the face inserts
  when the band wraps once around the chip's rim.
* ``assets/ui/chip_{cents}.png`` -- 176 x 176 RGBA HUD icon: the face with a
  mild perspective, a visible rim showing the edge band, and a soft shadow.

Output is deterministic (fixed seeds). Usage from the repository root::

    python3 tools/generate_chips.py
"""
from __future__ import annotations

import math
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
CHIPS_DIR = ROOT / "assets" / "chips"
UI_DIR = ROOT / "assets" / "ui"
FONT_DIRS = [
    ROOT / "assets" / "fonts",
    Path("/usr/share/fonts/truetype/noto"),
    Path("/usr/share/fonts/opentype/inter"),
]
SERIF_BOLD = "NotoSerifDisplay-Bold.ttf"
SANS_SEMI = "Inter-SemiBold.otf"
LANCZOS = Image.Resampling.LANCZOS

FACE_SIZE = 512
EDGE_W, EDGE_H = 1024, 48
UI_SIZE = 176
INSERTS = 8
INSERT_OFFSET_DEG = 22.5          # centre angle of the first insert
INSERT_WIDTH = 0.27               # tangential width in chip radii


def rgb(hex_code: str) -> tuple[int, int, int]:
    h = hex_code.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


IVORY = rgb("#ECE8DF")
INLAY = rgb("#F7F2E6")
GOLD = rgb("#D4AF37")

CHIPS = [
    # cents, label, base, insert, denomination text colour
    (100, "$1", IVORY, rgb("#2C5AA0"), rgb("#2C5AA0")),
    (500, "$5", rgb("#B3202A"), rgb("#F2EDE2"), rgb("#B3202A")),
    (2500, "$25", rgb("#1E7A3C"), rgb("#F2EDE2"), rgb("#1E7A3C")),
    (10000, "$100", rgb("#17171A"), GOLD, rgb("#17171A")),
    (50000, "$500", rgb("#5B2A86"), rgb("#E8C547"), rgb("#5B2A86")),
    (100000, "$1K", rgb("#D0761C"), rgb("#1A120A"), rgb("#9A4B0C")),
]


@lru_cache(maxsize=None)
def font(name: str, px: int) -> ImageFont.FreeTypeFont:
    for d in FONT_DIRS:
        p = d / name
        if p.exists():
            return ImageFont.truetype(str(p), px)
    raise FileNotFoundError(f"font {name} not found in {FONT_DIRS}")


@lru_cache(maxsize=None)
def cap_ratio(name: str) -> float:
    return -font(name, 1000).getbbox("H", anchor="ls")[1] / 1000.0


def is_gold(color) -> bool:
    return tuple(color) == GOLD


def gold_field(X: np.ndarray, Y: np.ndarray) -> np.ndarray:
    """Soft metallic gold as a colour field (H x W x 3)."""
    t = X * 0.8 + Y * 0.45
    v = 0.5 + 0.42 * np.sin(t * 2.4 + 0.6) + 0.08 * np.sin(t * 9.0)
    stops = [(0.0, rgb("#8F6E1E")), (0.4, rgb("#C29C32")), (0.62, GOLD), (0.86, rgb("#EBD27E")),
             (1.0, rgb("#F7E9B6"))]
    xs = [s[0] for s in stops]
    out = np.zeros(X.shape + (3,), np.float32)
    for ch in range(3):
        out[..., ch] = np.interp(v, xs, [s[1][ch] for s in stops])
    return out


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def text_mask(n: int, txt: str, fontname: str, cap: float, cx: float, cy: float, max_w: float,
              condense_min: float = 0.86) -> np.ndarray:
    """Coverage mask (n x n, 0..1) with ``txt`` centred on (cx, cy) by its ink box."""
    size = max(6, int(round(cap / cap_ratio(fontname))))
    f = font(fontname, size)
    m = Image.new("L", (int(size * (len(txt) + 1)), int(size * 2)), 0)
    ImageDraw.Draw(m).text((size // 2, int(size * 1.4)), txt, font=f, fill=255, anchor="ls")
    m = m.crop(m.getbbox())
    w, h = m.size
    if w > max_w:
        cond = max(condense_min, max_w / w)
        m = m.resize((max(1, int(w * cond)), h), LANCZOS)
        w = m.width
        if w > max_w:
            s = max_w / w
            m = m.resize((max(1, int(w * s)), max(1, int(h * s))), LANCZOS)
    out = Image.new("L", (n, n), 0)
    out.paste(m, (int(round(cx - m.width / 2)), int(round(cy - m.height / 2))))
    return np.asarray(out).astype(np.float32) / 255.0


def arc_text_mask(n: int, txt: str, fontname: str, cap: float, cx: float, cy: float, r: float,
                  tracking: float) -> np.ndarray:
    """Letters on a top arc (baseline radius ``r``), tops pointing outward."""
    size = max(6, int(round(cap / cap_ratio(fontname))))
    f = font(fontname, size)
    out = Image.new("L", (n, n), 0)
    advs = [f.getlength(ch) + tracking for ch in txt]
    total = sum(advs) - tracking
    rr = r + cap / 2
    pos = -total / 2
    for ch, adv in zip(txt, advs):
        mid = pos + (adv - tracking) / 2
        pos += adv
        theta = 1.5 * math.pi + mid / rr
        phi = 270.0 - math.degrees(theta)
        box = int(size * 2)
        m = Image.new("L", (box, box), 0)
        ImageDraw.Draw(m).text((box / 2, box / 2 + cap / 2), ch, font=f, fill=255, anchor="ms")
        m = m.rotate(phi, resample=Image.Resampling.BICUBIC)
        px = cx + rr * math.cos(theta)
        py = cy + rr * math.sin(theta)
        out.paste(m, (int(round(px - box / 2)), int(round(py - box / 2))), m)
    return np.asarray(out).astype(np.float32) / 255.0


def spade_mask(n, cx, cy, size) -> np.ndarray:
    """Small vector spade (same construction as the card pips)."""
    def cubic(p0, p1, p2, p3, k=24):
        pts = []
        for i in range(k + 1):
            t = i / k
            mt = 1 - t
            pts.append((mt ** 3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t ** 3 * p3[0],
                        mt ** 3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t ** 3 * p3[1]))
        return pts
    right = cubic((0, -0.5), (0.07, -0.34), (0.52, -0.21), (0.52, 0.04))
    right += cubic((0.52, 0.04), (0.52, 0.20), (0.42, 0.29), (0.285, 0.29))[1:]
    right += cubic((0.285, 0.29), (0.16, 0.29), (0.07, 0.23), (0.025, 0.15))[1:]
    body = right + [(-x, y) for x, y in reversed(right)][1:-1]
    stem = cubic((0.032, 0.10), (0.044, 0.30), (0.11, 0.44), (0.20, 0.50))
    stem = stem + [(-x, y) for x, y in reversed(stem)]
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    for poly in (body, stem):
        d.polygon([(cx + x * size, cy + y * size) for x, y in poly], fill=255)
    return np.asarray(m).astype(np.float32) / 255.0


def blend(img: np.ndarray, color, alpha: np.ndarray) -> None:
    """In-place: img = img * (1 - a) + color * a (color: RGB tuple or field)."""
    a = alpha[..., None]
    col = color if isinstance(color, np.ndarray) else np.array(color, np.float32)[None, None, :]
    img *= (1 - a)
    img += col * a


# =============================================================================
# chip face
# =============================================================================
def render_face(spec, size: int, small: bool = False, ss: int = 3, seed: int = 0) -> Image.Image:
    cents, label, base, insert, text_col = spec
    n = size * ss
    c = (n - 1) / 2.0
    R = n / 2.0 - 2.5 * ss
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    X = (xx - c) / R
    Y = (yy - c) / R
    r = np.sqrt(X * X + Y * Y)
    th = np.arctan2(Y, X)
    px = 1.0 / R                                   # one hi-res pixel in radius units

    def cov(d):
        return np.clip(d / px + 0.5, 0.0, 1.0)

    gold = gold_field(X, Y)
    ins_col = gold if is_gold(insert) else insert
    img = np.empty((n, n, 3), np.float32)
    img[...] = np.array(base, np.float32)

    # rectangular edge inserts
    step = 2 * math.pi / INSERTS
    off = math.radians(INSERT_OFFSET_DEG)
    dth = np.mod(th - off + step / 2, step) - step / 2
    radial = r * np.cos(dth)
    tang = r * np.sin(dth)
    spot = cov(np.minimum(INSERT_WIDTH / 2 - np.abs(tang), radial - 0.775))
    blend(img, ins_col, spot)
    # thin keyline around each insert
    side_d = np.where(radial > 0.775, np.abs(np.abs(tang) - INSERT_WIDTH / 2), 9.0)
    inner_d = np.where(np.abs(tang) < INSERT_WIDTH / 2, np.abs(radial - 0.775), 9.0)
    keyline = cov(0.006 - np.minimum(side_d, inner_d))
    dark = tuple(int(v * 0.55) for v in base) if sum(base) > 200 else tuple(int(v * 0.8) for v in insert)
    blend(img, dark if not is_gold(insert) else rgb("#7A5C18"), keyline * 0.55)

    ring_col = gold if is_gold(insert) else insert
    # inner ring
    blend(img, ring_col, cov(0.0085 - np.abs(r - 0.742)))
    # dashed ring
    dashes = 36
    f = np.mod(th / (2 * math.pi) * dashes, 1.0)
    along = (0.30 - np.abs(f - 0.5)) * (2 * math.pi * 0.665 / dashes)
    blend(img, ring_col, cov(np.minimum(0.016 - np.abs(r - 0.665), along)))
    # tiny dots between dashes
    fd = np.mod(th / (2 * math.pi) * dashes + 0.5, 1.0)
    dd = np.sqrt(((fd - 0.5) * 2 * math.pi * 0.665 / dashes) ** 2 + (r - 0.665) ** 2)
    blend(img, ring_col, cov(0.0075 - dd))

    # ivory inlay with a soft inset shadow
    inlay_r = 0.56 if small else 0.52
    inlay = cov(inlay_r - r)
    inlay_col = np.empty_like(img)
    inlay_col[...] = np.array(INLAY, np.float32)
    shade = 1.0 - 0.07 * smoothstep(0.40, inlay_r, r) - 0.05 * smoothstep(0.44, inlay_r, r) * np.clip(-(X * 0.6 + Y * 0.8) / (r + 1e-6), 0, 1)
    inlay_col *= shade[..., None]
    blend(img, inlay_col, inlay)
    blend(img, gold, cov(0.0075 - np.abs(r - inlay_r)))
    blend(img, gold, cov(0.0035 - np.abs(r - (inlay_r - 0.035))) * 0.9)

    # denomination + maker's mark
    if small:
        cap = 0.40 * R
        tm = text_mask(n, label, SERIF_BOLD, cap, c, c + 0.01 * R, 0.92 * R)
    else:
        cap = 0.30 * R
        tm = text_mask(n, label, SERIF_BOLD, cap, c, c + 0.035 * R, 0.74 * R)
        arc = arc_text_mask(n, "SHADOWFETCH", SANS_SEMI, 0.050 * R, c, c, 0.385 * R, 0.022 * R)
        blend(img, text_col, arc * 0.9)
        sp = spade_mask(n, c, c + 0.395 * R, 0.085 * R)
        blend(img, text_col, sp * 0.9)
        for sgn in (-1, 1):
            lz = np.abs(X - sgn * 0.105) / 0.022 + np.abs(Y - 0.398) / 0.030
            blend(img, gold, np.clip((1 - lz) / (px / 0.025) + 0.5, 0, 1))
    blend(img, text_col, tm)

    # clay / ceramic shading
    light = 1.0 + 0.075 * np.clip(-(X * 0.55 + Y * 0.83), -1.2, 1.2)
    bevel = 1.0 - 0.30 * smoothstep(0.955, 1.0, r)
    lip = 1.0 + 0.06 * np.exp(-((r - 0.935) / 0.016) ** 2)
    img *= (light * bevel * lip)[..., None]
    sheen = 16.0 * np.exp(-(((X + 0.38) ** 2) + ((Y + 0.46) ** 2)) / 0.30) * (r < 1.0)
    darkness = 1.0 - np.clip(np.array(base, np.float32).mean() / 255.0, 0, 1)
    img += (sheen * (0.35 + 0.65 * darkness))[..., None]

    alpha = cov(1.0 - r)
    rgba = np.dstack([np.clip(img, 0, 255), alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA").resize((size, size), LANCZOS) if ss > 1 else Image.fromarray(rgba, "RGBA")

    # fine clay grain + sparse speckles (final resolution, inside the disc)
    arr = np.asarray(out).astype(np.float32)
    rng = np.random.default_rng(1000 + cents + seed)
    g = ndimage.gaussian_filter(rng.normal(0, 1, (size, size)).astype(np.float32), 0.8)
    g *= 1.6 / (g.std() + 1e-6)
    speck = (rng.random((size, size)) < 0.0035) * rng.choice([-7.0, 6.0], (size, size))
    arr[..., :3] += (g + speck)[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


# =============================================================================
# edge band
# =============================================================================
def render_edge(spec) -> Image.Image:
    cents, label, base, insert, _ = spec
    w, h = EDGE_W, EDGE_H
    ss = 4
    xs = (np.arange(w * ss, dtype=np.float32) + 0.5) / ss       # final-px x of each hi-res column
    period = w / INSERTS
    local = np.mod(xs, period) - period / 2                     # 0 at stripe centre
    half = INSERT_WIDTH / (2 * math.pi) * w / 2
    stripe = np.clip(half - np.abs(local) + 0.5, 0, 1)
    stripe = stripe.reshape(w, ss).mean(axis=1)                 # box-filter to final res
    img = np.empty((h, w, 3), np.float32)
    img[...] = np.array(base, np.float32)
    if is_gold(insert):
        Yg = np.tile(np.linspace(-1, 1, h, dtype=np.float32)[:, None], (1, w))
        tt = 0.5 + 0.35 * np.sin(Yg * 2.2 + 0.4)                # vertical sheen, x-invariant => tiles
        ins = np.empty_like(img)
        for ch, (lo, hi) in enumerate(zip(rgb("#9C7A24"), rgb("#F0DC94"))):
            ins[..., ch] = lo + (hi - lo) * tt
        blend(img, ins, np.tile(stripe[None, :], (h, 1)))
    else:
        blend(img, insert, np.tile(stripe[None, :], (h, 1)))
    # keylines at the stripe borders
    kl = np.clip(1.0 - np.abs(np.abs(local) - half) * 1.2, 0, 1).reshape(w, ss).mean(axis=1) * 0.35
    dark = np.array([v * 0.55 for v in base], np.float32) if sum(base) > 200 else np.array(insert, np.float32) * 0.8
    blend(img, dark, np.tile(kl[None, :], (h, 1)))
    # fine ridges (256 per turn -> periodic), vertical grain, rounded profile
    rng = np.random.default_rng(7000 + cents)
    x = np.arange(w, dtype=np.float32)
    ridges = 1.0 + 0.022 * np.sin(2 * math.pi * x * 256 / w)
    col_noise = ndimage.gaussian_filter1d(rng.normal(0, 1, w).astype(np.float32), 1.2, mode="wrap")
    col_noise *= 0.018 / (col_noise.std() + 1e-6)
    fine = ndimage.gaussian_filter(rng.normal(0, 1, (h, w)).astype(np.float32), (0.6, 2.5), mode="wrap")
    fine *= 1.8 / (fine.std() + 1e-6)
    yv = (np.arange(h, dtype=np.float32) + 0.5) / h * 2 - 1
    profile = 1.0 - 0.28 * np.abs(yv) ** 3 + 0.05 * np.exp(-((yv + 0.35) / 0.25) ** 2)
    img *= (ridges + col_noise)[None, :, None]
    img *= profile[:, None, None]
    img += fine[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


# =============================================================================
# UI icon
# =============================================================================
def render_ui(spec, edge: Image.Image) -> Image.Image:
    ss = 4
    n = UI_SIZE * ss
    cx = n / 2
    rx = 75.0 * ss
    ry = rx * 0.90
    thick = 10.0 * ss
    cy = 78.0 * ss
    canvas = np.zeros((n, n, 4), np.float32)

    # soft contact shadow
    sh = Image.new("L", (n, n), 0)
    ImageDraw.Draw(sh).ellipse((cx - rx * 0.98, cy + thick + 6 * ss - ry * 0.96,
                                cx + rx * 0.98, cy + thick + 6 * ss + ry * 0.96), fill=255)
    sh = np.asarray(sh.filter(ImageFilter.GaussianBlur(6 * ss))).astype(np.float32) / 255.0 * 0.55
    canvas[..., 3] = sh * 255

    # rim (cylinder side) textured with the edge band
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) + 0.5
    nx = (xx - cx) / rx
    inside_x = np.abs(nx) < 1.0
    ey = np.sqrt(np.clip(1 - nx * nx, 0, 1)) * ry            # lower half-ellipse offset
    top_edge = cy + ey
    bot_edge = cy + ey + thick
    side = inside_x & (yy >= cy) & (yy <= bot_edge)
    theta = np.arccos(np.clip(nx, -1, 1))                      # 0 at right, pi at left (front half)
    u = (np.degrees(theta) / 360.0 * EDGE_W) % EDGE_W
    v = np.clip((yy - top_edge) / thick, 0, 0.999) * EDGE_H
    e = np.asarray(edge).astype(np.float32)
    samp = e[v.astype(int), u.astype(int)]
    lightv = 0.52 + 0.48 * np.clip(np.sin(theta), 0, 1) ** 0.8
    samp *= (lightv * 0.92)[..., None]
    cov_side = np.clip(np.minimum(bot_edge - yy, yy - (cy - 1)) + 0.5, 0, 1) * side
    # antialias the left/right silhouette
    cov_side *= np.clip((1 - np.abs(nx)) * rx + 0.5, 0, 1)
    a = cov_side[..., None]
    canvas[..., :3] = canvas[..., :3] * (1 - a) + samp * a
    canvas[..., 3] = np.maximum(canvas[..., 3], cov_side * 255)

    # face with mild foreshortening
    face = render_face(spec, int(rx * 2), small=True, ss=1, seed=17)
    face = face.resize((int(rx * 2), int(ry * 2)), LANCZOS)
    f = np.asarray(face).astype(np.float32)
    fx0 = int(round(cx - rx))
    fy0 = int(round(cy - ry))
    region = canvas[fy0:fy0 + f.shape[0], fx0:fx0 + f.shape[1]]
    fa = f[..., 3:4] / 255.0
    ra = region[..., 3:4] / 255.0
    out_a = fa + ra * (1 - fa)
    region[..., :3] = (f[..., :3] * fa + region[..., :3] * ra * (1 - fa)) / np.maximum(out_a, 1e-6)
    region[..., 3:4] = out_a * 255
    img = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8), "RGBA")
    return img.resize((UI_SIZE, UI_SIZE), LANCZOS)


def main() -> None:
    CHIPS_DIR.mkdir(parents=True, exist_ok=True)
    UI_DIR.mkdir(parents=True, exist_ok=True)
    for spec in CHIPS:
        cents = spec[0]
        face = render_face(spec, FACE_SIZE)
        face.save(CHIPS_DIR / f"face_{cents}.png", optimize=True)
        edge = render_edge(spec)
        edge.save(CHIPS_DIR / f"edge_{cents}.png", optimize=True)
        render_ui(spec, edge).save(UI_DIR / f"chip_{cents}.png", optimize=True)
        print(f"chip {cents:>6} ({spec[1]}): face, edge, ui")


if __name__ == "__main__":
    main()
