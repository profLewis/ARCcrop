import SwiftUI
import CoreLocation

@Observable @MainActor
final class AppSettings {
    static let shared = AppSettings()

    var enabledSources: [EODataSource: Bool] = [
        .sentinel2: true,
        .landsat: true,
        .modis: false,
    ]

    var vegetationIndex: VegetationIndex = .ndvi

    /// Ordered list of active crop map layers (bottom to top)
    var activeCropMaps: [CropMapSource] = [] {
        didSet {
            let ids = activeCropMaps.map(\.id)
            UserDefaults.standard.set(ids, forKey: "activeCropMaps")
        }
    }

    /// Per-source opacity: key = source.id, value = 0.05...1.0
    var layerOpacity: [String: Double] = [:] {
        didSet {
            UserDefaults.standard.set(layerOpacity, forKey: "layerOpacity")
        }
    }

    /// The "focused" layer for the opacity slider (index into activeCropMaps)
    var focusedLayerIndex: Int = 0

    /// The focused source (or .none if no layers active)
    var focusedCropMap: CropMapSource {
        guard !activeCropMaps.isEmpty,
              focusedLayerIndex >= 0,
              focusedLayerIndex < activeCropMaps.count
        else { return activeCropMaps.first ?? .none }
        return activeCropMaps[focusedLayerIndex]
    }

    /// Get opacity for a source (default 1.0)
    func opacity(for source: CropMapSource) -> Double {
        layerOpacity[source.id] ?? 1.0
    }

    /// Backward-compatible single-source accessor
    var selectedCropMap: CropMapSource {
        get { activeCropMaps.first ?? .none }
        set {
            if newValue == .none {
                activeCropMaps = []
            } else {
                activeCropMaps = [newValue]
            }
        }
    }

    var mapStyle: MapStyle = .satellite {
        didSet { UserDefaults.standard.set(mapStyle.rawValue, forKey: "mapStyle") }
    }
    var showBorders: Bool = false {
        didSet { UserDefaults.standard.set(showBorders, forKey: "showBorders") }
    }
    var showFieldBoundaries: Bool = false {
        didSet { UserDefaults.standard.set(showFieldBoundaries, forKey: "showFieldBoundaries") }
    }
    var showPoliticalBoundaries: Bool = false {
        didSet { UserDefaults.standard.set(showPoliticalBoundaries, forKey: "showPoliticalBoundaries") }
    }
    var showMasterMap: Bool = false {
        didSet { UserDefaults.standard.set(showMasterMap, forKey: "showMasterMap") }
    }
    var showFTWBoundaries: Bool = false {
        didSet { UserDefaults.standard.set(showFTWBoundaries, forKey: "showFTWBoundaries") }
    }

    /// Legacy global overlay opacity — reads/writes focused layer
    var overlayOpacity: Double {
        get { opacity(for: focusedCropMap) }
        set { layerOpacity[focusedCropMap.id] = newValue }
    }

    /// When true, map labels (place names) render above crop overlays
    var showLabelsAbove: Bool = false

    /// When false, the status log banner is hidden
    var showStatusBanner: Bool = true

    /// When true, automatically selects the best crop map for the current map view
    var autoBestMap: Bool = false {
        didSet { UserDefaults.standard.set(autoBestMap, forKey: "autoBestMap") }
    }

    /// When true, selecting a new layer adds it alongside existing ones.
    /// When false, selecting a new layer replaces all current layers ("clear on load").
    var allowMultipleLayers: Bool = true {
        didSet { UserDefaults.standard.set(allowMultipleLayers, forKey: "allowMultipleLayers") }
    }

    /// When true, changing the year stepper updates ALL active layers to the closest available year.
    /// When false, only the focused layer is changed.
    var syncYearAcrossLayers: Bool = true {
        didSet { UserDefaults.standard.set(syncYearAcrossLayers, forKey: "syncYearAcrossLayers") }
    }

    /// Tile cache disk capacity in MB (default 2 GB, max 5 GB)
    var cacheSizeMB: Int = 2048 {
        didSet {
            UserDefaults.standard.set(cacheSizeMB, forKey: "cacheSizeMB")
            #if !os(tvOS)
            WMSTileOverlay.applyDiskCapacity(cacheSizeMB)
            #endif
        }
    }

