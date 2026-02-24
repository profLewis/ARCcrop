import SwiftUI

@Observable @MainActor
final class AppSettings {
    static let shared = AppSettings()

    var enabledSources: [EODataSource: Bool] = [
        .sentinel2: true,
        .landsat: true,
        .modis: false,
    ]

    var vegetationIndex: VegetationIndex = .ndvi
    var selectedCropMap: CropMapSource = .none

    private init() {}
}
