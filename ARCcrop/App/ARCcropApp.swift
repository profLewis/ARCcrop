import SwiftUI

@main
struct ARCcropApp: App {
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
        }
    }
}
