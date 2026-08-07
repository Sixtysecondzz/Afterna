import GoogleMobileAds
import SwiftUI
import UIKit

/// In-feed native ad row styled to match Memories list cards.
struct NativeFeedAdView: View {
    @State private var ad: NativeAd?

    var body: some View {
        Group {
            if let ad {
                NativeAdRepresentable(ad: ad)
                    .frame(minHeight: 120)
            } else {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignTokens.mist)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sponsored")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.mist)
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.mist.opacity(0.7))
                            .frame(width: 160, height: 10)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .task {
                    NativeAdManager.shared.preload()
                    for _ in 0..<8 {
                        if let next = NativeAdManager.shared.dequeueAd() {
                            ad = next
                            break
                        }
                        try? await Task.sleep(nanoseconds: 400_000_000)
                    }
                }
            }
        }
        .listRowBackground(DesignTokens.mist.opacity(0.35))
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct NativeAdRepresentable: UIViewRepresentable {
    let ad: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let view = NativeAdCardView()
        view.apply(ad)
        return view
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {
        (uiView as? NativeAdCardView)?.apply(ad)
    }
}

/// Programmatic NativeAdView — no XIB required.
final class NativeAdCardView: NativeAdView {
    private let sponsoredLabel = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let iconImageView = UIImageView()
    private let ctaButton = UIButton(type: .system)
    private let media = MediaView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        sponsoredLabel.text = "Sponsored"
        sponsoredLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        sponsoredLabel.textColor = .secondaryLabel

        headlineLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headlineLabel.textColor = UIColor(DesignTokens.ink)
        headlineLabel.numberOfLines = 2

        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2

        advertiserLabel.font = .systemFont(ofSize: 12)
        advertiserLabel.textColor = UIColor(DesignTokens.accent)

        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 8
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
        ])

        ctaButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        ctaButton.backgroundColor = UIColor(DesignTokens.accent)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.layer.cornerRadius = 8
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        ctaButton.isUserInteractionEnabled = false

        media.translatesAutoresizingMaskIntoConstraints = false
        media.heightAnchor.constraint(equalToConstant: 140).isActive = true

        let textStack = UIStackView(arrangedSubviews: [sponsoredLabel, headlineLabel, bodyLabel, advertiserLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let top = UIStackView(arrangedSubviews: [iconImageView, textStack])
        top.axis = .horizontal
        top.spacing = 12
        top.alignment = .top

        let root = UIStackView(arrangedSubviews: [top, media, ctaButton])
        root.axis = .vertical
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        headlineView = headlineLabel
        bodyView = bodyLabel
        iconView = iconImageView
        callToActionView = ctaButton
        advertiserView = advertiserLabel
        mediaView = media
    }

    func apply(_ ad: NativeAd) {
        headlineLabel.text = ad.headline
        bodyLabel.text = ad.body
        bodyLabel.isHidden = ad.body == nil
        advertiserLabel.text = ad.advertiser
        advertiserLabel.isHidden = ad.advertiser == nil
        iconImageView.image = ad.icon?.image
        iconImageView.isHidden = ad.icon == nil
        ctaButton.setTitle(ad.callToAction ?? "Open", for: .normal)
        ctaButton.isHidden = ad.callToAction == nil
        media.mediaContent = ad.mediaContent
        let hasMedia = ad.mediaContent.hasVideoContent || ad.mediaContent.mainImage != nil
        media.isHidden = !hasMedia
        nativeAd = ad
    }
}
