import Foundation

enum WallStyle: String, Codable, CaseIterable, Identifiable {
    case month, year, today
    var id: String { rawValue }
    var isPro: Bool { self != .month }
}

enum WallRange: String, Codable, CaseIterable, Identifiable {
    case month, twoWeeks
    var id: String { rawValue }
}

enum WallPosition: String, Codable, CaseIterable, Identifiable {
    case upper, lower
    var id: String { rawValue }
}

enum WallTint: String, Codable, CaseIterable, Identifiable {
    case ink, forest, sand, slate
    var id: String { rawValue }
}

struct WallConfig: Codable, Equatable {
    var style: WallStyle = .month
    var range: WallRange = .month
    var grayPast = true
    var position: WallPosition = .upper
    var tint: WallTint = .ink
    var showEvents = false
    var usePhoto = false
    var textScale: Double = 1.0

    func limitedToFree() -> WallConfig {
        var c = self
        c.style = .month
        c.usePhoto = false
        c.showEvents = false
        return c
    }

    var needsPro: Bool { style.isPro || usePhoto || showEvents }
}

enum StyleCode {
    static let prefix = "CW1:"
    static let maxLength = 400

    private struct Payload: Codable {
        var s: String; var r: String; var g: Bool; var p: String; var t: String; var x: Double
    }

    enum Failure: Error, Equatable { case empty, prefix, tooLong, corrupt }

    static func encode(_ c: WallConfig) -> String {
        let payload = Payload(s: c.style.rawValue, r: c.range.rawValue, g: c.grayPast,
                              p: c.position.rawValue, t: c.tint.rawValue, x: c.textScale)
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return prefix + b64
    }

    static func decode(_ raw: String, into base: WallConfig) throws -> WallConfig {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Failure.empty }
        guard text.count <= maxLength else { throw Failure.tooLong }
        guard let start = text.range(of: prefix) else { throw Failure.prefix }
        var body = String(text[start.upperBound...]).split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        body = body.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while body.count % 4 != 0 { body += "=" }
        guard let data = Data(base64Encoded: body),
              let p = try? JSONDecoder().decode(Payload.self, from: data),
              let style = WallStyle(rawValue: p.s), let range = WallRange(rawValue: p.r),
              let position = WallPosition(rawValue: p.p), let tint = WallTint(rawValue: p.t),
              (0.8...1.4).contains(p.x) else { throw Failure.corrupt }
        var c = base
        c.style = style; c.range = range; c.grayPast = p.g; c.position = position; c.tint = tint; c.textScale = p.x
        return c
    }
}
