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

/// Supported FAO API languages
enum FAOLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, fr, es, ar, zh, ru

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: "English"
        case .fr: "Fran\u{00E7}ais"
        case .es: "Espa\u{00F1}ol"
        case .ar: "\u{0627}\u{0644}\u{0639}\u{0631}\u{0628}\u{064A}\u{0629}"
        case .zh: "\u{4E2D}\u{6587}"
        case .ru: "\u{0420}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}\u{0439}"
        }
    }
}

enum FAOCropCalendarService {
    static let baseURL = "https://api-cropcalendar.apps.fao.org/api/v1"

    /// Supported languages for the API
    static let supportedLanguages = FAOLanguage.allCases

    // MARK: - Data types

    struct CropOption: Identifiable, Sendable, Hashable {
        let id: String
        let name: String
    }

    struct CountryOption: Identifiable, Sendable, Hashable {
        let id: String    // ISO 2-letter code (e.g. "KE")
        let name: String  // Localised name
    }

    struct AEZOption: Identifiable, Sendable, Hashable {
        let id: String
        let name: String
    }

    struct CountryEntry: Decodable, Sendable { let id: String; let name: String }
    struct CropEntry: Decodable, Sendable { let crop_name: String; let crop_id: String }
    struct AEZEntry: Decodable, Sendable { let id: String; let name: String }

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

    // MARK: - Crop IDs of major staple crops (pinned to top of lists)

    static let pinnedCropIDs: Set<String> = [
        "0373", // Wheat (bread)
        "0113", // Corn/Maize (sweet)
        "0338", // Corn
        "0303", // Rice
        "0327", // Soybean
        "0024", // Barley
        "0325", // Sorghum
        "0362", // Cotton (upland)
        "0115", // Cotton
        "0335", // Sunflower
        "0283", // Potato
        "0334", // Sugarcane
        "0087", // Chickpea
        "0200", // Lentil
        "0262", // Peanut
        "0265", // Pearl millet
        "0076", // Cassava
        "0109", // Rapeseed/Canola
        "0241", // Oats
        "0341", // Sweet potato
        "0349", // Tef
    ]

    // MARK: - In-memory cache (invalidated on language change)

    nonisolated(unsafe) private static var cachedLanguage: String?
    nonisolated(unsafe) private static var cachedAllCrops: [CropOption]?
    nonisolated(unsafe) private static var cachedCountries: [CountryOption]?
    nonisolated(unsafe) private static var cachedCropsForCountry: [String: [CropOption]] = [:]
    nonisolated(unsafe) private static var cachedAEZForCountry: [String: [AEZOption]] = [:]

    /// Clear all cached data (called when language changes)
    static func invalidateCache() {
        cachedLanguage = nil
        cachedAllCrops = nil
        cachedCountries = nil
        cachedCropsForCountry = [:]
        cachedAEZForCountry = [:]
    }

    // MARK: - Fetch all crops globally

    /// Fetch all ~400 crops from the FAO API, sorted with pinned crops first
    static func fetchAllCrops(language: String = "en") async throws -> [CropOption] {
        if cachedLanguage == language, let cached = cachedAllCrops { return cached }

        let url = URL(string: "\(baseURL)/crops?language=\(language)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let entries = try JSONDecoder().decode([CropEntry].self, from: data)

        var crops = entries.map { CropOption(id: $0.crop_id, name: $0.crop_name) }
        // Sort: pinned crops first (alphabetically), then rest alphabetically
        crops.sort { a, b in
            let aPin = pinnedCropIDs.contains(a.id)
            let bPin = pinnedCropIDs.contains(b.id)
            if aPin != bPin { return aPin }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        cachedAllCrops = crops
        cachedLanguage = language
        return crops
    }

    // MARK: - Fetch all countries

    /// Fetch all ~60 countries that have FAO crop calendar data
    static func fetchCountries(language: String = "en") async throws -> [CountryOption] {
        if cachedLanguage == language, let cached = cachedCountries { return cached }

        let url = URL(string: "\(baseURL)/countries?language=\(language)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let entries = try JSONDecoder().decode([CountryEntry].self, from: data)

        let countries = entries
            .map { CountryOption(id: $0.id, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        cachedCountries = countries
        cachedLanguage = language
        return countries
    }

    // MARK: - Fetch crops for a specific country

    /// Fetch crops available for a given country (ISO code)
    static func fetchCrops(forCountry country: String, language: String = "en") async throws -> [CropOption] {
        if let cached = cachedCropsForCountry[country], cachedLanguage == language { return cached }

        let url = URL(string: "\(baseURL)/countries/\(country)/crops?language=\(language)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let entries = try JSONDecoder().decode([CropEntry].self, from: data)

        var crops = entries.map { CropOption(id: $0.crop_id, name: $0.crop_name) }
        crops.sort { a, b in
            let aPin = pinnedCropIDs.contains(a.id)
            let bPin = pinnedCropIDs.contains(b.id)
            if aPin != bPin { return aPin }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        cachedCropsForCountry[country] = crops
        return crops
    }

    // MARK: - Fetch AEZ for a country

    /// Fetch Agro-Ecological Zones for a given country (ISO code)
    static func fetchAEZ(forCountry country: String, language: String = "en") async throws -> [AEZOption] {
        if let cached = cachedAEZForCountry[country], cachedLanguage == language { return cached }

        let url = URL(string: "\(baseURL)/countries/\(country)/aez?language=\(language)")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 204 { return [] }
        let entries = try JSONDecoder().decode([AEZEntry].self, from: data)

        let zones = entries
            .map { AEZOption(id: $0.id, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        cachedAEZForCountry[country] = zones
        return zones
    }

    // MARK: - Fetch crop calendar

    static func fetchCalendar(country: String, cropID: String, language: String = "en") async throws -> [CalendarEntry] {
        let url = URL(string: "\(baseURL)/countries/\(country)/cropCalendar?crop=\(cropID)&language=\(language)")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 204 { return [] }
        return try JSONDecoder().decode([CalendarEntry].self, from: data)
    }

    /// Fetch calendar filtered by AEZ
    static func fetchCalendar(country: String, cropID: String, aez: String, language: String = "en") async throws -> [CalendarEntry] {
        let url = URL(string: "\(baseURL)/countries/\(country)/cropCalendar?crop=\(cropID)&aez=\(aez)&language=\(language)")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 204 { return [] }
        return try JSONDecoder().decode([CalendarEntry].self, from: data)
    }

    // MARK: - Reverse geocode

    static func countryCode(lat: Double, lon: Double) async -> String? {
        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            return placemarks.first?.isoCountryCode
        } catch { return nil }
    }

    // MARK: - Season extraction

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
