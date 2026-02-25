import SwiftUI

struct CropMapPickerView: View {
    @Binding var selectedSource: CropMapSource

    var body: some View {
        Menu {
            Button {
                selectedSource = .none
            } label: {
                if case .none = selectedSource {
                    Label("None", systemImage: "checkmark")
                } else {
                    Text("None")
                }
            }

            Section("GEOGLAM (Embedded)") {
                sourceButton(.geoglamCropPicture, icon: "paintpalette.fill")
                ForEach(GEOGLAMCrop.allCases) { crop in
                    sourceButton(.geoglam(crop), icon: "leaf.fill")
                }
            }

            Section("WMS Services") {
                sourceButton(.usdaCDL(year: 2023), icon: "flag.fill")
                sourceButton(.gladCropland(year: 2020), icon: "map.fill")
            }

            Section("Requires API Key") {
                sourceButton(.dynamicWorld, icon: "globe")
                sourceButton(.worldCereal, icon: "globe.europe.africa.fill")
                sourceButton(.copernicusLandCover, icon: "satellite.fill")
                sourceButton(.fromGLC, icon: "square.grid.3x3.fill")
                sourceButton(.mapBiomas(year: 2022), icon: "leaf.arrow.circlepath")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.3.layers.3d")
                Text(selectedSource == .none ? "Crop Map" : selectedSource.displayName)
                    .lineLimit(1)
            }
            .font(.callout.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }

    private func sourceButton(_ source: CropMapSource, icon: String) -> some View {
        Button {
            selectedSource = source
        } label: {
            HStack {
                Label(source.displayName, systemImage: icon)
                if source.id == selectedSource.id {
                    Image(systemName: "checkmark")
                }
                if source.requiresAPIKey && !source.isAvailable {
                    Image(systemName: "key")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
