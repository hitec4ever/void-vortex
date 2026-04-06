import SwiftUI
import Combine

class GameEngine: ObservableObject {
    // MARK: - Published state
    @Published var state: GameState = .start
    @Published var score: Int = 0
    @Published var hiScore: Int = 0
    @Published var gameTime: CGFloat = 0
    @Published var level: Int = 1
    @Published var lives: Int = GameConstants.startLives
    @Published var player = Player()
    @Published var obstacles: [Obstacle] = []
    @Published var powerups: [Powerup] = []
    @Published var particles: [Particle] = []
    @Published var screenShake: CGFloat = 0
    @Published var pulsePhase: CGFloat = 0
    @Published var levelUpName: String = ""
    @Published var levelUpElement: String = ""
    @Published var slowmoActive: Bool = false
    @Published var lifeLostTrigger: Int = 0  // increments on each life loss
    @Published var nearMissTrigger: Int = 0  // increments on near-miss events
    @Published var showLevelUpBanner: Bool = false  // non-blocking level-up overlay

    // MARK: - Black hole absorption
    var playerAbsorbing: Bool = false
    var playerAbsorbProgress: CGFloat = 0    // 0→1 over absorption duration

    /// 0 = far away (maxRadius), 1 = at event horizon (minRadius)
    /// Used by renderer for proximity-based visual feedback
    var proximityFactor: CGFloat {
        let range = GameConstants.maxRadius - GameConstants.minRadius
        guard range > 0 else { return 0 }
        let clamped = max(GameConstants.minRadius, min(GameConstants.maxRadius, player.radius))
        return 1.0 - (clamped - GameConstants.minRadius) / range
    }

    // MARK: - Internal state
    var inputIn: Bool = false
    var inputOut: Bool = false
    var stars: [Star] = []
    var accretionParticles: [AccretionParticle] = []
    var slowmoTimer: CGFloat = 0
    private var nearMissCooldown: CGFloat = 0
    private var gracePeriod: CGFloat = 3.0
    private var spawnAccumulator: CGFloat = 0
    private var ringSpawnAccumulator: CGFloat = 0

    // MARK: - Display link
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0

    // MARK: - Sound
    let sound = SoundEngine()

    // MARK: - Center point
    var centerX: CGFloat = 195
    var centerY: CGFloat = 402

    // MARK: - Previous run tracking (for Game Over comparisons)
    var previousScore: Int = 0
    var previousTime: CGFloat = 0
    var previousLevel: Int = 0
    var isNewHighScore: Bool = false
    var isNewTimeBest: Bool = false
    var bestTime: CGFloat = 0

    init() {
        hiScore = UserDefaults.standard.integer(forKey: "gw_hiscore")
        bestTime = CGFloat(UserDefaults.standard.double(forKey: "gw_besttime"))
        generateStars()
        generateAccretionDisk()
    }

    // MARK: - Stars
    func generateStars() {
        stars = (0..<150).map { _ in
            Star(
                x: CGFloat.random(in: 0...390),
                y: CGFloat.random(in: 0...844),
                size: CGFloat.random(in: 0.3...1.5),
                brightness: CGFloat.random(in: 0.1...0.5),
                twinkleSpeed: CGFloat.random(in: 0.5...2.5),
                twinkleOffset: CGFloat.random(in: 0...(.pi * 2))
            )
        }
    }

    func regenerateStarsForSize(width: CGFloat, height: CGFloat) {
        stars = (0..<150).map { _ in
            Star(
                x: CGFloat.random(in: 0...width),
                y: CGFloat.random(in: 0...height),
                size: CGFloat.random(in: 0.3...1.5),
                brightness: CGFloat.random(in: 0.1...0.5),
                twinkleSpeed: CGFloat.random(in: 0.5...2.5),
                twinkleOffset: CGFloat.random(in: 0...(.pi * 2))
            )
        }
    }

    func generateAccretionDisk() {
        accretionParticles = (0..<80).map { _ in
            AccretionParticle(
                angle: CGFloat.random(in: 0...(.pi * 2)),
                radius: CGFloat.random(in: 12...50),
                speed: CGFloat.random(in: 2.0...5.0),
                size: CGFloat.random(in: 0.6...2.5),
                brightness: CGFloat.random(in: 0.3...0.9)
            )
        }
    }

    // MARK: - Current level definition
    var currentLevelDef: LevelDef {
        GameConstants.levelDef(for: level)
    }

