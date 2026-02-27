import SwiftUI
import MapKit

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
            // Union of all active layers that have year ranges
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
                    mapType: settings.effectiveMapType,
                    isBlank: settings.mapStyle == .blank,
                    hiddenClasses: settings.hiddenClasses,
                    showFieldBoundaries: settings.showFieldBoundaries,
                    showPoliticalBoundaries: settings.showPoliticalBoundaries,
                    showMasterMap: settings.showMasterMap,
                    showFTWBoundaries: settings.showFTWBoundaries,
                    showLabelsAbove: settings.showLabelsAbove
                )
                .ignoresSafeArea(edges: .bottom)

                // Top-right: year stepper + map controls
                VStack(alignment: .trailing, spacing: 6) {
                    if let yearRange = effectiveYearRange {
                        YearStepperView(
                            year: settings.focusedCropMap.currentYear,
                            range: yearRange
                        ) { newYear in
                            if settings.syncYearAcrossLayers && settings.activeCropMaps.count > 1 {
                                // Update all layers to closest available year
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

                    // Layer opacity control (only when at least one crop map is active)
                    if !settings.activeCropMaps.isEmpty {
                        LayerOpacityControl()
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Bottom-left: legends (multi-layer) + zoom level bottom-right
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        MultiLegendView()
                            .padding(8)
                        Spacer()
                        // Zoom level indicator
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

                // Top-left: status banner
                if settings.showStatusBanner, let msg = log.latestMessage {
                    VStack {
                        HStack {
                            Spacer()
                            StatusBannerView(message: log.progressText ?? msg, level: log.latestLevel ?? .info, isActive: log.isActive, tileProgress: log.tileProgress)
                            Spacer()
                        }
                        .padding(.top, 4)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    CropMapPickerView()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { isSearching = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingLog = true } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .sheet(isPresented: $isSearching) {
                PlaceSearchSheet { coordinate in
                    isSearching = false
                    NotificationCenter.default.post(
                        name: .mapZoomToCoordinate, object: nil,
                        userInfo: ["coordinate": coordinate]
                    )
                    // Auto-switch crop map if current doesn't cover new location (only when auto mode on)
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

    private var isMultiLine: Bool { message.contains("\n") }

    var body: some View {
        VStack(spacing: 2) {
            if isMultiLine {
                // Multi-line results (e.g. crop history) — vertical scroll
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

    /// Whether the UK is currently in/near the map view
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

// MARK: - Layer opacity control (vertical slider + horizontal layer cycling)

struct LayerOpacityControl: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 2) {
            // Layer indicator dots (one per active layer)
            if settings.activeCropMaps.count > 1 {
                HStack(spacing: 3) {
                    ForEach(Array(settings.activeCropMaps.enumerated()), id: \.element.id) { idx, _ in
                        Circle()
                            .fill(idx == settings.focusedLayerIndex ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 5, height: 5)
                    }
                }

                // Focused layer name
                Text(settings.focusedCropMap.sourceName)
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 50)
            }

            // Vertical slider for focused layer opacity
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
                    // Horizontal swipe to cycle layers
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

// MARK: - MKMapView wrapper

struct MapContainerView: UIViewRepresentable {
    var activeCropMaps: [CropMapSource]
    var layerOpacity: [String: Double]
    var mapType: UInt
    var isBlank: Bool
    var hiddenClasses: Set<String>
    var showFieldBoundaries: Bool
    var showPoliticalBoundaries: Bool
    var showMasterMap: Bool
    var showFTWBoundaries: Bool
    var showLabelsAbove: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = MKMapType(rawValue: mapType) ?? .hybrid
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false

        NotificationCenter.default.addObserver(
            forName: .mapZoomToCoordinate, object: nil, queue: .main
        ) { notification in
            if let coord = notification.userInfo?["coordinate"] as? CLLocationCoordinate2D {
                let region = MKCoordinateRegion(center: coord, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
                mapView.setRegion(region, animated: true)
            }
        }

        // Long press to identify crop class at pixel
        let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        context.coordinator.mapView = mapView

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let newType = MKMapType(rawValue: mapType) ?? .hybrid
        if mapView.mapType != newType {
            let savedRegion = mapView.region
            mapView.mapType = newType
            mapView.setRegion(savedRegion, animated: false)
        }

        let coord = context.coordinator
        let sourcesChanged = coord.currentSources.map(\.id) != activeCropMaps.map(\.id)
        let styleChanged = coord.currentMapType != mapType || coord.wasBlank != isBlank
        let filterChanged = coord.currentHidden != hiddenClasses
        let fieldBoundaryChanged = coord.showingFieldBoundaries != showFieldBoundaries
        let politicalChanged = coord.showingPoliticalBoundaries != showPoliticalBoundaries
        let masterMapChanged = coord.showingMasterMap != showMasterMap
        let ftwChanged = coord.showingFTWBoundaries != showFTWBoundaries
        let refOverlayChanged = fieldBoundaryChanged || politicalChanged || masterMapChanged || ftwChanged
        let opacityChanged = coord.currentOpacities != layerOpacity
        let labelsChanged = coord.currentLabelsAbove != showLabelsAbove

        // Update opacity on existing renderers without rebuilding
        if opacityChanged {
            coord.currentOpacities = layerOpacity
            for overlay in mapView.overlays {
                if Self.isReferenceOverlay(overlay) { continue }
                if let sourceID = coord.overlaySourceMap[ObjectIdentifier(overlay as AnyObject)],
                   let renderer = mapView.renderer(for: overlay) {
                    renderer.alpha = CGFloat(layerOpacity[sourceID] ?? 1.0)
                }
            }
        }

        // Re-order overlays when labels-above setting changes (no data reload needed)
        if labelsChanged && !sourcesChanged && !filterChanged {
            coord.currentLabelsAbove = showLabelsAbove
            let newLevel: MKOverlayLevel = showLabelsAbove ? .aboveRoads : .aboveLabels
            let allOverlays = mapView.overlays
            mapView.removeOverlays(allOverlays)
            for overlay in allOverlays {
                if Self.isReferenceOverlay(overlay) {
                    mapView.addOverlay(overlay, level: .aboveLabels)
                } else {
                    mapView.addOverlay(overlay, level: newLevel)
                }
            }
        }

        // Only rebuild overlays if something actually changed
        guard sourcesChanged || styleChanged || filterChanged || refOverlayChanged else { return }

        // For style/overlay-only changes, just toggle reference overlays without touching data overlays
        if !sourcesChanged && !filterChanged {
            coord.currentMapType = mapType
            coord.wasBlank = isBlank
            Self.syncReferenceOverlays(on: mapView, coord: coord,
                                        showFieldBoundaries: showFieldBoundaries,
                                        showPoliticalBoundaries: showPoliticalBoundaries,
                                        showMasterMap: showMasterMap,
                                        showFTWBoundaries: showFTWBoundaries,
                                        isBlank: isBlank)
            return
        }

        // Detect newly added sources (for zoom-to-coverage)
        let oldIDs = Set(coord.currentSources.map(\.id))
        let newIDs = Set(activeCropMaps.map(\.id))
        let addedIDs = newIDs.subtracting(oldIDs)

        coord.currentSources = activeCropMaps
        coord.currentMapType = mapType
        coord.wasBlank = isBlank
        coord.currentHidden = hiddenClasses
        coord.currentLabelsAbove = showLabelsAbove
        coord.currentOpacities = layerOpacity
        coord.hasAutoSwitched = false

        // Remove all overlays and rebuild
        mapView.removeOverlays(mapView.overlays)
        coord.geoglamRenderer = nil
        coord.overlaySourceMap = [:]
        ActivityLog.shared.resetTileProgress()

        // Dark tile base when "No Base Map"
        if isBlank {
            mapView.addOverlay(BlankTileOverlay(), level: .aboveLabels)
        }

        // Zoom to coverage of newly added source (last one added)
        if let addedSource = activeCropMaps.last, addedIDs.contains(addedSource.id),
           let region = addedSource.coverageRegion {
            let center = CLLocationCoordinate2D(latitude: region.lat, longitude: region.lon)
            let covRegion = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: region.latSpan, longitudeDelta: region.lonSpan)
            )
            let visible = mapView.region
            let overlaps = abs(visible.center.latitude - center.latitude) < (visible.span.latitudeDelta + region.latSpan) / 2 &&
                           abs(visible.center.longitude - center.longitude) < (visible.span.longitudeDelta + region.lonSpan) / 2
            if !overlaps {
                mapView.setRegion(covRegion, animated: true)
            }
        }

        // Compute hidden RGB values for pixel filtering
        var allHiddenRGBs: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for source in activeCropMaps {
            if let legend = CropMapLegendData.forSource(source), !hiddenClasses.isEmpty {
                let rgbs = LegendColorExtractor.rgbValues(for: legend.entries, matching: hiddenClasses)
                allHiddenRGBs.append(contentsOf: rgbs)
            }
        }

        // Add data overlays for each active source (level depends on labels-above setting)
        let dataLevel: MKOverlayLevel = showLabelsAbove ? .aboveRoads : .aboveLabels
        for source in activeCropMaps {
            let sourceOpacity = layerOpacity[source.id] ?? 1.0

            // Per-source hidden RGBs
            let sourceRGBs: [(r: UInt8, g: UInt8, b: UInt8)]
            if let legend = CropMapLegendData.forSource(source), !hiddenClasses.isEmpty {
                sourceRGBs = LegendColorExtractor.rgbValues(for: legend.entries, matching: hiddenClasses)
            } else {
                sourceRGBs = []
            }

            switch source {
            case .none:
                break
            case .geoglamMajorityCrop:
                ActivityLog.shared.activity("Loading GEOGLAM Majority Crop (reprojecting...)")
                if let overlay = GEOGLAMOverlayManager.shared.majorityCropOverlay() {
                    mapView.addOverlay(overlay, level: dataLevel)
                    coord.overlaySourceMap[ObjectIdentifier(overlay)] = source.id
                }
            case .geoglam(let crop):
                ActivityLog.shared.activity("Loading GEOGLAM \(crop.rawValue) (reprojecting...)")
                if let overlay = GEOGLAMOverlayManager.shared.overlay(for: crop) {
                    mapView.addOverlay(overlay, level: dataLevel)
                    coord.overlaySourceMap[ObjectIdentifier(overlay)] = source.id
                }
            default:
                if let tileOverlay = CropMapOverlayFactory.makeTileOverlay(for: source) {
                    if !sourceRGBs.isEmpty {
                        let filtered = FilteredTileOverlay(source: tileOverlay, hiddenRGBs: sourceRGBs)
                        mapView.addOverlay(filtered, level: dataLevel)
                        coord.overlaySourceMap[ObjectIdentifier(filtered)] = source.id
                        ActivityLog.shared.activity("Loading \(source.sourceName) (filtering \(hiddenClasses.count) classes)")
                    } else {
                        mapView.addOverlay(tileOverlay, level: dataLevel)
                        coord.overlaySourceMap[ObjectIdentifier(tileOverlay)] = source.id
                        ActivityLog.shared.activity("Loading \(source.sourceName)")
                    }
                } else {
                    ActivityLog.shared.warn("\(source.sourceName): no WMS endpoint available")
                }
            }
        }

        // Reference overlays (political boundaries, field boundaries, MasterMap, FTW)
        Self.syncReferenceOverlays(on: mapView, coord: coord,
                                    showFieldBoundaries: showFieldBoundaries,
                                    showPoliticalBoundaries: showPoliticalBoundaries,
                                    showMasterMap: showMasterMap,
                                    showFTWBoundaries: showFTWBoundaries,
                                    isBlank: isBlank)

        // Store hidden colors for GEOGLAM renderer
        coord.pendingHiddenRGBs = allHiddenRGBs
    }

    /// Helper to check if an overlay is a reference/base overlay (not a data overlay)
    private static func isReferenceOverlay(_ overlay: MKOverlay) -> Bool {
        overlay is BlankTileOverlay || overlay is OSFieldBoundaryOverlay ||
        overlay is LSIBOverlay || overlay is PMTileOverlay
    }

    /// Add/remove all reference overlays based on current toggle states
    private static func syncReferenceOverlays(
        on mapView: MKMapView, coord: Coordinator,
        showFieldBoundaries: Bool, showPoliticalBoundaries: Bool,
        showMasterMap: Bool, showFTWBoundaries: Bool, isBlank: Bool
    ) {
        // Remove existing reference overlays
        let refs = mapView.overlays.filter { isReferenceOverlay($0) }
        mapView.removeOverlays(refs)
        // Also remove MasterMap polygons
        let masterMapOverlays = mapView.overlays.filter { coord.masterMapOverlayIDs.contains(ObjectIdentifier($0 as AnyObject)) }
        mapView.removeOverlays(masterMapOverlays)
        coord.masterMapOverlayIDs.removeAll()

        // Re-add based on current state
        if isBlank {
            mapView.insertOverlay(BlankTileOverlay(), at: 0, level: .aboveLabels)
        }
        if showFieldBoundaries, let key = KeychainService.load(for: .osDataHub) {
            mapView.addOverlay(OSFieldBoundaryOverlay(apiKey: key), level: .aboveLabels)
        }
        coord.showingFieldBoundaries = showFieldBoundaries

        if showPoliticalBoundaries {
            mapView.addOverlay(LSIBOverlay(), level: .aboveLabels)
        }
        coord.showingPoliticalBoundaries = showPoliticalBoundaries

        if showFTWBoundaries {
            let ftw = PMTileOverlay(url: URL(string: "https://data.source.coop/kerner-lab/fields-of-the-world/ftw-sources.pmtiles")!)
            mapView.addOverlay(ftw, level: .aboveLabels)
        }
        coord.showingFTWBoundaries = showFTWBoundaries

        // OS MasterMap WFS — will be loaded on demand via regionDidChangeAnimated
        coord.showingMasterMap = showMasterMap
        if showMasterMap {
            coord.masterMapQueryPending = true
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var currentSources: [CropMapSource] = []
        var currentMapType: UInt = 2
        var wasBlank = false
        var currentHidden: Set<String> = []
        var pendingHiddenRGBs: [(r: UInt8, g: UInt8, b: UInt8)] = []
        var geoglamRenderer: GEOGLAMOverlayRenderer?
        var showingFieldBoundaries = false
        var showingPoliticalBoundaries = false
        var showingMasterMap = false
        var showingFTWBoundaries = false
        var masterMapQueryPending = false
        var masterMapOverlayIDs: Set<ObjectIdentifier> = []
        var currentOpacities: [String: Double] = [:]
        var currentLabelsAbove = false
        /// Map overlay ObjectIdentifier → source ID for per-layer opacity
        var overlaySourceMap: [ObjectIdentifier: String] = [:]
        /// Prevent repeated out-of-bounds auto-switch per source selection
        var hasAutoSwitched = false
        weak var mapView: MKMapView?

        private var tileLoadLogged = false

        func mapView(_ mapView: MKMapView, didFinishRenderingMap fullyRendered: Bool) {
            if !tileLoadLogged, !currentSources.isEmpty {
                tileLoadLogged = true
                let center = mapView.centerCoordinate
                let names = currentSources.map(\.sourceName).joined(separator: ", ")
                Task { @MainActor in
                    ActivityLog.shared.success(
                        "\(names) rendered at \(String(format: "%.2f", center.latitude))N, \(String(format: "%.2f", center.longitude))E"
                    )
                }
            }
        }

        /// When user pans/zooms, cancel stale tile downloads and detect out-of-bounds
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Update map center and zoom level; cancel stale tile downloads on zoom change
            let center = mapView.centerCoordinate
            let lonDelta = mapView.region.span.longitudeDelta
            let zoom = lonDelta > 0 ? log2(360.0 * Double(mapView.frame.width) / (256.0 * lonDelta)) : 0
            WMSTileOverlay.cancelStaleDownloads(currentZoom: Int(zoom))
            Task { @MainActor in
                AppSettings.shared.mapCenter = center
                AppSettings.shared.mapZoomLevel = zoom

                // Auto-best-map: always pick best source for current location
                if AppSettings.shared.autoBestMap {
                    let current = AppSettings.shared.selectedCropMap
                    if let best = CropMapSource.bestSource(at: center.latitude, longitude: center.longitude),
                       best.sourceName != current.sourceName {
                        AppSettings.shared.hiddenClasses = []
                        AppSettings.shared.selectedCropMap = best
                        ActivityLog.shared.info("Auto: \(best.displayName)")
                    }
                    return
                }
            }

            // Auto-switch when panned outside current source's coverage (only when auto-best-map is on)
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

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            tileLoadLogged = false
            let isBaseOverlay = overlay is BlankTileOverlay || overlay is OSFieldBoundaryOverlay || overlay is LSIBOverlay || overlay is PMTileOverlay
            let sourceID = overlaySourceMap[ObjectIdentifier(overlay as AnyObject)]
            let alpha = CGFloat(sourceID.flatMap { currentOpacities[$0] } ?? 1.0)

            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(overlay: tileOverlay)
                if !isBaseOverlay { renderer.alpha = alpha }
                return renderer
            }
            if let geoglamOverlay = overlay as? GEOGLAMMapOverlay {
                let renderer = GEOGLAMOverlayRenderer(overlay: geoglamOverlay)
                renderer.hiddenRGBs = pendingHiddenRGBs
                renderer.alpha = alpha
                geoglamRenderer = renderer
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: - Long press crop identification

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
            let locStr = String(format: "%.4f°%@, %.4f°%@",
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
            // Return all non-null properties
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

            let overlay: GEOGLAMMapOverlay?
            switch source {
            case .geoglamMajorityCrop: overlay = GEOGLAMOverlayManager.shared.majorityCropOverlay()
            case .geoglam(let crop): overlay = GEOGLAMOverlayManager.shared.overlay(for: crop)
            default: return nil
            }

            guard let image = overlay?.image, let cgImage = image.cgImage else { return nil }
            let w = cgImage.width, h = cgImage.height
            // Image is now Mercator-projected — use MKMapPoint for pixel lookup
            let mapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            let world = MKMapRect.world
            let px = Int(mapPoint.x / world.size.width * Double(w))
            let py = Int(mapPoint.y / world.size.height * Double(h))
            guard px >= 0, px < w, py >= 0, py < h else { return nil }

            // Crop single pixel and read color
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
