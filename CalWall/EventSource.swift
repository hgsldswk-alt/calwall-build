import EventKit
import Foundation

enum EventSource {
    static let store = EKEventStore()

    static var authorized: Bool {
        if Launch.testFlag("-fake-events") { return true }
        return EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static var denied: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        return s == .denied || s == .restricted || Launch.testFlag("-events-denied")
    }

    static func requestAccess() async -> Bool {
        if Launch.testFlag("-fake-events") { return true }
        if Launch.testFlag("-events-denied") { return false }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    static func load(for today: Date, calendar: Calendar = .current) -> (today: [WallEvent], days: Set<Date>) {
        if Launch.testFlag("-fake-events") { return fake(today, calendar: calendar) }
        guard authorized else { return ([], []) }
        let dayStart = calendar.startOfDay(for: today)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let month = calendar.dateInterval(of: .month, for: today),
              let from = calendar.date(byAdding: .day, value: -7, to: month.start),
              let to = calendar.date(byAdding: .day, value: 14, to: month.end) else { return ([], []) }
        let events = store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: nil))
        var days = Set<Date>()
        for e in events {
            var d = calendar.startOfDay(for: e.startDate)
            let last = calendar.startOfDay(for: max(e.startDate, e.endDate.addingTimeInterval(-1)))
            while d <= last {
                days.insert(d)
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
        }
        let todays = events.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
            .map { WallEvent(title: $0.title ?? "", start: max($0.startDate, dayStart), allDay: $0.isAllDay) }
        return (todays, days)
    }

    private static func fake(_ today: Date, calendar: Calendar) -> ([WallEvent], Set<Date>) {
        let base = calendar.startOfDay(for: today)
        func at(_ h: Int, _ m: Int) -> Date { calendar.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base }
        let events = [WallEvent(title: L.t("demo.dentist"), start: at(10, 0), allDay: false),
                      WallEvent(title: L.t("demo.call"), start: at(15, 30), allDay: false),
                      WallEvent(title: L.t("demo.yoga"), start: at(19, 0), allDay: false)]
        let offsets = [-21, -18, -14, -9, -5, 0, 2, 5]
        let days = Set(offsets.compactMap { calendar.date(byAdding: .day, value: $0, to: base) })
        return (events, days)
    }
}
