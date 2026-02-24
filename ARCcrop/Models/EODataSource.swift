import SwiftUI

enum EODataSource: String, CaseIterable, Identifiable, Codable {
    case sentinel2 = "Sentinel-2"
    case landsat = "Landsat"
    case modis = "MODIS"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .sentinel2: "10m resolution, 5-day revisit (ESA Copernicus)"
        case .landsat: "30m resolution, 16-day revisit (NASA/USGS)"
        case .modis: "250m–1km resolution, daily revisit (NASA)"
        }
    }

    var iconName: String {
        switch self {
        case .sentinel2: "satellite.fill"
        case .landsat: "globe.americas.fill"
        case .modis: "globe.europe.africa.fill"
        }
    }

    var color: Color {
        switch self {
        case .sentinel2: .blue
        case .landsat: .green
        case .modis: .orange
        }
    }
}

enum VegetationIndex: String, CaseIterable, Identifiable, Codable {
    case ndvi = "NDVI"
    case evi = "EVI"
    case lai = "LAI"

    var id: String { rawValue }
}
