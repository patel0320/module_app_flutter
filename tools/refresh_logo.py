"""
Regenerate assets/images/logo.png:
- Keep the orange "soleux" wordmark untouched.
- Erase the gray "PDU Management Tool" subtitle band.
- Draw "Device Manager" in the same gray, same band, with a matching bold
  sans-serif (Arial Black on this system), same cap-height.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SRC = Path(r"E:\work\module_app_flutter\assets\images\logo.png")
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\ariblk.ttf",     # Arial Black
    r"C:\Windows\Fonts\impact.ttf",     # Impact
    r"C:\Windows\Fonts\seguisb.ttf",    # Segoe UI Semibold
]
GRAY = (73, 73, 73, 255)


def mask_subtitle(im: Image.Image) -> None:
    """Erase the gray subtitle band (rows ~70..95) by zeroing alpha on gray pixels."""
    px = im.load()
    w, h = im.size
    for y in range(max(0, 70), min(h, 96)):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 30:
                continue
            if abs(r - g) <= 4 and abs(g - b) <= 4 and r < 110:
                px[x, y] = (0, 0, 0, 0)


def fit_font(font_path: str, max_width_px: int, target_cap_px: int,
             text: str) -> ImageFont.FreeTypeFont:
    """Largest TTF size where `text` width <= max_width_px and cap ~= target."""
    lo, hi = 10, 80
    best = None
    while lo <= hi:
        mid = (lo + hi) // 2
        f = ImageFont.truetype(font_path, mid)
        bbox = f.getbbox(text)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        if tw > max_width_px:
            hi = mid - 1
        else:
            best = f
            lo = mid + 1
    return best or ImageFont.truetype(font_path, 10)


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    mask_subtitle(im)

    draw = ImageDraw.Draw(im)
    text = "Device Manager"

    # Original subtitle band: x=4..244 (width 240), cap-height ~19px.
    band_left, band_right = 4, 244
    max_w = band_right - band_left
    target_cap = 19

    chosen_font = None
    chosen_path = None
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            chosen_font = fit_font(path, max_w, target_cap, text)
            chosen_path = path
            break
    if chosen_font is None:
        raise SystemExit("No suitable bold sans-serif font found on this system.")

    bbox = draw.textbbox((0, 0), text, font=chosen_font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]

    # Center the new shorter string within the original band width while
    # anchoring the cap-line to the same y as the original (row 74).
    band_left, band_right = 4, 244
    LEFT = band_left + (band_right - band_left - tw) // 2
    TOP = 74 - bbox[1]  # bbox[1] is negative for ascenders; anchors cap row 74
    draw.text((LEFT, TOP), text, font=chosen_font, fill=GRAY)

    print(f"font:        {chosen_path}")
    print(f"font size:   {chosen_font.size}")
    print(f"text bbox:   {bbox}  tw={tw} th={th}")
    print(f"draw origin: ({LEFT}, {TOP})")

    im.save(SRC, format="PNG")
    print(f"wrote: {SRC}")


if __name__ == "__main__":
    main()
