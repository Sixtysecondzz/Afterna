import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class RewardedAdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = RewardedAdManager()

    private var rewardedAd: GADRewardedAd?
    private var rewardHandler: ((Bool) -> Void)?

    func loadAd() async {
        let ad: GADRewardedAd? = await withCheckedContinuation { continuation in
            GADRewardedAd.load(
                withAdUnitID: AdMobConfig.rewardedUnitID,
                request: GADRequest()
            ) { ad, error in
                if let error {
                    print("[AdMob] Rewarded load failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: ad)
            }
        }
        guard let ad else {
            rewardedAd = nil
            return
        }
        ad.fullScreenContentDelegate = self
        rewardedAd = ad
        print("[AdMob] Rewarded loaded (\(AdMobConfig.rewardedUnitID))")
    }

    func show(completion: @escaping (Bool) -> Void) {
        guard let rewardedAd else {
            completion(false)
            Task { await loadAd() }
            return
        }
        guard let root = UIKitPresenter.topViewController() else {
            completion(false)
            return
        }

        rewardHandler = completion
        rewardedAd.present(fromRootViewController: root) { [weak self] in
            guard let self else { return }
            let handler = self.rewardHandler
            self.rewardHandler = nil
            handler?(true)
        }
    }

    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        rewardedAd = nil
        if rewardHandler != nil {
            let handler = rewardHandler
            rewardHandler = nil
            handler?(false)
        }
        Task { await loadAd() }
    }

    func ad(
        _ ad: any GADFullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: any Error
    ) {
        print("[AdMob] Rewarded present failed: \(error.localizedDescription)")
        rewardedAd = nil
        let handler = rewardHandler
        rewardHandler = nil
        handler?(false)
        Task { await loadAd() }
    }
}
