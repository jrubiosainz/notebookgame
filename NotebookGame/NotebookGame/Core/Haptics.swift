import UIKit

/// Small, tasteful haptics. Every call is cheap and safe to make from any scene.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()

    static func prepare() {
        light.prepare()
        medium.prepare()
    }

    static func tap() { light.impactOccurred() }
    static func hit() { medium.impactOccurred() }
    static func bigHit() { heavy.impactOccurred() }
    static func success() { notice.notificationOccurred(.success) }
    static func failure() { notice.notificationOccurred(.error) }
}
