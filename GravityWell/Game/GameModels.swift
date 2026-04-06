import SwiftUI
import Foundation

// MARK: - Game State
enum GameState: Equatable {
    case start
    case playing
    case paused
    case gameOver
    case tutorial
}

// MARK: - Player
struct Player {
    var angle: CGFloat = -.pi / 2
    var radius: CGFloat = 140
    var targetRadius: CGFloat = 140
    var speed: CGFloat = 0.7
    var alive: Bool = true
    var shielded: Bool = false
    var shieldTimer: CGFloat = 0
    var shieldLayers: Int = 0  // 0 = no shield, 1 = single, 2 = double
    var trail: [TrailPoint] = []
    var invincible: CGFloat = 2.0  // Longer start invincibility
    var thrustIn: CGFloat = 0
    var thrustOut: CGFloat = 0
}

struct TrailPoint {
    var x: CGFloat
    var y: CGFloat
    var age: CGFloat = 0
}

// MARK: - Obstacles
enum ObstacleType {
    case asteroid
    case orbiter
    case ring
    case magneticField   // Level 3: area that pushes/pulls player
    case vortex          // Level 5: spinning zone that speeds up orbital speed
    case laserBeam       // Level 7: rotating laser beam from center
}

struct Obstacle: Identifiable {
    let id = UUID()
    var type: ObstacleType
    var life: CGFloat

    // Asteroid
    var x: CGFloat = 0
    var y: CGFloat = 0
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var size: CGFloat = 10
    var originalSize: CGFloat = 10
    var rotation: CGFloat = 0
    var rotSpeed: CGFloat = 0
    var vertices: [CGFloat] = []
    var craters: [Crater] = []
    var hue: Double = 25

    // Orbiter
    var angle: CGFloat = 0
    var radius: CGFloat = 100
    var orbSpeed: CGFloat = 1
    var pulsePhase: CGFloat = 0
    var trailHistory: [CGPoint] = []

    // Ring
    var expandSpeed: CGFloat = 80
    var thickness: CGFloat = 3
    var gapAngle: CGFloat = 0
    var gapSize: CGFloat = 0.8

    // Magnetic field
    var fieldStrength: CGFloat = 0  // positive = push, negative = pull
    var fieldRadius: CGFloat = 40

    // Laser beam
    var laserAngle: CGFloat = 0
    var laserRotSpeed: CGFloat = 0.5
    var laserLength: CGFloat = 200
}

struct Crater {
    var angle: CGFloat
    var dist: CGFloat
    var size: CGFloat
}

// MARK: - Powerups
enum PowerupType {
    case point
    case shield
    case slowmo      // Level 4: slows down everything briefly
    case extraLife   // Level 6: gives extra life
}

struct Powerup: Identifiable {
    let id = UUID()
    var type: PowerupType
    var angle: CGFloat
    var radius: CGFloat
    var bobPhase: CGFloat = 0
    var spinAngle: CGFloat = 0
    var life: CGFloat = 12
}

// MARK: - Particles
struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var maxLife: CGFloat
    var size: CGFloat
    var color: Color
    var drag: CGFloat = 0.98
}

// MARK: - Stars
struct Star {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var brightness: CGFloat
    var twinkleSpeed: CGFloat
    var twinkleOffset: CGFloat
}

// MARK: - Accretion Particle
struct AccretionParticle {
    var angle: CGFloat
    var radius: CGFloat
    var speed: CGFloat
    var size: CGFloat
    var brightness: CGFloat
}

// MARK: - Level Definition
struct LevelDef {
    let level: Int
    let pointsRequired: Int
    let name: String
    let newElement: String
    let gravityMultiplier: CGFloat
    let spawnRateMultiplier: CGFloat
    let orbitalSpeedMultiplier: CGFloat
    let unlockedObstacles: [ObstacleType]
    let unlockedPowerups: [PowerupType]
}

// MARK: - Constants
struct GameConstants {
    static let minRadius: CGFloat = 40
    static let maxRadius: CGFloat = 200
    static let playerSize: CGFloat = 9
    static let thrustForce: CGFloat = 160
    static let baseGravity: CGFloat = 14
    static let baseSpeed: CGFloat = 0.7
    static let startLives: Int = 3

