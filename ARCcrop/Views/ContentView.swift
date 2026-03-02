import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var network = NetworkMonitor.shared
    @State private var didStartupCheck = false

    var body: some View {
        @Bindable var settings = settings
        TabView(selection: $settings.selectedTab) {
            #if !os(tvOS)
            Tab("Map", systemImage: "map", value: AppTab.map) {
                MapView()
            }
            #endif

            Tab("Dashboard", systemImage: "chart.bar", value: AppTab.dashboard) {
                CropDashboardView()
            }

            Tab("Settings", systemImage: "gear", value: AppTab.settings) {
                SettingsView()
            }
        }
        .task {
            // Wait briefly for NWPathMonitor to report initial status
            try? await Task.sleep(for: .milliseconds(200))
            settings.deferLayersIfNeeded(isWiFi: network.isWiFi)
            didStartupCheck = true
        }
        .onChange(of: network.isWiFi) {
            guard didStartupCheck else { return }
            if network.isWiFi, settings.deferredCropMaps != nil {
                settings.restoreDeferredLayers()
            }
        }
        .onChange(of: settings.allowCellularLoading) {
            if settings.allowCellularLoading, settings.deferredCropMaps != nil {
                settings.restoreDeferredLayers()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings.shared)
}
