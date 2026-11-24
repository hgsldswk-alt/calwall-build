import CoreGraphics

enum WallLayout {
    static func contentTop(_ size: CGSize, _ position: WallPosition) -> CGFloat {
        size.height * (position == .upper ? 0.34 : 0.52)
    }
    static func contentBottom(_ size: CGSize) -> CGFloat { size.height * 0.85 }
    static func clockZone(_ size: CGSize) -> CGRect {
        CGRect(x: size.width * 0.06, y: size.height * 0.05, width: size.width * 0.88, height: size.height * 0.25)
    }
}
