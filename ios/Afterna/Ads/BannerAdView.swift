import GoogleMobileAds
import SwiftUI
import UIKit

/// Anchored adaptive banner (Memories / Search only — never Capture).
/// Collapses to zero height until an ad actually fills, so no-fill never shows a blank strip.
struct BannerAdView: View {
    @State private var isLoaded = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width > 0 ? geo.size.width : UIScreen.main.bounds.width
            let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
            BannerViewRepresentable(adSize: adSize, isLoaded: $isLoaded)
                .frame(width: adSize.size.width, height: adSize.size.height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: isLoaded ? 60 : 0)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: isLoaded)
    }
}

private struct BannerViewRepresentable: UIViewRepresentable {
    let adSize: AdSize
    @Binding var isLoaded: Bool

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
        Coordinator(isLoaded: $isLoaded)
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let isLoaded: Binding<Bool>

        init(isLoaded: Binding<Bool>) {
            self.isLoaded = isLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[AdMob] Banner loaded")
            isLoaded.wrappedValue = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Banner failed: \(error.localizedDescription)")
            isLoaded.wrappedValue = false
        }
    }
}
