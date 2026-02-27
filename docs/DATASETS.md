# ARCcrop Dataset Reference

Comprehensive documentation for every dataset available in ARCcrop. Datasets are grouped by geographic region, matching the app's menu structure.

---

## Table of Contents

- [Global Datasets](#global-datasets)
  - [GEOGLAM Best Available Crop Type Masks](#geoglam-best-available-crop-type-masks)
  - [ESA WorldCover](#esa-worldcover)
  - [ESA WorldCereal](#esa-worldcereal)
  - [GLAD Global Cropland](#glad-global-cropland)
  - [Google Dynamic World](#google-dynamic-world)
  - [Copernicus Global Land Cover](#copernicus-global-land-cover)
  - [FROM-GLC](#from-glc)
- [North America](#north-america)
  - [USDA Cropland Data Layer (CDL)](#usda-cropland-data-layer-cdl)
  - [AAFC Annual Crop Inventory (Canada)](#aafc-annual-crop-inventory-canada)
- [South America](#south-america)
  - [MapBiomas](#mapbiomas)
  - [GeoINTA Argentina](#geointa-argentina)
- [Europe -- Crop Type Maps](#europe----crop-type-maps)
  - [JRC EU Crop Map (EUCROPMAP)](#jrc-eu-crop-map-eucropmap)
  - [CROME England](#crome-england)
  - [DLR CropTypes Germany](#dlr-croptypes-germany)
  - [RPG France](#rpg-france)
  - [BRP Netherlands](#brp-netherlands)
- [Europe -- Parcel / Field Block Maps](#europe----parcel--field-block-maps)
  - [INVEKOS Austria](#invekos-austria)
  - [ALV Flanders (Belgium)](#alv-flanders-belgium)
  - [SIGPAC Spain](#sigpac-spain)
  - [FVM Denmark](#fvm-denmark)
  - [LPIS Czechia](#lpis-czechia)
  - [GERK Slovenia](#gerk-slovenia)
  - [ARKOD Croatia](#arkod-croatia)
  - [GSAA Estonia](#gsaa-estonia)
  - [Latvia Field Blocks](#latvia-field-blocks)
  - [IFAP Portugal](#ifap-portugal)
  - [LPIS Poland](#lpis-poland)
  - [Jordbruk Sweden](#jordbruk-sweden)
  - [FLIK Luxembourg](#flik-luxembourg)
  - [BLW Switzerland](#blw-switzerland)
- [Oceania](#oceania)
  - [ABARES Australia](#abares-australia)
  - [LCDB New Zealand](#lcdb-new-zealand)

---

## Global Datasets

### GEOGLAM Best Available Crop Type Masks

| Field | Value |
|-------|-------|
| **Full Name** | GEOGLAM Best Available Crop Type Masks v1.0 |
| **Provider** | IIASA / GEOGLAM |
| **Spatial Resolution** | ~5.6 km (0.05 degrees) |
| **Geographic Coverage** | Global |
| **Temporal Coverage** | 2022 (single year) |
| **Data Type** | Embedded raster (bundled PNG, reprojected on-device) |
| **Classification** | 5 crops: Winter Wheat, Spring Wheat, Maize, Soybean, Rice |
| **Access** | No API key required |
| **Source** | Zenodo (DOI: 10.5281/zenodo.7230863) |

**Modes in app:**
- **Majority Crop** -- shows the dominant crop at each grid cell using categorical colours
- **Crop Proportion** (per crop) -- shows area fraction (0--100%) for each of the 5 crops using graduated colour intensity

**App processing:** The bundled PNGs are in equirectangular projection (EPSG:4326). On first load, the app reprojects each image to Web Mercator (EPSG:3857) using nearest-neighbour interpolation to align with the MapKit map view. The reprojected images are cached in memory. Black pixels (RGB 0,0,0) are treated as nodata and rendered transparent.

---

### ESA WorldCover

| Field | Value |
|-------|-------|
| **Full Name** | ESA WorldCover |
| **Provider** | ESA / Copernicus |
| **Spatial Resolution** | 10 m |
| **Geographic Coverage** | Global |
| **Temporal Coverage** | 2020--2021 |
| **Data Type** | WMS raster classification |
| **WMS Endpoint** | `https://services.terrascope.be/wms/v2` |
| **WMS Layer** | `WORLDCOVER_2021_MAP` |
| **Max Zoom** | 18 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |
| **Classification** | 11 classes |
| **Access** | No API key required |

**Legend classes:** Tree Cover, Shrubland, Grassland, Cropland, Built-up, Bare/Sparse Vegetation, Water, Wetland, Mangroves, Moss/Lichen (10 shown in app legend).

**Source data:** Derived from Sentinel-1 and Sentinel-2 imagery.

---

### ESA WorldCereal

| Field | Value |
|-------|-------|
| **Full Name** | ESA WorldCereal v100 |
| **Provider** | ESA / VITO |
| **Spatial Resolution** | 10 m |
| **Geographic Coverage** | Global |
| **Temporal Coverage** | 2021 |
| **Data Type** | WMS raster (binary crop type masks) |
| **WMS Endpoint** | `https://services.terrascope.be/wms/v2` |
| **Max Zoom** | 18 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |
| **Access** | No API key required |

**Four sub-layers available:**

| Sub-layer | WMS Layer Name | Classification |
|-----------|---------------|----------------|
| All Temporary Crops | `WORLDCEREAL_TEMPORARYCROPS_V1` | Binary: Temporary Crops |
| Maize | `WORLDCEREAL_MAIZE_V1` | Binary: Maize |
| Winter Cereals | `WORLDCEREAL_WINTERCEREALS_V1` | Binary: Winter Cereals |
| Spring Cereals | `WORLDCEREAL_SPRINGCEREALS_V1` | Binary: Spring Cereals |

**Source data:** Derived from Sentinel-2 imagery. Each layer is a binary mask indicating presence/absence of the target crop type.

---

### GLAD Global Cropland

| Field | Value |
|-------|-------|
| **Full Name** | GLAD Global Cropland |
| **Provider** | University of Maryland / GLAD |
| **Spatial Resolution** | 30 m |
| **Geographic Coverage** | Global |
| **Temporal Coverage** | 2003--2020 |
| **Data Type** | WMS raster (binary cropland extent) |
| **Classification** | 2 classes: Cropland, Non-Cropland |
| **Access** | No API key required |

**Source data:** Derived from Landsat imagery. Provides a binary cropland/non-cropland classification.

---

### Google Dynamic World

| Field | Value |
|-------|-------|
| **Full Name** | Google Dynamic World |
| **Provider** | Google / WRI |
| **Spatial Resolution** | 10 m |
| **Geographic Coverage** | Global |
| **Temporal Coverage** | 2018--2024 |
| **Data Type** | Near-realtime land use/land cover |
| **Classification** | 6 classes shown in legend: Trees, Grass, Bare, Crops, Built, Water |
| **Access** | Requires Google Earth Engine service account JSON |

**API Key:** Requires a Google Cloud service account with Earth Engine API enabled. The service account JSON file contents are stored in the iOS Keychain.

---

### Copernicus Global Land Cover

| Field | Value |
|-------|-------|
| **Full Name** | Copernicus Global Land Cover |
| **Provider** | ESA / Copernicus |
| **Spatial Resolution** | 100 m |
| **Geographic Coverage** | Global |
| **Temporal Coverage** | 2015--2019 |
| **Data Type** | Discrete land cover classification |
| **Classification** | 5 classes shown in legend: Cropland, Forest, Bare/Sparse, Water, Urban |
| **Access** | Requires Copernicus Data Space username + password |

**Source data:** Derived from Proba-V satellite imagery.

---

### FROM-GLC

| Field | Value |
|-------|-------|
| **Full Name** | FROM-GLC (Finer Resolution Observation and Monitoring of Global Land Cover) |
| **Provider** | Tsinghua University |
| **Spatial Resolution** | 30 m |
| **Geographic Coverage** | Global |
| **Temporal Coverage** | 2017--2020 |
| **Data Type** | Land cover classification |
| **Classification** | 4 classes shown in legend: Cropland, Forest, Grassland, Other |
| **Access** | Requires Google Earth Engine service account JSON |

**Source data:** Derived from Landsat and Sentinel imagery.

---

## North America

### USDA Cropland Data Layer (CDL)

| Field | Value |
|-------|-------|
| **Full Name** | USDA CropScape Cropland Data Layer |
| **Acronym** | CDL |
| **Provider** | USDA National Agricultural Statistics Service (NASS) |
| **Spatial Resolution** | 30 m |
| **Geographic Coverage** | Continental United States |
| **Temporal Coverage** | 2008--2023 (16 years) |
| **Data Type** | WMS raster classification |
| **WMS Endpoint** | `https://nassgeodata.gmu.edu/CropScapeService/wms_cdlall.cgi` |
| **WMS Layer** | `cdl_{year}` (e.g. `cdl_2023`) |
| **Max Zoom** | 17 |
| **CRS** | EPSG:4326 (server only supports 4326 and 5070) |
| **WMS Version** | 1.1.1 |
| **Classification** | 10 classes in legend (full CDL has 100+) |
| **Access** | No API key required |

**Legend classes:** Corn, Soybeans, Winter Wheat, Spring Wheat, Rice, Cotton, Sorghum, Grass/Pasture, Forest, Developed. Uses the official USDA CropScape colour palette.

**Source data:** Annual crop-specific land cover from NASS using satellite imagery and extensive ground truth data.

---

### AAFC Annual Crop Inventory (Canada)

| Field | Value |
|-------|-------|
| **Full Name** | AAFC Annual Crop Inventory |
| **Acronym** | ACI |
| **Provider** | Agriculture and Agri-Food Canada (AAFC) |
| **Spatial Resolution** | 30 m |
| **Geographic Coverage** | Canada |
| **Temporal Coverage** | 2009--2024 (16 years) |
| **Data Type** | WMS raster classification |
| **WMS Endpoint** | `https://www.agr.gc.ca/imagery-images/services/annual_crop_inventory/{year}/ImageServer/WMSServer` |
| **WMS Layer** | `{year}:annual_crop_inventory` |
| **Max Zoom** | 17 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |
| **Classification** | 60+ classes (8 shown in legend) |
| **Access** | No API key required |

**Legend classes:** Wheat, Canola, Barley, Soybeans, Corn, Lentils, Peas, Pasture.

**Source data:** Derived from Landsat and RapidEye satellite imagery with ground truth data from Agriculture Canada.

---

## South America

### MapBiomas

| Field | Value |
|-------|-------|
| **Full Name** | MapBiomas |
| **Provider** | MapBiomas Network |
| **Spatial Resolution** | 30 m |
| **Geographic Coverage** | South America |
| **Temporal Coverage** | 2000--2022 (23 years) |
| **Data Type** | Annual land use/land cover classification |
| **Classification** | 4 classes shown in legend: Soy, Sugar Cane, Forest, Pasture |
| **Access** | Requires Google Earth Engine service account JSON |

**Source data:** Annual land use and land cover mapping derived from Landsat imagery. Comprehensive coverage of the Brazilian biomes and expanding to other South American countries.

---

### GeoINTA Argentina

| Field | Value |
|-------|-------|
| **Full Name** | Mapa Nacional de Cultivos (National Crop Map) |
| **Provider** | INTA (Instituto Nacional de Tecnologia Agropecuaria) |
| **Spatial Resolution** | 30 m |
| **Geographic Coverage** | Argentina |
| **Temporal Coverage** | 2024 (summer campaign) |
| **Data Type** | WMS raster classification |
| **WMS Endpoint** | `https://geo-backend.inta.gob.ar/geoserver/wms` |
| **WMS Layer** | `geonode:mnc_verano2024_f300268fd112b0ec3ef5f731edb78882` |
| **Max Zoom** | 17 |
| **CRS** | EPSG:4326 |
| **WMS Version** | 1.3.0 |
| **Classification** | Server-styled (no fixed legend in app) |
| **Access** | No API key required |

**Source data:** Derived from Landsat and Sentinel imagery for summer cropping campaign.

---

## Europe -- Crop Type Maps

### JRC EU Crop Map (EUCROPMAP)

| Field | Value |
|-------|-------|
| **Full Name** | JRC EU Crop Map (EUCROPMAP) |
| **Provider** | Joint Research Centre / European Commission (JRC/EC) |
| **Spatial Resolution** | 10 m |
| **Geographic Coverage** | EU-27 + Ukraine |
| **Temporal Coverage** | 2018--2022 (5 years) |
| **Data Type** | WMS raster classification |
| **WMS Endpoint** | `https://jeodpp.jrc.ec.europa.eu/jeodpp/services/ows/wms/landcover/eucropmap` |
| **WMS Layer** | `LC.EUCROPMAP.{year}` (e.g. `LC.EUCROPMAP.2022`) |
| **Max Zoom** | 18 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |
| **Classification** | 19 crop types + 4 non-crop classes (23 total in legend) |
| **Access** | No API key required |

**Legend classes:** Artificial, Common Wheat, Durum Wheat, Barley, Rye, Oats, Maize, Rice, Triticale, Potatoes, Sugar Beet, Other Crops, Sunflower, Rapeseed, Soya, Dry Pulses, Fodder Crops, Bare Arable, Woodland, Grasslands, Bare Land, Water, Wetlands.

**Source data:** Derived primarily from Sentinel-1 SAR imagery.

---

### CROME England

| Field | Value |
|-------|-------|
| **Full Name** | Crop Map of England (CROME) |
| **Provider** | Defra / Rural Payments Agency (RPA) |
| **Spatial Resolution** | ~20 m hexagonal grid |
| **Geographic Coverage** | England |
| **Temporal Coverage** | 2017--2024 (8 years) |
| **Data Type** | WMS raster classification (hexagonal) |
| **WMS Endpoint** | `https://environment.data.gov.uk/spatialdata/crop-map-of-england-{year}/wms` |
| **WMS Layer** | `Crop_Map_of_England_{year}` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |
| **Classification** | 11 classes in legend (15+ in full dataset) |
| **Access** | No API key required |

**Legend classes:** Winter Wheat, Barley, Oats, Oilseed Rape, Maize, Potatoes, Sugar Beet, Field Beans, Peas, Grass, Fallow. Uses the official Defra colour palette.

**App processing:** The WMS service provides per-county sublayers. The app supports both full England layer requests and bounded per-county requests via `BoundedWMSTileOverlay` that clips tile loading to each county's geographic extent, reducing unnecessary downloads. 40 English counties are defined with exact bounding boxes from the WMS GetCapabilities response.

---

### DLR CropTypes Germany

| Field | Value |
|-------|-------|
| **Full Name** | DLR CropTypes Germany |
| **Provider** | German Aerospace Center Earth Observation Center (DLR EOC) |
| **Spatial Resolution** | 10 m |
| **Geographic Coverage** | Germany |
| **Temporal Coverage** | 2023 (single year) |
| **Data Type** | WMS raster classification |
| **WMS Endpoint** | `https://geoservice.dlr.de/eoc/land/wms` |
| **WMS Layer** | `CROPTYPES_DE_P1Y` |
| **Max Zoom** | 18 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |
| **Extra Params** | `STYLES=croptypes` |
| **Classification** | 18 crop types (10 shown in legend) |
| **Access** | No API key required |

**Legend classes:** Winter Wheat, Winter Barley, Winter Rye, Rapeseed, Spring Barley, Spring Oats, Maize, Sugar Beet, Potatoes, Permanent Grass.

**Source data:** Derived from Sentinel-2 optical imagery.

---

### RPG France

| Field | Value |
|-------|-------|
| **Full Name** | Registre Parcellaire Graphique (RPG) |
| **Provider** | IGN / ASP |
| **Spatial Resolution** | Parcel-level vector |
| **Geographic Coverage** | France |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS vector parcels |
| **WMS Endpoint** | `https://data.geopf.fr/wms-r/wms` |
| **WMS Layer** | `LANDUSE.AGRICULTURE.LATEST` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |
| **Classification** | 28+ crop groups (6 shown in legend) |
| **Access** | No API key required |

**Legend classes (approximate):** Cereals, Oilseeds, Protein Crops, Vineyards, Orchards, Grassland.

**Note:** The IGN Geoplateforme WMS does not expose an SLD, so the legend colours are approximate.

---

### BRP Netherlands

| Field | Value |
|-------|-------|
| **Full Name** | Basisregistratie Percelen (BRP) |
| **Provider** | RVO / PDOK |
| **Spatial Resolution** | Parcel-level vector |
| **Geographic Coverage** | Netherlands |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS vector parcels |
| **WMS Endpoint** | `https://service.pdok.nl/rvo/brpgewaspercelen/wms/v1_0` |
| **WMS Layer** | `BrpGewas` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |
| **Classification** | 4 crop categories shown in legend |
| **License** | CC0 (public domain) |
| **Access** | No API key required |

**Legend classes:** Bouwland (Arable), Grasland (Grassland), Overige (Other), Landschap (Landscape). Styled by crop category (gewasgroep).

---

## Europe -- Parcel / Field Block Maps

These datasets provide parcel-level or field-block-level agricultural land boundaries via WMS. They are served with server-side styling and do not have fixed legend data in the app. All are accessible without API keys.

### INVEKOS Austria

| Field | Value |
|-------|-------|
| **Full Name** | INVEKOS reference parcels (Feldstuecke) |
| **Provider** | Agrarmarkt Austria (AMA) / LFRZ |
| **Geographic Coverage** | Austria |
| **Temporal Coverage** | 2025 |
| **Data Type** | WMS INSPIRE parcels |
| **WMS Endpoint** | `https://inspire.lfrz.gv.at/009501/wms` |
| **WMS Layer** | `inspire_feldstuecke_2025-2` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |

---

### ALV Flanders (Belgium)

| Field | Value |
|-------|-------|
| **Full Name** | Agricultural use parcels (Landbouwgebruikspercelen) |
| **Provider** | Digitaal Vlaanderen |
| **Geographic Coverage** | Flanders (Belgium) |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS open data parcels |
| **WMS Endpoint** | `https://geo.api.vlaanderen.be/ALV/wms` |
| **WMS Layer** | `LbGebrPerc2024` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |

---

### SIGPAC Spain

| Field | Value |
|-------|-------|
| **Full Name** | SIGPAC agricultural enclosures (recintos) |
| **Provider** | FEGA / MAPA |
| **Geographic Coverage** | Spain |
| **Temporal Coverage** | 2025 |
| **Data Type** | WMS parcels (national parcel registry) |
| **WMS Endpoint** | `https://wms.mapa.gob.es/sigpac/wms` |
| **WMS Layer** | `AU.Sigpac:recinto` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |

---

### FVM Denmark

| Field | Value |
|-------|-------|
| **Full Name** | Agricultural fields (Marker) |
| **Provider** | Landbrugsstyrelsen (LBST) |
| **Geographic Coverage** | Denmark |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS open geodata fields |
| **WMS Endpoint** | `https://geodata.fvm.dk/geoserver/ows` |
| **WMS Layer** | `Marker_2024` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |

---

### LPIS Czechia

| Field | Value |
|-------|-------|
| **Full Name** | LPIS soil blocks (DPB) |
| **Provider** | Czech Ministry of Agriculture (MZe) |
| **Geographic Coverage** | Czechia |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS public parcels |
| **WMS Endpoint** | `https://mze.gov.cz/public/app/wms/public_DPB_PB_OPV.fcgi` |
| **WMS Layer** | `DPB_UCINNE` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |

---

### GERK Slovenia

| Field | Value |
|-------|-------|
| **Full Name** | GERK agricultural use units |
| **Provider** | Slovenian Ministry of Agriculture (MKGP) |
| **Geographic Coverage** | Slovenia |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS INSPIRE parcels |
| **WMS Endpoint** | `https://storitve.eprostor.gov.si/ows-pub-wms/SI.MKGP.GERK/ows` |
| **WMS Layer** | `RKG_BLOK_GERK` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |

---

### ARKOD Croatia

| Field | Value |
|-------|-------|
| **Full Name** | ARKOD land parcels |
| **Provider** | APPRRR (Agency for Payments in Agriculture, Fisheries and Rural Development) |
| **Geographic Coverage** | Croatia |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS public parcels (updated weekly) |
| **WMS Endpoint** | `https://servisi.apprrr.hr/NIPP/wms` |
| **WMS Layer** | `hr.land_parcels` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:4326 |
| **WMS Version** | 1.1.1 |

---

### GSAA Estonia

| Field | Value |
|-------|-------|
| **Full Name** | GSAA declared agricultural fields |
| **Provider** | PRIA (Estonian Agricultural Registers and Information Board) |
| **Geographic Coverage** | Estonia |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS INSPIRE fields |
| **WMS Endpoint** | `https://kls.pria.ee/geoserver/inspire_gsaa/wms` |
| **WMS Layer** | `inspire_gsaa` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |

---

### Latvia Field Blocks

| Field | Value |
|-------|-------|
| **Full Name** | Agricultural field blocks (Lauku bloki) |
| **Provider** | LAD (Rural Support Service) |
| **Geographic Coverage** | Latvia |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS field blocks |
| **WMS Endpoint** | `https://karte.lad.gov.lv/arcgis/services/lauku_bloki/MapServer/WMSServer` |
| **WMS Layer** | `0` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:4326 |
| **WMS Version** | 1.1.1 |

---

### IFAP Portugal

| Field | Value |
|-------|-------|
| **Full Name** | iSIP agricultural parcels |
| **Provider** | IFAP (Instituto de Financiamento da Agricultura e Pescas) |
| **Geographic Coverage** | Portugal (split by region; Centro region as default) |
| **Temporal Coverage** | 2019 |
| **Data Type** | WMS INSPIRE parcels |
| **WMS Endpoint** | `https://www.ifap.pt/isip/ows/isip.data/wms` |
| **WMS Layer** | `Parcelas_2019_Centro` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |

---

### LPIS Poland

| Field | Value |
|-------|-------|
| **Full Name** | LPIS reference parcels (by voivodeship) |
| **Provider** | GUGiK / ARiMR |
| **Geographic Coverage** | Poland (Mazowieckie/Warsaw region as default) |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS parcels |
| **WMS Endpoint** | `https://mapy.geoportal.gov.pl/wss/ext/arimr_lpis` |
| **WMS Layer** | `14` (Mazowieckie voivodeship) |
| **Max Zoom** | 19 |
| **CRS** | EPSG:4326 |
| **WMS Version** | 1.1.1 |

**Note:** The Polish LPIS is split by voivodeship (administrative region). The app defaults to layer `14` (Mazowieckie, the Warsaw region).

---

### Jordbruk Sweden

| Field | Value |
|-------|-------|
| **Full Name** | Agricultural blocks (Jordbruksblock) |
| **Provider** | Jordbruksverket (SJV -- Swedish Board of Agriculture) |
| **Geographic Coverage** | Sweden |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS INSPIRE field blocks |
| **WMS Endpoint** | `https://epub.sjv.se/inspire/inspire/wms` |
| **WMS Layer** | `jordbruksblock` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.1.1 |

---

### FLIK Luxembourg

| Field | Value |
|-------|-------|
| **Full Name** | FLIK agricultural parcels |
| **Provider** | ASTA (Administration des services techniques de l'agriculture) |
| **Geographic Coverage** | Luxembourg |
| **Temporal Coverage** | 2024 |
| **Data Type** | WMS INSPIRE parcels |
| **WMS Endpoint** | `https://wms.inspire.geoportail.lu/geoserver/af/wms` |
| **WMS Layer** | `af:asta_flik_parcels` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:3857 |
| **WMS Version** | 1.3.0 |

---

### BLW Switzerland

| Field | Value |
|-------|-------|
| **Full Name** | Landwirtschaftliche Nutzungsflaechen (Agricultural land use areas) |
| **Provider** | BLW (Federal Office for Agriculture) |
| **Geographic Coverage** | Switzerland |
| **Temporal Coverage** | 2025 |
| **Data Type** | WMS parcels |
| **WMS Endpoint** | `https://wms.geo.admin.ch/` |
| **WMS Layer** | `ch.blw.landwirtschaftliche-nutzungsflaechen` |
| **Max Zoom** | 19 |
| **CRS** | EPSG:4326 |
| **WMS Version** | 1.3.0 |

---

## Oceania

### ABARES Australia

| Field | Value |
|-------|-------|
| **Full Name** | ABARES Catchment Scale Land Use (CLUM) |
| **Provider** | Australian Bureau of Agricultural and Resource Economics and Sciences (ABARES), Dept of Agriculture |
| **Spatial Resolution** | Catchment scale |
| **Geographic Coverage** | Australia |
| **Temporal Coverage** | 2023 |
| **Data Type** | WMS land use classification |
| **WMS Endpoint** | `https://di-daa.img.arcgis.com/arcgis/services/Land_and_vegetation/Catchment_Scale_Land_Use_Simplified/ImageServer/WMSServer` |
| **WMS Layer** | `Catchment_Scale_Land_Use_Simplified` |
| **Max Zoom** | 17 |
| **CRS** | EPSG:4326 |
| **WMS Version** | 1.3.0 |
| **Classification** | Simplified ALUM classification (server-styled) |
| **Access** | No API key required |

---

### LCDB New Zealand

| Field | Value |
|-------|-------|
| **Full Name** | Land Cover Database v6 (LCDB) |
| **Provider** | Manaaki Whenua / Landcare Research (MWLR) |
| **Spatial Resolution** | Land cover polygons |
| **Geographic Coverage** | New Zealand |
| **Temporal Coverage** | 2023/24 |
| **Data Type** | WMS land cover classification |
| **WMS Endpoint** | `https://maps.scinfo.org.nz/lcdb/wms` |
| **WMS Layer** | `lcdb_lcdb6` |
| **Max Zoom** | 17 |
| **CRS** | EPSG:4326 |
| **WMS Version** | 1.1.1 |
| **Classification** | 33 land cover classes (server-styled) |
| **Access** | No API key required |

---

## Additional Overlays

These are supplementary boundary layers, not crop type maps.

### LSIB Political Boundaries

| Field | Value |
|-------|-------|
| **Full Name** | Large Scale International Boundary (LSIB) |
| **Provider** | US State Department |
| **WMS Endpoint** | `https://services.geodata.state.gov/geoserver/lsib/wms` |
| **WMS Layer** | `lsib:LSIB` |

### OS Field Boundaries (UK)

| Field | Value |
|-------|-------|
| **Provider** | Ordnance Survey (OS Data Hub) |
| **Tile Endpoint** | `https://api.os.uk/maps/raster/v1/zxy/Outdoor_3857/{z}/{x}/{y}.png` |
| **Max Zoom** | 20 |
| **Access** | Requires OS Data Hub API key |
| **Free Tier** | 1000 transactions/month |

---

## Technical Notes

### WMS Tile Caching

All WMS tile requests are cached aggressively using a dedicated `URLCache` instance:
- Memory cache: 200 MB
- Disk cache: 2 GB default, configurable up to 5 GB in app settings
- Cache policy: `returnCacheDataElseLoad` -- tiles are served from disk cache across app sessions, only fetching from the network on cache miss
- Tiles are force-cached even when the WMS server sends `no-cache` or `no-store` headers, since crop map tile data is static for a given year and layer

### Class Filtering

When a user hides a legend class, the app uses pixel-level RGB filtering via `FilteredTileOverlay`. Each downloaded tile image is scanned pixel by pixel, and any pixel whose RGB values fall within a configurable tolerance (default 30 for WMS tiles, 20 for GEOGLAM rasters) of a hidden class's colour is set to fully transparent.

### Coordinate Reference Systems

The app supports both EPSG:3857 (Web Mercator) and EPSG:4326 (Geographic) coordinate reference systems for WMS requests. The CRS is selected per dataset based on what each WMS server supports. BBOX axis ordering follows WMS version conventions: WMS 1.1.1 always uses longitude-first, while WMS 1.3.0 with EPSG:4326 uses latitude-first.

### PMTiles Support

The app includes a native PMTiles v3 reader that supports:
- HTTP range requests for lazy tile loading
- Gzip-compressed directories and tiles
- Hilbert curve tile ID computation for Z/X/Y lookups
- MVT (Mapbox Vector Tile) protobuf decoding
- On-the-fly rasterisation of polygon and line features to PNG tiles
- Support for pre-rendered tile types (PNG, JPEG, WebP)
