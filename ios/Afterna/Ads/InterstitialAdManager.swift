import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class InterstitialAdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = InterstitialAdManager()

    private var interstitialAd: GADInterstitialAd?
    private var memoryOpenCount = 0

    func loadAd() async {
        let ad: GADInterstitialAd? = await withCheckedContinuation { continuation in
            GADInterstitialAd.load(
                withAdUnitID: AdMobConfig.interstitialUnitID,
                request: GADRequest()
            ) { ad, error in
                if let error {
                    print("[AdMob] Interstitial load failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: ad)
            }
        }
        guard let ad else {
            interstitialAd = nil
            return
        }
        ad.fullScreenContentDelegate = self
        interstitialAd = ad
    }

    func showIfReady() {
        guard let interstitialAd else {
            Task { await loadAd() }
            return
        }
        guard let root = UIKitPresenter.topViewController() else {
            Task { await loadAd() }
            return
        }
        interstitialAd.present(fromRootViewController: root)
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

    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        interstitialAd = nil
        Task { await loadAd() }
    }

    func ad(
        _ ad: any GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        print("[AdMob] Interstitial present failed: \(error.localizedDescription)")
        interstitialAd = nil
        Task { await loadAd() }
    }
}
