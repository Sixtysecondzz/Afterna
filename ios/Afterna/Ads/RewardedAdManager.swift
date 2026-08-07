import Foundation
import GoogleMobileAds
import UIKit

@MainActor
final class RewardedAdManager: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAdManager()

    private var rewardedAd: RewardedAd?
    private var rewardHandler: ((Bool) -> Void)?

    func loadAd() async {
        do {
            let ad = try await RewardedAd.load(
                with: AdMobConfig.rewardedUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            print("[AdMob] Rewarded loaded (\(AdMobConfig.rewardedUnitID))")
        } catch {
            print("[AdMob] Rewarded load failed: \(error.localizedDescription)")
            rewardedAd = nil
        }
    }

    /// Presents a rewarded ad. Calls `completion(true)` only when the user earns the reward.
    func show(completion: @escaping (Bool) -> Void) {
        guard let rewardedAd else {
            completion(false)
            Task { await loadAd() }
            return
        }

        rewardHandler = completion
        rewardedAd.present(from: nil) { [weak self] in
            guard let self else { return }
            let handler = self.rewardHandler
            self.rewardHandler = nil
            handler?(true)
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        if rewardHandler != nil {
            // Dismissed without reward callback already firing → treat as no reward.
            let handler = rewardHandler
            rewardHandler = nil
            handler?(false)
        }
        Task { await loadAd() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMob] Rewarded present failed: \(error.localizedDescription)")
        rewardedAd = nil
        let handler = rewardHandler
        rewardHandler = nil
        handler?(false)
        Task { await loadAd() }
    }
}
