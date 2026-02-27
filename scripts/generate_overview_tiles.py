#!/usr/bin/env python3
"""
Generate coarse overview PMTiles for all WMS-based crop map datasets.

Fetches WMS tiles at z0-8 (configurable per source), skips transparent tiles,
and writes to MBTiles for conversion to PMTiles.

Usage:
    pip install aiohttp Pillow
    python generate_overview_tiles.py [--source usda_cdl] [--all] [--max-zoom 6]
    pmtiles convert <source>.mbtiles <source>.pmtiles

Sources are defined in wms_sources.json.
"""

import asyncio
import aiohttp
import io
import os
import sys
import json
import time
import sqlite3
import argparse
from PIL import Image

ORIGIN_SHIFT = 20037508.3427892
TILE_SIZE = 256

# All WMS sources with their configurations
WMS_SOURCES = {
    "usda_cdl": {
        "name": "USDA CDL",
        "base_url": "https://nassgeodata.gmu.edu/CropScapeService/wms_cdlall.cgi",
        "layers": "cdl_{year}",
        "crs": "EPSG:4326",
        "wms_version": "1.1.1",
        "years": list(range(2008, 2024)),
        "default_year": 2023,
        "max_zoom": 8,
        "bounds": [-130, 24, -65, 50],  # [west, south, east, north]
    },
    "aafc": {
        "name": "AAFC Canada",
        "base_url": "https://www.agr.gc.ca/imagery-images/services/annual_crop_inventory/{year}/ImageServer/WMSServer",
        "layers": "{year}:annual_crop_inventory",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "years": list(range(2009, 2025)),
        "default_year": 2024,
        "max_zoom": 8,
        "bounds": [-141, 42, -52, 70],
    },
    "jrc_eucropmap": {
        "name": "JRC EU Crop Map",
        "base_url": "https://jeodpp.jrc.ec.europa.eu/jeodpp/services/ows/wms/landcover/eucropmap",
        "layers": "LC.EUCROPMAP.{year}",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "years": list(range(2018, 2023)),
        "default_year": 2022,
        "max_zoom": 8,
        "bounds": [-12, 34, 45, 72],
    },
    "crome": {
        "name": "CROME England",
        "base_url": "https://environment.data.gov.uk/spatialdata/crop-map-of-england-{year}/wms",
        "layers": "Crop_Map_of_England_{year}",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "years": list(range(2017, 2025)),
        "default_year": 2024,
        "max_zoom": 8,
        "bounds": [-6, 49.5, 2, 56],
    },
    "dlr_croptypes": {
        "name": "DLR CropTypes Germany",
        "base_url": "https://geoservice.dlr.de/eoc/land/wms",
        "layers": "CROPTYPES_DE_P1Y",
        "extra_params": "STYLES=croptypes",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [5, 47, 16, 55.5],
    },
    "rpg_france": {
        "name": "RPG France",
        "base_url": "https://data.geopf.fr/wms-r/wms",
        "layers": "LANDUSE.AGRICULTURE.LATEST",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [-5.5, 41, 10, 51.5],
    },
    "brp_netherlands": {
        "name": "BRP Netherlands",
        "base_url": "https://service.pdok.nl/rvo/brpgewaspercelen/wms/v1_0",
        "layers": "BrpGewas",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [3, 50.5, 7.5, 54],
    },
    "esa_worldcover": {
        "name": "ESA WorldCover",
        "base_url": "https://services.terrascope.be/wms/v2",
        "layers": "WORLDCOVER_{year}_MAP",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "years": [2020, 2021],
        "default_year": 2021,
        "max_zoom": 6,
        "bounds": [-180, -85, 180, 85],
    },
    "worldcereal": {
        "name": "ESA WorldCereal Temporary Crops",
        "base_url": "https://services.terrascope.be/wms/v2",
        "layers": "WORLDCEREAL_TEMPORARYCROPS_V1",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "max_zoom": 6,
        "bounds": [-180, -85, 180, 85],
    },
    "worldcereal_maize": {
        "name": "ESA WorldCereal Maize",
        "base_url": "https://services.terrascope.be/wms/v2",
        "layers": "WORLDCEREAL_MAIZE_V1",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "max_zoom": 6,
        "bounds": [-180, -85, 180, 85],
    },
    "invekos_austria": {
        "name": "INVEKOS Austria",
        "base_url": "https://inspire.lfrz.gv.at/009501/wms",
        "layers": "inspire_feldstuecke_2025-2",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [9, 46, 17.5, 49],
    },
    "alv_flanders": {
        "name": "ALV Flanders",
        "base_url": "https://geo.api.vlaanderen.be/ALV/wms",
        "layers": "LbGebrPerc2024",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [2.5, 50.6, 6, 51.5],
    },
    "sigpac_spain": {
        "name": "SIGPAC Spain",
        "base_url": "https://wms.mapa.gob.es/sigpac/wms",
        "layers": "AU.Sigpac:recinto",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [-10, 35, 5, 44],
    },
    "fvm_denmark": {
        "name": "FVM Denmark",
        "base_url": "https://geodata.fvm.dk/geoserver/ows",
        "layers": "Marker_2024",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [7.5, 54, 15.5, 58],
    },
    "lpis_czechia": {
        "name": "LPIS Czechia",
        "base_url": "https://mze.gov.cz/public/app/wms/public_DPB_PB_OPV.fcgi",
        "layers": "DPB_UCINNE",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [12, 48.5, 19, 51.5],
    },
    "gerk_slovenia": {
        "name": "GERK Slovenia",
        "base_url": "https://storitve.eprostor.gov.si/ows-pub-wms/SI.MKGP.GERK/ows",
        "layers": "RKG_BLOK_GERK",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [13, 45.4, 16.6, 47],
    },
    "arkod_croatia": {
        "name": "ARKOD Croatia",
        "base_url": "https://servisi.apprrr.hr/NIPP/wms",
        "layers": "hr.land_parcels",
        "crs": "EPSG:4326",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [13, 42, 20, 47],
    },
    "gsaa_estonia": {
        "name": "GSAA Estonia",
        "base_url": "https://kls.pria.ee/geoserver/inspire_gsaa/wms",
        "layers": "inspire_gsaa",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [21, 57, 28.5, 60],
    },
    "latvia_fields": {
        "name": "Latvia Field Blocks",
        "base_url": "https://karte.lad.gov.lv/arcgis/services/lauku_bloki/MapServer/WMSServer",
        "layers": "0",
        "crs": "EPSG:4326",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [20, 55.5, 28.5, 58.5],
    },
    "ifap_portugal": {
        "name": "IFAP Portugal",
        "base_url": "https://www.ifap.pt/isip/ows/isip.data/wms",
        "layers": "Parcelas_2019_Centro",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [-10, 36.5, -6, 42.5],
    },
    "lpis_poland": {
        "name": "LPIS Poland",
        "base_url": "https://mapy.geoportal.gov.pl/wss/ext/arimr_lpis",
        "layers": "14",
        "crs": "EPSG:4326",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [14, 49, 24.5, 55],
    },
    "jordbruk_sweden": {
        "name": "Jordbruk Sweden",
        "base_url": "https://epub.sjv.se/inspire/inspire/wms",
        "layers": "jordbruksblock",
        "crs": "EPSG:3857",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [10, 55, 25, 70],
    },
    "flik_luxembourg": {
        "name": "FLIK Luxembourg",
        "base_url": "https://wms.inspire.geoportail.lu/geoserver/af/wms",
        "layers": "af:asta_flik_parcels",
        "crs": "EPSG:3857",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [5.7, 49.4, 6.6, 50.2],
    },
    "blw_switzerland": {
        "name": "BLW Switzerland",
        "base_url": "https://wms.geo.admin.ch/",
        "layers": "ch.blw.landwirtschaftliche-nutzungsflaechen",
        "crs": "EPSG:4326",
        "wms_version": "1.3.0",
        "max_zoom": 8,
        "bounds": [5.9, 45.8, 10.5, 48],
    },
    "abares_australia": {
        "name": "ABARES Australia",
        "base_url": "https://di-daa.img.arcgis.com/arcgis/services/Land_and_vegetation/Catchment_Scale_Land_Use_Simplified/ImageServer/WMSServer",
        "layers": "Catchment_Scale_Land_Use_Simplified",
        "crs": "EPSG:4326",
        "wms_version": "1.3.0",
        "max_zoom": 7,
        "bounds": [112, -44, 155, -10],
    },
    "lcdb_newzealand": {
        "name": "LCDB New Zealand",
        "base_url": "https://maps.scinfo.org.nz/lcdb/wms",
        "layers": "lcdb_lcdb6",
        "crs": "EPSG:4326",
        "wms_version": "1.1.1",
        "max_zoom": 8,
        "bounds": [165, -48, 179, -34],
    },
    "geointa_argentina": {
        "name": "GeoINTA Argentina",
        "base_url": "https://geo-backend.inta.gob.ar/geoserver/wms",
        "layers": "geonode:mnc_verano2024_f300268fd112b0ec3ef5f731edb78882",
        "crs": "EPSG:4326",
        "wms_version": "1.3.0",
        "max_zoom": 7,
        "bounds": [-74, -56, -53, -21],
    },
}


