import Foundation
import GoogleMobileAds

enum AdMobBootstrap {
    @MainActor
    static func start() {
        // Info.plist must contain GADApplicationIdentifier (see project.yml / README).
        GADMobileAds.sharedInstance().start { status in
            print("[AdMob] SDK started: \(status.adapterStatusesByClassName.keys.count) adapters")
        }
        Task {
            await AppOpenAdManager.shared.loadAd()
            await InterstitialAdManager.shared.loadAd()
            await RewardedAdManager.shared.loadAd()
            NativeAdManager.shared.preload()
        }
    }
}
