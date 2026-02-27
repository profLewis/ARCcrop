import SwiftUI

struct CropMapPickerView: View {
    @Environment(AppSettings.self) private var settings

    private var lat: Double { settings.mapCenter.latitude }
    private var lon: Double { settings.mapCenter.longitude }

    private func isActive(_ source: CropMapSource) -> Bool {
        settings.activeCropMaps.contains(where: { $0.baseID == source.baseID })
    }

    private var anyGEOGLAMActive: Bool {
        settings.activeCropMaps.contains { src in
            if case .geoglam = src { return true }
            if case .geoglamMajorityCrop = src { return true }
            return false
        }
    }

    private var anyWorldCerealActive: Bool {
        settings.activeCropMaps.contains { src in
            switch src {
            case .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals: return true
            default: return false
            }
        }
    }

    var body: some View {
        Menu {
            Button {
                settings.activeCropMaps = []
                settings.hiddenClasses = []
                WMSTileOverlay.cancelAllDownloads()
                PMTileOverlay.cancelAllDownloads()
            } label: {
                if settings.activeCropMaps.isEmpty {
                    Label("None", systemImage: "checkmark")
                } else {
                    Text("Clear All")
                }
            }

            // MARK: - Global
            Section("Global") {
                Menu {
                    sourceButton(.geoglamMajorityCrop, label: "Majority Crop", icon: "globe")
                    ForEach(GEOGLAMCrop.allCases) { crop in
                        sourceButton(.geoglam(crop), label: "\(crop.rawValue) %", icon: "chart.pie.fill")
                    }
                } label: {
                    Label("GEOGLAM (~5.6km)", systemImage: anyGEOGLAMActive ? "globe.badge.chevron.backward" : "globe")
                }

                Menu {
                    sourceButton(.worldCereal, label: "All Temporary Crops", icon: "globe.europe.africa.fill")
                    sourceButton(.worldCerealMaize, label: "Maize", icon: "globe.europe.africa.fill")
                    sourceButton(.worldCerealWinterCereals, label: "Winter Cereals", icon: "globe.europe.africa.fill")
                    sourceButton(.worldCerealSpringCereals, label: "Spring Cereals", icon: "globe.europe.africa.fill")
                } label: {
                    Label("WorldCereal (10m)", systemImage: anyWorldCerealActive ? "globe.europe.africa.fill" : "globe.europe.africa")
                }

                sourceButton(.esaWorldCover(year: 2021), label: "ESA WorldCover (10m)", icon: "globe.europe.africa")
                sourceButton(.dynamicWorld, label: "Dynamic World (10m)", icon: "globe")
                sourceButton(.copernicusLandCover, label: "Copernicus LC (100m)", icon: "satellite.fill")
                sourceButton(.fromGLC, label: "FROM-GLC (30m)", icon: "square.grid.3x3.fill")
            }

            // MARK: - North America
            Section("North America") {
                sourceButton(.usdaCDL(year: 2023), label: "\u{1F1FA}\u{1F1F8} USDA CDL", icon: "leaf.fill")
                sourceButton(.aafcCanada(year: 2024), label: "\u{1F1E8}\u{1F1E6} AAFC Canada", icon: "leaf.fill")
            }

            // MARK: - South America
            Section("South America") {
                sourceButton(.mapBiomas(year: 2022), label: "\u{1F30E} MapBiomas", icon: "leaf.arrow.circlepath")
                sourceButton(.geoIntaArgentina, label: "\u{1F1E6}\u{1F1F7} GeoINTA Argentina", icon: "leaf.fill")
            }

            // MARK: - Europe — Crop Type Maps
            Section("Europe — Crop Type") {
                sourceButton(.jrcEUCropMap(year: 2022), label: "\u{1F1EA}\u{1F1FA} JRC EU Crop Map", icon: "leaf.fill")
                sourceButton(.cromeEngland(year: 2024), label: "\u{1F1EC}\u{1F1E7} CROME England", icon: "leaf.fill")
                sourceButton(.dlrCropTypes, label: "\u{1F1E9}\u{1F1EA} DLR CropTypes", icon: "leaf.fill")
                sourceButton(.rpgFrance, label: "\u{1F1EB}\u{1F1F7} RPG France", icon: "leaf.fill")
                sourceButton(.brpNetherlands, label: "\u{1F1F3}\u{1F1F1} BRP Netherlands", icon: "leaf.fill")
            }

            // MARK: - Europe — Parcel Maps
            Section("Europe — Parcels") {
                sourceButton(.invekosAustria, label: "\u{1F1E6}\u{1F1F9} INVEKOS Austria", icon: "leaf.fill")
                sourceButton(.alvFlanders, label: "\u{1F1E7}\u{1F1EA} ALV Flanders", icon: "leaf.fill")
                sourceButton(.sigpacSpain, label: "\u{1F1EA}\u{1F1F8} SIGPAC Spain", icon: "leaf.fill")
                sourceButton(.fvmDenmark, label: "\u{1F1E9}\u{1F1F0} FVM Denmark", icon: "leaf.fill")
                sourceButton(.lpisCzechia, label: "\u{1F1E8}\u{1F1FF} LPIS Czechia", icon: "leaf.fill")
                sourceButton(.gerkSlovenia, label: "\u{1F1F8}\u{1F1EE} GERK Slovenia", icon: "leaf.fill")
                sourceButton(.arkodCroatia, label: "\u{1F1ED}\u{1F1F7} ARKOD Croatia", icon: "leaf.fill")
                sourceButton(.gsaaEstonia, label: "\u{1F1EA}\u{1F1EA} GSAA Estonia", icon: "leaf.fill")
                sourceButton(.latviaFieldBlocks, label: "\u{1F1F1}\u{1F1FB} Latvia Fields", icon: "leaf.fill")
                sourceButton(.ifapPortugal, label: "\u{1F1F5}\u{1F1F9} IFAP Portugal", icon: "leaf.fill")
                sourceButton(.lpisPoland, label: "\u{1F1F5}\u{1F1F1} LPIS Poland", icon: "leaf.fill")
                sourceButton(.jordbrukSweden, label: "\u{1F1F8}\u{1F1EA} Jordbruk Sweden", icon: "leaf.fill")
                sourceButton(.flikLuxembourg, label: "\u{1F1F1}\u{1F1FA} FLIK Luxembourg", icon: "leaf.fill")
                sourceButton(.blwSwitzerland, label: "\u{1F1E8}\u{1F1ED} BLW Switzerland", icon: "leaf.fill")
            }

            // MARK: - Oceania
            Section("Oceania") {
                sourceButton(.abaresAustralia, label: "\u{1F1E6}\u{1F1FA} ABARES Australia", icon: "leaf.fill")
                sourceButton(.lcdbNewZealand, label: "\u{1F1F3}\u{1F1FF} LCDB New Zealand", icon: "leaf.fill")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.3.layers.3d")
                if settings.activeCropMaps.isEmpty {
                    Text("Crop Map")
                } else if settings.activeCropMaps.count == 1 {
                    Text(settings.activeCropMaps[0].sourceName)
                } else {
                    Text("\(settings.activeCropMaps.count) layers")
                }
            }
            .font(.callout.bold())
            .lineLimit(1)
        }
    }