def lon_to_tile_x(lon, z):
    return int((lon + 180) / 360 * (2 ** z))


def lat_to_tile_y(lat, z):
    import math
    lat_rad = math.radians(lat)
    n = 2 ** z
    return int((1 - math.log(math.tan(lat_rad) + 1 / math.cos(lat_rad)) / math.pi) / 2 * n)


def tile_bbox_3857(z, x, y):
    n = 2 ** z
    span = 2 * ORIGIN_SHIFT / n
    x_min = -ORIGIN_SHIFT + x * span
    x_max = -ORIGIN_SHIFT + (x + 1) * span
    y_max = ORIGIN_SHIFT - y * span
    y_min = ORIGIN_SHIFT - (y + 1) * span
    return x_min, y_min, x_max, y_max


def tile_bbox_4326(z, x, y):
    import math
    n = 2 ** z
    lon_min = x / n * 360 - 180
    lon_max = (x + 1) / n * 360 - 180
    lat_max = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * y / n))))
    lat_min = math.degrees(math.atan(math.sinh(math.pi * (1 - 2 * (y + 1) / n))))
    return lon_min, lat_min, lon_max, lat_max


def build_wms_url(source, z, x, y, year=None):
    """Construct WMS GetMap URL for a tile."""
    src = WMS_SOURCES[source]
    crs = src.get("crs", "EPSG:3857")
    version = src.get("wms_version", "1.1.1")

    # Resolve year in URL templates
    base_url = src["base_url"]
    layers = src["layers"]
    if year:
        base_url = base_url.replace("{year}", str(year))
        layers = layers.replace("{year}", str(year))

    if crs == "EPSG:4326":
        lon_min, lat_min, lon_max, lat_max = tile_bbox_4326(z, x, y)
        if version == "1.3.0":
            bbox = f"{lat_min},{lon_min},{lat_max},{lon_max}"
        else:
            bbox = f"{lon_min},{lat_min},{lon_max},{lat_max}"
    else:
        x_min, y_min, x_max, y_max = tile_bbox_3857(z, x, y)
        bbox = f"{x_min},{y_min},{x_max},{y_max}"

    srs_param = "CRS" if version == "1.3.0" else "SRS"
    url = (
        f"{base_url}?SERVICE=WMS&VERSION={version}&REQUEST=GetMap"
        f"&LAYERS={layers}&{srs_param}={crs}&BBOX={bbox}"
        f"&WIDTH={TILE_SIZE}&HEIGHT={TILE_SIZE}&FORMAT=image/png&TRANSPARENT=TRUE&STYLES="
    )
    extra = src.get("extra_params", "")
    if extra:
        url += f"&{extra}"
    return url


