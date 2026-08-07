import SwiftUI

enum DesignTokens {
    static let accent = Color(red: 0.18, green: 0.44, blue: 0.41) // eucalyptus
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.14)
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.93)
    static let mist = Color(red: 0.90, green: 0.93, blue: 0.92)

    static let displayFont = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let titleFont = Font.system(.title2, design: .serif).weight(.medium)
    static let bodyFont = Font.system(.body, design: .default)
}
