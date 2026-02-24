import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            #if !os(tvOS)
            Tab("Map", systemImage: "map") {
                MapView()
            }
            #endif

            Tab("Dashboard", systemImage: "chart.bar") {
                CropDashboardView()
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppSettings.shared)
}
