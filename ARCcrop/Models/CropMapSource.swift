import SwiftUI

enum GEOGLAMCrop: String, CaseIterable, Identifiable, Sendable {
    case winterWheat = "Winter Wheat"
    case springWheat = "Spring Wheat"
    case maize = "Maize"
    case soybean = "Soybean"
    case rice = "Rice"

    var id: String { rawValue }

    var filename: String {
        switch self {
        case .winterWheat: "GEOGLAM_WinterWheat"
        case .springWheat: "GEOGLAM_SpringWheat"
        case .maize: "GEOGLAM_Maize"
        case .soybean: "GEOGLAM_Soybean"
        case .rice: "GEOGLAM_Rice"
        }
    }

    var color: Color {
        switch self {
        case .winterWheat: .brown
        case .springWheat: .orange
        case .maize: .yellow
        case .soybean: .green
        case .rice: .cyan
        }
    }
}

enum CropMapSource: Hashable, Identifiable, Sendable {
    case none
    case geoglamMajorityCrop
    case geoglam(GEOGLAMCrop)
    case usdaCDL(year: Int)
    case jrcEUCropMap(year: Int)
    case cromeEngland(year: Int)
    case dlrCropTypes
    case rpgFrance
    case brpNetherlands
    case aafcCanada(year: Int)
    // European parcel maps
    case invekosAustria
    case alvFlanders
    case sigpacSpain
    case fvmDenmark
    case lpisCzechia
    case gerkSlovenia
    case arkodCroatia
    case gsaaEstonia
    case latviaFieldBlocks
    case ifapPortugal
    case lpisPoland
    case jordbrukSweden
    case flikLuxembourg
    case blwSwitzerland
    // Non-European national
    case abaresAustralia
    case lcdbNewZealand
    case geoIntaArgentina
    // Non-European national (continued)
    case modisLandCover(year: Int)
    case gfsadCropland
    case nalcms
    case deAfricaCrop
    case deaLandCover(year: Int)
    case mexicoMadmex(year: Int)
    case indiaBhuvan
    case turkeyCorine
    case indonesiaKlhk
    case waporLCC
    case walloniaAgriculture(year: Int)
    case nibioNorway
    // Land use / land cover
    case esaWorldCover(year: Int)
    case gladCropland(year: Int)
    case dynamicWorld
    case worldCereal
    case worldCerealMaize
    case worldCerealWinterCereals
    case worldCerealSpringCereals
    case copernicusLandCover
    case fromGLC
    case mapBiomas(year: Int)

    var id: String {
        switch self {
        case .none: "none"
        case .geoglamMajorityCrop: "geoglam_majority"
        case .geoglam(let crop): "geoglam_\(crop.rawValue)"
        case .usdaCDL(let year): "usda_cdl_\(year)"
        case .jrcEUCropMap(let year): "jrc_eucropmap_\(year)"
        case .cromeEngland(let year): "crome_\(year)"
        case .dlrCropTypes: "dlr_croptypes"
        case .rpgFrance: "rpg_france"
        case .brpNetherlands: "brp_netherlands"
        case .aafcCanada(let year): "aafc_\(year)"
        case .invekosAustria: "invekos_austria"
        case .alvFlanders: "alv_flanders"
        case .sigpacSpain: "sigpac_spain"
        case .fvmDenmark: "fvm_denmark"
        case .lpisCzechia: "lpis_czechia"
        case .gerkSlovenia: "gerk_slovenia"
        case .arkodCroatia: "arkod_croatia"
        case .gsaaEstonia: "gsaa_estonia"
        case .latviaFieldBlocks: "latvia_field_blocks"
        case .ifapPortugal: "ifap_portugal"
        case .lpisPoland: "lpis_poland"
        case .jordbrukSweden: "jordbruk_sweden"
        case .flikLuxembourg: "flik_luxembourg"
        case .blwSwitzerland: "blw_switzerland"
        case .abaresAustralia: "abares_australia"
        case .lcdbNewZealand: "lcdb_newzealand"
        case .geoIntaArgentina: "geointa_argentina"
        case .modisLandCover(let year): "modis_landcover_\(year)"
        case .gfsadCropland: "gfsad_cropland"
        case .nalcms: "nalcms"
        case .deAfricaCrop: "deafrica_crop"
        case .deaLandCover(let year): "dea_landcover_\(year)"
        case .mexicoMadmex(let year): "mexico_madmex_\(year)"
        case .indiaBhuvan: "india_bhuvan"
        case .turkeyCorine: "turkey_corine"
        case .indonesiaKlhk: "indonesia_klhk"
        case .waporLCC: "wapor_lcc"
        case .walloniaAgriculture(let year): "wallonia_\(year)"
        case .nibioNorway: "nibio_norway"
        case .esaWorldCover(let year): "esa_worldcover_\(year)"
        case .gladCropland(let year): "glad_\(year)"
        case .dynamicWorld: "dynamic_world"
        case .worldCereal: "worldcereal"
        case .worldCerealMaize: "worldcereal_maize"
        case .worldCerealWinterCereals: "worldcereal_wintercereals"
        case .worldCerealSpringCereals: "worldcereal_springcereals"
        case .copernicusLandCover: "copernicus_lc"
        case .fromGLC: "from_glc"
        case .mapBiomas(let year): "mapbiomas_\(year)"
        }
    }

    /// Identity ignoring year — used to prevent duplicate entries of the same source at different years
    var baseID: String {
        switch self {
        case .usdaCDL: "usda_cdl"
        case .jrcEUCropMap: "jrc_eucropmap"
        case .cromeEngland: "crome"
        case .aafcCanada: "aafc"
        case .modisLandCover: "modis_landcover"
        case .deaLandCover: "dea_landcover"
        case .mexicoMadmex: "mexico_madmex"
        case .walloniaAgriculture: "wallonia"
        case .esaWorldCover: "esa_worldcover"
        case .gladCropland: "glad"
        case .mapBiomas: "mapbiomas"
        default: id
        }
    }

