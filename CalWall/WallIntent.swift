import AppIntents
import UIKit
import UniformTypeIdentifiers

@MainActor
enum WallpaperMaker {
    static func screen(_ state: StoredState) -> (CGSize, CGFloat) {
        if let p = state.screenPoints, let s = state.screenScale, p.width > 0 { return (p, s) }
        let b = UIScreen.main.bounds.size
        return (b.width > 0 ? b : CGSize(width: 393, height: 852), UIScreen.main.scale)
    }

    static func input(_ state: StoredState, now: Date, pro: Bool) -> WallInput {
        let config = pro ? state.config : state.config.limitedToFree()
        let loaded = config.showEvents ? EventSource.load(for: now) : ([], [])
        return WallInput(config: config, today: now, events: loaded.0, eventDays: loaded.1,
                         photo: config.usePhoto ? LocalStore.loadPhoto() : nil)
    }

    static func image(_ state: StoredState, now: Date) -> UIImage? {
        let (points, scale) = screen(state)
        let pro = state.entitlement.hasPro(at: now)
        return WallRenderer.render(input(state, now: now, pro: pro), points: points, scale: scale)
    }

    static func recordRun(_ state: inout StoredState, now: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: now)
        if !state.runDays.contains(day) { state.runDays.append(day) }
        state.runDays = Array(state.runDays.sorted().suffix(400))
        state.lastRun = now
    }
}

struct MakeWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.title"
    static var description = IntentDescription("intent.description")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        var state = LocalStore.load()
        let now = Date()
        guard let image = WallpaperMaker.image(state, now: now), let data = image.pngData() else {
            throw IntentFailure.render
        }
        WallpaperMaker.recordRun(&state, now: now)
        LocalStore.save(state)
        return .result(value: IntentFile(data: data, filename: "calendar-wallpaper.png", type: .png))
    }

    enum IntentFailure: Error, CustomLocalizedStringResourceConvertible {
        case render
        var localizedStringResource: LocalizedStringResource { "intent.failed" }
    }
}

struct CalWallShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: MakeWallpaperIntent(),
                    phrases: ["Make wallpaper with \(.applicationName)", "Update \(.applicationName)"],
                    shortTitle: "intent.short", systemImageName: "calendar")
    }
}
