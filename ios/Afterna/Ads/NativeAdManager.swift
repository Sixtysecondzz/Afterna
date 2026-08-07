import Foundation
import GoogleMobileAds
import UIKit

/// Loads a small pool of native ads for in-feed placement.
@MainActor
final class NativeAdManager: NSObject {
    static let shared = NativeAdManager()

    private(set) var readyAds: [GADNativeAd] = []
    private var adLoader: GADAdLoader?
    private var loading = false
    private let poolSize = 3

    func preload() {
        guard !loading else { return }
        guard readyAds.count < poolSize else { return }
        loading = true
        let loader = GADAdLoader(
            adUnitID: AdMobConfig.nativeUnitID,
            rootViewController: UIKitPresenter.topViewController(),
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        adLoader = loader
        loader.load(GADRequest())
    }

    func dequeueAd() -> GADNativeAd? {
        guard !readyAds.isEmpty else {
            preload()
            return nil
        }
        let ad = readyAds.removeFirst()
        preload()
        return ad
    }
}

extension NativeAdManager: GADAdLoaderDelegate, GADNativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        Task { @MainActor in
            self.readyAds.append(nativeAd)
            self.loading = false
            print("[AdMob] Native loaded (pool=\(self.readyAds.count))")
            if self.readyAds.count < self.poolSize {
                self.preload()
            }
        }
    }

    nonisolated func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: any Error) {
        Task { @MainActor in
            self.loading = false
            print("[AdMob] Native load failed: \(error.localizedDescription)")
        }
    }
}
