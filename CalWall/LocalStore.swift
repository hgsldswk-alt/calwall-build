import Foundation
import Security
import UIKit

struct StoredState: Codable, Equatable {
    var config = WallConfig()
    var entitlement = Entitlement()
    var runDays: [Date] = []
    var lastRun: Date?
    var screenPoints: CGSize?
    var screenScale: CGFloat?
    var reviewAsked = false
    var milestonesShown: [Int] = []
}

enum LocalStore {
    private static let key = "calwall.state.v1"
    static var defaults: UserDefaults = .standard

    static func load() -> StoredState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(StoredState.self, from: data) else { return StoredState() }
        return state
    }

    static func save(_ state: StoredState) {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }

    static var photoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wall-photo.jpg")
    }

    static func savePhoto(_ image: UIImage) -> Bool {
        let scaled = image.limited(to: 2400)
        guard let data = scaled.jpegData(compressionQuality: 0.88) else { return false }
        do {
            try FileManager.default.createDirectory(at: photoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: photoURL, options: .atomic)
            return true
        } catch { return false }
    }

    static func loadPhoto() -> UIImage? { UIImage(contentsOfFile: photoURL.path) }
}

enum TrialAnchor {
    private static let account = "calwall.firstOpen"

    static func read() -> Date? {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        query[kSecAttrService as String] = "calwall"
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data,
              let seconds = Double(String(decoding: data, as: UTF8.self)) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    static func write(_ date: Date) {
        let data = Data(String(date.timeIntervalSince1970).utf8)
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account,
                                   kSecAttrService as String: "calwall"]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

extension UIImage {
    func limited(to longest: CGFloat) -> UIImage {
        let side = max(size.width, size.height)
        guard side > longest else { return self }
        let ratio = longest / side
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
