import Foundation
import Observation

/// Local Recording Credits wallet. 1 credit = `rewardMinutes` of capture time (default 10).
@Observable
@MainActor
final class CreditsWallet {
    private let defaults: UserDefaults
    private let rewardMinutes: Int
    private let maxDailyRewards: Int
    private let welcomeCredits: Int

    private(set) var creditBalance: Int = 0
    private(set) var leftoverMinutes: Int = 0
    private(set) var rewardsEarnedToday: Int = 0
    private(set) var lastError: String?

    private var activeUserId: String = "anonymous"

    init(
        defaults: UserDefaults = .standard,
        rewardMinutes: Int = 10,
        maxDailyRewards: Int = 6,
        welcomeCredits: Int = AdMobConfig.welcomeCredits
    ) {
        self.defaults = defaults
        self.rewardMinutes = max(rewardMinutes, 1)
        self.maxDailyRewards = max(maxDailyRewards, 0)
        self.welcomeCredits = max(welcomeCredits, 0)
    }

    var minutesPerCredit: Int { rewardMinutes }

    var availableMinutes: Int {
        creditBalance * rewardMinutes + leftoverMinutes
    }

    var dailyRewardsRemaining: Int {
        max(0, maxDailyRewards - rewardsEarnedToday)
    }

    func bind(userId: String?) {
        let id = (userId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "anonymous"
        activeUserId = id
        load()
        ensureWelcomeGrant()
        refreshDailyCap()
    }

    /// Grant welcome credits once per user (guests + new sign-ups).
    @discardableResult
    func ensureWelcomeGrant() -> Bool {
        let key = welcomeKey
        guard !defaults.bool(forKey: key) else { return false }
        creditBalance += welcomeCredits
        defaults.set(true, forKey: key)
        persist()
        return true
    }

    @discardableResult
    func earnCreditFromRewardedAd() -> Bool {
        refreshDailyCap()
        guard dailyRewardsRemaining > 0 else {
            lastError = "Daily reward limit reached. Come back tomorrow."
            return false
        }
        creditBalance += 1
        rewardsEarnedToday += 1
        defaults.set(rewardsEarnedToday, forKey: rewardsCountKey)
        defaults.set(Self.dayStamp(), forKey: rewardsDayKey)
        lastError = nil
        persist()
        return true
    }

    func canStartRecording() -> Bool {
        availableMinutes > 0
    }

    /// Deduct recording time from leftover minutes, then whole credits.
    func consume(durationMs: Int) {
        guard durationMs > 0 else { return }
        var need = Int(ceil(Double(durationMs) / 60_000.0))
        if need < 1 { need = 1 }

        if leftoverMinutes >= need {
            leftoverMinutes -= need
            persist()
            return
        }

        need -= leftoverMinutes
        leftoverMinutes = 0

        let creditsNeeded = Int(ceil(Double(need) / Double(rewardMinutes)))
        let spend = min(creditBalance, creditsNeeded)
        creditBalance -= spend
        let minutesFromCredits = spend * rewardMinutes
        let leftover = minutesFromCredits - need
        if leftover > 0 {
            leftoverMinutes = leftover
        }
        persist()
    }

    private func load() {
        creditBalance = defaults.integer(forKey: creditsKey)
        leftoverMinutes = defaults.integer(forKey: leftoverKey)
        refreshDailyCap()
    }

    private func persist() {
        defaults.set(creditBalance, forKey: creditsKey)
        defaults.set(leftoverMinutes, forKey: leftoverKey)
    }

    private func refreshDailyCap() {
        let today = Self.dayStamp()
        let storedDay = defaults.string(forKey: rewardsDayKey) ?? ""
        if storedDay != today {
            rewardsEarnedToday = 0
            defaults.set(today, forKey: rewardsDayKey)
            defaults.set(0, forKey: rewardsCountKey)
        } else {
            rewardsEarnedToday = defaults.integer(forKey: rewardsCountKey)
        }
    }

    private var creditsKey: String { "afterna.credits.balance.\(activeUserId)" }
    private var leftoverKey: String { "afterna.credits.leftover.\(activeUserId)" }
    private var welcomeKey: String { "afterna.credits.welcome.\(activeUserId)" }
    private var rewardsDayKey: String { "afterna.credits.rewards.day.\(activeUserId)" }
    private var rewardsCountKey: String { "afterna.credits.rewards.count.\(activeUserId)" }

    private static func dayStamp() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
