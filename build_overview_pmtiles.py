#!/usr/bin/env python3
"""Download WMS tiles and build overview PMTiles for parcel datasets.

Downloads tiles at the native zoom where data is visible,
then creates overview tiles by downsampling (mode/nearest-neighbor)
to produce a complete z0-zN tile pyramid. Outputs MBTiles → PMTiles.

Usage:
    python3 build_overview_pmtiles.py <dataset_id> [--data-zoom N] [--dry-run]
"""

import argparse
import io
import math
import os
import sqlite3
import struct
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from PIL import Image

# Force unbuffered output
sys.stdout.reconfigure(line_buffering=True)

# ============ DATASET CONFIGURATIONS ============
CONFIGS = {
    'brp': {
        'name': 'BRP Netherlands',
        'wms': 'https://service.pdok.nl/rvo/brpgewaspercelen/wms/v1_0',
        'layers': 'BrpGewas', 'version': '1.3.0', 'crs': '3857',
        'styles': '', 'bbox': [3.3, 50.75, 7.22, 53.5],
        'data_zoom': 14, 'min_overview': 7,
    },
    'alv': {
        'name': 'Flanders ALV',
        'wms': 'https://geo.api.vlaanderen.be/ALV/wms',
        'layers': 'LbGebrPerc2024', 'version': '1.3.0', 'crs': '3857',
        'styles': '', 'bbox': [2.5, 50.6, 5.9, 51.5],
        'data_zoom': 14, 'min_overview': 8,
    },
    'wallonia': {
        'name': 'Wallonia Agriculture',
        'wms': 'https://geoservices.wallonie.be/arcgis/services/AGRICULTURE/SIGEC_PARC_AGRI_ANON__2023/MapServer/WMSServer',
        'layers': '0', 'version': '1.3.0', 'crs': '3857',
        'styles': '', 'bbox': [2.8, 49.45, 6.4, 50.85],
        'data_zoom': 14, 'min_overview': 8,
    },
    'invekos': {
        'name': 'INVEKOS Austria',
        'wms': 'https://inspire.lfrz.gv.at/009501/wms',
        'layers': 'inspire_feldstuecke_2025-2', 'version': '1.3.0', 'crs': '3857',
        'styles': '', 'bbox': [9.5, 46.37, 17.17, 49.02],
        'data_zoom': 13, 'min_overview': 7,
    },
    'fvm': {
        'name': 'Denmark FVM',
        'wms': 'https://geodata.fvm.dk/geoserver/ows',
        'layers': 'Jordbrugsanalyser:Marker24', 'version': '1.1.1', 'crs': '3857',
        'styles': 'Marker', 'bbox': [8.0, 54.5, 15.2, 57.8],
        'data_zoom': 14, 'min_overview': 7,
    },
    'flik': {
        'name': 'Luxembourg FLIK',
        'wms': 'https://wms.inspire.geoportail.lu/geoserver/af/wms',
        'layers': 'LU.ExistingLandUseObject_LPIS_2024', 'version': '1.3.0', 'crs': '3857',
        'styles': '', 'bbox': [5.73, 49.44, 6.53, 50.19],
        'data_zoom': 14, 'min_overview': 9,
    },
    'portugal': {
        'name': 'Portugal IFAP',
        'wms': 'https://www.ifap.pt/isip/ows/isip.data/wms',
        'layers': 'isip.data:ocupacoes.solo.Centro_N.2017jun10', 'version': '1.3.0', 'crs': '3857',
        'styles': '', 'bbox': [-9.5, 36.9, -6.2, 42.2],
        'data_zoom': 14, 'min_overview': 7,
    },
    'nibio': {
        'name': 'NIBIO Norway',
        'wms': 'https://wms.nibio.no/cgi-bin/ar5',
        'layers': 'Arealtype', 'version': '1.1.1', 'crs': '4326',
        'styles': '', 'bbox': [4.5, 58.0, 12.0, 64.0],  # Agricultural Norway (Rogaland to Trøndelag)
        'data_zoom': 14, 'min_overview': 7,
    },
}

TILE_SIZE = 256
WORLD_SIZE = 20037508.34 * 2
TRANSPARENT_THRESHOLD = 400  # bytes — PNGs smaller than this are transparent


def lon_to_tile_x(lon, zoom):
    return int((lon + 180.0) / 360.0 * (1 << zoom))


def lat_to_tile_y(lat, zoom):
    lat_r = math.radians(lat)
    n = 1 << zoom
    return int((1.0 - math.log(math.tan(lat_r) + 1.0 / math.cos(lat_r)) / math.pi) / 2.0 * n)


def tile_bbox_3857(x, y, z):
    """Get tile bounds in EPSG:3857."""
    tile_size = WORLD_SIZE / (1 << z)
    x0 = -WORLD_SIZE / 2 + x * tile_size
    y1 = WORLD_SIZE / 2 - y * tile_size
    x1 = x0 + tile_size
    y0 = y1 - tile_size
    return x0, y0, x1, y1


