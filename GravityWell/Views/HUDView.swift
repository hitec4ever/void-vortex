import SwiftUI

struct HUDView: View {
    @ObservedObject var engine: GameEngine

    // Lives animation
    @State private var livesShake: CGFloat = 0
    @State private var heartScales: [CGFloat] = Array(repeating: 1.0, count: 5)
    @State private var lostLifeIndex: Int? = nil
    @State private var blinkOpacity: Double = 1.0

    // Score punch (only for discrete reward events, not per-frame drip)
    @State private var scorePunch: CGFloat = 1.0
    @State private var scoreGlow: Double = 0
    @State private var scoreBright: Double = 0

    // Damage disruption (single-direction displacement + power dip, no oscillation)
    @State private var glitchOffset: CGFloat = 0
    @State private var glitchDim: Double = 0

    // Near-miss glow flare
    @State private var nearMissGlow: Double = 0

    private let hudColor = VoidStyle.accentSecond  // #4DA3FF

    // MARK: - HUD Liveliness (glow-only breathing — text stays rock-solid)

    /// Slow glow radius fluctuation (~6s cycle). Only affects shadow spread, never text.
    private var glowBreathe: CGFloat {
        let phase = Double(engine.pulsePhase)
        // Two layered sines to avoid obvious periodicity
        let a = sin(phase * 1.05)            // ~6.0s cycle
        let b = sin(phase * 0.73 + 2.1)      // ~8.6s cycle
        return CGFloat(a * 0.6 + b * 0.4)    // -1…1 blended
    }

    /// Glow opacity micro-fluctuation. Shadow intensity only.
    /// Base: ±2.5%. Under proximity stress: amplitude scales up via proxBreatheLift.
    private var glowBreatheFactor: Double {
        1.0 + Double(glowBreathe) * 0.025 * proxBreatheLift
    }

    /// Opacity micro-breathing for secondary HUD elements. Range: 0.92–1.0.
    /// Phase-offset from glow breathing to avoid visible correlation between the two.
    private var opacityBreathe: Double {
        let phase = Double(engine.pulsePhase)
        let a = sin(phase * 0.82 + 1.4)        // ~7.7s cycle
        let b = sin(phase * 1.13 + 3.8)        // ~5.6s cycle
        let blend = a * 0.55 + b * 0.45        // -1…1
        return 0.96 + blend * 0.04             // 0.92…1.0
    }

    // MARK: - Proximity Reactions (gravitational stress — no motion, only glow depth)

    /// Proximity danger (0=safe, 1=at event horizon)
    private var prox: CGFloat {
        engine.proximityFactor
    }

    /// EaseOut-quadratic proximity curve: early onset, smooth plateau near critical.
    /// p=0→0, p=0.5→0.75, p=1→1. No sudden jumps near event horizon.
    private var proxCurve: CGFloat {
        prox * (2.0 - prox)
    }

    /// Proximity deepens glow — shadow becomes denser. EaseOut ramp.
    private var proxGlow: Double {
        Double(proxCurve) * 0.06
    }

    /// Proximity widens glow radius — gravitational lensing feel on shadow spread.
    private var proxGlowRadius: CGFloat {
        proxCurve * 4  // 0→4px, smooth plateau near critical
    }

    /// Proximity amplifies the existing breathing — glow fluctuations become more
    /// pronounced under gravitational stress. No new animation, just the same breathing
    /// feels "strained". At safe distance ×1.0, at event horizon ×2.2.
    private var proxBreatheLift: Double {
        1.0 + Double(proxCurve) * 1.2
    }

