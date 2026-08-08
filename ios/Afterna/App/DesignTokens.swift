import SwiftUI
import UIKit

enum DesignTokens {
    // MARK: Colors
    static let accent = Color(red: 0.18, green: 0.44, blue: 0.41) // eucalyptus
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.14)
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let mist = Color(red: 0.90, green: 0.93, blue: 0.92)
    static let success = Color(red: 0.20, green: 0.55, blue: 0.35)
    static let error = Color(red: 0.75, green: 0.25, blue: 0.22)
    static let textSecondary = Color(red: 0.42, green: 0.45, blue: 0.47)

    // MARK: Typography
    static let displayFont = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let titleFont = Font.system(.title2, design: .serif).weight(.medium)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .default).weight(.medium)

    // MARK: Spacing
    static let spaceXS: CGFloat = 4
    static let spaceS: CGFloat = 8
    static let spaceM: CGFloat = 16
    static let spaceL: CGFloat = 24

    // MARK: Shape
    static let radius: CGFloat = 12
    static let radiusLarge: CGFloat = 16
}

/// Maps raw pipeline statuses ("succeeded", "processing", …) to tester-friendly labels and colors.
enum ConversationStatus {
    static func label(_ raw: String) -> String {
        switch raw {
        case "succeeded", "ready": return "Ready"
        case "draft": return "Draft"
        case "processing", "transcribing", "running": return "Processing…"
        case "uploading": return "Uploading…"
        case "queued": return "Queued"
        case "failed", "dead": return "Failed"
        case "local": return "On device"
        default: return raw.capitalized
        }
    }

    static func color(_ raw: String) -> Color {
        switch raw {
        case "succeeded", "ready": return DesignTokens.success
        case "draft": return DesignTokens.accent
        case "failed", "dead": return DesignTokens.error
        case "local": return DesignTokens.textSecondary
        default: return DesignTokens.accent
        }
    }
}

/// Small colored capsule showing a friendly conversation status.
struct StatusChip: View {
    let statusRaw: String

    var body: some View {
        Text(ConversationStatus.label(statusRaw))
            .font(DesignTokens.captionFont)
            .foregroundStyle(ConversationStatus.color(statusRaw))
            .padding(.horizontal, DesignTokens.spaceS)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(ConversationStatus.color(statusRaw).opacity(0.12))
            )
            .accessibilityLabel("Status: \(ConversationStatus.label(statusRaw))")
    }
}

/// Lightweight haptics wrappers.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

/// Shared paper/mist gradient background used on the marquee screens.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [DesignTokens.paper, DesignTokens.mist],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
