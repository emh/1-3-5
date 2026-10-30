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
    @AppStorage("theme") private var theme: AppTheme = .system
    @State private var importing = false
    @State private var export: SharedExport?
    @State private var exportURL: URL?
    @State private var prompt: SettingsPrompt?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Theme").font(Theme.font(.body))
                    Picker("Theme", selection: $theme) {
                        ForEach(AppTheme.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("theme-picker")
                    Text("System follows your device’s appearance.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 20)
                Rule()
                snackSettings
                Rule()
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

    private var snackSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Snack rhythm").font(Theme.font(.headline))
            if let error = store.widgetUpdateError {
                Text(error).font(Theme.font(.caption)).foregroundStyle(Theme.destructive)
                Button("Retry widget update") { store.retrySave() }
            }
            Stepper("Daily target: \(store.data.snackSchedule.dailyTarget)", value: scheduleBinding(\.dailyTarget), in: 1...300)
            DatePicker("Start", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
            DatePicker("End", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
            Text("Your expected snacks build steadily from Start to End. The green dot tracks completed snacks; the outlined dot shows where you’d be on pace. A red arc shows the gap to catch up, and a brighter green arc shows your lead. In monochrome, the gap is dashed when behind and solid when ahead.")
                .font(Theme.font(.caption)).foregroundStyle(Theme.secondary)
            Text("Add Snack rhythm from your Home Screen’s widget gallery. Each dot inside the ring is one completed snack (one minute of exercise). Progress resets at midnight. For overnight hours, your daily pace includes the morning and evening portions of the window.")
                .font(Theme.font(.caption)).foregroundStyle(Theme.secondary)
        }
        .font(Theme.font(.body))
        .padding(.vertical, 20)
    }

    private func scheduleBinding(_ key: WritableKeyPath<SnackSchedule, Int>) -> Binding<Int> {
        Binding(get: { store.data.snackSchedule[keyPath: key] }, set: { value in
            var schedule = store.data.snackSchedule
            schedule[keyPath: key] = value
            store.setSnackSchedule(schedule)
        })
    }

    private func timeBinding(_ key: WritableKeyPath<SnackSchedule, Int>) -> Binding<Date> {
        Binding(get: {
            let minute = store.data.snackSchedule[keyPath: key]
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date())!
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            scheduleBinding(key).wrappedValue = parts.hour! * 60 + parts.minute!
        })
    }

    private func row(_ title: String, destructive: Bool = false) -> some View {
        HStack(spacing: 16) {
            Text(title).font(Theme.font(.body))
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondary)
        }
        .foregroundStyle(destructive ? Theme.destructive : Theme.foreground)
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
