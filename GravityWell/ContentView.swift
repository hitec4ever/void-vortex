import SwiftUI

struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VoidStyle.bgPrimary
                .ignoresSafeArea()

            GameView(engine: engine)

            // HUD overlay
            if engine.state == .playing || engine.state == .paused {
                HUDView(engine: engine)
            }

            // Start screen
            if engine.state == .start {
                StartScreen(engine: engine, showSettings: $showSettings)
                    .transition(.opacity)
            }

            // Settings screen
            if showSettings {
                SettingsScreen(isShowing: $showSettings, soundEngine: engine.sound)
                    .transition(.opacity)
            }

            // Tutorial screen
            if engine.state == .tutorial {
                TutorialScreen(engine: engine)
                    .transition(.opacity)
            }

            // Game over screen
            if engine.state == .gameOver {
                GameOverScreen(engine: engine)
                    .transition(.opacity)
            }

            // Level up banner (non-blocking overlay during gameplay)
            if engine.showLevelUpBanner {
                LevelUpBanner(engine: engine)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .allowsHitTesting(false)
            }

            // Pause overlay
            if engine.state == .paused {
                PauseOverlay(engine: engine)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: engine.state)
        .onChange(of: engine.state) { _, newState in
            switch newState {
            case .playing:
                engine.sound.musicForGameplay()
            case .paused:
                engine.sound.musicForPause()
            case .start, .gameOver, .tutorial:
                engine.sound.musicForMenu()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && engine.state == .playing {
                engine.togglePause()
            }
        }
    }
}

struct PauseOverlay: View {
    @ObservedObject var engine: GameEngine
    @State private var showQuitConfirm = false
    @State private var showPauseSettings = false
    @State private var showDifficultyRestart = false
    @State private var difficultyBeforeSettings: Difficulty = .normal

    var body: some View {
        ZStack {
            VoidStyle.bgPrimary.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("PAUSED")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(6)
                    .foregroundColor(.white.opacity(0.4))

                Button(action: {
                    engine.togglePause()
                }) {
                    VoidStyle.primaryButton("RESUME", width: 220)
                }
                .buttonStyle(.arcade)

                Button(action: {
                    engine.startGame()
                }) {
                    VoidStyle.secondaryButton("RESTART", width: 220)
                }
                .buttonStyle(.arcade)

                Button(action: {
                    difficultyBeforeSettings = GameSettings.shared.difficulty
                    showPauseSettings = true
                }) {
                    VoidStyle.ghostButton("SETTINGS", width: 220)
                }
                .buttonStyle(.arcade)

                Button(action: {
                    showQuitConfirm = true
                }) {
                    VoidStyle.ghostButton("MAIN MENU", width: 220)
                }
                .buttonStyle(.arcade)
            }

            // Settings overlay on top of pause — game stays paused
            if showPauseSettings {
                SettingsScreen(isShowing: $showPauseSettings, soundEngine: engine.sound)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showPauseSettings)
        .onChange(of: showPauseSettings) { _, isShowing in
            // When settings close, check if difficulty was changed
            if !isShowing && GameSettings.shared.difficulty != difficultyBeforeSettings {
                showDifficultyRestart = true
            }
        }
        .alert("Quit Game?", isPresented: $showQuitConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Quit", role: .destructive) {
                engine.goToMainMenu()
            }
        } message: {
            Text("Your current progress will be lost.")
        }
        .alert("Difficulty Changed", isPresented: $showDifficultyRestart) {
            Button("Restart", role: .destructive) {
                engine.startGame()
            }
            Button("Cancel", role: .cancel) {
                // Revert difficulty back
                GameSettings.shared.difficulty = difficultyBeforeSettings
            }
        } message: {
            Text("The game will restart with the new difficulty.")
        }
    }
}

#Preview {
    ContentView()
}
