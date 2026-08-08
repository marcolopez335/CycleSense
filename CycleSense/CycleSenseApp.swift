import SwiftUI

@main
struct CycleSenseApp: App {
    @StateObject private var store = CycleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                // Cream is the identity — night variant is future work.
                .preferredColorScheme(.light)
                .tint(Theme.primary)
        }
    }
}
