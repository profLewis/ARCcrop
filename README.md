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
- **FTW field boundaries overlay** ([Fields of The World](https://fieldsofthe.world/), 1.6M boundaries, 24 countries)
- **OS field boundaries overlay** (UK, requires OS Data Hub API key)
- **FAO Crop Calendar** -- dynamic crop calendar lookups for 400+ crops, 60 countries, with AEZ zones; supports 6 languages (en/fr/es/ar/zh/ru)
- **Tile caching** -- configurable disk cache (default 2 GB, up to 5 GB) with persistent caching across sessions
- **PMTiles support** -- native reader for PMTiles v3 archives with MVT vector tile rasterisation
- **GEOGLAM embedded data** -- bundled global crop proportion rasters with on-device equirectangular-to-Mercator reprojection

## Data Sources

### Global

| Dataset | Provider | Resolution | Years | Licence / Access | Link |
|---------|----------|-----------|-------|------------------|------|
| GEOGLAM Majority Crop | IIASA/GEOGLAM | ~5.6 km | 2022 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [Zenodo (DOI: 10.5281/zenodo.7230863)](https://doi.org/10.5281/zenodo.7230863) |
| GEOGLAM Crop Proportions | IIASA/GEOGLAM | ~5.6 km | 2022 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [Zenodo (DOI: 10.5281/zenodo.7230863)](https://doi.org/10.5281/zenodo.7230863) |
| ESA WorldCover | ESA/Copernicus | 10 m | 2020--2021 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [worldcover2021.esa.int](https://worldcover2021.esa.int/) |
| ESA WorldCereal | ESA/VITO | 10 m | 2021 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | [esa-worldcereal.org](https://esa-worldcereal.org/) |
| Dynamic World | Google/WRI | 10 m | 2018--2024 | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). **Requires Google Earth Engine service account.** | [dynamicworld.app](https://dynamicworld.app/) |
| Copernicus Land Cover | ESA/Copernicus | 100 m | 2015--2019 | [Copernicus free & open](https://land.copernicus.eu/en/data-policy). **Requires Copernicus Data Space login.** | [land.copernicus.eu](https://land.copernicus.eu/en/products/global-dynamic-land-cover) |
| FROM-GLC | Tsinghua University | 30 m | 2017--2020 | Free for research. **Requires Google Earth Engine service account.** | [data.tsinghua.edu.cn](http://data.ess.tsinghua.edu.cn/) |
| Fields of The World (FTW) | Kerner Lab / Radiant Earth | Vector | 2024 | Mixed per-country (see `license` field in data). No auth required. | [fieldsofthe.world](https://fieldsofthe.world/) |

### North America

| Dataset | Provider | Resolution | Years | Licence / Access | Link |
|---------|----------|-----------|-------|------------------|------|
| USDA CDL | USDA NASS | 30 m | 2008--2023 | Public domain (US Government). No auth required. | [nassgeodata.gmu.edu/CropScape](https://nassgeodata.gmu.edu/CropScape/) |
| AAFC Canada | Agriculture & Agri-Food Canada | 30 m | 2009--2024 | [Open Government Licence -- Canada](https://open.canada.ca/en/open-government-licence-canada). No auth required. | [open.canada.ca](https://open.canada.ca/data/en/dataset/ba2645d5-4458-414d-b196-6303ac06c1c9) |

### South America

| Dataset | Provider | Resolution | Years | Licence / Access | Link |
|---------|----------|-----------|-------|------------------|------|
| MapBiomas | MapBiomas Network | 30 m | 2000--2022 | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). **Requires Google Earth Engine service account.** | [mapbiomas.org](https://mapbiomas.org/) |
| GeoINTA Argentina | INTA | 30 m | 2024 | Open access. No auth required. | [geointa.inta.gob.ar](https://geointa.inta.gob.ar/) |

### Europe -- Crop Type Maps

| Dataset | Provider | Resolution | Years | Licence / Access | Link |
|---------|----------|-----------|-------|------------------|------|
| JRC EU Crop Map | JRC/European Commission | 10 m | 2018--2022 | [Reuse policy (Commission Decision 2011/833/EU)](https://commission.europa.eu/legal-notice_en). No auth required. | [publications.jrc.ec.europa.eu](https://publications.jrc.ec.europa.eu/repository/handle/JRC134889) |
| CROME England | Defra/RPA | ~20 m hex | 2017--2024 | [OGL v3](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/). No auth required. | [environment.data.gov.uk](https://environment.data.gov.uk/dataset/bb4dfa19-26bc-46d0-98e8-c977e6921619) |
| DLR CropTypes Germany | DLR EOC | 10 m | 2023 | [DLR EOC Geoservice Terms](https://geoservice.dlr.de/web/datapolicy). No auth required. | [geoservice.dlr.de](https://geoservice.dlr.de/web/maps/eoc:croptypes) |
| RPG France | IGN/ASP | Parcels | 2024 | [Licence Ouverte / Open Licence 2.0](https://www.etalab.gouv.fr/licence-ouverte-open-licence/). No auth required. | [geoservices.ign.fr](https://geoservices.ign.fr/rpg) |
| BRP Netherlands | RVO/PDOK | Parcels | 2024 | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). No auth required. | [pdok.nl](https://www.pdok.nl/introductie/-/article/brpgewaspercelen) |

### Europe -- Parcel / Field Block Maps

| Dataset | Provider | Country | Licence / Access | Link |
|---------|----------|---------|------------------|------|
| INVEKOS Austria | AMA/LFRZ | Austria | [CC BY 4.0 AT](https://creativecommons.org/licenses/by/4.0/deed.de). No auth required. | [inspire.lfrz.gv.at](https://geometadatensuche.inspire.gv.at/) |
| ALV Flanders | Digitaal Vlaanderen | Belgium (Flanders) | [Modellicentie Gratis Hergebruik](https://overheid.vlaanderen.be/modellicenties-gratis-hergebruik). No auth required. | [geopunt.be](https://www.geopunt.be/) |
| SIGPAC Spain | FEGA/MAPA | Spain | Open government data. No auth required. | [sigpac.mapa.gob.es](https://sigpac.mapa.gob.es/fega/visor/) |
| FVM Denmark | LBST (Danish Agricultural Agency) | Denmark | [Danish Open Government Licence](https://data.gov.dk/). No auth required. | [geodata.fvm.dk](https://geodata.fvm.dk/) |
| LPIS Czechia | MZe (Ministry of Agriculture) | Czechia | Open government data. No auth required. | [eagri.cz](https://eagri.cz/public/web/mze/farmar/LPIS/) |
| GERK Slovenia | MKGP | Slovenia | [INSPIRE](https://inspire.ec.europa.eu/). No auth required. | [eprostor.gov.si](https://eprostor.gov.si/) |
| ARKOD Croatia | APPRRR | Croatia | Open government data. No auth required. | [preglednik.arkod.hr](https://preglednik.arkod.hr/) |
| GSAA Estonia | PRIA | Estonia | [INSPIRE](https://inspire.ec.europa.eu/). No auth required. | [kls.pria.ee](https://kls.pria.ee/) |
| Latvia Field Blocks | LAD (Rural Support Service) | Latvia | Open government data. No auth required. | [karte.lad.gov.lv](https://karte.lad.gov.lv/) |
| IFAP Portugal | IFAP | Portugal | [INSPIRE](https://inspire.ec.europa.eu/). No auth required. | [ifap.pt](https://www.ifap.pt/) |
| LPIS Poland | ARiMR/GUGiK | Poland | Open government data. No auth required. | [geoportal.gov.pl](https://mapy.geoportal.gov.pl/) |
| Jordbruk Sweden | SJV (Jordbruksverket) | Sweden | [Creative Commons Zero](https://creativecommons.org/publicdomain/zero/1.0/). No auth required. | [jordbruksverket.se](https://jordbruksverket.se/) |
| FLIK Luxembourg | ASTA / Geoportal.lu | Luxembourg | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). No auth required. | [geoportail.lu](https://data.public.lu/) |
| BLW Switzerland | BLW (Federal Office for Agriculture) | Switzerland | [Open Government Data Switzerland](https://opendata.swiss/). No auth required. | [map.geo.admin.ch](https://map.geo.admin.ch/) |

### Oceania

| Dataset | Provider | Resolution | Licence / Access | Link |
|---------|----------|-----------|------------------|------|
| ABARES Australia | Dept of Agriculture | Land Use | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). No auth required. | [agriculture.gov.au](https://www.agriculture.gov.au/abares/aclump/catchment-scale-land-use) |
| LCDB New Zealand | Manaaki Whenua / Landcare Research | 33 classes | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). No auth required. | [lris.scinfo.org.nz](https://lris.scinfo.org.nz/layer/104400-lcdb-v60-land-cover-database-version-60/) |

### FAO Crop Calendar

The app integrates with the [FAO Crop Calendar API](https://cropcalendar.apps.fao.org/) (v1), providing planting and harvest dates for **400+ crops** across **60 countries** with per-country **Agro-Ecological Zone (AEZ)** breakdowns. Data is available in 6 languages: English, French, Spanish, Arabic, Chinese, and Russian. No authentication is required.

Additional embedded crop calendar sources:
- **SAGE** (Sacks et al.) -- 0.5 degree grid, 15 crops. [DOI: 10.1111/j.1466-8238.2010.00551.x](https://doi.org/10.1111/j.1466-8238.2010.00551.x)
- **GEOGLAM CM4EW** -- Sub-national calendars, 8 crops. [crop-monitor.org](https://cropmonitor.org/)

## API Keys

Most datasets are freely accessible without authentication. The following require API credentials:

| Provider | Datasets | Credential Type | Registration |
|----------|----------|----------------|--------------|
| Google Earth Engine | Dynamic World, FROM-GLC, MapBiomas | Service account JSON key | [code.earthengine.google.com/register](https://code.earthengine.google.com/register) |
| Copernicus Data Space | Copernicus Land Cover | Username + password | [dataspace.copernicus.eu](https://identity.dataspace.copernicus.eu/) |
| OS Data Hub | OS Field Boundaries (UK) | API key | [osdatahub.os.uk](https://osdatahub.os.uk/) |

Credentials are stored securely in the iOS Keychain.

## Attribution

If you use ARCcrop or the datasets it provides access to, please cite the original data providers. Key references:

- **GEOGLAM**: Becker-Reshef, I. et al. (2023). Best Available Cropland Masks. *Zenodo*. [DOI: 10.5281/zenodo.7230863](https://doi.org/10.5281/zenodo.7230863)
- **ESA WorldCover**: Zanaga, D. et al. (2022). ESA WorldCover 10m 2021 v200. [DOI: 10.5281/zenodo.7254221](https://doi.org/10.5281/zenodo.7254221)
- **ESA WorldCereal**: Van Tricht, K. et al. (2023). WorldCereal: a dynamic open-source system for global-scale, seasonal, and reproducible crop and irrigation mapping. *Earth System Science Data*, 15(12). [DOI: 10.5194/essd-15-5491-2023](https://doi.org/10.5194/essd-15-5491-2023)
- **Dynamic World**: Brown, C.F. et al. (2022). Dynamic World, Near real-time global 10 m land use land cover mapping. *Scientific Data*, 9(1), 251. [DOI: 10.1038/s41597-022-01307-4](https://doi.org/10.1038/s41597-022-01307-4)
- **JRC EU Crop Map**: d'Andrimont, R. et al. (2021). From parcel to continental scale -- A first European crop type map based on Sentinel-1 and LUCAS Copernicus in-situ observations. *Remote Sensing of Environment*, 266. [DOI: 10.1016/j.rse.2021.112708](https://doi.org/10.1016/j.rse.2021.112708)
- **USDA CDL**: USDA NASS Cropland Data Layer. [nass.usda.gov/Research_and_Science/Cropland/SARS1a.php](https://www.nass.usda.gov/Research_and_Science/Cropland/SARS1a.php)
- **Fields of The World**: Kerner, H. et al. (2024). Fields of The World (FTW) -- A Machine Learning Benchmark Dataset For Field Boundary Delineation. [arXiv: 2409.16252](https://arxiv.org/abs/2409.16252)
- **SAGE Crop Calendar**: Sacks, W.J. et al. (2010). Crop planting dates: an analysis of global patterns. *Global Ecology and Biogeography*, 19(5), 607-620. [DOI: 10.1111/j.1466-8238.2010.00551.x](https://doi.org/10.1111/j.1466-8238.2010.00551.x)
- **FAO Crop Calendar**: [cropcalendar.apps.fao.org](https://cropcalendar.apps.fao.org/)

## Architecture

ARCcrop is a native Swift/SwiftUI application targeting iOS. Key architectural components:

- **WMSTileOverlay** -- `MKTileOverlay` subclass that constructs OGC WMS GetMap URLs from tile coordinates, supporting both EPSG:3857 and EPSG:4326, WMS 1.1.1 and 1.3.0
- **FilteredTileOverlay** -- pixel-level filtering to hide specific crop classes by matching RGB values in downloaded tiles
- **BoundedWMSTileOverlay** -- geographic bounds checking to avoid unnecessary tile requests outside a dataset's coverage area
- **PMTileOverlay** -- native PMTiles v3 reader with Hilbert curve tile ID computation, protobuf MVT decoding, and on-the-fly rasterisation
- **GEOGLAMOverlayManager** -- loads bundled PNG rasters and reprojects from equirectangular (EPSG:4326) to Web Mercator (EPSG:3857) using nearest-neighbour interpolation
- **CropMapLegendData** -- static legend definitions with official colour palettes for each dataset
- **FAOCropCalendarService** -- dynamic REST client for the FAO Crop Calendar API with language support, caching, and AEZ zone queries
- **AppSettings** -- observable settings model with UserDefaults persistence for layer state, opacity, cache size, and legend overrides

## Requirements

- iOS 18.0+
- Xcode 16.0+

## Licence

The ARCcrop application code is provided as-is. Individual datasets are subject to their own licensing terms as listed in the tables above. Most European parcel datasets are provided under open government or INSPIRE licences. Users are responsible for complying with the terms of each data provider when using the data accessed through this application.