    var displayName: String {
        switch self {
        case .none: "None"
        case .geoglamMajorityCrop: "GEOGLAM Majority Crop (2022)"
        case .geoglam(let crop): "GEOGLAM \(crop.rawValue) % (2022)"
        case .usdaCDL(let year): "USDA CDL (\(year))"
        case .jrcEUCropMap(let year): "JRC EU Crop Map (\(year))"
        case .cromeEngland(let year): "CROME England (\(year))"
        case .dlrCropTypes: "DLR CropTypes Germany"
        case .rpgFrance: "RPG France"
        case .brpNetherlands: "BRP Netherlands (2024)"
        case .aafcCanada(let year): "AAFC Canada (\(year))"
        case .invekosAustria: "INVEKOS Austria"
        case .alvFlanders: "ALV Flanders"
        case .sigpacSpain: "SIGPAC Spain"
        case .fvmDenmark: "FVM Denmark"
        case .lpisCzechia: "LPIS Czechia"
        case .gerkSlovenia: "GERK Slovenia"
        case .arkodCroatia: "ARKOD Croatia"
        case .gsaaEstonia: "GSAA Estonia"
        case .latviaFieldBlocks: "Latvia Field Blocks"
        case .ifapPortugal: "IFAP Portugal"
        case .lpisPoland: "LPIS Poland"
        case .jordbrukSweden: "Jordbruk Sweden"
        case .flikLuxembourg: "FLIK Luxembourg"
        case .blwSwitzerland: "BLW Switzerland"
        case .abaresAustralia: "ABARES Australia"
        case .lcdbNewZealand: "LCDB New Zealand"
        case .geoIntaArgentina: "GeoINTA Argentina (2024)"
        case .modisLandCover(let year): "MODIS Land Cover (\(year))"
        case .gfsadCropland: "GFSAD Global Croplands (2000)"
        case .nalcms: "NALCMS Land Cover (2020)"
        case .deAfricaCrop: "DE Africa Cropland"
        case .deaLandCover(let year): "DEA Land Cover (\(year))"
        case .mexicoMadmex(let year): "Mexico MAD-Mex (\(year))"
        case .indiaBhuvan: "India Bhuvan LULC"
        case .turkeyCorine: "CORINE Turkey (2018)"
        case .indonesiaKlhk: "Indonesia KLHK"
        case .waporLCC: "WaPOR Land Cover"
        case .walloniaAgriculture(let year): "Wallonia Agriculture (\(year))"
        case .nibioNorway: "NIBIO AR5 Norway"
        case .esaWorldCover(let year): "ESA WorldCover (\(year))"
        case .gladCropland(let year): "GLAD Cropland (\(year))"
        case .dynamicWorld: "Esri 10m Land Cover (2023)"
        case .worldCereal: "ESA WorldCereal (2021)"
        case .worldCerealMaize: "ESA WorldCereal Maize (2021)"
        case .worldCerealWinterCereals: "ESA WorldCereal Winter Cereals (2021)"
        case .worldCerealSpringCereals: "ESA WorldCereal Spring Cereals (2021)"
        case .copernicusLandCover: "Copernicus LC100 (2019)"
        case .fromGLC: "GLAD Land Cover (2020)"
        case .mapBiomas(let year): "MapBiomas (\(year))"
        }
    }

    var subtitle: String {
        switch self {
        case .none: ""
        case .geoglamMajorityCrop: "Embedded · Dominant crop · 5.6km · Global"
        case .geoglam: "Embedded · Proportion · 5.6km · Global"
        case .usdaCDL: "WMS · 30m · US"
        case .jrcEUCropMap: "WMS · 10m · EU-27 + Ukraine"
        case .cromeEngland: "WMS · ~20m hex · England"
        case .dlrCropTypes: "WMS · 10m · Germany"
        case .rpgFrance: "WMS · Parcels · France"
        case .brpNetherlands: "WMS · Parcels · Netherlands"
        case .aafcCanada: "WMS · 30m · Canada"
        case .invekosAustria: "WMS · Parcels · Austria"
        case .alvFlanders: "WMS · Parcels · Flanders"
        case .sigpacSpain: "WMS · Parcels · Spain"
        case .fvmDenmark: "WMS · Fields · Denmark"
        case .lpisCzechia: "WMS · Parcels · Czechia"
        case .gerkSlovenia: "WMS · Parcels · Slovenia"
        case .arkodCroatia: "WMS · Parcels · Croatia"
        case .gsaaEstonia: "WMS · Fields · Estonia"
        case .latviaFieldBlocks: "WMS · Field blocks · Latvia"
        case .ifapPortugal: "WMS · Parcels · Portugal"
        case .lpisPoland: "WMS · Parcels · Poland"
        case .jordbrukSweden: "WMS · Field blocks · Sweden"
        case .flikLuxembourg: "WMS · Parcels · Luxembourg"
        case .blwSwitzerland: "WMS · Parcels · Switzerland"
        case .abaresAustralia: "WMS · Land Use · Australia"
        case .lcdbNewZealand: "WMS · Land Cover · New Zealand"
        case .geoIntaArgentina: "WMS · 30m · Argentina"
        case .modisLandCover: "WMS · 500m · Global"
        case .gfsadCropland: "WMS · 1km · Global"
        case .nalcms: "WMS · 30m · N. America"
        case .deAfricaCrop: "WMS · 10m · Africa"
        case .deaLandCover: "WMS · 25m · Australia"
        case .mexicoMadmex: "WMS · 30m · Mexico"
        case .indiaBhuvan: "WMS · 56m · India"
        case .turkeyCorine: "WMS · 100m · Turkey"
        case .indonesiaKlhk: "WMS · 250k · Indonesia"
        case .waporLCC: "WMS · 100m · Africa/ME"
        case .walloniaAgriculture: "WMS · Parcels · Wallonia"
        case .nibioNorway: "WMS · Land Type · Norway"
        case .esaWorldCover: "10m · Global"
        case .gladCropland: "30m · Global"
        case .dynamicWorld: "ArcGIS · 10m · Global"
        case .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals: "WMS · 10m · Global"
        case .copernicusLandCover: "WMS · 100m · Global"
        case .fromGLC: "ArcGIS · 30m · Global"
        case .mapBiomas: "WMS · 30m · S. America"
        }
    }