    /// Legend class keys that are currently hidden (toggled off)
    var hiddenClasses: Set<String> = []

    /// Legend customisations: key = "sourceId|originalLabel", value = (newLabel, hexColor)
    /// Persisted via UserDefaults as [[String]]
    var legendOverrides: [String: (label: String, hex: String)] = [:] {
        didSet {
            let arr = legendOverrides.map { [$0.key, $0.value.label, $0.value.hex] }
            UserDefaults.standard.set(arr, forKey: "legendOverrides")
        }
    }

    /// Current map center coordinate (updated from MKMapView delegate)
    var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)

    /// Current map zoom level (updated from MKMapView delegate)
    var mapZoomLevel: Double = 5.0

    // Navigation: tab switching + deep-link into API key setup
    var selectedTab: AppTab = .map
    var apiKeySetupProvider: APIKeyProvider? = nil
    var pendingCropMapSource: CropMapSource? = nil

    /// Effective MKMapType combining base style and border overlay
    var effectiveMapType: UInt {
        switch mapStyle {
        case .standard: showBorders ? 0 : 0          // standard always has borders
        case .satellite: showBorders ? 2 : 1          // hybrid when borders on
        case .blank: showBorders ? 4 : 4              // mutedStandard for both (dark tile covers it)
        }
    }

    private init() {
        // Restore active crop maps (prefer new array format, fall back to legacy single)
        if let ids = UserDefaults.standard.stringArray(forKey: "activeCropMaps") {
            self.activeCropMaps = ids.compactMap { CropMapSource.from(id: $0) }.filter { $0 != .none }
        } else if let savedID = UserDefaults.standard.string(forKey: "selectedCropMap"),
                  let source = CropMapSource.from(id: savedID), source != .none {
            self.activeCropMaps = [source]
        }
        if let opDict = UserDefaults.standard.dictionary(forKey: "layerOpacity") as? [String: Double] {
            self.layerOpacity = opDict
        }
        if let savedStyle = UserDefaults.standard.string(forKey: "mapStyle"),
           let style = MapStyle(rawValue: savedStyle) {
            self.mapStyle = style
        }
        self.showBorders = UserDefaults.standard.bool(forKey: "showBorders")
        self.showFieldBoundaries = UserDefaults.standard.bool(forKey: "showFieldBoundaries")
        self.showPoliticalBoundaries = UserDefaults.standard.bool(forKey: "showPoliticalBoundaries")
        self.showMasterMap = UserDefaults.standard.bool(forKey: "showMasterMap")
        self.showFTWBoundaries = UserDefaults.standard.bool(forKey: "showFTWBoundaries")
        self.autoBestMap = UserDefaults.standard.bool(forKey: "autoBestMap")
        if UserDefaults.standard.object(forKey: "allowMultipleLayers") != nil {
            self.allowMultipleLayers = UserDefaults.standard.bool(forKey: "allowMultipleLayers")
        }
        if UserDefaults.standard.object(forKey: "syncYearAcrossLayers") != nil {
            self.syncYearAcrossLayers = UserDefaults.standard.bool(forKey: "syncYearAcrossLayers")
        }
        let saved = UserDefaults.standard.integer(forKey: "cacheSizeMB")
        self.cacheSizeMB = saved > 0 ? saved : 2048
        // Restore legend overrides
        if let arr = UserDefaults.standard.array(forKey: "legendOverrides") as? [[String]] {
            var overrides: [String: (label: String, hex: String)] = [:]
            for item in arr where item.count == 3 {
                overrides[item[0]] = (label: item[1], hex: item[2])
            }
            self.legendOverrides = overrides
        }
    }
}

enum AppTab: Hashable {
    case map, dashboard, settings
}

enum MapStyle: String, CaseIterable, Identifiable, Sendable {
    case standard = "Standard"
    case satellite = "Satellite"
    case blank = "No Base Map"

    var id: String { rawValue }
}
