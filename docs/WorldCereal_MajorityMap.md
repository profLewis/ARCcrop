# WorldCereal Majority Crop Map — Generation Rules

## Input Layers

Four ESA WorldCereal v1.0 binary crop mask layers, each at 10m global resolution (Sentinel-2, 2021):

| Layer | WMS Layer Name | Colour | Pixel Values |
|-------|---------------|--------|-------------|
| Temporary Crops | `WORLDCEREAL_TEMPORARYCROPS_V1` | #E0181C (red) | 0 = no crop, 1 = crop |
| Maize | `WORLDCEREAL_MAIZE_V1` | #FFD300 (yellow) | 0 = no maize, 1 = maize |
| Winter Cereals | `WORLDCEREAL_WINTERCEREALS_V1` | #A87000 (brown) | 0 = no winter cereals, 1 = winter cereals |
| Spring Cereals | `WORLDCEREAL_SPRINGCEREALS_V1` | #00A8E6 (blue) | 0 = no spring cereals, 1 = spring cereals |

Source: Terrascope WMS (`services.terrascope.be/wms/v2`), provided by ESA/VITO.

## Relationship to GEOGLAM

WorldCereal crop masks are analogous to the GEOGLAM crop fraction maps:
- **GEOGLAM** provides crop area *fractions* (0–100%) at ~5.6 km resolution for 5 major crops (Winter Wheat, Spring Wheat, Maize, Soybean, Rice).
- **WorldCereal** provides *binary* crop presence/absence masks at 10m resolution for 4 crop categories.

Both are organised together under "Crop Type Maps" in the app's layer picker, with GEOGLAM as the coarse global view and WorldCereal as the fine-resolution view.

## Majority Map Generation Rules

### Per-pixel classification

For each pixel, examine all 4 binary layers:

1. **Single positive**: If exactly one layer is positive (value = 1), assign that crop class.
2. **Multiple positives**: If two or more layers are positive, the pixel is in conflict.
3. **No positives**: If all layers are 0, the pixel is classified as "no crop" (transparent).

### Conflict resolution — local spatial majority

When a pixel has multiple positive layers (e.g. both Maize and Winter Cereals are flagged):

1. Sample a local neighbourhood around the pixel (e.g. 3x3 or 5x5 kernel).
2. For each conflicting crop class, count how many neighbouring pixels are positive in that class's binary layer.
3. Assign the crop class with the **highest local count** (spatial majority).
4. If counts are tied, apply this priority order: Maize > Winter Cereals > Spring Cereals > Temporary Crops.

### Priority rationale

The priority order favours specific crop types over the generic "Temporary Crops" class, since Temporary Crops is a superset that includes all the others. When a pixel is flagged as both Maize and Temporary Crops, the more specific label (Maize) is preferred.

### Output classes

| Value | Class | Colour |
|-------|-------|--------|
| 0 | No crop (transparent) | — |
| 1 | Temporary Crops (only) | #E0181C |
| 2 | Maize | #FFD300 |
| 3 | Winter Cereals | #A87000 |
| 4 | Spring Cereals | #00A8E6 |

## Implementation Notes

- The majority map is generated on-device by compositing the 4 WMS tile responses.
- Each tile (256x256 px) is fetched from all 4 layers, then combined per-pixel.
- Conflict resolution uses the spatial majority within the tile itself.
- The result is cached as a single composite tile overlay.
- This approach avoids needing a server-side composite endpoint.

## Data Citation

Van Tricht, K., Degerickx, J., Gilliams, S., et al. (2023). WorldCereal: a dynamic open-source system for global-scale, seasonal, and reproducible crop and irrigation mapping. *Earth System Science Data*, 15, 5491–5515. DOI: 10.5194/essd-15-5491-2023.
