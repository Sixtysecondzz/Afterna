import Foundation

/// AdMob IDs for Afterna.
///
/// **Required before App Store / production ads:** set `applicationID` to your AdMob *App ID*
/// (format `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` from AdMob → Apps → App settings).
/// Unit IDs alone are not enough for `GADApplicationIdentifier`.
enum AdMobConfig {
    /// AdMob App ID (GADApplicationIdentifier).
    static let applicationID = "ca-app-pub-9350266309525886~6797170145"

    /// Google sample App ID — used while `useTestAds == true` so Simulator testing is safe.
    static let testApplicationID = "ca-app-pub-3940256099942544~1458002511"

    static let productionAppOpen = "ca-app-pub-9350266309525886/4087246329"
    static let productionInterstitial = "ca-app-pub-9350266309525886/6837798679"
    static let productionBanner = "ca-app-pub-9350266309525886/3320959568"

    static let testAppOpen = "ca-app-pub-3940256099942544/5575463023"
    static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"
    static let testBanner = "ca-app-pub-3940256099942544/2435281174"

    /// DEBUG defaults to test ads to avoid accidental invalid traffic / policy strikes.
    #if DEBUG
    static var useTestAds = true
    #else
    static var useTestAds = false
    #endif

    static var appOpenUnitID: String { useTestAds ? testAppOpen : productionAppOpen }
    static var interstitialUnitID: String { useTestAds ? testInterstitial : productionInterstitial }
    static var bannerUnitID: String { useTestAds ? testBanner : productionBanner }

    /// How often to show an interstitial when opening memories (product: every 4–6).
    static var memoryOpenInterstitialInterval: Int = 5
}