def tile_bbox_4326(x, y, z):
    """Get tile bounds in EPSG:4326 (lon/lat)."""
    n = 1 << z
    lon0 = x / n * 360.0 - 180.0
    lon1 = (x + 1) / n * 360.0 - 180.0
    lat1 = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    lat0 = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * (y + 1) / n))))
    return lon0, lat0, lon1, lat1


def build_wms_url(cfg, x, y, z):
    """Build WMS GetMap URL for a tile."""
    if cfg['crs'] == '4326':
        lon0, lat0, lon1, lat1 = tile_bbox_4326(x, y, z)
        srs_key = 'CRS' if cfg['version'] == '1.3.0' else 'SRS'
        srs_val = 'EPSG:4326'
        if cfg['version'] == '1.3.0':
            bbox = f'{lat0},{lon0},{lat1},{lon1}'  # lat/lon order for 1.3.0
        else:
            bbox = f'{lon0},{lat0},{lon1},{lat1}'  # lon/lat order for 1.1.1
    else:
        x0, y0, x1, y1 = tile_bbox_3857(x, y, z)
        srs_key = 'CRS' if cfg['version'] == '1.3.0' else 'SRS'
        srs_val = 'EPSG:3857'
        bbox = f'{x0},{y0},{x1},{y1}'

    url = (f"{cfg['wms']}?SERVICE=WMS&VERSION={cfg['version']}&REQUEST=GetMap"
           f"&LAYERS={cfg['layers']}&STYLES={cfg['styles']}"
           f"&{srs_key}={srs_val}&BBOX={bbox}"
           f"&WIDTH={TILE_SIZE}&HEIGHT={TILE_SIZE}&FORMAT=image/png&TRANSPARENT=TRUE")
    return url


def download_tile(cfg, x, y, z, retries=3):
    """Download a single tile, return PNG bytes or None."""
    url = build_wms_url(cfg, x, y, z)
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'ARCcrop-overview/1.0'})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                if len(data) < TRANSPARENT_THRESHOLD:
                    return None  # transparent tile
                ct = resp.headers.get('Content-Type', '')
                if 'xml' in ct or 'html' in ct:
                    return None  # error response
                return data
        except Exception:
            if attempt < retries - 1:
                time.sleep(1)
    return None


def init_mbtiles(path):
    """Create a new MBTiles database."""
    if os.path.exists(path):
        os.remove(path)
    conn = sqlite3.connect(path)
    conn.execute("CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)")
    conn.execute("CREATE TABLE metadata (name TEXT, value TEXT)")
    conn.execute("CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row)")
    conn.commit()
    return conn


def insert_tile(conn, z, x, y_xyz, png_data):
    """Insert a tile into MBTiles (converts XYZ y to TMS y)."""
    y_tms = (1 << z) - 1 - y_xyz
    conn.execute("INSERT OR REPLACE INTO tiles VALUES (?, ?, ?, ?)", (z, x, y_tms, png_data))


def get_tile(conn, z, x, y_xyz):
    """Get a tile from MBTiles (converts XYZ y to TMS y), return PNG bytes or None."""
    y_tms = (1 << z) - 1 - y_xyz
    row = conn.execute("SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=?",
                       (z, x, y_tms)).fetchone()
    return row[0] if row else None


