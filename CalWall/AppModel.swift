import StoreKit
import SwiftUI
import UIKit

enum Sheet: String, Identifiable {
    case guide, share, paywall, settings
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: StoredState
    @Published var sheet: Sheet?
    @Published var notice: String?
    @Published var milestone: Int?
    @Published private(set) var photo: UIImage?
    @Published private(set) var events: [WallEvent] = []
    @Published private(set) var eventDays: Set<Date> = []
    @Published var now: Date = .now
    let purchases = Purchases()

    init() {
        var s = LocalStore.load()
        if Launch.testFlag("-reset") { s = StoredState() }
        if let anchor = TrialAnchor.read(), !Launch.uiTesting {
            s.entitlement.firstOpen = min(anchor, s.entitlement.firstOpen)
        } else if !Launch.uiTesting {
            TrialAnchor.write(s.entitlement.firstOpen)
        }
        if Launch.testFlag("-expired") { s.entitlement.firstOpen = Date().addingTimeInterval(-40 * 86_400) }
        if Launch.testFlag("-pro") { s.entitlement.purchasedPro = true }
        if Launch.testFlag("-fake-events") { s.config.showEvents = true }
        if Launch.testFlag("-streak") {
            let cal = Calendar.current
            s.runDays = (0..<12).compactMap { cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: .now)) }
            s.lastRun = cal.date(bySettingHour: 0, minute: 5, second: 0, of: .now)
            if !Launch.testFlag("-milestone") { s.milestonesShown = [7] }
        }
        state = s
        if Launch.uiTesting { LocalStore.save(s) }
        now = .now
        photo = s.config.usePhoto ? LocalStore.loadPhoto() : nil
        if Launch.testFlag("-demo-photo") { photo = DemoPhoto.make(); state.config.usePhoto = true }
        recordScreen()
        reloadEvents()
        if Launch.testFlag("-sheet-guide") { sheet = .guide }
        if Launch.testFlag("-sheet-share") { sheet = .share }
        if Launch.testFlag("-sheet-paywall") { sheet = .paywall }
    }

    var hasPro: Bool { state.entitlement.hasPro(at: now) }
    var trialDaysLeft: Int { max(0, Int(ceil(state.entitlement.trialEnd.timeIntervalSince(now) / 86_400))) }
    var entitlement: Entitlement { state.entitlement }
    var effectiveConfig: WallConfig { hasPro ? state.config : state.config.limitedToFree() }
    var streak: Int { RunStats.streak(state.runDays, now: now) }

    var input: WallInput {
        let c = effectiveConfig
        return WallInput(config: c, today: now, events: c.showEvents ? events : [],
                         eventDays: c.showEvents ? eventDays : [], photo: c.usePhoto ? photo : nil)
    }
    var screenPoints: CGSize { WallpaperMaker.screen(state).0 }

    func updateEntitlement(_ e: Entitlement) { mutate { $0.entitlement = e } }

    private func mutate(_ change: (inout StoredState) -> Void) {
        change(&state)
        LocalStore.save(state)
    }

    func recordScreen() {
        let b = UIScreen.main.bounds.size
        guard b.width > 0 else { return }
        mutate { $0.screenPoints = b; $0.screenScale = UIScreen.main.scale }
    }

    func refresh() {
        now = .now
        let latest = LocalStore.load()
        if latest.runDays != state.runDays { state.runDays = latest.runDays; state.lastRun = latest.lastRun }
        reloadEvents()
        checkMilestone()
    }

    func reloadEvents() {
        let loaded = state.config.showEvents ? EventSource.load(for: now) : ([], [])
        events = loaded.0; eventDays = loaded.1
    }

    func choose(_ style: WallStyle) {
        guard !style.isPro || hasPro else { sheet = .paywall; return }
        mutate { $0.config.style = style }
    }

    func edit(_ change: (inout WallConfig) -> Void) { mutate { change(&$0.config) } }

    func toggleEvents() async {
        if state.config.showEvents { mutate { $0.config.showEvents = false }; reloadEvents(); return }
        guard hasPro else { sheet = .paywall; return }
        if !EventSource.authorized {
            guard await EventSource.requestAccess() else { notice = L.t("events.denied"); return }
        }
        mutate { $0.config.showEvents = true }
        reloadEvents()
    }

    func setPhoto(_ image: UIImage?) {
        guard hasPro else { sheet = .paywall; return }
        guard let image else { mutate { $0.config.usePhoto = false }; photo = nil; return }
        if LocalStore.savePhoto(image) {
            photo = LocalStore.loadPhoto()
            mutate { $0.config.usePhoto = true }
        } else { notice = L.t("photo.failed") }
    }

    func useSolid(_ tint: WallTint) {
        photo = nil
        mutate { $0.config.usePhoto = false; $0.config.tint = tint }
    }

    func saveToPhotos() {
        guard let image = WallpaperMaker.image(state, now: now) else { notice = L.t("intent.failed"); return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        notice = L.t("saved.photos")
    }

    func copyStyleCode() {
        UIPasteboard.general.string = L.t("code.caption") + "\n" + StyleCode.encode(state.config)
        notice = L.t("code.copied")
    }

    func importStyleCode(_ text: String) -> String? {
        do {
            let c = try StyleCode.decode(text, into: state.config)
            if c.needsPro && !hasPro { sheet = .paywall; return nil }
            mutate { $0.config = c }
            notice = L.t("code.imported")
            return nil
        } catch {
            return L.t("code.invalid")
        }
    }

    func checkMilestone() {
        let s = streak
        guard let m = RunStats.milestones.last(where: { s >= $0 }), !state.milestonesShown.contains(m) else { return }
        mutate { $0.milestonesShown.append(m) }
        milestone = m
    }

    func maybeAskReview(_ request: () -> Void) {
        guard !state.reviewAsked, state.runDays.count >= 3, sheet == nil, milestone == nil, !Launch.uiTesting else { return }
        mutate { $0.reviewAsked = true }
        request()
    }
}

enum DemoPhoto {
    static func make() -> UIImage {
        let size = CGSize(width: 1179, height: 2556)
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let colors = [UIColor(red: 0.85, green: 0.62, blue: 0.48, alpha: 1).cgColor,
                          UIColor(red: 0.24, green: 0.35, blue: 0.33, alpha: 1).cgColor,
                          UIColor(red: 0.08, green: 0.1, blue: 0.09, alpha: 1).cgColor]
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.55, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            UIColor(red: 0.16, green: 0.24, blue: 0.22, alpha: 1).setFill()
            let hill = UIBezierPath()
            hill.move(to: CGPoint(x: 0, y: size.height * 0.62))
            hill.addCurve(to: CGPoint(x: size.width, y: size.height * 0.58), controlPoint1: CGPoint(x: size.width * 0.3, y: size.height * 0.48),
                          controlPoint2: CGPoint(x: size.width * 0.7, y: size.height * 0.7))
            hill.addLine(to: CGPoint(x: size.width, y: size.height)); hill.addLine(to: CGPoint(x: 0, y: size.height)); hill.close()
            hill.fill()
        }
    }
}
