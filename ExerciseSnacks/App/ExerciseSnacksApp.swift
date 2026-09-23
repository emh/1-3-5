import SwiftUI

@main
struct ExerciseSnacksApp: App {
    @State private var store = AppStore.launchStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
