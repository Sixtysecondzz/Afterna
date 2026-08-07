import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class AppOpenAdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AppOpenAdManager()

    private var appOpenAd: GADAppOpenAd?
    private var isLoadingAd = false
    private var isShowingAd = false
    private var loadTime: Date?
    private let timeoutInterval: TimeInterval = 4 * 3_600
    private var openCount = 0

    func loadAd() async {
        guard !isLoadingAd, !isAdAvailable() else { return }
        isLoadingAd = true
        defer { isLoadingAd = false }

        let ad: GADAppOpenAd? = await withCheckedContinuation { continuation in
            GADAppOpenAd.load(
                withAdUnitID: AdMobConfig.appOpenUnitID,
                request: GADRequest()
            ) { ad, error in
                if let error {
                    print("[AdMob] App open load failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: ad)
            }
        }
        guard let ad else {
            appOpenAd = nil
            loadTime = nil
            return
        }
        ad.fullScreenContentDelegate = self
        appOpenAd = ad
        loadTime = Date()
    }

    /// Show on warm start / return to foreground. Skips the very first cold open.
    func showAdIfAvailable() {
        openCount += 1
        guard openCount > 1 else {
            Task { await loadAd() }
            return
        }
        guard !isShowingAd else { return }
        guard isAdAvailable(), let appOpenAd else {
            Task { await loadAd() }
            return
        }
        guard let root = UIKitPresenter.topViewController() else {
            Task { await loadAd() }
            return
        }
        appOpenAd.present(fromRootViewController: root)
        isShowingAd = true
    }

    private func isAdAvailable() -> Bool {
        guard appOpenAd != nil, let loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < timeoutInterval
    }

    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        appOpenAd = nil
        isShowingAd = false
        Task { await loadAd() }
    }

    func ad(
        _ ad: any GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        print("[AdMob] App open present failed: \(error.localizedDescription)")
        appOpenAd = nil
        isShowingAd = false
        Task { await loadAd() }
    }
}
