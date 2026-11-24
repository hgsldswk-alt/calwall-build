import SwiftUI
import UIKit

struct WallInput {
    var config: WallConfig
    var today: Date
    var events: [WallEvent]
    var eventDays: Set<Date>
    var photo: UIImage?
}

struct WallPalette {
    var background: Color
    var ink: Color
    var muted: Color
    var past: Color
    static let today = Color(red: 0.878, green: 0.478, blue: 0.373)

    static func of(_ tint: WallTint) -> WallPalette {
        switch tint {
        case .ink: return .init(background: Color(red: 0.078, green: 0.094, blue: 0.086), ink: Color(red: 0.953, green: 0.937, blue: 0.902),
                                muted: Color(red: 0.49, green: 0.525, blue: 0.51), past: Color(red: 0.333, green: 0.376, blue: 0.357))
        case .forest: return .init(background: Color(red: 0.122, green: 0.373, blue: 0.357), ink: Color(red: 0.965, green: 0.957, blue: 0.937),
                                   muted: Color(red: 0.70, green: 0.79, blue: 0.77), past: Color(red: 0.42, green: 0.56, blue: 0.54))
        case .sand: return .init(background: Color(red: 0.925, green: 0.894, blue: 0.835), ink: Color(red: 0.118, green: 0.141, blue: 0.133),
                                 muted: Color(red: 0.42, green: 0.44, blue: 0.42), past: Color(red: 0.66, green: 0.64, blue: 0.60))
        case .slate: return .init(background: Color(red: 0.204, green: 0.243, blue: 0.290), ink: Color(red: 0.945, green: 0.949, blue: 0.957),
                                  muted: Color(red: 0.62, green: 0.67, blue: 0.72), past: Color(red: 0.42, green: 0.47, blue: 0.53))
        }
    }
}

struct WallpaperView: View {
    let input: WallInput
    let size: CGSize
    var calendar: Calendar = .current

    private var palette: WallPalette {
        var p = WallPalette.of(input.config.tint)
        if input.config.usePhoto && input.photo != nil {
            p.ink = .white; p.muted = Color.white.opacity(0.78); p.past = Color.white.opacity(0.45)
        }
        return p
    }
    private var unit: CGFloat { size.width / 393 * input.config.textScale }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            content
                .frame(width: size.width * 0.82, alignment: .leading)
                .padding(.leading, size.width * 0.09)
                .padding(.top, WallLayout.contentTop(size, input.config.position))
                .frame(maxHeight: WallLayout.contentBottom(size), alignment: .top)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder private var background: some View {
        if input.config.usePhoto, let photo = input.photo {
            Image(uiImage: photo).resizable().scaledToFill()
                .frame(width: size.width, height: size.height).clipped()
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom))
        } else {
            palette.background
        }
    }

    @ViewBuilder private var content: some View {
        switch input.config.style {
        case .month: monthBlock
        case .year: yearBlock
        case .today: todayBlock
        }
    }

    private func title(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 12 * unit, weight: .bold)).tracking(1.2 * unit)
            .foregroundStyle(palette.muted)
    }

    private var monthBlock: some View {
        let cells = input.config.range == .month
            ? CalendarMath.monthGrid(for: input.today, calendar: calendar, eventDays: input.eventDays)
            : CalendarMath.twoWeeks(for: input.today, calendar: calendar, eventDays: input.eventDays)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4 * unit), count: 7)
        return VStack(alignment: .leading, spacing: 8 * unit) {
            title(input.today.formatted(.dateTime.month(.wide).year()))
            LazyVGrid(columns: columns, spacing: 5 * unit) {
                ForEach(Array(CalendarMath.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, s in
                    Text(s).font(.system(size: 10 * unit, weight: .semibold)).foregroundStyle(palette.muted)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in dayCell(cell) }
            }
            if input.config.showEvents { eventLines(limit: 3) }
        }
    }

    private func dayCell(_ cell: DayCell) -> some View {
        ZStack {
            if cell.isToday { Circle().fill(WallPalette.today) }
            if let d = cell.day {
                Text("\(d)").font(.system(size: 13 * unit, weight: cell.isToday ? .bold : .regular))
                    .foregroundStyle(cell.isToday ? .white : (cell.isPast && input.config.grayPast ? palette.past : palette.ink))
            }
            if cell.hasEvent && input.config.showEvents && !cell.isToday {
                Circle().fill(cell.isPast && input.config.grayPast ? palette.past : palette.ink)
                    .frame(width: 3.5 * unit, height: 3.5 * unit).offset(y: 10 * unit)
            }
        }
        .frame(height: 26 * unit)
    }

    private var yearBlock: some View {
        let progress = CalendarMath.yearProgress(for: input.today, calendar: calendar)
        let perRow = 19
        let rows = Int(ceil(Double(progress.daysInYear) / Double(perRow)))
        let dot = 7 * unit, gap = 3.4 * unit
        return VStack(alignment: .leading, spacing: 9 * unit) {
            title("\(calendar.component(.year, from: input.today)) · " + L.f("wall.day", progress.dayOfYear))
            VStack(alignment: .leading, spacing: gap) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: gap) {
                        ForEach(0..<perRow, id: \.self) { c in
                            let day = r * perRow + c + 1
                            if day <= progress.daysInYear {
                                Circle().fill(day == progress.dayOfYear ? WallPalette.today
                                              : day < progress.dayOfYear ? palette.ink : palette.past)
                                    .frame(width: dot, height: dot)
                            }
                        }
                    }
                }
            }
            Text(L.f("wall.yearLeft", progress.percent, progress.daysLeft))
                .font(.system(size: 12 * unit)).foregroundStyle(palette.muted)
            if input.config.showEvents { eventLines(limit: 2) }
        }
    }

    private var todayBlock: some View {
        VStack(alignment: .leading, spacing: 10 * unit) {
            title(input.config.showEvents ? L.f("wall.todayCount", input.events.count) : L.t("wall.today"))
            if input.config.showEvents {
                eventLines(limit: 6, big: true)
            } else {
                Text(input.today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 22 * unit, weight: .semibold)).foregroundStyle(palette.ink)
            }
        }
    }

    @ViewBuilder private func eventLines(limit: Int, big: Bool = false) -> some View {
        let (shown, more) = CalendarMath.todayList(input.events, limit: limit)
        VStack(alignment: .leading, spacing: (big ? 9 : 6) * unit) {
            if shown.isEmpty {
                Text(L.t("wall.noEvents")).font(.system(size: (big ? 15 : 12) * unit)).foregroundStyle(palette.muted)
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, e in
                HStack(alignment: .firstTextBaseline, spacing: 10 * unit) {
                    Text(e.allDay ? L.t("wall.allDay") : e.start.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: (big ? 14 : 11.5) * unit, weight: .semibold).monospacedDigit())
                        .foregroundStyle(WallPalette.today)
                        .frame(width: 58 * unit, alignment: .leading)
                    Text(e.title).font(.system(size: (big ? 16 : 12.5) * unit)).foregroundStyle(palette.ink).lineLimit(1)
                }
            }
            if more > 0 {
                Text(L.f("wall.more", more)).font(.system(size: 11 * unit)).foregroundStyle(palette.muted)
            }
        }
    }
}

enum WallRenderer {
    @MainActor
    static func render(_ input: WallInput, points: CGSize, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: WallpaperView(input: input, size: points))
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
