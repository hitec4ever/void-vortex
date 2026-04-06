import SwiftUI

struct GameOverScreen: View {
    @ObservedObject var engine: GameEngine

    // MARK: - Animation states
    @State private var imageOpacity: Double = 0
    @State private var gameOverScale: Double = 0.5
    @State private var gameOverOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var statsOffset: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var buttonScale: Double = 0.8
    @State private var buttonGlowPulse: Double = 0
    @State private var tapHintOpacity: Double = 0
    @State private var highScoreBannerScale: Double = 0
    @State private var highScoreBannerOpacity: Double = 0
    @State private var canTapToRestart: Bool = false
    @State private var gameOverDrop: CGFloat = -30

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Background ──
                VoidStyle.bgPrimary.ignoresSafeArea()

                // Background image – dimmed
                Image("GameOverImage")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .opacity(imageOpacity * 0.75)

                // Dark overlay for legibility
                VoidStyle.bgPrimary.opacity(0.35).ignoresSafeArea()
                    .opacity(imageOpacity)

                // Top gradient
                VStack {
                    LinearGradient(
                        colors: [VoidStyle.bgPrimary.opacity(0.8), VoidStyle.bgPrimary.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                    Spacer()
                }
                .ignoresSafeArea()

                // Bottom gradient
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, VoidStyle.bgPrimary.opacity(0.7), VoidStyle.bgPrimary.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 260)
                }
                .ignoresSafeArea()

                // ── Content ──
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geo.size.height * 0.25)

                    // ── 1. GAME OVER ──
                    ZStack {
                        Text("GAME OVER")
                            .font(.system(size: 40, weight: .black))
                            .tracking(4)
                            .foregroundColor(VoidStyle.danger)
                            .blur(radius: 20)
                            .opacity(gameOverOpacity * 0.35)

                        Text("GAME OVER")
                            .font(.system(size: 40, weight: .black))
                            .tracking(4)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(red: 0.90, green: 0.90, blue: 0.94)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .black, radius: 6, x: 0, y: 3)
                            .shadow(color: VoidStyle.danger.opacity(0.2), radius: 20)
                    }
                    .scaleEffect(gameOverScale)
                    .opacity(gameOverOpacity)
                    .offset(y: gameOverDrop)

                    // ── 2. Mission Failed ──
                    Text("MISSION FAILED")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(5)
                        .foregroundColor(VoidStyle.danger.opacity(0.6))
                        .opacity(subtitleOpacity)
                        .padding(.top, 6)

                    // ── 3. NEW HIGH SCORE banner ──
                    if engine.isNewHighScore {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                            Text("NEW HIGH SCORE")
                                .font(.system(size: 12, weight: .bold))
                                .tracking(3)
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(VoidStyle.gold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(VoidStyle.gold.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(VoidStyle.gold.opacity(0.4), lineWidth: 1)
                                )
                        )
                        .scaleEffect(highScoreBannerScale)
                        .opacity(highScoreBannerOpacity)
                        .padding(.top, 12)
                    }

                    // ── Push everything below to bottom ──
                    Spacer()

                    // ── 4. Stats panel — compact, above buttons ──
                    VStack(spacing: 0) {
                        StatRow(
                            label: "SCORE",
                            value: engine.score.formatted(),
                            isHighlight: true,
                            accentColor: VoidStyle.accent,
                            isBest: engine.isNewHighScore,
                            bestLabel: "HIGH SCORE",
                            currentRaw: CGFloat(engine.score),
                            previousRaw: CGFloat(engine.previousScore)
                        )

                        Divider().background(Color.white.opacity(0.06))

                        StatRow(
                            label: "TIME",
                            value: engine.formattedTime,
                            isHighlight: false,
                            accentColor: VoidStyle.textPrimary,
                            isBest: engine.isNewTimeBest,
                            bestLabel: "PERSONAL BEST",
                            currentRaw: engine.gameTime,
                            previousRaw: engine.previousTime
                        )

                        Divider().background(Color.white.opacity(0.06))

                        StatRow(
                            label: "LEVEL",
                            value: "\(engine.level)",
                            isHighlight: false,
                            accentColor: VoidStyle.textPrimary,
                            isBest: false,
                            bestLabel: nil,
                            currentRaw: CGFloat(engine.level),
                            previousRaw: CGFloat(engine.previousLevel)
                        )
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(VoidStyle.panelBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(VoidStyle.panelBorder, lineWidth: 1)
                            )
                    )
                    .opacity(statsOpacity)
                    .offset(y: statsOffset)
                    .padding(.horizontal, 28)

                    // Best records
                    HStack(spacing: 20) {
                        HStack(spacing: 5) {
                            Text("BEST:")
                                .foregroundColor(.white.opacity(0.4))
                            Text(engine.hiScore.formatted())
                                .foregroundColor(VoidStyle.accent.opacity(0.9))
                                .fontWeight(.semibold)
                        }
                        HStack(spacing: 5) {
                            Text("TIME:")
                                .foregroundColor(.white.opacity(0.4))
                            Text(engine.formattedBestTime)
                                .foregroundColor(.white.opacity(0.7))
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.system(size: 12))
                    .tracking(1)
                    .opacity(statsOpacity)
                    .padding(.top, 10)
                    .padding(.bottom, 20)

                    // ── 5. TRY AGAIN button ──
                    Button(action: {
                        restartGame()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(VoidStyle.accent.opacity(0.2))
                                .frame(width: 260, height: 58)
                                .blur(radius: 12)
                                .scaleEffect(1.0 + buttonGlowPulse * 0.08)

                            VoidStyle.primaryButton("TRY AGAIN", width: 260)
                                .shadow(color: VoidStyle.accent.opacity(0.5), radius: 16 + buttonGlowPulse * 4)
                        }
                    }
                    .buttonStyle(.arcade)
                    .scaleEffect(buttonScale)
                    .opacity(buttonOpacity)

                    // ── 6. Main Menu button ──
                    Button(action: {
                        engine.goToMainMenu()
                    }) {
                        VoidStyle.ghostButton("MAIN MENU", width: 260)
                    }
                    .buttonStyle(.arcade)
                    .opacity(buttonOpacity)
                    .padding(.top, 8)

                    // ── 7. Tap hint ──
                    Text("TAP ANYWHERE TO RETRY")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.3))
                        .opacity(tapHintOpacity)
                        .padding(.top, 8)

                    Spacer()
                        .frame(height: geo.safeAreaInsets.bottom + 24)
                }
            }
            // ── Tap anywhere to restart ──
            .contentShape(Rectangle())
            .onTapGesture {
                if canTapToRestart {
                    restartGame()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            runEntryAnimations()
        }
        .onDisappear {
            resetAnimations()
        }
    }

    // MARK: - Restart
    private func restartGame() {
        HapticEngine.medium()
        engine.startGame()
    }

    // MARK: - Animations
    private func runEntryAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            imageOpacity = 1.0
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.15)) {
            gameOverScale = 1.0
            gameOverOpacity = 1.0
            gameOverDrop = 0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            subtitleOpacity = 1.0
        }

        if engine.isNewHighScore {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65).delay(0.7)) {
                highScoreBannerScale = 1.0
                highScoreBannerOpacity = 1.0
            }
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
            statsOpacity = 1.0
            statsOffset = 0
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(1.1)) {
            buttonOpacity = 1.0
            buttonScale = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                buttonGlowPulse = 1.0
            }
        }

        withAnimation(.easeOut(duration: 0.4).delay(1.6)) {
            tapHintOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            canTapToRestart = true
        }
    }

    private func resetAnimations() {
        imageOpacity = 0
        gameOverScale = 0.5
        gameOverOpacity = 0
        subtitleOpacity = 0
        statsOpacity = 0
        statsOffset = 20
        buttonOpacity = 0
        buttonScale = 0.8
        buttonGlowPulse = 0
        tapHintOpacity = 0
        highScoreBannerScale = 0
        highScoreBannerOpacity = 0
        canTapToRestart = false
        gameOverDrop = -30
    }
}

