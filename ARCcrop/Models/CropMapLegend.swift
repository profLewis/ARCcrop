import SwiftUI

struct LegendEntry: Identifiable, Sendable {
    let color: Color
    let label: String
    var id: String { label }
}

struct CropMapLegendData: Sendable {
    let title: String
    let entries: [LegendEntry]

    static func forSource(_ source: CropMapSource) -> CropMapLegendData? {
        switch source {
        case .none:
            return nil

        case .geoglamMajorityCrop:
            return CropMapLegendData(
                title: "GEOGLAM Majority Crop",
                entries: [
                    LegendEntry(color: Color(red: 0.64, green: 0.52, blue: 0.37), label: "Winter Wheat"),
                    LegendEntry(color: .orange, label: "Spring Wheat"),
                    LegendEntry(color: Color(red: 1.0, green: 0.8, blue: 0.0), label: "Maize"),
                    LegendEntry(color: Color(red: 0.2, green: 0.78, blue: 0.35), label: "Soybean"),
                    LegendEntry(color: Color(red: 0.2, green: 0.68, blue: 0.9), label: "Rice"),
                ]
            )

        case .geoglam(let crop):
            return CropMapLegendData(
                title: "GEOGLAM \(crop.rawValue)",
                entries: [
                    LegendEntry(color: crop.color.opacity(0.2), label: "< 20%"),
                    LegendEntry(color: crop.color.opacity(0.4), label: "20-40%"),
                    LegendEntry(color: crop.color.opacity(0.6), label: "40-60%"),
                    LegendEntry(color: crop.color.opacity(0.8), label: "60-80%"),
                    LegendEntry(color: crop.color, label: "> 80%"),
                ]
            )

        case .usdaCDL:
            // Official USDA CropScape palette
            return CropMapLegendData(
                title: "USDA CDL",
                entries: [
                    LegendEntry(color: Color(red: 255/255, green: 212/255, blue: 0/255), label: "Corn"),            // #FFD400
                    LegendEntry(color: Color(red: 38/255, green: 115/255, blue: 0/255), label: "Soybeans"),          // #267300
                    LegendEntry(color: Color(red: 168/255, green: 112/255, blue: 0/255), label: "Winter Wheat"),     // #A87000
                    LegendEntry(color: Color(red: 217/255, green: 181/255, blue: 108/255), label: "Spring Wheat"),   // #D9B56C
                    LegendEntry(color: Color(red: 0/255, green: 169/255, blue: 230/255), label: "Rice"),             // #00A9E6
                    LegendEntry(color: Color(red: 255/255, green: 38/255, blue: 38/255), label: "Cotton"),           // #FF2626
                    LegendEntry(color: Color(red: 255/255, green: 158/255, blue: 15/255), label: "Sorghum"),         // #FF9E0F
                    LegendEntry(color: Color(red: 233/255, green: 255/255, blue: 190/255), label: "Grass/Pasture"),  // #E9FFBE
                    LegendEntry(color: Color(red: 149/255, green: 206/255, blue: 147/255), label: "Forest"),         // #95CE93
                    LegendEntry(color: Color(red: 156/255, green: 156/255, blue: 156/255), label: "Developed"),      // #9C9C9C
                ]
            )

        case .jrcEUCropMap:
            return CropMapLegendData(
                title: "JRC EU Crop Map",
                entries: [
                    // #ff130f Artificial
                    LegendEntry(color: Color(red: 1.0, green: 0.075, blue: 0.059), label: "Artificial"),
                    // #a57000 Common wheat
                    LegendEntry(color: Color(red: 0.647, green: 0.439, blue: 0.0), label: "Common Wheat"),
                    // #896054 Durum wheat
                    LegendEntry(color: Color(red: 0.537, green: 0.376, blue: 0.329), label: "Durum Wheat"),
                    // #e2007c Barley
                    LegendEntry(color: Color(red: 0.886, green: 0.0, blue: 0.486), label: "Barley"),
                    // #aa007c Rye
                    LegendEntry(color: Color(red: 0.667, green: 0.0, blue: 0.486), label: "Rye"),
                    // #a05989 Oats
                    LegendEntry(color: Color(red: 0.627, green: 0.349, blue: 0.537), label: "Oats"),
                    // #ffd300 Maize
                    LegendEntry(color: Color(red: 1.0, green: 0.827, blue: 0.0), label: "Maize"),
                    // #00a8e2 Rice
                    LegendEntry(color: Color(red: 0.0, green: 0.659, blue: 0.886), label: "Rice"),
                    // #d69ebc Triticale / Other cereals
                    LegendEntry(color: Color(red: 0.839, green: 0.620, blue: 0.737), label: "Triticale"),
                    // #dda50a Potatoes
                    LegendEntry(color: Color(red: 0.867, green: 0.647, blue: 0.039), label: "Potatoes"),
                    // #a800e2 Sugar beet
                    LegendEntry(color: Color(red: 0.659, green: 0.0, blue: 0.886), label: "Sugar Beet"),
                    // #00af49 Other root / industrial crops
                    LegendEntry(color: Color(red: 0.0, green: 0.686, blue: 0.286), label: "Other Crops"),
                    // #ffff00 Sunflower
                    LegendEntry(color: Color(red: 1.0, green: 1.0, blue: 0.0), label: "Sunflower"),
                    // #d1ff00 Rapeseed
                    LegendEntry(color: Color(red: 0.820, green: 1.0, blue: 0.0), label: "Rapeseed"),
                    // #267000 Soya
                    LegendEntry(color: Color(red: 0.149, green: 0.439, blue: 0.0), label: "Soya"),
                    // #f2a377 Dry pulses
                    LegendEntry(color: Color(red: 0.949, green: 0.639, blue: 0.467), label: "Dry Pulses"),
                    // #e8bfff Fodder crops
                    LegendEntry(color: Color(red: 0.910, green: 0.749, blue: 1.0), label: "Fodder Crops"),
                    // #696969 Bare arable land
                    LegendEntry(color: Color(red: 0.412, green: 0.412, blue: 0.412), label: "Bare Arable"),
                    // #93cc93 Woodland & Shrubland
                    LegendEntry(color: Color(red: 0.576, green: 0.800, blue: 0.576), label: "Woodland"),
                    // #e8ffbf Grasslands
                    LegendEntry(color: Color(red: 0.910, green: 1.0, blue: 0.749), label: "Grasslands"),
                    // #a89e7f Bare land
                    LegendEntry(color: Color(red: 0.659, green: 0.620, blue: 0.498), label: "Bare Land"),
                    // #0793de Water
                    LegendEntry(color: Color(red: 0.027, green: 0.576, blue: 0.871), label: "Water"),
                    // #7cafaf Wetlands
                    LegendEntry(color: Color(red: 0.486, green: 0.686, blue: 0.686), label: "Wetlands"),
                ]
            )

        case .cromeEngland:
            // Official DEFRA CROME GetLegendGraphic palette
            return CropMapLegendData(
                title: "CROME England",
                entries: [
                    LegendEntry(color: Color(red: 0xA5/255, green: 0x70/255, blue: 0x00/255), label: "Winter Wheat"),    // #A57000
                    LegendEntry(color: Color(red: 0xDA/255, green: 0xE3/255, blue: 0x1B/255), label: "Barley"),          // #DAE31B
                    LegendEntry(color: Color(red: 0xA1/255, green: 0x59/255, blue: 0x89/255), label: "Oats"),            // #A15989
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xFF/255, blue: 0x00/255), label: "Oilseed Rape"),    // #FFFF00
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xD3/255, blue: 0x00/255), label: "Maize"),           // #FFD300
                    LegendEntry(color: Color(red: 0x70/255, green: 0x26/255, blue: 0x01/255), label: "Potatoes"),        // #702601
                    LegendEntry(color: Color(red: 0x6F/255, green: 0x55/255, blue: 0xCA/255), label: "Sugar Beet"),      // #6F55CA
                    LegendEntry(color: Color(red: 0x82/255, green: 0x65/255, blue: 0x49/255), label: "Field Beans"),     // #826549
                    LegendEntry(color: Color(red: 0x54/255, green: 0xFF/255, blue: 0x00/255), label: "Peas"),            // #54FF00
                    LegendEntry(color: Color(red: 0xE9/255, green: 0xFF/255, blue: 0xBF/255), label: "Grass"),           // #E9FFBF
                    LegendEntry(color: Color(red: 0xBF/255, green: 0xBF/255, blue: 0xBF/255), label: "Fallow"),          // #BFBFBF
                ]
            )

        case .dlrCropTypes:
            // Official DLR EOC GetLegendGraphic palette
            return CropMapLegendData(
                title: "DLR CropTypes",
                entries: [
                    LegendEntry(color: Color(red: 0x00/255, green: 0x70/255, blue: 0xFF/255), label: "Winter Wheat"),    // #0070FF
                    LegendEntry(color: Color(red: 0x73/255, green: 0xDF/255, blue: 0xFF/255), label: "Winter Barley"),   // #73DFFF
                    LegendEntry(color: Color(red: 0x73/255, green: 0xB2/255, blue: 0xFF/255), label: "Winter Rye"),      // #73B2FF
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xFF/255, blue: 0x73/255), label: "Rapeseed"),        // #FFFF73
                    LegendEntry(color: Color(red: 0xE6/255, green: 0x98/255, blue: 0x00/255), label: "Spring Barley"),   // #E69800
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xAA/255, blue: 0x00/255), label: "Spring Oats"),     // #FFAA00
                    LegendEntry(color: Color(red: 0xE6/255, green: 0x00/255, blue: 0xA9/255), label: "Maize"),           // #E600A9
                    LegendEntry(color: Color(red: 0x84/255, green: 0x00/255, blue: 0xA8/255), label: "Sugar Beet"),      // #8400A8
                    LegendEntry(color: Color(red: 0xA8/255, green: 0x70/255, blue: 0x00/255), label: "Potatoes"),        // #A87000
                    LegendEntry(color: Color(red: 0x70/255, green: 0xA8/255, blue: 0x00/255), label: "Permanent Grass"), // #70A800
                ]
            )

        case .rpgFrance:
            // Approximate — IGN Géoplateforme WMS does not expose SLD
            return CropMapLegendData(
                title: "RPG France",
                entries: [
                    LegendEntry(color: Color(red: 0.85, green: 0.65, blue: 0.13), label: "Cereals"),
                    LegendEntry(color: Color(red: 0.8, green: 0.73, blue: 0.0), label: "Oilseeds"),
                    LegendEntry(color: Color(red: 0.2, green: 0.6, blue: 0.2), label: "Protein Crops"),
                    LegendEntry(color: Color(red: 0.5, green: 0.0, blue: 0.5), label: "Vineyards"),
                    LegendEntry(color: Color(red: 0.0, green: 0.5, blue: 0.0), label: "Orchards"),
                    LegendEntry(color: Color(red: 0.6, green: 0.8, blue: 0.2), label: "Grassland"),
                ]
            )

        case .brpNetherlands:
            // PDOK WMS default style — styled by category (gewasgroep)
            return CropMapLegendData(
                title: "BRP Netherlands",
                entries: [
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xFF/255, blue: 0xBE/255), label: "Bouwland (Arable)"),      // #FFFFBE
                    LegendEntry(color: Color(red: 0xA3/255, green: 0xFF/255, blue: 0x73/255), label: "Grasland (Grassland)"),    // #A3FF73
                    LegendEntry(color: Color(red: 0x38/255, green: 0xA8/255, blue: 0x00/255), label: "Overige (Other)"),         // #38A800
                    LegendEntry(color: Color(red: 0xD7/255, green: 0xC2/255, blue: 0x9E/255), label: "Landschap (Landscape)"),   // #D7C29E
                ]
            )

        case .aafcCanada:
            // Official AAFC Annual Crop Inventory palette (Earth Engine)
            return CropMapLegendData(
                title: "AAFC Canada",
                entries: [
                    LegendEntry(color: Color(red: 0xA7/255, green: 0xB3/255, blue: 0x4D/255), label: "Wheat"),         // #A7B34D
                    LegendEntry(color: Color(red: 0xD6/255, green: 0xFF/255, blue: 0x70/255), label: "Canola"),         // #D6FF70
                    LegendEntry(color: Color(red: 0xDA/255, green: 0xE3/255, blue: 0x1D/255), label: "Barley"),         // #DAE31D
                    LegendEntry(color: Color(red: 0xCC/255, green: 0x99/255, blue: 0x33/255), label: "Soybeans"),       // #CC9933
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xFF/255, blue: 0x99/255), label: "Corn"),           // #FFFF99
                    LegendEntry(color: Color(red: 0xB7/255, green: 0x4B/255, blue: 0x15/255), label: "Lentils"),        // #B74B15
                    LegendEntry(color: Color(red: 0x8F/255, green: 0x6C/255, blue: 0x3D/255), label: "Peas"),           // #8F6C3D
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xCC/255, blue: 0x33/255), label: "Pasture"),        // #FFCC33
                ]
            )

        // EU parcel maps — server-styled, no fixed legend
        case .invekosAustria, .alvFlanders, .sigpacSpain, .fvmDenmark, .lpisCzechia,
             .gerkSlovenia, .arkodCroatia, .gsaaEstonia, .latviaFieldBlocks,
             .ifapPortugal, .lpisPoland, .jordbrukSweden, .flikLuxembourg, .blwSwitzerland,
             .abaresAustralia, .lcdbNewZealand, .geoIntaArgentina:
            return nil

        case .esaWorldCover:
            // Official ESA WorldCover 2021 color palette
            return CropMapLegendData(
                title: "ESA WorldCover",
                entries: [
                    LegendEntry(color: Color(red: 0/255, green: 100/255, blue: 0/255), label: "Tree Cover"),         // #006400
                    LegendEntry(color: Color(red: 255/255, green: 187/255, blue: 34/255), label: "Shrubland"),        // #FFBB22
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 76/255), label: "Grassland"),        // #FFFF4C
                    LegendEntry(color: Color(red: 240/255, green: 150/255, blue: 255/255), label: "Cropland"),        // #F096FF
                    LegendEntry(color: Color(red: 250/255, green: 0/255, blue: 0/255), label: "Built-up"),            // #FA0000
                    LegendEntry(color: Color(red: 180/255, green: 180/255, blue: 180/255), label: "Bare/Sparse"),     // #B4B4B4
                    LegendEntry(color: Color(red: 0/255, green: 100/255, blue: 200/255), label: "Water"),             // #0064C8
                    LegendEntry(color: Color(red: 0/255, green: 150/255, blue: 160/255), label: "Wetland"),           // #0096A0
                    LegendEntry(color: Color(red: 0/255, green: 207/255, blue: 117/255), label: "Mangroves"),         // #00CF75
                    LegendEntry(color: Color(red: 250/255, green: 230/255, blue: 160/255), label: "Moss/Lichen"),     // #FAE6A0
                ]
            )

        case .dynamicWorld:
            return CropMapLegendData(
                title: "Dynamic World",
                entries: [
                    LegendEntry(color: Color(red: 0.0, green: 0.39, blue: 0.0), label: "Trees"),
                    LegendEntry(color: Color(red: 0.53, green: 0.81, blue: 0.31), label: "Grass"),
                    LegendEntry(color: Color(red: 0.55, green: 0.27, blue: 0.07), label: "Bare"),
                    LegendEntry(color: Color(red: 1.0, green: 0.82, blue: 0.0), label: "Crops"),
                    LegendEntry(color: Color(red: 0.68, green: 0.0, blue: 0.0), label: "Built"),
                    LegendEntry(color: Color(red: 0.0, green: 0.0, blue: 0.8), label: "Water"),
                ]
            )

        case .worldCereal:
            // Terrascope WMS WORLDCEREAL_TEMPORARYCROPS_V1 — binary crop mask
            return CropMapLegendData(
                title: "WorldCereal",
                entries: [
                    LegendEntry(color: Color(red: 224/255, green: 24/255, blue: 28/255), label: "Temporary Crops"),   // #E0181C
                ]
            )

        case .worldCerealMaize:
            return CropMapLegendData(
                title: "WorldCereal Maize",
                entries: [
                    LegendEntry(color: Color(red: 255/255, green: 211/255, blue: 0/255), label: "Maize"),   // #FFD300
                ]
            )

        case .worldCerealWinterCereals:
            return CropMapLegendData(
                title: "WorldCereal Winter Cereals",
                entries: [
                    LegendEntry(color: Color(red: 168/255, green: 112/255, blue: 0/255), label: "Winter Cereals"),   // #A87000
                ]
            )

        case .worldCerealSpringCereals:
            return CropMapLegendData(
                title: "WorldCereal Spring Cereals",
                entries: [
                    LegendEntry(color: Color(red: 0/255, green: 168/255, blue: 230/255), label: "Spring Cereals"),   // #00A8E6
                ]
            )

        case .gladCropland:
            return CropMapLegendData(
                title: "GLAD Cropland",
                entries: [
                    LegendEntry(color: Color(red: 1.0, green: 0.82, blue: 0.0), label: "Cropland"),
                    LegendEntry(color: Color(red: 0.0, green: 0.5, blue: 0.0), label: "Non-Cropland"),
                ]
            )

        case .copernicusLandCover:
            return CropMapLegendData(
                title: "Copernicus LC",
                entries: [
                    LegendEntry(color: .yellow, label: "Cropland"),
                    LegendEntry(color: .green, label: "Forest"),
                    LegendEntry(color: .brown, label: "Bare/Sparse"),
                    LegendEntry(color: .blue, label: "Water"),
                    LegendEntry(color: .gray, label: "Urban"),
                ]
            )

        case .fromGLC:
            return CropMapLegendData(
                title: "FROM-GLC",
                entries: [
                    LegendEntry(color: .yellow, label: "Cropland"),
                    LegendEntry(color: .green, label: "Forest"),
                    LegendEntry(color: .cyan, label: "Grassland"),
                    LegendEntry(color: .gray, label: "Other"),
                ]
            )

        case .mapBiomas:
            return CropMapLegendData(
                title: "MapBiomas",
                entries: [
                    LegendEntry(color: Color(red: 0.9, green: 0.8, blue: 0.3), label: "Soy"),
                    LegendEntry(color: Color(red: 0.8, green: 0.6, blue: 0.2), label: "Sugar Cane"),
                    LegendEntry(color: .green, label: "Forest"),
                    LegendEntry(color: Color(red: 0.6, green: 0.8, blue: 0.4), label: "Pasture"),
                ]
            )
        }
    }
}
