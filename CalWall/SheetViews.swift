import CoreImage
import StoreKit
import SwiftUI

private struct SheetFrame<Content: View>: View {
    let title: String
    let closeID: String
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 12) { content }.padding(18) }
                .background(Theme.paper.ignoresSafeArea())
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.t("action.done")) { dismiss() }.accessibilityIdentifier(closeID)
                    }
                }
        }
        .tint(Theme.accent)
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
    }
}

struct GuideView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        SheetFrame(title: L.t("auto.title"), closeID: "guide.done") {
            step(1, L.t("guide.1"), L.t("guide.1b"))
            step(2, L.t("guide.2"), L.t("guide.2b"))
            step(3, L.t("guide.3"), L.t("guide.3b"))
            PrimaryButton(title: L.t("guide.open"), id: "guide.openShortcuts") {
                if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
            }
            if let last = model.state.lastRun {
                Text(L.f("auto.last", last.formatted(date: .abbreviated, time: .shortened), model.streak))
                    .font(.footnote).foregroundStyle(Theme.accent).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("guide.lastRun")
            } else {
                Text(L.t("guide.notYet")).font(.footnote).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("guide.notYet")
            }
            Button(L.t("guide.saveNow")) { model.saveToPhotos() }
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("guide.save")
        }
    }

    private func step(_ n: Int, _ title: String, _ note: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Text("\(n)").font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(width: 28, height: 28).background(Theme.accent, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body)
                    Text(note).font(.footnote).foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

struct ShareSheetView: View {
    @EnvironmentObject private var model: AppModel
    @State private var image: UIImage?

    var body: some View {
        SheetFrame(title: L.t("share.title"), closeID: "share.done") {
            ShareCard(input: model.input, points: model.screenPoints, qr: qrImage)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("share.card")
            HStack(spacing: 8) {
                if let image {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(L.t("share.title"), image: Image(uiImage: image))) {
                        Text(L.t("share.image")).font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(.white).background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityIdentifier("share.image")
                }
                Button(L.t("code.copy")) { model.copyStyleCode() }
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
                    .accessibilityIdentifier("share.code")
            }
            Text(L.t("share.privacy")).font(.footnote).foregroundStyle(Theme.muted)
        }
        .task { render() }
    }

    private var qrImage: UIImage? {
        guard let url = ShareLinks.storeURL, let cg = DownloadQR.make(for: url) else { return nil }
        return UIImage(cgImage: cg)
    }

    @MainActor private func render() {
        var input = model.input
        input.events = input.events.isEmpty ? [] : input.events.map { e in
            WallEvent(title: L.t("share.eventPlaceholder"), start: e.start, allDay: e.allDay)
        }
        let renderer = ImageRenderer(content: ShareCard(input: input, points: model.screenPoints, qr: qrImage).frame(width: 360))
        renderer.scale = 3
        image = renderer.uiImage
    }
}

struct ShareCard: View {
    let input: WallInput
    let points: CGSize
    let qr: UIImage?
    var body: some View {
        VStack(spacing: 14) {
            WallPreview(input: input, points: points, showZone: false).frame(width: 190)
            HStack(spacing: 12) {
                if let qr {
                    Image(uiImage: qr).interpolation(.none).resizable().frame(width: 58, height: 58)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L.t("share.line")).font(.footnote)
                    Text("#CalendarWallpaper").font(.footnote.bold()).foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(20).frame(width: 300)
        .background(Color(red: 0.937, green: 0.922, blue: 0.886), in: RoundedRectangle(cornerRadius: 24))
        .foregroundStyle(Theme.ink)
    }
}

enum ShareLinks {
    static var storeURL: URL? {
        let id = (Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String) ?? ""
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)")
    }
}

enum DownloadQR {
    static func make(for url: URL) -> CGImage? {
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter?.outputImage else { return nil }
        let padded = output.composited(over: CIImage(color: .white)).cropped(to: output.extent.insetBy(dx: -4, dy: -4))
        let scaled = padded.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        SheetFrame(title: L.t("pro.title"), closeID: "paywall.close") {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L.t("pro.name")).font(.headline)
                        Spacer()
                        Text(model.purchases.product(Launch.proID)?.displayPrice ?? "").font(.headline)
                            .accessibilityIdentifier("paywall.price")
                    }
                    Text(L.t("pro.oneTime")).font(.subheadline)
                    Text(model.hasPro ? L.f("trial.left", model.trialDaysLeft) : L.t("trial.ended"))
                        .font(.footnote).foregroundStyle(Theme.muted)
                    ForEach(["pro.f1", "pro.f2", "pro.f3", "pro.f4"], id: \.self) { k in
                        Label(L.t(k), systemImage: "checkmark").font(.subheadline)
                    }
                    Text(L.t("pro.free")).font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            PrimaryButton(title: L.t("pro.buy"), id: "paywall.buy") {
                Task { await model.purchases.purchase(Launch.proID, model: model); if model.entitlement.purchasedPro { dismiss() } }
            }
            Button(L.t("pro.restore")) { Task { await model.purchases.restore(model: model) } }
                .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("paywall.restore")
            if let e = model.purchases.error { Text(L.t(e)).font(.footnote).foregroundStyle(Theme.muted) }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var code = ""
    @State private var error: String?
    var body: some View {
        SheetFrame(title: L.t("settings.title"), closeID: "settings.done") {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t("code.import")).font(.headline)
                    TextField(L.t("code.placeholder"), text: $code, axis: .vertical).font(.system(.footnote, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("settings.code")
                    HStack {
                        Button(L.t("code.paste")) { code = UIPasteboard.general.string ?? "" }.accessibilityIdentifier("settings.paste")
                        Spacer()
                        Button(L.t("code.apply")) { error = model.importStyleCode(code) }.accessibilityIdentifier("settings.apply")
                            .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.frame(minHeight: 44)
                    if let error { Text(error).font(.footnote).foregroundStyle(Theme.coral).accessibilityIdentifier("settings.error") }
                }
            }
            if !Launch.freePeriod {
                Button(L.t("pro.restore")) { Task { await model.purchases.restore(model: model) } }
                    .frame(maxWidth: .infinity, minHeight: 44)
                if !model.entitlement.purchasedPro {
                    Button(L.t("pro.title")) { model.sheet = .paywall }.frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("settings.pro")
                }
            }
            Text(L.t("settings.privacy")).font(.footnote).foregroundStyle(Theme.muted)
        }
    }
}

struct MilestoneView: View {
    let days: Int
    @EnvironmentObject private var model: AppModel
    var body: some View {
        SheetFrame(title: L.t("milestone.title"), closeID: "milestone.done") {
            Card {
                VStack(spacing: 10) {
                    Text("\(days)").font(.system(size: 64, weight: .bold)).foregroundStyle(Theme.coral)
                    Text(L.f("milestone.line", days)).font(.headline).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
            }
            PrimaryButton(title: L.t("share.open"), id: "milestone.share") {
                model.milestone = nil
                Task { try? await Task.sleep(for: .milliseconds(400)); model.sheet = .share }
            }
        }
    }
}
