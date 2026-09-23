import SwiftUI
import UniformTypeIdentifiers

private struct SharedExport: Identifiable {
    let id = UUID()
    let url: URL
}

private enum SettingsPrompt {
    case reset, replace(StoredData), error(String)

    var title: String {
        switch self {
        case .reset: "Reset all data?"
        case .replace: "Replace all data?"
        case .error: "Couldn’t complete action"
        }
    }

    var message: String {
        switch self {
        case .reset: return "Delete your history and restore the starter exercise library? This cannot be undone."
        case .replace(let data):
            let exerciseCount = LibraryParser.parse(data.libraryText).count
            return "Replace your library and history with \(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises") and \(data.snacks.count) \(data.snacks.count == 1 ? "snack" : "snacks")?"
        case .error(let message): return message
        }
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var importing = false
    @State private var export: SharedExport?
    @State private var exportURL: URL?
    @State private var prompt: SettingsPrompt?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                NavigationLink(value: AppRoute.library) { row("Exercise Library") }
                    .accessibilityIdentifier("exercise-library")
                Rule()
                Button { prepareExport() } label: { row("Export Data") }
                    .accessibilityIdentifier("export-data")
                Rule()
                Button { importing = true } label: { row("Import Data") }
                    .accessibilityIdentifier("import-data")
                Rule()
                Button { prompt = .reset } label: { row("Reset All Data", destructive: true) }
                    .accessibilityIdentifier("reset-data")
                    .padding(.top, 42)
                Rule()
                if busy { ProgressView().tint(Theme.accent).padding(.top, 24) }
            }
            .buttonStyle(.plain)
            .disabled(busy || store.isReplacing)
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .settingsPage("SETTINGS")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): prepareImport(url)
            case .failure(let error): prompt = .error(error.localizedDescription)
            }
        }
        .sheet(item: $export, onDismiss: cleanExport) { item in ShareSheet(url: item.url) }
        .alert(prompt?.title ?? "", isPresented: Binding(
            get: { prompt != nil }, set: { if !$0 { prompt = nil } }
        ), presenting: prompt) { value in
            switch value {
            case .reset:
                Button("Reset All Data", role: .destructive) { replace(with: .seed) }
                Button("Cancel", role: .cancel) {}
            case .replace(let data):
                Button("Replace", role: .destructive) { replace(with: data) }
                Button("Cancel", role: .cancel) {}
            case .error:
                Button("OK", role: .cancel) {}
            }
        } message: { Text($0.message) }
    }

    private func row(_ title: String, destructive: Bool = false) -> some View {
        HStack(spacing: 16) {
            Text(title).font(Theme.font(.body))
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
        }
        .foregroundStyle(destructive ? Color(red: 0.95, green: 0.57, blue: 0.55) : Theme.foreground)
        .frame(minHeight: 62)
        .contentShape(Rectangle())
    }

    private func prepareExport() {
        busy = true
        store.flushLibrary()
        Task {
            defer { busy = false }
            await store.waitForWrites()
            let data = store.data
            do {
                let url = try await Task.detached { try LocalDataStore.exportFile(for: data) }.value
                exportURL = url
                export = SharedExport(url: url)
            } catch { prompt = .error(error.localizedDescription) }
        }
    }

    private func cleanExport() {
        if let exportURL { try? FileManager.default.removeItem(at: exportURL.deletingLastPathComponent()) }
        exportURL = nil
    }

    private func prepareImport(_ url: URL) {
        busy = true
        Task {
            defer { busy = false }
            do {
                let data = try await Task.detached { try LocalDataStore.readImport(at: url) }.value
                prompt = .replace(data)
            } catch { prompt = .error(error.localizedDescription) }
        }
    }

    private func replace(with data: StoredData) {
        busy = true
        Task {
            defer { busy = false }
            do { try await store.replaceData(with: data) }
            catch { prompt = .error(error.localizedDescription) }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
