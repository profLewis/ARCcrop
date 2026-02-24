import SwiftUI

struct CropDashboardView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Recent Observations") {
                    ContentUnavailableView(
                        "No Observations",
                        systemImage: "leaf",
                        description: Text("Select a region on the map to view crop conditions.")
                    )
                }

                Section("Data Sources") {
                    ForEach(EODataSource.allCases) { source in
                        HStack {
                            Image(systemName: source.iconName)
                                .foregroundStyle(source.color)
                            VStack(alignment: .leading) {
                                Text(source.displayName)
                                    .font(.headline)
                                Text(source.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            #if !os(tvOS)
            .toolbarTitleDisplayMode(.inline)
            #endif
        }
    }
}

#Preview {
    CropDashboardView()
}
