import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class AppOpenAdManager: NSObject, FullScreenContentDelegate {
    static let shared = AppOpenAdManager()

    private var appOpenAd: AppOpenAd?
    private var isLoadingAd = false
    private var isShowingAd = false
    private var loadTime: Date?
    private let timeoutInterval: TimeInterval = 4 * 3_600
    private var openCount = 0

    func loadAd() async {
        guard !isLoadingAd, !isAdAvailable() else { return }
        isLoadingAd = true
        defer { isLoadingAd = false }

        do {
            let ad = try await AppOpenAd.load(with: AdMobConfig.appOpenUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            appOpenAd = ad
            loadTime = Date()
        } catch {
            print("[AdMob] App open load failed: \(error.localizedDescription)")
            appOpenAd = nil
            loadTime = nil
        }
    }

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
        appOpenAd.present(from: UIKitPresenter.topViewController())
        isShowingAd = true
    }

    private func isAdAvailable() -> Bool {
        guard appOpenAd != nil, let loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < timeoutInterval
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        appOpenAd = nil
        isShowingAd = false
        Task { await loadAd() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMob] App open present failed: \(error.localizedDescription)")
        appOpenAd = nil
        isShowingAd = false
        Task { await loadAd() }
    }
}