    var about: String {
        switch self {
        case .none: ""
        case .geoglamMajorityCrop, .geoglam: """
            GEOGLAM Best Available Crop Type Masks (v1.0, Oct 2022). \
            Global crop type area fractions at ~5.6km resolution for 5 major crops. \
            Source: IIASA/GEOGLAM via Zenodo (DOI: 10.5281/zenodo.7230863).
            """
        case .usdaCDL: "USDA CropScape Cropland Data Layer. 30m resolution, US only. Annual crop-specific land cover from NASS."
        case .jrcEUCropMap: "JRC EU Crop Map (EUCROPMAP). 10m crop type map for EU-27 + Ukraine from Sentinel-1. 19 crop types."
        case .cromeEngland: "Crop Map of England (CROME). Hexagonal crop classification from Sentinel-1/2. 15+ crop types. Defra/RPA."
        case .dlrCropTypes: "DLR CropTypes Germany. 10m crop type map from Sentinel-2. 18 crop types. German Aerospace Center."
        case .rpgFrance: "Registre Parcellaire Graphique (RPG). Parcel-level crop declarations. 28+ crop groups. IGN/ASP."
        case .brpNetherlands: "Basisregistratie Percelen (BRP). Parcel-level crop declarations. PDOK/RVO. CC0 license."
        case .aafcCanada: "AAFC Annual Crop Inventory. 30m crop type from Landsat/RapidEye. 60+ classes. Agriculture Canada."
        case .invekosAustria: "INVEKOS reference parcels (Feldstuecke). INSPIRE WMS from Agrarmarkt Austria (AMA)."
        case .alvFlanders: "Agricultural use parcels (Landbouwgebruikspercelen). Open data from Digitaal Vlaanderen."
        case .sigpacSpain: "SIGPAC agricultural enclosures (recintos). National parcel registry from FEGA/MAPA."
        case .fvmDenmark: "Agricultural fields (Marker). Open geodata from Landbrugsstyrelsen."
        case .lpisCzechia: "LPIS soil blocks (DPB). Public WMS from Czech Ministry of Agriculture (MZe)."
        case .gerkSlovenia: "GERK agricultural use units. INSPIRE WMS from Slovenian Ministry of Agriculture."
        case .arkodCroatia: "ARKOD land parcels. Public WMS from APPRRR, updated weekly."
        case .gsaaEstonia: "GSAA declared agricultural fields. INSPIRE WMS from PRIA (Estonian Agricultural Registers)."
        case .latviaFieldBlocks: "Agricultural field blocks (Lauku bloki). WMS from LAD (Rural Support Service)."
        case .ifapPortugal: "iSIP agricultural parcels. INSPIRE WMS from IFAP, split by region."
        case .lpisPoland: "LPIS reference parcels by voivodeship. WMS from GUGiK/ARiMR."
        case .jordbrukSweden: "Agricultural blocks (Jordbruksblock). INSPIRE WMS from Jordbruksverket."
        case .flikLuxembourg: "FLIK agricultural parcels. INSPIRE WMS from Geoportal Luxembourg."
        case .blwSwitzerland: "Landwirtschaftliche Nutzungsflaechen. Agricultural land use areas from BLW (Federal Office for Agriculture)."
        case .abaresAustralia: "ABARES Catchment Scale Land Use (CLUM). Simplified ALUM classification. Dept of Agriculture."
        case .lcdbNewZealand: "Land Cover Database v6 (2023/24). 33 classes. Manaaki Whenua / Landcare Research."
        case .geoIntaArgentina: "Mapa Nacional de Cultivos. 30m crop type from Landsat/Sentinel. INTA (summer campaign)."
        case .modisLandCover: "NASA MODIS Combined L3 IGBP Land Cover Type. 500m annual global land cover. 17 classes."
        case .gfsadCropland: "GFSAD Global Cropland Extent. 1km binary cropland mask from year 2000. USGS/NASA."
        case .nalcms: "North American Land Change Monitoring System. 30m land cover for USA, Canada, Mexico. 19 classes. CEC/USGS/CONABIO."
        case .deAfricaCrop: "Digital Earth Africa crop mask. 10m Sentinel-2 cropland extent for Africa."
        case .deaLandCover: "Digital Earth Australia land cover. 25m Landsat-based annual classification. Geoscience Australia."
        case .mexicoMadmex: "CONABIO MAD-Mex. 30m Landsat-8 land cover, 31 classes. National map of Mexico."
        case .indiaBhuvan: "NRSC/ISRO Bhuvan LULC. 56m AWiFS-based land use/land cover at 1:250k. Multiple LULC classes."
        case .turkeyCorine: "Copernicus CORINE Land Cover 2018. 100m. 44 land cover classes including agricultural types."
        case .indonesiaKlhk: "KLHK Indonesia land cover. 1:250k. 23 classes incl. rice, dry agriculture, plantations."
        case .waporLCC: "FAO WaPOR v2 Land Cover Classification. 100m annual. Irrigated/rainfed cropland distinction. Africa and Middle East."
        case .walloniaAgriculture: "SIGEC anonymous agricultural parcels. SPW Wallonia open geodata."
        case .nibioNorway: "NIBIO AR5 land resource map. Area type classification covering Norway. Norwegian Inst. of Bioeconomy Research."
        case .esaWorldCover: "ESA WorldCover. 10m global land cover from Sentinel-1 and Sentinel-2. 11 classes."
        case .gladCropland: "GLAD Global Cropland. 30m binary cropland extent from Landsat. University of Maryland."
        case .dynamicWorld: "Esri/Impact Observatory Sentinel-2 10m Land Cover. Annual 9-class LULC from Sentinel-2. Free via ArcGIS Living Atlas."
        case .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals:
            "ESA WorldCereal v100. 10m global crop type maps from Sentinel-2."
        case .copernicusLandCover: "Copernicus Global Land Service LC100. 100m discrete classification. VITO/Copernicus."
        case .fromGLC: "GLAD Global Land Cover/Land Use. 30m from Landsat. University of Maryland."
        case .mapBiomas: "MapBiomas. 30m annual land use/land cover for South America from Landsat."
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .none, .geoglamMajorityCrop, .geoglam,
             .usdaCDL, .jrcEUCropMap, .cromeEngland, .dlrCropTypes, .rpgFrance, .brpNetherlands, .aafcCanada,
             .invekosAustria, .alvFlanders, .sigpacSpain, .fvmDenmark, .lpisCzechia,
             .gerkSlovenia, .arkodCroatia, .gsaaEstonia, .latviaFieldBlocks,
             .ifapPortugal, .lpisPoland, .jordbrukSweden, .flikLuxembourg, .blwSwitzerland,
             .abaresAustralia, .lcdbNewZealand, .geoIntaArgentina,
             .modisLandCover, .gfsadCropland, .nalcms, .deAfricaCrop, .deaLandCover,
             .mexicoMadmex, .indiaBhuvan, .turkeyCorine, .indonesiaKlhk, .waporLCC,
             .walloniaAgriculture, .nibioNorway,
             .esaWorldCover, .gladCropland, .worldCereal,
             .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals,
             .mapBiomas, .dynamicWorld, .fromGLC, .copernicusLandCover:
            false
        }
    }

