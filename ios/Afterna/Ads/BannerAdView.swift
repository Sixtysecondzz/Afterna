import GoogleMobileAds
import SwiftUI
import UIKit

/// Anchored adaptive banner (Memories / Search only — never Capture).
struct BannerAdView: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width
            let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
            BannerViewRepresentable(adSize: adSize)
                .frame(width: adSize.size.width, height: adSize.size.height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 60)
    }
}

private struct BannerViewRepresentable: UIViewRepresentable {
    let adSize: GADAdSize

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: adSize)
        banner.adUnitID = AdMobConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIKitPresenter.topViewController()
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // Reload if width/size changes significantly could be added later.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("[AdMob] Banner loaded")
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Banner failed: \(error.localizedDescription)")
        }
    }
}
