"""Turn art/raw into Shared/Assets.xcassets (resized imagesets + iOS/macOS app icons)."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "art", "raw")
CAT = os.path.join(ROOT, "Shared", "Assets.xcassets")

def write_json(path, obj):
    with open(path, "w") as f: json.dump(obj, f, indent=2)

os.makedirs(CAT, exist_ok=True)
write_json(os.path.join(CAT, "Contents.json"), {"info": {"author": "xcode", "version": 1}})

for name in sorted(os.listdir(RAW)):
    if not name.endswith(".png") or name.startswith("app_icon"): continue
    stem = name[:-4]
    d = os.path.join(CAT, f"{stem}.imageset"); os.makedirs(d, exist_ok=True)
    im = Image.open(os.path.join(RAW, name)).convert("RGBA")
    im.thumbnail((720, 720), Image.LANCZOS)
    im.save(os.path.join(d, f"{stem}.png"), optimize=True)
    write_json(os.path.join(d, "Contents.json"), {
        "images": [{"idiom": "universal", "filename": f"{stem}.png"}],
        "info": {"author": "xcode", "version": 1}})

# iOS icon: single 1024, full bleed, no alpha.
icon = Image.open(os.path.join(RAW, "app_icon.png")).convert("RGB").resize((1024, 1024), Image.LANCZOS)
ios = os.path.join(CAT, "AppIcon.appiconset"); os.makedirs(ios, exist_ok=True)
icon.save(os.path.join(ios, "icon-ios.png"))

# macOS icon: rounded-rect tile with margin and soft shadow, per Apple's grid.
def mac_tile(size=1024):
    s = 4; S = size * s
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    inset = int(S * 100 / 1024); tile = S - 2 * inset; r = int(tile * 0.225)
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([inset, inset + S // 80, inset + tile, inset + tile + S // 80], r, fill=(40, 25, 15, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S // 90))
    canvas.alpha_composite(shadow)
    art = Image.open(os.path.join(RAW, "app_icon.png")).convert("RGBA").resize((tile, tile), Image.LANCZOS)
    mask = Image.new("L", (tile, tile), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tile - 1, tile - 1], r, fill=255)
    canvas.paste(art, (inset, inset), mask)
    return canvas.resize((size, size), Image.LANCZOS)

big = mac_tile()
images = [{"idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "icon-ios.png"}]
for pt in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        px = pt * scale; fn = f"icon-mac-{px}.png"
        big.resize((px, px), Image.LANCZOS).save(os.path.join(ios, fn))
        images.append({"idiom": "mac", "size": f"{pt}x{pt}", "scale": f"{scale}x", "filename": fn})
write_json(os.path.join(ios, "Contents.json"), {"images": images, "info": {"author": "xcode", "version": 1}})

# Accent colour.
acc = os.path.join(CAT, "AccentColor.colorset"); os.makedirs(acc, exist_ok=True)
write_json(os.path.join(acc, "Contents.json"), {"colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {"red": "0.886", "green": "0.376", "blue": "0.247", "alpha": "1.000"}}}], "info": {"author": "xcode", "version": 1}})
print("ok")
