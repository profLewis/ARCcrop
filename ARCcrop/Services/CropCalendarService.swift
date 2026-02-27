import Foundation
import CoreLocation

// MARK: - Crop Calendar Data Source Selection

enum CropCalendarSource: String, CaseIterable, Identifiable, Sendable {
    case fao = "FAO Crop Calendar"
    case sage = "SAGE (Sacks et al.)"
    case geoglam = "GEOGLAM Sub-National"
    case builtIn = "Built-in Zones"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .fao: "REST API · 100+ crops · Country+AEZ"
        case .sage: "Embedded · 15 crops · 0.5° grid"
        case .geoglam: "Embedded · 8 crops · Sub-national"
        case .builtIn: "Embedded · ~75 zones · 8 regions"
        }
    }
}

// MARK: - Unified Season Result

struct CropSeasonInfo: Sendable {
    let crop: String
    let region: String
    let source: CropCalendarSource
    let plantingDOY: Int      // day of year (1-365) for planting
    let harvestDOY: Int       // day of year for harvest
    let plantingMonth: Int    // 1-12
    let harvestMonth: Int     // 1-12

    var seasonLengthDays: Int {
        harvestDOY > plantingDOY
            ? harvestDOY - plantingDOY
            : (365 - plantingDOY) + harvestDOY
    }

    static func monthFromDOY(_ doy: Int) -> Int {
        let daysInMonths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var remaining = doy
        for (i, days) in daysInMonths.enumerated() {
            if remaining <= days { return i + 1 }
            remaining -= days
        }
        return 12
    }
}

// MARK: - FAO Crop Calendar API Client

enum FAOCropCalendarService {
    static let baseURL = "https://api-cropcalendar.apps.fao.org/api/v1"

    struct CropOption: Identifiable, Sendable {
        let id: String
        let name: String
    }

    static let commonCrops: [CropOption] = [
        CropOption(id: "0373", name: "Wheat"),
        CropOption(id: "0113", name: "Maize"),
        CropOption(id: "0303", name: "Rice"),
        CropOption(id: "0327", name: "Soybean"),
        CropOption(id: "0024", name: "Barley"),
        CropOption(id: "0325", name: "Sorghum"),
        CropOption(id: "0362", name: "Cotton"),
        CropOption(id: "0335", name: "Sunflower"),
        CropOption(id: "0283", name: "Potato"),
        CropOption(id: "0334", name: "Sugarcane"),
        CropOption(id: "0087", name: "Chickpea"),
        CropOption(id: "0200", name: "Lentil"),
        CropOption(id: "0262", name: "Groundnut"),
    ]

    struct CountryEntry: Decodable, Sendable { let id: String; let name: String }
    struct CropEntry: Decodable, Sendable { let crop_name: String; let crop_id: String }

    struct CalendarEntry: Decodable, Sendable {
        let crop: CropInfo
        let aez: AEZInfo?
        let sessions: [Session]

        struct CropInfo: Decodable, Sendable { let id: String; let name: String }
        struct AEZInfo: Decodable, Sendable { let id: String; let name: String }
        struct Session: Decodable, Sendable {
            let early_sowing: DateField?
            let later_sowing: DateField?
            let early_harvest: DateField?
            let late_harvest: DateField?
        }
        struct DateField: Decodable, Sendable { let month: String; let day: String }
    }

    static func fetchCalendar(country: String, cropID: String) async throws -> [CalendarEntry] {
        let url = URL(string: "\(baseURL)/countries/\(country)/cropCalendar?crop=\(cropID)&language=en")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 204 { return [] }
        return try JSONDecoder().decode([CalendarEntry].self, from: data)
    }

    static func countryCode(lat: Double, lon: Double) async -> String? {
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            return placemarks.first?.isoCountryCode
        } catch { return nil }
    }

    static func extractSeason(from entries: [CalendarEntry]) -> CropSeasonInfo? {
        var sosMin = 366, eosMax = 0
        var cropName = ""

        for entry in entries {
            if cropName.isEmpty { cropName = entry.crop.name }
            for session in entry.sessions {
                if let es = session.early_sowing, let doy = dayOfYear(month: es.month, day: es.day) {
                    sosMin = min(sosMin, doy)
                }
                if let lh = session.late_harvest, let doy = dayOfYear(month: lh.month, day: lh.day) {
                    eosMax = max(eosMax, doy)
                }
            }
        }

        guard sosMin < 366, eosMax > 0 else { return nil }
        return CropSeasonInfo(
            crop: cropName,
            region: entries.first?.aez?.name ?? "National",
            source: .fao,
            plantingDOY: sosMin,
            harvestDOY: eosMax,
            plantingMonth: CropSeasonInfo.monthFromDOY(sosMin),
            harvestMonth: CropSeasonInfo.monthFromDOY(eosMax)
        )
    }

    private static func dayOfYear(month: String, day: String) -> Int? {
        guard let m = Int(month), let d = Int(day), m >= 1, m <= 12, d >= 1, d <= 31 else { return nil }
        var components = DateComponents()
        components.year = 2024
        components.month = m
        components.day = d
        guard let date = Calendar.current.date(from: components) else { return nil }
        return Calendar.current.ordinality(of: .day, in: .year, for: date)
    }
}

