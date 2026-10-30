import SwiftUI
import WidgetKit

struct SnackEntry: TimelineEntry {
    let date: Date
    let snapshot: SnackWidgetSnapshot
    var isAvailable = true

    static func example(hour: Int = 13, count: Int) -> SnackEntry {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: hour))!
        return SnackEntry(date: date, snapshot: SnackWidgetSnapshot(
            completions: Array(repeating: date, count: count)
        ))
    }
}

struct SnackProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnackEntry {
        .example(count: 12)
    }
    func getSnapshot(in context: Context, completion: @escaping (SnackEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }
    private func entry(at date: Date) -> SnackEntry {
        let snapshot = SnackWidgetStorage.read()
        return SnackEntry(date: date, snapshot: snapshot ?? SnackWidgetSnapshot(), isAvailable: snapshot != nil)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnackEntry>) -> Void) {
        let now = Date()
        let current = entry(at: now)
        // Advance the pace marker even when no snacks are completed. Include exact day/window boundaries.
        var dates = Set((0...288).map { now.addingTimeInterval(Double($0 * 300)) })
        let calendar = Calendar.current
        for offset in 0...2 {
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
            dates.insert(day)
            for minute in [current.snapshot.schedule.startMinute, current.snapshot.schedule.endMinute] {
                dates.insert(calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)!)
            }
        }
        let entries = dates.filter { $0 >= now && $0 <= now.addingTimeInterval(86400) }.sorted().map {
            SnackEntry(date: $0, snapshot: current.snapshot, isAvailable: current.isAvailable)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct SnackWidgetView: View {
    let entry: SnackEntry
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Group {
            if entry.isAvailable {
                SnackPaceChart(state: entry.snapshot.state(at: entry.date), renderingMode: renderingMode)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk.circle").font(.largeTitle)
                    Text("Open Exercise Snacks to get started")
                        .font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.background, for: .widget)
    }
}

struct SnackPaceChart: View {
    let state: SnackWidgetState
    var renderingMode: WidgetRenderingMode = .fullColor
    private var monochrome: Bool { renderingMode != .fullColor }
    @Environment(\.colorScheme) private var colorScheme
    private var green: Color {
        if monochrome { return .white }
        return colorScheme == .dark ? Color(red: 0.36, green: 0.72, blue: 0.46) : Color(red: 0.17, green: 0.46, blue: 0.27)
    }
    private let lead = Color(red: 0.30, green: 0.75, blue: 0.46)
    private var red: Color {
        colorScheme == .dark ? Color(red: 0.98, green: 0.40, blue: 0.42) : Color(red: 0.80, green: 0.16, blue: 0.19)
    }
    private var behind: Bool { state.paceDifference < 0 }
    private var gapColor: Color { monochrome ? .white : behind ? red : lead }
    private var expected: String { number(state.expectedCount) }
    private var status: String {
        if state.count >= state.target { return "Goal met" }
        if state.paceDifference == 0 { return "On pace" }
        return "\(number(abs(state.paceDifference))) \(behind ? "behind" : "ahead")"
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let diameter = max(0, size - 26)
            let completedOffset = markerOffset(fraction: state.completedFraction, radius: diameter / 2)
            let expectedOffset = markerOffset(fraction: state.expectedFraction, radius: diameter / 2)
            ZStack {
                ZStack {
                    Circle().stroke(green.opacity(monochrome ? 0.18 : 0.13), lineWidth: 7)
                    Circle().trim(from: 0, to: state.completedFraction)
                        .stroke(green, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle().trim(from: min(state.completedFraction, state.expectedFraction),
                                  to: max(state.completedFraction, state.expectedFraction))
                        .stroke(gapColor.opacity(monochrome && behind ? 0.65 : 1),
                                style: StrokeStyle(lineWidth: 11, lineCap: monochrome && behind ? .butt : .round,
                                                   dash: monochrome && behind ? [3, 3] : []))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: diameter, height: diameter)
                .frame(width: size, height: size)
                // Real alpha cutouts survive Home Screen tinting. Background-colored fills don't.
                // Separate masks keep overlapping holes transparent when the markers meet.
                .mask {
                    MarkerCutout(offset: completedOffset, diameter: 20)
                        .fill(.white, style: FillStyle(eoFill: true))
                }
                .mask {
                    MarkerCutout(offset: expectedOffset, diameter: 26)
                        .fill(.white, style: FillStyle(eoFill: true))
                }
                // A hollow outline remains hollow in tinted/clear appearances.
                Circle().stroke(monochrome ? .white : Color.primary.opacity(0.65), lineWidth: 2.5)
                    .frame(width: 20, height: 20)
                    .offset(expectedOffset)
                // The larger solid head is isolated from the arc by a transparent halo.
                Circle().fill(green)
                    .frame(width: 14, height: 14)
                    .offset(completedOffset)
                CompletedSnackDots(count: state.count, target: state.target)
                    .fill(green)
                    .frame(width: max(0, diameter - 32), height: max(0, diameter - 32))
            }
            .frame(width: size, height: size)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.count) of \(state.target) snacks today. \(expected) expected by now. \(status).")
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func markerOffset(fraction: Double, radius: Double) -> CGSize {
        let angle = fraction * 2 * .pi - .pi / 2
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

/// Remove one circular region from the ring without introducing an opaque background color.
private struct MarkerCutout: Shape {
    let offset: CGSize
    let diameter: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.addRect(rect)
            path.addEllipse(in: CGRect(x: rect.midX + offset.width - diameter / 2,
                                       y: rect.midY + offset.height - diameter / 2,
                                       width: diameter, height: diameter))
        }
    }
}

/// A growing cluster with one dot per completed exercise, including snacks beyond the goal.
private struct CompletedSnackDots: Shape {
    let count: Int
    let target: Int

    func path(in rect: CGRect) -> Path {
        guard count > 0 else { return Path() }
        let radius = min(rect.width, rect.height) / 2
        // Size for the goal so dots stay in place as snacks accumulate; shrink only on overflow.
        let capacity = max(1, max(count, target))
        let spacing = min(12, radius / (sqrt(Double(capacity - 1)) + 0.45))
        let dotRadius = spacing * 0.43
        let goldenAngle = Double.pi * (3 - sqrt(5))
        return Path { path in
            for index in 0..<count {
                let distance = spacing * sqrt(Double(index))
                let angle = Double(index) * goldenAngle - .pi / 2
                let center = CGPoint(x: rect.midX + cos(angle) * distance,
                                     y: rect.midY + sin(angle) * distance)
                path.addEllipse(in: CGRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                           width: dotRadius * 2, height: dotRadius * 2))
            }
        }
    }
}

@main
struct SnackProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SnackWidgetStorage.kind, provider: SnackProvider()) { entry in
            SnackWidgetView(entry: entry)
        }
        .configurationDisplayName("Snack rhythm")
        .description("Chase your daily pace. See completed snacks, expected progress, and how far ahead or behind you are.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview("Daily pace", as: .systemSmall) {
    SnackProgressWidget()
} timeline: {
    SnackEntry.example(count: 1)
    SnackEntry.example(count: 12)
    SnackEntry.example(count: 18)
    SnackEntry.example(count: 15)
    SnackEntry.example(hour: 7, count: 0)
    SnackEntry.example(hour: 19, count: 24)
    SnackEntry.example(hour: 19, count: 38)
}
