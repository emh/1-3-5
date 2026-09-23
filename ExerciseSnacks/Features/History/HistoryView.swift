import SwiftUI

struct SnackDraft: Identifiable {
    let id = UUID()
    let exercises: [String]
}

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: SnackDraft?
    @State private var lastSize = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image("BrandIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text("exercise snacks")
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("1, 3, 5. Exercise snacks")
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                NavigationLink(value: AppRoute.settings) {
                    Image(systemName: "gearshape").font(.system(size: 22)).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 20)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("history-top")
                        if store.historySections.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("NO SNACKS YET").font(Theme.font(.caption)).tracking(1)
                                    .foregroundStyle(Theme.secondary)
                                if store.exercises.isEmpty {
                                    NavigationLink(store.data.libraryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Add exercises" : "Manage exercises", value: AppRoute.library)
                                        .font(Theme.font(.body))
                                }
                            }.padding(.horizontal, 24).padding(.top, 4)
                        }
                        ForEach(store.historySections) { section in
                            Section {
                                ForEach(section.snacks) { snack in
                                    SnackRow(snack: snack)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(store.recentSnackID == snack.id ? Theme.accent.opacity(0.12) : .clear)
                                        .id(snack.id)
                                }
                            } header: {
                                VStack(alignment: .leading, spacing: 14) {
                                    if section.id != store.historySections.first?.id { Rule().padding(.top, 12) }
                                    Text(section.title).font(Theme.font(.caption)).tracking(1.1)
                                        .foregroundStyle(Theme.secondary)
                                        .accessibilityAddTraits(.isHeader)
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .accessibilityIdentifier("history")
                .task(id: store.recentSnackID) {
                    guard let recentID = store.recentSnackID else { return }
                    await Task.yield()
                    proxy.scrollTo("history-top", anchor: .top)
                    do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
                    if store.recentSnackID == recentID {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { store.recentSnackID = nil }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 14) {
                Rule()
                HStack(spacing: 34) {
                    ForEach(SnackGenerator.sizes, id: \.self) { size in
                        Button("\(size)") {
                            var random = SystemRandomNumberGenerator()
                            if let exercises = SnackGenerator.generate(count: size, library: store.exercises, preferences: store.data.exercisePreferences, using: &random) {
                                lastSize = size
                                draft = SnackDraft(exercises: exercises)
                            }
                        }
                        .buttonStyle(RoundButtonStyle(emphasized: lastSize == size))
                        .disabled(store.exercises.count < size)
                        .accessibilityLabel("\(size) minute snack")
                        .accessibilityHint(store.exercises.count < size ? "Add or unmute more exercises in your library" : "Preview \(size) exercises")
                        .accessibilityIdentifier("snack-size-\(size)")
                    }
                }.padding(.bottom, 12)
            }.background(Theme.background)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.foreground)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $draft, onDismiss: store.startQueuedSession) { draft in
            SnackPreviewView(draft: draft).environment(store)
        }
    }
}

private struct SnackRow: View {
    let snack: Snack
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var timeWidth = 64.0
    @ScaledMetric(relativeTo: .caption) private var durationWidth = 36.0

    private var time: String {
        snack.completedAt.formatted(Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "en_GB")))
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) { Text(time); Text(snack.durationLabel) }.foregroundStyle(Theme.secondary)
                    names
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Text(time).frame(width: timeWidth, alignment: .leading)
                    Text(snack.durationLabel).frame(width: durationWidth, alignment: .leading)
                    names.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .font(Theme.font(.subheadline))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(time), \(snack.exercises.count) minute snack, \(snack.exercises.joined(separator: ", "))")
        .accessibilityIdentifier("snack-record")
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(snack.exercises.enumerated()), id: \.offset) { _, name in Text(name).fixedSize(horizontal: false, vertical: true) }
        }
    }
}
