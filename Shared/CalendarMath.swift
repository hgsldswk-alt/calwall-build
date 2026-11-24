import Foundation

struct WallEvent: Equatable, Codable {
    var title: String
    var start: Date
    var allDay: Bool
}

struct DayCell: Equatable {
    var day: Int?
    var date: Date?
    var isToday = false
    var isPast = false
    var hasEvent = false
}

enum CalendarMath {
    static func monthGrid(for today: Date, calendar: Calendar = .current, eventDays: Set<Date> = []) -> [DayCell] {
        let startOfToday = calendar.startOfDay(for: today)
        guard let interval = calendar.dateInterval(of: .month, for: today),
              let days = calendar.range(of: .day, in: .month, for: today) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let lead = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells = Array(repeating: DayCell(), count: lead)
        for d in days {
            guard let date = calendar.date(byAdding: .day, value: d - 1, to: interval.start) else { continue }
            let day = calendar.startOfDay(for: date)
            cells.append(DayCell(day: d, date: day, isToday: day == startOfToday,
                                 isPast: day < startOfToday, hasEvent: eventDays.contains(day)))
        }
        while cells.count % 7 != 0 { cells.append(DayCell()) }
        return cells
    }

    static func twoWeeks(for today: Date, calendar: Calendar = .current, eventDays: Set<Date> = []) -> [DayCell] {
        let startOfToday = calendar.startOfDay(for: today)
        guard let week = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        return (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let day = calendar.startOfDay(for: date)
            return DayCell(day: calendar.component(.day, from: day), date: day, isToday: day == startOfToday,
                           isPast: day < startOfToday, hasEvent: eventDays.contains(day))
        }
    }

    static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    struct YearProgress: Equatable {
        var dayOfYear: Int
        var daysInYear: Int
        var daysLeft: Int { daysInYear - dayOfYear }
        var percent: Int { Int((Double(dayOfYear) / Double(daysInYear) * 100).rounded(.down)) }
    }

    static func yearProgress(for today: Date, calendar: Calendar = .current) -> YearProgress {
        let day = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        let total = calendar.range(of: .day, in: .year, for: today)?.count ?? 365
        return YearProgress(dayOfYear: day, daysInYear: total)
    }

    static func todayList(_ events: [WallEvent], limit: Int = 6) -> ([WallEvent], Int) {
        let sorted = events.sorted { a, b in
            if a.allDay != b.allDay { return a.allDay }
            return a.start < b.start
        }
        return (Array(sorted.prefix(limit)), max(0, sorted.count - limit))
    }
}

enum RunStats {
    static func streak(_ days: [Date], now: Date, calendar: Calendar = .current) -> Int {
        let set = Set(days.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: now)
        if !set.contains(cursor), let y = calendar.date(byAdding: .day, value: -1, to: cursor) { cursor = y }
        var count = 0
        while set.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    static let milestones = [7, 30, 100]
}