    // MARK: - Game Loop
    func startGameLoop() {
        stopGameLoop()
        lastTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(gameStep))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopGameLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func gameStep(_ link: CADisplayLink) {
        let now = link.timestamp
        var dt = CGFloat(now - lastTime)
        lastTime = now
        dt = min(dt, 0.05)
        update(dt: dt)
    }

    // MARK: - Update
    func update(dt: CGFloat) {
        var effectiveDt = dt
        if slowmoActive {
            slowmoTimer -= dt
            if slowmoTimer <= 0 {
                slowmoActive = false
            } else {
                effectiveDt = dt * 0.4
            }
        }

        pulsePhase += dt

        for i in accretionParticles.indices {
            accretionParticles[i].angle += accretionParticles[i].speed * effectiveDt
        }

        guard state == .playing, player.alive else { return }

        gameTime += effectiveDt

        if gracePeriod > 0 {
            gracePeriod -= effectiveDt
        }

        // Level check (non-blocking – game continues)
        let newLevel = GameConstants.levelForScore(score)
        if newLevel > level {
            triggerLevelUp(newLevel: newLevel)
        }

        let levelDef = currentLevelDef

        // Gravity — stronger when closer to the black hole, scaled by difficulty
        let diff = GameSettings.shared.difficulty
        let baseGrav = GameConstants.baseGravity * levelDef.gravityMultiplier * diff.gravityMul
        let proxBoost = 1.0 + proximityFactor * proximityFactor * diff.proxGravBoost
        player.targetRadius -= baseGrav * proxBoost * effectiveDt

        // Input (disabled during absorption)
        if !playerAbsorbing {
            if inputIn {
                player.targetRadius -= GameConstants.thrustForce * effectiveDt
                player.thrustIn = min(1, player.thrustIn + effectiveDt * 8)
            } else {
                player.thrustIn = max(0, player.thrustIn - effectiveDt * 4)
            }

            if inputOut {
                player.targetRadius += GameConstants.thrustForce * effectiveDt
                player.thrustOut = min(1, player.thrustOut + effectiveDt * 8)
            } else {
                player.thrustOut = max(0, player.thrustOut - effectiveDt * 4)
            }
        } else {
            // Fade thrust visuals during absorption
            player.thrustIn = max(0, player.thrustIn - effectiveDt * 6)
            player.thrustOut = max(0, player.thrustOut - effectiveDt * 6)
        }

        player.targetRadius = max(GameConstants.minRadius, min(GameConstants.maxRadius, player.targetRadius))
        player.radius += (player.targetRadius - player.radius) * 8 * effectiveDt

        let orbSpeed = GameConstants.baseSpeed * levelDef.orbitalSpeedMultiplier * diff.orbSpeedMul
        player.speed = orbSpeed
        player.angle += player.speed * effectiveDt

        let px = centerX + cos(player.angle) * player.radius
        let py = centerY + sin(player.angle) * player.radius

        // Trail
        let lastTrail = player.trail.last
        let trailDist = lastTrail.map { hypot(px - $0.x, py - $0.y) } ?? 100
        if trailDist > 2 {
            player.trail.append(TrailPoint(x: px, y: py))
        }
        if player.trail.count > 50 { player.trail.removeFirst() }
        for i in player.trail.indices { player.trail[i].age += effectiveDt }

        // Engine particles
        if (inputIn || inputOut) && Float.random(in: 0...1) < 0.5 {
            let moveAngle = player.angle + .pi / 2
            let color: Color = inputIn ? .red : .green
            spawnParticles(
                x: px - cos(moveAngle) * 6, y: py - sin(moveAngle) * 6,
                color: color, count: 1,
                speed: 15, speedVar: 25, life: 0.15, lifeVar: 0.2,
                size: 0.8, sizeVar: 1.5, drag: 0.95
            )
        }

        if player.shielded {
            player.shieldTimer -= effectiveDt
            if player.shieldTimer <= 0 {
                player.shielded = false
                player.shieldLayers = 0
            }
        }
        if player.invincible > 0 { player.invincible -= effectiveDt }

        // Spawn obstacles (after grace period)
        if gracePeriod <= 0 {
            let baseSpawnRate: CGFloat = 1.2
            let spawnRate = baseSpawnRate / (levelDef.spawnRateMultiplier * diff.spawnRateMul)
            spawnAccumulator += effectiveDt
            if spawnAccumulator >= spawnRate {
                spawnAccumulator = 0
                spawnObstacle()
            }

            // Extra ring spawns (rings come more frequently than other obstacles)
            if levelDef.unlockedObstacles.contains(.ring) {
                ringSpawnAccumulator += effectiveDt
                let ringInterval: CGFloat = 2.2 / (levelDef.spawnRateMultiplier * diff.spawnRateMul)
                if ringSpawnAccumulator >= ringInterval {
                    ringSpawnAccumulator = 0
                    spawnRing()
                }
            }
        }

        if CGFloat.random(in: 0...1) < effectiveDt / 3.5 { spawnPowerup() }

        score += Int(effectiveDt * 10 * (1 + (player.radius - GameConstants.minRadius) / 50))

        updateObstacles(dt: effectiveDt, px: px, py: py)

        // Black hole absorption — spaghettify the player before registering the hit
        if playerAbsorbing {
            playerAbsorbProgress += effectiveDt * 1.6  // ~0.6s total absorption
            // Pull player toward center during absorption
            player.targetRadius = max(10, player.radius - 60 * effectiveDt)
            player.radius = max(10, player.radius - 60 * effectiveDt)
            // Emit inward wisps during absorption
            if CGFloat.random(in: 0...1) < effectiveDt * 12 {
                let toCenter = atan2(centerY - py, centerX - px)
                let pAngle = toCenter + CGFloat.random(in: -0.4...0.4)
                particles.append(Particle(
                    x: px + CGFloat.random(in: -6...6),
                    y: py + CGFloat.random(in: -6...6),
                    vx: cos(pAngle) * 25, vy: sin(pAngle) * 25,
                    life: 0.2, maxLife: 0.2,
                    size: CGFloat.random(in: 0.4...1.2),
                    color: Color(red: 1.0, green: 0.7, blue: 0.3).opacity(0.7),
                    drag: 0.92
                ))
            }
            if playerAbsorbProgress >= 1.0 {
                playerAbsorbing = false
                playerAbsorbProgress = 0
                // Ship silently consumed — no explosion, no hit sound
                lives -= 1
                lifeLostTrigger += 1
                HapticEngine.medium()
                if lives <= 0 {
                    player.alive = false
                    sound.play(.death)
                    isNewHighScore = score > hiScore
                    isNewTimeBest = gameTime > bestTime
                    if isNewTimeBest { bestTime = gameTime; UserDefaults.standard.set(Double(gameTime), forKey: "gw_besttime") }
                    if score > hiScore { hiScore = score; UserDefaults.standard.set(hiScore, forKey: "gw_hiscore") }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.state = .gameOver }
                } else {
                    player.invincible = GameSettings.shared.difficulty.invincibilityTime
                    player.targetRadius = 140
                    obstacles.removeAll()
                    spawnAccumulator = 0
                    ringSpawnAccumulator = 0
                    gracePeriod = 1.5
                }
            }
        } else if player.radius <= GameConstants.minRadius + 2 && player.invincible <= 0 {
            // Start absorption sequence
            playerAbsorbing = true
            playerAbsorbProgress = 0
            screenShake = 0.3
            HapticEngine.medium()
        }