// MARK: - Compact Stat Row (always single-line, never tall)
struct StatRow: View {
    let label: String
    let value: String
    let isHighlight: Bool
    let accentColor: Color
    let isBest: Bool
    let bestLabel: String?
    let currentRaw: CGFloat
    let previousRaw: CGFloat

    private var isImproved: Bool { currentRaw > previousRaw && previousRaw > 0 }
    private var isDeclined: Bool { currentRaw < previousRaw && previousRaw > 0 }
    private var delta: CGFloat {
        guard previousRaw > 0 else { return 0 }
        return ((currentRaw - previousRaw) / previousRaw) * 100
    }

    var body: some View {
        HStack(spacing: 0) {
            // Label column
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2.5)
                    .foregroundColor(.white.opacity(0.35))

                if isBest, let bestLabel = bestLabel {
                    Text(bestLabel)
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(VoidStyle.gold)
                }
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            // Value — prominent
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(isHighlight ? accentColor : .white)

            Spacer()

            // Delta
            if previousRaw > 0 {
                HStack(spacing: 3) {
                    if isImproved {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                        Text("+\(Int(abs(delta)))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    } else if isDeclined {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(Int(abs(delta)))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    } else {
                        Text("=")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .foregroundColor(
                    isImproved ? VoidStyle.success :
                    isDeclined ? VoidStyle.danger :
                    .white.opacity(0.3)
                )
                .frame(width: 60, alignment: .trailing)
            } else {
                Color.clear.frame(width: 60)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }
}
