import SwiftUI

// MARK: - Non-blocking Level Up Banner
// Appears during gameplay without pausing — auto-dismisses after ~3 seconds
struct LevelUpBanner: View {
    @ObservedObject var engine: GameEngine

    @State private var levelScale: CGFloat = 0.3
    @State private var levelOpacity: Double = 0
    @State private var nameOpacity: Double = 0
    @State private var elementOpacity: Double = 0
    @State private var ringExpand: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var fadeOut: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 140)

            ZStack {
                // Expanding ring pulse (behind everything)
                Circle()
                    .stroke(VoidStyle.accentSecond.opacity(0.15), lineWidth: 2)
                    .frame(width: 160, height: 160)
                    .scaleEffect(ringExpand)
                    .opacity(ringOpacity)

                Circle()
                    .stroke(VoidStyle.accentSecond.opacity(0.08), lineWidth: 1)
                    .frame(width: 200, height: 200)
                    .scaleEffect(ringExpand * 0.9)
                    .opacity(ringOpacity * 0.5)

                // Content card – semi-transparent so game is visible
                VStack(spacing: 6) {
                    // "LEVEL" label
                    Text("LEVEL")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(5)
                        .foregroundColor(VoidStyle.accent.opacity(0.8))
                        .opacity(nameOpacity)

                    // Level number – big and bold
                    Text("\(engine.level)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, VoidStyle.accentSecond.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: VoidStyle.accentSecond.opacity(0.5), radius: 20)
                        .scaleEffect(levelScale)
                        .opacity(levelOpacity)

                    // Level name
                    Text(engine.levelUpName)
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundColor(VoidStyle.textPrimary.opacity(0.9))
                        .opacity(nameOpacity)

                    // New element description
                    Text(engine.levelUpElement)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(VoidStyle.textSecondary.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .opacity(elementOpacity)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 32)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(VoidStyle.bgPrimary.opacity(0.65))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(VoidStyle.accentSecond.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .opacity(fadeOut)

            Spacer()
        }
        .onAppear {
            runAnimations()
        }
        .onDisappear {
            resetState()
        }
    }

    private func runAnimations() {
        // Ring expansion
        withAnimation(.easeOut(duration: 0.7)) {
            ringExpand = 1.2
            ringOpacity = 1.0
        }

        // Level number pops in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65).delay(0.05)) {
            levelScale = 1.0
            levelOpacity = 1.0
        }

        // Name + description fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
            nameOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.45)) {
            elementOpacity = 1.0
        }

        // Ring fades
        withAnimation(.easeOut(duration: 1.5).delay(0.6)) {
            ringOpacity = 0.0
        }

        // Entire banner fades out after 2.2s
        withAnimation(.easeOut(duration: 0.8).delay(2.2)) {
            fadeOut = 0.0
        }
    }

    private func resetState() {
        levelScale = 0.3
        levelOpacity = 0
        nameOpacity = 0
        elementOpacity = 0
        ringExpand = 0.5
        ringOpacity = 0
        fadeOut = 1.0
    }
}
