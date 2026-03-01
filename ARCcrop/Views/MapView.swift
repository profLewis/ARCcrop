import SwiftUI
import MapKit
import MapLibre

#if !os(tvOS)
struct MapView: View {
    @Environment(AppSettings.self) private var settings
    @State private var log = ActivityLog.shared
    @State private var isSearching = false
    @State private var showingLog = false

    /// Effective year range: when syncing across layers, use the union of all active layer ranges.
    /// When not syncing, use the focused layer's range.
    private var effectiveYearRange: ClosedRange<Int>? {
        if settings.syncYearAcrossLayers && settings.activeCropMaps.count > 1 {
            var lo = Int.max, hi = Int.min
            var hasAny = false
            for source in settings.activeCropMaps {
                if let r = source.availableYears, r.count > 1 {
                    lo = min(lo, r.lowerBound)
                    hi = max(hi, r.upperBound)
                    hasAny = true
                }
            }
            return hasAny ? lo...hi : nil
        } else {
            let range = settings.focusedCropMap.availableYears
            return (range != nil && range!.count > 1) ? range : nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapContainerView(
                    activeCropMaps: settings.activeCropMaps,
                    layerOpacity: settings.layerOpacity,
                    mapStyle: settings.mapStyle,
                    showBorders: settings.showBorders,
                    hiddenClasses: settings.hiddenClasses,
                    showFieldBoundaries: settings.showFieldBoundaries,
                    showPoliticalBoundaries: settings.showPoliticalBoundaries,
                    showMasterMap: settings.showMasterMap,
                    showFTWBoundaries: settings.showFTWBoundaries,
                    showLabelsAbove: settings.showLabelsAbove
                )
                .ignoresSafeArea(edges: .bottom)

                // Top bar: pinned controls across the top of the map
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        // Search button
                        Button { isSearching = true } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.callout.bold())
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        // Crop map picker (always visible)
                        CropMapPickerView()
                            .frame(maxWidth: .infinity)

                        // Log button
                        Button { showingLog = true } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.callout.bold())
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                    // Status banner (just below the pinned bar)
                    if settings.showStatusBanner, let msg = log.latestMessage {
                        StatusBannerView(message: log.progressText ?? msg, level: log.latestLevel ?? .info, isActive: log.isActive, tileProgress: log.tileProgress)
                            .padding(.top, 4)
                            .allowsHitTesting(false)
                    }

                    Spacer()
                }

                // Right side: year stepper + map controls + opacity
                VStack(alignment: .trailing, spacing: 6) {
                    Spacer().frame(height: 48)

                    if let yearRange = effectiveYearRange {
                        YearStepperView(
                            year: settings.focusedCropMap.currentYear,
                            range: yearRange
                        ) { newYear in
                            if settings.syncYearAcrossLayers && settings.activeCropMaps.count > 1 {
                                for i in settings.activeCropMaps.indices {
                                    settings.activeCropMaps[i] = settings.activeCropMaps[i].withClosestYear(newYear)
                                }
                            } else {
                                let idx = settings.focusedLayerIndex
                                if idx >= 0 && idx < settings.activeCropMaps.count {
                                    settings.activeCropMaps[idx] = settings.activeCropMaps[idx].withYear(newYear)
                                }
                            }
                        }
                    }

                    MapControlsMenu(
                        mapStyle: Binding(get: { settings.mapStyle }, set: { settings.mapStyle = $0 }),
                        showBorders: Binding(get: { settings.showBorders }, set: { settings.showBorders = $0 }),
                        showFieldBoundaries: Binding(get: { settings.showFieldBoundaries }, set: { settings.showFieldBoundaries = $0 }),
                        showPoliticalBoundaries: Binding(get: { settings.showPoliticalBoundaries }, set: { settings.showPoliticalBoundaries = $0 }),
                        showMasterMap: Binding(get: { settings.showMasterMap }, set: { settings.showMasterMap = $0 }),
                        showFTWBoundaries: Binding(get: { settings.showFTWBoundaries }, set: { settings.showFTWBoundaries = $0 }),
                        showLabelsAbove: Binding(get: { settings.showLabelsAbove }, set: { settings.showLabelsAbove = $0 }),
                        showStatusBanner: Binding(get: { settings.showStatusBanner }, set: { settings.showStatusBanner = $0 }),
                        autoBestMap: Binding(get: { settings.autoBestMap }, set: { settings.autoBestMap = $0 }),
                        allowMultipleLayers: Binding(get: { settings.allowMultipleLayers }, set: { settings.allowMultipleLayers = $0 }),
                        syncYearAcrossLayers: Binding(get: { settings.syncYearAcrossLayers }, set: { settings.syncYearAcrossLayers = $0 }),
                        hasOSKey: KeychainService.hasKey(for: .osDataHub),
                        mapCenter: settings.mapCenter
                    )

                    if !settings.activeCropMaps.isEmpty {
                        LayerOpacityControl()
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Bottom-left: legends + zoom level bottom-right
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        MultiLegendView()
                            .padding(8)
                        Spacer()
                        Text("z\(String(format: "%.1f", settings.mapZoomLevel))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isSearching) {
                PlaceSearchSheet { coordinate in
                    isSearching = false
                    NotificationCenter.default.post(
                        name: .mapZoomToCoordinate, object: nil,
                        userInfo: ["coordinate": coordinate]
                    )
                    if settings.autoBestMap {
                        let current = settings.selectedCropMap
                        if current != .none,
                           !current.covers(latitude: coordinate.latitude, longitude: coordinate.longitude),
                           let better = CropMapSource.bestSource(at: coordinate.latitude, longitude: coordinate.longitude, excluding: current) {
                            settings.hiddenClasses = []
                            settings.selectedCropMap = better
                            ActivityLog.shared.info("Switched to \(better.displayName) (covers this area)")
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingLog) {
                LogView(isPresented: $showingLog)
                    .presentationDetents([.large])
            }
            .onChange(of: settings.autoBestMap) {
                if settings.autoBestMap {
                    let center = settings.mapCenter
                    if let best = CropMapSource.bestSource(at: center.latitude, longitude: center.longitude) {
                        settings.hiddenClasses = []
                        settings.selectedCropMap = best
                        ActivityLog.shared.info("Auto: \(best.displayName)")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .cropMapAutoSwitch)) { notification in
                guard let lat = notification.userInfo?["latitude"] as? Double,
                      let lon = notification.userInfo?["longitude"] as? Double else { return }
                let current = settings.selectedCropMap
                if let better = CropMapSource.bestSource(at: lat, longitude: lon, excluding: current) {
                    settings.hiddenClasses = []
                    settings.selectedCropMap = better
                    ActivityLog.shared.info("Switched to \(better.displayName) (covers this area)")
                }
            }
        }
    }

    private func handleSourceSelection(_ source: CropMapSource) {
        if source.requiresAPIKey && !source.isAvailable {
            settings.pendingCropMapSource = source
            settings.apiKeySetupProvider = source.apiKeyProvider
            settings.selectedTab = .settings
        } else if settings.activeCropMaps.contains(where: { $0.id == source.id }) {
            settings.activeCropMaps.removeAll { $0.id == source.id }
        } else {
            settings.activeCropMaps.append(source)
            settings.focusedLayerIndex = settings.activeCropMaps.count - 1
            ActivityLog.shared.info("Added \(source.displayName)")
        }
    }
}

// MARK: - Status banner

struct StatusBannerView: View {
    let message: String
    let level: ActivityLog.Entry.Level
    let isActive: Bool
    let tileProgress: Double?
    @State private var leafRotation: Double = 0
    @State private var opacity: Double = 1.0

    private var isMultiLine: Bool { message.contains("\n") }
    /// Success messages auto-fade; errors stay visible until next action
    private var shouldAutoFade: Bool { !isActive && level == .success }

    var body: some View {
        VStack(spacing: 2) {
            if isMultiLine {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300, alignment: .leading)
                }
                .frame(maxWidth: 300, maxHeight: 200)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        if isActive {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.green)
                                .rotationEffect(.degrees(leafRotation))
                                .onAppear {
                                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                        leafRotation = 360
                                    }
                                }
                        } else if level == .success {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.green)
                        } else if level == .error {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.red)
                        }
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .fixedSize()
                        if isActive, let progress = tileProgress {
                            Text("\(Int(progress * 100))%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(color.opacity(0.6))
                        } else if isActive {
                            Text("...")
                                .font(.caption2)
                                .foregroundStyle(color.opacity(0.6))
                        }
                    }
                }
                .frame(maxWidth: 300)
            }
            if isActive, let progress = tileProgress, progress < 1.0 {
                ProgressView(value: progress)
                    .tint(.green)
                    .frame(width: 120)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: isMultiLine ? 8 : 20))
        .opacity(opacity)
        .onChange(of: message) {
            // Reset opacity when new message arrives
            opacity = 1.0
            scheduleAutoFade()
        }
        .onAppear { scheduleAutoFade() }
    }

    private func scheduleAutoFade() {
        guard shouldAutoFade else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeOut(duration: 1.5)) {
                opacity = 0.0
            }
        }
    }

    private var color: Color {
        switch level {
        case .info: .white
        case .success: .green
        case .warning: .yellow
        case .error: .red
        }
    }
}

