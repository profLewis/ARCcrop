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
            // Official USDA CropScape palette — all classes visible in tiles
            return CropMapLegendData(
                title: "USDA CDL",
                entries: [
                    // Major crops
                    LegendEntry(color: Color(red: 255/255, green: 212/255, blue: 0/255), label: "Corn"),              // #FFD400
                    LegendEntry(color: Color(red: 38/255, green: 115/255, blue: 0/255), label: "Soybeans"),            // #267300
                    LegendEntry(color: Color(red: 168/255, green: 112/255, blue: 0/255), label: "Winter Wheat"),       // #A87000
                    LegendEntry(color: Color(red: 217/255, green: 181/255, blue: 108/255), label: "Spring Wheat"),     // #D9B56C
                    LegendEntry(color: Color(red: 0/255, green: 169/255, blue: 230/255), label: "Rice"),               // #00A9E6
                    LegendEntry(color: Color(red: 255/255, green: 38/255, blue: 38/255), label: "Cotton"),             // #FF2626
                    LegendEntry(color: Color(red: 255/255, green: 158/255, blue: 15/255), label: "Sorghum"),           // #FF9E0F
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 0/255), label: "Sunflower"),          // #FFFF00
                    LegendEntry(color: Color(red: 112/255, green: 168/255, blue: 0/255), label: "Peanuts"),            // #70A800
                    LegendEntry(color: Color(red: 0/255, green: 175/255, blue: 77/255), label: "Tobacco/Other"),       // #00AF4D
                    LegendEntry(color: Color(red: 209/255, green: 255/255, blue: 0/255), label: "Canola"),             // #D1FF00
                    // Cereals
                    LegendEntry(color: Color(red: 226/255, green: 0/255, blue: 127/255), label: "Barley"),             // #E2007F
                    LegendEntry(color: Color(red: 174/255, green: 1/255, blue: 126/255), label: "Rye"),                // #AE017E
                    LegendEntry(color: Color(red: 161/255, green: 88/255, blue: 137/255), label: "Oats"),              // #A15889
                    LegendEntry(color: Color(red: 115/255, green: 0/255, blue: 76/255), label: "Millet"),              // #73004C
                    LegendEntry(color: Color(red: 214/255, green: 157/255, blue: 188/255), label: "Other Grains"),     // #D69DBC
                    LegendEntry(color: Color(red: 115/255, green: 115/255, blue: 0/255), label: "Dbl Crop Wht/Soy"),   // #737300
                    // Hay & forage
                    LegendEntry(color: Color(red: 255/255, green: 168/255, blue: 227/255), label: "Alfalfa"),          // #FFA8E3
                    LegendEntry(color: Color(red: 165/255, green: 245/255, blue: 141/255), label: "Other Hay"),        // #A5F58D
                    LegendEntry(color: Color(red: 232/255, green: 190/255, blue: 255/255), label: "Clover"),           // #E8BEFF
                    LegendEntry(color: Color(red: 178/255, green: 255/255, blue: 222/255), label: "Sod/Grass Seed"),   // #B2FFDE
                    // Pulses & specialty
                    LegendEntry(color: Color(red: 168/255, green: 0/255, blue: 0/255), label: "Dry Beans"),            // #A80000
                    LegendEntry(color: Color(red: 85/255, green: 255/255, blue: 0/255), label: "Peas"),                // #55FF00
                    LegendEntry(color: Color(red: 128/255, green: 212/255, blue: 255/255), label: "Mint/Herbs"),       // #80D4FF
                    LegendEntry(color: Color(red: 255/255, green: 102/255, blue: 102/255), label: "Vegs & Fruits"),    // #FF6666
                    LegendEntry(color: Color(red: 182/255, green: 112/255, blue: 92/255), label: "Pecans"),            // #B6705C
                    // Land cover
                    LegendEntry(color: Color(red: 233/255, green: 255/255, blue: 190/255), label: "Grass/Pasture"),    // #E9FFBE
                    LegendEntry(color: Color(red: 191/255, green: 191/255, blue: 122/255), label: "Fallow/Idle"),      // #BFBF7A
                    LegendEntry(color: Color(red: 149/255, green: 206/255, blue: 147/255), label: "Forest"),           // #95CE93
                    LegendEntry(color: Color(red: 199/255, green: 215/255, blue: 158/255), label: "Shrubland"),        // #C7D79E
                    LegendEntry(color: Color(red: 204/255, green: 191/255, blue: 163/255), label: "Barren"),           // #CCBFA3
                    LegendEntry(color: Color(red: 77/255, green: 112/255, blue: 163/255), label: "Water"),             // #4D70A3
                    LegendEntry(color: Color(red: 128/255, green: 179/255, blue: 179/255), label: "Wetlands"),         // #80B3B3
                    LegendEntry(color: Color(red: 156/255, green: 156/255, blue: 156/255), label: "Developed"),        // #9C9C9C
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
            // Official AAFC Annual Crop Inventory palette — full GEE catalog
            return CropMapLegendData(
                title: "AAFC Canada",
                entries: [
                    // Land cover
                    LegendEntry(color: Color(red: 0x33/255, green: 0x33/255, blue: 0xFF/255), label: "Water"),              // #3333FF
                    LegendEntry(color: Color(red: 0x99/255, green: 0x66/255, blue: 0x66/255), label: "Exposed Land"),       // #996666
                    LegendEntry(color: Color(red: 0xCC/255, green: 0x66/255, blue: 0x99/255), label: "Urban/Developed"),    // #CC6699
                    LegendEntry(color: Color(red: 0xE1/255, green: 0xE1/255, blue: 0xE1/255), label: "Greenhouses"),        // #E1E1E1
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xFF/255, blue: 0x00/255), label: "Shrubland"),          // #FFFF00
                    LegendEntry(color: Color(red: 0x99/255, green: 0x33/255, blue: 0x99/255), label: "Wetland"),            // #993399
                    LegendEntry(color: Color(red: 0x50/255, green: 0x1B/255, blue: 0x50/255), label: "Peatland"),           // #501B50
                    LegendEntry(color: Color(red: 0xCC/255, green: 0xCC/255, blue: 0x00/255), label: "Grassland"),          // #CCCC00
                    LegendEntry(color: Color(red: 0x66/255, green: 0x66/255, blue: 0x66/255), label: "Forest Fire/Burnt"),  // #666666
                    // Agriculture general
                    LegendEntry(color: Color(red: 0xCC/255, green: 0x66/255, blue: 0x00/255), label: "Agriculture"),        // #CC6600
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xCC/255, blue: 0x33/255), label: "Pasture/Forages"),    // #FFCC33
                    LegendEntry(color: Color(red: 0x78/255, green: 0x99/255, blue: 0xF6/255), label: "Too Wet to Seed"),    // #7899F6
                    LegendEntry(color: Color(red: 0xFF/255, green: 0x99/255, blue: 0x00/255), label: "Fallow"),             // #FF9900
                    // Cereals
                    LegendEntry(color: Color(red: 0xA7/255, green: 0xB3/255, blue: 0x4D/255), label: "Wheat"),             // #A7B34D
                    LegendEntry(color: Color(red: 0x80/255, green: 0x97/255, blue: 0x69/255), label: "Winter Wheat"),       // #809769
                    LegendEntry(color: Color(red: 0x92/255, green: 0xA5/255, blue: 0x5B/255), label: "Spring Wheat"),       // #92A55B
                    LegendEntry(color: Color(red: 0xDA/255, green: 0xE3/255, blue: 0x1D/255), label: "Barley"),             // #DAE31D
                    LegendEntry(color: Color(red: 0xD1/255, green: 0xD5/255, blue: 0x2B/255), label: "Oats"),              // #D1D52B
                    LegendEntry(color: Color(red: 0xCA/255, green: 0xCD/255, blue: 0x32/255), label: "Rye"),               // #CACD32
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xFF/255, blue: 0x99/255), label: "Corn"),               // #FFFF99
                    LegendEntry(color: Color(red: 0x99/255, green: 0x99/255, blue: 0x00/255), label: "Sorghum"),            // #999900
                    LegendEntry(color: Color(red: 0x99/255, green: 0xCC/255, blue: 0x00/255), label: "Other Grains"),       // #99CC00
                    // Oilseeds
                    LegendEntry(color: Color(red: 0xD6/255, green: 0xFF/255, blue: 0x70/255), label: "Canola/Rapeseed"),    // #D6FF70
                    LegendEntry(color: Color(red: 0x8C/255, green: 0x8C/255, blue: 0xFF/255), label: "Flaxseed"),           // #8C8CFF
                    LegendEntry(color: Color(red: 0xD6/255, green: 0xCC/255, blue: 0x00/255), label: "Mustard"),            // #D6CC00
                    LegendEntry(color: Color(red: 0x31/255, green: 0x54/255, blue: 0x91/255), label: "Sunflower"),          // #315491
                    LegendEntry(color: Color(red: 0xCC/255, green: 0x99/255, blue: 0x33/255), label: "Soybeans"),           // #CC9933
                    // Pulses
                    LegendEntry(color: Color(red: 0x8F/255, green: 0x6C/255, blue: 0x3D/255), label: "Peas"),              // #8F6C3D
                    LegendEntry(color: Color(red: 0xB6/255, green: 0xA4/255, blue: 0x72/255), label: "Chickpeas"),          // #B6A472
                    LegendEntry(color: Color(red: 0x82/255, green: 0x65/255, blue: 0x4A/255), label: "Beans"),              // #82654A
                    LegendEntry(color: Color(red: 0xA3/255, green: 0x90/255, blue: 0x69/255), label: "Fababeans"),          // #A39069
                    LegendEntry(color: Color(red: 0xB8/255, green: 0x59/255, blue: 0x00/255), label: "Lentils"),            // #B85900
                    // Specialty crops
                    LegendEntry(color: Color(red: 0xB7/255, green: 0x4B/255, blue: 0x15/255), label: "Vegetables"),         // #B74B15
                    LegendEntry(color: Color(red: 0xFF/255, green: 0xCC/255, blue: 0xCC/255), label: "Potatoes"),           // #FFCCCC
                    LegendEntry(color: Color(red: 0x6F/255, green: 0x55/255, blue: 0xCA/255), label: "Sugarbeets"),         // #6F55CA
                    LegendEntry(color: Color(red: 0xDC/255, green: 0x54/255, blue: 0x24/255), label: "Fruits"),             // #DC5424
                    LegendEntry(color: Color(red: 0xD2/255, green: 0x00/255, blue: 0x00/255), label: "Blueberry"),          // #D20000
                    LegendEntry(color: Color(red: 0xCC/255, green: 0x00/255, blue: 0x00/255), label: "Cranberry"),          // #CC0000
                    LegendEntry(color: Color(red: 0xFF/255, green: 0x66/255, blue: 0x66/255), label: "Orchards"),           // #FF6666
                    LegendEntry(color: Color(red: 0x74/255, green: 0x42/255, blue: 0xBD/255), label: "Vineyards"),          // #7442BD
                    LegendEntry(color: Color(red: 0x8E/255, green: 0x76/255, blue: 0x72/255), label: "Hemp"),               // #8E7672
                    LegendEntry(color: Color(red: 0xB5/255, green: 0xFB/255, blue: 0x05/255), label: "Sod"),               // #B5FB05
                    LegendEntry(color: Color(red: 0xCC/255, green: 0xFF/255, blue: 0x05/255), label: "Herbs"),              // #CCFF05
                    LegendEntry(color: Color(red: 0x74/255, green: 0x9A/255, blue: 0x66/255), label: "Other Crops"),        // #749A66
                    // Forest
                    LegendEntry(color: Color(red: 0x00/255, green: 0x99/255, blue: 0x00/255), label: "Forest"),             // #009900
                    LegendEntry(color: Color(red: 0x00/255, green: 0x66/255, blue: 0x00/255), label: "Coniferous"),         // #006600
                    LegendEntry(color: Color(red: 0x00/255, green: 0xCC/255, blue: 0x00/255), label: "Broadleaf"),          // #00CC00
                    LegendEntry(color: Color(red: 0xCC/255, green: 0x99/255, blue: 0x00/255), label: "Mixedwood"),          // #CC9900
                ]
            )

        // EU parcel maps — server-styled, no fixed legend
        case .invekosAustria, .alvFlanders, .sigpacSpain, .fvmDenmark, .lpisCzechia,
             .gerkSlovenia, .arkodCroatia, .gsaaEstonia, .latviaFieldBlocks,
             .ifapPortugal, .lpisPoland, .jordbrukSweden, .flikLuxembourg, .blwSwitzerland,
             .abaresAustralia, .lcdbNewZealand, .geoIntaArgentina,
             .walloniaAgriculture, .nibioNorway, .indiaBhuvan, .indonesiaKlhk:
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
                title: "Esri 10m Land Cover",
                entries: [
                    LegendEntry(color: Color(red: 65/255, green: 155/255, blue: 223/255), label: "Water"),          // #419BDF
                    LegendEntry(color: Color(red: 57/255, green: 125/255, blue: 73/255), label: "Trees"),            // #397D49
                    LegendEntry(color: Color(red: 228/255, green: 150/255, blue: 53/255), label: "Crops"),           // #E49635
                    LegendEntry(color: Color(red: 227/255, green: 226/255, blue: 195/255), label: "Rangeland"),      // #E3E2C3
                    LegendEntry(color: Color(red: 122/255, green: 135/255, blue: 198/255), label: "Flooded Veg"),    // #7A87C6
                    LegendEntry(color: Color(red: 196/255, green: 40/255, blue: 27/255), label: "Built Area"),       // #C4281B
                    LegendEntry(color: Color(red: 165/255, green: 155/255, blue: 143/255), label: "Bare Ground"),    // #A59B8F
                    LegendEntry(color: Color(red: 168/255, green: 235/255, blue: 255/255), label: "Snow/Ice"),       // #A8EBFF
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
                title: "GLAD GLCLUC",
                entries: [
                    LegendEntry(color: .yellow, label: "Cropland"),
                    LegendEntry(color: .green, label: "Forest"),
                    LegendEntry(color: .cyan, label: "Grassland"),
                    LegendEntry(color: .gray, label: "Other"),
                ]
            )

        case .modisLandCover:
            // Standard MODIS IGBP 17-class land cover palette
            return CropMapLegendData(
                title: "MODIS Land Cover",
                entries: [
                    LegendEntry(color: Color(red: 5/255, green: 100/255, blue: 35/255), label: "Evergreen Needleleaf"),
                    LegendEntry(color: Color(red: 0/255, green: 160/255, blue: 0/255), label: "Evergreen Broadleaf"),
                    LegendEntry(color: Color(red: 170/255, green: 200/255, blue: 0/255), label: "Deciduous Needleleaf"),
                    LegendEntry(color: Color(red: 0/255, green: 220/255, blue: 130/255), label: "Deciduous Broadleaf"),
                    LegendEntry(color: Color(red: 76/255, green: 115/255, blue: 0/255), label: "Mixed Forest"),
                    LegendEntry(color: Color(red: 255/255, green: 180/255, blue: 50/255), label: "Closed Shrublands"),
                    LegendEntry(color: Color(red: 255/255, green: 235/255, blue: 175/255), label: "Open Shrublands"),
                    LegendEntry(color: Color(red: 0/255, green: 210/255, blue: 0/255), label: "Woody Savannas"),
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 100/255), label: "Savannas"),
                    LegendEntry(color: Color(red: 220/255, green: 240/255, blue: 100/255), label: "Grasslands"),
                    LegendEntry(color: Color(red: 0/255, green: 170/255, blue: 230/255), label: "Wetlands"),
                    LegendEntry(color: Color(red: 255/255, green: 190/255, blue: 255/255), label: "Croplands"),
                    LegendEntry(color: Color(red: 255/255, green: 0/255, blue: 0/255), label: "Urban"),
                    LegendEntry(color: Color(red: 255/255, green: 210/255, blue: 120/255), label: "Cropland/Natural"),
                    LegendEntry(color: Color(red: 0/255, green: 0/255, blue: 200/255), label: "Water"),
                    LegendEntry(color: Color(red: 200/255, green: 200/255, blue: 200/255), label: "Barren"),
                ]
            )

        case .gfsadCropland:
            return CropMapLegendData(
                title: "GFSAD Croplands",
                entries: [
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 0/255), label: "Cropland"),
                    LegendEntry(color: Color(red: 200/255, green: 200/255, blue: 200/255), label: "Non-Cropland"),
                ]
            )

        case .nalcms:
            // Standard NALCMS 19-class palette
            return CropMapLegendData(
                title: "NALCMS",
                entries: [
                    LegendEntry(color: Color(red: 0/255, green: 61/255, blue: 0/255), label: "Temp. Needleleaf"),
                    LegendEntry(color: Color(red: 148/255, green: 168/255, blue: 0/255), label: "Sub-polar Taiga"),
                    LegendEntry(color: Color(red: 0/255, green: 130/255, blue: 0/255), label: "Trop. Broadleaf Evergreen"),
                    LegendEntry(color: Color(red: 0/255, green: 160/255, blue: 0/255), label: "Trop. Broadleaf Deciduous"),
                    LegendEntry(color: Color(red: 0/255, green: 207/255, blue: 0/255), label: "Temp. Broadleaf Deciduous"),
                    LegendEntry(color: Color(red: 122/255, green: 174/255, blue: 0/255), label: "Mixed Forest"),
                    LegendEntry(color: Color(red: 204/255, green: 204/255, blue: 0/255), label: "Trop. Shrubland"),
                    LegendEntry(color: Color(red: 209/255, green: 170/255, blue: 61/255), label: "Temp. Shrubland"),
                    LegendEntry(color: Color(red: 230/255, green: 230/255, blue: 130/255), label: "Trop. Grassland"),
                    LegendEntry(color: Color(red: 220/255, green: 206/255, blue: 0/255), label: "Temp. Grassland"),
                    LegendEntry(color: Color(red: 207/255, green: 117/255, blue: 148/255), label: "Wetland"),
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 0/255), label: "Cropland"),
                    LegendEntry(color: Color(red: 200/255, green: 200/255, blue: 200/255), label: "Barren"),
                    LegendEntry(color: Color(red: 255/255, green: 0/255, blue: 0/255), label: "Urban"),
                    LegendEntry(color: Color(red: 0/255, green: 0/255, blue: 255/255), label: "Water"),
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 255/255), label: "Snow/Ice"),
                ]
            )

        case .deAfricaCrop:
            return CropMapLegendData(
                title: "DE Africa Crop",
                entries: [
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 0/255), label: "Cropland"),
                ]
            )

        case .deaLandCover:
            return CropMapLegendData(
                title: "DEA Land Cover",
                entries: [
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 0/255), label: "Cultivated"),
                    LegendEntry(color: Color(red: 56/255, green: 168/255, blue: 0/255), label: "Natural Vegetation"),
                    LegendEntry(color: Color(red: 0/255, green: 100/255, blue: 200/255), label: "Water"),
                    LegendEntry(color: Color(red: 190/255, green: 190/255, blue: 190/255), label: "Bare"),
                ]
            )

        case .mexicoMadmex:
            return nil

        case .turkeyCorine:
            // CORINE simplified agricultural classes
            return CropMapLegendData(
                title: "CORINE Turkey",
                entries: [
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 168/255), label: "Arable Land"),
                    LegendEntry(color: Color(red: 242/255, green: 166/255, blue: 77/255), label: "Permanent Crops"),
                    LegendEntry(color: Color(red: 230/255, green: 230/255, blue: 77/255), label: "Pastures"),
                    LegendEntry(color: Color(red: 204/255, green: 242/255, blue: 77/255), label: "Agri/Natural"),
                    LegendEntry(color: Color(red: 56/255, green: 168/255, blue: 0/255), label: "Forest"),
                    LegendEntry(color: Color(red: 204/255, green: 204/255, blue: 204/255), label: "Bare/Sparse"),
                    LegendEntry(color: Color(red: 0/255, green: 100/255, blue: 255/255), label: "Water"),
                    LegendEntry(color: Color(red: 230/255, green: 0/255, blue: 0/255), label: "Artificial"),
                ]
            )

        case .waporLCC:
            return CropMapLegendData(
                title: "WaPOR LCC",
                entries: [
                    LegendEntry(color: Color(red: 255/255, green: 255/255, blue: 0/255), label: "Rainfed Cropland"),
                    LegendEntry(color: Color(red: 0/255, green: 200/255, blue: 255/255), label: "Irrigated Cropland"),
                    LegendEntry(color: Color(red: 56/255, green: 168/255, blue: 0/255), label: "Trees/Shrubs"),
                    LegendEntry(color: Color(red: 200/255, green: 230/255, blue: 130/255), label: "Grassland"),
                    LegendEntry(color: Color(red: 0/255, green: 0/255, blue: 200/255), label: "Water"),
                    LegendEntry(color: Color(red: 190/255, green: 190/255, blue: 190/255), label: "Bare/Sparse"),
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