    private func sourceButton(_ source: CropMapSource, label: String, icon: String) -> some View {
        let active = isActive(source)
        return Button {
            if source.requiresAPIKey && !source.isAvailable {
                settings.pendingCropMapSource = source
                settings.apiKeySetupProvider = source.apiKeyProvider
                settings.selectedTab = .settings
                return
            }
            if active {
                settings.activeCropMaps.removeAll { $0.baseID == source.baseID }
                WMSTileOverlay.cancelAllDownloads()
                PMTileOverlay.cancelAllDownloads()
            } else {
                // Snap to the currently displayed year if one is showing
                let currentYear = settings.focusedCropMap.currentYear
                let snapped = currentYear > 0 ? source.withClosestYear(currentYear) : source

                // Remove any existing entry of the same source type (different year)
                settings.activeCropMaps.removeAll { $0.baseID == source.baseID }

                // Reset opacity to full colour for the new layer
                settings.layerOpacity[snapped.id] = 1.0

                if settings.allowMultipleLayers {
                    settings.activeCropMaps.append(snapped)
                    settings.focusedLayerIndex = settings.activeCropMaps.count - 1
                    ActivityLog.shared.info("Added \(snapped.displayName)")
                } else {
                    WMSTileOverlay.cancelAllDownloads()
                    PMTileOverlay.cancelAllDownloads()
                    settings.activeCropMaps = [snapped]
                    settings.focusedLayerIndex = 0
                    ActivityLog.shared.info("Loaded \(snapped.displayName)")
                }
            }
        } label: {
            Label(label, systemImage: active ? "eye.fill" : "eye.slash")
                .foregroundStyle(active ? .green : .primary)
        }
    }
}