    var apiKeyProvider: APIKeyProvider? {
        switch self {
        default: nil
        }
    }

    var isAvailable: Bool {
        switch self {
        case .none, .geoglamMajorityCrop, .geoglam,
             .usdaCDL, .jrcEUCropMap, .cromeEngland, .dlrCropTypes, .rpgFrance, .brpNetherlands, .aafcCanada,
             .invekosAustria, .alvFlanders, .sigpacSpain, .fvmDenmark, .lpisCzechia,
             .gerkSlovenia, .arkodCroatia, .gsaaEstonia, .latviaFieldBlocks,
             .ifapPortugal, .lpisPoland, .jordbrukSweden, .flikLuxembourg, .blwSwitzerland,
             .abaresAustralia, .lcdbNewZealand, .geoIntaArgentina,
             .modisLandCover, .gfsadCropland, .nalcms, .deAfricaCrop, .deaLandCover,
             .mexicoMadmex, .indiaBhuvan, .turkeyCorine, .indonesiaKlhk, .waporLCC,
             .walloniaAgriculture, .nibioNorway,
             .esaWorldCover, .gladCropland, .worldCereal,
             .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals,
             .mapBiomas, .dynamicWorld, .fromGLC, .copernicusLandCover:
            return true
        default:
            guard let provider = apiKeyProvider else { return false }
            return KeychainService.hasKey(for: provider)
        }
    }

    // MARK: - Year support

    var currentYear: Int {
        switch self {
        case .none: 0
        case .geoglamMajorityCrop, .geoglam: 2022
        case .usdaCDL(let y): y
        case .jrcEUCropMap(let y): y
        case .cromeEngland(let y): y
        case .dlrCropTypes: 2023
        case .rpgFrance: 2024
        case .brpNetherlands: 2024
        case .aafcCanada(let y): y
        case .invekosAustria: 2025
        case .alvFlanders: 2024
        case .sigpacSpain: 2025
        case .fvmDenmark: 2024
        case .lpisCzechia: 2024
        case .gerkSlovenia: 2024
        case .arkodCroatia: 2024
        case .gsaaEstonia: 2024
        case .latviaFieldBlocks: 2024
        case .ifapPortugal: 2019
        case .lpisPoland: 2024
        case .jordbrukSweden: 2024
        case .flikLuxembourg: 2024
        case .blwSwitzerland: 2025
        case .abaresAustralia: 2023
        case .lcdbNewZealand: 2024
        case .geoIntaArgentina: 2024
        case .modisLandCover(let y): y
        case .gfsadCropland: 2000
        case .nalcms: 2020
        case .deAfricaCrop: 2021
        case .deaLandCover(let y): y
        case .mexicoMadmex(let y): y
        case .indiaBhuvan: 2021
        case .turkeyCorine: 2018
        case .indonesiaKlhk: 2021
        case .waporLCC: 2021
        case .walloniaAgriculture(let y): y
        case .nibioNorway: 2024
        case .esaWorldCover(let y): y
        case .gladCropland(let y): y
        case .dynamicWorld: 2023
        case .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals: 2021
        case .copernicusLandCover: 2019
        case .fromGLC: 2020
        case .mapBiomas(let y): y
        }
    }

    var availableYears: ClosedRange<Int>? {
        switch self {
        case .none, .geoglamMajorityCrop, .geoglam, .dlrCropTypes, .rpgFrance, .brpNetherlands,
             .invekosAustria, .alvFlanders, .sigpacSpain, .fvmDenmark, .lpisCzechia,
             .gerkSlovenia, .arkodCroatia, .gsaaEstonia, .latviaFieldBlocks,
             .ifapPortugal, .lpisPoland, .jordbrukSweden, .flikLuxembourg, .blwSwitzerland,
             .abaresAustralia, .lcdbNewZealand, .geoIntaArgentina,
             .gfsadCropland, .nalcms, .deAfricaCrop, .indiaBhuvan, .turkeyCorine,
             .indonesiaKlhk, .waporLCC, .nibioNorway: nil
        case .usdaCDL: 2008...2023
        case .jrcEUCropMap: 2018...2022
        case .cromeEngland: 2017...2024
        case .aafcCanada: 2009...2024
        case .modisLandCover: 2020...2023
        case .deaLandCover: 2018...2020
        case .mexicoMadmex: 2017...2018
        case .walloniaAgriculture: 2019...2023
        case .esaWorldCover: 2020...2021
        case .gladCropland: 2003...2020
        case .dynamicWorld: 2017...2023
        case .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals: 2021...2021
        case .copernicusLandCover: 2015...2019
        case .fromGLC: 2017...2020
        case .mapBiomas: nil
        }
    }