def build_overview_tile(conn, z, x, y):
    """Build an overview tile at zoom z by compositing 4 child tiles from z+1."""
    children = []
    for dy in range(2):
        for dx in range(2):
            cx, cy = x * 2 + dx, y * 2 + dy
            data = get_tile(conn, z + 1, cx, cy)
            if data:
                try:
                    img = Image.open(io.BytesIO(data)).convert('RGBA')
                except Exception:
                    img = Image.new('RGBA', (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
            else:
                img = Image.new('RGBA', (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
            children.append((dx, dy, img))

    # Composite into 512x512 then downsample to 256x256
    combined = Image.new('RGBA', (TILE_SIZE * 2, TILE_SIZE * 2), (0, 0, 0, 0))
    for dx, dy, img in children:
        combined.paste(img, (dx * TILE_SIZE, dy * TILE_SIZE))

    # Downsample using NEAREST to preserve crop colors
    overview = combined.resize((TILE_SIZE, TILE_SIZE), Image.NEAREST)

    # Check if tile has any non-transparent pixels
    pixels = overview.getdata()
    has_content = any(p[3] > 0 for p in pixels)
    if not has_content:
        return None

    buf = io.BytesIO()
    overview.save(buf, format='PNG', optimize=True)
    return buf.getvalue()


def main():
    parser = argparse.ArgumentParser(description='Build overview PMTiles for parcel datasets')
    parser.add_argument('dataset', choices=list(CONFIGS.keys()), help='Dataset ID')
    parser.add_argument('--data-zoom', type=int, help='Override data zoom level')
    parser.add_argument('--min-overview', type=int, help='Override minimum overview zoom')
    parser.add_argument('--workers', type=int, default=8, help='Concurrent download threads')
    parser.add_argument('--dry-run', action='store_true', help='Just count tiles, don\'t download')
    parser.add_argument('--output-dir', default='.', help='Output directory')
    args = parser.parse_args()

    cfg = CONFIGS[args.dataset]
    data_zoom = args.data_zoom or cfg['data_zoom']
    min_overview = args.min_overview or cfg['min_overview']
    name = cfg['name']

    # Calculate tile range at data zoom
    bbox = cfg['bbox']
    x_min = lon_to_tile_x(bbox[0], data_zoom)
    x_max = lon_to_tile_x(bbox[2], data_zoom)
    y_min = lat_to_tile_y(bbox[3], data_zoom)  # Note: lat_to_tile_y is inverted
    y_max = lat_to_tile_y(bbox[1], data_zoom)

    total_tiles = (x_max - x_min + 1) * (y_max - y_min + 1)
    print(f"=== {name} ===")
    print(f"Data zoom: z{data_zoom}, Overview: z{min_overview}-z{data_zoom}")
    print(f"Tile range: x[{x_min}-{x_max}] y[{y_min}-{y_max}] = {total_tiles} tiles")

    if args.dry_run:
        print("(dry run — not downloading)")
        return

    # Init MBTiles
    mbtiles_path = os.path.join(args.output_dir, f"{args.dataset}-overview.mbtiles")
    pmtiles_path = os.path.join(args.output_dir, f"{args.dataset}-overview.pmtiles")
    conn = init_mbtiles(mbtiles_path)

    # Set metadata
    conn.execute("INSERT INTO metadata VALUES ('name', ?)", (name,))
    conn.execute("INSERT INTO metadata VALUES ('format', 'png')")
    conn.execute("INSERT INTO metadata VALUES ('type', 'overlay')")
    conn.execute("INSERT INTO metadata VALUES ('minzoom', ?)", (str(min_overview),))
    conn.execute("INSERT INTO metadata VALUES ('maxzoom', ?)", (str(data_zoom),))
    conn.execute("INSERT INTO metadata VALUES ('bounds', ?)",
                 (f"{bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]}",))
    conn.commit()

    # Download data zoom tiles
    print(f"\n--- Downloading z{data_zoom} tiles ---")
    tiles_to_download = [(x, y) for x in range(x_min, x_max + 1) for y in range(y_min, y_max + 1)]
    downloaded = 0
    non_empty = 0
    start = time.time()

    def download_one(xy):
        x, y = xy
        data = download_tile(cfg, x, y, data_zoom)
        return x, y, data

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(download_one, xy): xy for xy in tiles_to_download}
        for future in as_completed(futures):
            x, y, data = future.result()
            downloaded += 1
            if data:
                insert_tile(conn, data_zoom, x, y, data)
                non_empty += 1
            if downloaded % 200 == 0:
                elapsed = time.time() - start
                rate = downloaded / elapsed if elapsed > 0 else 0
                eta = (total_tiles - downloaded) / rate if rate > 0 else 0
                pct = downloaded / total_tiles * 100
                print(f"  [{pct:5.1f}%] {downloaded}/{total_tiles} — "
                      f"{non_empty} data, {downloaded - non_empty} empty — "
                      f"{rate:.1f}/s, ETA {eta:.0f}s")

    conn.commit()
    elapsed = time.time() - start
    print(f"\nDownloaded {total_tiles} tiles in {elapsed:.0f}s: {non_empty} with data")

    # Build overview tiles from data_zoom-1 down to min_overview
    for z in range(data_zoom - 1, min_overview - 1, -1):
        # Calculate tile range at this zoom
        zx_min = x_min >> (data_zoom - z)
        zx_max = x_max >> (data_zoom - z)
        zy_min = y_min >> (data_zoom - z)
        zy_max = y_max >> (data_zoom - z)
        ztotal = (zx_max - zx_min + 1) * (zy_max - zy_min + 1)
        zcount = 0

        print(f"\n--- Building z{z} overviews ({ztotal} tiles) ---")
        for x in range(zx_min, zx_max + 1):
            for y in range(zy_min, zy_max + 1):
                data = build_overview_tile(conn, z, x, y)
                if data:
                    insert_tile(conn, z, x, y, data)
                    zcount += 1
        conn.commit()
        print(f"  z{z}: {zcount}/{ztotal} tiles with data")

    conn.commit()
    conn.close()

    # Get file size
    mbtiles_size = os.path.getsize(mbtiles_path) / 1024 / 1024
    print(f"\nMBTiles: {mbtiles_path} ({mbtiles_size:.1f} MB)")

    # Convert to PMTiles
    print("Converting to PMTiles...")
    os.system(f"pmtiles convert {mbtiles_path} {pmtiles_path}")
    if os.path.exists(pmtiles_path):
        pmtiles_size = os.path.getsize(pmtiles_path) / 1024 / 1024
        print(f"PMTiles: {pmtiles_path} ({pmtiles_size:.1f} MB)")
    else:
        print("PMTiles conversion failed — check 'pmtiles' CLI")

    print(f"\n=== DONE: {name} ===")


if __name__ == '__main__':
    main()
