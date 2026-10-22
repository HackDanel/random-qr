#!/usr/bin/env python3
"""Prepare photos for the Random QR app.

photos/  ->  build/<slug>.jpg  ->  rsync to server  ->  app/assets/qr_list.json

Server settings (base URL, ssh host) are read from tools/config.json
(see config.example.json); command-line flags override them.

Each photo gets a random, unguessable slug. The filename -> slug mapping is kept
in mapping.json so re-running never changes URLs of already-shared QR codes.

Optional dependencies:
  Pillow       (+ pillow-heif for .heic) - resize/convert to JPEG
  qrcode[pil]  - only for --export-png
"""

import argparse
import json
import secrets
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PHOTOS_DIR = ROOT / "photos"
BUILD_DIR = ROOT / "build"
OUT_DIR = ROOT / "out"
MAPPING_FILE = ROOT / "mapping.json"
CONFIG_FILE = ROOT / "config.json"
QR_LIST_FILE = ROOT.parent / "app" / "assets" / "qr_list.json"

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic"}
MAX_SIDE = 2000

try:
    from PIL import Image, ImageOps

    try:
        from pillow_heif import register_heif_opener

        register_heif_opener()
    except ImportError:
        pass
except ImportError:
    Image = None


def load_config() -> dict[str, str]:
    if CONFIG_FILE.exists():
        return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
    return {}


def load_mapping() -> dict[str, str]:
    if MAPPING_FILE.exists():
        return json.loads(MAPPING_FILE.read_text(encoding="utf-8"))
    return {}


def new_slug(taken: set[str]) -> str:
    while True:
        slug = secrets.token_urlsafe(6)  # 8 chars, URL-safe
        if slug not in taken:
            return slug


def build_photo(src: Path, slug: str) -> str:
    """Write the photo into BUILD_DIR, return the published file name."""
    if Image is not None:
        try:
            with Image.open(src) as img:
                img = ImageOps.exif_transpose(img).convert("RGB")
                img.thumbnail((MAX_SIDE, MAX_SIDE))
                name = f"{slug}.jpg"
                img.save(BUILD_DIR / name, "JPEG", quality=85, optimize=True)
                return name
        except Exception as e:  # e.g. HEIC without pillow-heif
            print(f"  ! {src.name}: cannot convert ({e}), copying as is", file=sys.stderr)
    name = f"{slug}{src.suffix.lower()}"
    shutil.copy2(src, BUILD_DIR / name)
    return name


def export_png(items: list[dict]) -> None:
    import qrcode

    OUT_DIR.mkdir(exist_ok=True)
    for item in items:
        qrcode.make(item["url"], box_size=20, border=4).save(OUT_DIR / f"{item['title']}.png")
    print(f"QR PNGs written to {OUT_DIR}")


def main() -> None:
    config = load_config()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base-url", default=config.get("base_url"), help="public URL of the photo folder, e.g. https://photos.example.com/p")
    parser.add_argument("--host", default=config.get("host"), help="ssh target for rsync, e.g. user@server (omit to skip upload)")
    parser.add_argument("--no-upload", action="store_true", help="skip rsync even if host is configured")
    parser.add_argument("--remote-dir", default=config.get("remote_dir", "/var/www/photos/p"), help="photo folder on the server")
    parser.add_argument("--export-png", action="store_true", help="also render QR PNGs into tools/out/ for printing")
    args = parser.parse_args()
    if not args.base_url:
        parser.error(f"--base-url is required (or set base_url in {CONFIG_FILE.name})")

    if Image is None:
        print("Pillow not installed: photos are uploaded without resizing", file=sys.stderr)

    photos = sorted(p for p in PHOTOS_DIR.glob("*") if p.suffix.lower() in EXTENSIONS)
    if not photos:
        sys.exit(f"No photos in {PHOTOS_DIR}")

    mapping = load_mapping()
    taken = set(mapping.values())
    BUILD_DIR.mkdir(exist_ok=True)

    base_url = args.base_url.rstrip("/")
    items = []
    for src in photos:
        if src.name not in mapping:
            mapping[src.name] = new_slug(taken)
            taken.add(mapping[src.name])
        slug = mapping[src.name]
        name = build_photo(src, slug)
        items.append({"id": slug, "title": src.stem, "url": f"{base_url}/{name}"})
        print(f"  {src.name} -> {name}")

    MAPPING_FILE.write_text(json.dumps(mapping, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    QR_LIST_FILE.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(items)} items written to {QR_LIST_FILE}")

    if args.host and not args.no_upload:
        # No --delete: removing a photo locally must not break QR codes already handed out.
        subprocess.run(
            ["rsync", "-av", "--chmod=F644,D755", f"{BUILD_DIR}/", f"{args.host}:{args.remote_dir.rstrip('/')}/"],
            check=True,
        )

    if args.export_png:
        export_png(items)


if __name__ == "__main__":
    main()
