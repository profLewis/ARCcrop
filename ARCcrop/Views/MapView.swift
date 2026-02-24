import SwiftUI
import MapKit

struct MapView: View {
    @State private var region = MapCameraPosition.automatic

    var body: some View {
        NavigationStack {
            Map(position: $region) {
            }
            .navigationTitle("Crop Map")
            #if !os(tvOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    MapView()
}
