import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            Form {
                Section("Data Sources") {
                    ForEach(EODataSource.allCases) { source in
                        Toggle(source.displayName, isOn: Binding(
                            get: { settings.enabledSources[source] ?? false },
                            set: { settings.enabledSources[source] = $0 }
                        ))
                    }
                }

                Section("Display") {
                    @Bindable var settings = settings
                    Picker("Vegetation Index", selection: $settings.vegetationIndex) {
                        ForEach(VegetationIndex.allCases) { index in
                            Text(index.rawValue).tag(index)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
            #if !os(tvOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppSettings.shared)
}
