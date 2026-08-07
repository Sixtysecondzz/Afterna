import GoogleMobileAds
import SwiftUI
import UIKit

/// Anchored adaptive banner (Memories / Search only — never Capture).
struct BannerAdView: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
            BannerViewRepresentable(adSize: adSize)
                .frame(width: adSize.size.width, height: adSize.size.height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 60)
    }
}

private struct BannerViewRepresentable: UIViewRepresentable {
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdMobConfig.bannerUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIKitPresenter.topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[AdMob] Banner loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Banner failed: \(error.localizedDescription)")
        }
    }
}
