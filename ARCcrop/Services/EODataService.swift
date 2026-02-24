import Foundation
import CoreLocation

protocol EODataService: Sendable {
    var source: EODataSource { get }

    func fetchCropConditions(
        for location: CLLocationCoordinate2D,
        startDate: Date,
        endDate: Date
    ) async throws -> [CropCondition]
}
