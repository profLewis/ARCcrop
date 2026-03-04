# ARCcrop

Interactive crop type map viewer for iOS and web. ARCcrop brings together 35+ crop mapping datasets from national agencies, space agencies, and research institutions into a single application, letting users explore agricultural land use data from around the world on an interactive map.

## Features

- **35+ crop map datasets** spanning Global, North America, South America, Europe, Africa, and Oceania
- **Multi-layer support** -- overlay multiple crop maps simultaneously with independent opacity controls
- **Interactive legend** with per-class toggling -- tap any legend entry to show/hide that crop type on the map
- **Legend customisation** -- long-press a legend entry to rename classes or change colours
- **Opacity slider** -- per-layer transparency control (5%--100%)
- **Year navigation** -- stepper to browse multi-year datasets (e.g. USDA CDL 2008--2023, CROME 2017--2024)
- **Drag-to-reorder layers** -- reorder the layer stack by dragging legend tabs
- **Sync year across layers** -- optionally lock all active layers to the same year
- **Auto-best-map** -- automatically selects the highest-resolution dataset available at the current map location
- **Multiple base maps** -- Satellite, Standard, or No Base Map (solid dark background)
- **Political boundaries overlay** (LSIB)
- **FTW field boundaries overlay** ([Fields of The World](https://fieldsofthe.world/), 1.6M boundaries, 24 countries)
- **OS field boundaries overlay** (UK, requires OS Data Hub API key)
- **FAO Crop Calendar** -- dynamic crop calendar lookups for 400+ crops, 60 countries, with AEZ zones; supports 6 languages (en/fr/es/ar/zh/ru)
- **Tile caching** -- configurable disk cache (default 2 GB, up to 5 GB) with persistent caching across sessions
- **PMTiles support** -- native reader for PMTiles v3 archives with MVT vector tile rasterisation
- **PMTiles overview tiles** -- pre-built raster overviews for parcel datasets that only render at high zoom, enabling useful low-zoom views
- **GEOGLAM embedded data** -- bundled global crop proportion rasters with on-device equirectangular-to-Mercator reprojection
- **Web preview** -- self-contained HTML preview (`preview.html`) with all datasets, legends, class toggle filtering, year selection, and diagnostics

## Web Preview

Open `preview.html` in any browser for a full interactive preview of all datasets. Features include:

- All 35+ datasets accessible from a sidebar
- Interactive legends with per-class toggling (pixel-level "keep mode" filtering)
- Year slider for multi-year datasets
- PMTiles overview tiles for parcel datasets at low zoom
- Diagnostics bar showing zoom level, scale, tile info, and source type
- CROME datasets served from dedicated [PMTiles viewer](https://proflewis.github.io/crome-work/)

## Data Sources

### Data Serving Architecture

Datasets are served from multiple sources depending on availability and performance:

| Method | Description | Used By |
|--------|-------------|---------|
| **WMS (OGC)** | Live Web Map Service tiles from authoritative endpoints | Most datasets |
| **PMTiles overview + WMS** | Pre-built raster overview tiles at low zoom (from [crome-maps](https://github.com/profLewis/crome-maps)), WMS at high zoom | NL, BE, AT, DK, NO, LU, PT |
| **PMTiles (standalone)** | Full PMTiles archives served via HTTP range requests | DEA Africa, DEA Australia, NZ LCDB, CROME |
| **ArcGIS tiles** | XYZ raster tiles from ArcGIS tile servers | GLAD, ABARES |
| **WMTS** | OGC Web Map Tile Service | Copernicus LC100 |
| **Bundled rasters** | PNG rasters embedded in the iOS app | GEOGLAM |

PMTiles overview files are hosted in the [crome-maps](https://github.com/profLewis/crome-maps) repository via GitHub LFS.

### Global

| Dataset | Provider | Resolution | Years | WMS/Source | Licence | Original Source |
|---------|----------|-----------|-------|------------|---------|-----------------|
| GEOGLAM Majority Crop | IIASA/GEOGLAM | ~5.6 km | 2022 | Bundled rasters | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [Zenodo DOI: 10.5281/zenodo.7230863](https://doi.org/10.5281/zenodo.7230863) |
| GEOGLAM Crop Proportions | IIASA/GEOGLAM | ~5.6 km | 2022 | Bundled rasters | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [Zenodo DOI: 10.5281/zenodo.7230863](https://doi.org/10.5281/zenodo.7230863) |
| ESA WorldCover | ESA/Copernicus | 10 m | 2020--2021 | `services.terrascope.be` WMS | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [worldcover2021.esa.int](https://worldcover2021.esa.int/) |
| ESA WorldCereal | ESA/VITO | 10 m | 2021 | `services.terrascope.be` WMS | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [esa-worldcereal.org](https://esa-worldcereal.org/) |
| MODIS Land Cover | NASA/USGS | 500 m | 2001--2022 | `gibs.earthdata.nasa.gov` WMS | Public domain | [earthdata.nasa.gov](https://earthdata.nasa.gov/) |
| Copernicus Land Cover 100m | ESA/Copernicus/VITO | 100 m | 2015--2019 | `land.copernicus.eu` WMTS | [Copernicus free & open](https://land.copernicus.eu/en/data-policy) | [land.copernicus.eu](https://land.copernicus.eu/en/products/global-dynamic-land-cover) |
| CORINE Land Cover | EEA/Copernicus | 100 m | 2000, 2006, 2012, 2018 | `image.discomap.eea.europa.eu` WMS | [Copernicus free & open](https://land.copernicus.eu/en/data-policy) | [land.copernicus.eu](https://land.copernicus.eu/en/products/corine-land-cover) |
| Dynamic World | Google/WRI | 10 m | 2018--2024 | Google Earth Engine | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). **Requires GEE key.** | [dynamicworld.app](https://dynamicworld.app/) |
| FROM-GLC | Tsinghua University | 30 m | 2017--2020 | Google Earth Engine | Free for research. **Requires GEE key.** | [data.tsinghua.edu.cn](http://data.ess.tsinghua.edu.cn/) |
| GLAD Land Cover | UMD/GLAD | 10 m | 2019--2021 | `tiles.arcgis.com` XYZ | Public (ArcGIS Living Atlas) | [glad.umd.edu](https://glad.umd.edu/) |
| GFSAD Global Croplands | USGS/NASA | 30 m | 2000 | `gibs.earthdata.nasa.gov` WMS | Public domain | [croplands.org](https://croplands.org/) |
| Fields of The World (FTW) | Kerner Lab / Radiant Earth | Vector | 2024 | Direct tile service | Mixed per-country | [fieldsofthe.world](https://fieldsofthe.world/) |

### North America

| Dataset | Provider | Resolution | Years | WMS/Source | Licence | Original Source |
|---------|----------|-----------|-------|------------|---------|-----------------|
| USDA CDL | USDA NASS | 30 m | 2008--2023 | `nassgeodata.gmu.edu` WMS (EPSG:4326) | Public domain (US Government) | [CropScape](https://nassgeodata.gmu.edu/CropScape/) |
| AAFC Canada | Agriculture & Agri-Food Canada | 30 m | 2009--2024 | `agr.gc.ca` WMS | [Open Government Licence -- Canada](https://open.canada.ca/en/open-government-licence-canada) | [open.canada.ca](https://open.canada.ca/data/en/dataset/ba2645d5-4458-414d-b196-6303ac06c1c9) |

### South America

| Dataset | Provider | Resolution | Years | WMS/Source | Licence | Original Source |
|---------|----------|-----------|-------|------------|---------|-----------------|
| MapBiomas | MapBiomas Network | 30 m | 2000--2022 | Google Earth Engine | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). **Requires GEE key.** | [mapbiomas.org](https://mapbiomas.org/) |
| GeoINTA Argentina | INTA | 30 m | 2024 | `geointa.inta.gob.ar` WMS | Open access | [geointa.inta.gob.ar](https://geointa.inta.gob.ar/) |

### Europe -- Crop Type Maps

| Dataset | Provider | Resolution | Years | WMS/Source | Licence | Original Source |
|---------|----------|-----------|-------|------------|---------|-----------------|
| JRC EU Crop Map | JRC/European Commission | 10 m | 2018--2022 | `jeodpp.jrc.ec.europa.eu` WMS | [Commission Decision 2011/833/EU](https://commission.europa.eu/legal-notice_en) | [JRC Publications](https://publications.jrc.ec.europa.eu/repository/handle/JRC134889) |
| CROME England | Defra/RPA | ~20 m hex | 2017--2024 | PMTiles via [crome-work](https://proflewis.github.io/crome-work/) | [OGL v3](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) | [environment.data.gov.uk](https://environment.data.gov.uk/dataset/bb4dfa19-26bc-46d0-98e8-c977e6921619) |
| DLR CropTypes Germany | DLR EOC | 10 m | 2023 | `geoservice.dlr.de` WMS | [DLR EOC Terms](https://geoservice.dlr.de/web/datapolicy) | [geoservice.dlr.de](https://geoservice.dlr.de/web/maps/eoc:croptypes) |
| RPG France | IGN/ASP | Parcels | 2024 | `data.geopf.fr` WMS | [Licence Ouverte 2.0](https://www.etalab.gouv.fr/licence-ouverte-open-licence/) | [geoservices.ign.fr](https://geoservices.ign.fr/rpg) |
| BRP Netherlands | RVO/PDOK | Parcels | 2024 | `service.pdok.nl` WMS + PMTiles overview (718 MB) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | [pdok.nl](https://www.pdok.nl/introductie/-/article/brpgewaspercelen) |

### Europe -- Parcel / Field Block Maps

| Dataset | Provider | Country | WMS/Source | Licence | Original Source |
|---------|----------|---------|------------|---------|-----------------|
| INVEKOS | AMA/LFRZ | Austria | `inspire.lfrz.gv.at` WMS + PMTiles overview (414 MB) | [CC BY 4.0 AT](https://creativecommons.org/licenses/by/4.0/deed.de) | [geometadatensuche.inspire.gv.at](https://geometadatensuche.inspire.gv.at/) |
| ALV Flanders | Digitaal Vlaanderen | Belgium (Flanders) | `geo.api.vlaanderen.be` WMS + PMTiles overview | [Modellicentie Gratis Hergebruik](https://overheid.vlaanderen.be/modellicenties-gratis-hergebruik) | [geopunt.be](https://www.geopunt.be/) |
| Wallonia SIGEC | SPW Wallonia | Belgium (Wallonia) | `geoservices.wallonie.be` WMS + PMTiles overview (48 MB) | Open government data | [geoportail.wallonie.be](https://geoportail.wallonie.be/) |
| FVM Denmark | LBST | Denmark | `geodata.fvm.dk` WMS + PMTiles overview | [Danish Open Government Licence](https://data.gov.dk/) | [geodata.fvm.dk](https://geodata.fvm.dk/) |
| NIBIO AR5 | NIBIO | Norway | `wms.nibio.no` WMS + PMTiles overview | Open government data | [nibio.no](https://www.nibio.no/) |
| FLIK Luxembourg | ASTA / Geoportal.lu | Luxembourg | `wms.inspire.geoportail.lu` WMS + PMTiles overview (51 MB) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | [data.public.lu](https://data.public.lu/) |
| IFAP Portugal | IFAP | Portugal | `ifap.pt` WMS + PMTiles overview | [INSPIRE](https://inspire.ec.europa.eu/) | [ifap.pt](https://www.ifap.pt/) |
| BLW Switzerland | BLW | Switzerland | `wms.geo.admin.ch` WMS | [Open Government Data CH](https://opendata.swiss/) | [map.geo.admin.ch](https://map.geo.admin.ch/) |
| SIGPAC Spain | FEGA/MAPA | Spain | `wms.mapa.gob.es` WMS | Open government data | [sigpac.mapa.gob.es](https://sigpac.mapa.gob.es/fega/visor/) |
| LPIS Czechia | MZe | Czechia | `mze.gov.cz` WMS | Open government data | [eagri.cz](https://eagri.cz/public/web/mze/farmar/LPIS/) |
| GERK Slovenia | MKGP | Slovenia | `storitve.eprostor.gov.si` WMS | [INSPIRE](https://inspire.ec.europa.eu/) | [eprostor.gov.si](https://eprostor.gov.si/) |
| ARKOD Croatia | APPRRR | Croatia | `servisi.apprrr.hr` WMS | Open government data | [preglednik.arkod.hr](https://preglednik.arkod.hr/) |
| GSAA Estonia | PRIA | Estonia | `kls.pria.ee` WMS (EPSG:4326) | [INSPIRE](https://inspire.ec.europa.eu/) | [kls.pria.ee](https://kls.pria.ee/) |
| Latvia Field Blocks | LAD | Latvia | `karte.lad.gov.lv` WMS (EPSG:4326) | Open government data | [karte.lad.gov.lv](https://karte.lad.gov.lv/) |
| LPIS Poland | ARiMR/GUGiK | Poland | `mapy.geoportal.gov.pl` WMS | Open government data | [geoportal.gov.pl](https://mapy.geoportal.gov.pl/) |
| Jordbruk Sweden | SJV | Sweden | `epub.sjv.se` WMS (EPSG:4326) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | [jordbruksverket.se](https://jordbruksverket.se/) |

### Africa

| Dataset | Provider | Resolution | Years | WMS/Source | Licence | Original Source |
|---------|----------|-----------|-------|------------|---------|-----------------|
| DE Africa Cropland | Digital Earth Africa | 10 m | 2021 | `ows.digitalearth.africa` WMS + PMTiles (97 MB) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [digitalearthafrica.org](https://www.digitalearthafrica.org/) |

### Oceania

| Dataset | Provider | Resolution | Years | WMS/Source | Licence | Original Source |
|---------|----------|-----------|-------|------------|---------|-----------------|
| DEA Land Cover | Geoscience Australia | 25 m | 2018--2020 | `ows.dea.ga.gov.au` WMS + PMTiles (278 MB) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [dea.ga.gov.au](https://www.dea.ga.gov.au/) |
| ABARES Land Use | ABARES | ~50 m | 2023 | `di-daa.img.arcgis.com` WMS | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [agriculture.gov.au](https://www.agriculture.gov.au/abares/aclump/catchment-scale-land-use) |
| LCDB v6 New Zealand | Manaaki Whenua | 15 m | 2023--2024 | `maps.scinfo.org.nz` WMS + PMTiles (32 MB) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [lris.scinfo.org.nz](https://lris.scinfo.org.nz/layer/104400-lcdb-v60-land-cover-database-version-60/) |

### FAO Crop Calendar

The app integrates with the [FAO Crop Calendar API](https://cropcalendar.apps.fao.org/) (v1), providing planting and harvest dates for **400+ crops** across **60 countries** with per-country **Agro-Ecological Zone (AEZ)** breakdowns. Data is available in 6 languages: English, French, Spanish, Arabic, Chinese, and Russian. No authentication is required.

Additional embedded crop calendar sources:
- **SAGE** (Sacks et al.) -- 0.5 degree grid, 15 crops. [DOI: 10.1111/j.1466-8238.2010.00551.x](https://doi.org/10.1111/j.1466-8238.2010.00551.x)
- **GEOGLAM CM4EW** -- Sub-national calendars, 8 crops. [crop-monitor.org](https://cropmonitor.org/)

## PMTiles Overview Tiles

Several European parcel datasets only render their WMS data at high zoom levels (z13--z14), making low-zoom navigation impractical. To solve this, pre-built raster overview PMTiles archives provide downsampled tile pyramids from the native WMS data:

| Dataset | File | Size | Zoom Range | Source WMS |
|---------|------|------|------------|------------|
| BRP Netherlands | `brp-overview.pmtiles` | 718 MB | z7--z14 | `service.pdok.nl` |
| INVEKOS Austria | `invekos-overview.pmtiles` | 414 MB | z7--z13 | `inspire.lfrz.gv.at` |
| ALV Flanders | `alv-overview.pmtiles` | 71 MB | z8--z14 | `geo.api.vlaanderen.be` |
| Wallonia SIGEC | `wallonia-overview.pmtiles` | 48 MB | z8--z14 | `geoservices.wallonie.be` |
| FLIK Luxembourg | `flik-overview.pmtiles` | 51 MB | z9--z14 | `wms.inspire.geoportail.lu` |
| NIBIO Norway | `nibio-overview.pmtiles` | ~TBD | z7--z14 | `wms.nibio.no` |
| FVM Denmark | `fvm-overview.pmtiles` | ~TBD | z7--z14 | `geodata.fvm.dk` |
| IFAP Portugal | `portugal-overview.pmtiles` | 160 MB | z7--z14 | `ifap.pt` |

These are built using `build_overview_pmtiles.py`, which downloads WMS tiles at the native data zoom, creates downsampled overviews using nearest-neighbour resampling, packages as MBTiles, and converts to PMTiles using the `pmtiles` CLI.

All overview PMTiles are hosted in the [crome-maps](https://github.com/profLewis/crome-maps) repository via GitHub LFS and served via HTTP range requests.

## API Keys

Most datasets are freely accessible without authentication. The following require API credentials:

| Provider | Datasets | Credential Type | Registration |
|----------|----------|----------------|--------------|
| Google Earth Engine | Dynamic World, FROM-GLC, MapBiomas | Service account JSON key | [code.earthengine.google.com/register](https://code.earthengine.google.com/register) |
| Copernicus Data Space | Copernicus Land Cover | Username + password | [dataspace.copernicus.eu](https://identity.dataspace.copernicus.eu/) |
| OS Data Hub | OS Field Boundaries (UK) | API key | [osdatahub.os.uk](https://osdatahub.os.uk/) |

Credentials are stored securely in the iOS Keychain.

## Copyright and Attribution

All datasets accessed through ARCcrop remain the intellectual property of their respective providers. Users must comply with each dataset's licensing terms. Key references:

- **GEOGLAM**: Becker-Reshef, I. et al. (2023). Best Available Cropland Masks. *Zenodo*. [DOI: 10.5281/zenodo.7230863](https://doi.org/10.5281/zenodo.7230863)
- **ESA WorldCover**: Zanaga, D. et al. (2022). ESA WorldCover 10m 2021 v200. [DOI: 10.5281/zenodo.7254221](https://doi.org/10.5281/zenodo.7254221). Copyright ESA/Copernicus.
- **ESA WorldCereal**: Van Tricht, K. et al. (2023). WorldCereal. *Earth System Science Data*, 15(12). [DOI: 10.5194/essd-15-5491-2023](https://doi.org/10.5194/essd-15-5491-2023). Copyright ESA/VITO.
- **Dynamic World**: Brown, C.F. et al. (2022). Dynamic World. *Scientific Data*, 9(1), 251. [DOI: 10.1038/s41597-022-01307-4](https://doi.org/10.1038/s41597-022-01307-4). Copyright Google/WRI.
- **JRC EU Crop Map**: d'Andrimont, R. et al. (2021). First European crop type map. *Remote Sensing of Environment*, 266. [DOI: 10.1016/j.rse.2021.112708](https://doi.org/10.1016/j.rse.2021.112708). Copyright European Commission JRC.
- **CORINE Land Cover**: Copyright EEA/Copernicus Land Monitoring Service.
- **MODIS Land Cover**: Friedl, M.A. et al. MCD12Q1 MODIS/Terra+Aqua Land Cover Type. [DOI: 10.5067/MODIS/MCD12Q1.061](https://doi.org/10.5067/MODIS/MCD12Q1.061). Public domain (NASA/USGS).
- **USDA CDL**: USDA NASS Cropland Data Layer. Public domain (US Government). [nass.usda.gov](https://www.nass.usda.gov/Research_and_Science/Cropland/SARS1a.php)
- **AAFC**: Agriculture and Agri-Food Canada Annual Crop Inventory. Open Government Licence -- Canada.
- **CROME**: Crown copyright (Defra/RPA), Open Government Licence v3.
- **DLR CropTypes**: Copyright DLR (German Aerospace Center), Earth Observation Center.
- **RPG France**: Licence Ouverte 2.0, IGN/ASP.
- **BRP Netherlands**: CC0, Rijksdienst voor Ondernemend Nederland (RVO).
- **NIBIO AR5**: Copyright NIBIO (Norwegian Institute of Bioeconomy Research).
- **FVM Denmark**: Danish Open Government Licence, Landbrugsstyrelsen.
- **INVEKOS Austria**: CC BY 4.0 AT, Agrarmarkt Austria.
- **ALV Flanders**: Modellicentie Gratis Hergebruik, Digitaal Vlaanderen.
- **Wallonia SIGEC**: Open government data, Service Public de Wallonie.
- **Digital Earth Africa**: CC BY 4.0.
- **DEA Land Cover**: CC BY 4.0, Geoscience Australia.
- **LCDB New Zealand**: CC BY 4.0, Manaaki Whenua / Landcare Research.
- **Fields of The World**: Kerner, H. et al. (2024). [arXiv: 2409.16252](https://arxiv.org/abs/2409.16252)
- **SAGE Crop Calendar**: Sacks, W.J. et al. (2010). *Global Ecology and Biogeography*, 19(5). [DOI: 10.1111/j.1466-8238.2010.00551.x](https://doi.org/10.1111/j.1466-8238.2010.00551.x)
- **FAO Crop Calendar**: [cropcalendar.apps.fao.org](https://cropcalendar.apps.fao.org/). Copyright FAO.

European parcel datasets (INVEKOS, ALV, FVM, GSAA, GERK, ARKOD, FLIK, LPIS, etc.) are provided under national open government data licences or [INSPIRE](https://inspire.ec.europa.eu/) directive requirements. The INSPIRE directive requires EU member states to make spatial data available for environmental policy purposes.

## Architecture

ARCcrop is a native Swift/SwiftUI application targeting iOS, with MapLibre Native for map rendering. Key architectural components:

- **WMSTileURLProtocol** -- NSURLProtocol subclass that intercepts tile requests to construct OGC WMS GetMap URLs, supporting EPSG:3857 and EPSG:4326, WMS 1.1.1 and 1.3.0
- **FilteredTileOverlay** -- pixel-level "keep mode" filtering that retains visible crop classes by matching RGB values within a Manhattan distance threshold, zeroing alpha for non-matching pixels
- **PMTilesURLProtocol** -- NSURLProtocol that serves tiles from bundled PMTiles v3 archives via Hilbert curve tile ID computation and gunzip decompression
- **PMTilesSource** -- native PMTiles v3 reader with protobuf MVT decoding and on-the-fly rasterisation for vector tiles
- **GEOGLAMOverlayManager** -- loads bundled PNG rasters and reprojects from equirectangular (EPSG:4326) to Web Mercator (EPSG:3857) using nearest-neighbour interpolation
- **CropMapLegendData** -- static legend definitions with official colour palettes for 20+ datasets
- **FAOCropCalendarService** -- dynamic REST client for the FAO Crop Calendar API with language support, caching, and AEZ zone queries
- **AppSettings** -- observable settings model with UserDefaults persistence for layer state, opacity, cache size, and legend overrides

### Web Preview Architecture

`preview.html` is a self-contained HTML file using Leaflet.js and PMTiles.js:

- **Standard WMS layers** via Leaflet's `L.tileLayer.wms`
- **Filtered layers** via custom `L.GridLayer` that fetches WMS tiles to canvas, reads pixel data, and filters by Manhattan distance to visible legend colours
- **PMTiles layers** via `pmtiles.js` library reading byte ranges from GitHub-hosted PMTiles archives
- **Combined PMTiles + WMS** for parcel datasets: overview PMTiles at low zoom, live WMS at high zoom

## Requirements

- iOS 18.0+
- Xcode 16.0+

## Licence

The ARCcrop application code is provided as-is. Individual datasets are subject to their own licensing terms as listed in the tables above. Most European parcel datasets are provided under open government or INSPIRE licences. Users are responsible for complying with the terms of each data provider when using the data accessed through this application.

Copyright notices for individual datasets must be preserved when redistributing or displaying data obtained through this application.
