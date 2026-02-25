import SwiftUI
import MapKit

#if !os(tvOS)
struct MapView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                MapContainerView(selectedCropMap: Binding(
                    get: { settings.selectedCropMap },
                    set: { handleSourceSelection($0) }
                ))
                .ignoresSafeArea(edges: .bottom)

                VStack(alignment: .trailing, spacing: 8) {
                    CropMapPickerView(selectedSource: Binding(
                        get: { settings.selectedCropMap },
                        set: { handleSourceSelection($0) }
                    ))
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                if let legend = CropMapLegendData.forSource(settings.selectedCropMap) {
                    VStack {
                        Spacer()
                        HStack {
                            CropMapLegendView(legendData: legend)
                                .padding(12)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Crop Map")
            .toolbarTitleDisplayMode(.inline)
        }
    }

    private func handleSourceSelection(_ source: CropMapSource) {
        if source.requiresAPIKey && !source.isAvailable {
            // Remember which source was requested, navigate to Settings API key page
            settings.pendingCropMapSource = source
            settings.apiKeySetupProvider = source.apiKeyProvider
            settings.selectedTab = .settings
        } else {
            settings.hiddenClasses = []
            settings.selectedCropMap = source
        }
    }
}

// MARK: - MKMapView wrapper

struct MapContainerView: UIViewRepresentable {
    @Binding var selectedCropMap: CropMapSource

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coord = context.coordinator
        guard coord.currentSource != selectedCropMap else { return }
        coord.currentSource = selectedCropMap

        mapView.removeOverlays(mapView.overlays)

        switch selectedCropMap {
        case .none:
            break
        case .geoglamCropPicture:
            if let overlay = GEOGLAMOverlayManager.shared.cropPictureOverlay() {
                mapView.addOverlay(overlay, level: .aboveRoads)
            }
        case .geoglam(let crop):
            if let overlay = GEOGLAMOverlayManager.shared.overlay(for: crop) {
                mapView.addOverlay(overlay, level: .aboveRoads)
            }
        case .usdaCDL:
            if let tileOverlay = CropMapOverlayFactory.makeTileOverlay(for: selectedCropMap) {
                mapView.addOverlay(tileOverlay, level: .aboveRoads)
            }
        default:
            break
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var currentSource: CropMapSource = .none

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(overlay: tileOverlay)
            }
            if let geoglamOverlay = overlay as? GEOGLAMMapOverlay {
                return GEOGLAMOverlayRenderer(overlay: geoglamOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#Preview {
    MapView()
        .environment(AppSettings.shared)
}
#endif
