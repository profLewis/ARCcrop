#!/usr/bin/env python3
"""
Download GEOGLAM Best Available Crop Type Masks from Zenodo and convert
to correctly-georeferenced PNGs for the ARCcrop iOS app.

Source: IIASA/GEOGLAM v1.0 (2022)
DOI: 10.5281/zenodo.7230863

The GeoTIFFs are global equirectangular at 0.05° (7200x3600 pixels).
This script:
  1. Downloads each crop's GeoTIFF from Zenodo
  2. Reads the actual georeference (should be 7200 cols x 3600 rows)
  3. Saves as RGBA PNGs at native resolution (no padding, no scaling)
  4. Applies the official GEOGLAM colour palette for majority crop
  5. Saves fraction PNGs with continuous colour ramps

Output: ARCcrop/Resources/GEOGLAM/GEOGLAM_*.png

Usage:
    pip install rasterio numpy Pillow requests
    python generate_geoglam_pngs.py
"""

import os
import sys
import requests
import numpy as np
import rasterio
from PIL import Image

# Zenodo record for GEOGLAM BACM v1.0
ZENODO_RECORD = "7230863"
ZENODO_API = f"https://zenodo.org/api/records/{ZENODO_RECORD}"

# Map from crop name -> (GeoTIFF filename pattern, output stem)
CROPS = {
    "MajorityCrop": {
        "tif_pattern": "majority_crop",
        "output": "GEOGLAM_MajorityCrop",
        "type": "categorical",
    },
    "WinterWheat": {
        "tif_pattern": "wheat-winter",
        "output": "GEOGLAM_WinterWheat",
        "type": "fraction",
    },
    "SpringWheat": {
        "tif_pattern": "wheat-spring",
        "output": "GEOGLAM_SpringWheat",
        "type": "fraction",
    },
    "Maize": {
        "tif_pattern": "maize",
        "output": "GEOGLAM_Maize",
        "type": "fraction",
    },
    "Soybean": {
        "tif_pattern": "soybean",
        "output": "GEOGLAM_Soybean",
        "type": "fraction",
    },
    "Rice": {
        "tif_pattern": "rice",
        "output": "GEOGLAM_Rice",
        "type": "fraction",
    },
}

# Official GEOGLAM majority crop palette (class -> RGBA)
MAJORITY_PALETTE = {
    0: (0, 0, 0, 0),         # No data / no crop → transparent
    1: (139, 90, 43, 255),    # Winter Wheat → brown
    2: (255, 165, 0, 255),    # Spring Wheat → orange
    3: (255, 255, 0, 255),    # Maize → yellow
    4: (0, 180, 0, 255),      # Soybean → green
    5: (0, 200, 200, 255),    # Rice → cyan
}

# Fraction colour ramp per crop (0% → transparent, 100% → full colour)
FRACTION_COLOURS = {
    "WinterWheat": (139, 90, 43),
    "SpringWheat": (255, 165, 0),
    "Maize": (255, 255, 0),
    "Soybean": (0, 180, 0),
    "Rice": (0, 200, 200),
}

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "ARCcrop", "Resources", "GEOGLAM")
DOWNLOAD_DIR = os.path.join(os.path.dirname(__file__), "geoglam_tifs")


def find_zenodo_files():
    """Fetch the Zenodo record and return a dict of filename -> download URL."""
    print(f"Fetching Zenodo record {ZENODO_RECORD}...")
    resp = requests.get(ZENODO_API, timeout=30)
    resp.raise_for_status()
    record = resp.json()
    files = {}
    for f in record.get("files", []):
        files[f["key"]] = f["links"]["self"]
    print(f"  Found {len(files)} files")
    for name in sorted(files):
        print(f"    {name}")
    return files


def download_file(url, dest):
    """Download a file with progress indicator."""
    if os.path.exists(dest) and os.path.getsize(dest) > 1000:
        print(f"  Already downloaded: {dest}")
        return
    print(f"  Downloading: {os.path.basename(dest)}...")
    resp = requests.get(url, stream=True, timeout=120)
    resp.raise_for_status()
    total = int(resp.headers.get("content-length", 0))
    downloaded = 0
    with open(dest, "wb") as f:
        for chunk in resp.iter_content(chunk_size=1024 * 1024):
            f.write(chunk)
            downloaded += len(chunk)
            if total:
                pct = downloaded / total * 100
                print(f"    {pct:.0f}% ({downloaded // (1024*1024)}MB / {total // (1024*1024)}MB)", end="\r")
    print(f"    Done: {os.path.getsize(dest) // 1024}KB")


