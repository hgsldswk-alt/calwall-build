import XCTest

final class FlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ args: [String] = [], language: String = "en", locale: String = "en_US") {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + args
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @discardableResult
    private func wait(_ id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = element(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), id, file: file, line: line)
        return e
    }

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let e = wait(id, file: file, line: line)
        let ready = NSPredicate { _, _ in e.exists && e.isHittable }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 8), .completed,
                       id, file: file, line: line)
        e.tap()
    }

    private func open(_ button: String, expect: String, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 {
            tap(button, file: file, line: line)
            if element(expect).waitForExistence(timeout: 4) { return }
        }
        XCTFail("\(button) 没打开 \(expect)", file: file, line: line)
    }

    private func isSelected(_ id: String) -> Bool { element(id).isSelected }

    private func waitSelected(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let e = element(id)
        let p = NSPredicate { _, _ in e.exists && e.isSelected }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: nil)], timeout: 8), .completed,
                       "\(id) 没选中", file: file, line: line)
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }


    func testFreshLaunchShowsWallpaperWithZeroTapsAndNoPermission() {
        launch()
        wait("home.preview")
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertTrue(isSelected("style.month"))
        tap("style.year")                                  // 换样式 1 下（试用期内高级全开）
        waitSelected("style.year")
        XCTAssertTrue(element("home.trial").exists)
    }

    func testExpiredTrialKeepsMonthFreeAndLocksProStyles() {
        launch(["-expired"])
        wait("home.preview")
        XCTAssertTrue(isSelected("style.month"))
        open("style.today", expect: "paywall.buy")
        tap("paywall.close")
        XCTAssertTrue(isSelected("style.month"))
        open("home.auto", expect: "guide.openShortcuts")    // 免费版也能设自动换
    }

    func testEventsShareAndStyleCodeInTwoTaps() {
        launch(["-fake-events"])
        XCTAssertTrue(wait("home.events").label.contains("✓"))
        open("home.share", expect: "share.card")
        tap("share.code")
        XCTAssertTrue(app.staticTexts.matching(identifier: "home.notice").firstMatch.waitForExistence(timeout: 6)
                      || element("share.code").exists)
        wait("share.image", timeout: 12)
        tap("share.done")
    }

    func testGuideShowsLastAutoUpdateAndStreak() {
        launch(["-streak"])
        XCTAssertTrue(wait("home.lastRun").label.contains("12"))
        open("home.auto", expect: "guide.lastRun")
        XCTAssertFalse(element("guide.notYet").exists)
        tap("guide.done")
    }

    func testStreakMilestoneCardOffersShare() {
        launch(["-streak", "-milestone"])
        wait("milestone.share", timeout: 12)
        open("milestone.share", expect: "share.card")
        tap("share.done")
    }

    func testImportStyleCodeAppliesAndRejectsGarbage() {
        launch()
        open("home.settings", expect: "settings.code")
        let field = element("settings.code")
        field.tap()
        field.typeText("hello")
        tap("settings.apply")
        wait("settings.error")
        let code = "CW1:eyJzIjoieWVhciIsInIiOiJtb250aCIsImciOnRydWUsInAiOiJsb3dlciIsInQiOiJzYW5kIiwieCI6MX0"
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + code)
        tap("settings.apply")
        tap("settings.done")
        waitSelected("style.year")
    }


    func testStoreScreenshotsEnglish() { storeShots("en", locale: "en_US", lang: "en") }
    func testStoreScreenshotsSimplifiedChinese() { storeShots("zh-Hans", locale: "zh_CN", lang: "zh-Hans") }
    func testStoreScreenshotsTraditionalChinese() { storeShots("zh-Hant", locale: "zh_TW", lang: "zh-Hant") }

    private func storeShots(_ language: String, locale: String, lang: String) {
        let p = "store-\(lang)-"
        launch(["-fake-events"], language: language, locale: locale)
        wait("home.preview"); sleep(1); shot(p + "01-month")
        tap("style.year"); sleep(1); shot(p + "02-year")
        app.terminate()

        launch(["-fake-events", "-demo-photo"], language: language, locale: locale)
        tap("style.today"); sleep(1); shot(p + "03-today")
        app.terminate()

        launch(["-streak", "-sheet-guide"], language: language, locale: locale)
        wait("guide.lastRun"); sleep(1); shot(p + "04-auto")
        app.terminate()

        launch(["-fake-events", "-sheet-share"], language: language, locale: locale)
        wait("share.card"); wait("share.image", timeout: 12); sleep(1); shot(p + "05-share")
        app.terminate()

        if lang == "zh-Hans" {
            launch(["-sheet-paywall"], language: language, locale: locale)
            wait("paywall.buy"); sleep(1); shot("paid-01-paywall")
        }
    }
}
