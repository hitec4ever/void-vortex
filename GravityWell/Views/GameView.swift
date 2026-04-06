import SwiftUI
import UIKit

struct GameView: View {
    @ObservedObject var engine: GameEngine
    private let renderer: GameRenderer

    init(engine: GameEngine) {
        self.engine = engine
        self.renderer = GameRenderer(engine: engine)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Game canvas
                Canvas { context, size in
                    renderer.render(context: context, size: size)
                }
                .ignoresSafeArea()
                .onAppear {
                    engine.setCenter(x: geo.size.width / 2, y: geo.size.height / 2)
                    engine.regenerateStarsForSize(width: geo.size.width, height: geo.size.height)
                }

                // Controls (only during gameplay)
                if engine.state == .playing {
                    VStack(spacing: 0) {
                        // Top area - not interactive (game visible)
                        Color.clear
                            .contentShape(Rectangle())
                            .allowsHitTesting(false)

                        // Bottom control zone
                        HStack(spacing: 0) {
                            // Left zone - Pull In
                            CockpitButton(
                                label: "PULL",
                                side: .left,
                                onPress: {
                                    engine.inputIn = true
                                    engine.sound.play(.thrustIn)
                                    HapticEngine.light()
                                },
                                onRelease: {
                                    engine.inputIn = false
                                    engine.sound.stopThrust()
                                }
                            )

                            // Right zone - Push Out
                            CockpitButton(
                                label: "PUSH",
                                side: .right,
                                onPress: {
                                    engine.inputOut = true
                                    engine.sound.play(.thrustOut)
                                    HapticEngine.light()
                                },
                                onRelease: {
                                    engine.inputOut = false
                                    engine.sound.stopThrust()
                                }
                            )
                        }
                        .frame(height: geo.size.height * 0.34)  // Bottom 34% of screen
                    }
                }
            }
        }
    }
}

// MARK: - Button Side
enum ButtonSide {
    case left, right
}

// MARK: - Cockpit Button (spaceship control style)
struct CockpitButton: View {
    let label: String
    let side: ButtonSide
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    // Metal/cockpit colors
    private let metalLight = Color(red: 0.55, green: 0.58, blue: 0.65)
    private let metalMid = Color(red: 0.32, green: 0.34, blue: 0.40)
    private let metalDark = Color(red: 0.16, green: 0.17, blue: 0.22)
    private let metalDeep = Color(red: 0.08, green: 0.09, blue: 0.12)

    // Accent colors for status ring
    private let accentOrange = Color(red: 0.96, green: 0.62, blue: 0.04)

    private let buttonSize: CGFloat = 82

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .overlay {
                VStack(spacing: 8) {
                    Spacer()
                        .frame(height: 4)

                    // ── Cockpit Button ──
                    ZStack {
                        // Ambient glow rim (always visible, intensifies on press)
                        Circle()
                            .fill(accentOrange.opacity(isPressed ? 0.18 : 0.04))
                            .frame(width: buttonSize + 28, height: buttonSize + 28)
                            .blur(radius: 14)

                        // Drop shadow
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: buttonSize, height: buttonSize)
                            .offset(y: isPressed ? 1 : 3)
                            .blur(radius: isPressed ? 4 : 6)

                        // Outer housing ring (dark metal bezel)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [metalDark, metalDeep],
                                    center: .center,
                                    startRadius: buttonSize * 0.3,
                                    endRadius: buttonSize * 0.5
                                )
                            )
                            .frame(width: buttonSize, height: buttonSize)

                        // Status ring (orange accent — soft glow idle, bright on press)
                        Circle()
                            .stroke(
                                accentOrange.opacity(isPressed ? 0.75 : 0.25),
                                lineWidth: isPressed ? 2.0 : 1.5
                            )
                            .frame(width: buttonSize - 5, height: buttonSize - 5)
                        // Soft glow around status ring
                        Circle()
                            .stroke(
                                accentOrange.opacity(isPressed ? 0.2 : 0.06),
                                lineWidth: 4
                            )
                            .frame(width: buttonSize - 5, height: buttonSize - 5)
                            .blur(radius: 3)

                        // Button face — brushed metal with inner lighting
                        Circle()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: isPressed ? metalMid : metalLight, location: 0),
                                        .init(color: metalMid, location: 0.35),
                                        .init(color: isPressed ? metalDeep : metalDark, location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: buttonSize - 12, height: buttonSize - 12)

                        // Concentric rings (brushed metal texture)
                        ForEach(0..<3, id: \.self) { ring in
                            Circle()
                                .stroke(
                                    Color.white.opacity(isPressed ? 0.03 : 0.06),
                                    lineWidth: 0.5
                                )
                                .frame(
                                    width: buttonSize - 20 - CGFloat(ring) * 12,
                                    height: buttonSize - 20 - CGFloat(ring) * 12
                                )
                        }

                        // Top highlight (convex metal reflection)
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(isPressed ? 0.08 : 0.22), location: 0),
                                        .init(color: .white.opacity(0.0), location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(width: buttonSize * 0.55, height: buttonSize * 0.3)
                            .offset(y: -buttonSize * 0.15)

                        // Center dimple (joystick concave feel)
                        Circle()
                            .fill(
                                RadialGradient(
                                    stops: [
                                        .init(color: metalDeep.opacity(isPressed ? 0.8 : 0.4), location: 0),
                                        .init(color: .clear, location: 1)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: buttonSize * 0.18
                                )
                            )
                            .frame(width: buttonSize * 0.36, height: buttonSize * 0.36)

                        // Center dot (small indicator — always has subtle glow)
                        Circle()
                            .fill(accentOrange.opacity(isPressed ? 0.95 : 0.4))
                            .frame(width: 6, height: 6)
                            .shadow(color: accentOrange.opacity(isPressed ? 0.7 : 0.15), radius: isPressed ? 8 : 4)

                        // Outer bezel rim highlight
                        Circle()
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.12), location: 0),
                                        .init(color: .white.opacity(0.0), location: 0.35),
                                        .init(color: .black.opacity(0.2), location: 1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .frame(width: buttonSize - 1, height: buttonSize - 1)
                    }
                    .scaleEffect(isPressed ? 0.97 : 1.0)
                    .offset(y: isPressed ? 1 : 0)
                    .animation(.easeOut(duration: 0.05), value: isPressed)

                    // Subtle label
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(.white.opacity(isPressed ? 0.45 : 0.22))

                    Spacer()
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
                    }
            )
    }
}

// MARK: - Haptic Engine
struct HapticEngine {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)

    static func light() {
        guard GameSettings.shared.hapticsEnabled else { return }
        lightGenerator.impactOccurred()
    }
    static func medium() {
        guard GameSettings.shared.hapticsEnabled else { return }
        mediumGenerator.impactOccurred()
    }
    static func heavy() {
        guard GameSettings.shared.hapticsEnabled else { return }
        heavyGenerator.impactOccurred()
    }

    /// Always fires — used by settings toggle to give feedback when enabling vibration
    static func forceLight() {
        lightGenerator.impactOccurred()
    }
}