def tif_to_majority_png(tif_path, png_path):
    """Convert categorical majority crop GeoTIFF to coloured RGBA PNG."""
    with rasterio.open(tif_path) as src:
        data = src.read(1)  # Single band
        h, w = data.shape
        transform = src.transform
        crs = src.crs
        print(f"  GeoTIFF: {w}x{h}, CRS={crs}")
        print(f"  Transform: {transform}")
        print(f"  Bounds: {src.bounds}")
        print(f"  Unique values: {np.unique(data)}")

    # Create RGBA image
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    for val, colour in MAJORITY_PALETTE.items():
        mask = data == val
        rgba[mask] = colour

    img = Image.fromarray(rgba, "RGBA")
    img.save(png_path, optimize=True)
    print(f"  Saved: {png_path} ({os.path.getsize(png_path) // 1024}KB)")
    return w, h


def tif_to_fraction_png(tif_path, png_path, crop_name):
    """Convert fraction GeoTIFF to coloured RGBA PNG with alpha = fraction."""
    with rasterio.open(tif_path) as src:
        data = src.read(1).astype(np.float32)
        h, w = data.shape
        nodata = src.nodata
        print(f"  GeoTIFF: {w}x{h}, nodata={nodata}")
        print(f"  Bounds: {src.bounds}")
        print(f"  Value range: {np.nanmin(data):.2f} - {np.nanmax(data):.2f}")

    # Mask nodata
    if nodata is not None:
        data[data == nodata] = 0
    data[np.isnan(data)] = 0

    # Normalise to 0-1 (values should already be 0-100 or 0-1)
    if np.nanmax(data) > 1.0:
        data = data / 100.0
    data = np.clip(data, 0, 1)

    r, g, b = FRACTION_COLOURS[crop_name]
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    mask = data > 0.01  # Skip near-zero
    rgba[mask, 0] = r
    rgba[mask, 1] = g
    rgba[mask, 2] = b
    rgba[mask, 3] = (data[mask] * 255).astype(np.uint8)

    img = Image.fromarray(rgba, "RGBA")
    img.save(png_path, optimize=True)
    print(f"  Saved: {png_path} ({os.path.getsize(png_path) // 1024}KB)")
    return w, h


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)

    # Fetch Zenodo file listing
    zenodo_files = find_zenodo_files()

    dimensions = {}

    for crop_name, config in CROPS.items():
        print(f"\n{'='*60}")
        print(f"Processing: {crop_name}")
        print(f"{'='*60}")

        # Find the matching GeoTIFF in Zenodo files
        pattern = config["tif_pattern"]
        matching = [
            (name, url) for name, url in zenodo_files.items()
            if pattern in name.lower() and name.endswith(".tif")
        ]

        if not matching:
            # Try broader match
            matching = [
                (name, url) for name, url in zenodo_files.items()
                if pattern.replace("-", "_") in name.lower() and name.endswith(".tif")
            ]

        if not matching:
            print(f"  WARNING: No GeoTIFF found matching '{pattern}'")
            print(f"  Available: {[n for n in zenodo_files if n.endswith('.tif')]}")
            continue

        tif_name, tif_url = matching[0]
        tif_path = os.path.join(DOWNLOAD_DIR, tif_name)

        # Download
        download_file(tif_url, tif_path)

        # Convert to PNG
        png_path = os.path.join(OUTPUT_DIR, f"{config['output']}.png")

        if config["type"] == "categorical":
            w, h = tif_to_majority_png(tif_path, png_path)
        else:
            w, h = tif_to_fraction_png(tif_path, png_path, crop_name)

        dimensions[crop_name] = (w, h)

    # Print summary
    print(f"\n{'='*60}")
    print("Summary")
    print(f"{'='*60}")
    for crop, (w, h) in dimensions.items():
        print(f"  {crop}: {w}x{h}")

    print(f"\nOutput directory: {OUTPUT_DIR}")
    print("\nIMPORTANT: Update GEOGLAMOverlay.swift reprojection code if dimensions changed.")
    print("  Expected: 7200x3600 (not square 7200x7200)")
    print("  The reprojection should map:")
    print("    Longitude: -180 to +180 (columns 0..W-1)")
    print("    Latitude:  +90 to -90  (rows 0..H-1)")


if __name__ == "__main__":
    main()