    /// Proximity causes very subtle opacity dimming — gravitational strain on the display.
    /// Range: 1.0 (safe) → 0.95 (event horizon). EaseOut ramp, smooth continuous.
    private var proxOpacity: Double {
        1.0 - Double(proxCurve) * 0.05
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top bar ──
            HStack(alignment: .top) {
                // Score (left) — dominant, high contrast
                VStack(alignment: .leading, spacing: 3) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(4)
                        .foregroundColor(hudColor.opacity(0.5))
                        .opacity(opacityBreathe * proxOpacity)

                    Text(engine.score.formatted())
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .brightness(scoreBright)
                        .shadow(color: hudColor.opacity((0.12 + proxGlow + scoreGlow + nearMissGlow) * glowBreatheFactor), radius: 6 + glowBreathe * 1.5 + CGFloat(scoreGlow) * 6 + CGFloat(nearMissGlow) * 4 + proxGlowRadius, y: 0)
                        .scaleEffect(scorePunch)
                        .contentTransition(.numericText())
                        .animation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.12), value: engine.score)
                }

                Spacer()

                // Level + Time (right) — informational, secondary
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 3) {
                        Text("LVL")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(hudColor.opacity(0.5))
                        Text("\(engine.level)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .shadow(color: hudColor.opacity(0.05 * glowBreatheFactor), radius: 3 + glowBreathe * 0.4, y: 0)

                    Text(engine.formattedTime)
                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: hudColor.opacity((0.08 + proxGlow) * glowBreatheFactor), radius: 4 + glowBreathe * 1.0 + proxGlowRadius * 0.6, y: 0)
                }
                .opacity(opacityBreathe * proxOpacity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 54)
            .offset(x: glitchOffset)

            // Hi-score indicator (subtle, only when close)
            if engine.score > 0 && engine.score > engine.hiScore - 200 && engine.hiScore > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 8))
                        .foregroundColor(hudColor.opacity(0.4))
                    Text("HI")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(hudColor.opacity(0.35))
                    Text(engine.hiScore.formatted())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
            }

            // ── Shield duration bar (above play field) ──
            if engine.player.shielded {
                ShieldBar(
                    remaining: engine.player.shieldTimer,
                    total: GameSettings.shared.difficulty.shieldDuration,
                    barColor: VoidStyle.shield,
                    hudColor: hudColor
                )
                .padding(.horizontal, 50)
                .padding(.top, 10)
                .shadow(color: VoidStyle.shield.opacity(0.06 * glowBreatheFactor), radius: 4 + glowBreathe * 0.5, y: 0)
                .opacity(opacityBreathe * proxOpacity)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }

            Spacer()

            // ── Bottom info bar ──
            VStack(spacing: 6) {
                // Status indicators
                HStack(spacing: 12) {
                    if engine.slowmoActive {
                        StatusBadge(
                            icon: "clock.fill",
                            text: "SLOW",
                            color: hudColor
                        )
                    }
                }

                // Lives – mini spaceships with glow presence
                HStack(spacing: 8) {
                    ForEach(0..<GameConstants.startLives, id: \.self) { i in
                        let isFilled = i < engine.lives
                        let isBlinking = lostLifeIndex == i

                        ShipLifeIcon(active: isFilled || isBlinking)
                            .scaleEffect(heartScales[i])
                            .opacity(isBlinking ? blinkOpacity : 1.0)
                            // Glow behind active ships — breathes through blur radius only
                            .background(
                                isFilled ?
                                Circle()
                                    .fill(hudColor.opacity((0.12 + proxGlow + nearMissGlow * 0.5) * glowBreatheFactor))
                                    .frame(width: 22, height: 22)
                                    .blur(radius: 6 + glowBreathe * 0.8)
                                : nil
                            )
                    }
                }
                .offset(x: livesShake)

                // Pause button – HUD element with presence
                if engine.state == .playing {
                    Button(action: {
                        engine.togglePause()
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(hudColor.opacity(0.7))
                            .frame(width: 48, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.9), location: 0),
                                                .init(color: Color(red: 0.03, green: 0.04, blue: 0.09).opacity(0.9), location: 1)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(hudColor.opacity(0.12), lineWidth: 0.8)
                            )
                            .shadow(color: hudColor.opacity((0.06 + proxGlow * 0.4) * glowBreatheFactor), radius: 6 + glowBreathe * 0.5 + proxGlowRadius * 0.3, y: 1)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)
            .offset(x: glitchOffset * 0.6)
        }
        .brightness(glitchDim)
        .allowsHitTesting(engine.state == .playing)
        .animation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.2), value: engine.player.shielded)
        .onChange(of: engine.lifeLostTrigger) { _, _ in
            triggerLifeLostAnimation()
            triggerDamageGlitch()
        }
        .onChange(of: engine.score) { oldVal, newVal in
            // Only punch on discrete reward events (pickups ≥5, not per-frame drip +1/+2)
            if newVal - oldVal >= 5 {
                triggerScorePunch()
            }
        }
        .onChange(of: engine.nearMissTrigger) { _, _ in
            triggerNearMiss()
        }
    }

    // MARK: - Near Miss FX
    private func triggerNearMiss() {
        // Brief glow flare — tension tick, not celebration.
        guard nearMissGlow == 0 else { return }

        // Spike — fast easeOut snap (30ms)
        withAnimation(.easeOut(duration: 0.03)) {
            nearMissGlow = 0.10
        }

        // Decay — controlled return (100ms). Total: ~135ms.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.035) {
            withAnimation(.easeOut(duration: 0.10)) {
                nearMissGlow = 0
            }
        }
    }

    // MARK: - Score Punch FX
    private func triggerScorePunch() {
        // Skip if a punch is still in progress
        guard scorePunch == 1.0 else { return }

        // Attack — snappy custom bezier (60ms). Front-loaded velocity, sharp deceleration.
        withAnimation(.timingCurve(0.12, 0.82, 0.3, 1.0, duration: 0.06)) {
            scorePunch = 1.03
            scoreGlow = 0.08
            scoreBright = 0.05
        }

        // Settle — controlled return (100ms). Smooth deceleration, no bounce. Total: 160ms.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.10)) {
                scorePunch = 1.0
                scoreGlow = 0
                scoreBright = 0
            }
        }
    }

    // MARK: - Damage Disruption FX
    private func triggerDamageGlitch() {
        // Single-direction system disruption: displacement + power dip → recovery
        // No oscillation, no random jitter — clean and controlled.

        // Impact — easeIn builds tension then snaps to displaced state (60ms)
        withAnimation(.easeIn(duration: 0.06)) {
            glitchOffset = 2.0
            glitchDim = -0.04
        }

        // Recovery — smooth easeOut stabilization, both channels together (180ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            withAnimation(.easeOut(duration: 0.18)) {
                glitchOffset = 0
                glitchDim = 0
            }
        }
    }

    // MARK: - Life Lost Animation
    private func triggerLifeLostAnimation() {
        let lostIndex = engine.lives

        // Single displacement + smooth return (not a back-and-forth shake)
        withAnimation(.easeIn(duration: 0.05)) {
            livesShake = -4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.18)) {
                livesShake = 0
            }
        }

        // Blink the lost life icon 4 times, then disappear
        if lostIndex >= 0 && lostIndex < heartScales.count {
            blinkOpacity = 1.0
            lostLifeIndex = lostIndex

            // Controlled scale punch — tight, no bounce
            withAnimation(.easeIn(duration: 0.05)) {
                heartScales[lostIndex] = 1.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.easeOut(duration: 0.12)) {
                    heartScales[lostIndex] = 1.0
                }
            }

            // 4 fast blinks then gone
            let blinkInterval = 0.07
            for blink in 0..<4 {
                let offTime = 0.12 + Double(blink) * (blinkInterval * 2)
                let onTime = offTime + blinkInterval

                DispatchQueue.main.asyncAfter(deadline: .now() + offTime) {
                    withAnimation(.linear(duration: 0.03)) { blinkOpacity = 0.0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + onTime) {
                    withAnimation(.linear(duration: 0.03)) { blinkOpacity = 1.0 }
                }
            }

            // Final disappear after blinks complete
            let totalBlinkTime = 0.12 + Double(4) * (blinkInterval * 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + totalBlinkTime) {
                withAnimation(.easeOut(duration: 0.1)) { blinkOpacity = 0.0 }
            }

            // Clear blinking state
            DispatchQueue.main.asyncAfter(deadline: .now() + totalBlinkTime + 0.2) {
                lostLifeIndex = nil
                blinkOpacity = 1.0
            }
        }
    }
}

