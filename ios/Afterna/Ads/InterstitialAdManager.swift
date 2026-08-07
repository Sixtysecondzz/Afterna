import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class InterstitialAdManager: NSObject, FullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    private var interstitialAd: InterstitialAd?
    private var memoryOpenCount = 0

    func loadAd() async {
        do {
            let ad = try await InterstitialAd.load(
                with: AdMobConfig.interstitialUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            interstitialAd = ad
        } catch {
            print("[AdMob] Interstitial load failed: \(error.localizedDescription)")
            interstitialAd = nil
        }
    }

    func showIfReady() {
        guard let interstitialAd else {
            Task { await loadAd() }
            return
        }
        interstitialAd.present(from: UIKitPresenter.topViewController())
    }

    func showAfterCaptureSaved() {
        showIfReady()
    }

    func showOnMemoryOpenIfNeeded() {
        memoryOpenCount += 1
        let interval = max(AdMobConfig.memoryOpenInterstitialInterval, 1)
        if memoryOpenCount % interval == 0 {
            showIfReady()
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitialAd = nil
        Task { await loadAd() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMob] Interstitial present failed: \(error.localizedDescription)")
        interstitialAd = nil
        Task { await loadAd() }
    }
}
