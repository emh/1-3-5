import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable {
    case light, dark, system

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

enum Theme {
    static let background = adaptive(light: 0xF6F7F2, dark: 0x0B0F0E)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x161B19)
    static let control = adaptive(light: 0xE3E9E1, dark: 0x252B28)
    static let foreground = adaptive(light: 0x17221A, dark: 0xEDF2ED)
    static let secondary = adaptive(light: 0x586657, dark: 0x96A199)
    static let accent = adaptive(light: 0x27683C, dark: 0xA3F0A6)
    static let separator = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white.withAlphaComponent(0.12) : .black.withAlphaComponent(0.15)
    })
    static let destructive = adaptive(light: 0xB33C35, dark: 0xF2918C)

    // Dynamic UIKit colors also adapt inside the native library editor and its toolbar.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

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
