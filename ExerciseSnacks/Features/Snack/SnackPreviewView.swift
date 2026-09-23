import SwiftUI

struct SnackPreviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var exercises: [String]
    @State private var highlightedIndex: Int?
    @State private var highlightToken = UUID()
    @State private var isStarting = false

    init(draft: SnackDraft) { _exercises = State(initialValue: draft.exercises) }

    private var canReroll: Bool { !SnackGenerator.candidates(library: store.exercises, current: exercises).isEmpty }
    private var sheetHeight: CGFloat { exercises.count == 5 ? 680 : exercises.count == 3 ? 540 : 360 }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                Text("YOUR SNACK").font(Theme.font(.title3, weight: .medium)).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 22)).frame(width: 44, height: 44) }
                    .buttonStyle(.plain).accessibilityLabel("Close preview").accessibilityIdentifier("close-preview")
            }
            Text("\(exercises.count) \(exercises.count == 1 ? "exercise" : "exercises") · 1 min each")
                .font(Theme.font(.caption)).foregroundStyle(Theme.secondary)
                .padding(.top, -12)

            ScrollView {
                VStack(spacing: 0) {
                    Rule()
                    ForEach(exercises.indices, id: \.self) { index in
                        exerciseRow(at: index)
                        .font(Theme.font(.body))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 4)
                        .background(highlightedIndex == index ? Theme.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        Rule()
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("Go") {
                guard !isStarting else { return }
                isStarting = true
                store.queuedExercises = exercises
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(isStarting)
            .accessibilityIdentifier("start-snack")
        }
        .padding(.horizontal, 26)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .foregroundStyle(Theme.foreground)
        .presentationBackground(Theme.surface)
        .presentationCornerRadius(26)
        .presentationDragIndicator(.hidden)
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(sheetHeight), .large])
        .task(id: highlightToken) {
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { highlightedIndex = nil }
        }
    }

    @ViewBuilder
    private func exerciseRow(at index: Int) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(index + 1)").font(Theme.font(.caption)).foregroundStyle(Theme.secondary)
                    Spacer()
                    rerollButton(at: index)
                }
                Text(exercises[index]).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(spacing: 14) {
                Text("\(index + 1)").foregroundStyle(Theme.secondary).frame(width: 24, alignment: .leading)
                Text(exercises[index]).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                rerollButton(at: index)
            }
        }
    }

    private func rerollButton(at index: Int) -> some View {
        Button {
            var random = SystemRandomNumberGenerator()
            if let next = SnackGenerator.reroll(at: index, current: exercises, library: store.exercises, preferences: store.data.exercisePreferences, using: &random) {
                exercises = next
                highlightedIndex = index
                highlightToken = UUID()
            }
        } label: {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 22)).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).disabled(!canReroll)
        .opacity(canReroll ? 1 : 0.3)
        .accessibilityLabel("Reroll \(exercises[index])")
        .accessibilityHint(canReroll ? "Replace only this exercise" : "No other exercises available")
        .accessibilityIdentifier("reroll-\(index)")
    }
}
