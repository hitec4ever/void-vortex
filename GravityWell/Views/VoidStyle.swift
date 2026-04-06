import SwiftUI

/// Void Vortex — Design System Constants
enum VoidStyle {
    // MARK: - Colors
    static let bgPrimary     = Color(red: 0.020, green: 0.027, blue: 0.059)  // #05070F
    static let accent        = Color(red: 0.961, green: 0.651, blue: 0.137)  // #F5A623
    static let accentSecond  = Color(red: 0.302, green: 0.639, blue: 1.000)  // #4DA3FF
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.85)

    // Derived accent shades
    static let accentDark    = Color(red: 0.82, green: 0.50, blue: 0.06)
    static let accentGlow    = Color(red: 0.96, green: 0.70, blue: 0.20)

    // Gameplay colors (unchanged — tied to game mechanics)
    static let danger        = Color(red: 0.94, green: 0.27, blue: 0.27)
    static let success       = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let shield        = Color(red: 0.02, green: 0.71, blue: 0.83)
    static let gold          = Color(red: 1.0,  green: 0.82, blue: 0.15)
    static let purple        = Color(red: 0.58, green: 0.30, blue: 0.86)

    // Panels
    static let panelBg       = Color(red: 0.04, green: 0.05, blue: 0.09).opacity(0.85)
    static let panelBorder   = Color.white.opacity(0.07)

    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.98, green: 0.72, blue: 0.18), location: 0),
            .init(color: Color(red: 0.96, green: 0.60, blue: 0.12), location: 0.5),
            .init(color: Color(red: 0.82, green: 0.44, blue: 0.06), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let secondaryGradient = LinearGradient(
        stops: [
            .init(color: accentSecond.opacity(0.15), location: 0),
            .init(color: accentSecond.opacity(0.05), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Button Styles
    static func primaryButton(_ label: String, width: CGFloat = 240) -> some View {
        Text(label)
            .font(.system(size: 17, weight: .bold, design: .default))
            .tracking(2.5)
            .textCase(.uppercase)
            .foregroundColor(.white)
            .frame(width: width)
            .padding(.vertical, 16)
            .background(primaryGradient)
            .cornerRadius(12)
            .shadow(color: accent.opacity(0.35), radius: 14, y: 2)
    }

    static func secondaryButton(_ label: String, width: CGFloat = 240) -> some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundColor(.white.opacity(0.9))
            .frame(width: width)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accentSecond.opacity(0.4), lineWidth: 1.2)
                    .background(accentSecond.opacity(0.06).cornerRadius(12))
            )
            .cornerRadius(12)
    }

    static func ghostButton(_ label: String, width: CGFloat = 240) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .medium))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundColor(.white.opacity(0.5))
            .frame(width: width)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
            )
            .cornerRadius(12)
    }
}

// MARK: - Button press animation modifier
struct ArcadePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ArcadePress {
    static var arcade: ArcadePress { ArcadePress() }
}
