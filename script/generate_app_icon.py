#!/usr/bin/env python3
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "Sources" / "PowerMode" / "Resources" / "GPUMode.icns"
SOURCE_IMAGE = ROOT / "Sources" / "PowerMode" / "Resources" / "GPUModeSource.png"
ICONSET_NAMES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def mix(start, end, amount):
    return tuple(int(start[i] + (end[i] - start[i]) * amount) for i in range(3))


def draw_base_icon(size=1024):
    if SOURCE_IMAGE.exists():
        return draw_source_icon(size)

    return draw_vector_icon(size)


def draw_source_icon(size):
    image = Image.open(SOURCE_IMAGE).convert("RGBA")
    image = ImageOps.fit(
        image,
        (size, size),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    )
    margin = int(size * 0.045)
    radius = int(size * 0.185)
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(
        (margin, margin, size - margin, size - margin),
        radius=radius,
        fill=255,
    )
    mask = mask.filter(ImageFilter.GaussianBlur(max(1, int(size * 0.0015))))
    image.putalpha(mask)
    return image


def draw_vector_icon(size=1024):
    scale = size / 1024
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    margin = int(size * 0.055)
    radius = int(size * 0.21)
    icon_box = (margin, margin, size - margin, size - margin)
    mask_draw.rounded_rectangle(
        icon_box,
        radius=radius,
        fill=255,
    )

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow, "RGBA")
    shadow_draw.rounded_rectangle(
        (
            margin + int(8 * scale),
            margin + int(26 * scale),
            size - margin - int(8 * scale),
            size - margin + int(18 * scale),
        ),
        radius=radius,
        fill=(6, 22, 30, 72),
    )
    icon.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(int(30 * scale))))

    backdrop = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    backdrop_draw = ImageDraw.Draw(backdrop, "RGBA")
    for y in range(size):
        amount = y / (size - 1)
        if amount < 0.52:
            color = mix((244, 249, 250), (155, 187, 196), amount / 0.52)
        else:
            color = mix((155, 187, 196), (38, 82, 96), (amount - 0.52) / 0.48)
        backdrop_draw.line((0, y, size, y), fill=(*color, 255))

    color_field = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    field_draw = ImageDraw.Draw(color_field, "RGBA")
    field_draw.ellipse(
        (
            int(-170 * scale),
            int(520 * scale),
            int(730 * scale),
            int(1150 * scale),
        ),
        fill=(62, 202, 213, 74),
    )
    field_draw.ellipse(
        (
            int(390 * scale),
            int(470 * scale),
            int(1180 * scale),
            int(1110 * scale),
        ),
        fill=(34, 96, 144, 78),
    )
    field_draw.ellipse(
        (
            int(170 * scale),
            int(-180 * scale),
            int(910 * scale),
            int(430 * scale),
        ),
        fill=(255, 255, 255, 96),
    )
    field_draw.ellipse(
        (
            int(560 * scale),
            int(130 * scale),
            int(1130 * scale),
            int(700 * scale),
        ),
        fill=(185, 154, 255, 42),
    )
    field_draw.ellipse(
        (
            int(-160 * scale),
            int(160 * scale),
            int(400 * scale),
            int(720 * scale),
        ),
        fill=(255, 205, 148, 34),
    )
    field_draw.ellipse(
        (
            int(260 * scale),
            int(640 * scale),
            int(980 * scale),
            int(1130 * scale),
        ),
        fill=(94, 238, 196, 42),
    )
    backdrop.alpha_composite(color_field.filter(ImageFilter.GaussianBlur(int(92 * scale))))

    base_glass = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    base_glass.alpha_composite(backdrop)
    base_glass.putalpha(mask)
    icon.alpha_composite(base_glass)

    draw = ImageDraw.Draw(icon, "RGBA")
    draw.rounded_rectangle(
        (
            margin + int(18 * scale),
            margin + int(18 * scale),
            size - margin - int(18 * scale),
            size - margin - int(18 * scale),
        ),
        radius=radius - int(18 * scale),
        outline=(255, 255, 255, 92),
        width=max(2, int(4 * scale)),
    )
    draw.rounded_rectangle(
        icon_box,
        radius=radius,
        outline=(215, 246, 249, 164),
        width=max(3, int(6 * scale)),
    )

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_draw = ImageDraw.Draw(highlight, "RGBA")
    highlight_draw.ellipse(
        (
            int(-260 * scale),
            int(-520 * scale),
            int(1280 * scale),
            int(600 * scale),
        ),
        fill=(255, 255, 255, 74),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(int(24 * scale)))
    highlight.putalpha(Image.composite(highlight.getchannel("A"), Image.new("L", (size, size), 0), mask))
    icon.alpha_composite(highlight)

    wafer = (
        int(size * 0.245),
        int(size * 0.275),
        int(size * 0.755),
        int(size * 0.745),
    )
    wafer_radius = int(size * 0.105)

    wafer_shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    wafer_shadow_draw = ImageDraw.Draw(wafer_shadow, "RGBA")
    wafer_shadow_draw.rounded_rectangle(
        (
            wafer[0] + int(8 * scale),
            wafer[1] + int(28 * scale),
            wafer[2] + int(8 * scale),
            wafer[3] + int(28 * scale),
        ),
        radius=wafer_radius,
        fill=(4, 23, 30, 82),
    )
    icon.alpha_composite(wafer_shadow.filter(ImageFilter.GaussianBlur(int(26 * scale))))

    wafer_mask = Image.new("L", (size, size), 0)
    wafer_mask_draw = ImageDraw.Draw(wafer_mask)
    wafer_mask_draw.rounded_rectangle(wafer, radius=wafer_radius, fill=255)

    frosted = backdrop.filter(ImageFilter.GaussianBlur(int(42 * scale)))
    frosted.alpha_composite(Image.new("RGBA", (size, size), (225, 243, 247, 96)))
    prism = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    prism_draw = ImageDraw.Draw(prism, "RGBA")
    prism_draw.ellipse(
        (
            int(260 * scale),
            int(305 * scale),
            int(545 * scale),
            int(650 * scale),
        ),
        fill=(255, 236, 193, 38),
    )
    prism_draw.ellipse(
        (
            int(475 * scale),
            int(315 * scale),
            int(790 * scale),
            int(690 * scale),
        ),
        fill=(175, 150, 255, 34),
    )
    prism_draw.ellipse(
        (
            int(315 * scale),
            int(505 * scale),
            int(725 * scale),
            int(805 * scale),
        ),
        fill=(111, 232, 219, 42),
    )
    frosted.alpha_composite(prism.filter(ImageFilter.GaussianBlur(int(56 * scale))))
    frost_shade = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    frost_shade_draw = ImageDraw.Draw(frost_shade, "RGBA")
    frost_shade_draw.rectangle(
        (0, int(size * 0.58), size, size),
        fill=(10, 40, 50, 62),
    )
    frosted.alpha_composite(frost_shade.filter(ImageFilter.GaussianBlur(int(38 * scale))))
    frosted.putalpha(wafer_mask)
    icon.alpha_composite(frosted)

    draw = ImageDraw.Draw(icon, "RGBA")
    draw.rounded_rectangle(
        wafer,
        radius=wafer_radius,
        outline=(255, 255, 255, 204),
        width=max(4, int(7 * scale)),
    )
    draw.rounded_rectangle(
        (
            wafer[0] + int(12 * scale),
            wafer[1] + int(12 * scale),
            wafer[2] - int(12 * scale),
            wafer[3] - int(12 * scale),
        ),
        radius=wafer_radius - int(12 * scale),
        outline=(187, 238, 242, 92),
        width=max(2, int(3 * scale)),
    )

    grain = Image.effect_noise((size, size), 18).convert("L")
    grain_alpha = grain.point(lambda value: 7 if value > 128 else 0)
    grain_layer = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    grain_layer.putalpha(Image.composite(grain_alpha, Image.new("L", (size, size), 0), wafer_mask))
    icon.alpha_composite(grain_layer)

    bolt = [
        (574, 342),
        (417, 556),
        (515, 546),
        (466, 696),
        (632, 472),
        (535, 486),
    ]
    bolt = [(int(x * scale), int(y * scale)) for x, y in bolt]

    glyph_glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glyph_glow_draw = ImageDraw.Draw(glyph_glow, "RGBA")
    glyph_glow_draw.polygon(bolt, fill=(202, 255, 251, 48))
    icon.alpha_composite(glyph_glow.filter(ImageFilter.GaussianBlur(int(20 * scale))))

    draw = ImageDraw.Draw(icon, "RGBA")
    draw.line(
        [(x + int(5 * scale), y + int(7 * scale)) for x, y in bolt + [bolt[0]]],
        fill=(9, 42, 50, 72),
        width=max(4, int(10 * scale)),
        joint="curve",
    )
    draw.polygon(bolt, fill=(255, 255, 255, 24))
    draw.line(
        bolt + [bolt[0]],
        fill=(248, 255, 255, 188),
        width=max(4, int(8 * scale)),
        joint="curve",
    )
    draw.line(
        bolt + [bolt[0]],
        fill=(127, 235, 232, 96),
        width=max(2, int(3 * scale)),
        joint="curve",
    )
    return icon


def write_iconset(base, iconset):
    iconset.mkdir(parents=True, exist_ok=True)
    for name, pixel_size in ICONSET_NAMES.items():
        image = base.resize((pixel_size, pixel_size), Image.Resampling.LANCZOS)
        image.save(iconset / name)


def main():
    output = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_OUTPUT
    iconutil = shutil.which("iconutil")
    if iconutil is None:
        raise SystemExit("iconutil is required to create macOS .icns files.")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gpumode-icon-") as temp_dir:
        iconset = Path(temp_dir) / "GPUMode.iconset"
        write_iconset(draw_base_icon(), iconset)
        subprocess.run([iconutil, "-c", "icns", str(iconset), "-o", str(output)], check=True)


if __name__ == "__main__":
    main()
