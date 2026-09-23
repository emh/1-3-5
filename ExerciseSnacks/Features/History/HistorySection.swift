import Foundation

struct HistorySection: Identifiable {
    let date: Date
    let title: String
    var snacks: [Snack]
    var id: Date { date }
}

enum HistoryGrouping {
    static func sections(for snacks: [Snack], now: Date = Date(), calendar: Calendar = .current) -> [HistorySection] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        var sections: [HistorySection] = []
        for snack in snacks.sorted(by: { $0.completedAt > $1.completedAt }) {
            let day = calendar.startOfDay(for: snack.completedAt)
            if sections.last?.date == day {
                sections[sections.count - 1].snacks.append(snack)
            } else {
                let title = day == today ? "TODAY" : day == yesterday ? "YESTERDAY" : formatter.string(from: day).uppercased()
                sections.append(HistorySection(date: day, title: title, snacks: [snack]))
            }
        }
        return sections
    }
}