    var sourceName: String {
        switch self {
        case .none: "None"
        case .geoglamMajorityCrop: "GEOGLAM Majority"
        case .geoglam(let crop): "GEOGLAM \(crop.rawValue)"
        case .usdaCDL: "USDA CDL"
        case .jrcEUCropMap: "JRC EU Crop Map"
        case .cromeEngland: "CROME England"
        case .dlrCropTypes: "DLR CropTypes"
        case .rpgFrance: "RPG France"
        case .brpNetherlands: "BRP Netherlands"
        case .aafcCanada: "AAFC Canada"
        case .invekosAustria: "INVEKOS Austria"
        case .alvFlanders: "ALV Flanders"
        case .sigpacSpain: "SIGPAC Spain"
        case .fvmDenmark: "FVM Denmark"
        case .lpisCzechia: "LPIS Czechia"
        case .gerkSlovenia: "GERK Slovenia"
        case .arkodCroatia: "ARKOD Croatia"
        case .gsaaEstonia: "GSAA Estonia"
        case .latviaFieldBlocks: "Latvia Fields"
        case .ifapPortugal: "IFAP Portugal"
        case .lpisPoland: "LPIS Poland"
        case .jordbrukSweden: "Jordbruk Sweden"
        case .flikLuxembourg: "FLIK Luxembourg"
        case .blwSwitzerland: "BLW Switzerland"
        case .abaresAustralia: "ABARES Australia"
        case .lcdbNewZealand: "LCDB NZ"
        case .geoIntaArgentina: "GeoINTA Argentina"
        case .modisLandCover: "MODIS LC"
        case .gfsadCropland: "GFSAD"
        case .nalcms: "NALCMS"
        case .deAfricaCrop: "DE Africa Crop"
        case .deaLandCover: "DEA Land Cover"
        case .mexicoMadmex: "MAD-Mex Mexico"
        case .indiaBhuvan: "Bhuvan India"
        case .turkeyCorine: "CORINE Turkey"
        case .indonesiaKlhk: "KLHK Indonesia"
        case .waporLCC: "WaPOR LCC"
        case .walloniaAgriculture: "Wallonia Agri"
        case .nibioNorway: "NIBIO Norway"
        case .esaWorldCover: "ESA WorldCover"
        case .gladCropland: "GLAD Cropland"
        case .dynamicWorld: "Esri Land Cover"
        case .worldCereal: "WorldCereal"
        case .worldCerealMaize: "WC Maize"
        case .worldCerealWinterCereals: "WC Winter Cereals"
        case .worldCerealSpringCereals: "WC Spring Cereals"
        case .copernicusLandCover: "Copernicus LC"
        case .fromGLC: "GLAD GLCLUC"
        case .mapBiomas: "MapBiomas"
        }
    }

    var provider: String {
        switch self {
        case .none: ""
        case .geoglamMajorityCrop, .geoglam: "IIASA/GEOGLAM"
        case .usdaCDL: "USDA NASS"
        case .jrcEUCropMap: "JRC/EC"
        case .cromeEngland: "Defra/RPA"
        case .dlrCropTypes: "DLR EOC"
        case .rpgFrance: "IGN/ASP"
        case .brpNetherlands: "RVO/PDOK"
        case .aafcCanada: "AAFC"
        case .invekosAustria: "AMA/LFRZ"
        case .alvFlanders: "Vlaanderen"
        case .sigpacSpain: "FEGA/MAPA"
        case .fvmDenmark: "LBST"
        case .lpisCzechia: "MZe"
        case .gerkSlovenia: "MKGP"
        case .arkodCroatia: "APPRRR"
        case .gsaaEstonia: "PRIA"
        case .latviaFieldBlocks: "LAD"
        case .ifapPortugal: "IFAP"
        case .lpisPoland: "ARiMR"
        case .jordbrukSweden: "SJV"
        case .flikLuxembourg: "ASTA"
        case .blwSwitzerland: "BLW"
        case .abaresAustralia: "ABARES"
        case .lcdbNewZealand: "MWLR"
        case .geoIntaArgentina: "INTA"
        case .modisLandCover: "NASA/USGS"
        case .gfsadCropland: "USGS/NASA"
        case .nalcms: "CEC/USGS"
        case .deAfricaCrop: "DE Africa"
        case .deaLandCover: "GA/DEA"
        case .mexicoMadmex: "CONABIO"
        case .indiaBhuvan: "NRSC/ISRO"
        case .turkeyCorine: "EEA/Copernicus"
        case .indonesiaKlhk: "KLHK"
        case .waporLCC: "FAO"
        case .walloniaAgriculture: "SPW"
        case .nibioNorway: "NIBIO"
        case .esaWorldCover: "ESA/Copernicus"
        case .gladCropland: "UMD/GLAD"
        case .dynamicWorld: "Esri/IO"
        case .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals: "ESA/VITO"
        case .copernicusLandCover: "ESA/Copernicus"
        case .fromGLC: "UMD/GLAD"
        case .mapBiomas: "MapBiomas"
        }
    }

    /// Coverage region as (center lat, center lon, span lat, span lon)
    var coverageRegion: (lat: Double, lon: Double, latSpan: Double, lonSpan: Double)? {
        switch self {
        case .none, .geoglamMajorityCrop, .geoglam: nil
        case .usdaCDL: (39.0, -98.0, 30.0, 60.0)
        case .jrcEUCropMap: (50.0, 15.0, 30.0, 50.0)
        case .cromeEngland: (52.5, -1.5, 8.0, 8.0)
        case .dlrCropTypes: (51.0, 10.5, 8.0, 12.0)
        case .rpgFrance: (46.5, 2.5, 10.0, 12.0)
        case .brpNetherlands: (52.2, 5.3, 3.5, 4.0)
        case .aafcCanada: (55.0, -100.0, 30.0, 60.0)
        case .invekosAustria: (47.5, 13.3, 4.0, 9.0)
        case .alvFlanders: (51.0, 4.5, 2.5, 4.5)
        case .sigpacSpain: (40.0, -3.5, 8.0, 14.0)
        case .fvmDenmark: (56.0, 10.0, 4.0, 10.0)
        case .lpisCzechia: (49.7, 15.4, 4.0, 8.0)
        case .gerkSlovenia: (46.1, 15.0, 2.0, 4.0)
        case .arkodCroatia: (44.5, 16.5, 5.0, 7.0)
        case .gsaaEstonia: (58.6, 25.0, 3.0, 7.0)
        case .latviaFieldBlocks: (56.9, 24.6, 3.0, 8.0)
        case .ifapPortugal: (39.5, -8.0, 8.0, 7.0)
        case .lpisPoland: (52.0, 19.0, 8.0, 15.0)
        case .jordbrukSweden: (62.0, 17.0, 15.0, 15.0)
        case .flikLuxembourg: (49.8, 6.1, 1.0, 1.0)
        case .blwSwitzerland: (46.8, 8.2, 3.0, 5.0)
        case .abaresAustralia: (-26.0, 134.0, 40.0, 60.0)
        case .lcdbNewZealand: (-41.0, 173.0, 15.0, 17.0)
        case .geoIntaArgentina: (-32.0, -62.0, 20.0, 15.0)
        case .nalcms: (49.0, -110.0, 70.0, 120.0)
        case .deAfricaCrop: (1.5, 17.0, 73.0, 70.0)
        case .deaLandCover: (-26.0, 134.0, 40.0, 60.0)
        case .mexicoMadmex: (23.6, -102.6, 18.2, 31.8)
        case .indiaBhuvan: (21.5, 82.8, 31.0, 29.5)
        case .turkeyCorine: (39.0, 35.5, 6.0, 19.0)
        case .indonesiaKlhk: (-2.5, 118.0, 17.0, 46.0)
        case .waporLCC: (2.5, 18.5, 75.0, 73.0)
        case .walloniaAgriculture: (50.2, 4.8, 2.0, 3.5)
        case .nibioNorway: (65.0, 15.0, 20.0, 20.0)
        case .esaWorldCover, .gladCropland, .dynamicWorld, .worldCereal,
             .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals,
             .copernicusLandCover, .fromGLC, .modisLandCover, .gfsadCropland: nil
        case .mapBiomas: (-15.0, -55.0, 40.0, 40.0)
        }
    }