// MARK: - SAGE Crop Calendar (embedded 0.5° grid)

enum SAGECropCalendar {
    private struct CropData: Decodable {
        // Each entry is [lat, lon, plantDOY, harvestDOY]
    }

    nonisolated(unsafe) private static var cache: [String: [[Double]]]?

    static func loadIfNeeded() {
        guard cache == nil else { return }
        guard let url = Bundle.main.url(forResource: "sage_crop_calendars", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [[Double]]].self, from: data) else {
            print("SAGE: Failed to load sage_crop_calendars.json")
            return
        }
        cache = decoded
    }

    static var availableCrops: [String] {
        loadIfNeeded()
        return cache?.keys.sorted() ?? []
    }

    /// Find nearest SAGE calendar entry for a given location and crop
    static func lookup(lat: Double, lon: Double, crop: String) -> CropSeasonInfo? {
        loadIfNeeded()
        guard let entries = cache?[crop] else { return nil }

        // Find nearest 0.5° grid cell
        var bestDist = Double.greatestFiniteMagnitude
        var bestEntry: [Double]?

        for entry in entries {
            guard entry.count >= 4 else { continue }
            let dlat = entry[0] - lat
            let dlon = entry[1] - lon
            let dist = dlat * dlat + dlon * dlon
            if dist < bestDist {
                bestDist = dist
                bestEntry = entry
            }
        }

        // Only match if within ~1 degree
        guard let entry = bestEntry, bestDist < 1.0 else { return nil }

        let plantDOY = Int(entry[2])
        let harvestDOY = Int(entry[3])

        return CropSeasonInfo(
            crop: crop,
            region: "SAGE grid (\(entry[0])°, \(entry[1])°)",
            source: .sage,
            plantingDOY: plantDOY,
            harvestDOY: harvestDOY,
            plantingMonth: CropSeasonInfo.monthFromDOY(plantDOY),
            harvestMonth: CropSeasonInfo.monthFromDOY(harvestDOY)
        )
    }
}

// MARK: - GEOGLAM Sub-National Crop Calendar (embedded JSON)

enum GEOGLAMCropCalendar {
    struct Record: Decodable, Sendable {
        let country: String
        let region: String
        let crop: String
        let planting: Int
        let vegetative: Int
        let harvest: Int
        let endofseaso: Int
        let outofseaso: Int
        let minimalpro: Int
    }

    struct CalendarFile: Decodable {
        let records: [Record]
    }

    nonisolated(unsafe) private static var cache: [Record]?

    static func loadIfNeeded() {
        guard cache == nil else { return }
        guard let url = Bundle.main.url(forResource: "GEOGLAM_CM4EW_Calendars_V1.4_active", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CalendarFile.self, from: data) else {
            print("GEOGLAM: Failed to load crop calendars")
            return
        }
        cache = decoded.records
    }

    /// Lookup by country name and optional crop filter
    static func lookup(country: String, crop: String? = nil) -> [CropSeasonInfo] {
        loadIfNeeded()
        guard let records = cache else { return [] }

        let matches = records.filter { record in
            record.country.localizedCaseInsensitiveContains(country) &&
            (crop == nil || record.crop.localizedCaseInsensitiveContains(crop!))
        }

        return matches.map { record in
            CropSeasonInfo(
                crop: record.crop,
                region: "\(record.country) — \(record.region)",
                source: .geoglam,
                plantingDOY: record.planting,
                harvestDOY: record.harvest,
                plantingMonth: CropSeasonInfo.monthFromDOY(record.planting),
                harvestMonth: CropSeasonInfo.monthFromDOY(record.harvest)
            )
        }
    }

    static var availableCountries: [String] {
        loadIfNeeded()
        return Array(Set(cache?.map(\.country) ?? [])).sorted()
    }
}
