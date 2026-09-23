import SwiftUI

enum Theme {
    static let background = Color(red: 0.043, green: 0.059, blue: 0.055)
    static let surface = Color(red: 0.087, green: 0.106, blue: 0.098)
    static let control = Color(red: 0.145, green: 0.169, blue: 0.157)
    static let foreground = Color(red: 0.93, green: 0.95, blue: 0.93)
    static let secondary = Color(red: 0.59, green: 0.63, blue: 0.60)
    static let accent = Color(red: 0.64, green: 0.94, blue: 0.65)
    static let separator = Color.white.opacity(0.12)

    static func font(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}

struct Rule: View {
    var body: some View { Rectangle().fill(Theme.separator).frame(height: 0.5) }
}

struct RoundButtonStyle: ButtonStyle {
    var emphasized = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.title3, weight: .medium))
            .frame(minWidth: 56, minHeight: 56)
            .foregroundStyle(emphasized ? Theme.background : Theme.foreground)
            .background(emphasized ? Theme.accent : Theme.control, in: Circle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.3)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(.body, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Theme.background)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
    }
}

