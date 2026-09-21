#!/usr/bin/env python3
"""Generate original 52-card faces + back for Shadowfetch Blackjack."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1] / "assets" / "cards"
W, H = 220, 328
SUITS = [("S", "#16120f", "♠"), ("H", "#b01e28", "♥"), ("D", "#b01e28", "♦"), ("C", "#16120f", "♣")]
RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
PIPS = {
    2: [(0.5, 0.28), (0.5, 0.72)],
    3: [(0.5, 0.26), (0.5, 0.50), (0.5, 0.74)],
    4: [(0.32, 0.28), (0.68, 0.28), (0.32, 0.72), (0.68, 0.72)],
    5: [(0.32, 0.28), (0.68, 0.28), (0.5, 0.50), (0.32, 0.72), (0.68, 0.72)],
    6: [(0.32, 0.28), (0.68, 0.28), (0.32, 0.50), (0.68, 0.50), (0.32, 0.72), (0.68, 0.72)],
    7: [(0.32, 0.26), (0.68, 0.26), (0.5, 0.38), (0.32, 0.50), (0.68, 0.50), (0.32, 0.74), (0.68, 0.74)],
    8: [(0.32, 0.26), (0.68, 0.26), (0.5, 0.38), (0.32, 0.50), (0.68, 0.50), (0.5, 0.62), (0.32, 0.74), (0.68, 0.74)],
    9: [(0.32, 0.24), (0.68, 0.24), (0.32, 0.40), (0.68, 0.40), (0.5, 0.50), (0.32, 0.60), (0.68, 0.60), (0.32, 0.76), (0.68, 0.76)],
    10: [(0.32, 0.22), (0.68, 0.22), (0.5, 0.32), (0.32, 0.42), (0.68, 0.42), (0.32, 0.58), (0.68, 0.58), (0.5, 0.68), (0.32, 0.78), (0.68, 0.78)],
}


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def rounded(draw: ImageDraw.ImageDraw, box, r, fill) -> None:
    draw.rounded_rectangle(box, radius=r, fill=fill)


def make_face(rank: str, suit: str, color: str, pip: str) -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rounded(d, (4, 4, W - 5, H - 5), 18, (36, 28, 16, 255))
    rounded(d, (8, 8, W - 9, H - 9), 15, (248, 241, 226, 255))
    rounded(d, (14, 14, W - 15, H - 15), 12, (252, 247, 236, 255))
    d.rounded_rectangle((18, 18, W - 19, H - 19), radius=10, outline=(196, 160, 64, 255), width=2)
    rf, sf = font(28), font(22)
    d.text((22, 16), rank, font=rf, fill=color)
    d.text((24, 48), pip, font=sf, fill=color)
    tw = d.textlength(rank, font=rf)
    d.text((W - 22 - tw, H - 52), rank, font=rf, fill=color)
    d.text((W - 46, H - 80), pip, font=sf, fill=color)
    if rank == "A":
        d.text((W / 2 - 28, H / 2 - 40), pip, font=font(72), fill=color)
    elif rank in "JQK":
        d.rounded_rectangle((58, 96, W - 59, H - 97), radius=10, fill=(28, 22, 16, 255))
        d.rounded_rectangle((64, 102, W - 65, H - 103), radius=8, outline=(212, 175, 55, 255), width=3)
        d.text((W / 2 - 16, 128), rank, font=font(54), fill=(212, 175, 55, 255))
        d.text((W / 2 - 18, 190), pip, font=font(36), fill=color)
    else:
        n = 10 if rank == "10" else int(rank)
        for x, y in PIPS[n]:
            d.text((x * W - 12, y * H - 16), pip, font=font(28), fill=color)
    return img


def make_back() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rounded(d, (4, 4, W - 5, H - 5), 18, (18, 14, 10, 255))
    rounded(d, (12, 12, W - 13, H - 13), 14, (28, 20, 12, 255))
    gold = (212, 175, 55, 255)
    d.rounded_rectangle((20, 20, W - 21, H - 21), radius=12, outline=gold, width=3)
    for y in range(40, H - 40, 16):
        for x in range(40, W - 40, 16):
            if (x + y) % 32 == 0:
                d.ellipse((x, y, x + 4, y + 4), fill=(140, 110, 40, 180))
    d.text((W / 2 - 18, 118), "S", font=font(64), fill=gold)
    d.text((W / 2 - 16, 188), "♠", font=font(36), fill=gold)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    make_back().save(OUT / "back.png")
    for suit, color, pip in SUITS:
        for rank in RANKS:
            make_face(rank, suit, color, pip).save(OUT / f"{rank}{suit}.png")
    print(f"Wrote {1 + 52} cards to {OUT}")


if __name__ == "__main__":
    main()
