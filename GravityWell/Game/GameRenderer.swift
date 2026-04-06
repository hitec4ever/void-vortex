import SwiftUI

struct GameRenderer {
    let engine: GameEngine

    func render(context: GraphicsContext, size: CGSize) {
        let cx = engine.centerX
        let cy = engine.centerY
        let pulse = engine.pulsePhase

        // Deep space background gradient
        let bgCenter = CGPoint(x: cx, y: cy)
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.04, green: 0.04, blue: 0.12), location: 0),
                    .init(color: Color(red: 0.024, green: 0.024, blue: 0.07), location: 0.5),
                    .init(color: Color(red: 0.012, green: 0.012, blue: 0.03), location: 1)
                ]),
                center: bgCenter, startRadius: 0, endRadius: 400
            )
        )

        // Starfield (with gravitational lensing near black hole)
        drawStars(context: context, pulse: pulse, cx: cx, cy: cy)

        // Screen shake transform
        var shakeContext = context
        if engine.screenShake > 0 {
            let sx = CGFloat.random(in: -1...1) * engine.screenShake * 14
            let sy = CGFloat.random(in: -1...1) * engine.screenShake * 14
            shakeContext = context
            shakeContext.translateBy(x: sx, y: sy)
        }

        // Orbital guide rings
        drawGuideRings(context: shakeContext, cx: cx, cy: cy)

        // Black hole
        drawBlackHole(context: shakeContext, cx: cx, cy: cy, pulse: pulse)

        // Obstacles
        drawObstacles(context: shakeContext, cx: cx, cy: cy, pulse: pulse)

        // Powerups
        drawPowerups(context: shakeContext, cx: cx, cy: cy, pulse: pulse)

        // Player
        drawPlayer(context: shakeContext, cx: cx, cy: cy, pulse: pulse)

        // Particles
        drawParticles(context: shakeContext)

        // Slow-mo overlay
        if engine.slowmoActive {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(0.03))
            )
        }
    }

    // MARK: - Stars with gravitational lensing
    private func drawStars(context: GraphicsContext, pulse: CGFloat, cx: CGFloat, cy: CGFloat) {
        let minR = GameConstants.minRadius
        let prox = engine.proximityFactor // 0=far, 1=close
        let shadowRadius: CGFloat = 18
        let lensingRadius: CGFloat = minR * (2.8 + prox * 0.4) // wider lensing zone when close
        let einsteinR: CGFloat = shadowRadius * 1.4

        for star in engine.stars {
            let dx = star.x - cx
            let dy = star.y - cy
            let dist = hypot(dx, dy)

            let twinkle = 0.5 + 0.5 * sin(pulse * star.twinkleSpeed + star.twinkleOffset)
            var alpha = star.brightness * twinkle * 0.75

            // ── Shadow occlusion: stars behind the black hole disappear ──
            if dist < shadowRadius * 0.9 {
                continue
            }

            var drawX = star.x
            var drawY = star.y
            var drawW = star.size * 2
            var drawH = star.size * 2
            var isLensed = false

            // ── Gravitational lensing displacement ──
            if dist < lensingRadius && dist > shadowRadius * 0.9 {
                let normalizedDist = (dist - shadowRadius * 0.9) / (lensingRadius - shadowRadius * 0.9)
                let t = 1.0 - max(0, min(1, normalizedDist)) // 1 near BH, 0 at edge

                // Radial outward displacement (light bends around the mass)
                // Deflection follows ~1/d: stronger close to the hole
                let deflection = t * t * 14.0
                let angle = atan2(dy, dx)
                drawX = star.x + cos(angle) * deflection
                drawY = star.y + sin(angle) * deflection

                // Tangential stretching: stars near the photon sphere get elongated
                // into arcs (light wraps around the black hole)
                if t > 0.4 {
                    let stretch = 1.0 + (t - 0.4) * 2.5 // up to ~2.5x elongation
                    let tangentAngle = angle + .pi / 2
                    let tangentX = abs(cos(tangentAngle))
                    let tangentY = abs(sin(tangentAngle))

                    // Stretch perpendicular to the radial direction
                    drawW = star.size * 2 * (1 + (stretch - 1) * tangentX)
                    drawH = star.size * 2 * (1 + (stretch - 1) * tangentY)
                    isLensed = true
                }

                // Brightness boost near the photon sphere (light focusing)
                if t > 0.5 {
                    alpha *= (1.0 + (t - 0.5) * 1.5) // up to ~1.75x brighter
                }

                // Fade out as stars approach the shadow edge
                if normalizedDist < 0.15 {
                    alpha *= normalizedDist / 0.15
                }
            }

            let starColor = Color(red: 0.72, green: 0.76, blue: 0.95).opacity(Double(alpha))
            context.fill(
                Path(ellipseIn: CGRect(x: drawX - drawW / 2, y: drawY - drawH / 2,
                                       width: drawW, height: drawH)),
                with: .color(starColor)
            )

            // Cross flare for bright stars (skip for heavily lensed ones)
            if star.size > 1.3 && twinkle > 0.75 && !isLensed {
                let flareColor = Color(red: 0.72, green: 0.76, blue: 0.95).opacity(Double(alpha * 0.22))
                var path = Path()
                path.move(to: CGPoint(x: drawX - 2.5, y: drawY))
                path.addLine(to: CGPoint(x: drawX + 2.5, y: drawY))
                path.move(to: CGPoint(x: drawX, y: drawY - 2.5))
                path.addLine(to: CGPoint(x: drawX, y: drawY + 2.5))
                context.stroke(path, with: .color(flareColor), lineWidth: 0.3)
            }
        }

        // ── Einstein ring: faint arc of focused background starlight ──
        // Appears at the photon sphere — intensifies subtly with proximity
        let ringProxBoost = 1.0 + prox * 0.3
        let ringAlpha = (0.035 + 0.015 * sin(pulse * 0.8)) * ringProxBoost
        var einsteinPath = Path()
        einsteinPath.addArc(center: CGPoint(x: cx, y: cy), radius: einsteinR,
                            startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(einsteinPath,
                       with: .color(Color(red: 0.7, green: 0.75, blue: 1.0).opacity(ringAlpha)),
                       lineWidth: 1.5)
        // Softer outer glow of the Einstein ring
        context.stroke(einsteinPath,
                       with: .color(Color(red: 0.6, green: 0.65, blue: 0.95).opacity(ringAlpha * 0.4)),
                       lineWidth: 4)
    }

    // MARK: - Guide Rings
    private func drawGuideRings(context: GraphicsContext, cx: CGFloat, cy: CGFloat) {
        var r: CGFloat = GameConstants.minRadius
        while r <= GameConstants.maxRadius {
            var path = Path()
            path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                        startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            context.stroke(path, with: .color(Color(red: 0.4, green: 0.47, blue: 1.0).opacity(0.025)), lineWidth: 0.5)
            r += 40
        }
    }

    // MARK: - Black Hole
    private func drawBlackHole(context: GraphicsContext, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        // Proximity factor: 0=far, 1=at event horizon
        let prox = engine.proximityFactor
        // Base pulse + proximity-enhanced pulse (subtle intensification when close)
        let bhPulse = 1 + sin(pulse * 1.5) * (0.08 + prox * 0.06)
        let center = CGPoint(x: cx, y: cy)
        let minR = GameConstants.minRadius
        let diskTilt: CGFloat = 0.38  // flattening ratio for tilted disk view

        // Micro-turbulence function: produces tiny, non-repeating variation
        // Uses overlapping sine waves with irrational frequency ratios
        // Turbulence amplitude increases subtly with proximity
        let turbAmp: CGFloat = 1.0 + prox * 0.4
        func turbulence(_ seed: CGFloat, _ speed: CGFloat = 1.0) -> CGFloat {
            let s = speed * (1.0 + prox * 0.2) // slightly faster turbulence when close
            let a = sin(pulse * 2.17 * s + seed * 3.7) * 0.4
            let b = sin(pulse * 3.51 * s + seed * 5.3) * 0.3
            let c = sin(pulse * 5.89 * s + seed * 7.1) * 0.2
            let d = sin(pulse * 8.43 * s + seed * 11.3) * 0.1
            return (a + b + c + d) * turbAmp
        }

        // Color palette (outer to inner):
        // deep blue → electric blue → purple → magenta/pink → orange → bright yellow
        struct DiskColor {
            let r: Double, g: Double, b: Double
        }
        let diskColors: [DiskColor] = [
            DiskColor(r: 0.08, g: 0.20, b: 0.65),  // deep blue (outermost)
            DiskColor(r: 0.15, g: 0.40, b: 0.95),  // bright blue
            DiskColor(r: 0.25, g: 0.35, b: 0.92),  // blue-indigo
            DiskColor(r: 0.50, g: 0.25, b: 0.85),  // purple
            DiskColor(r: 0.75, g: 0.20, b: 0.70),  // magenta
            DiskColor(r: 0.90, g: 0.25, b: 0.50),  // pink-red
            DiskColor(r: 0.95, g: 0.45, b: 0.10),  // orange
            DiskColor(r: 1.00, g: 0.65, b: 0.05),  // warm orange
            DiskColor(r: 1.00, g: 0.82, b: 0.15),  // yellow (innermost)
            DiskColor(r: 1.00, g: 0.92, b: 0.50),  // bright yellow-white
        ]

        // Proximity-scaled energy boost (subtle: 1.0 far → up to 1.25 close)
        let proxEnergy: CGFloat = 1.0 + prox * 0.25

        // ── 1. Distant gravitational haze ──
        let hazeR = minR * 3.2
        context.fill(
            Path(ellipseIn: CGRect(x: cx - hazeR, y: cy - hazeR, width: hazeR * 2, height: hazeR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.15, green: 0.15, blue: 0.55).opacity(0.06 * proxEnergy), location: 0),
                    .init(color: Color(red: 0.3, green: 0.15, blue: 0.5).opacity(0.03 * proxEnergy), location: 0.4),
                    .init(color: .clear, location: 1)
                ]),
                center: center, startRadius: minR * 0.5, endRadius: hazeR
            )
        )

        // ── 2. Outer accretion glow (blue/purple halo) ──
        let outerGlowR = minR * 2.0
        context.fill(
            Path(ellipseIn: CGRect(x: cx - outerGlowR, y: cy - outerGlowR * diskTilt,
                                   width: outerGlowR * 2, height: outerGlowR * diskTilt * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.4, green: 0.3, blue: 0.9).opacity(0.08 * bhPulse * proxEnergy), location: 0),
                    .init(color: Color(red: 0.2, green: 0.15, blue: 0.7).opacity(0.04 * proxEnergy), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: center, startRadius: minR * 0.3, endRadius: outerGlowR
            )
        )

        // ── 3. Multi-color accretion disk rings (10 concentric elliptical rings) ──
        let numRings = diskColors.count
        for ring in 0..<numRings {
            let t = CGFloat(ring) / CGFloat(numRings - 1)  // 0 = outermost, 1 = innermost
            let ringR = minR * (1.6 - t * 1.1) * bhPulse  // outer rings bigger
            let ringW: CGFloat = 4 + (1 - t) * 4  // outer rings wider
            let ringAlpha = (0.3 + t * 0.15) * bhPulse * proxEnergy

            let c = diskColors[ring]

            var diskPath = Path()
            diskPath.addEllipse(in: CGRect(x: cx - ringR, y: cy - ringR * diskTilt,
                                            width: ringR * 2, height: ringR * diskTilt * 2))
            context.stroke(diskPath,
                           with: .color(Color(red: c.r, green: c.g, blue: c.b).opacity(Double(ringAlpha))),
                           lineWidth: ringW)

            // Secondary glow layer for each ring
            context.stroke(diskPath,
                           with: .color(Color(red: c.r, green: c.g, blue: c.b).opacity(Double(ringAlpha * 0.2))),
                           lineWidth: ringW + 4)
        }

        // ── 4. Colorful orbiting accretion particles (with lensing compression) ──
        for (pIdx, p) in engine.accretionParticles.enumerated() {
            // Lensing: inner particles get slight radial compression
            // simulating light paths curving tighter near the event horizon
            let lensingFactor: CGFloat = p.radius < 25 ? 1.0 + (25 - p.radius) * 0.006 : 1.0
            // Micro-turbulence: tiny positional jitter suggesting turbulent accretion flow
            let turbX = turbulence(CGFloat(pIdx) * 0.37 + p.angle) * 0.3
            let turbY = turbulence(CGFloat(pIdx) * 0.53 + p.angle + 100) * 0.2
            let ax = cx + cos(p.angle) * p.radius * bhPulse * 1.3 * lensingFactor + turbX
            let ay = cy + sin(p.angle) * p.radius * diskTilt * bhPulse * lensingFactor + turbY
            let distFactor = 1 - (p.radius - 12) / 38  // 0=far, 1=close

            // Color shifts based on distance: outer=blue, inner=orange/yellow
            let colorT = max(0, min(1, Double(distFactor)))
            let pr = 0.2 + colorT * 0.8     // blue→yellow red channel
            let pg = 0.4 + colorT * 0.45    // blue→yellow green
            let pb = 0.95 - colorT * 0.75   // blue→yellow blue channel

            let brightness = p.brightness * (0.6 + 0.4 * sin(pulse * 4 + p.angle))
            let particleSize = p.size * (1 + distFactor * 0.5)
            let color = Color(red: pr, green: pg, blue: pb).opacity(Double(brightness * 0.65))

            context.fill(
                Path(ellipseIn: CGRect(x: ax - particleSize, y: ay - particleSize,
                                       width: particleSize * 2, height: particleSize * 2)),
                with: .color(color)
            )

            // Sparkle glow for bright particles
            if brightness > 0.45 {
                let glowS = particleSize * 3.5
                context.fill(
                    Path(ellipseIn: CGRect(x: ax - glowS, y: ay - glowS,
                                           width: glowS * 2, height: glowS * 2)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: Color(red: pr, green: pg, blue: pb).opacity(Double(brightness * 0.2)), location: 0),
                            .init(color: .clear, location: 1)
                        ]),
                        center: CGPoint(x: ax, y: ay), startRadius: 0, endRadius: glowS
                    )
                )
            }
        }

        // ── 5. Sparkle stars around disk ──
        for i in 0..<20 {
            let seed = CGFloat(i) * 137.5
            let sparkAngle = pulse * 0.3 + seed
            let sparkR = minR * (0.6 + CGFloat(i % 7) * 0.18)
            let sx = cx + cos(sparkAngle) * sparkR * 1.2
            let sy = cy + sin(sparkAngle) * sparkR * diskTilt
            let sparkAlpha = 0.3 + 0.3 * sin(pulse * 5 + seed)
            let sparkSize: CGFloat = 0.5 + CGFloat(i % 3) * 0.4

            if sparkAlpha > 0.35 {
                context.fill(
                    Path(ellipseIn: CGRect(x: sx - sparkSize, y: sy - sparkSize,
                                           width: sparkSize * 2, height: sparkSize * 2)),
                    with: .color(Color.white.opacity(Double(sparkAlpha * 0.5)))
                )
                // Cross flare for brightest
                if sparkAlpha > 0.5 {
                    var flarePath = Path()
                    flarePath.move(to: CGPoint(x: sx - 2.5, y: sy))
                    flarePath.addLine(to: CGPoint(x: sx + 2.5, y: sy))
                    flarePath.move(to: CGPoint(x: sx, y: sy - 2.5))
                    flarePath.addLine(to: CGPoint(x: sx, y: sy + 2.5))
                    context.stroke(flarePath, with: .color(Color.white.opacity(Double(sparkAlpha * 0.2))), lineWidth: 0.4)
                }
            }
        }

        // ── 6. Inner photon ring (bright multi-color, with micro-turbulence) ──
        let photonR = minR * 0.5 * bhPulse
        let photonAlpha = 0.5 + 0.15 * sin(pulse * 2)
        var photonPath = Path()
        photonPath.addEllipse(in: CGRect(x: cx - photonR, y: cy - photonR * diskTilt,
                                          width: photonR * 2, height: photonR * diskTilt * 2))
        context.stroke(photonPath,
                       with: .color(Color(red: 1.0, green: 0.9, blue: 0.5).opacity(Double(photonAlpha * 0.25))),
                       lineWidth: 6)
        context.stroke(photonPath,
                       with: .color(Color(red: 1.0, green: 0.85, blue: 0.3).opacity(Double(photonAlpha * 0.5))),
                       lineWidth: 2.5)
        context.stroke(photonPath,
                       with: .color(Color.white.opacity(Double(photonAlpha * 0.4))),
                       lineWidth: 0.8)

        // Photon ring turbulence ghosts — ultra-faint copies at micro-offset radii
        // Simulates frame-dragging instability in the photon sphere
        for g in 0..<3 {
            let ghostOffset = turbulence(CGFloat(g) * 2.1) * 0.6  // ±0.6 pixel jitter
            let ghostR = photonR + ghostOffset
            let ghostAlpha = 0.035 + turbulence(CGFloat(g) * 3.7, 0.5) * 0.01
            var ghostPath = Path()
            ghostPath.addEllipse(in: CGRect(x: cx - ghostR, y: cy - ghostR * diskTilt,
                                             width: ghostR * 2, height: ghostR * diskTilt * 2))
            context.stroke(ghostPath,
                           with: .color(Color(red: 1.0, green: 0.88, blue: 0.4).opacity(Double(ghostAlpha))),
                           lineWidth: 1.5)
        }

        // ── 7. Event horizon (pure black core) ──
        let ehRadius = 16 * bhPulse
        let auraR = ehRadius * 2.5
        context.fill(
            Path(ellipseIn: CGRect(x: cx - auraR, y: cy - auraR, width: auraR * 2, height: auraR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.85), location: 0.35),
                    .init(color: .black.opacity(0.3), location: 0.6),
                    .init(color: .clear, location: 1)
                ]),
                center: center, startRadius: 0, endRadius: auraR
            )
        )

        // Solid black core
        context.fill(
            Path(ellipseIn: CGRect(x: cx - ehRadius, y: cy - ehRadius,
                                   width: ehRadius * 2, height: ehRadius * 2)),
            with: .color(.black)
        )

        // ── Event horizon edge treatment ──
        // Tight dark gradient collar to sharpen boundary contrast
        let collarR = ehRadius + 3.0
        context.fill(
            Path(ellipseIn: CGRect(x: cx - collarR, y: cy - collarR,
                                   width: collarR * 2, height: collarR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.7), location: Double(ehRadius / collarR - 0.08)),
                    .init(color: .black, location: Double(ehRadius / collarR)),
                    .init(color: .clear, location: 1)
                ]),
                center: center, startRadius: 0, endRadius: collarR
            )
        )

        // Chromatic boundary — red-shifted ring outside, blue-shifted inside
        // Simulates extreme gravitational frequency shifting at the boundary
        // Micro-turbulence: chromatic separation drifts non-uniformly
        let microShift: CGFloat = 0.6 + turbulence(0.0, 0.3) * 0.15  // 0.45–0.75 pixel drift

        // Blue-violet: just inside the boundary (blue-shifted infall)
        // Draw as segments with per-segment radius micro-jitter for instability
        let chromaSegs = 16
        for seg in 0..<chromaSegs {
            let a0 = CGFloat(seg) / CGFloat(chromaSegs) * .pi * 2
            let a1 = CGFloat(seg + 1) / CGFloat(chromaSegs) * .pi * 2
            let segJitter = turbulence(CGFloat(seg) * 1.1) * 0.25  // ±0.25px radius variation
            let innerR = ehRadius - microShift + segJitter
            let outerR = ehRadius + microShift - segJitter * 0.7
            let segOpacityVar = 1.0 + turbulence(CGFloat(seg) * 2.3, 0.6) * 0.08

            var innerSeg = Path()
            innerSeg.addArc(center: center, radius: innerR,
                            startAngle: .radians(Double(a0)), endAngle: .radians(Double(a1)),
                            clockwise: false)
            context.stroke(innerSeg,
                           with: .color(Color(red: 0.35, green: 0.45, blue: 1.0).opacity(0.18 * segOpacityVar)),
                           lineWidth: 1.2)

            var outerSeg = Path()
            outerSeg.addArc(center: center, radius: outerR,
                            startAngle: .radians(Double(a0)), endAngle: .radians(Double(a1)),
                            clockwise: false)
            context.stroke(outerSeg,
                           with: .color(Color(red: 1.0, green: 0.55, blue: 0.2).opacity(0.14 * segOpacityVar)),
                           lineWidth: 1.0)
        }

        // Core energy line — razor-thin white ring at exact boundary
        // Drawn as segments with micro-radius variation for spacetime instability
        let energyAlpha = 0.22 + 0.04 * sin(pulse * 1.7 + 0.5)
        let energySegs = 20
        for seg in 0..<energySegs {
            let a0 = CGFloat(seg) / CGFloat(energySegs) * .pi * 2
            let a1 = CGFloat(seg + 1) / CGFloat(energySegs) * .pi * 2
            let rJitter = turbulence(CGFloat(seg) * 0.9 + 50.0) * 0.2  // ±0.2px — barely visible
            let segAlphaVar = energyAlpha * (1.0 + turbulence(CGFloat(seg) * 1.7 + 30.0, 0.8) * 0.06)

            var energySeg = Path()
            energySeg.addArc(center: center, radius: ehRadius + rJitter,
                             startAngle: .radians(Double(a0)), endAngle: .radians(Double(a1)),
                             clockwise: false)
            context.stroke(energySeg,
                           with: .color(Color(red: 0.92, green: 0.88, blue: 1.0).opacity(Double(segAlphaVar))),
                           lineWidth: 0.8)
        }

        // Segmented instability arcs — bright fragments drifting along boundary
        // Enhanced with micro-radius jitter and linewidth variation
        let arcCount = 5
        for k in 0..<arcCount {
            let baseAngle = CGFloat(k) * (.pi * 2 / CGFloat(arcCount))
            let drift = pulse * (0.12 + CGFloat(k) * 0.037)
            let arcStart = baseAngle + drift
            let arcSpan: CGFloat = 0.12 + 0.06 * sin(pulse * 0.8 + CGFloat(k) * 1.9)

            // Each arc sits at a slightly different radius — spacetime turbulence
            let arcRadiusOffset = turbulence(CGFloat(k) * 3.3 + 10.0) * 0.3

            var arc = Path()
            arc.addArc(center: center, radius: ehRadius + arcRadiusOffset,
                       startAngle: .radians(Double(arcStart)),
                       endAngle: .radians(Double(arcStart + arcSpan)),
                       clockwise: false)

            let arcAlpha = 0.22 + 0.08 * sin(pulse * 1.3 + CGFloat(k) * 2.3)
            let arcWidth = 1.2 + turbulence(CGFloat(k) * 4.1, 0.5) * 0.3  // 0.9–1.5px
            context.stroke(arc,
                           with: .color(Color(red: 1.0, green: 0.92, blue: 0.85).opacity(Double(arcAlpha))),
                           lineWidth: arcWidth)
        }

        // ── 8. Relativistic jets (subtle purple/blue) ──
        let jetAlpha = 0.04 + 0.02 * sin(pulse * 2.5)
        let jetWidth: CGFloat = 5 + sin(pulse * 3) * 2
        let jetHeight = minR * 2.0

        for direction: CGFloat in [-1, 1] {
            var jet = Path()
            jet.move(to: CGPoint(x: cx - jetWidth * 0.3, y: cy))
            jet.addQuadCurve(
                to: CGPoint(x: cx, y: cy + direction * jetHeight),
                control: CGPoint(x: cx - jetWidth, y: cy + direction * jetHeight * 0.5))
            jet.addQuadCurve(
                to: CGPoint(x: cx + jetWidth * 0.3, y: cy),
                control: CGPoint(x: cx + jetWidth, y: cy + direction * jetHeight * 0.5))
            jet.closeSubpath()

            context.fill(jet, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.5, green: 0.4, blue: 1.0).opacity(jetAlpha * 2.5), location: 0),
                    .init(color: Color(red: 0.3, green: 0.3, blue: 0.9).opacity(jetAlpha), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint: CGPoint(x: cx, y: cy + direction * jetHeight)
            ))
        }

        // ── 9. Danger zone ring (subtle pulsing) ──
        let dangerAlpha = 0.10 + sin(pulse * 3) * 0.06
        var dangerPath = Path()
        dangerPath.addArc(center: center, radius: GameConstants.minRadius,
                          startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(
            dangerPath,
            with: .color(Color(red: 0.94, green: 0.27, blue: 0.27).opacity(Double(dangerAlpha))),
            style: StrokeStyle(lineWidth: 1.0, dash: [4, 4])
        )

        // Inner glow on danger ring (purple-ish)
        context.stroke(
            dangerPath,
            with: .color(Color(red: 0.6, green: 0.3, blue: 1.0).opacity(Double(dangerAlpha * 0.25))),
            lineWidth: 4
        )

        // ── 10. Outer boundary ──
        var outerPath = Path()
        outerPath.addArc(center: center, radius: GameConstants.maxRadius,
                         startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(outerPath, with: .color(.white.opacity(0.025)), lineWidth: 1)
    }

    // MARK: - Obstacles
    private func drawObstacles(context: GraphicsContext, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        for obstacle in engine.obstacles {
            switch obstacle.type {
            case .asteroid:
                drawAsteroid(context: context, o: obstacle)
            case .orbiter:
                drawOrbiter(context: context, o: obstacle, cx: cx, cy: cy, pulse: pulse)
            case .ring:
                drawRing(context: context, o: obstacle, cx: cx, cy: cy, pulse: pulse)
            case .magneticField:
                drawMagneticField(context: context, o: obstacle, cx: cx, cy: cy, pulse: pulse)
            case .vortex:
                drawVortex(context: context, o: obstacle, cx: cx, cy: cy, pulse: pulse)
            case .laserBeam:
                drawLaserBeam(context: context, o: obstacle, cx: cx, cy: cy, pulse: pulse)
            }
        }
    }

    private func drawAsteroid(context: GraphicsContext, o: Obstacle) {
        var ctx = context
        ctx.translateBy(x: o.x, y: o.y)
        ctx.rotate(by: .radians(Double(o.rotation)))

        let numV = o.vertices.count
        guard numV >= 3 else { return }

        // Build asteroid path
        var path = Path()
        for i in 0...numV {
            let a = CGFloat(i) / CGFloat(numV) * .pi * 2
            let r = o.size * o.vertices[i % numV]
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { path.move(to: pt) }
            else { path.addLine(to: pt) }
        }
        path.closeSubpath()

        // ── 3D Directional lighting (light from top-left) ──
        let lightX = -o.size * 0.3
        let lightY = -o.size * 0.45

        // ── Ambient shadow halo (ground the asteroid in space) ──
        let haloR = o.size * 1.3
        ctx.fill(
            Path(ellipseIn: CGRect(x: -haloR, y: -haloR, width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.55),
                    .init(color: Color.black.opacity(0.06), location: 0.75),
                    .init(color: .clear, location: 1)
                ]),
                center: .zero, startRadius: 0, endRadius: haloR
            )
        )

        // Base fill with off-center gradient for 3D depth
        ctx.fill(path, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(hue: o.hue / 360, saturation: 0.18, brightness: 0.72), location: 0),
                .init(color: Color(hue: o.hue / 360, saturation: 0.28, brightness: 0.56), location: 0.25),
                .init(color: Color(hue: o.hue / 360, saturation: 0.38, brightness: 0.38), location: 0.55),
                .init(color: Color(hue: o.hue / 360, saturation: 0.48, brightness: 0.18), location: 0.85),
                .init(color: Color(hue: o.hue / 360, saturation: 0.52, brightness: 0.10), location: 1)
            ]),
            center: CGPoint(x: lightX, y: lightY),
            startRadius: 0, endRadius: o.size * 1.5
        ))

        // ── Terminator shadow band (dark crescent on shadow side for spherical look) ──
        let shadowX = o.size * 0.35
        let shadowY = o.size * 0.4
        let termR = o.size * 1.1
        ctx.fill(
            Path(ellipseIn: CGRect(x: shadowX - termR * 0.6, y: shadowY - termR * 0.6,
                                   width: termR * 1.2, height: termR * 1.2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hue: o.hue / 360, saturation: 0.5, brightness: 0.04).opacity(0.5), location: 0),
                    .init(color: Color(hue: o.hue / 360, saturation: 0.4, brightness: 0.08).opacity(0.3), location: 0.4),
                    .init(color: .clear, location: 0.8)
                ]),
                center: CGPoint(x: shadowX, y: shadowY),
                startRadius: 0, endRadius: termR * 0.6
            )
        )

        // ── Specular highlight (bright spot near light source) ──
        let specSize = o.size * 0.35
        ctx.fill(
            Path(ellipseIn: CGRect(x: lightX - specSize, y: lightY - specSize,
                                   width: specSize * 2, height: specSize * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hue: o.hue / 360, saturation: 0.04, brightness: 0.95).opacity(0.55), location: 0),
                    .init(color: Color(hue: o.hue / 360, saturation: 0.08, brightness: 0.85).opacity(0.2), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: lightX, y: lightY), startRadius: 0, endRadius: specSize
            )
        )

        // ── Secondary specular (broader, softer – fills more of the lit hemisphere) ──
        let sec = o.size * 0.6
        ctx.fill(
            Path(ellipseIn: CGRect(x: lightX * 0.7 - sec, y: lightY * 0.7 - sec,
                                   width: sec * 2, height: sec * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hue: o.hue / 360, saturation: 0.06, brightness: 0.80).opacity(0.12), location: 0),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: lightX * 0.7, y: lightY * 0.7), startRadius: 0, endRadius: sec
            )
        )

        // ── Rim light on shadow side (backlit edge – stronger for 3D pop) ──
        ctx.stroke(path, with: .linearGradient(
            Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.4),
                .init(color: Color(hue: o.hue / 360, saturation: 0.10, brightness: 0.80).opacity(0.35), location: 0.7),
                .init(color: Color(hue: o.hue / 360, saturation: 0.06, brightness: 0.90).opacity(0.25), location: 1)
            ]),
            startPoint: CGPoint(x: lightX, y: lightY),
            endPoint: CGPoint(x: o.size * 0.5, y: o.size * 0.55)
        ), lineWidth: 1.5)

        // ── Dark edge outline on lit side (ambient occlusion at edge) ──
        ctx.stroke(path, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hue: o.hue / 360, saturation: 0.3, brightness: 0.3).opacity(0.4), location: 0),
                .init(color: Color(hue: o.hue / 360, saturation: 0.2, brightness: 0.25).opacity(0.2), location: 0.4),
                .init(color: .clear, location: 0.6)
            ]),
            startPoint: CGPoint(x: lightX * 0.5, y: lightY * 0.5),
            endPoint: CGPoint(x: o.size * 0.5, y: o.size * 0.5)
        ), lineWidth: 0.8)

        // ── Enhanced 3D craters ──
        for cr in o.craters {
            let crX = cos(cr.angle) * o.size * cr.dist
            let crY = sin(cr.angle) * o.size * cr.dist
            let crSize = o.size * cr.size

            // Crater depression (shadow offset toward light for depth)
            let craterPath = Path(ellipseIn: CGRect(x: crX - crSize, y: crY - crSize,
                                                     width: crSize * 2, height: crSize * 2))
            ctx.fill(craterPath, with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hue: o.hue / 360, saturation: 0.5, brightness: 0.06).opacity(0.75), location: 0),
                    .init(color: Color(hue: o.hue / 360, saturation: 0.4, brightness: 0.15).opacity(0.45), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: crX + crSize * 0.25, y: crY + crSize * 0.25),
                startRadius: 0, endRadius: crSize
            ))

            // Crater rim highlight (light-facing edge – stronger)
            let rimHL = Path(ellipseIn: CGRect(x: crX - crSize * 0.3 - crSize * 0.65,
                                                y: crY - crSize * 0.3 - crSize * 0.65,
                                                width: crSize * 1.3, height: crSize * 1.3))
            ctx.fill(rimHL, with: .color(Color(hue: o.hue / 360, saturation: 0.10, brightness: 0.75).opacity(0.22)))

            // Inner crater floor highlight (reflected light)
            let innerR = crSize * 0.3
            ctx.fill(
                Path(ellipseIn: CGRect(x: crX - innerR, y: crY - innerR,
                                       width: innerR * 2, height: innerR * 2)),
                with: .color(Color(hue: o.hue / 360, saturation: 0.3, brightness: 0.12).opacity(0.3))
            )
        }

        // ── Surface texture bumps ──
        for i in 0..<8 {
            let bAngle = CGFloat(i) * 1.37 + 0.7
            let bDist = o.size * (0.12 + CGFloat(i % 5) * 0.15)
            let bx = cos(bAngle) * bDist
            let by = sin(bAngle) * bDist
            let bSize = o.size * (0.04 + CGFloat(i % 3) * 0.025)

            ctx.fill(
                Path(ellipseIn: CGRect(x: bx - bSize, y: by - bSize,
                                       width: bSize * 2, height: bSize * 2)),
                with: .color(Color(hue: o.hue / 360, saturation: 0.3, brightness: 0.20).opacity(0.45))
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: bx - bSize * 0.6 - bSize * 0.35, y: by - bSize * 0.6 - bSize * 0.35,
                                       width: bSize * 1.2, height: bSize * 1.2)),
                with: .color(Color(hue: o.hue / 360, saturation: 0.08, brightness: 0.68).opacity(0.18))
            )
        }

        // ── Surface veins / scratch lines ──
        for i in 0..<5 {
            let vAngle1 = CGFloat(i) * 1.85 + 0.3
            let vAngle2 = vAngle1 + CGFloat.pi * (0.15 + CGFloat(i % 3) * 0.1)
            let vR1 = o.size * (0.15 + CGFloat(i % 4) * 0.12)
            let vR2 = o.size * (0.35 + CGFloat(i % 3) * 0.18)

            var veinPath = Path()
            let vx1 = cos(vAngle1) * vR1
            let vy1 = sin(vAngle1) * vR1
            let vx2 = cos(vAngle2) * vR2
            let vy2 = sin(vAngle2) * vR2
            let mx = (vx1 + vx2) * 0.5 + cos(vAngle1 + 1.0) * o.size * 0.08
            let my = (vy1 + vy2) * 0.5 + sin(vAngle1 + 1.0) * o.size * 0.08

            veinPath.move(to: CGPoint(x: vx1, y: vy1))
            veinPath.addQuadCurve(to: CGPoint(x: vx2, y: vy2),
                                   control: CGPoint(x: mx, y: my))

            ctx.stroke(veinPath,
                       with: .color(Color(hue: o.hue / 360, saturation: 0.4, brightness: 0.12).opacity(0.28)),
                       lineWidth: 0.6)
            var ridgePath = Path()
            let offset: CGFloat = 0.5
            ridgePath.move(to: CGPoint(x: vx1 - offset, y: vy1 - offset))
            ridgePath.addQuadCurve(to: CGPoint(x: vx2 - offset, y: vy2 - offset),
                                    control: CGPoint(x: mx - offset, y: my - offset))
            ctx.stroke(ridgePath,
                       with: .color(Color(hue: o.hue / 360, saturation: 0.08, brightness: 0.62).opacity(0.12)),
                       lineWidth: 0.4)
        }

        // ── Mineral speckles ──
        for i in 0..<12 {
            let sAngle = CGFloat(i) * 2.618 + 0.5
            let sDist = o.size * (0.1 + CGFloat(i % 6) * 0.12)
            let sx = cos(sAngle) * sDist
            let sy = sin(sAngle) * sDist
            let sSize = o.size * (0.015 + CGFloat(i % 4) * 0.008)
            let bright = CGFloat(i % 2 == 0 ? 0.55 : 0.35)

            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - sSize, y: sy - sSize,
                                       width: sSize * 2, height: sSize * 2)),
                with: .color(Color(hue: (o.hue + CGFloat(i * 12).truncatingRemainder(dividingBy: 360)) / 360,
                                   saturation: 0.2, brightness: bright).opacity(0.3))
            )
        }

        // ── Dust layer ──
        let dustR = o.size * 0.65
        ctx.fill(
            Path(ellipseIn: CGRect(x: -dustR * 0.4, y: dustR * 0.1,
                                   width: dustR * 1.2, height: dustR * 0.8)),
            with: .color(Color(hue: o.hue / 360, saturation: 0.15, brightness: 0.4).opacity(0.08))
        )
    }

    private func drawOrbiter(context: GraphicsContext, o: Obstacle, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        let ox = cx + cos(o.angle) * o.radius
        let oy = cy + sin(o.angle) * o.radius
        let pulseFactor = 0.8 + 0.2 * sin(o.pulsePhase)

        // Trail
        if o.trailHistory.count > 2 {
            for t in 0..<(o.trailHistory.count - 1) {
                let alpha = CGFloat(t) / CGFloat(o.trailHistory.count) * 0.2
                let th = o.trailHistory[t]
                let s = o.size * CGFloat(t) / CGFloat(o.trailHistory.count) * 0.6
                context.fill(
                    Path(ellipseIn: CGRect(x: th.x - s, y: th.y - s, width: s * 2, height: s * 2)),
                    with: .color(Color(red: 0.94, green: 0.27, blue: 0.27).opacity(Double(alpha)))
                )
            }
        }

        // Outer danger haze
        let hazeR = o.size * 3.5
        context.fill(
            Path(ellipseIn: CGRect(x: ox - hazeR, y: oy - hazeR, width: hazeR * 2, height: hazeR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.94, green: 0.27, blue: 0.27).opacity(Double(0.08 * pulseFactor)), location: 0),
                    .init(color: Color(red: 0.7, green: 0.15, blue: 0.15).opacity(Double(0.03 * pulseFactor)), location: 0.6),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: ox, y: oy), startRadius: 0, endRadius: hazeR
            )
        )

        // Corona ring
        let coronaR = o.size * 1.8 * pulseFactor
        var coronaPath = Path()
        coronaPath.addArc(center: CGPoint(x: ox, y: oy), radius: coronaR,
                          startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(coronaPath,
                       with: .color(Color(red: 1.0, green: 0.4, blue: 0.2).opacity(Double(0.12 * pulseFactor))),
                       lineWidth: 2)

        // Main sphere with 3D lighting
        let coreR = o.size * pulseFactor
        let lightOff = o.size * 0.25
        context.fill(
            Path(ellipseIn: CGRect(x: ox - coreR, y: oy - coreR, width: coreR * 2, height: coreR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 1.0, green: 0.65, blue: 0.55), location: 0),
                    .init(color: Color(red: 1.0, green: 0.42, blue: 0.35), location: 0.25),
                    .init(color: Color(red: 0.88, green: 0.22, blue: 0.22), location: 0.55),
                    .init(color: Color(red: 0.55, green: 0.08, blue: 0.08), location: 0.85),
                    .init(color: Color(red: 0.35, green: 0.04, blue: 0.04), location: 1)
                ]),
                center: CGPoint(x: ox - lightOff, y: oy - lightOff),
                startRadius: 0, endRadius: coreR * 1.3
            )
        )

        // Hot white center (specular)
        let hotR = o.size * 0.3 * pulseFactor
        context.fill(
            Path(ellipseIn: CGRect(x: ox - lightOff - hotR, y: oy - lightOff - hotR,
                                   width: hotR * 2, height: hotR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 1.0, green: 0.9, blue: 0.85).opacity(0.7), location: 0),
                    .init(color: Color(red: 1.0, green: 0.7, blue: 0.6).opacity(0.3), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: ox - lightOff, y: oy - lightOff),
                startRadius: 0, endRadius: hotR
            )
        )

        // Rim light on dark side
        let rimR = coreR * 0.9
        var rimPath = Path()
        rimPath.addArc(center: CGPoint(x: ox, y: oy), radius: rimR,
                       startAngle: .radians(Double(o.angle + 0.5)),
                       endAngle: .radians(Double(o.angle + 2.5)),
                       clockwise: false)
        context.stroke(rimPath,
                       with: .color(Color(red: 1.0, green: 0.5, blue: 0.3).opacity(Double(0.25 * pulseFactor))),
                       lineWidth: 1)
    }

    private func drawRing(context: GraphicsContext, o: Obstacle, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        let alpha = min(1, o.life * 0.5)
        let center = CGPoint(x: cx, y: cy)
        let gapStart = o.gapAngle - o.gapSize * .pi
        let gapEnd = o.gapAngle + o.gapSize * .pi

        // Ring glow
        var glowPath = Path()
        glowPath.addArc(center: center, radius: o.radius,
                        startAngle: .radians(Double(gapEnd)),
                        endAngle: .radians(Double(gapStart + .pi * 2)),
                        clockwise: false)
        context.stroke(glowPath,
                       with: .color(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(Double(alpha * 0.15))),
                       lineWidth: o.thickness + 6)

        // Ring main
        var mainPath = Path()
        mainPath.addArc(center: center, radius: o.radius,
                        startAngle: .radians(Double(gapEnd)),
                        endAngle: .radians(Double(gapStart + .pi * 2)),
                        clockwise: false)
        context.stroke(mainPath,
                       with: .color(Color(red: 0.96, green: 0.62, blue: 0.04).opacity(Double(alpha * 0.85))),
                       lineWidth: o.thickness)

        // Inner bright edge
        context.stroke(mainPath,
                       with: .color(Color(red: 1.0, green: 0.9, blue: 0.59).opacity(Double(alpha * 0.4))),
                       lineWidth: 1)

        // Gap indicators (green dots)
        for a in [gapStart, gapEnd] {
            let gx = cx + cos(a) * o.radius
            let gy = cy + sin(a) * o.radius

            // Outer glow
            context.fill(
                Path(ellipseIn: CGRect(x: gx - 8, y: gy - 8, width: 16, height: 16)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.13, green: 0.77, blue: 0.37).opacity(Double(alpha * 0.4)), location: 0),
                        .init(color: .clear, location: 1)
                    ]),
                    center: CGPoint(x: gx, y: gy), startRadius: 0, endRadius: 8
                )
            )

            // Core dot
            context.fill(
                Path(ellipseIn: CGRect(x: gx - 3, y: gy - 3, width: 6, height: 6)),
                with: .color(Color(red: 0.13, green: 0.77, blue: 0.37).opacity(Double(alpha * 0.8)))
            )
        }
    }

    // MARK: - Magnetic Field
    private func drawMagneticField(context: GraphicsContext, o: Obstacle, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        let fx = cx + cos(o.angle) * o.radius
        let fy = cy + sin(o.angle) * o.radius
        let fadeIn = min(1, (o.life > 1 ? 1 : o.life))
        let pulseFactor = 0.85 + 0.15 * sin(o.pulsePhase)
        let isPush = o.fieldStrength > 0

        // Base color: purple for push, magenta for pull
        let baseColor = isPush
            ? Color(red: 0.6, green: 0.3, blue: 0.95)
            : Color(red: 0.95, green: 0.3, blue: 0.7)

        // Outer zone glow
        let zoneR = o.fieldRadius * pulseFactor
        context.fill(
            Path(ellipseIn: CGRect(x: fx - zoneR, y: fy - zoneR, width: zoneR * 2, height: zoneR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: baseColor.opacity(Double(fadeIn * 0.12)), location: 0),
                    .init(color: baseColor.opacity(Double(fadeIn * 0.06)), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: fx, y: fy), startRadius: 0, endRadius: zoneR
            )
        )

        // Rotating field lines (4 spirals)
        for i in 0..<4 {
            let lineAngle = o.pulsePhase + CGFloat(i) * .pi / 2
            let innerR: CGFloat = 6
            let outerR = o.fieldRadius * 0.8
            var fieldPath = Path()
            let steps = 12
            for s in 0...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let r = innerR + (outerR - innerR) * t
                let spiralOffset = isPush ? t * 0.6 : -t * 0.6
                let a = lineAngle + spiralOffset
                let px = fx + cos(a) * r
                let py = fy + sin(a) * r
                if s == 0 { fieldPath.move(to: CGPoint(x: px, y: py)) }
                else { fieldPath.addLine(to: CGPoint(x: px, y: py)) }
            }
            context.stroke(fieldPath,
                           with: .color(baseColor.opacity(Double(fadeIn * 0.3))),
                           lineWidth: 1.2)
        }

        // Border ring (dashed)
        var borderPath = Path()
        borderPath.addArc(center: CGPoint(x: fx, y: fy), radius: o.fieldRadius * 0.9,
                          startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(borderPath,
                       with: .color(baseColor.opacity(Double(fadeIn * 0.2))),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // Center icon
        let centerR: CGFloat = 5
        context.fill(
            Path(ellipseIn: CGRect(x: fx - centerR, y: fy - centerR, width: centerR * 2, height: centerR * 2)),
            with: .color(baseColor.opacity(Double(fadeIn * 0.5)))
        )

        // Arrow indicators (push = outward, pull = inward)
        for i in 0..<4 {
            let arrowAngle = o.pulsePhase * 0.5 + CGFloat(i) * .pi / 2
            let arrowDist = o.fieldRadius * (0.5 + 0.15 * sin(o.pulsePhase * 2))
            let ax = fx + cos(arrowAngle) * arrowDist
            let ay = fy + sin(arrowAngle) * arrowDist
            let tipLen: CGFloat = 4
            let tipAngle = isPush ? arrowAngle : arrowAngle + .pi

            var arrowPath = Path()
            arrowPath.move(to: CGPoint(x: ax + cos(tipAngle) * tipLen, y: ay + sin(tipAngle) * tipLen))
            arrowPath.addLine(to: CGPoint(x: ax + cos(tipAngle + 2.5) * tipLen * 0.6,
                                           y: ay + sin(tipAngle + 2.5) * tipLen * 0.6))
            arrowPath.move(to: CGPoint(x: ax + cos(tipAngle) * tipLen, y: ay + sin(tipAngle) * tipLen))
            arrowPath.addLine(to: CGPoint(x: ax + cos(tipAngle - 2.5) * tipLen * 0.6,
                                           y: ay + sin(tipAngle - 2.5) * tipLen * 0.6))
            context.stroke(arrowPath, with: .color(baseColor.opacity(Double(fadeIn * 0.4))), lineWidth: 1.2)
        }
    }

    // MARK: - Vortex
    private func drawVortex(context: GraphicsContext, o: Obstacle, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        let vx = cx + cos(o.angle) * o.radius
        let vy = cy + sin(o.angle) * o.radius
        let fadeIn = min(1, (o.life > 1 ? 1 : o.life))

        let vortexColor = Color(red: 0.02, green: 0.85, blue: 0.95)

        // Outer zone
        let zoneR = o.fieldRadius
        context.fill(
            Path(ellipseIn: CGRect(x: vx - zoneR, y: vy - zoneR, width: zoneR * 2, height: zoneR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: vortexColor.opacity(Double(fadeIn * 0.1)), location: 0),
                    .init(color: vortexColor.opacity(Double(fadeIn * 0.04)), location: 0.6),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: vx, y: vy), startRadius: 0, endRadius: zoneR
            )
        )

        // Spinning spiral arms (3 arms)
        for arm in 0..<3 {
            let baseAngle = o.pulsePhase + CGFloat(arm) * (.pi * 2 / 3)
            var spiralPath = Path()
            let steps = 20
            for s in 0...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let r = 3 + (zoneR * 0.85) * t
                let a = baseAngle + t * 3.0 // 3 full rotations over the arm length
                let sx = vx + cos(a) * r
                let sy = vy + sin(a) * r
                if s == 0 { spiralPath.move(to: CGPoint(x: sx, y: sy)) }
                else { spiralPath.addLine(to: CGPoint(x: sx, y: sy)) }
            }
            let armAlpha = fadeIn * (0.25 + 0.1 * sin(pulse * 3 + CGFloat(arm)))
            context.stroke(spiralPath,
                           with: .color(vortexColor.opacity(Double(armAlpha))),
                           lineWidth: 1.5)
        }

        // Center bright core
        let coreR: CGFloat = 4
        context.fill(
            Path(ellipseIn: CGRect(x: vx - coreR, y: vy - coreR, width: coreR * 2, height: coreR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: vortexColor.opacity(Double(fadeIn * 0.6)), location: 0),
                    .init(color: vortexColor.opacity(Double(fadeIn * 0.2)), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: vx, y: vy), startRadius: 0, endRadius: coreR
            )
        )

        // Outer dashed ring
        var ringPath = Path()
        ringPath.addArc(center: CGPoint(x: vx, y: vy), radius: zoneR * 0.95,
                        startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        context.stroke(ringPath,
                       with: .color(vortexColor.opacity(Double(fadeIn * 0.15))),
                       style: StrokeStyle(lineWidth: 0.8, dash: [3, 6]))
    }

    // MARK: - Laser Beam
    private func drawLaserBeam(context: GraphicsContext, o: Obstacle, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        let fadeIn = min(1, (o.life > 0.5 ? 1 : o.life * 2))
        let laserColor = Color(red: 0.94, green: 0.27, blue: 0.27)
        let beamPulse = 0.7 + 0.3 * sin(o.pulsePhase)

        // Draw two opposing beams (180° apart)
        for offset: CGFloat in [0, .pi] {
            let beamAngle = o.laserAngle + offset
            let startR = GameConstants.minRadius + 5
            let endR = o.laserLength

            let sx = cx + cos(beamAngle) * startR
            let sy = cy + sin(beamAngle) * startR
            let ex = cx + cos(beamAngle) * endR
            let ey = cy + sin(beamAngle) * endR

            // Wide glow beam
            var glowPath = Path()
            glowPath.move(to: CGPoint(x: sx, y: sy))
            glowPath.addLine(to: CGPoint(x: ex, y: ey))
            context.stroke(glowPath,
                           with: .color(laserColor.opacity(Double(fadeIn * 0.08 * beamPulse))),
                           lineWidth: 12)

            // Medium beam
            context.stroke(glowPath,
                           with: .color(laserColor.opacity(Double(fadeIn * 0.2 * beamPulse))),
                           lineWidth: 4)

            // Core beam (bright)
            context.stroke(glowPath,
                           with: .color(laserColor.opacity(Double(fadeIn * 0.7 * beamPulse))),
                           lineWidth: 1.5)

            // Bright core line
            context.stroke(glowPath,
                           with: .color(Color(red: 1.0, green: 0.7, blue: 0.7).opacity(Double(fadeIn * 0.5 * beamPulse))),
                           lineWidth: 0.5)

            // Tip glow at the end point
            let tipR: CGFloat = 6 * beamPulse
            context.fill(
                Path(ellipseIn: CGRect(x: ex - tipR, y: ey - tipR, width: tipR * 2, height: tipR * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: laserColor.opacity(Double(fadeIn * 0.3)), location: 0),
                        .init(color: .clear, location: 1)
                    ]),
                    center: CGPoint(x: ex, y: ey), startRadius: 0, endRadius: tipR
                )
            )
        }

        // Bright source at center (laser emitter)
        let emitR: CGFloat = 8 * beamPulse
        context.fill(
            Path(ellipseIn: CGRect(x: cx - emitR, y: cy - emitR, width: emitR * 2, height: emitR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: laserColor.opacity(Double(fadeIn * 0.4)), location: 0),
                    .init(color: laserColor.opacity(Double(fadeIn * 0.1)), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: emitR
            )
        )

        // Warning indicator ring (rotating dashes aligned with laser)
        var warnPath = Path()
        for seg in 0..<2 {
            let sa = o.laserAngle + CGFloat(seg) * .pi - 0.15
            let ea = o.laserAngle + CGFloat(seg) * .pi + 0.15
            warnPath.addArc(center: CGPoint(x: cx, y: cy), radius: GameConstants.minRadius + 8,
                            startAngle: .radians(Double(sa)),
                            endAngle: .radians(Double(ea)),
                            clockwise: false)
        }
        context.stroke(warnPath,
                       with: .color(laserColor.opacity(Double(fadeIn * 0.5))),
                       lineWidth: 2)
    }

    // MARK: - Powerups
    private func drawPowerups(context: GraphicsContext, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        for p in engine.powerups {
            let ppx = cx + cos(p.angle) * p.radius
            let ppy = cy + sin(p.angle) * p.radius + sin(p.bobPhase) * 3
            let fadeIn = min(1, (12 - p.life) * 4)
            let fadeOut = min(1, p.life * 2)
            let alpha = fadeIn * fadeOut

            var ctx = context
            ctx.opacity = Double(alpha)

            switch p.type {
            case .point:
                drawPointPowerup(context: ctx, x: ppx, y: ppy, spin: p.spinAngle, pulse: pulse)
            case .shield:
                drawShieldPowerup(context: ctx, x: ppx, y: ppy, spin: p.spinAngle, pulse: pulse)
            case .slowmo:
                drawSlowmoPowerup(context: ctx, x: ppx, y: ppy, spin: p.spinAngle, pulse: pulse)
            case .extraLife:
                drawExtraLifePowerup(context: ctx, x: ppx, y: ppy, spin: p.spinAngle, pulse: pulse)
            }
        }
    }

    private func drawPointPowerup(context: GraphicsContext, x: CGFloat, y: CGFloat, spin: CGFloat, pulse: CGFloat) {
        var ctx = context
        ctx.translateBy(x: x, y: y)

        // Light rays
        for r in 0..<4 {
            let rayAngle = spin + CGFloat(r) * .pi / 2
            let rayLen = 14 + sin(pulse * 4 + CGFloat(r)) * 4
            let rayAlpha = 0.15 + sin(pulse * 3) * 0.08
            var rayPath = Path()
            rayPath.move(to: .zero)
            rayPath.addLine(to: CGPoint(x: cos(rayAngle) * rayLen, y: sin(rayAngle) * rayLen))
            ctx.stroke(rayPath, with: .color(Color(red: 0.39, green: 0.4, blue: 0.95).opacity(Double(rayAlpha))),
                       lineWidth: 1)
        }

        // Outer glow
        ctx.fill(
            Path(ellipseIn: CGRect(x: -14, y: -14, width: 28, height: 28)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.39, green: 0.4, blue: 0.95).opacity(0.2), location: 0),
                    .init(color: .clear, location: 1)
                ]),
                center: .zero, startRadius: 0, endRadius: 14
            )
        )

        // Diamond
        var dCtx = ctx
        dCtx.rotate(by: .radians(Double(spin)))

        var diamond = Path()
        diamond.move(to: CGPoint(x: 0, y: -8))
        diamond.addLine(to: CGPoint(x: 6, y: 0))
        diamond.addLine(to: CGPoint(x: 0, y: 8))
        diamond.addLine(to: CGPoint(x: -6, y: 0))
        diamond.closeSubpath()

        dCtx.fill(diamond, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.51, green: 0.55, blue: 0.97),
                Color(red: 0.39, green: 0.4, blue: 0.95),
                Color(red: 0.31, green: 0.27, blue: 0.9)
            ]),
            startPoint: CGPoint(x: -6, y: -8), endPoint: CGPoint(x: 6, y: 8)
        ))

        // Diamond shine
        var shine = Path()
        shine.move(to: CGPoint(x: 0, y: -8))
        shine.addLine(to: CGPoint(x: 6, y: 0))
        shine.addLine(to: CGPoint(x: 0, y: -2))
        shine.closeSubpath()
        dCtx.fill(shine, with: .color(.white.opacity(0.25)))
    }

    private func drawShieldPowerup(context: GraphicsContext, x: CGFloat, y: CGFloat, spin: CGFloat, pulse: CGFloat) {
        var ctx = context
        ctx.translateBy(x: x, y: y)

        let shPulse = 0.8 + 0.2 * sin(pulse * 4)
        let glowR = 16 * shPulse

        // Pulsing glow
        ctx.fill(
            Path(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.02, green: 0.71, blue: 0.83).opacity(0.15), location: 0),
                    .init(color: .clear, location: 1)
                ]),
                center: .zero, startRadius: 0, endRadius: glowR
            )
        )

        // Rotating ring segments
        for s in 0..<3 {
            let sa = spin + CGFloat(s) * (.pi * 2 / 3)
            var segPath = Path()
            segPath.addArc(center: .zero, radius: 9,
                           startAngle: .radians(Double(sa)),
                           endAngle: .radians(Double(sa + 1.2)),
                           clockwise: false)
            ctx.stroke(segPath, with: .color(Color(red: 0.02, green: 0.71, blue: 0.83)), lineWidth: 2)
        }

        // Inner shield icon (hexagonal)
        var shield = Path()
        shield.move(to: CGPoint(x: 0, y: -5))
        shield.addLine(to: CGPoint(x: 4, y: -2))
        shield.addLine(to: CGPoint(x: 4, y: 2))
        shield.addLine(to: CGPoint(x: 0, y: 5))
        shield.addLine(to: CGPoint(x: -4, y: 2))
        shield.addLine(to: CGPoint(x: -4, y: -2))
        shield.closeSubpath()
        ctx.fill(shield, with: .color(Color(red: 0.02, green: 0.71, blue: 0.83).opacity(0.6)))
        ctx.stroke(shield, with: .color(Color(red: 0.02, green: 0.71, blue: 0.83)), lineWidth: 0.8)
    }

    private func drawSlowmoPowerup(context: GraphicsContext, x: CGFloat, y: CGFloat, spin: CGFloat, pulse: CGFloat) {
        var ctx = context
        ctx.translateBy(x: x, y: y)

        let clockColor = Color(red: 0.96, green: 0.62, blue: 0.04)
        let shPulse = 0.85 + 0.15 * sin(pulse * 3)
        let glowR = 14 * shPulse

        // Pulsing glow
        ctx.fill(
            Path(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: clockColor.opacity(0.2), location: 0),
                    .init(color: .clear, location: 1)
                ]),
                center: .zero, startRadius: 0, endRadius: glowR
            )
        )

        // Clock face (circle)
        var clockRing = Path()
        clockRing.addArc(center: .zero, radius: 8,
                         startAngle: .zero, endAngle: .degrees(360), clockwise: false)
        ctx.stroke(clockRing, with: .color(clockColor.opacity(0.7)), lineWidth: 1.5)

        // Clock hands
        let hourAngle = spin * 0.5
        let minuteAngle = spin * 2
        var hourHand = Path()
        hourHand.move(to: .zero)
        hourHand.addLine(to: CGPoint(x: cos(hourAngle - .pi / 2) * 4,
                                      y: sin(hourAngle - .pi / 2) * 4))
        ctx.stroke(hourHand, with: .color(clockColor), lineWidth: 1.5)

        var minuteHand = Path()
        minuteHand.move(to: .zero)
        minuteHand.addLine(to: CGPoint(x: cos(minuteAngle - .pi / 2) * 6,
                                        y: sin(minuteAngle - .pi / 2) * 6))
        ctx.stroke(minuteHand, with: .color(clockColor.opacity(0.8)), lineWidth: 1)

        // Center dot
        ctx.fill(
            Path(ellipseIn: CGRect(x: -1.5, y: -1.5, width: 3, height: 3)),
            with: .color(clockColor)
        )

        // Tick marks (12 o'clock and 6 o'clock)
        for t in 0..<4 {
            let ta = CGFloat(t) * .pi / 2
            let ix = cos(ta) * 6.5, iy = sin(ta) * 6.5
            let ox = cos(ta) * 8, oy = sin(ta) * 8
            var tickPath = Path()
            tickPath.move(to: CGPoint(x: ix, y: iy))
            tickPath.addLine(to: CGPoint(x: ox, y: oy))
            ctx.stroke(tickPath, with: .color(clockColor.opacity(0.5)), lineWidth: 0.8)
        }
    }

    private func drawExtraLifePowerup(context: GraphicsContext, x: CGFloat, y: CGFloat, spin: CGFloat, pulse: CGFloat) {
        var ctx = context
        ctx.translateBy(x: x, y: y)

        let heartColor = Color(red: 0.13, green: 0.85, blue: 0.37)
        let shPulse = 0.85 + 0.15 * sin(pulse * 4)
        let glowR = 16 * shPulse

        // Pulsing glow
        ctx.fill(
            Path(ellipseIn: CGRect(x: -glowR, y: -glowR, width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: heartColor.opacity(0.2), location: 0),
                    .init(color: .clear, location: 1)
                ]),
                center: .zero, startRadius: 0, endRadius: glowR
            )
        )

        // Rotating ring segments
        for s in 0..<3 {
            let sa = spin + CGFloat(s) * (.pi * 2 / 3)
            var segPath = Path()
            segPath.addArc(center: .zero, radius: 10,
                           startAngle: .radians(Double(sa)),
                           endAngle: .radians(Double(sa + 1.0)),
                           clockwise: false)
            ctx.stroke(segPath, with: .color(heartColor.opacity(0.5)), lineWidth: 1.5)
        }

        // Heart shape
        let heartScale = shPulse * 0.85
        var heart = Path()
        // Draw a simple heart using bezier curves
        heart.move(to: CGPoint(x: 0, y: 3 * heartScale))
        heart.addCurve(
            to: CGPoint(x: 0, y: -3 * heartScale),
            control1: CGPoint(x: -8 * heartScale, y: 0),
            control2: CGPoint(x: -8 * heartScale, y: -6 * heartScale)
        )
        heart.addCurve(
            to: CGPoint(x: 0, y: 3 * heartScale),
            control1: CGPoint(x: 8 * heartScale, y: -6 * heartScale),
            control2: CGPoint(x: 8 * heartScale, y: 0)
        )
        heart.closeSubpath()
        ctx.fill(heart, with: .color(heartColor.opacity(0.7)))

        // Plus sign on heart
        var plusPath = Path()
        plusPath.move(to: CGPoint(x: 0, y: -2.5 * heartScale))
        plusPath.addLine(to: CGPoint(x: 0, y: 1 * heartScale))
        plusPath.move(to: CGPoint(x: -1.8 * heartScale, y: -0.8 * heartScale))
        plusPath.addLine(to: CGPoint(x: 1.8 * heartScale, y: -0.8 * heartScale))
        ctx.stroke(plusPath, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
    }

    // MARK: - Player
    private func drawPlayer(context: GraphicsContext, cx: CGFloat, cy: CGFloat, pulse: CGFloat) {
        guard engine.player.alive || engine.player.invincible > 0 else { return }

        let player = engine.player
        let px = cx + cos(player.angle) * player.radius
        let py = cy + sin(player.angle) * player.radius

        // Blink during invincibility
        if player.invincible > 0 && !engine.playerAbsorbing {
            let blink = sin(pulse * 20)
            if blink < 0 { return }
        }

        // Black hole absorption spaghettification
        let absorbT = engine.playerAbsorbProgress  // 0→1
        let absorbScale = max(0.05, 1.0 - absorbT * 0.85)        // ship shrinks to ~15%
        let absorbStretchY = 1.0 + absorbT * 1.8                   // stretches toward center
        let absorbSquishX = max(0.15, 1.0 - absorbT * 0.7)        // squishes horizontally
        let absorbAlpha = max(0.0, 1.0 - absorbT * absorbT)       // fades quadratically

        // Trail (ribbon style)
        if player.trail.count > 2 {
            for i in 1..<player.trail.count {
                let t = player.trail[i]
                let prev = player.trail[i - 1]
                let progress = CGFloat(i) / CGFloat(player.trail.count)
                let width = GameConstants.playerSize * progress * 0.6

                let trailColor: Color = player.shielded
                    ? Color(red: 0.02, green: 0.71, blue: 0.83).opacity(Double(progress * 0.15))
                    : Color(red: 0.39, green: 0.4, blue: 0.95).opacity(Double(progress * 0.12))

                var path = Path()
                path.move(to: CGPoint(x: prev.x, y: prev.y))
                path.addLine(to: CGPoint(x: t.x, y: t.y))
                context.stroke(path, with: .color(trailColor),
                               style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }

        // Shield ring
        if player.shielded {
            let shieldAlpha = 0.3 + 0.15 * sin(pulse * 5)
            let shieldColor = Color(red: 0.02, green: 0.71, blue: 0.83)

            // Shield glow
            let shieldR = GameConstants.playerSize + 12
            context.fill(
                Path(ellipseIn: CGRect(x: px - shieldR, y: py - shieldR,
                                       width: shieldR * 2, height: shieldR * 2)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: shieldColor.opacity(Double(shieldAlpha * 0.5)), location: 0),
                        .init(color: .clear, location: 1)
                    ]),
                    center: CGPoint(x: px, y: py),
                    startRadius: GameConstants.playerSize,
                    endRadius: shieldR
                )
            )

            // Rotating segments
            for s in 0..<4 {
                let sa = pulse * 2 + CGFloat(s) * .pi / 2
                var segPath = Path()
                segPath.addArc(center: CGPoint(x: px, y: py), radius: GameConstants.playerSize + 6,
                               startAngle: .radians(Double(sa)),
                               endAngle: .radians(Double(sa + 0.8)),
                               clockwise: false)
                context.stroke(segPath,
                               with: .color(shieldColor.opacity(Double(shieldAlpha))),
                               lineWidth: 1.5)
            }
        }

        // Ship rotation
        let moveAngle = player.angle + .pi / 2
        var shipCtx = context
        shipCtx.opacity = absorbAlpha
        shipCtx.translateBy(x: px, y: py)
        // During absorption: rotate toward center and spaghettify
        if absorbT > 0 {
            let toCenter = atan2(cy - py, cx - px) + .pi / 2
            // Blend from normal flight angle to pointing-at-center
            let blendedAngle = moveAngle * (1 - absorbT) + toCenter * absorbT
            shipCtx.rotate(by: .radians(Double(blendedAngle)))
            shipCtx.scaleBy(x: absorbSquishX * absorbScale, y: absorbStretchY * absorbScale)
        } else {
            shipCtx.rotate(by: .radians(Double(moveAngle)))
        }

        let S = GameConstants.playerSize
        let thrustLevel = max(player.thrustIn, player.thrustOut)

        // Engine exhaust
        if thrustLevel > 0.05 {
            let isThrusting = player.thrustIn > player.thrustOut
            let exhaustColor = isThrusting
                ? Color(red: 0.94, green: 0.27, blue: 0.27)
                : Color(red: 0.13, green: 0.77, blue: 0.37)
            let exhaustLen = 8 + thrustLevel * 12 + CGFloat.random(in: 0...1) * thrustLevel * 6

            // Exhaust glow
            let ellipseW = (3 + thrustLevel * 2) * 2
            let ellipseH = exhaustLen * 0.5 * 2
            shipCtx.fill(
                Path(ellipseIn: CGRect(x: -ellipseW / 2, y: S * 0.5 + exhaustLen * 0.3 - ellipseH / 2,
                                       width: ellipseW, height: ellipseH)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: exhaustColor.opacity(0.6), location: 0),
                        .init(color: exhaustColor.opacity(0.3), location: 0.3),
                        .init(color: .clear, location: 1)
                    ]),
                    center: CGPoint(x: 0, y: S * 0.5 + exhaustLen * 0.3),
                    startRadius: 0, endRadius: exhaustLen * 0.5
                )
            )

            // Inner flame
            var flamePath = Path()
            flamePath.move(to: CGPoint(x: -2.5 * thrustLevel, y: S * 0.4))
            flamePath.addQuadCurve(to: CGPoint(x: 0, y: S * 0.5 + exhaustLen * 0.7),
                                   control: CGPoint(x: -1, y: S * 0.5 + exhaustLen * 0.4))
            flamePath.addQuadCurve(to: CGPoint(x: 2.5 * thrustLevel, y: S * 0.4),
                                   control: CGPoint(x: 1, y: S * 0.5 + exhaustLen * 0.4))
            shipCtx.fill(flamePath, with: .color(.white.opacity(0.5)))
        }

        // Ship body glow (brighter for gameplay visibility)
        let glowColor: Color = player.shielded
            ? Color(red: 0.02, green: 0.71, blue: 0.83)
            : Color(red: 0.45, green: 0.48, blue: 0.98)
        shipCtx.fill(
            Path(ellipseIn: CGRect(x: -S * 2.5, y: -S * 2.5, width: S * 5, height: S * 5)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: glowColor.opacity(0.14), location: 0),
                    .init(color: glowColor.opacity(0.04), location: 0.5),
                    .init(color: .clear, location: 1)
                ]),
                center: .zero, startRadius: 0, endRadius: S * 2.5
            )
        )

        // ──── Wing shadows (depth under wings) ────
        for side: CGFloat in [-1, 1] {
            var shadowPath = Path()
            shadowPath.move(to: CGPoint(x: side * S * 0.33, y: S * 0.13))
            shadowPath.addLine(to: CGPoint(x: side * S * 1.13, y: S * 0.83))
            shadowPath.addLine(to: CGPoint(x: side * S * 0.93, y: S * 0.68))
            shadowPath.addLine(to: CGPoint(x: side * S * 0.23, y: S * 0.03))
            shadowPath.closeSubpath()
            shipCtx.fill(shadowPath, with: .color(Color.black.opacity(0.25)))
        }

        // ──── Wings with 3D bevel ────
        let wingBaseColor: Color = player.shielded
            ? Color(red: 0.08, green: 0.55, blue: 0.65) : Color(red: 0.30, green: 0.30, blue: 0.42)
        let wingDarkColor: Color = player.shielded
            ? Color(red: 0.03, green: 0.35, blue: 0.45) : Color(red: 0.15, green: 0.15, blue: 0.25)

        for side: CGFloat in [-1, 1] {
            var wingPath = Path()
            wingPath.move(to: CGPoint(x: side * S * 0.3, y: S * 0.1))
            wingPath.addLine(to: CGPoint(x: side * S * 1.1, y: S * 0.8))
            wingPath.addLine(to: CGPoint(x: side * S * 0.9, y: S * 0.65))
            wingPath.addLine(to: CGPoint(x: side * S * 0.2, y: 0))
            wingPath.closeSubpath()

            // Wing 3D gradient (light top, dark bottom)
            shipCtx.fill(wingPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: wingBaseColor, location: 0),
                    .init(color: wingDarkColor, location: 0.7),
                    .init(color: wingDarkColor.opacity(0.8), location: 1)
                ]),
                startPoint: CGPoint(x: side * S * 0.2, y: -S * 0.2),
                endPoint: CGPoint(x: side * S * 0.8, y: S * 0.9)
            ))

            // Wing center ridge line (structural strut)
            var ridgeLine = Path()
            ridgeLine.move(to: CGPoint(x: side * S * 0.25, y: S * 0.05))
            ridgeLine.addLine(to: CGPoint(x: side * S * 1.0, y: S * 0.72))
            shipCtx.stroke(ridgeLine, with: .color(.white.opacity(0.1)), lineWidth: 0.6)

            // Wing leading edge highlight
            var edgeLine = Path()
            edgeLine.move(to: CGPoint(x: side * S * 0.3, y: S * 0.1))
            edgeLine.addLine(to: CGPoint(x: side * S * 1.1, y: S * 0.8))
            shipCtx.stroke(edgeLine, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
        }

        // ──── Main hull with 3D metallic finish ────
        var hullPath = Path()
        hullPath.move(to: CGPoint(x: 0, y: -S * 1.2))
        hullPath.addLine(to: CGPoint(x: -S * 0.45, y: -S * 0.2))
        hullPath.addLine(to: CGPoint(x: -S * 0.5, y: S * 0.3))
        hullPath.addLine(to: CGPoint(x: -S * 0.3, y: S * 0.55))
        hullPath.addLine(to: CGPoint(x: S * 0.3, y: S * 0.55))
        hullPath.addLine(to: CGPoint(x: S * 0.5, y: S * 0.3))
        hullPath.addLine(to: CGPoint(x: S * 0.45, y: -S * 0.2))
        hullPath.closeSubpath()

        if player.shielded {
            shipCtx.fill(hullPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.25, green: 0.92, blue: 0.98), location: 0),
                    .init(color: Color(red: 0.13, green: 0.83, blue: 0.93), location: 0.25),
                    .init(color: Color(red: 0.06, green: 0.65, blue: 0.78), location: 0.55),
                    .init(color: Color(red: 0.03, green: 0.50, blue: 0.62), location: 0.8),
                    .init(color: Color(red: 0.02, green: 0.40, blue: 0.52), location: 1)
                ]),
                startPoint: CGPoint(x: -S * 0.5, y: -S * 1.2),
                endPoint: CGPoint(x: S * 0.3, y: S * 0.55)
            ))
        } else {
            // Silver metallic hull with 3D lighting (bright for gameplay clarity)
            shipCtx.fill(hullPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.96, green: 0.96, blue: 1.0), location: 0),
                    .init(color: Color(red: 0.85, green: 0.85, blue: 0.92), location: 0.15),
                    .init(color: Color(red: 0.70, green: 0.70, blue: 0.80), location: 0.35),
                    .init(color: Color(red: 0.55, green: 0.55, blue: 0.66), location: 0.6),
                    .init(color: Color(red: 0.40, green: 0.40, blue: 0.52), location: 0.8),
                    .init(color: Color(red: 0.30, green: 0.30, blue: 0.44), location: 1)
                ]),
                startPoint: CGPoint(x: -S * 0.5, y: -S * 1.2),
                endPoint: CGPoint(x: S * 0.3, y: S * 0.55)
            ))
        }

        // Center ridge highlight (raised spine of hull)
        var ridgeHL = Path()
        ridgeHL.move(to: CGPoint(x: 0, y: -S * 1.1))
        ridgeHL.addLine(to: CGPoint(x: 0, y: S * 0.5))
        shipCtx.stroke(ridgeHL, with: .color(.white.opacity(player.shielded ? 0.2 : 0.12)), lineWidth: 0.8)

        // Specular highlight on hull (metallic reflection strip)
        var specPath = Path()
        specPath.move(to: CGPoint(x: -S * 0.15, y: -S * 0.8))
        specPath.addQuadCurve(to: CGPoint(x: -S * 0.1, y: S * 0.1),
                               control: CGPoint(x: -S * 0.35, y: -S * 0.3))
        specPath.addLine(to: CGPoint(x: -S * 0.05, y: S * 0.1))
        specPath.addQuadCurve(to: CGPoint(x: -S * 0.05, y: -S * 0.85),
                               control: CGPoint(x: -S * 0.2, y: -S * 0.3))
        specPath.closeSubpath()
        shipCtx.fill(specPath, with: .color(.white.opacity(0.08)))

        // Panel seam lines (horizontal)
        for lineY in [-S * 0.1, S * 0.2] {
            let halfW = S * 0.46 - abs(lineY) * 0.08
            var panelLine = Path()
            panelLine.move(to: CGPoint(x: -halfW, y: lineY))
            panelLine.addLine(to: CGPoint(x: halfW, y: lineY))
            shipCtx.stroke(panelLine, with: .color(Color.black.opacity(0.15)), lineWidth: 0.4)
            var panelHL = Path()
            panelHL.move(to: CGPoint(x: -halfW, y: lineY + 0.5))
            panelHL.addLine(to: CGPoint(x: halfW, y: lineY + 0.5))
            shipCtx.stroke(panelHL, with: .color(.white.opacity(0.06)), lineWidth: 0.3)
        }

        // Hull edge bevels (3D edge lighting)
        let leftEdgeCol: Color = player.shielded
            ? Color(red: 0.2, green: 0.9, blue: 1.0).opacity(0.3) : Color.white.opacity(0.2)

        // Left edge (light facing)
        var leftEdge = Path()
        leftEdge.move(to: CGPoint(x: 0, y: -S * 1.2))
        leftEdge.addLine(to: CGPoint(x: -S * 0.45, y: -S * 0.2))
        leftEdge.addLine(to: CGPoint(x: -S * 0.5, y: S * 0.3))
        leftEdge.addLine(to: CGPoint(x: -S * 0.3, y: S * 0.55))
        shipCtx.stroke(leftEdge, with: .color(leftEdgeCol), lineWidth: 0.7)

        // Right edge (shadow side)
        var rightEdge = Path()
        rightEdge.move(to: CGPoint(x: 0, y: -S * 1.2))
        rightEdge.addLine(to: CGPoint(x: S * 0.45, y: -S * 0.2))
        rightEdge.addLine(to: CGPoint(x: S * 0.5, y: S * 0.3))
        rightEdge.addLine(to: CGPoint(x: S * 0.3, y: S * 0.55))
        shipCtx.stroke(rightEdge, with: .color(Color.black.opacity(0.15)), lineWidth: 0.5)

        // Bottom edge
        var bottomEdge = Path()
        bottomEdge.move(to: CGPoint(x: -S * 0.3, y: S * 0.55))
        bottomEdge.addLine(to: CGPoint(x: S * 0.3, y: S * 0.55))
        shipCtx.stroke(bottomEdge, with: .color(Color.black.opacity(0.1)), lineWidth: 0.5)

        // ──── Enhanced cockpit with 3D glass canopy ────
        // Cockpit frame/bezel
        var cockpitFrame = Path()
        cockpitFrame.move(to: CGPoint(x: 0, y: -S * 0.9))
        cockpitFrame.addLine(to: CGPoint(x: -S * 0.2, y: -S * 0.2))
        cockpitFrame.addQuadCurve(to: CGPoint(x: S * 0.2, y: -S * 0.2),
                                   control: CGPoint(x: 0, y: -S * 0.08))
        cockpitFrame.closeSubpath()
        shipCtx.fill(cockpitFrame, with: .color(Color(red: 0.15, green: 0.15, blue: 0.22).opacity(0.5)))

        // Cockpit glass
        var cockpitPath = Path()
        cockpitPath.move(to: CGPoint(x: 0, y: -S * 0.85))
        cockpitPath.addLine(to: CGPoint(x: -S * 0.18, y: -S * 0.2))
        cockpitPath.addQuadCurve(to: CGPoint(x: S * 0.18, y: -S * 0.2),
                                  control: CGPoint(x: 0, y: -S * 0.1))
        cockpitPath.closeSubpath()

        if player.shielded {
            shipCtx.fill(cockpitPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.5, green: 0.95, blue: 1.0), location: 0),
                    .init(color: Color(red: 0.2, green: 0.85, blue: 0.95), location: 0.3),
                    .init(color: Color(red: 0.08, green: 0.70, blue: 0.82), location: 0.6),
                    .init(color: Color(red: 0.03, green: 0.50, blue: 0.65), location: 1)
                ]),
                startPoint: CGPoint(x: 0, y: -S * 0.85),
                endPoint: CGPoint(x: 0, y: -S * 0.1)
            ))
        } else {
            shipCtx.fill(cockpitPath, with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color(red: 0.72, green: 0.78, blue: 1.0), location: 0),
                    .init(color: Color(red: 0.52, green: 0.56, blue: 0.98), location: 0.25),
                    .init(color: Color(red: 0.38, green: 0.38, blue: 0.93), location: 0.5),
                    .init(color: Color(red: 0.24, green: 0.22, blue: 0.78), location: 0.75),
                    .init(color: Color(red: 0.16, green: 0.14, blue: 0.58), location: 1)
                ]),
                startPoint: CGPoint(x: 0, y: -S * 0.85),
                endPoint: CGPoint(x: 0, y: -S * 0.1)
            ))
        }

        // Cockpit glass reflection (main)
        var reflPath = Path()
        reflPath.move(to: CGPoint(x: -S * 0.04, y: -S * 0.78))
        reflPath.addLine(to: CGPoint(x: -S * 0.13, y: -S * 0.4))
        reflPath.addLine(to: CGPoint(x: -S * 0.04, y: -S * 0.35))
        reflPath.closeSubpath()
        shipCtx.fill(reflPath, with: .color(.white.opacity(0.25)))

        // Secondary reflection spot
        var refl2 = Path()
        refl2.move(to: CGPoint(x: S * 0.06, y: -S * 0.55))
        refl2.addLine(to: CGPoint(x: S * 0.1, y: -S * 0.38))
        refl2.addLine(to: CGPoint(x: S * 0.05, y: -S * 0.35))
        refl2.closeSubpath()
        shipCtx.fill(refl2, with: .color(.white.opacity(0.12)))

        // Cockpit edge highlight
        shipCtx.stroke(cockpitPath, with: .color(.white.opacity(0.15)), lineWidth: 0.5)

        // ──── Enhanced engine nozzles ────
        for side: CGFloat in [-1, 1] {
            // Nozzle housing
            var nozzlePath = Path()
            nozzlePath.move(to: CGPoint(x: side * S * 0.15 - 2.5, y: S * 0.42))
            nozzlePath.addLine(to: CGPoint(x: side * S * 0.15 + 2.5, y: S * 0.42))
            nozzlePath.addLine(to: CGPoint(x: side * S * 0.15 + 3, y: S * 0.55))
            nozzlePath.addLine(to: CGPoint(x: side * S * 0.15 - 3, y: S * 0.55))
            nozzlePath.closeSubpath()

            let nozzleBaseColor = player.shielded
                ? Color(red: 0.04, green: 0.45, blue: 0.55) : Color(red: 0.22, green: 0.22, blue: 0.35)
            shipCtx.fill(nozzlePath, with: .linearGradient(
                Gradient(colors: [nozzleBaseColor.opacity(0.9), nozzleBaseColor.opacity(0.5)]),
                startPoint: CGPoint(x: 0, y: S * 0.42), endPoint: CGPoint(x: 0, y: S * 0.55)
            ))

            // Nozzle glow when thrusting
            if thrustLevel > 0.1 {
                let glowColor = player.thrustIn > player.thrustOut
                    ? Color(red: 0.99, green: 0.65, blue: 0.65)
                    : Color(red: 0.53, green: 0.94, blue: 0.67)
                let nozzleGlowR: CGFloat = 3 + thrustLevel * 2
                shipCtx.fill(
                    Path(ellipseIn: CGRect(x: side * S * 0.15 - nozzleGlowR, y: S * 0.5 - nozzleGlowR * 0.5,
                                           width: nozzleGlowR * 2, height: nozzleGlowR)),
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: glowColor.opacity(0.7), location: 0),
                            .init(color: glowColor.opacity(0.2), location: 0.5),
                            .init(color: .clear, location: 1)
                        ]),
                        center: CGPoint(x: side * S * 0.15, y: S * 0.5),
                        startRadius: 0, endRadius: nozzleGlowR
                    )
                )
            }
        }

        // Wing tip lights
        let blinkAlpha = sin(pulse * 6) > 0 ? 0.8 : 0.2

        // Left wing tip (red)
        shipCtx.fill(
            Path(ellipseIn: CGRect(x: -S * 1.05 - 1.2, y: S * 0.75 - 1.2, width: 2.4, height: 2.4)),
            with: .color(Color(red: 0.94, green: 0.27, blue: 0.27).opacity(blinkAlpha))
        )
        if blinkAlpha > 0.5 {
            shipCtx.fill(
                Path(ellipseIn: CGRect(x: -S * 1.05 - 4, y: S * 0.75 - 4, width: 8, height: 8)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.4), location: 0),
                        .init(color: .clear, location: 1)
                    ]),
                    center: CGPoint(x: -S * 1.05, y: S * 0.75), startRadius: 0, endRadius: 4
                )
            )
        }

        // Right wing tip (green)
        shipCtx.fill(
            Path(ellipseIn: CGRect(x: S * 1.05 - 1.2, y: S * 0.75 - 1.2, width: 2.4, height: 2.4)),
            with: .color(Color(red: 0.13, green: 0.77, blue: 0.37).opacity(blinkAlpha))
        )
        if blinkAlpha > 0.5 {
            shipCtx.fill(
                Path(ellipseIn: CGRect(x: S * 1.05 - 4, y: S * 0.75 - 4, width: 8, height: 8)),
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.4), location: 0),
                        .init(color: .clear, location: 1)
                    ]),
                    center: CGPoint(x: S * 1.05, y: S * 0.75), startRadius: 0, endRadius: 4
                )
            )
        }

        // Nose highlight
        var nosePath = Path()
        nosePath.move(to: CGPoint(x: 0, y: -S * 1.2))
        nosePath.addLine(to: CGPoint(x: -S * 0.1, y: -S * 0.6))
        nosePath.addLine(to: CGPoint(x: 0, y: -S * 0.7))
        nosePath.closeSubpath()
        shipCtx.fill(nosePath, with: .color(.white.opacity(0.12)))

        // Tether line (very subtle)
        var tether = Path()
        tether.move(to: CGPoint(x: cx - px, y: cy - py))
        tether.addLine(to: .zero)
        shipCtx.stroke(tether, with: .color(Color(red: 0.39, green: 0.4, blue: 0.95).opacity(0.03)), lineWidth: 0.5)
    }

    // MARK: - Particles
    private func drawParticles(context: GraphicsContext) {
        for p in engine.particles {
            let a = p.life / p.maxLife

            var ctx = context
            ctx.opacity = Double(a * 0.8)
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - p.size * a, y: p.y - p.size * a,
                                       width: p.size * a * 2, height: p.size * a * 2)),
                with: .color(p.color)
            )

            // Big particles get glow
            if p.size > 2 {
                var glowCtx = context
                glowCtx.opacity = Double(a * 0.2)
                glowCtx.fill(
                    Path(ellipseIn: CGRect(x: p.x - p.size * a * 2, y: p.y - p.size * a * 2,
                                           width: p.size * a * 4, height: p.size * a * 4)),
                    with: .color(p.color)
                )
            }
        }
    }

}
