import SwiftUI

struct StartScreen: View {
    @ObservedObject var engine: GameEngine
    @Binding var showSettings: Bool

    // Animation states
    @State private var imageOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleScale: Double = 0.92
    @State private var subtitleOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 20
    @State private var accentPulse: Double = 0

    var body: some View {
        ZStack {
            // Full-screen background
            VoidStyle.bgPrimary
                .ignoresSafeArea()

            // Background image
            GeometryReader { geo in
                Image("TitleImage")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .opacity(imageOpacity)

            // Top gradient for title readability
            VStack {
                LinearGradient(
                    colors: [VoidStyle.bgPrimary.opacity(0.85), VoidStyle.bgPrimary.opacity(0.4), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
                Spacer()
            }
            .ignoresSafeArea()

            // Bottom gradient for button readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, VoidStyle.bgPrimary.opacity(0.8), VoidStyle.bgPrimary.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 240)
            }
            .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 100)

                // Title block
                VStack(spacing: 6) {
                    // VOID VORTEX
                    VStack(spacing: 2) {
                        Text("VOID")
                            .font(.system(size: 52, weight: .bold))
                            .tracking(16)
                        Text("VORTEX")
                            .font(.system(size: 52, weight: .bold))
                            .tracking(16)
                    }
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: Color(red: 0.95, green: 0.90, blue: 0.80), location: 0.6),
                                .init(color: VoidStyle.accent.opacity(0.7 + accentPulse * 0.15), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: VoidStyle.accent.opacity(0.15), radius: 20, y: 4)

                    // Decorative divider
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, VoidStyle.accent.opacity(0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 50, height: 1)

                        Circle()
                            .fill(VoidStyle.accent.opacity(0.5))
                            .frame(width: 4, height: 4)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [VoidStyle.accent.opacity(0.4), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 50, height: 1)
                    }
                    .padding(.top, 8)

                    // Subtitle
                    Text("SURVIVE THE PULL")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(6)
                        .foregroundColor(.white)
                        .opacity(subtitleOpacity)
                        .padding(.top, 6)
                }
                .scaleEffect(titleScale)
                .opacity(titleOpacity)

                Spacer()

                // Buttons
                VStack(spacing: 14) {
                    Button(action: {
                        HapticEngine.medium()
                        engine.startGame()
                    }) {
                        VoidStyle.primaryButton("START GAME")
                    }
                    .buttonStyle(.arcade)

                    Button(action: {
                        HapticEngine.light()
                        engine.state = .tutorial
                    }) {
                        VoidStyle.secondaryButton("HOW TO PLAY")
                    }
                    .buttonStyle(.arcade)

                    Button(action: {
                        HapticEngine.light()
                        withAnimation(.easeOut(duration: 0.25)) {
                            showSettings = true
                        }
                    }) {
                        VoidStyle.ghostButton("SETTINGS", width: 200)
                    }
                    .buttonStyle(.arcade)
                }
                .opacity(buttonsOpacity)
                .offset(y: buttonsOffset)

                // High score
                if engine.hiScore > 0 {
                    Text("BEST: \(engine.hiScore.formatted())")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(VoidStyle.accent.opacity(0.4))
                        .padding(.top, 20)
                        .opacity(buttonsOpacity)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            runEntryAnimations()
        }
        .onDisappear {
            resetAnimations()
        }
    }

    private func runEntryAnimations() {
        // Background image
        withAnimation(.easeOut(duration: 0.8)) {
            imageOpacity = 1.0
        }

        // Title scales in with spring
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15)) {
            titleOpacity = 1.0
            titleScale = 1.0
        }

        // Subtitle fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            subtitleOpacity = 1.0
        }

        // Buttons slide up
        withAnimation(.easeOut(duration: 0.5).delay(0.65)) {
            buttonsOpacity = 1.0
            buttonsOffset = 0
        }

        // Slow accent pulse on title gradient
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            accentPulse = 1.0
        }
    }

    private func resetAnimations() {
        imageOpacity = 0
        titleOpacity = 0
        titleScale = 0.92
        subtitleOpacity = 0
        buttonsOpacity = 0
        buttonsOffset = 20
        accentPulse = 0
    }
}
