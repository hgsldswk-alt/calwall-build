import PhotosUI
import StoreKit
import SwiftUI

@main
struct CalWallApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    @Environment(\.requestReview) private var requestReview

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .task { await model.purchases.loadProducts(); await model.purchases.refresh(model: model) }
                .task { await model.purchases.listen(model: model) }
                .onChange(of: phase) { _, p in
                    if p == .active {
                        model.refresh()
                        model.maybeAskReview { requestReview() }
                    }
                }
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.184, green: 0.204, blue: 0.196)
    static let coral = WallPalette.today
    static let paper = Color(red: 0.965, green: 0.957, blue: 0.937)
    static let surface = Color(red: 1.0, green: 0.992, blue: 0.973)
    static let ink = Color(red: 0.118, green: 0.141, blue: 0.133)
    static let muted = Color(red: 0.36, green: 0.404, blue: 0.388)
    static let line = Color(red: 0.855, green: 0.839, blue: 0.80)
}

struct ChipButton: View {
    let title: String
    let on: Bool
    let id: String
    var locked = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
                if locked { Image(systemName: "lock.fill").font(.caption2) }
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(on ? Theme.accent : Theme.ink)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.accent : Theme.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct PrimaryButton: View {
    let title: String
    let id: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

struct WallPreview: View {
    let input: WallInput
    let points: CGSize
    var showZone = true

    var body: some View {
        GeometryReader { geo in
            let k = min(geo.size.width / points.width, geo.size.height / points.height)
            ZStack(alignment: .top) {
                WallpaperView(input: input, size: points)
                    .overlay(alignment: .top) { clock }
                    .frame(width: points.width, height: points.height)
                    .clipShape(RoundedRectangle(cornerRadius: 54))
                    .scaleEffect(k, anchor: .center)
                    .frame(width: points.width * k, height: points.height * k)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        }
        .aspectRatio(points.width / points.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L.t("a11y.preview"))
        .accessibilityIdentifier("home.preview")
    }

    private var clock: some View {
        let zone = WallLayout.clockZone(points)
        let light = input.config.tint == .sand && !(input.config.usePhoto && input.photo != nil)
        return ZStack(alignment: .top) {
            if showZone {
                RoundedRectangle(cornerRadius: 22).stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .foregroundStyle((light ? Color.black : Color.white).opacity(0.35))
                    .frame(width: zone.width, height: zone.height)
            }
            VStack(spacing: 2) {
                Text(input.today.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.system(size: 20, weight: .semibold))
                Text(input.today.formatted(date: .omitted, time: .shortened)).font(.system(size: 96, weight: .semibold))
            }
            .foregroundStyle(light ? Theme.ink : .white).opacity(0.92).padding(.top, zone.height * 0.22)
        }
        .padding(.top, zone.minY)
    }
}
