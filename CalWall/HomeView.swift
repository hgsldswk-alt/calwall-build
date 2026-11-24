import PhotosUI
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var photoItem: PhotosPickerItem?
    @State private var showTune = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L.t("app.name")).font(.headline)
                Spacer()
                Button(L.t("share.open")) { model.sheet = .share }.accessibilityIdentifier("home.share")
                    .frame(minWidth: 44, minHeight: 44)
                Button { model.sheet = .settings } label: { Image(systemName: "gearshape") }
                    .frame(minWidth: 44, minHeight: 44).accessibilityLabel(L.t("settings.title")).accessibilityIdentifier("home.settings")
            }
            .foregroundStyle(Theme.accent).font(.subheadline.weight(.semibold))

            WallPreview(input: model.input, points: model.screenPoints)
                .frame(maxHeight: .infinity)
                .onTapGesture { showTune.toggle() }

            Text(L.t("home.zoneHint")).font(.caption).foregroundStyle(Theme.muted)

            HStack(spacing: 8) {
                ForEach(WallStyle.allCases) { s in
                    ChipButton(title: L.t("style." + s.rawValue), on: model.effectiveConfig.style == s,
                               id: "style." + s.rawValue, locked: s.isPro && !model.hasPro) { model.choose(s) }
                }
            }

            if showTune { TunePanel().transition(.move(edge: .bottom).combined(with: .opacity)) }

            HStack(spacing: 8) {
                Menu {
                    ForEach(WallTint.allCases) { t in
                        Button(L.t("tint." + t.rawValue)) { model.useSolid(t) }
                    }
                } label: {
                    label(model.effectiveConfig.usePhoto ? L.t("bg.photoOn") : L.t("bg.title"), on: model.effectiveConfig.usePhoto)
                }
                .accessibilityIdentifier("home.background")
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo").font(.body.weight(.semibold)).frame(width: 50, height: 46)
                        .foregroundStyle(Theme.accent).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
                }
                .accessibilityLabel(L.t("bg.pick")).accessibilityIdentifier("home.photo")
                Button { Task { await model.toggleEvents() } } label: {
                    label(model.effectiveConfig.showEvents ? L.t("events.on") : L.t("events.show"), on: model.effectiveConfig.showEvents)
                }
                .buttonStyle(.plain).accessibilityIdentifier("home.events")
            }

            PrimaryButton(title: L.t("auto.open"), id: "home.auto") { model.sheet = .guide }
            if let last = model.state.lastRun {
                Text(L.f("auto.last", last.formatted(date: .abbreviated, time: .shortened), model.streak))
                    .font(.caption).foregroundStyle(Theme.accent).accessibilityIdentifier("home.lastRun")
            } else if !model.hasPro || model.trialDaysLeft <= 30, !Launch.freePeriod, !model.entitlement.purchasedPro {
                Text(model.hasPro ? L.f("trial.left", model.trialDaysLeft) : L.t("trial.ended"))
                    .font(.caption).foregroundStyle(Theme.muted).accessibilityIdentifier("home.trial")
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Theme.paper.ignoresSafeArea())
        .animation(.snappy, value: showTune)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    model.setPhoto(image)
                } else { model.notice = L.t("photo.failed") }
                photoItem = nil
            }
        }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .guide: GuideView()
            case .share: ShareSheetView()
            case .paywall: PaywallView()
            case .settings: SettingsView()
            }
        }
        .sheet(item: Binding(get: { model.milestone.map(MilestoneBox.init) }, set: { _ in model.milestone = nil })) { box in
            MilestoneView(days: box.days)
        }
        .overlay(alignment: .top) {
            if let n = model.notice {
                Text(n).font(.subheadline).padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule()).padding(.top, 6)
                    .accessibilityIdentifier("home.notice")
                    .task { try? await Task.sleep(for: .seconds(2.5)); model.notice = nil }
            }
        }
        .tint(Theme.accent)
    }

    private func label(_ text: String, on: Bool) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(on ? Theme.accent : Theme.ink)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(on ? Theme.accent : Theme.line, lineWidth: on ? 2 : 1))
    }
}

struct MilestoneBox: Identifiable { let days: Int; var id: Int { days } }

struct TunePanel: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(spacing: 6) {
            if model.effectiveConfig.style == .month {
                Picker(L.t("tune.range"), selection: Binding(get: { model.state.config.range }, set: { v in model.edit { $0.range = v } })) {
                    ForEach(WallRange.allCases) { Text(L.t("range." + $0.rawValue)).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("tune.range")
            }
            Toggle(L.t("tune.gray"), isOn: Binding(get: { model.state.config.grayPast }, set: { v in model.edit { $0.grayPast = v } }))
                .accessibilityIdentifier("tune.gray")
            Picker(L.t("tune.position"), selection: Binding(get: { model.state.config.position }, set: { v in model.edit { $0.position = v } })) {
                ForEach(WallPosition.allCases) { Text(L.t("position." + $0.rawValue)).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("tune.position")
            HStack {
                Image(systemName: "textformat.size.smaller")
                Slider(value: Binding(get: { model.state.config.textScale }, set: { v in model.edit { $0.textScale = v } }), in: 0.8...1.4, step: 0.1)
                    .accessibilityLabel(L.t("tune.size")).accessibilityIdentifier("tune.size")
                Image(systemName: "textformat.size.larger")
            }.foregroundStyle(Theme.muted)
        }
        .font(.subheadline)
        .padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line))
    }
}