// MARK: - Map controls

struct MapControlsMenu: View {
    @Binding var mapStyle: MapStyle
    @Binding var showBorders: Bool
    @Binding var showFieldBoundaries: Bool
    @Binding var showPoliticalBoundaries: Bool
    @Binding var showMasterMap: Bool
    @Binding var showFTWBoundaries: Bool
    @Binding var showLabelsAbove: Bool
    @Binding var showStatusBanner: Bool
    @Binding var autoBestMap: Bool
    @Binding var allowMultipleLayers: Bool
    @Binding var syncYearAcrossLayers: Bool
    var hasOSKey: Bool
    var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)

    private var isNearUK: Bool {
        mapCenter.latitude >= 49 && mapCenter.latitude <= 61 &&
        mapCenter.longitude >= -11 && mapCenter.longitude <= 3
    }

    var body: some View {
        Menu {
            Section("Base Map") {
                ForEach(MapStyle.allCases) { s in
                    Button {
                        mapStyle = s
                    } label: {
                        if s == mapStyle {
                            Label(s.rawValue, systemImage: "checkmark")
                        } else {
                            Text(s.rawValue)
                        }
                    }
                }
            }
            Section("Overlays") {
                Button {
                    showBorders.toggle()
                } label: {
                    if showBorders {
                        Label("Borders & Roads", systemImage: "checkmark")
                    } else {
                        Text("Borders & Roads")
                    }
                }
                if showBorders {
                    Button {
                        showLabelsAbove.toggle()
                    } label: {
                        if showLabelsAbove {
                            Label("Labels on Top", systemImage: "checkmark")
                        } else {
                            Text("Labels on Top")
                        }
                    }
                }
                if hasOSKey && isNearUK {
                    Button {
                        showFieldBoundaries.toggle()
                    } label: {
                        if showFieldBoundaries {
                            Label("OS Field Boundaries", systemImage: "checkmark")
                        } else {
                            Text("OS Field Boundaries")
                        }
                    }
                    Button {
                        showMasterMap.toggle()
                    } label: {
                        if showMasterMap {
                            Label("OS MasterMap", systemImage: "checkmark")
                        } else {
                            Text("OS MasterMap")
                        }
                    }
                }
                Button {
                    showPoliticalBoundaries.toggle()
                } label: {
                    if showPoliticalBoundaries {
                        Label("Political Boundaries", systemImage: "checkmark")
                    } else {
                        Text("Political Boundaries")
                    }
                }
                Button {
                    showFTWBoundaries.toggle()
                } label: {
                    if showFTWBoundaries {
                        Label("Field Boundaries (FTW)", systemImage: "checkmark")
                    } else {
                        Text("Field Boundaries (FTW)")
                    }
                }
            }
            Section("Display") {
                Button {
                    allowMultipleLayers.toggle()
                } label: {
                    if allowMultipleLayers {
                        Label("Multi-Layer", systemImage: "checkmark")
                    } else {
                        Text("Multi-Layer")
                    }
                }
                Button {
                    syncYearAcrossLayers.toggle()
                } label: {
                    if syncYearAcrossLayers {
                        Label("Sync Year (All Layers)", systemImage: "checkmark")
                    } else {
                        Text("Sync Year (All Layers)")
                    }
                }
                Button {
                    autoBestMap.toggle()
                } label: {
                    if autoBestMap {
                        Label("Best Map (Auto)", systemImage: "checkmark")
                    } else {
                        Text("Best Map (Auto)")
                    }
                }
                Button {
                    showStatusBanner.toggle()
                } label: {
                    if showStatusBanner {
                        Label("Status Log", systemImage: "checkmark")
                    } else {
                        Text("Status Log")
                    }
                }
            }
        } label: {
            Image(systemName: "map")
                .font(.callout.bold())
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
    }
}