    /// Whether this source has data at the given coordinate (global sources always return true)
    func covers(latitude: Double, longitude: Double) -> Bool {
        guard let r = coverageRegion else { return true }
        return latitude >= r.lat - r.latSpan / 2 && latitude <= r.lat + r.latSpan / 2 &&
               longitude >= r.lon - r.lonSpan / 2 && longitude <= r.lon + r.lonSpan / 2
    }

    /// Whether this source is relevant at the given coordinate (wider than covers(), for menu filtering)
    func isRelevantAt(latitude: Double, longitude: Double) -> Bool {
        guard let r = coverageRegion else { return true }
        let padding = 15.0
        return latitude >= r.lat - r.latSpan / 2 - padding && latitude <= r.lat + r.latSpan / 2 + padding &&
               longitude >= r.lon - r.lonSpan / 2 - padding && longitude <= r.lon + r.lonSpan / 2 + padding
    }

    /// Best available crop map for a location (no exclusion). Used by auto-best-map.
    static func bestSource(at latitude: Double, longitude: Double) -> CropMapSource? {
        let candidates: [CropMapSource] = [
            .cromeEngland(year: 2024),
            .dlrCropTypes,
            .rpgFrance,
            .brpNetherlands,
            .invekosAustria,
            .alvFlanders,
            .sigpacSpain,
            .fvmDenmark,
            .lpisCzechia,
            .gerkSlovenia,
            .arkodCroatia,
            .gsaaEstonia,
            .latviaFieldBlocks,
            .ifapPortugal,
            .lpisPoland,
            .jordbrukSweden,
            .flikLuxembourg,
            .blwSwitzerland,
            .walloniaAgriculture(year: 2023),
            .nibioNorway,
            .abaresAustralia,
            .deaLandCover(year: 2020),
            .lcdbNewZealand,
            .geoIntaArgentina,
            .mexicoMadmex(year: 2018),
            .indiaBhuvan,
            .indonesiaKlhk,
            .turkeyCorine,
            .usdaCDL(year: 2023),
            .aafcCanada(year: 2024),
            .nalcms,
            .mapBiomas(year: 2020),
            .deAfricaCrop,
            .waporLCC,
            .jrcEUCropMap(year: 2022),
            .esaWorldCover(year: 2021),
            .geoglamMajorityCrop,
        ]
        return candidates.first {
            $0.covers(latitude: latitude, longitude: longitude) && $0.isAvailable
        }
    }

    /// Best available crop map for a location, excluding the current source.
    /// Prefers detailed regional sources, falls back to global.
    static func bestSource(at latitude: Double, longitude: Double, excluding current: CropMapSource) -> CropMapSource? {
        let candidates: [CropMapSource] = [
            .cromeEngland(year: 2024),
            .dlrCropTypes,
            .rpgFrance,
            .brpNetherlands,
            .invekosAustria,
            .alvFlanders,
            .sigpacSpain,
            .fvmDenmark,
            .lpisCzechia,
            .gerkSlovenia,
            .arkodCroatia,
            .gsaaEstonia,
            .latviaFieldBlocks,
            .ifapPortugal,
            .lpisPoland,
            .jordbrukSweden,
            .flikLuxembourg,
            .blwSwitzerland,
            .walloniaAgriculture(year: 2023),
            .nibioNorway,
            .abaresAustralia,
            .deaLandCover(year: 2020),
            .lcdbNewZealand,
            .geoIntaArgentina,
            .mexicoMadmex(year: 2018),
            .indiaBhuvan,
            .indonesiaKlhk,
            .turkeyCorine,
            .usdaCDL(year: 2023),
            .aafcCanada(year: 2024),
            .nalcms,
            .mapBiomas(year: 2020),
            .deAfricaCrop,
            .waporLCC,
            .jrcEUCropMap(year: 2022),
            .esaWorldCover(year: 2021),
            .geoglamMajorityCrop,
        ]
        return candidates.first {
            $0.covers(latitude: latitude, longitude: longitude) &&
            $0.isAvailable &&
            $0.sourceName != current.sourceName
        }
    }

    func withYear(_ year: Int) -> CropMapSource {
        switch self {
        case .usdaCDL: .usdaCDL(year: year)
        case .jrcEUCropMap: .jrcEUCropMap(year: year)
        case .cromeEngland: .cromeEngland(year: year)
        case .aafcCanada: .aafcCanada(year: year)
        case .modisLandCover: .modisLandCover(year: year)
        case .deaLandCover: .deaLandCover(year: year)
        case .mexicoMadmex: .mexicoMadmex(year: year)
        case .walloniaAgriculture: .walloniaAgriculture(year: year)
        case .esaWorldCover: .esaWorldCover(year: year)
        case .gladCropland: .gladCropland(year: year)
        case .mapBiomas: .mapBiomas(year: year)
        default: self
        }
    }

