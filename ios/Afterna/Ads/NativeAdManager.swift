import Foundation
import GoogleMobileAds
import Observation
import UIKit

/// Loads a small pool of native ads for in-feed placement.
@Observable
@MainActor
final class NativeAdManager: NSObject, AdLoaderDelegate, NativeAdLoaderDelegate {
    static let shared = NativeAdManager()

    private(set) var readyAds: [NativeAd] = []
    private var adLoader: AdLoader?
    private var loading = false
    private let poolSize = 3

    func preload() {
        guard !loading else { return }
        guard readyAds.count < poolSize else { return }
        loading = true
        let loader = AdLoader(
            adUnitID: AdMobConfig.nativeUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        adLoader = loader
        loader.load(Request())
    }

    /// Take one ready ad for a feed slot (may be nil if not loaded yet).
    func dequeueAd() -> NativeAd? {
        guard !readyAds.isEmpty else {
            preload()
            return nil
        }
        let ad = readyAds.removeFirst()
        preload()
        return ad
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        Task { @MainActor in
            self.readyAds.append(nativeAd)
            self.loading = false
            print("[AdMob] Native loaded (pool=\(self.readyAds.count))")
            if self.readyAds.count < self.poolSize {
                self.preload()
            }
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            self.loading = false
            print("[AdMob] Native load failed: \(error.localizedDescription)")
        }
    }
}
