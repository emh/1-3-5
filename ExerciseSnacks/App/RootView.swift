import SwiftUI

enum AppRoute: Hashable { case settings, library }

struct RootView: View {
    @AppStorage("theme") private var theme: AppTheme = .system
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmRecoveryReset = false

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoaded {
                    HistoryView()
                } else if let error = store.loadError {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("COULDN’T OPEN DATA").font(Theme.font(.headline))
                        Text(error).font(Theme.font(.subheadline)).foregroundStyle(Theme.secondary)
                        Button("Retry") { Task { await store.load() } }.buttonStyle(PrimaryButtonStyle())
                        Button("Reset All Data", role: .destructive) { confirmRecoveryReset = true }
                            .font(Theme.font(.body))
                    }.padding(28)
                } else {
                    ProgressView().tint(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .foregroundStyle(Theme.foreground)
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .settings: SettingsView()
                case .library: LibraryEditorView()
                }
            }
        }
        .fullScreenCover(item: Binding(get: { store.session }, set: { _ in })) { session in
            ActiveSnackView(session: session).environment(store)
        }
        .storageErrors(enabled: store.session == nil)
        .alert("Reset all data?", isPresented: $confirmRecoveryReset) {
            Button("Reset All Data", role: .destructive) {
                Task {
                    do { try await store.replaceData(with: .seed) }
                    catch { store.loadError = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete your history and restore the starter exercise library? This cannot be undone.")
        }
        .task { await store.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { store.backgrounded() }
            if phase == .active {
                store.refreshHistory()
                store.startOrReconcile()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in store.refreshHistory() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in store.refreshHistory() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in store.refreshHistory() }
        .preferredColorScheme(theme.colorScheme)
    }
}

private struct StorageErrorModifier: ViewModifier {
    @Environment(AppStore.self) private var store
    let enabled: Bool

    func body(content: Content) -> some View {
        content.alert("Couldn’t save data", isPresented: Binding(
            get: { enabled && store.storageIssue != nil },
            set: { if !$0 { store.storageIssue = nil } }
        )) {
            Button("Retry") { store.retrySave() }
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.storageIssue?.message ?? "")
        }
    }
}

extension View {
    func storageErrors(enabled: Bool = true) -> some View { modifier(StorageErrorModifier(enabled: enabled)) }

    func settingsPage(_ title: String) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.background)
            .foregroundStyle(Theme.foreground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text(title).font(Theme.font(.headline)) } }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

#if DEBUG
#Preview("History · Light") { RootView().environment(AppStore.preview()).preferredColorScheme(.light) }
#Preview("History · Dark") { RootView().environment(AppStore.preview()).preferredColorScheme(.dark) }
#Preview("Empty · Light") { RootView().environment(AppStore.preview(data: .seed)).preferredColorScheme(.light) }
#Preview("Empty · Dark") { RootView().environment(AppStore.preview(data: .seed)).preferredColorScheme(.dark) }
#endif