// MARK: - Shield Duration Bar
struct ShieldBar: View {
    let remaining: CGFloat
    let total: CGFloat
    let barColor: Color
    let hudColor: Color

    private var fraction: CGFloat {
        max(0, min(1, remaining / total))
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 9))
                    .foregroundColor(hudColor.opacity(0.5))

                Text("SHIELD")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(hudColor.opacity(0.45))

                Spacer()

                Text(String(format: "%.1fs", remaining))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(.white.opacity(fraction < 0.3 ? 0.9 : 0.7))
            }

            // Bar track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(barColor.opacity(0.08))

                    // Fill bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    fraction < 0.3 ? VoidStyle.danger : barColor,
                                    fraction < 0.3 ? VoidStyle.danger.opacity(0.6) : barColor.opacity(0.5)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fraction)
                        .animation(.linear(duration: 0.1), value: fraction)

                    // Soft glow on fill edge
                    if fraction > 0.05 {
                        Capsule()
                            .fill(barColor.opacity(fraction < 0.3 ? 0.0 : 0.12))
                            .frame(width: geo.size.width * fraction, height: 2)
                            .offset(y: -1)
                    }
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Ship Life Icon (mini spaceship silhouette)
struct ShipLifeIcon: View {
    let active: Bool

    private let shipColor = Color(red: 0.75, green: 0.82, blue: 1.0)
    private let engineGlow = VoidStyle.accentSecond

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2

