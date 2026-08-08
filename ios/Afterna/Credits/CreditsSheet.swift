import SwiftUI

struct CreditsSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Recording Credits")
                    .font(DesignTokens.displayFont)
                    .foregroundStyle(DesignTokens.ink)

                Text("1 credit = \(container.credits.minutesPerCredit) minutes of capture time. New accounts start with \(AdMobConfig.welcomeCredits) free credits.")
                    .font(DesignTokens.bodyFont)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Credits", value: "\(container.credits.creditBalance)")
                    LabeledContent("Time left", value: "\(container.credits.availableMinutes) min")
                    LabeledContent("Rewards left today", value: "\(container.credits.dailyRewardsRemaining)")
                }
                .font(.body.weight(.medium))

                Button {
                    Task { await watchAd() }
                } label: {
                    Text(busy ? "Loading ad…" : "Watch ad for +1 credit")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DesignTokens.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(busy || container.credits.dailyRewardsRemaining == 0)

                if container.credits.dailyRewardsRemaining == 0 {
                    Label(
                        "You've reached today's reward limit — more ads unlock tomorrow.",
                        systemImage: "clock"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let err = container.credits.lastError, !err.isEmpty {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func watchAd() async {
        busy = true
        message = nil
        defer { busy = false }

        await RewardedAdManager.shared.loadAd()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            RewardedAdManager.shared.show { earned in
                if earned {
                    if container.credits.earnCreditFromRewardedAd() {
                        message = "You earned 1 credit."
                    }
                } else {
                    message = "Ad wasn’t completed — no credit granted."
                }
                cont.resume()
            }
        }
    }
}