    /// Snap to the closest available year for this source.
    /// Returns self unchanged if no year range exists.
    func withClosestYear(_ target: Int) -> CropMapSource {
        guard let range = availableYears else { return self }
        let clamped = min(max(target, range.lowerBound), range.upperBound)
        return withYear(clamped)
    }

    /// Reconstruct from the persisted id string
    static func from(id: String) -> CropMapSource? {
        switch id {
        case "none": return CropMapSource.none
        case "geoglam_majority": return .geoglamMajorityCrop
        case "dlr_croptypes": return .dlrCropTypes
        case "rpg_france": return .rpgFrance
        case "brp_netherlands": return .brpNetherlands
        case "worldcereal": return .worldCereal
        case "worldcereal_maize": return .worldCerealMaize
        case "worldcereal_wintercereals": return .worldCerealWinterCereals
        case "worldcereal_springcereals": return .worldCerealSpringCereals
        case "dynamic_world": return .dynamicWorld
        case "copernicus_lc": return .copernicusLandCover
        case "from_glc": return .fromGLC
        case "invekos_austria": return .invekosAustria
        case "alv_flanders": return .alvFlanders
        case "sigpac_spain": return .sigpacSpain
        case "fvm_denmark": return .fvmDenmark
        case "lpis_czechia": return .lpisCzechia
        case "gerk_slovenia": return .gerkSlovenia
        case "arkod_croatia": return .arkodCroatia
        case "gsaa_estonia": return .gsaaEstonia
        case "latvia_field_blocks": return .latviaFieldBlocks
        case "ifap_portugal": return .ifapPortugal
        case "lpis_poland": return .lpisPoland
        case "jordbruk_sweden": return .jordbrukSweden
        case "flik_luxembourg": return .flikLuxembourg
        case "blw_switzerland": return .blwSwitzerland
        case "abares_australia": return .abaresAustralia
        case "lcdb_newzealand": return .lcdbNewZealand
        case "geointa_argentina": return .geoIntaArgentina
        case "gfsad_cropland": return .gfsadCropland
        case "nalcms": return .nalcms
        case "deafrica_crop": return .deAfricaCrop
        case "india_bhuvan": return .indiaBhuvan
        case "turkey_corine": return .turkeyCorine
        case "indonesia_klhk": return .indonesiaKlhk
        case "wapor_lcc": return .waporLCC
        case "nibio_norway": return .nibioNorway
        default: break
        }
        if id.hasPrefix("geoglam_") {
            let cropName = String(id.dropFirst("geoglam_".count))
            if let crop = GEOGLAMCrop.allCases.first(where: { $0.rawValue == cropName }) {
                return .geoglam(crop)
            }
        }
        if id.hasPrefix("usda_cdl_"), let y = Int(id.dropFirst("usda_cdl_".count)) { return .usdaCDL(year: y) }
        if id.hasPrefix("jrc_eucropmap_"), let y = Int(id.dropFirst("jrc_eucropmap_".count)) { return .jrcEUCropMap(year: y) }
        if id.hasPrefix("crome_"), let y = Int(id.dropFirst("crome_".count)) { return .cromeEngland(year: y) }
        if id.hasPrefix("aafc_"), let y = Int(id.dropFirst("aafc_".count)) { return .aafcCanada(year: y) }
        if id.hasPrefix("esa_worldcover_"), let y = Int(id.dropFirst("esa_worldcover_".count)) { return .esaWorldCover(year: y) }
        if id.hasPrefix("glad_"), let y = Int(id.dropFirst("glad_".count)) { return .gladCropland(year: y) }
        if id.hasPrefix("mapbiomas_"), let y = Int(id.dropFirst("mapbiomas_".count)) { return .mapBiomas(year: y) }
        if id.hasPrefix("modis_landcover_"), let y = Int(id.dropFirst("modis_landcover_".count)) { return .modisLandCover(year: y) }
        if id.hasPrefix("dea_landcover_"), let y = Int(id.dropFirst("dea_landcover_".count)) { return .deaLandCover(year: y) }
        if id.hasPrefix("mexico_madmex_"), let y = Int(id.dropFirst("mexico_madmex_".count)) { return .mexicoMadmex(year: y) }
        if id.hasPrefix("wallonia_"), let y = Int(id.dropFirst("wallonia_".count)) { return .walloniaAgriculture(year: y) }
        return nil
    }

    static var allSources: [CropMapSource] {
        var sources: [CropMapSource] = [.none, .geoglamMajorityCrop]
        for crop in GEOGLAMCrop.allCases { sources.append(.geoglam(crop)) }
        sources.append(contentsOf: [
            .usdaCDL(year: 2023), .jrcEUCropMap(year: 2022),
            .cromeEngland(year: 2024), .dlrCropTypes, .rpgFrance, .brpNetherlands, .aafcCanada(year: 2024),
            .invekosAustria, .alvFlanders, .sigpacSpain, .fvmDenmark, .lpisCzechia,
            .gerkSlovenia, .arkodCroatia, .gsaaEstonia, .latviaFieldBlocks,
            .ifapPortugal, .lpisPoland, .jordbrukSweden, .flikLuxembourg, .blwSwitzerland,
            .abaresAustralia, .lcdbNewZealand, .geoIntaArgentina,
            .modisLandCover(year: 2023), .gfsadCropland, .nalcms,
            .deAfricaCrop, .deaLandCover(year: 2020), .mexicoMadmex(year: 2018),
            .indiaBhuvan, .turkeyCorine, .indonesiaKlhk, .waporLCC,
            .walloniaAgriculture(year: 2023), .nibioNorway,
            .esaWorldCover(year: 2021), .gladCropland(year: 2020),
            .dynamicWorld, .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals,
            .copernicusLandCover, .fromGLC, .mapBiomas(year: 2020),
        ])
        return sources
    }
}

// MARK: - Credential type

enum CredentialType: Sendable {
    case apiKey
    case usernamePassword
    case none
}

// MARK: - API Key Providers

enum APIKeyProvider: String, CaseIterable, Sendable {
    case googleEarthEngine = "Google Earth Engine"
    case copernicus = "Copernicus Data Space"
    case planetaryComputer = "Planetary Computer"
    case nasaEarthdata = "NASA Earthdata"
    case aws = "AWS (Element84)"
    case osDataHub = "OS Data Hub"

