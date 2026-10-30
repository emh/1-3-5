import SwiftUI

struct ActiveSnackView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityDimFlashingLights) private var dimFlashingLights
    @Bindable var session: SnackSession
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 76.0
    @State private var sounds = TimerSoundPlayer()
    @State private var flashSequence = 0
    @State private var flashing = false

    private var paused: Bool { session.engine.phase.isPaused }
    private var gettingReady: Bool { session.engine.phase.isCountingDown || session.engine.phase == .ready }
    private var ending: Bool { session.engine.phase == .finishing || session.engine.phase == .cancelled }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Equal space above and below keeps the timer itself centered.
                    upperSection.frame(minHeight: max(0, (geometry.size.height - 96) / 2))
                    timer.frame(maxWidth: .infinity, minHeight: 96)
                    lowerSection.frame(minHeight: max(0, (geometry.size.height - 96) / 2))
                }
                .padding(.horizontal, 28)
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .accessibilityIdentifier("active-scroll")
        }
        .background(Theme.background)
        .foregroundStyle(Theme.foreground)
        .overlay {
            Theme.accent.opacity(flashing ? 0.28 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .interactiveDismissDisabled()
        .alert("End snack?", isPresented: $session.isConfirmingCancellation) {
            Button("End Snack", role: .destructive) { store.cancelSession() }
            Button("Keep Going", role: .cancel) { store.keepSession() }
        } message: { Text("This snack won’t be added to your log.") }
        .storageErrors()
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            sounds.prepare()
            store.startOrReconcile()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                store.tick()
            }
        }
        .onChange(of: session.feedbackState) { previous, current in
            guard scenePhase == .active, let cue = current.cue(after: previous) else { return }
            sounds.play(cue)
            if cue == .countdown, !dimFlashingLights { flashSequence += 1 }
        }
        .task(id: flashSequence) {
            guard flashSequence > 0 else { return }
            flashing = true
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            withAnimation(.easeOut(duration: 0.18)) { flashing = false }
        }
        .onChange(of: session.engine.phase, initial: true) { _, _ in updateActivity() }
        .onChange(of: scenePhase) { _, _ in updateActivity() }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            sounds.stop()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: session.engine.index) { _, _ in scenePhase == .active }
    }

    private var upperSection: some View {
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
            .padding(.top, 10)
            Spacer(minLength: 40)
            Text(gettingReady ? "GET READY" : session.engine.exercise.uppercased())
                .font(Theme.font(.title2, weight: .medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("active-exercise")
                .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var timer: some View {
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
    }

    private var lowerSection: some View {
        let revision = session.engine.revision
        return VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(session.engine.nextExercise == nil ? "LAST EXERCISE" : "UP NEXT")
                    .font(Theme.font(.caption)).tracking(1)
                if let next = session.engine.nextExercise {
                    Text(next)
                        .font(Theme.font(.body))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("next-exercise")
                }
            }
            .foregroundStyle(Theme.secondary)
            .padding(.top, 24)
            .opacity(ending ? 0 : 1)
            Spacer(minLength: 40)
            HStack(spacing: typeSize.isAccessibilitySize ? 16 : 56) {
                timerControl(paused ? "Resume" : "Pause", symbol: paused ? "play.fill" : "pause.fill", id: "pause-resume") {
                    store.togglePause(expectedRevision: revision)
                }
                timerControl(gettingReady ? "Start now" : "Skip", symbol: "forward.end.fill", id: "skip") {
                    store.skip(expectedRevision: revision)
                }
            }
            .disabled(ending)
            .padding(.bottom, 32)
        }
    }

    private func updateActivity() {
        let ticking = scenePhase == .active && session.engine.phase.isTicking
        UIApplication.shared.isIdleTimerDisabled = ticking
        if !ticking {
            flashing = false
            sounds.stop()
        }
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
