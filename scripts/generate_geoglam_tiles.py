#!/usr/bin/env python3
"""Generate GEOGLAM images in multiple projections for GitHub hosting.

Pure-Python approach (no GDAL/rasterio dependency issues).
Reads the 7200x3600 RGBA PNGs (EPSG:4326, -180..180 lon, -90..90 lat)
and produces:
  1. 4326 PNGs  (original projection, copied)
  2. Web Mercator (3857) PNGs (pre-reprojected, nearest-neighbor)
  3. 2048px versions of the 3857 images for mobile

All output goes to ../geoglam/ for GitHub hosting.
"""

import math
import sys
from pathlib import Path

import numpy as np

try:
    from PIL import Image
except ImportError:
    sys.exit("pip install Pillow")

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
RESOURCE_DIR = PROJECT_DIR / "ARCcrop" / "Resources" / "GEOGLAM"
OUTPUT_DIR = PROJECT_DIR / "geoglam"

DATASETS = [
    "GEOGLAM_MajorityCrop",
    "GEOGLAM_WinterWheat",
    "GEOGLAM_SpringWheat",
    "GEOGLAM_Maize",
    "GEOGLAM_Soybean",
    "GEOGLAM_Rice",
]

MERC_LAT = 85.051129


def reproject_4326_to_3857(src_data: np.ndarray, out_size: int) -> np.ndarray:
    """Reproject equirectangular (4326) RGBA image to Web Mercator (3857).

    Uses nearest-neighbor sampling (correct for classified/categorical data).

    Source: 7200x3600 (W×H), lon -180..180, lat +90..-90 (top to bottom)
    Output: out_size × out_size square, Mercator projection clipped to ±85.051°
    """
    src_h, src_w = src_data.shape[:2]
    out = np.zeros((out_size, out_size, 4), dtype=np.uint8)

    merc_max = math.pi  # Mercator y at 85.051°

    for out_row in range(out_size):
        # Map output row to Mercator y, then to latitude
        y_frac = (out_row + 0.5) / out_size
        merc_y = merc_max * (1.0 - 2.0 * y_frac)
        lat = math.degrees(math.atan(math.sinh(merc_y)))

        # Map latitude to source row (lat +90 at row 0, -90 at row H-1)
        row_frac = (90.0 - lat) / 180.0
        src_row = min(max(int(row_frac * src_h), 0), src_h - 1)

        for out_col in range(out_size):
            # Map output column to longitude
            lon_frac = (out_col + 0.5) / out_size
            # lon = -180 + lon_frac * 360
            col_frac = lon_frac  # directly maps to source column fraction
            src_col = min(max(int(col_frac * src_w), 0), src_w - 1)

            pixel = src_data[src_row, src_col]
            # Make black pixels transparent
            if pixel[0] == 0 and pixel[1] == 0 and pixel[2] == 0:
                out[out_row, out_col, 3] = 0
            else:
                out[out_row, out_col] = pixel

    return out


def reproject_vectorized(src_data: np.ndarray, out_size: int) -> np.ndarray:
    """Vectorized (fast) version of 4326→3857 reprojection."""
    src_h, src_w = src_data.shape[:2]
    merc_max = math.pi

    # Build output row → source row mapping
    out_rows = np.arange(out_size)
    y_frac = (out_rows + 0.5) / out_size
    merc_y = merc_max * (1.0 - 2.0 * y_frac)
    lat = np.degrees(np.arctan(np.sinh(merc_y)))
    row_frac = (90.0 - lat) / 180.0
    src_rows = np.clip((row_frac * src_h).astype(int), 0, src_h - 1)

    # Build output col → source col mapping
    out_cols = np.arange(out_size)
    col_frac = (out_cols + 0.5) / out_size
    src_cols = np.clip((col_frac * src_w).astype(int), 0, src_w - 1)

    # Index using meshgrid
    row_idx = src_rows[:, np.newaxis]  # (out_size, 1)
    col_idx = src_cols[np.newaxis, :]  # (1, out_size)
    # Broadcast to (out_size, out_size)
    out = src_data[row_idx, col_idx]  # (out_size, out_size, 4)

    # Make black pixels transparent
    black_mask = (out[:, :, 0] == 0) & (out[:, :, 1] == 0) & (out[:, :, 2] == 0)
    out[black_mask, 3] = 0

    return out


def main():
    OUTPUT_DIR.mkdir(exist_ok=True)
    print(f"Output: {OUTPUT_DIR}\n")

    for name in DATASETS:
        src_path = RESOURCE_DIR / f"{name}.png"
        if not src_path.exists():
            print(f"  SKIP {name}: not found")
            continue

        print(f"Processing {name}...")

        img = Image.open(src_path).convert("RGBA")
        src_data = np.array(img)
        h, w = src_data.shape[:2]
        print(f"  Source: {w}x{h}")

        # 1. Copy 4326 PNG
        out_4326 = OUTPUT_DIR / f"{name}_4326.png"
        img.save(out_4326, optimize=True)
        print(f"  4326: {out_4326.name} ({out_4326.stat().st_size / 1024:.0f} KB)")

        # 2. Full-res 3857 (same width as source, capped at 4096)
        full_size = min(w, 4096)
        merc_full = reproject_vectorized(src_data, full_size)
        out_full = OUTPUT_DIR / f"{name}_3857.png"
        Image.fromarray(merc_full).save(out_full, optimize=True)
        print(f"  3857: {out_full.name} ({full_size}x{full_size}, {out_full.stat().st_size / 1024:.0f} KB)")

        # 3. Mobile 2048px 3857
        mobile_size = 2048
        merc_mobile = reproject_vectorized(src_data, mobile_size)
        out_mobile = OUTPUT_DIR / f"{name}_3857_2048.png"
        Image.fromarray(merc_mobile).save(out_mobile, optimize=True)
        print(f"  3857 mobile: {out_mobile.name} ({mobile_size}x{mobile_size}, {out_mobile.stat().st_size / 1024:.0f} KB)")

        print()

    print("Done! Files in:", OUTPUT_DIR)


if __name__ == "__main__":
    main()