    var credentialType: CredentialType {
        switch self {
        case .googleEarthEngine: .apiKey
        case .copernicus: .usernamePassword
        case .planetaryComputer: .apiKey
        case .nasaEarthdata: .usernamePassword
        case .aws: .none
        case .osDataHub: .apiKey
        }
    }

    var credentialKeys: [String] {
        switch self {
        case .googleEarthEngine: ["gee.serviceaccount"]
        case .copernicus: ["cdse.username", "cdse.password"]
        case .planetaryComputer: ["planetary.apikey"]
        case .nasaEarthdata: ["earthdata.username", "earthdata.password"]
        case .aws: []
        case .osDataHub: ["osdatahub.apikey"]
        }
    }

    var signupURL: String {
        switch self {
        case .googleEarthEngine: "https://console.cloud.google.com/apis/credentials"
        case .copernicus: "https://documentation.dataspace.copernicus.eu/APIs/Token.html"
        case .planetaryComputer: "https://planetarycomputer.microsoft.com/docs/quickstarts/reading-stac/"
        case .nasaEarthdata: "https://urs.earthdata.nasa.gov/profile"
        case .aws: "https://earth-search.aws.element84.com/v1"
        case .osDataHub: "https://osdatahub.os.uk/projects"
        }
    }

    var registrationURL: String {
        switch self {
        case .googleEarthEngine: "https://code.earthengine.google.com/register"
        case .copernicus: "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/auth?client_id=cdse-public&response_type=code&scope=openid&redirect_uri=https%3A//dataspace.copernicus.eu/account/confirmed/1883"
        case .planetaryComputer: "https://planetarycomputer.microsoft.com"
        case .nasaEarthdata: "https://urs.earthdata.nasa.gov/users/new"
        case .aws: "https://earth-search.aws.element84.com/v1"
        case .osDataHub: "https://osdatahub.os.uk/projects"
        }
    }

    var documentationURL: String {
        switch self {
        case .googleEarthEngine: "https://developers.google.com/earth-engine/guides/service_account"
        case .copernicus: "https://documentation.dataspace.copernicus.eu/APIs/OData.html"
        case .planetaryComputer: "https://planetarycomputer.microsoft.com/docs/quickstarts/reading-stac/"
        case .nasaEarthdata: "https://www.earthdata.nasa.gov/learn/get-started"
        case .aws: "https://stacindex.org/catalogs/earth-search"
        case .osDataHub: "https://osdatahub.os.uk/docs/wfs/overview"
        }
    }

    var instructions: String {
        switch self {
        case .googleEarthEngine: """
            1. [Register for Earth Engine](https://code.earthengine.google.com/register) (requires a Google account)

            2. Go to [Google Cloud Console](https://console.cloud.google.com)

            3. Create a new project (or select existing)

            4. Enable the "Earth Engine API": APIs & Services → Library → search "Earth Engine" → Enable

            5. Create a Service Account: APIs & Services → Credentials → Create Credentials → Service Account → name it → Done

            6. Create a key for the service account: Click the service account → Keys tab → Add Key → Create new key → JSON → Download the JSON file

            7. Copy the entire JSON content and paste it as your API key below
            """
        case .copernicus: """
            1. [Register at Copernicus Data Space](https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/auth?client_id=cdse-public&response_type=code&scope=openid&redirect_uri=https%3A//dataspace.copernicus.eu/account/confirmed/1883) — click "Register" on the login page

            2. Fill in the form, accept terms, and click Register

            3. Check your email and click "Verify email address"

            4. Enter your CDSE username (email) and password below — the app will generate access tokens automatically when needed

            See [Token documentation](https://documentation.dataspace.copernicus.eu/APIs/Token.html) for details.
            """
        case .planetaryComputer: """
            **No API key is needed for basic access.** Sentinel-2, Landsat, and other public datasets work without a subscription key.

            If you have a subscription key, paste it below. Otherwise, leave this blank — the app will work without one.
            """
        case .nasaEarthdata: """
            1. [Create an Earthdata account](https://urs.earthdata.nasa.gov/users/new) — registration is free

            2. After registering, go to your [profile](https://urs.earthdata.nasa.gov/profile) and note your username

            3. Enter your Earthdata username and password below — the app will generate bearer tokens automatically

            Required for: HLS (Harmonized Landsat Sentinel-2), MODIS, VIIRS, and other NASA LP DAAC products
            """
        case .aws: """
            No credentials are needed. AWS Earth Search (Element84) provides free public access to Sentinel-2 L2A, Landsat, and other collections via STAC.

            Data endpoint: [earth-search.aws.element84.com/v1](https://earth-search.aws.element84.com/v1)
            """
        case .osDataHub: """
            1. Go to [OS Data Hub](https://osdatahub.os.uk) and sign in (or register)

            2. Go to [API Projects](https://osdatahub.os.uk/projects) and create or select a project

            3. Add the **OS Features API** to your project

            4. Copy the **Project API Key** and paste it below
            """
        }
    }

    var registrationHint: String {
        switch self {
        case .googleEarthEngine:
            "You need a Google account. Earth Engine registration is free for research and non-commercial use."
        case .copernicus:
            "Registration is free. Click the avatar icon in the top right, then tap Register."
        case .planetaryComputer:
            "No key needed for public data. Optional subscription key for higher rate limits."
        case .nasaEarthdata:
            "Registration is free. You will need a username and password."
        case .aws:
            "No registration required. Public access to Sentinel-2, Landsat, and more."
        case .osDataHub:
            "Free tier includes 1000 transactions/month. Create a project at osdatahub.os.uk."
        }
    }

    var usedBy: String {
        switch self {
        case .googleEarthEngine: "Dynamic World, FROM-GLC"
        case .copernicus: "Copernicus Land Cover, Sentinel-2 (CDSE)"
        case .planetaryComputer: "Sentinel-2, Landsat (Planetary Computer)"
        case .nasaEarthdata: "HLS, MODIS, VIIRS (NASA LP DAAC)"
        case .aws: "Sentinel-2, Landsat (Element84 Earth Search)"
        case .osDataHub: "OS Field Boundaries overlay"
        }
    }
}