// MARK: - Place search

extension Notification.Name {
    static let mapZoomToCoordinate = Notification.Name("mapZoomToCoordinate")
    static let cropMapAutoSwitch = Notification.Name("cropMapAutoSwitch")
}

struct PlaceSearchSheet: View {
    let onSelect: (CLLocationCoordinate2D) -> Void
    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @StateObject private var completer = SearchCompleter()

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { result in
                Button {
                    search(for: result)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title).font(.callout)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Search Places")
            .toolbarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "City, region or coordinates")
            .onChange(of: searchText) { _, newValue in
                completer.queryFragment = newValue
            }
            .onReceive(completer.$results) { results = $0 }
        }
    }

    private func search(for completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            if let item = response?.mapItems.first {
                onSelect(item.placemark.coordinate)
            }
        }
    }
}

final class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    var queryFragment: String {
        get { completer.queryFragment }
        set { completer.queryFragment = newValue }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {}
}

// MARK: - Year stepper

struct YearStepperView: View {
    let year: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                if year > range.lowerBound { onChange(year - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.bold())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(year <= range.lowerBound)

            Menu {
                ForEach(Array(range), id: \.self) { y in
                    Button(String(y)) { onChange(y) }
                }
            } label: {
                Text(String(year))
                    .font(.callout.bold().monospacedDigit())
                    .frame(minWidth: 44)
            }

            Button {
                if year < range.upperBound { onChange(year + 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(year >= range.upperBound)
        }
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Layer opacity control

struct LayerOpacityControl: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 2) {
            Slider(value: Binding(
                get: { settings.opacity(for: settings.focusedCropMap) },
                set: { settings.layerOpacity[settings.focusedCropMap.id] = $0 }
            ), in: 0.05...1.0)
                .frame(width: 100)
                .rotationEffect(.degrees(-90))
                .frame(width: 28, height: 100)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    let count = settings.activeCropMaps.count
                    guard count > 1 else { return }
                    if value.translation.width > 0 {
                        settings.focusedLayerIndex = (settings.focusedLayerIndex + 1) % count
                    } else {
                        settings.focusedLayerIndex = (settings.focusedLayerIndex - 1 + count) % count
                    }
                }
        )
    }
}

// MARK: - MapLibre network delegate (injects URLProtocol into MapLibre's session)

final class MapLibreNetworkDelegate: NSObject, MLNNetworkConfigurationDelegate {
    func session(for configuration: MLNNetworkConfiguration) -> URLSession {
        let config = URLSessionConfiguration.default
        config.protocolClasses = [WMSTileURLProtocol.self] + (config.protocolClasses ?? [])
        config.urlCache = URLCache(memoryCapacity: 128 * 1024 * 1024, diskCapacity: 1024 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }
}

// MARK: - MapLibre map wrapper

struct MapContainerView: UIViewRepresentable {
    var activeCropMaps: [CropMapSource]
    var layerOpacity: [String: Double]
    var mapStyle: MapStyle
    var showBorders: Bool
    var hiddenClasses: Set<String>
    var showFieldBoundaries: Bool
    var showPoliticalBoundaries: Bool
    var showMasterMap: Bool
    var showFTWBoundaries: Bool
    var showLabelsAbove: Bool

