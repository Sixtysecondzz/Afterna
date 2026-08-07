import Foundation

/// AdMob IDs for Afterna.
enum AdMobConfig {
    /// AdMob App ID (GADApplicationIdentifier).
    static let applicationID = "ca-app-pub-9350266309525886~6797170145"

    static let testApplicationID = "ca-app-pub-3940256099942544~1458002511"

    static let productionAppOpen = "ca-app-pub-9350266309525886/4087246329"
    static let productionInterstitial = "ca-app-pub-9350266309525886/6837798679"
    static let productionBanner = "ca-app-pub-9350266309525886/3320959568"
    static let productionRewarded = "ca-app-pub-9350266309525886/8233660880"

    static let testAppOpen = "ca-app-pub-3940256099942544/5575463023"
    static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"
    static let testBanner = "ca-app-pub-3940256099942544/2435281174"
    static let testRewarded = "ca-app-pub-3940256099942544/1712485313"

    /// Production AdMob units (set `true` only when intentionally testing with Google sample IDs).
    static var useTestAds = false

    static var appOpenUnitID: String { useTestAds ? testAppOpen : productionAppOpen }
    static var interstitialUnitID: String { useTestAds ? testInterstitial : productionInterstitial }
    static var bannerUnitID: String { useTestAds ? testBanner : productionBanner }
    static var rewardedUnitID: String {
        if useTestAds { return testRewarded }
        let id = (Bundle.main.object(forInfoDictionaryKey: "GADRewardedAdUnitID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if id.contains("/"), !id.contains("REPLACE") { return id }
        if productionRewarded.contains("/"), !productionRewarded.contains("REPLACE") {
            return productionRewarded
        }
        return testRewarded
    }

    static var memoryOpenInterstitialInterval: Int = 5

    /// Guests + new accounts start with this many Recording Credits.
    static let welcomeCredits = 5
}
