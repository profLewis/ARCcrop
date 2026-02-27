#!/usr/bin/env python3
"""
Generate a combined WorldCereal crop type map from individual WMS layers.

Fetches tiles for maize, winter cereals, spring cereals, and temporary crops
from Terrascope WMS, combines into a single classified raster, and saves as
MBTiles (which can be converted to PMTiles via `pmtiles convert`).

Usage:
    pip install aiohttp Pillow
    python generate_worldcereal_croptype.py [--min-zoom 0] [--max-zoom 6]
    pmtiles convert worldcereal_croptype.mbtiles worldcereal_croptype.pmtiles
"""

import asyncio
import aiohttp
import io
import os
import sys
import time
import sqlite3
import argparse
from PIL import Image

# WorldCereal WMS layers on Terrascope
WMS_BASE = "https://services.terrascope.be/wms/v2"

LAYERS = [
    {
        "id": "maize",
        "wms_layer": "WORLDCEREAL_MAIZE_V1",
        "color": (255, 215, 0, 255),       # Gold yellow
        "priority": 1,
    },
    {
        "id": "winter_cereals",
        "wms_layer": "WORLDCEREAL_WINTERCEREALS_V1",
        "color": (205, 133, 63, 255),       # Brown/sienna
        "priority": 2,
    },
    {
        "id": "spring_cereals",
        "wms_layer": "WORLDCEREAL_SPRINGCEREALS_V1",
        "color": (144, 238, 144, 255),      # Light green
        "priority": 3,
    },
    {
        "id": "other_crops",
        "wms_layer": "WORLDCEREAL_TEMPORARYCROPS_V1",
        "color": (34, 139, 34, 255),        # Forest green (fallback)
        "priority": 4,
    },
]

ORIGIN_SHIFT = 20037508.3427892
TILE_SIZE = 256
ALPHA_THRESHOLD = 30  # Minimum alpha to count as "crop present"


def tile_bbox_3857(z, x, y):
    """Get EPSG:3857 BBOX string for a tile."""
    n = 2 ** z
    span = 2 * ORIGIN_SHIFT / n
    x_min = -ORIGIN_SHIFT + x * span
    x_max = -ORIGIN_SHIFT + (x + 1) * span
    y_max = ORIGIN_SHIFT - y * span
    y_min = ORIGIN_SHIFT - (y + 1) * span
    return f"{x_min},{y_min},{x_max},{y_max}"


def wms_url(layer_name, z, x, y):
    bbox = tile_bbox_3857(z, x, y)
    return (
        f"{WMS_BASE}?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap"
        f"&LAYERS={layer_name}&SRS=EPSG:3857&BBOX={bbox}"
        f"&WIDTH={TILE_SIZE}&HEIGHT={TILE_SIZE}"
        f"&FORMAT=image/png&TRANSPARENT=TRUE&STYLES="
    )


def flip_y(z, y):
    """Convert XYZ y to TMS y (MBTiles uses TMS)."""
    return (2 ** z) - 1 - y


def combine_tiles(layer_images):
    """
    Combine 4 binary crop-type tiles into a single classified tile.
    Priority: maize > winter cereals > spring cereals > other crops.
    Returns PNG bytes or None if all-transparent.
    """
    output = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    out_px = output.load()
    has_data = False

    for py in range(TILE_SIZE):
        for px in range(TILE_SIZE):
            for layer in sorted(LAYERS, key=lambda l: l["priority"]):
                img = layer_images.get(layer["id"])
                if img is None:
                    continue
                r, g, b, a = img.getpixel((px, py))
                if a > ALPHA_THRESHOLD:
                    out_px[px, py] = layer["color"]
                    has_data = True
                    break

    if not has_data:
        return None

    buf = io.BytesIO()
    output.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def init_mbtiles(path):
    """Create MBTiles database with metadata."""
    if os.path.exists(path):
        os.remove(path)
    db = sqlite3.connect(path)
    db.execute("CREATE TABLE metadata (name TEXT, value TEXT)")
    db.execute(
        "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, "
        "tile_row INTEGER, tile_data BLOB)"
    )
    db.execute(
        "CREATE UNIQUE INDEX tile_index ON tiles "
        "(zoom_level, tile_column, tile_row)"
    )
    metadata = {
        "name": "WorldCereal Crop Type 2021",
        "format": "png",
        "type": "overlay",
        "description": "Combined crop type map from ESA WorldCereal 2021 "
                       "(maize, winter cereals, spring cereals, other temporary crops)",
        "attribution": "ESA/VITO WorldCereal v100",
        "bounds": "-180,-85.051,180,85.051",
        "center": "0,0,2",
    }
    for k, v in metadata.items():
        db.execute("INSERT INTO metadata VALUES (?, ?)", (k, v))
    db.commit()
    return db