    /// Build a MapLibre style JSON for the given base map and write it to a temp file.
    private static func writeStyleJSON(mapStyle: MapStyle) -> URL {
        let esri = "https://server.arcgisonline.com/ArcGIS/rest/services"
        let tileURL: String?
        let bgColor: String

        switch mapStyle {
        case .satellite:
            tileURL = "\(esri)/World_Imagery/MapServer/tile/{z}/{y}/{x}"
            bgColor = "#000000"
        case .hybrid:
            // Satellite + labels overlay
            tileURL = "\(esri)/World_Imagery/MapServer/tile/{z}/{y}/{x}"
            bgColor = "#000000"
        case .standard:
            tileURL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            bgColor = "#e8e4d8"
        case .terrain:
            tileURL = "\(esri)/World_Topo_Map/MapServer/tile/{z}/{y}/{x}"
            bgColor = "#e8e4d8"
        case .dark:
            tileURL = "\(esri)/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}"
            bgColor = "#1a1a1a"
        case .blank:
            tileURL = nil
            bgColor = "#1f1f1f"
        }

        var sources = ""
        var layers = """
        {"id":"background","type":"background","paint":{"background-color":"\(bgColor)"}}
        """

        if let tileURL {
            sources = """
            "basemap-src":{"type":"raster","tiles":["\(tileURL)"],"tileSize":256,"maxzoom":19}
            """
            layers += """
            ,{"id":"basemap","type":"raster","source":"basemap-src"}
            """
        }

        // Hybrid: add labels overlay on top of satellite
        if mapStyle == .hybrid {
            sources += """
            ,"labels-src":{"type":"raster","tiles":["\(esri)/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}"],"tileSize":256,"maxzoom":19}
            """
            layers += """
            ,{"id":"labels","type":"raster","source":"labels-src"}
            """
        }

        let json = """
        {"version":8,"sources":{\(sources)},"layers":[\(layers)]}
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("arccrop_style.json")
        try? json.data(using: .utf8)?.write(to: url)
        return url
    }

    /// Strong reference to the network delegate so it doesn't get deallocated (MapLibre holds weak ref)
    private static var networkDelegate: MapLibreNetworkDelegate?

    func makeUIView(context: Context) -> MLNMapView {
        // Set up the network delegate so MapLibre uses our custom URLSession
        // (which includes WMSTileURLProtocol for arccrop-filter:// interception).
        if Self.networkDelegate == nil {
            let delegate = MapLibreNetworkDelegate()
            Self.networkDelegate = delegate
            MLNNetworkConfiguration.sharedManager.delegate = delegate
        }
        // Also register globally (for URLSession.shared fallback)
        URLProtocol.registerClass(WMSTileURLProtocol.self)

        let styleURL = Self.writeStyleJSON(mapStyle: mapStyle)
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.allowsRotating = false
        mapView.allowsTilting = false

        // Set MapLibre ambient cache size
        let cacheMB = AppSettings.shared.cacheSizeMB
        MLNOfflineStorage.shared.setMaximumAmbientCacheSize(UInt(cacheMB) * 1024 * 1024) { _ in }

        // Zoom-to-coordinate notification
        NotificationCenter.default.addObserver(
            forName: .mapZoomToCoordinate, object: nil, queue: .main
        ) { notification in
            if let coord = notification.userInfo?["coordinate"] as? CLLocationCoordinate2D {
                mapView.setCenter(coord, zoomLevel: 10, animated: true)
            }
        }

        // Long press for crop identification
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)

        let coord = context.coordinator
        coord.mapView = mapView
        coord.currentSources = activeCropMaps
        coord.currentMapStyle = mapStyle
        coord.currentShowBorders = showBorders
        coord.currentHidden = hiddenClasses
        coord.currentOpacities = layerOpacity
        coord.showingFieldBoundaries = showFieldBoundaries
        coord.showingPoliticalBoundaries = showPoliticalBoundaries
        coord.showingFTWBoundaries = showFTWBoundaries

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        let coord = context.coordinator
        guard let style = mapView.style, coord.styleLoaded else {
            // Style not loaded yet — store pending state
            coord.currentSources = activeCropMaps
            coord.currentMapStyle = mapStyle
            coord.currentShowBorders = showBorders
            coord.currentHidden = hiddenClasses
            coord.currentOpacities = layerOpacity
            coord.showingFieldBoundaries = showFieldBoundaries
            coord.showingPoliticalBoundaries = showPoliticalBoundaries
            coord.showingFTWBoundaries = showFTWBoundaries
            return
        }

        let basemapChanged = coord.currentMapStyle != mapStyle || coord.currentShowBorders != showBorders
        let sourcesChanged = coord.currentSources.map(\.id) != activeCropMaps.map(\.id)
        let opacityChanged = coord.currentOpacities != layerOpacity
        let filterChanged = coord.currentHidden != hiddenClasses
        let fieldBoundaryChanged = coord.showingFieldBoundaries != showFieldBoundaries
        let politicalChanged = coord.showingPoliticalBoundaries != showPoliticalBoundaries
        let ftwChanged = coord.showingFTWBoundaries != showFTWBoundaries
        let refOverlayChanged = fieldBoundaryChanged || politicalChanged || ftwChanged

        // Update opacity on existing layers without rebuilding
        if opacityChanged && !sourcesChanged {
            coord.currentOpacities = layerOpacity
            for source in activeCropMaps {
                if let layer = style.layer(withIdentifier: "data-\(source.id)") as? MLNRasterStyleLayer {
                    let opacity = layerOpacity[source.id] ?? 1.0
                    layer.rasterOpacity = NSExpression(forConstantValue: opacity)
                }
            }
        }

        // Base map change — reload entire style (data layers re-added in didFinishLoading)
        if basemapChanged {
            coord.currentMapStyle = mapStyle
            coord.currentShowBorders = showBorders
            coord.currentSources = activeCropMaps
            coord.currentHidden = hiddenClasses
            coord.currentOpacities = layerOpacity
            coord.showingFieldBoundaries = showFieldBoundaries
            coord.showingPoliticalBoundaries = showPoliticalBoundaries
            coord.showingFTWBoundaries = showFTWBoundaries
            coord.styleLoaded = false
            mapView.styleURL = Self.writeStyleJSON(mapStyle: mapStyle)
            return
        }

        // Data sources or filter changed — rebuild data layers
        if sourcesChanged || filterChanged {
            let oldIDs = Set(coord.currentSources.map(\.id))
            let newIDs = Set(activeCropMaps.map(\.id))
            let addedIDs = newIDs.subtracting(oldIDs)

            coord.currentSources = activeCropMaps
            coord.currentHidden = hiddenClasses
            coord.currentOpacities = layerOpacity
            coord.hasAutoSwitched = false

            // Remove all existing data layers and sources
            coord.removeAllDataLayers(style: style)
            ActivityLog.shared.resetTileProgress()

            // Add data layers for each active source
            coord.addDataLayers(style: style)

            // Zoom to coverage of newly added source
            if let addedSource = activeCropMaps.last, addedIDs.contains(addedSource.id),
               let region = addedSource.coverageRegion {
                let center = CLLocationCoordinate2D(latitude: region.lat, longitude: region.lon)
                let visible = mapView.visibleCoordinateBounds
                let overlaps = abs(visible.sw.latitude + visible.ne.latitude) / 2 - center.latitude <
                    (visible.ne.latitude - visible.sw.latitude + region.latSpan) / 2 &&
                    abs(visible.sw.longitude + visible.ne.longitude) / 2 - center.longitude <
                    (visible.ne.longitude - visible.sw.longitude + region.lonSpan) / 2
                if !overlaps {
                    mapView.setCenter(center, zoomLevel: 5, animated: true)
                }
            }
        }

        // Reference overlays
        if refOverlayChanged {
            coord.showingFieldBoundaries = showFieldBoundaries
            coord.showingPoliticalBoundaries = showPoliticalBoundaries
            coord.showingFTWBoundaries = showFTWBoundaries
            coord.syncReferenceOverlays(style: style)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    @MainActor final class Coordinator: NSObject, @preconcurrency MLNMapViewDelegate {
        var currentSources: [CropMapSource] = []
        var currentMapStyle: MapStyle = .satellite
        var currentShowBorders = false
        var currentHidden: Set<String> = []
        var currentOpacities: [String: Double] = [:]
        var showingFieldBoundaries = false
        var showingPoliticalBoundaries = false
        var showingFTWBoundaries = false
        var hasAutoSwitched = false
        var styleLoaded = false
        weak var mapView: MLNMapView?

        // MARK: Style loaded

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            styleLoaded = true
            addDataLayers(style: style)
            syncReferenceOverlays(style: style)
        }

        // MARK: Data layer management

        func removeAllDataLayers(style: MLNStyle) {
            // Remove layers and sources with "data-" and "src-" prefixes
            for layerID in style.layers.compactMap(\.identifier) {
                if layerID.hasPrefix("data-") {
                    if let layer = style.layer(withIdentifier: layerID) {
                        style.removeLayer(layer)
                    }
                }
            }
            for sourceID in style.sources.compactMap(\.identifier) {
                if sourceID.hasPrefix("src-") {
                    if let source = style.source(withIdentifier: sourceID) {
                        style.removeSource(source)
                    }
                }
            }
        }

        func addDataLayers(style: MLNStyle) {
            for source in currentSources {
                let sourceId = "src-\(source.id)"
                let layerId = "data-\(source.id)"

                // Skip if already exists
                if style.source(withIdentifier: sourceId) != nil { continue }

                switch source {
                case .none:
                    continue
                case .geoglamMajorityCrop:
                    ActivityLog.shared.activity("Loading GEOGLAM Majority Crop (reprojecting...)")
                    addGEOGLAMLayer(style: style, source: source)
                    continue
                case .geoglam(let crop):
                    ActivityLog.shared.activity("Loading GEOGLAM \(crop.rawValue) (reprojecting...)")
                    addGEOGLAMLayer(style: style, source: source)
                    continue
                default:
                    break
                }

                guard let params = CropMapOverlayFactory.sourceParams(for: source) else {
                    if source.requiresAPIKey {
                        let provider = source.apiKeyProvider?.rawValue ?? "API"
                        if source.isAvailable {
                            ActivityLog.shared.error("\(source.sourceName): \(provider) key saved but tile endpoint not yet implemented. This dataset requires server-side GEE processing.")
                        } else {
                            ActivityLog.shared.error("\(source.sourceName): requires \(provider) key — tap the key icon in the menu to set up")
                        }
                    } else {
                        ActivityLog.shared.error("\(source.sourceName): no tile endpoint configured")
                    }
                    continue
                }

                // Determine if we need the proxy (4326 reprojection or pixel filtering)
                let filterColors: [(r: UInt8, g: UInt8, b: UInt8)]
                if !currentHidden.isEmpty {
                    let entries = CropMapLegendData.forSource(source)?.entries ?? []
                    filterColors = LegendColorExtractor.rgbValues(for: entries, matching: currentHidden)
                } else {
                    filterColors = []
                }

                let tileURL: String
                if params.needs4326 || !filterColors.isEmpty {
                    // Route through URLProtocol proxy
                    let proxyTemplate = params.tileURLTemplate
                        .replacingOccurrences(of: "{bbox-epsg-3857}", with: "PROXY_BBOX")
                    tileURL = CropMapOverlayFactory.proxyURL(
                        template: proxyTemplate,
                        needs4326: params.needs4326,
                        filterColors: filterColors)
                } else {
                    // Direct URL — best performance, MapLibre caches natively
                    tileURL = params.tileURLTemplate
                }

                let tileSource = MLNRasterTileSource(
                    identifier: sourceId,
                    tileURLTemplates: [tileURL],
                    options: [
                        .tileSize: 256,
                        .minimumZoomLevel: params.minZoom,
                        .maximumZoomLevel: params.maxZoom
                    ]
                )
                style.addSource(tileSource)

                let layer = MLNRasterStyleLayer(identifier: layerId, source: tileSource)
                layer.rasterOpacity = NSExpression(forConstantValue: currentOpacities[source.id] ?? 1.0)
                style.addLayer(layer)

                ActivityLog.shared.activity("Loading \(source.sourceName)")
                waitingForInitialRender = true
                loadingStartTime = loadingStartTime ?? Date()
            }
        }

        private func addGEOGLAMLayer(style: MLNStyle, source: CropMapSource) {
            var image: UIImage?
            switch source {
            case .geoglamMajorityCrop:
                image = GEOGLAMOverlayManager.shared.mercatorImage(for: nil)
            case .geoglam(let crop):
                image = GEOGLAMOverlayManager.shared.mercatorImage(for: crop)
            default:
                return
            }

            guard image != nil else { return }

            // Apply per-pixel class filtering if any classes are hidden
            if !currentHidden.isEmpty {
                let entries = CropMapLegendData.forSource(source)?.entries ?? []
                let filterColors = LegendColorExtractor.rgbValues(for: entries, matching: currentHidden)
                if !filterColors.isEmpty {
                    image = GEOGLAMOverlayManager.filterImage(image!, hiding: filterColors)
                }
            }

            guard let image else { return }

            let sourceId = "src-\(source.id)"
            let layerId = "data-\(source.id)"

            let quad = MLNCoordinateQuad(
                topLeft: CLLocationCoordinate2D(latitude: 85.051, longitude: -180),
                bottomLeft: CLLocationCoordinate2D(latitude: -85.051, longitude: -180),
                bottomRight: CLLocationCoordinate2D(latitude: -85.051, longitude: 180),
                topRight: CLLocationCoordinate2D(latitude: 85.051, longitude: 180)
            )
            let imgSource = MLNImageSource(identifier: sourceId, coordinateQuad: quad, image: image)
            style.addSource(imgSource)

            let layer = MLNRasterStyleLayer(identifier: layerId, source: imgSource)
            layer.rasterOpacity = NSExpression(forConstantValue: currentOpacities[source.id] ?? 1.0)
            style.addLayer(layer)
        }

        // MARK: Reference overlays (LSIB, OS, FTW)

        func syncReferenceOverlays(style: MLNStyle) {
            // Remove existing reference layers
            for id in ["ref-lsib", "ref-os-field", "ref-ftw-fill", "ref-ftw-outline"] {
                if let layer = style.layer(withIdentifier: id) {
                    style.removeLayer(layer)
                }
            }
            for id in ["refsrc-lsib", "refsrc-os-field", "refsrc-ftw"] {
                if let source = style.source(withIdentifier: id) {
                    style.removeSource(source)
                }
            }

            // LSIB political boundaries
            if showingPoliticalBoundaries {
                let source = MLNRasterTileSource(
                    identifier: "refsrc-lsib",
                    tileURLTemplates: [CropMapOverlayFactory.lsibTemplate],
                    options: [.tileSize: 256]
                )
                style.addSource(source)
                let layer = MLNRasterStyleLayer(identifier: "ref-lsib", source: source)
                style.addLayer(layer)
            }

            // OS Field Boundaries
            if showingFieldBoundaries, let key = KeychainService.load(for: .osDataHub) {
                let template = CropMapOverlayFactory.osFieldBoundaryTemplate(apiKey: key)
                let source = MLNRasterTileSource(
                    identifier: "refsrc-os-field",
                    tileURLTemplates: [template],
                    options: [.tileSize: 256, .maximumZoomLevel: 20]
                )
                style.addSource(source)
                let layer = MLNRasterStyleLayer(identifier: "ref-os-field", source: source)
                style.addLayer(layer)
            }

            // FTW field boundaries (PMTiles — native MapLibre support)
            if showingFTWBoundaries {
                let source = MLNVectorTileSource(
                    identifier: "refsrc-ftw",
                    tileURLTemplates: ["pmtiles://https://data.source.coop/kerner-lab/fields-of-the-world/ftw-sources.pmtiles"]
                )
                style.addSource(source)

                let fill = MLNFillStyleLayer(identifier: "ref-ftw-fill", source: source)
                fill.sourceLayerIdentifier = "default"
                fill.fillColor = NSExpression(forConstantValue: UIColor.yellow.withAlphaComponent(0.15))
                style.addLayer(fill)

                let outline = MLNLineStyleLayer(identifier: "ref-ftw-outline", source: source)
                outline.sourceLayerIdentifier = "default"
                outline.lineColor = NSExpression(forConstantValue: UIColor.yellow.withAlphaComponent(0.6))
                outline.lineWidth = NSExpression(forConstantValue: 1.0)
                style.addLayer(outline)
            }
        }

        // MARK: Tile loading feedback

        /// Set to true only when new data sources are added (not on pan/zoom)
        private var waitingForInitialRender = false
        private var loadingStartTime: Date?

        func mapViewDidFinishRenderingFrame(_ mapView: MLNMapView, fullyRendered: Bool) {
            if fullyRendered && waitingForInitialRender {
                waitingForInitialRender = false
                if let start = loadingStartTime {
                    let elapsed = Date().timeIntervalSince(start)
                    ActivityLog.shared.success(String(format: "Loaded (%.1fs)", elapsed))
                }
                loadingStartTime = nil
            }
        }

        func mapViewDidFailLoadingMap(_ mapView: MLNMapView, withError error: Error) {
            ActivityLog.shared.error("Map loading failed: \(error.localizedDescription)")
            waitingForInitialRender = false
            loadingStartTime = nil
        }

        // MARK: Region tracking

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.centerCoordinate
            let zoom = mapView.zoomLevel

            Task { @MainActor in
                AppSettings.shared.mapCenter = center
                AppSettings.shared.mapZoomLevel = zoom

                if AppSettings.shared.autoBestMap {
                    let current = AppSettings.shared.selectedCropMap
                    if let best = CropMapSource.bestSource(at: center.latitude, longitude: center.longitude),
                       best.sourceName != current.sourceName {
                        AppSettings.shared.hiddenClasses = []
                        AppSettings.shared.selectedCropMap = best
                        ActivityLog.shared.info("Auto: \(best.displayName)")
                    }
                }
            }

            // Auto-switch when panned outside current source's coverage
            if AppSettings.shared.autoBestMap,
               !hasAutoSwitched,
               !currentSources.isEmpty {
                let firstSource = currentSources[0]
                if firstSource.coverageRegion != nil,
                   !firstSource.covers(latitude: center.latitude, longitude: center.longitude) {
                    hasAutoSwitched = true
                    NotificationCenter.default.post(
                        name: .cropMapAutoSwitch, object: nil,
                        userInfo: ["latitude": center.latitude, "longitude": center.longitude]
                    )
                }
            }
        }

        // MARK: Long press crop identification

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let mapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let source = currentSources.first ?? .none
            Task { @MainActor in
                await Self.performCropIdentification(coordinate: coordinate, source: source)
            }
        }

        @MainActor
        private static func performCropIdentification(coordinate: CLLocationCoordinate2D, source: CropMapSource) async {
            guard source != .none else { return }
            let lat = coordinate.latitude, lon = coordinate.longitude
            let locStr = String(format: "%.4f\u{00B0}%@, %.4f\u{00B0}%@",
                                abs(lat), lat >= 0 ? "N" : "S",
                                abs(lon), lon >= 0 ? "E" : "W")

            ActivityLog.shared.activity("Identifying at \(locStr)")

            // GEOGLAM: local pixel sampling
            switch source {
            case .geoglamMajorityCrop, .geoglam:
                if let result = identifyGEOGLAMPixel(lat: lat, lon: lon, source: source) {
                    ActivityLog.shared.success("\(source.sourceName): \(result) at \(locStr)")
                } else {
                    ActivityLog.shared.info("No data at \(locStr)")
                }
                return
            default:
                break
            }

            // WMS: GetFeatureInfo for current year
            let currentResult = await queryWMSFeatureInfo(source: source, lat: lat, lon: lon)
            if let result = currentResult {
                ActivityLog.shared.info("\(source.sourceName) \(source.currentYear): \(result)")
            } else {
                ActivityLog.shared.info("\(source.sourceName) \(source.currentYear): No data at \(locStr)")
            }

            // Query all other available years in parallel
            if let years = source.availableYears, years.count > 1 {
                var yearResults: [(Int, String)] = []
                await withTaskGroup(of: (Int, String?).self) { group in
                    for year in years where year != source.currentYear {
                        let yearSource = source.withYear(year)
                        group.addTask {
                            return (year, await queryWMSFeatureInfo(source: yearSource, lat: lat, lon: lon))
                        }
                    }
                    for await (year, result) in group {
                        if let result { yearResults.append((year, result)) }
                    }
                }
                yearResults.sort { $0.0 > $1.0 }
                if !yearResults.isEmpty {
                    var lines = ["Crop history at \(locStr):"]
                    if let cr = currentResult { lines.append("  \(source.currentYear): \(cr)") }
                    for (year, result) in yearResults { lines.append("  \(year): \(result)") }
                    ActivityLog.shared.info(lines.joined(separator: "\n"))
                }
            }

            if let cr = currentResult {
                ActivityLog.shared.success("\(source.sourceName) \(source.currentYear): \(cr) at \(locStr)")
            } else {
                ActivityLog.shared.success("No data at \(locStr)")
            }
        }

        // MARK: - WMS GetFeatureInfo

        private static func queryWMSFeatureInfo(source: CropMapSource, lat: Double, lon: Double) async -> String? {
            guard let (baseURL, layers) = wmsInfoParams(for: source) else { return nil }

            let delta = 0.00005
            let bbox = "\(lon-delta),\(lat-delta),\(lon+delta),\(lat+delta)"
            let base = "\(baseURL)?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetFeatureInfo" +
                "&LAYERS=\(layers)&QUERY_LAYERS=\(layers)&SRS=EPSG:4326" +
                "&BBOX=\(bbox)&WIDTH=1&HEIGHT=1&X=0&Y=0"

            // Try JSON first
            if let url = URL(string: "\(base)&INFO_FORMAT=application/json") {
                do {
                    let (data, resp) = try await URLSession.shared.data(from: url)
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200,
                       let result = parseJSONFeatureInfo(data) {
                        return result
                    }
                } catch {}
            }

            // Fallback to text/plain
            if let url = URL(string: "\(base)&INFO_FORMAT=text/plain") {
                do {
                    let (data, resp) = try await URLSession.shared.data(from: url)
                    if let http = resp as? HTTPURLResponse, http.statusCode == 200,
                       let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !text.isEmpty {
                        return parseTextFeatureInfo(text)
                    }
                } catch {}
            }

            return nil
        }

        private static func wmsInfoParams(for source: CropMapSource) -> (baseURL: String, layers: String)? {
            switch source {
            case .usdaCDL(let year):
                return ("https://nassgeodata.gmu.edu/CropScapeService/wms_cdlall.cgi", "cdl_\(year)")
            case .jrcEUCropMap(let year):
                return ("https://jeodpp.jrc.ec.europa.eu/jeodpp/services/ows/wms/landcover/eucropmap", "LC.EUCROPMAP.\(year)")
            case .cromeEngland(let year):
                return ("https://environment.data.gov.uk/spatialdata/crop-map-of-england-\(year)/wms", "Crop_Map_Of_England_\(year)")
            case .dlrCropTypes:
                return ("https://geoservice.dlr.de/eoc/land/wms", "CROPTYPES_DE_P1Y")
            case .rpgFrance:
                return ("https://data.geopf.fr/wms-r/wms", "LANDUSE.AGRICULTURE.LATEST")
            case .aafcCanada(let year):
                return ("https://agriculture.canada.ca/atlas/services/imageservices/annual_crop_inventory_\(year)/ImageServer/WMSServer", "0")
            case .esaWorldCover(let year):
                return ("https://services.terrascope.be/wms/v2", "WORLDCOVER_\(year)_MAP")
            case .brpNetherlands:
                return ("https://service.pdok.nl/rvo/brpgewaspercelen/wms/v1_0", "BrpGewas")
            case .invekosAustria:
                return ("https://inspire.lfrz.gv.at/009501/wms", "inspire_feldstuecke_2025-2")
            case .alvFlanders:
                return ("https://geo.api.vlaanderen.be/ALV/wms", "LbGebrPerc2024")
            case .sigpacSpain:
                return ("https://wms.mapa.gob.es/sigpac/wms", "AU.Sigpac:recinto")
            case .fvmDenmark:
                return ("https://geodata.fvm.dk/geoserver/ows", "Marker_2024")
            case .lpisCzechia:
                return ("https://mze.gov.cz/public/app/wms/public_DPB_PB_OPV.fcgi", "DPB_UCINNE")
            case .gerkSlovenia:
                return ("https://storitve.eprostor.gov.si/ows-pub-wms/SI.MKGP.GERK/ows", "RKG_BLOK_GERK")
            case .arkodCroatia:
                return ("https://servisi.apprrr.hr/NIPP/wms", "hr.land_parcels")
            case .gsaaEstonia:
                return ("https://kls.pria.ee/geoserver/inspire_gsaa/wms", "inspire_gsaa")
            case .latviaFieldBlocks:
                return ("https://karte.lad.gov.lv/arcgis/services/lauku_bloki/MapServer/WMSServer", "0")
            case .ifapPortugal:
                return ("https://www.ifap.pt/isip/ows/isip.data/wms", "Parcelas_2019_Centro")
            case .lpisPoland:
                return ("https://mapy.geoportal.gov.pl/wss/ext/arimr_lpis", "14")
            case .jordbrukSweden:
                return ("https://epub.sjv.se/inspire/inspire/wms", "jordbruksblock")
            case .flikLuxembourg:
                return ("https://wms.inspire.geoportail.lu/geoserver/af/wms", "af:asta_flik_parcels")
            case .blwSwitzerland:
                return ("https://wms.geo.admin.ch/", "ch.blw.landwirtschaftliche-nutzungsflaechen")
            case .abaresAustralia:
                return ("https://di-daa.img.arcgis.com/arcgis/services/Land_and_vegetation/Catchment_Scale_Land_Use_Simplified/ImageServer/WMSServer", "Catchment_Scale_Land_Use_Simplified")
            case .lcdbNewZealand:
                return ("https://maps.scinfo.org.nz/lcdb/wms", "lcdb_lcdb6")
            case .geoIntaArgentina:
                return ("https://geo-backend.inta.gob.ar/geoserver/wms", "geonode:mnc_verano2024_f300268fd112b0ec3ef5f731edb78882")
            default:
                return nil
            }
        }

        private static func parseJSONFeatureInfo(_ data: Data) -> String? {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]],
                  let first = features.first,
                  let properties = first["properties"] as? [String: Any],
                  !properties.isEmpty else { return nil }

            let cropKeys = ["category", "cropname", "crop_name", "cromeid", "lucode", "lu_name",
                            "class_name", "classname", "label", "crop", "type", "name",
                            "dn", "gray_index", "pixel_value", "value"]
            let lowerProps = Dictionary(uniqueKeysWithValues: properties.map { ($0.key.lowercased(), $0.value) })
            for key in cropKeys {
                if let val = lowerProps[key] {
                    let v = "\(val)"
                    if v != "<null>" && !v.isEmpty && v != "0" { return v }
                }
            }
            let pairs = properties.compactMap { key, val -> String? in
                if val is NSNull { return nil }
                let s = "\(val)"; if s == "<null>" { return nil }
                return "\(key): \(s)"
            }
            return pairs.isEmpty ? nil : pairs.joined(separator: ", ")
        }

        private static func parseTextFeatureInfo(_ text: String) -> String? {
            let lines = text.components(separatedBy: .newlines)
            var values: [String] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("-") || trimmed.hasPrefix("Results") { continue }
                if trimmed.contains("=") {
                    let parts = trimmed.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                    guard parts.count >= 2 else { continue }
                    let key = parts[0].lowercased()
                    let val = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                    if key.contains("geom") || key == "objectid" || key == "fid" || key == "gml_id" { continue }
                    if !val.isEmpty && val != "null" { values.append("\(parts[0]): \(val)") }
                }
            }
            return values.isEmpty ? nil : values.joined(separator: ", ")
        }

        // MARK: - GEOGLAM pixel sampling

        @MainActor
        private static func identifyGEOGLAMPixel(lat: Double, lon: Double, source: CropMapSource) -> String? {
            guard let legend = CropMapLegendData.forSource(source) else { return nil }

            let image: UIImage?
            switch source {
            case .geoglamMajorityCrop: image = GEOGLAMOverlayManager.shared.mercatorImage(for: nil)
            case .geoglam(let crop): image = GEOGLAMOverlayManager.shared.mercatorImage(for: crop)
            default: return nil
            }

            guard let cgImage = image?.cgImage else { return nil }
            let w = cgImage.width, h = cgImage.height

            // Web Mercator pixel lookup (replaces MKMapPoint)
            let xFrac = (lon + 180.0) / 360.0
            let latRad = lat * .pi / 180.0
            let yFrac = (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0
            let px = Int(xFrac * Double(w))
            let py = Int(yFrac * Double(h))
            guard px >= 0, px < w, py >= 0, py < h else { return nil }

            let cropRect = CGRect(x: px, y: py, width: 1, height: 1)
            guard let cropped = cgImage.cropping(to: cropRect),
                  let ctx = CGContext(
                      data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return nil }

            ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            guard let data = ctx.data else { return nil }
            let buf = data.bindMemory(to: UInt8.self, capacity: 4)
            let r = buf[0], g = buf[1], b = buf[2], a = buf[3]
            guard a > 0 else { return nil }

            // Unpremultiply if needed
            let ur: UInt8, ug: UInt8, ub: UInt8
            if a < 255 {
                ur = UInt8(min(255, Int(r) * 255 / Int(a)))
                ug = UInt8(min(255, Int(g) * 255 / Int(a)))
                ub = UInt8(min(255, Int(b) * 255 / Int(a)))
            } else {
                ur = r; ug = g; ub = b
            }

            // Match against legend colors
            let tolerance = 40
            for entry in legend.entries {
                let uiColor = UIColor(entry.color)
                var er: CGFloat = 0, eg: CGFloat = 0, eb: CGFloat = 0
                uiColor.getRed(&er, green: &eg, blue: &eb, alpha: nil)
                let lr = UInt8(er * 255), lg = UInt8(eg * 255), lb = UInt8(eb * 255)
                if abs(Int(ur) - Int(lr)) <= tolerance &&
                   abs(Int(ug) - Int(lg)) <= tolerance &&
                   abs(Int(ub) - Int(lb)) <= tolerance {
                    return entry.label
                }
            }
            return "Unknown (R:\(ur) G:\(ug) B:\(ub))"
        }
    }
}

#Preview {
    MapView()
        .environment(AppSettings.shared)
}
#endif