    // Level definitions
    static let levels: [LevelDef] = [
        LevelDef(level: 1, pointsRequired: 0,     name: "Orbital Entry",
                 newElement: "Dodge asteroids!",
                 gravityMultiplier: 1.0, spawnRateMultiplier: 1.0, orbitalSpeedMultiplier: 1.0,
                 unlockedObstacles: [.asteroid],
                 unlockedPowerups: [.point]),

        LevelDef(level: 2, pointsRequired: 500,   name: "Energy Orbiters",
                 newElement: "Energy orbiters now orbit the black hole!",
                 gravityMultiplier: 1.1, spawnRateMultiplier: 1.1, orbitalSpeedMultiplier: 1.0,
                 unlockedObstacles: [.asteroid, .orbiter],
                 unlockedPowerups: [.point, .shield]),

        LevelDef(level: 3, pointsRequired: 1500,  name: "Magnetic Anomalies",
                 newElement: "Magnetic fields push and pull your ship!",
                 gravityMultiplier: 1.25, spawnRateMultiplier: 1.2, orbitalSpeedMultiplier: 1.08,
                 unlockedObstacles: [.asteroid, .orbiter, .magneticField],
                 unlockedPowerups: [.point, .shield]),

        LevelDef(level: 4, pointsRequired: 3000,  name: "Ring Pulse",
                 newElement: "Expanding ring pulses! Find the gap. Collect clocks to slow time.",
                 gravityMultiplier: 1.3, spawnRateMultiplier: 1.2, orbitalSpeedMultiplier: 1.1,
                 unlockedObstacles: [.asteroid, .orbiter, .magneticField, .ring],
                 unlockedPowerups: [.point, .shield, .slowmo]),

        LevelDef(level: 5, pointsRequired: 5000,  name: "Gravity Vortex",
                 newElement: "Vortex zones speed up your orbit!",
                 gravityMultiplier: 1.4, spawnRateMultiplier: 1.25, orbitalSpeedMultiplier: 1.15,
                 unlockedObstacles: [.asteroid, .orbiter, .magneticField, .ring, .vortex],
                 unlockedPowerups: [.point, .shield, .slowmo]),

        LevelDef(level: 6, pointsRequired: 8000,  name: "Second Chance",
                 newElement: "Extra lives appear! Don't miss them.",
                 gravityMultiplier: 1.5, spawnRateMultiplier: 1.3, orbitalSpeedMultiplier: 1.2,
                 unlockedObstacles: [.asteroid, .orbiter, .magneticField, .ring, .vortex],
                 unlockedPowerups: [.point, .shield, .slowmo, .extraLife]),

        LevelDef(level: 7, pointsRequired: 12000, name: "Laser Grid",
                 newElement: "Rotating laser beams from the core!",
                 gravityMultiplier: 1.6, spawnRateMultiplier: 1.35, orbitalSpeedMultiplier: 1.25,
                 unlockedObstacles: [.asteroid, .orbiter, .magneticField, .ring, .vortex, .laserBeam],
                 unlockedPowerups: [.point, .shield, .slowmo, .extraLife]),

        LevelDef(level: 8, pointsRequired: 17000, name: "Event Horizon",
                 newElement: "Maximum chaos! Good luck.",
                 gravityMultiplier: 1.8, spawnRateMultiplier: 1.4, orbitalSpeedMultiplier: 1.3,
                 unlockedObstacles: [.asteroid, .orbiter, .magneticField, .ring, .vortex, .laserBeam],
                 unlockedPowerups: [.point, .shield, .slowmo, .extraLife]),
    ]

    static func levelDef(for level: Int) -> LevelDef {
        let idx = min(level - 1, levels.count - 1)
        return levels[max(0, idx)]
    }

    static func levelForScore(_ score: Int) -> Int {
        var lvl = 1
        for def in levels {
            if score >= def.pointsRequired { lvl = def.level }
            else { break }
        }
        return lvl
    }
}
