import Foundation
import GoogleMobileAds

enum AdMobBootstrap {
    @MainActor
    static func start() {
        // Info.plist must contain GADApplicationIdentifier (see project.yml / README).
        // sharedInstance is a property (not a method) in GMA 11+/12 Swift overlays.
        GADMobileAds.sharedInstance.start { status in
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