def flip_y(z, y):
    return (2 ** z) - 1 - y


def is_transparent(data):
    """Check if a PNG tile is fully transparent."""
    try:
        img = Image.open(io.BytesIO(data)).convert("RGBA")
        # Sample pixels — if all alpha=0, skip
        pixels = img.getdata()
        # Check a sample of pixels
        sample = list(pixels)[::max(1, len(pixels) // 100)]
        return all(p[3] == 0 for p in sample)
    except Exception:
        return True


def init_mbtiles(path, name, description=""):
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
    for k, v in {"name": name, "format": "png", "type": "overlay",
                  "description": description}.items():
        db.execute("INSERT INTO metadata VALUES (?, ?)", (k, v))
    db.commit()
    return db


async def fetch_tile(session, url, semaphore, retries=2):
    for attempt in range(retries + 1):
        async with semaphore:
            try:
                async with session.get(
                    url, timeout=aiohttp.ClientTimeout(total=30)
                ) as resp:
                    if resp.status == 200:
                        data = await resp.read()
                        if len(data) > 100:
                            return data
            except (aiohttp.ClientError, asyncio.TimeoutError):
                if attempt < retries:
                    await asyncio.sleep(1)
    return None


async def generate_source(source_id, max_zoom_override=None, year_override=None,
                           output_dir="pmtiles", concurrency=8):
    """Generate overview tiles for a single source."""
    src = WMS_SOURCES[source_id]
    name = src["name"]
    max_zoom = max_zoom_override or src.get("max_zoom", 6)
    bounds = src.get("bounds", [-180, -85, 180, 85])
    year = year_override or src.get("default_year")
    years = [year] if year else [None]

    for yr in years:
        suffix = f"_{yr}" if yr else ""
        mbtiles_path = os.path.join(output_dir, f"{source_id}{suffix}.mbtiles")
        os.makedirs(output_dir, exist_ok=True)

        desc = f"{name}{f' ({yr})' if yr else ''} overview tiles z0-{max_zoom}"
        print(f"\n{'='*60}")
        print(f"Generating: {desc}")
        print(f"Output: {mbtiles_path}")
        print(f"Bounds: {bounds}")
        print(f"{'='*60}")

        db = init_mbtiles(mbtiles_path, f"{name}{suffix}", desc)
        semaphore = asyncio.Semaphore(concurrency)
        connector = aiohttp.TCPConnector(limit=concurrency * 2)

        saved = 0
        skipped = 0
        t0 = time.time()

        async with aiohttp.ClientSession(connector=connector) as session:
            for z in range(0, max_zoom + 1):
                # Compute tile range for bounds at this zoom
                x_min = max(0, lon_to_tile_x(bounds[0], z))
                x_max = min(2**z - 1, lon_to_tile_x(bounds[2], z))
                y_min = max(0, lat_to_tile_y(bounds[3], z))  # Note: y is inverted
                y_max = min(2**z - 1, lat_to_tile_y(bounds[1], z))

                level_total = (x_max - x_min + 1) * (y_max - y_min + 1)
                print(f"\n  z{z}: {level_total} tiles (x={x_min}-{x_max}, y={y_min}-{y_max})")

                batch = []
                for yy in range(y_min, y_max + 1):
                    for xx in range(x_min, x_max + 1):
                        url = build_wms_url(source_id, z, xx, yy, year=yr)
                        batch.append((z, xx, yy, url))

                        if len(batch) >= 32:
                            results = await asyncio.gather(
                                *[fetch_tile(session, b[3], semaphore) for b in batch]
                            )
                            for (bz, bx, by, _), data in zip(batch, results):
                                if data and not is_transparent(data):
                                    tms_y = flip_y(bz, by)
                                    db.execute(
                                        "INSERT OR REPLACE INTO tiles VALUES (?,?,?,?)",
                                        (bz, bx, tms_y, data),
                                    )
                                    saved += 1
                                else:
                                    skipped += 1

                            elapsed = time.time() - t0
                            rate = (saved + skipped) / max(elapsed, 0.1)
                            print(f"    saved={saved} skipped={skipped} ({rate:.1f}/s)", end="\r")
                            batch = []

                if batch:
                    results = await asyncio.gather(
                        *[fetch_tile(session, b[3], semaphore) for b in batch]
                    )
                    for (bz, bx, by, _), data in zip(batch, results):
                        if data and not is_transparent(data):
                            tms_y = flip_y(bz, by)
                            db.execute(
                                "INSERT OR REPLACE INTO tiles VALUES (?,?,?,?)",
                                (bz, bx, tms_y, data),
                            )
                            saved += 1
                        else:
                            skipped += 1

                db.commit()

        db.execute("INSERT OR REPLACE INTO metadata VALUES ('minzoom', '0')")
        db.execute("INSERT OR REPLACE INTO metadata VALUES ('maxzoom', ?)", (str(max_zoom),))
        db.execute("INSERT OR REPLACE INTO metadata VALUES ('bounds', ?)",
                   (f"{bounds[0]},{bounds[1]},{bounds[2]},{bounds[3]}",))
        db.commit()
        db.close()

        elapsed = time.time() - t0
        size_mb = os.path.getsize(mbtiles_path) / (1024 * 1024)
        print(f"\n  Done: {saved} tiles, {size_mb:.1f}MB in {elapsed:.0f}s")
        print(f"  Convert: pmtiles convert {mbtiles_path} {mbtiles_path.replace('.mbtiles', '.pmtiles')}")


async def generate_all(max_zoom_override=None, output_dir="pmtiles", concurrency=6):
    """Generate overview tiles for ALL sources."""
    for source_id in WMS_SOURCES:
        try:
            await generate_source(source_id, max_zoom_override=max_zoom_override,
                                   output_dir=output_dir, concurrency=concurrency)
        except Exception as e:
            print(f"\n  ERROR generating {source_id}: {e}")
            continue


def main():
    parser = argparse.ArgumentParser(description="Generate WMS overview tiles as MBTiles/PMTiles")
    parser.add_argument("--source", help="Single source ID (e.g., usda_cdl)")
    parser.add_argument("--all", action="store_true", help="Generate for all sources")
    parser.add_argument("--list", action="store_true", help="List available sources")
    parser.add_argument("--max-zoom", type=int, help="Override max zoom level")
    parser.add_argument("--year", type=int, help="Override year")
    parser.add_argument("--output-dir", default="pmtiles")
    parser.add_argument("--concurrency", type=int, default=6)
    args = parser.parse_args()

    if args.list:
        print("Available sources:")
        for sid, src in sorted(WMS_SOURCES.items()):
            years = src.get("years", [])
            yr_str = f" ({years[0]}-{years[-1]})" if years else ""
            print(f"  {sid:25s} {src['name']}{yr_str}  z0-{src.get('max_zoom', 6)}")
        return

    if args.all:
        asyncio.run(generate_all(args.max_zoom, args.output_dir, args.concurrency))
    elif args.source:
        if args.source not in WMS_SOURCES:
            print(f"Unknown source: {args.source}")
            print(f"Available: {', '.join(sorted(WMS_SOURCES.keys()))}")
            sys.exit(1)
        asyncio.run(generate_source(
            args.source, args.max_zoom, args.year, args.output_dir, args.concurrency
        ))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
