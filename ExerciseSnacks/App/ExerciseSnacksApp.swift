import SwiftUI

@main
struct ExerciseSnacksApp: App {
    @State private var store = AppStore.launchStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .defaultAppStorage(AppTheme.preferences)
                .tint(Theme.accent)
        }
    }
}
