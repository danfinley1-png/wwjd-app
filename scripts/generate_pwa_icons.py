"""Generate PWA icons and social preview image from assets/images/wwjd_header.jpg."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "images" / "wwjd_header.jpg"
OUT_DIR = ROOT / "web" / "icons"
WEB_DIR = ROOT / "web"
MAROON = (0x8B, 0x1E, 0x1E)
OG_SIZE = (1200, 630)


def crop_logo_square(image: Image.Image) -> Image.Image:
    w, h = image.size
    size = min(w, h)
    # Bias crop upward so the crucifix and wings dominate the icon.
    top = max(0, (h - size) // 2 - int(size * 0.08))
    left = (w - size) // 2
    return image.crop((left, top, left + size, top + size))


def save_square(image: Image.Image, path: Path, px: int) -> None:
    image.resize((px, px), Image.Resampling.LANCZOS).save(path, optimize=True)


def save_maskable(image: Image.Image, path: Path, px: int) -> None:
    canvas = Image.new("RGB", (px, px), MAROON)
    inner = int(px * 0.72)
    scaled = image.resize((inner, inner), Image.Resampling.LANCZOS)
    offset = (px - inner) // 2
    canvas.paste(scaled, (offset, offset))
    canvas.save(path, optimize=True)


def save_og_preview(image: Image.Image, path: Path) -> None:
    """1200×630 Open Graph / link-preview image with maroon background."""
    canvas = Image.new("RGB", OG_SIZE, MAROON)
    draw = ImageDraw.Draw(canvas)

    # Logo centered above title text.
    logo_px = 340
    logo = image.resize((logo_px, logo_px), Image.Resampling.LANCZOS)
    logo_x = (OG_SIZE[0] - logo_px) // 2
    logo_y = 72
    canvas.paste(logo, (logo_x, logo_y))

    title = "WWJD-DI"
    subtitle = "What Would Jesus Do — Discernment & Inspiration"
    title_y = logo_y + logo_px + 28

    try:
        title_font = ImageFont.truetype("arialbd.ttf", 64)
        subtitle_font = ImageFont.truetype("arial.ttf", 28)
    except OSError:
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()

    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_w = title_bbox[2] - title_bbox[0]
    draw.text(
        ((OG_SIZE[0] - title_w) // 2, title_y),
        title,
        fill=(255, 255, 255),
        font=title_font,
    )

    sub_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    sub_w = sub_bbox[2] - sub_bbox[0]
    draw.text(
        ((OG_SIZE[0] - sub_w) // 2, title_y + 72),
        subtitle,
        fill=(240, 230, 210),
        font=subtitle_font,
    )

    canvas.save(path, optimize=True)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    cropped = crop_logo_square(Image.open(SRC).convert("RGB"))

    for name, px in [
        ("Icon-192.png", 192),
        ("Icon-512.png", 512),
        ("apple-touch-icon.png", 180),
    ]:
        save_square(cropped, OUT_DIR / name, px)

    for name, px in [
        ("Icon-maskable-192.png", 192),
        ("Icon-maskable-512.png", 512),
    ]:
        save_maskable(cropped, OUT_DIR / name, px)

    save_og_preview(cropped, WEB_DIR / "og-preview.png")
    save_square(cropped, WEB_DIR / "favicon.png", 48)
    print("PWA icons generated in web/icons/, og-preview.png and favicon.png in web/")


if __name__ == "__main__":
    main()
