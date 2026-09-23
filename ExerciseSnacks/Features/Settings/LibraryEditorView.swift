import SwiftUI

struct LibraryEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ExerciseTextEditor(store: store)
            .settingsPage("EXERCISE LIBRARY")
            .onDisappear { store.flushLibrary() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { store.flushLibrary() } }
    }
}