async def fetch_tile(session, url, semaphore, retries=2):
    """Fetch a single WMS tile with retries."""
    for attempt in range(retries + 1):
        async with semaphore:
            try:
                async with session.get(
                    url, timeout=aiohttp.ClientTimeout(total=30)
                ) as resp:
                    if resp.status == 200:
                        data = await resp.read()
                        if len(data) > 100:  # Skip tiny error responses
                            return data
            except (aiohttp.ClientError, asyncio.TimeoutError):
                if attempt < retries:
                    await asyncio.sleep(1)
    return None


async def process_tile(session, semaphore, z, x, y):
    """Fetch all layers for one tile and combine."""
    tasks = {}
    for layer in LAYERS:
        url = wms_url(layer["wms_layer"], z, x, y)
        tasks[layer["id"]] = fetch_tile(session, url, semaphore)

    results = await asyncio.gather(*tasks.values())
    layer_images = {}
    for lid, data in zip(tasks.keys(), results):
        if data:
            try:
                layer_images[lid] = Image.open(io.BytesIO(data)).convert("RGBA")
            except Exception:
                pass

    if not layer_images:
        return None

    return combine_tiles(layer_images)


async def generate(min_zoom, max_zoom, output_path, concurrency=8):
    """Main generation loop."""
    db = init_mbtiles(output_path)
    semaphore = asyncio.Semaphore(concurrency)
    connector = aiohttp.TCPConnector(limit=concurrency * 2)

    total_tiles = sum(4 ** z for z in range(min_zoom, max_zoom + 1))
    saved = 0
    skipped = 0
    t0 = time.time()

    async with aiohttp.ClientSession(connector=connector) as session:
        for z in range(min_zoom, max_zoom + 1):
            n = 2 ** z
            level_total = n * n
            level_done = 0
            print(f"\n--- Zoom {z}: {level_total} tiles ({level_total * 4} WMS requests) ---")

            # Process in batches to avoid memory issues
            batch_size = min(64, n * n)
            batch = []

            for y in range(n):
                for x in range(n):
                    batch.append((z, x, y))

                    if len(batch) >= batch_size:
                        results = await asyncio.gather(
                            *[process_tile(session, semaphore, bz, bx, by)
                              for bz, bx, by in batch]
                        )
                        for (bz, bx, by), png_data in zip(batch, results):
                            if png_data:
                                tms_y = flip_y(bz, by)
                                db.execute(
                                    "INSERT OR REPLACE INTO tiles VALUES (?,?,?,?)",
                                    (bz, bx, tms_y, png_data),
                                )
                                saved += 1
                            else:
                                skipped += 1
                            level_done += 1

                        elapsed = time.time() - t0
                        rate = (saved + skipped) / max(elapsed, 0.1)
                        print(
                            f"  z{z}: {level_done}/{level_total} | "
                            f"saved={saved} skipped={skipped} | "
                            f"{rate:.1f} tiles/s",
                            end="\r",
                        )
                        batch = []
                        db.commit()

            # Final batch
            if batch:
                results = await asyncio.gather(
                    *[process_tile(session, semaphore, bz, bx, by)
                      for bz, bx, by in batch]
                )
                for (bz, bx, by), png_data in zip(batch, results):
                    if png_data:
                        tms_y = flip_y(bz, by)
                        db.execute(
                            "INSERT OR REPLACE INTO tiles VALUES (?,?,?,?)",
                            (bz, bx, tms_y, png_data),
                        )
                        saved += 1
                    else:
                        skipped += 1
                db.commit()

            print(f"\n  z{z} complete: {saved} tiles saved, {skipped} skipped")

    # Update metadata with actual zoom range
    db.execute(
        "INSERT OR REPLACE INTO metadata VALUES ('minzoom', ?)", (str(min_zoom),)
    )
    db.execute(
        "INSERT OR REPLACE INTO metadata VALUES ('maxzoom', ?)", (str(max_zoom),)
    )
    db.commit()
    db.close()

    elapsed = time.time() - t0
    print(f"\nDone in {elapsed:.0f}s. {saved} tiles saved to {output_path}")
    print(f"Convert to PMTiles: pmtiles convert {output_path} "
          f"{output_path.replace('.mbtiles', '.pmtiles')}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate combined WorldCereal crop type map"
    )
    parser.add_argument("--min-zoom", type=int, default=0)
    parser.add_argument("--max-zoom", type=int, default=6,
                        help="Max zoom level (default 6, ~2.5km/pixel)")
    parser.add_argument("--output", default="worldcereal_croptype_2021.mbtiles")
    parser.add_argument("--concurrency", type=int, default=8)
    args = parser.parse_args()

    print(f"Generating WorldCereal combined crop type map z{args.min_zoom}-{args.max_zoom}")
    print(f"Layers: {', '.join(l['id'] for l in LAYERS)}")
    print(f"Output: {args.output}")

    asyncio.run(generate(args.min_zoom, args.max_zoom, args.output, args.concurrency))


if __name__ == "__main__":
    main()
