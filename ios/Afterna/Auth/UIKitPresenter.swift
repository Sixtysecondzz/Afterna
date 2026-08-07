import UIKit

@MainActor
enum UIKitPresenter {
    static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return topMost(from: root)
    }

    private static func topMost(from base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topMost(from: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topMost(from: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topMost(from: presented)
        }
        return base
    }
}
