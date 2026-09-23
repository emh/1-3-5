import SwiftUI

struct ActiveSnackView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Bindable var session: SnackSession
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 76.0

    private var paused: Bool { session.engine.phase == .paused }
    private var ending: Bool { session.engine.phase == .finishing || session.engine.phase == .cancelled }

    var body: some View {
        let revision = session.engine.revision
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Button { store.beginCancellation() } label: {
                            Image(systemName: "xmark").font(.title3).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain).disabled(ending)
                        .accessibilityLabel("Cancel snack").accessibilityIdentifier("cancel-snack")
                        Spacer()
                        Text("\(session.engine.index + 1) / \(session.engine.exercises.count)")
                            .font(Theme.font(.body))
                            .accessibilityLabel("Exercise \(session.engine.index + 1) of \(session.engine.exercises.count)")
                            .accessibilityIdentifier("exercise-position")
                    }
                    Spacer(minLength: 52)
                    Text(session.engine.exercise.uppercased())
                        .font(Theme.font(.title2, weight: .medium))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("active-exercise")
                    Spacer(minLength: 52)
                    Group {
                        if ending {
                            VStack(spacing: 20) {
                                Text(session.engine.phase == .cancelled ? "ENDING…" : "SAVING…")
                                    .font(Theme.font(.title2)).foregroundStyle(Theme.secondary)
                                if store.isSaving { ProgressView().tint(Theme.accent) }
                                else { Button("Retry") { store.retrySave() }.font(Theme.font(.body)) }
                            }
                        } else {
                            Text(paused ? "PAUSED" : session.timerText)
                                .font(.system(size: min(timerSize, 140), weight: .semibold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(paused ? Theme.secondary : Theme.accent)
                                .lineLimit(1).minimumScaleFactor(0.45)
                                .accessibilityLabel(paused ? "Paused" : "\(session.secondsRemaining) seconds remaining")
                                .accessibilityIdentifier("countdown")
                        }
                    }.frame(maxWidth: .infinity, minHeight: 96)
                    Spacer(minLength: 80)
                    HStack(spacing: typeSize.isAccessibilitySize ? 16 : 56) {
                        timerControl(paused ? "Resume" : "Pause", symbol: paused ? "play.fill" : "pause.fill", id: "pause-resume") {
                            store.togglePause(expectedRevision: revision)
                        }
                        timerControl("Skip", symbol: "forward.end.fill", id: "skip") { store.skip(expectedRevision: revision) }
                    }
                    .disabled(ending)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 28)
                .padding(.top, 10)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("active-scroll")
        }
        .background(Theme.background)
        .foregroundStyle(Theme.foreground)
        .interactiveDismissDisabled()
        .alert("End snack?", isPresented: $session.isConfirmingCancellation) {
            Button("End Snack", role: .destructive) { store.cancelSession() }
            Button("Keep Going", role: .cancel) { store.keepSession() }
        } message: { Text("This snack won’t be added to your log.") }
        .storageErrors()
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            store.startOrReconcile()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                store.tick()
            }
        }
        .onChange(of: session.engine.phase, initial: true) { _, _ in updateIdleSleep() }
        .onChange(of: scenePhase) { _, _ in updateIdleSleep() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sensoryFeedback(.impact(weight: .light), trigger: session.engine.index) { _, _ in scenePhase == .active }
    }

    private func updateIdleSleep() {
        UIApplication.shared.isIdleTimerDisabled = scenePhase == .active && session.engine.phase == .running
    }

    private func timerControl(_ title: String, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.title3)
                    .frame(width: 58, height: 58).background(Theme.control, in: Circle())
                Text(title).font(Theme.font(.caption))
            }.frame(minWidth: 88)
        }
        .buttonStyle(.plain).accessibilityLabel(title).accessibilityIdentifier(id)
    }
}
