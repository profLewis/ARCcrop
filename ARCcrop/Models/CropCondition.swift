import Foundation
import CoreLocation

struct CropCondition: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let location: CLLocationCoordinate2D
    let vegetationIndex: Double
    let source: EODataSource
    let cloudCoverPercent: Double?

    init(
        id: UUID = UUID(),
        date: Date,
        location: CLLocationCoordinate2D,
        vegetationIndex: Double,
        source: EODataSource,
        cloudCoverPercent: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.location = location
        self.vegetationIndex = vegetationIndex
        self.source = source
        self.cloudCoverPercent = cloudCoverPercent
    }
}
