import XCTest

final class CoreTests: XCTestCase {
    private func cal(firstWeekday: Int = 1) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        c.firstWeekday = firstWeekday
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ c: Calendar) -> Date {
        c.date(from: DateComponents(year: y, month: m, day: d, hour: 9))!
    }

    func testMonthGridSundayFirstStartsWithoutBlanks() {
        let c = cal()
        let cells = CalendarMath.monthGrid(for: date(2026, 11, 24, c), calendar: c)
        XCTAssertEqual(cells.first?.day, 1)
        XCTAssertEqual(cells.count, 35)
        XCTAssertEqual(cells.filter { $0.day != nil }.count, 30)
        XCTAssertEqual(cells.first(where: \.isToday)?.day, 24)
        XCTAssertEqual(cells.filter(\.isPast).count, 23)
    }

    func testMonthGridMondayFirstPadsSixBlanksAndFullRows() {
        let c = cal(firstWeekday: 2)
        let cells = CalendarMath.monthGrid(for: date(2026, 11, 24, c), calendar: c)
        XCTAssertEqual(cells.prefix(6).filter { $0.day == nil }.count, 6)
        XCTAssertEqual(cells[6].day, 1)
        XCTAssertEqual(cells.count % 7, 0)
        XCTAssertEqual(CalendarMath.weekdaySymbols(calendar: c).count, 7)
    }

    func testEventDaysMarkCells() {
        let c = cal()
        let today = date(2026, 2, 10, c)
        let marked = Set([c.startOfDay(for: date(2026, 2, 3, c)), c.startOfDay(for: date(2026, 2, 28, c))])
        let cells = CalendarMath.monthGrid(for: today, calendar: c, eventDays: marked)
        XCTAssertEqual(cells.filter(\.hasEvent).compactMap(\.day), [3, 28])
    }

    func testTwoWeeksStartsAtWeekStart() {
        let c = cal()
        let cells = CalendarMath.twoWeeks(for: date(2026, 11, 24, c), calendar: c)
        XCTAssertEqual(cells.count, 14)
        XCTAssertEqual(cells.first?.day, 22)
        XCTAssertEqual(cells.last?.day, 5)
        XCTAssertEqual(cells.firstIndex(where: \.isToday), 2)
    }

    func testYearProgressLeapYear() {
        let c = cal()
        let p = CalendarMath.yearProgress(for: date(2028, 12, 31, c), calendar: c)
        XCTAssertEqual(p.daysInYear, 366)
        XCTAssertEqual(p.dayOfYear, 366)
        XCTAssertEqual(p.daysLeft, 0)
        let q = CalendarMath.yearProgress(for: date(2026, 11, 24, c), calendar: c)
        XCTAssertEqual(q.dayOfYear, 328)
        XCTAssertEqual(q.percent, 89)
    }

    func testTodayListAllDayFirstAndOverflow() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        var events = (0..<8).map { WallEvent(title: "e\($0)", start: base.addingTimeInterval(Double(8 - $0) * 600), allDay: false) }
        events.append(WallEvent(title: "holiday", start: base, allDay: true))
        let (shown, more) = CalendarMath.todayList(events, limit: 6)
        XCTAssertEqual(shown.first?.title, "holiday")
        XCTAssertEqual(shown.count, 6)
        XCTAssertEqual(more, 3)
        XCTAssertEqual(shown[1].title, "e7")
    }

    func testStyleCodeRoundTripKeepsPrivateFields() throws {
        var mine = WallConfig(); mine.showEvents = true; mine.usePhoto = true
        var theirs = WallConfig(); theirs.style = .year; theirs.tint = .sand; theirs.position = .lower; theirs.textScale = 1.2; theirs.grayPast = false
        let code = StyleCode.encode(theirs)
        XCTAssertTrue(code.hasPrefix("CW1:"))
        let merged = try StyleCode.decode("Look at this!\n" + code + "\nthanks", into: mine)
        XCTAssertEqual(merged.style, .year); XCTAssertEqual(merged.tint, .sand)
        XCTAssertEqual(merged.position, .lower); XCTAssertEqual(merged.textScale, 1.2); XCTAssertFalse(merged.grayPast)
        XCTAssertTrue(merged.showEvents); XCTAssertTrue(merged.usePhoto)
    }

    func testStyleCodeRejectsBadInput() {
        XCTAssertThrowsError(try StyleCode.decode("", into: WallConfig())) { XCTAssertEqual($0 as? StyleCode.Failure, .empty) }
        XCTAssertThrowsError(try StyleCode.decode("hello", into: WallConfig())) { XCTAssertEqual($0 as? StyleCode.Failure, .prefix) }
        XCTAssertThrowsError(try StyleCode.decode("CW1:%%%", into: WallConfig())) { XCTAssertEqual($0 as? StyleCode.Failure, .corrupt) }
        XCTAssertThrowsError(try StyleCode.decode("CW1:" + String(repeating: "A", count: 500), into: WallConfig()))
        let weird = "CW1:" + Data(#"{"s":"month","r":"month","g":true,"p":"upper","t":"ink","x":9}"#.utf8).base64EncodedString()
        XCTAssertThrowsError(try StyleCode.decode(weird, into: WallConfig()))
    }

    func testFreeConfigDropsProFeatures() {
        var c = WallConfig(); c.style = .today; c.usePhoto = true; c.showEvents = true; c.tint = .slate
        XCTAssertTrue(c.needsPro)
        let free = c.limitedToFree()
        XCTAssertEqual(free.style, .month); XCTAssertFalse(free.usePhoto); XCTAssertFalse(free.showEvents)
        XCTAssertEqual(free.tint, .slate)
        XCTAssertFalse(free.needsPro)
    }

    func testStreakCountsUpToTodayOrYesterday() {
        let c = cal()
        let now = date(2026, 11, 24, c)
        let days = (0..<5).map { c.date(byAdding: .day, value: -$0 - 1, to: c.startOfDay(for: now))! }
        XCTAssertEqual(RunStats.streak(days, now: now, calendar: c), 5)
        XCTAssertEqual(RunStats.streak(days + [c.startOfDay(for: now)], now: now, calendar: c), 6)
        let gap = days.filter { $0 != days[2] }
        XCTAssertEqual(RunStats.streak(gap, now: now, calendar: c), 2)
        XCTAssertEqual(RunStats.streak([], now: now, calendar: c), 0)
    }

    func testTrialThirtyDaysThenExpires() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let e = Entitlement(firstOpen: start)
        XCTAssertTrue(e.hasPro(at: start.addingTimeInterval(29 * 86_400), free: false))
        XCTAssertFalse(e.hasPro(at: start.addingTimeInterval(31 * 86_400), free: false))
    }

    func testLayoutNeverOverlapsClockOrBottomButtons() {
        let sizes = [CGSize(width: 375, height: 667), CGSize(width: 390, height: 844),
                     CGSize(width: 393, height: 852), CGSize(width: 440, height: 956)]
        for size in sizes {
            let clock = WallLayout.clockZone(size)
            for position in WallPosition.allCases {
                let top = WallLayout.contentTop(size, position)
                XCTAssertGreaterThan(top, clock.maxY, "\(size) \(position)")
                XCTAssertLessThan(top, WallLayout.contentBottom(size) - size.height * 0.25, "\(size) \(position) 内容区太小")
            }
            XCTAssertLessThanOrEqual(WallLayout.contentBottom(size), size.height * 0.85)
        }
    }
}
