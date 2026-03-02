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
            } label: {
                if settings.activeCropMaps.isEmpty {
                    Label("None", systemImage: "checkmark")
                } else {
                    Text("Clear All")
                }
            }

            // MARK: - Global
            Section("Global") {
                // GEOGLAM: tap to load/unload majority crop
                groupButton(
                    defaultSource: .geoglamMajorityCrop,
                    label: "GEOGLAM (~5.6km)",
                    icon: "globe",
                    isGroupActive: anyGEOGLAMActive
                )
                // GEOGLAM variants sub-menu
                if anyGEOGLAMActive {
                    Menu("  GEOGLAM Crop…") {
                        variantButton(.geoglamMajorityCrop, label: "Majority Crop")
                        ForEach(GEOGLAMCrop.allCases) { crop in
                            variantButton(.geoglam(crop), label: crop.rawValue)
                        }
                    }
                }
                // WorldCereal: tap to load/unload all temp crops
                groupButton(
                    defaultSource: .worldCereal,
                    label: "WorldCereal (10m)",
                    icon: "globe.europe.africa",
                    isGroupActive: anyWorldCerealActive
                )
                // WorldCereal variants sub-menu
                if anyWorldCerealActive {
                    Menu("  WorldCereal Crop…") {
                        variantButton(.worldCereal, label: "All Temp. Crops")
                        variantButton(.worldCerealMaize, label: "Maize")
                        variantButton(.worldCerealWinterCereals, label: "Winter Cereals")
                        variantButton(.worldCerealSpringCereals, label: "Spring Cereals")
                    }
                }
                sourceButton(.esaWorldCover(year: 2021), label: "ESA WorldCover (10m)", icon: "globe.europe.africa")
                sourceButton(.dynamicWorld, label: "Esri Land Cover (10m)", icon: "globe")
                sourceButton(.modisLandCover(year: 2023), label: "MODIS Land Cover (500m)", icon: "satellite.fill")
                sourceButton(.gfsadCropland, label: "GFSAD Croplands (1km)", icon: "globe")
                sourceButton(.copernicusLandCover, label: "Copernicus LC100 (100m)", icon: "satellite.fill")
                sourceButton(.fromGLC, label: "GLAD Land Cover (30m)", icon: "square.grid.3x3.fill")
            }

            // MARK: - North America
            Section("North America") {
                sourceButton(.usdaCDL(year: 2023), label: "\u{1F1FA}\u{1F1F8} USDA CDL", icon: "leaf.fill")
                sourceButton(.aafcCanada(year: 2024), label: "\u{1F1E8}\u{1F1E6} AAFC Canada", icon: "leaf.fill")
                sourceButton(.mexicoMadmex(year: 2018), label: "\u{1F1F2}\u{1F1FD} Mexico MAD-Mex", icon: "leaf.fill")
                sourceButton(.nalcms, label: "\u{1F30E} NALCMS (30m)", icon: "globe.americas")
            }

            // MARK: - South America
            Section("South America") {
                sourceButton(.mapBiomas(year: 2020), label: "\u{1F30E} MapBiomas", icon: "leaf.arrow.circlepath")
                sourceButton(.geoIntaArgentina, label: "\u{1F1E6}\u{1F1F7} GeoINTA Argentina", icon: "leaf.fill")
            }

            // MARK: - Africa & Middle East
            Section("Africa & Middle East") {
                sourceButton(.deAfricaCrop, label: "\u{1F30D} DE Africa Cropland", icon: "leaf.fill")
                sourceButton(.waporLCC, label: "\u{1F30D} WaPOR Land Cover", icon: "globe.europe.africa")
            }

            // MARK: - Asia
            Section("Asia") {
                sourceButton(.indiaBhuvan, label: "\u{1F1EE}\u{1F1F3} India Bhuvan LULC", icon: "leaf.fill")
                sourceButton(.indonesiaKlhk, label: "\u{1F1EE}\u{1F1E9} Indonesia KLHK", icon: "leaf.fill")
                sourceButton(.turkeyCorine, label: "\u{1F1F9}\u{1F1F7} Turkey CORINE", icon: "leaf.fill")
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
                sourceButton(.walloniaAgriculture(year: 2023), label: "\u{1F1E7}\u{1F1EA} Wallonia Agriculture", icon: "leaf.fill")
                sourceButton(.nibioNorway, label: "\u{1F1F3}\u{1F1F4} NIBIO Norway", icon: "leaf.fill")
            }

            // MARK: - Oceania
            Section("Oceania") {
                sourceButton(.abaresAustralia, label: "\u{1F1E6}\u{1F1FA} ABARES Australia", icon: "leaf.fill")
                sourceButton(.deaLandCover(year: 2020), label: "\u{1F1E6}\u{1F1FA} DEA Land Cover", icon: "leaf.fill")
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }

    /// Button for a group header: tap selects/deselects the default source for the group.
    private func groupButton(defaultSource: CropMapSource, label: String, icon: String, isGroupActive: Bool) -> some View {
        Button {
            if isGroupActive {
                // Remove all sources in this group (matching baseID)
                settings.activeCropMaps.removeAll { src in
                    switch (src, defaultSource) {
                    case (.geoglamMajorityCrop, .geoglamMajorityCrop), (.geoglam, .geoglamMajorityCrop): return true
                    case (.worldCereal, .worldCereal), (.worldCerealMaize, .worldCereal),
                         (.worldCerealWinterCereals, .worldCereal), (.worldCerealSpringCereals, .worldCereal): return true
                    default: return false
                    }
                }
            } else {
                let currentYear = settings.focusedCropMap.currentYear
                let snapped = currentYear > 0 ? defaultSource.withClosestYear(currentYear) : defaultSource
                settings.layerOpacity[snapped.id] = 1.0
                if settings.allowMultipleLayers {
                    settings.activeCropMaps.append(snapped)
                    settings.focusedLayerIndex = settings.activeCropMaps.count - 1
                } else {
                    settings.activeCropMaps = [snapped]
                    settings.focusedLayerIndex = 0
                }
                ActivityLog.shared.info("Loaded \(snapped.displayName)")
            }
        } label: {
            Label(label, systemImage: isGroupActive ? "eye.fill" : icon)
                .foregroundStyle(isGroupActive ? .green : .primary)
        }
    }

    /// Button for switching to a specific variant within a group (e.g. GEOGLAM → Winter Wheat)
    private func variantButton(_ source: CropMapSource, label: String) -> some View {
        let active = settings.activeCropMaps.contains { $0.id == source.id }
        let isGEOGLAM = source.id.hasPrefix("geoglam")
        return Button {
            // Replace the current group entry with this variant
            settings.activeCropMaps = settings.activeCropMaps.map { existing in
                if isGEOGLAM {
                    switch existing {
                    case .geoglamMajorityCrop, .geoglam: return source
                    default: return existing
                    }
                } else {
                    switch existing {
                    case .worldCereal, .worldCerealMaize, .worldCerealWinterCereals, .worldCerealSpringCereals: return source
                    default: return existing
                    }
                }
            }
            settings.hiddenClasses = []
            ActivityLog.shared.info("Switched to \(source.displayName)")
        } label: {
            if active {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }

    private func sourceButton(_ source: CropMapSource, label: String, icon: String) -> some View {
        let active = isActive(source)
        let needsKey = source.requiresAPIKey
        let hasKey = needsKey && source.isAvailable
        return Button {
            if needsKey && !hasKey {
                settings.pendingCropMapSource = source
                settings.apiKeySetupProvider = source.apiKeyProvider
                settings.selectedTab = .settings
                ActivityLog.shared.activity("\(source.sourceName) requires a \(source.apiKeyProvider?.rawValue ?? "API") key — opening settings…")
                return
            }
            if active {
                settings.activeCropMaps.removeAll { $0.baseID == source.baseID }
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
                    settings.activeCropMaps = [snapped]
                    settings.focusedLayerIndex = 0
                    ActivityLog.shared.info("Loaded \(snapped.displayName)")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Label(label, systemImage: active ? "eye.fill" : "eye.slash")
                    .foregroundStyle(active ? .green : .primary)
                if needsKey {
                    Image(systemName: "key.fill")
                        .font(.caption2)
                        .foregroundStyle(hasKey ? .green : .red)
                }
            }
        }
    }
}
