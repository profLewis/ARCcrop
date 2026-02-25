import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var settings

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
    }
}

#Preview {
    ContentView()
        .environment(AppSettings.shared)
}
