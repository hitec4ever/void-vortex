import Foundation

// MARK: - Difficulty
enum Difficulty: Int, CaseIterable {
    case easy = 0
    case normal = 1
    case hard = 2

    var label: String {
        switch self {
        case .easy:   return "EASY"
        case .normal: return "NORMAL"
        case .hard:   return "HARD"
        }
    }

    /// Multiplier on gravity pull
    var gravityMul: CGFloat {
        switch self {
        case .easy:   return 0.7
        case .normal: return 1.0
        case .hard:   return 1.4
        }
    }

    /// Multiplier on obstacle spawn rate
    var spawnRateMul: CGFloat {
        switch self {
        case .easy:   return 0.7
        case .normal: return 1.0
        case .hard:   return 1.3
        }
    }

    /// Multiplier on orbital speed
    var orbSpeedMul: CGFloat {
        switch self {
        case .easy:   return 0.9
        case .normal: return 1.0
        case .hard:   return 1.15
        }
    }

    /// Starting lives
    var startLives: Int { 3 }

    /// Shield duration
    var shieldDuration: CGFloat {
        switch self {
        case .easy:   return 7
        case .normal: return 5
        case .hard:   return 3.5
        }
    }

    /// Player invincibility after hit
    var invincibilityTime: CGFloat {
        switch self {
        case .easy:   return 3.0
        case .normal: return 2.5
        case .hard:   return 1.8
        }
    }

    /// Proximity gravity boost factor (quadratic max)
    var proxGravBoost: CGFloat {
        switch self {
        case .easy:   return 1.2
        case .normal: return 2.0
        case .hard:   return 3.0
        }
    }
}

/// Persisted user preferences — singleton accessed via GameSettings.shared
class GameSettings: ObservableObject {
    static let shared = GameSettings()

    @Published var fxVolume: Float {
        didSet { UserDefaults.standard.set(fxVolume, forKey: "vv_fxVolume") }
    }

    @Published var musicVolume: Float {
        didSet { UserDefaults.standard.set(musicVolume, forKey: "vv_musicVolume") }
    }

    @Published var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "vv_haptics") }
    }

    @Published var difficulty: Difficulty {
        didSet { UserDefaults.standard.set(difficulty.rawValue, forKey: "vv_difficulty") }
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "vv_fxVolume": Float(1.0),
            "vv_musicVolume": Float(1.0),
            "vv_haptics": true,
            "vv_difficulty": Difficulty.normal.rawValue
        ])
        self.fxVolume = d.float(forKey: "vv_fxVolume")
        self.musicVolume = d.float(forKey: "vv_musicVolume")
        self.hapticsEnabled = d.bool(forKey: "vv_haptics")
        self.difficulty = Difficulty(rawValue: d.integer(forKey: "vv_difficulty")) ?? .normal
    }
}
