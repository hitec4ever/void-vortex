import SwiftUI

struct TutorialScreen: View {
    @ObservedObject var engine: GameEngine
    @State private var appeared = false

    var body: some View {
        ZStack {
            VoidStyle.bgPrimary.opacity(0.96)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    Text("HOW TO PLAY")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(5)
                        .foregroundColor(VoidStyle.accentSecond)
                        .padding(.top, 60)
                        .padding(.bottom, 30)

                    // Goal section
                    TutorialSection(title: "Goal", items: [
                        TutorialItem(icon: "circle.circle", color: VoidStyle.textPrimary,
                                     text: "Your ship orbits a black hole. Survive as long as possible to score points."),
                        TutorialItem(icon: "heart.fill", color: VoidStyle.danger,
                                     text: "You start with 3 lives. Losing all lives ends the game.")
                    ])

                    // Controls section
                    TutorialSection(title: "Controls", items: [
                        TutorialItem(icon: "arrow.down.circle", color: VoidStyle.danger,
                                     text: "Tap LEFT side of screen to pull your ship closer to the black hole."),
                        TutorialItem(icon: "arrow.up.circle", color: VoidStyle.success,
                                     text: "Tap RIGHT side of screen to push your ship outward, away from the black hole.")
                    ])

                    // Obstacles section
                    TutorialSection(title: "Obstacles", items: [
                        TutorialItem(icon: "circle.fill", color: Color(red: 0.6, green: 0.45, blue: 0.3),
                                     text: "Asteroids — Rocks pulled in by gravity. Dodge them!"),
                        TutorialItem(icon: "smallcircle.filled.circle", color: VoidStyle.danger,
                                     text: "Orbiters — Glowing energy balls that orbit the black hole."),
                        TutorialItem(icon: "circle.dashed", color: VoidStyle.accent,
                                     text: "Ring Pulses — Expanding rings with a gap. Find the green gap!"),
                        TutorialItem(icon: "magnet", color: VoidStyle.purple,
                                     text: "Magnetic Fields — Purple zones that push or pull you."),
                        TutorialItem(icon: "tornado", color: VoidStyle.shield,
                                     text: "Vortex Zones — Speed up your orbit when you pass through."),
                        TutorialItem(icon: "light.max", color: VoidStyle.danger,
                                     text: "Laser Beams — Rotating beams from the core. Jump over them!")
                    ])

                    // Powerups section
                    TutorialSection(title: "Power-ups", items: [
                        TutorialItem(icon: "diamond.fill", color: VoidStyle.accentSecond,
                                     text: "Points — Collect for bonus score."),
                        TutorialItem(icon: "shield.fill", color: VoidStyle.shield,
                                     text: "Shield — Absorbs one hit from any obstacle."),
                        TutorialItem(icon: "clock.fill", color: VoidStyle.accent,
                                     text: "Slow-Mo — Slows down time for 4 seconds."),
                        TutorialItem(icon: "heart.fill", color: VoidStyle.success,
                                     text: "Extra Life — Gives you an additional life (max 5).")
                    ])

                    // Levels section
                    TutorialSection(title: "Levels", items: [
                        TutorialItem(icon: "arrow.up.right", color: VoidStyle.accent,
                                     text: "Score points to level up! Each level adds new obstacles and power-ups."),
                        TutorialItem(icon: "bolt.fill", color: VoidStyle.textPrimary,
                                     text: "Higher levels = stronger gravity, faster spawns, more chaos!")
                    ])

                    // Back button
                    Button(action: {
                        HapticEngine.light()
                        engine.state = .start
                    }) {
                        VoidStyle.secondaryButton("BACK", width: 200)
                    }
                    .buttonStyle(.arcade)
                    .padding(.top, 30)
                    .padding(.bottom, 60)
                }
                .padding(.horizontal, 28)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}

struct TutorialSection: View {
    let title: String
    let items: [TutorialItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundColor(VoidStyle.textSecondary.opacity(0.5))
                .padding(.bottom, 4)

            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: items[i].icon)
                        .font(.system(size: 16))
                        .foregroundColor(items[i].color)
                        .frame(width: 28, height: 28)

                    Text(items[i].text)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(VoidStyle.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 28)
    }
}

struct TutorialItem {
    let icon: String
    let color: Color
    let text: String
}
