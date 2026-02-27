# ARCcrop

Interactive crop type map viewer for iOS. ARCcrop brings together over 30 crop mapping datasets from national agencies, space agencies, and research institutions into a single mobile application, letting users explore agricultural land use data from around the world on an interactive map.

## Features

- **30+ crop map datasets** spanning Global, North America, South America, Europe, and Oceania
- **Multi-layer support** -- overlay multiple crop maps simultaneously with independent opacity controls
- **Interactive legend** with per-class toggling -- tap any legend entry to show/hide that crop type on the map
- **Legend customisation** -- long-press a legend entry to rename classes or change colours
- **Opacity slider** -- per-layer transparency control (5%--100%)
- **Year navigation** -- stepper to browse multi-year datasets (e.g. USDA CDL 2008--2023)
- **Drag-to-reorder layers** -- reorder the layer stack by dragging legend tabs
- **Sync year across layers** -- optionally lock all active layers to the same year
- **Auto-best-map** -- automatically selects the highest-resolution dataset available at the current map location
- **Multiple base maps** -- Satellite, Standard, or No Base Map (solid dark background)
- **Political boundaries overlay** (LSIB)
- **OS field boundaries overlay** (UK, requires OS Data Hub API key)
- **Tile caching** -- configurable disk cache (default 2 GB, up to 5 GB) with persistent caching across sessions
- **PMTiles support** -- native reader for PMTiles v3 archives with MVT vector tile rasterisation
- **GEOGLAM embedded data** -- bundled global crop proportion rasters with on-device equirectangular-to-Mercator reprojection

## Data Sources

### Global

| Dataset | Provider | Resolution | Type | Years |
|---------|----------|-----------|------|-------|
| GEOGLAM Majority Crop | IIASA/GEOGLAM | ~5.6 km | Embedded raster (dominant crop) | 2022 |
| GEOGLAM Crop Proportions | IIASA/GEOGLAM | ~5.6 km | Embedded raster (% area per crop) | 2022 |
| ESA WorldCover | ESA/Copernicus | 10 m | WMS raster (11 land cover classes) | 2020--2021 |
| ESA WorldCereal | ESA/VITO | 10 m | WMS raster (crop type masks) | 2021 |
| GLAD Cropland | UMD/GLAD | 30 m | WMS raster (binary cropland) | 2003--2020 |
| Dynamic World | Google/WRI | 10 m | Near-realtime land use/land cover | 2018--2024 |
| Copernicus Land Cover | ESA/Copernicus | 100 m | Discrete land cover classification | 2015--2019 |
| FROM-GLC | Tsinghua University | 30 m | Land cover from Landsat/Sentinel | 2017--2020 |

### North America

| Dataset | Provider | Resolution | Type | Years |
|---------|----------|-----------|------|-------|
| USDA CDL | USDA NASS | 30 m | WMS raster (crop-specific land cover) | 2008--2023 |
| AAFC Canada | AAFC | 30 m | WMS raster (60+ crop classes) | 2009--2024 |

### South America

| Dataset | Provider | Resolution | Type | Years |
|---------|----------|-----------|------|-------|
| MapBiomas | MapBiomas | 30 m | Land use/land cover from Landsat | 2000--2022 |
| GeoINTA Argentina | INTA | 30 m | WMS raster (summer crop campaign) | 2024 |

### Europe -- Crop Type Maps

| Dataset | Provider | Resolution | Type | Years |
|---------|----------|-----------|------|-------|
| JRC EU Crop Map | JRC/EC | 10 m | WMS raster (19 crop types, EU-27 + Ukraine) | 2018--2022 |
| CROME England | Defra/RPA | ~20 m hex | WMS raster (hexagonal crop classification) | 2017--2024 |
| DLR CropTypes Germany | DLR EOC | 10 m | WMS raster (18 crop types) | 2023 |
| RPG France | IGN/ASP | Parcels | WMS vector (28+ crop groups) | 2024 |
| BRP Netherlands | RVO/PDOK | Parcels | WMS vector (parcel-level crop declarations) | 2024 |

### Europe -- Parcel / Field Block Maps

| Dataset | Provider | Country | Type |
|---------|----------|---------|------|
| INVEKOS Austria | AMA/LFRZ | Austria | WMS parcels |
| ALV Flanders | Vlaanderen | Belgium (Flanders) | WMS parcels |
| SIGPAC Spain | FEGA/MAPA | Spain | WMS parcels |
| FVM Denmark | LBST | Denmark | WMS fields |
| LPIS Czechia | MZe | Czechia | WMS parcels |
| GERK Slovenia | MKGP | Slovenia | WMS parcels |
| ARKOD Croatia | APPRRR | Croatia | WMS parcels |
| GSAA Estonia | PRIA | Estonia | WMS fields |
| Latvia Field Blocks | LAD | Latvia | WMS field blocks |
| IFAP Portugal | IFAP | Portugal | WMS parcels |
| LPIS Poland | ARiMR | Poland | WMS parcels |
| Jordbruk Sweden | SJV | Sweden | WMS field blocks |
| FLIK Luxembourg | ASTA | Luxembourg | WMS parcels |
| BLW Switzerland | BLW | Switzerland | WMS parcels |

### Oceania

| Dataset | Provider | Resolution | Type |
|---------|----------|-----------|------|
| ABARES Australia | ABARES | Land Use | WMS (Catchment Scale Land Use) |
| LCDB New Zealand | MWLR | Land Cover | WMS (33 land cover classes) |

## API Keys

Most datasets are freely accessible without authentication. The following require API credentials:

| Provider | Datasets | Credential Type |
|----------|----------|----------------|
| Google Earth Engine | Dynamic World, FROM-GLC, MapBiomas | Service account JSON |
| Copernicus Data Space | Copernicus Land Cover | Username + password |
| OS Data Hub | OS Field Boundaries (UK) | API key |

Credentials are stored securely in the iOS Keychain.

## Architecture

ARCcrop is a native Swift/SwiftUI application targeting iOS. Key architectural components:

- **WMSTileOverlay** -- `MKTileOverlay` subclass that constructs OGC WMS GetMap URLs from tile coordinates, supporting both EPSG:3857 and EPSG:4326, WMS 1.1.1 and 1.3.0
- **FilteredTileOverlay** -- pixel-level filtering to hide specific crop classes by matching RGB values in downloaded tiles
- **BoundedWMSTileOverlay** -- geographic bounds checking to avoid unnecessary tile requests outside a dataset's coverage area
- **PMTileOverlay** -- native PMTiles v3 reader with Hilbert curve tile ID computation, protobuf MVT decoding, and on-the-fly rasterisation
- **GEOGLAMOverlayManager** -- loads bundled PNG rasters and reprojects from equirectangular (EPSG:4326) to Web Mercator (EPSG:3857) using nearest-neighbour interpolation
- **CropMapLegendData** -- static legend definitions with official colour palettes for each dataset
- **AppSettings** -- observable settings model with UserDefaults persistence for layer state, opacity, cache size, and legend overrides

## Requirements

- iOS 18.0+
- Xcode 16.0+

## License

See individual dataset providers for data licensing terms. The PDOK BRP Netherlands dataset is CC0. Most European INSPIRE WMS services are provided under open government data licences.
