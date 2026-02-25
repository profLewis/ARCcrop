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

        case .geoglamCropPicture:
            return CropMapLegendData(
                title: "GEOGLAM Crop Picture",
                entries: [
                    LegendEntry(color: .red, label: "Soybean + Maize"),
                    LegendEntry(color: .green, label: "Wheat (Winter + Spring)"),
                    LegendEntry(color: .blue, label: "Rice"),
                    LegendEntry(color: .yellow, label: "Maize + Wheat"),
                    LegendEntry(color: .cyan, label: "Wheat + Rice"),
                    LegendEntry(color: .purple, label: "Soybean/Maize + Rice"),
                ]
            )

        case .geoglam(let crop):
            return CropMapLegendData(
                title: "GEOGLAM \(crop.rawValue)",
                entries: [
                    LegendEntry(color: crop.color.opacity(0.2), label: "< 20%"),
                    LegendEntry(color: crop.color.opacity(0.4), label: "20–40%"),
                    LegendEntry(color: crop.color.opacity(0.6), label: "40–60%"),
                    LegendEntry(color: crop.color.opacity(0.8), label: "60–80%"),
                    LegendEntry(color: crop.color, label: "> 80%"),
                ]
            )

        case .usdaCDL:
            return CropMapLegendData(
                title: "USDA Cropland Data Layer",
                entries: [
                    LegendEntry(color: Color(red: 1.0, green: 0.82, blue: 0.0), label: "Corn"),
                    LegendEntry(color: Color(red: 0.14, green: 0.56, blue: 0.14), label: "Soybeans"),
                    LegendEntry(color: Color(red: 0.66, green: 0.44, blue: 0.16), label: "Winter Wheat"),
                    LegendEntry(color: Color(red: 0.85, green: 0.65, blue: 0.13), label: "Spring Wheat"),
                    LegendEntry(color: Color(red: 0.0, green: 0.63, blue: 0.78), label: "Rice"),
                    LegendEntry(color: Color(red: 1.0, green: 0.5, blue: 0.0), label: "Cotton"),
                    LegendEntry(color: Color(red: 0.5, green: 0.8, blue: 0.5), label: "Other Crops"),
                    LegendEntry(color: Color(red: 0.0, green: 0.39, blue: 0.0), label: "Forest"),
                    LegendEntry(color: Color(red: 0.74, green: 0.74, blue: 0.74), label: "Developed"),
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
                    LegendEntry(color: Color(red: 1.0, green: 1.0, blue: 1.0), label: "Snow/Ice"),
                    LegendEntry(color: Color(red: 0.5, green: 0.5, blue: 0.5), label: "Flooded Veg"),
                    LegendEntry(color: Color(red: 0.0, green: 0.5, blue: 0.5), label: "Shrub/Scrub"),
                ]
            )

        case .worldCereal:
            return CropMapLegendData(
                title: "ESA WorldCereal",
                entries: [
                    LegendEntry(color: .green, label: "Temporary Crops"),
                    LegendEntry(color: .yellow, label: "Maize"),
                    LegendEntry(color: .orange, label: "Cereals"),
                    LegendEntry(color: .blue, label: "Irrigated"),
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
                title: "Copernicus Land Cover",
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