        updatePowerups(dt: effectiveDt, px: px, py: py)
        updateParticles(dt: effectiveDt)

        if screenShake > 0 { screenShake -= effectiveDt * 2 }
        if nearMissCooldown > 0 { nearMissCooldown -= effectiveDt }
    }

    // MARK: - Level Up (non-blocking – gameplay continues)
    func triggerLevelUp(newLevel: Int) {
        let def = GameConstants.levelDef(for: newLevel)
        level = newLevel
        levelUpName = def.name
        levelUpElement = def.newElement
        // Don't change state – game keeps playing
        sound.play(.wave)
        HapticEngine.medium()
        obstacles.removeAll()
        powerups.removeAll()
        player.invincible = 2.0
        gracePeriod = 2.0
        spawnAccumulator = 0
        ringSpawnAccumulator = 0

        // Show banner overlay (auto-hides after delay)
        withAnimation(.easeInOut(duration: 0.4)) {
            showLevelUpBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation(.easeInOut(duration: 0.5)) {
                self?.showLevelUpBanner = false
            }
        }
    }

    func resumeAfterLevelUp() {
        // Keep for compatibility but no longer needed
        state = .playing
        lastTime = CACurrentMediaTime()
    }

    // MARK: - Spawn Protection
    /// Minimum distance (in radius units) an orbiting obstacle must spawn from the player
    private let spawnSafeRadius: CGFloat = 35

    private func isSafeSpawnAngle(_ spawnAngle: CGFloat, _ spawnRadius: CGFloat) -> Bool {
        // Check if the spawn position is far enough from player
        let dx = cos(spawnAngle) * spawnRadius - cos(player.angle) * player.radius
        let dy = sin(spawnAngle) * spawnRadius - sin(player.angle) * player.radius
        return hypot(dx, dy) > spawnSafeRadius
    }

    private func safeSpawnAngle(forRadius spawnRadius: CGFloat) -> CGFloat {
        // Try up to 5 times to find a safe angle, then just offset from player
        for _ in 0..<5 {
            let a = CGFloat.random(in: 0...(.pi * 2))
            if isSafeSpawnAngle(a, spawnRadius) { return a }
        }
        // Fallback: spawn opposite to player
        return player.angle + .pi + CGFloat.random(in: -0.5...0.5)
    }

    // MARK: - Obstacle Spawning
    func spawnObstacle() {
        let levelDef = currentLevelDef
        let available = levelDef.unlockedObstacles
        guard !available.isEmpty else { return }

        let chosenType = available.randomElement()!
        let angle = CGFloat.random(in: 0...(.pi * 2))

        switch chosenType {
        case .asteroid:
            let speed: CGFloat = 35 + CGFloat.random(in: 0...25) + CGFloat(level) * 3
            let r = GameConstants.maxRadius + 60 + CGFloat.random(in: 0...80)
            let numVerts = Int.random(in: 7...10)
            var o = Obstacle(type: .asteroid, life: 8)
            o.x = centerX + cos(angle) * r
            o.y = centerY + sin(angle) * r
            o.vx = -cos(angle) * speed * CGFloat.random(in: 0.3...0.7)
            o.vy = -sin(angle) * speed * CGFloat.random(in: 0.3...0.7)
            let astSize = CGFloat.random(in: 8...18)
            o.size = astSize
            o.originalSize = astSize
            o.rotation = CGFloat.random(in: 0...(.pi * 2))
            o.rotSpeed = CGFloat.random(in: -2.5...2.5)
            o.vertices = (0..<numVerts).map { _ in CGFloat.random(in: 0.6...1.0) }
            o.craters = (0..<Int.random(in: 2...3)).map { _ in
                Crater(angle: .random(in: 0...(.pi * 2)), dist: .random(in: 0...0.5), size: .random(in: 0.15...0.35))
            }
            o.hue = Double.random(in: 15...45)
            obstacles.append(o)

        case .orbiter:
            let r = GameConstants.minRadius + 25 + CGFloat.random(in: 0...(GameConstants.maxRadius - GameConstants.minRadius - 30))
            var o = Obstacle(type: .orbiter, life: CGFloat.random(in: 6...10))
            o.angle = safeSpawnAngle(forRadius: r)
            o.radius = r
            o.orbSpeed = (Bool.random() ? 1 : -1) * (0.4 + CGFloat.random(in: 0...0.6) + CGFloat(level) * 0.05)
            o.size = CGFloat.random(in: 5...9)
            o.pulsePhase = CGFloat.random(in: 0...(.pi * 2))
            obstacles.append(o)

        case .ring:
            spawnRing()

        case .magneticField:
            let r = GameConstants.minRadius + 30 + CGFloat.random(in: 0...(GameConstants.maxRadius - GameConstants.minRadius - 40))
            var o = Obstacle(type: .magneticField, life: CGFloat.random(in: 4...7))
            o.angle = safeSpawnAngle(forRadius: r)
            o.radius = r
            o.fieldRadius = CGFloat.random(in: 35...60)
            o.fieldStrength = (Bool.random() ? 1 : -1) * CGFloat.random(in: 60...120)
            o.pulsePhase = CGFloat.random(in: 0...(.pi * 2))
            obstacles.append(o)

        case .vortex:
            let r = GameConstants.minRadius + 20 + CGFloat.random(in: 0...(GameConstants.maxRadius - GameConstants.minRadius - 30))
            var o = Obstacle(type: .vortex, life: CGFloat.random(in: 5...8))
            o.angle = safeSpawnAngle(forRadius: r)
            o.radius = r
            o.fieldRadius = CGFloat.random(in: 25...40)
            o.rotSpeed = CGFloat.random(in: 2...5)
            o.pulsePhase = CGFloat.random(in: 0...(.pi * 2))
            obstacles.append(o)

        case .laserBeam:
            var o = Obstacle(type: .laserBeam, life: CGFloat.random(in: 4...7))
            o.laserAngle = CGFloat.random(in: 0...(.pi * 2))
            o.laserRotSpeed = (Bool.random() ? 1 : -1) * CGFloat.random(in: 0.3...0.7)
            o.laserLength = GameConstants.maxRadius + 20
            obstacles.append(o)
        }
    }

    /// Dedicated ring spawner — rings expand slower and spawn on their own timer
    private func spawnRing() {
        var o = Obstacle(type: .ring, life: 6)
        o.radius = 20
        o.expandSpeed = 40 + CGFloat(level) * 4
        o.thickness = CGFloat.random(in: 3...5)
        o.gapAngle = CGFloat.random(in: 0...(.pi * 2))
        o.gapSize = max(0.75, 0.88 - CGFloat(level) * 0.01)  // wall ≤ quarter circle
        obstacles.append(o)
    }

    func updateObstacles(dt: CGFloat, px: CGFloat, py: CGFloat) {
        obstacles.removeAll { $0.life <= 0 }

        for i in obstacles.indices.reversed() {
            guard i < obstacles.count else { continue }
            obstacles[i].life -= dt

            var ox: CGFloat = 0, oy: CGFloat = 0, oSize: CGFloat = 0
            var hasPosition = false

            switch obstacles[i].type {
            case .asteroid:
                let dx = centerX - obstacles[i].x
                let dy = centerY - obstacles[i].y
                let dist = hypot(dx, dy)
                // Strong gravity pull towards center – gets much stronger near the hole
                let grav = 3500 / (dist + 30)
                obstacles[i].vx += (dx / dist) * grav * dt
                obstacles[i].vy += (dy / dist) * grav * dt
                obstacles[i].x += obstacles[i].vx * dt
                obstacles[i].y += obstacles[i].vy * dt
                obstacles[i].rotation += obstacles[i].rotSpeed * dt
                // Speed up rotation as asteroid gets closer (tidal forces)
                if dist < GameConstants.minRadius * 2 {
                    obstacles[i].rotSpeed *= 1 + dt * 3
                }
                ox = obstacles[i].x; oy = obstacles[i].y; oSize = obstacles[i].size
                hasPosition = true

                // Shrink asteroid based on distance to center — use originalSize as base
                let shrinkZone = GameConstants.minRadius * 1.5
                if dist < shrinkZone {
                    let t = dist / shrinkZone // 1 at edge → 0 at center
                    // Smooth cubic shrink from full size to near-zero at center
                    obstacles[i].size = obstacles[i].originalSize * max(0.02, t * t)

                    // Emit wisps being pulled inward — more intense closer to center
                    let wispChance: Float = Float(1.0 - Double(t)) * 0.6
                    if Float.random(in: 0...1) < wispChance {
                        let toCenter = atan2(centerY - oy, centerX - ox)
                        let pAngle = toCenter + CGFloat.random(in: -0.35...0.35)
                        let pSpeed: CGFloat = 15 + CGFloat.random(in: 0...25)
                        particles.append(Particle(
                            x: ox + CGFloat.random(in: -oSize...oSize) * 0.3,
                            y: oy + CGFloat.random(in: -oSize...oSize) * 0.3,
                            vx: cos(pAngle) * pSpeed, vy: sin(pAngle) * pSpeed,
                            life: 0.3, maxLife: 0.3,
                            size: CGFloat.random(in: 0.4...1.5),
                            color: Color(red: 1.0, green: Double.random(in: 0.5...0.85), blue: Double.random(in: 0.1...0.3)),
                            drag: 0.92
                        ))
                    }
                }

                // Absorbed only when actually at the center of the black hole
                if dist < GameConstants.minRadius * 0.3 {
                    // Final wisps at the point of no return
                    for _ in 0..<5 {
                        let toCenter = atan2(centerY - oy, centerX - ox)
                        let pAngle = toCenter + CGFloat.random(in: -0.25...0.25)
                        particles.append(Particle(
                            x: ox, y: oy,
                            vx: cos(pAngle) * 12, vy: sin(pAngle) * 12,
                            life: 0.2, maxLife: 0.2,
                            size: CGFloat.random(in: 0.3...1.0),
                            color: Color(red: 1.0, green: 0.7, blue: 0.2).opacity(0.7),
                            drag: 0.88
                        ))
                    }
                    obstacles[i].life = 0
                    score += 5
                    continue
                }
                if dist > 500 { obstacles[i].life = 0 }

            case .orbiter:
                obstacles[i].angle += obstacles[i].orbSpeed * dt
                obstacles[i].pulsePhase += dt * 4
                ox = centerX + cos(obstacles[i].angle) * obstacles[i].radius
                oy = centerY + sin(obstacles[i].angle) * obstacles[i].radius
                oSize = obstacles[i].size
                hasPosition = true
                obstacles[i].trailHistory.append(CGPoint(x: ox, y: oy))
                if obstacles[i].trailHistory.count > 12 { obstacles[i].trailHistory.removeFirst() }

            case .ring:
                obstacles[i].radius += obstacles[i].expandSpeed * dt
                if obstacles[i].radius > GameConstants.maxRadius + 80 { obstacles[i].life = 0; continue }
                if abs(player.radius - obstacles[i].radius) < obstacles[i].thickness + GameConstants.playerSize {
                    var angleDiff = player.angle.truncatingRemainder(dividingBy: .pi * 2)
                    if angleDiff < 0 { angleDiff += .pi * 2 }
                    var gapAngle = obstacles[i].gapAngle.truncatingRemainder(dividingBy: .pi * 2)
                    if gapAngle < 0 { gapAngle += .pi * 2 }
                    var diff = abs(angleDiff - gapAngle)
                    if diff > .pi { diff = .pi * 2 - diff }
                    if diff > obstacles[i].gapSize * .pi && player.invincible <= 0 {
                        handleHit(px: px, py: py)
                    }
                }
                continue

            case .magneticField:
                obstacles[i].pulsePhase += dt * 3
                let fx = centerX + cos(obstacles[i].angle) * obstacles[i].radius
                let fy = centerY + sin(obstacles[i].angle) * obstacles[i].radius
                let ddx = px - fx, ddy = py - fy
                let dist = hypot(ddx, ddy)
                if dist < obstacles[i].fieldRadius && player.invincible <= 0 {
                    let force = obstacles[i].fieldStrength * (1 - dist / obstacles[i].fieldRadius)
                    player.targetRadius += force * dt
                }
                continue

            case .vortex:
                obstacles[i].pulsePhase += dt * obstacles[i].rotSpeed
                let vxP = centerX + cos(obstacles[i].angle) * obstacles[i].radius
                let vyP = centerY + sin(obstacles[i].angle) * obstacles[i].radius
                let ddx = px - vxP, ddy = py - vyP
                let dist = hypot(ddx, ddy)
                if dist < obstacles[i].fieldRadius {
                    let influence = 1 - dist / obstacles[i].fieldRadius
                    player.angle += influence * 1.5 * dt
                }
                continue

            case .laserBeam:
                obstacles[i].laserAngle += obstacles[i].laserRotSpeed * dt
                obstacles[i].pulsePhase += dt * 6
                if player.invincible <= 0 {
                    let lA = obstacles[i].laserAngle
                    var pA = player.angle.truncatingRemainder(dividingBy: .pi * 2)
                    if pA < 0 { pA += .pi * 2 }
                    for offset: CGFloat in [0, .pi] {
                        var checkA = (lA + offset).truncatingRemainder(dividingBy: .pi * 2)
                        if checkA < 0 { checkA += .pi * 2 }
                        var diff = abs(pA - checkA)
                        if diff > .pi { diff = .pi * 2 - diff }
                        if diff < 0.06 && player.radius > GameConstants.minRadius + 10 {
                            handleHit(px: px, py: py)
                            break
                        }
                    }
                }
                continue
            }

            if hasPosition {
                let dx = px - ox, dy = py - oy
                let dist = hypot(dx, dy)
                let hitThreshold = GameConstants.playerSize + oSize * 0.45
                if dist < hitThreshold && player.invincible <= 0 {
                    if player.shielded {
                        // Shield absorbs the hit
                        player.shielded = false
                        player.shieldLayers = 0
                        player.invincible = 0.5
                        screenShake = 0.2
                        spawnParticles(x: ox, y: oy, color: .cyan, count: 15, speed: 40, speedVar: 60)
                        obstacles[i].life = 0
                        sound.play(.hit)
                    } else {
                        hitPlayer(px: px, py: py)
                    }
                } else if dist < hitThreshold * 1.8 && player.invincible <= 0 && nearMissCooldown <= 0 {
                    nearMissTrigger += 1
                    nearMissCooldown = 0.5  // prevent rapid-fire triggers
                }
            }
        }
    }

    func handleHit(px: CGFloat, py: CGFloat) {
        if player.shielded {
            // Shield absorbs the hit
            player.shielded = false
            player.shieldLayers = 0
            player.invincible = 0.5
            screenShake = 0.2
            sound.play(.hit)
            spawnParticles(x: px, y: py, color: .cyan, count: 15, speed: 40, speedVar: 60)
        } else {
            hitPlayer(px: px, py: py)
        }
    }

    // MARK: - Hit / Death (with lives)
    func hitPlayer(px: CGFloat, py: CGFloat, absorbed: Bool = false) {
        lives -= 1
        lifeLostTrigger += 1
        screenShake = absorbed ? 0.3 : 0.6
        HapticEngine.heavy()
        sound.play(.hit)

        if absorbed {
            // Inward wisps — pulled into the black hole
            spawnAbsorptionWisps(px: px, py: py, count: 15)
        } else {
            spawnParticles(x: px, y: py, color: .red, count: 20, speed: 50, speedVar: 100, life: 0.3, lifeVar: 0.5, size: 1.5, sizeVar: 2.5)
            spawnParticles(x: px, y: py, color: .orange, count: 12, speed: 30, speedVar: 60, life: 0.2, lifeVar: 0.4, size: 1, sizeVar: 2)
        }

        if lives <= 0 {
            killPlayer(px: px, py: py, absorbed: absorbed)
        } else {
            player.invincible = GameSettings.shared.difficulty.invincibilityTime
            player.targetRadius = 140
            obstacles.removeAll()
            spawnAccumulator = 0
            ringSpawnAccumulator = 0
            gracePeriod = 1.5
        }
    }

    func killPlayer(px: CGFloat, py: CGFloat, absorbed: Bool = false) {
        player.alive = false
        screenShake = absorbed ? 0.4 : 0.8

        if absorbed {
            // Final absorption — strong inward wisps, no outward explosion
            spawnAbsorptionWisps(px: px, py: py, count: 25)
        } else {
            spawnParticles(x: px, y: py, color: .red, count: 30, speed: 50, speedVar: 120, life: 0.4, lifeVar: 0.6, size: 1.5, sizeVar: 3)
            spawnParticles(x: px, y: py, color: .orange, count: 20, speed: 30, speedVar: 80, life: 0.3, lifeVar: 0.5, size: 1, sizeVar: 2)
            spawnParticles(x: px, y: py, color: .white, count: 10, speed: 80, speedVar: 100, life: 0.15, lifeVar: 0.2, size: 0.5, sizeVar: 1.5)
        }
        sound.play(.death)

        // Track records before updating hiScore
        isNewHighScore = score > hiScore
        isNewTimeBest = gameTime > bestTime
        if isNewTimeBest {
            bestTime = gameTime
            UserDefaults.standard.set(Double(gameTime), forKey: "gw_besttime")
        }
        if score > hiScore {
            hiScore = score
            UserDefaults.standard.set(hiScore, forKey: "gw_hiscore")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.state = .gameOver
        }
    }

    /// Spawn inward-spiraling wisps that get pulled toward the black hole center
    private func spawnAbsorptionWisps(px: CGFloat, py: CGFloat, count: Int) {
        for _ in 0..<count {
            let toCenter = atan2(centerY - py, centerX - px)
            let pAngle = toCenter + CGFloat.random(in: -0.5...0.5)
            let pSpeed: CGFloat = 15 + CGFloat.random(in: 0...30)
            particles.append(Particle(
                x: px + CGFloat.random(in: -8...8),
                y: py + CGFloat.random(in: -8...8),
                vx: cos(pAngle) * pSpeed, vy: sin(pAngle) * pSpeed,
                life: 0.2 + CGFloat.random(in: 0...0.15),
                maxLife: 0.3,
                size: CGFloat.random(in: 0.3...1.2),
                color: Color(red: 1.0, green: Double.random(in: 0.5...0.85), blue: Double.random(in: 0.1...0.3)).opacity(0.7),
                drag: 0.9
            ))
        }
    }

    // MARK: - Powerup Logic
    func spawnPowerup() {
        let levelDef = currentLevelDef
        let available = levelDef.unlockedPowerups
        guard !available.isEmpty else { return }

        let angle = CGFloat.random(in: 0...(.pi * 2))
        let r = GameConstants.minRadius + 30 + CGFloat.random(in: 0...(GameConstants.maxRadius - GameConstants.minRadius - 40))
        let roll = CGFloat.random(in: 0...1)
        let type: PowerupType
        if available.contains(.extraLife) && roll < 0.05 { type = .extraLife }
        else if available.contains(.slowmo) && roll < 0.15 { type = .slowmo }
        else if available.contains(.shield) && roll < 0.35 { type = .shield }
        else { type = .point }
        powerups.append(Powerup(type: type, angle: angle, radius: r, bobPhase: CGFloat.random(in: 0...(.pi * 2))))
    }

    func updatePowerups(dt: CGFloat, px: CGFloat, py: CGFloat) {
        for i in powerups.indices.reversed() {
            guard i < powerups.count else { continue }
            powerups[i].life -= dt
            powerups[i].bobPhase += dt * 3
            powerups[i].spinAngle += dt * 2
            if powerups[i].life <= 0 { powerups.remove(at: i); continue }

            let ppx = centerX + cos(powerups[i].angle) * powerups[i].radius
            let ppy = centerY + sin(powerups[i].angle) * powerups[i].radius
            if hypot(px - ppx, py - ppy) < GameConstants.playerSize + 12 {
                switch powerups[i].type {
                case .point:
                    score += 50 * level
                    sound.play(.collect)
                    HapticEngine.light()
                    spawnParticles(x: ppx, y: ppy, color: Color(red: 0.39, green: 0.4, blue: 0.95), count: 12, speed: 30, speedVar: 60)
                case .shield:
                    if player.shielded {
                        // Already shielded — add 1s bonus time
                        player.shieldTimer = min(player.shieldTimer + 1.0, GameSettings.shared.difficulty.shieldDuration)
                    } else {
                        player.shielded = true
                        player.shieldLayers = 1
                        player.shieldTimer = GameSettings.shared.difficulty.shieldDuration
                    }
                    sound.play(.shield); HapticEngine.light()
                    spawnParticles(x: ppx, y: ppy, color: .cyan, count: 15, speed: 40, speedVar: 50)
                case .slowmo:
                    slowmoActive = true; slowmoTimer = 4
                    sound.play(.shield); HapticEngine.light()
                    spawnParticles(x: ppx, y: ppy, color: Color(red: 0.96, green: 0.62, blue: 0.04), count: 12, speed: 30, speedVar: 50)
                case .extraLife:
                    lives = min(lives + 1, 5)
                    sound.play(.collect); HapticEngine.medium()
                    spawnParticles(x: ppx, y: ppy, color: .green, count: 20, speed: 40, speedVar: 60)
                }
                powerups.remove(at: i)
            }
        }
    }

    // MARK: - Particle Logic
    func spawnParticles(x: CGFloat, y: CGFloat, color: Color, count: Int,
                        speed: CGFloat = 60, speedVar: CGFloat = 80,
                        life: CGFloat = 0.3, lifeVar: CGFloat = 0.5,
                        size: CGFloat = 1, sizeVar: CGFloat = 2.5, drag: CGFloat = 0.98) {
        for _ in 0..<count {
            let a = CGFloat.random(in: 0...(.pi * 2))
            let s = speed + CGFloat.random(in: 0...speedVar)
            let l = life + CGFloat.random(in: 0...lifeVar)
            particles.append(Particle(x: x, y: y, vx: cos(a) * s, vy: sin(a) * s,
                                      life: l, maxLife: l, size: size + CGFloat.random(in: 0...sizeVar), color: color, drag: drag))
        }
    }

    func updateParticles(dt: CGFloat) {
        for i in particles.indices.reversed() {
            guard i < particles.count else { continue }
            particles[i].vx *= particles[i].drag
            particles[i].vy *= particles[i].drag
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].life -= dt
            if particles[i].life <= 0 { particles.remove(at: i) }
        }
    }

    // MARK: - Game State Management
    func startGame() {
        // Save previous run for comparison on next Game Over
        previousScore = score
        previousTime = gameTime
        previousLevel = level

        state = .playing
        score = 0; gameTime = 0; level = 1; lives = GameSettings.shared.difficulty.startLives
        obstacles = []; particles = []; powerups = []
        screenShake = 0; slowmoActive = false; slowmoTimer = 0; nearMissCooldown = 0
        gracePeriod = 3.0; spawnAccumulator = 0; ringSpawnAccumulator = 0; showLevelUpBanner = false
        playerAbsorbing = false; playerAbsorbProgress = 0
        player = Player()
        sound.ensureReady()
        startGameLoop()
    }

    func togglePause() {
        if state == .playing { state = .paused }
        else if state == .paused { state = .playing; lastTime = CACurrentMediaTime() }
    }

    func goToMainMenu() {
        stopGameLoop()
        state = .start
        // Reset so start screen is clean
        inputIn = false
        inputOut = false
        showLevelUpBanner = false
    }

    func setCenter(x: CGFloat, y: CGFloat) {
        centerX = x; centerY = y
    }

    var formattedTime: String {
        let mins = Int(gameTime) / 60; let secs = Int(gameTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var formattedBestTime: String {
        let mins = Int(bestTime) / 60; let secs = Int(bestTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    static func formatTime(_ t: CGFloat) -> String {
        let mins = Int(t) / 60; let secs = Int(t) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    deinit { stopGameLoop() }
}