            if active {
                // Engine glow (small soft circle at bottom)
                let glowRect = CGRect(x: cx - 3, y: cy + 3, width: 6, height: 4)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .color(engineGlow.opacity(0.5))
                )

                // Ship body – top-down triangular silhouette
                var ship = Path()
                ship.move(to: CGPoint(x: cx, y: cy - 7))       // nose
                ship.addLine(to: CGPoint(x: cx - 3, y: cy + 1))  // left wing root
                ship.addLine(to: CGPoint(x: cx - 6, y: cy + 5))  // left wing tip
                ship.addLine(to: CGPoint(x: cx - 2.5, y: cy + 3))// left wing inner
                ship.addLine(to: CGPoint(x: cx - 1.5, y: cy + 6))// left exhaust
                ship.addLine(to: CGPoint(x: cx + 1.5, y: cy + 6))// right exhaust
                ship.addLine(to: CGPoint(x: cx + 2.5, y: cy + 3))// right wing inner
                ship.addLine(to: CGPoint(x: cx + 6, y: cy + 5))  // right wing tip
                ship.addLine(to: CGPoint(x: cx + 3, y: cy + 1))  // right wing root
                ship.closeSubpath()

                // Fill ship
                context.fill(ship, with: .color(shipColor))

                // Cockpit highlight (small dot near nose)
                let cockpitRect = CGRect(x: cx - 1.2, y: cy - 4, width: 2.4, height: 2.4)
                context.fill(
                    Path(ellipseIn: cockpitRect),
                    with: .color(.white.opacity(0.7))
                )
            } else {
                // Ghost ship – faint outline only
                var ship = Path()
                ship.move(to: CGPoint(x: cx, y: cy - 7))
                ship.addLine(to: CGPoint(x: cx - 3, y: cy + 1))
                ship.addLine(to: CGPoint(x: cx - 6, y: cy + 5))
                ship.addLine(to: CGPoint(x: cx - 2.5, y: cy + 3))
                ship.addLine(to: CGPoint(x: cx - 1.5, y: cy + 6))
                ship.addLine(to: CGPoint(x: cx + 1.5, y: cy + 6))
                ship.addLine(to: CGPoint(x: cx + 2.5, y: cy + 3))
                ship.addLine(to: CGPoint(x: cx + 6, y: cy + 5))
                ship.addLine(to: CGPoint(x: cx + 3, y: cy + 1))
                ship.closeSubpath()

                context.stroke(ship, with: .color(.white.opacity(0.12)), lineWidth: 0.8)
            }
        }
        .frame(width: 18, height: 18)
    }
}

// MARK: - Status Badge (SLOW indicator)
struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color

    @State private var pulse: Double = 0.85

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 8, weight: .semibold))
                .tracking(3)
        }
        .foregroundColor(color.opacity(0.8))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.06))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.15), lineWidth: 0.6)
                )
        )
        .shadow(color: color.opacity(0.08), radius: 4, y: 0)
        .opacity(pulse)
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: true)) {
                pulse = 1.0
            }
        }
    }
}
