import SwiftUI

struct CropMapPickerView: View {
    @Binding var selectedSource: CropMapSource

    var body: some View {
        Menu {
            Button("None") {
                selectedSource = .none
            }

            Section("GEOGLAM (Embedded)") {
                Button {
                    selectedSource = .geoglamCropPicture
                } label: {
                    Label("Crop Picture RGB (2022)", systemImage: "paintpalette.fill")
                }
                ForEach(GEOGLAMCrop.allCases) { crop in
                    Button {
                        selectedSource = .geoglam(crop)
                    } label: {
                        Label("\(crop.rawValue) (2022)", systemImage: "leaf.fill")
                    }
                }
            }

            Section("WMS Services") {
                Button {
                    selectedSource = .usdaCDL(year: 2023)
                } label: {
                    Label("USDA CDL (2023, US)", systemImage: "flag.fill")
                }
            }

            Section("Requires API Key") {
                apiKeyButton(.dynamicWorld, icon: "globe")
                apiKeyButton(.worldCereal, icon: "globe.europe.africa.fill")
                apiKeyButton(.gladCropland(year: 2020), icon: "map.fill")
                apiKeyButton(.copernicusLandCover, icon: "satellite.fill")
                apiKeyButton(.fromGLC, icon: "square.grid.3x3.fill")
                apiKeyButton(.mapBiomas(year: 2022), icon: "leaf.arrow.circlepath")
            }
        } label: {
            Label("Crop Map", systemImage: "square.3.layers.3d")
                .font(.callout.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }

    private func apiKeyButton(_ source: CropMapSource, icon: String) -> some View {
        Button {
            selectedSource = source
        } label: {
            HStack {
                Label(source.displayName, systemImage: icon)
                if source.isAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }
}
