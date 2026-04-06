import SwiftUI

struct SettingsScreen: View {
    @ObservedObject private var settings = GameSettings.shared
    @Binding var isShowing: Bool
    let soundEngine: SoundEngine

    @State private var appeared = false

    var body: some View {
        ZStack {
            VoidStyle.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                Text("SETTINGS")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(5)
                    .foregroundColor(VoidStyle.accentSecond)
                    .padding(.top, 70)
                    .padding(.bottom, 44)

                // Settings controls
                VStack(spacing: 32) {
                    // FX Volume
                    VolumeControl(
                        label: "SOUND FX",
                        icon: "speaker.wave.3.fill",
                        value: $settings.fxVolume,
                        accentColor: VoidStyle.accent
                    ) {
                        soundEngine.applyFXVolume()
                    }

                    // Music Volume
                    VolumeControl(
                        label: "MUSIC",
                        icon: "music.note",
                        value: $settings.musicVolume,
                        accentColor: VoidStyle.accent
                    ) {
                        soundEngine.applyMusicVolume()
                    }

                    // Vibration toggle
                    HapticsToggle(enabled: $settings.hapticsEnabled)

                    // Difficulty selector
                    DifficultyPicker(difficulty: $settings.difficulty)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Back button
                Button(action: {
                    HapticEngine.light()
                    withAnimation(.easeOut(duration: 0.25)) {
                        isShowing = false
                    }
                }) {
                    VoidStyle.secondaryButton("BACK", width: 200)
                }
                .buttonStyle(.arcade)

                // Version
                Text("VOID VORTEX v\(appVersion)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.15))
                    .padding(.top, 20)
                    .padding(.bottom, 30)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

// MARK: - Volume Control (segmented bar)
struct VolumeControl: View {
    let label: String
    let icon: String
    @Binding var value: Float
    let accentColor: Color
    let onChange: () -> Void

    private let steps = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label row
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))

                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.45))

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(value > 0 ? accentColor.opacity(0.7) : .white.opacity(0.25))
            }

            // Segmented volume bar
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(0..<steps, id: \.self) { i in
                        let threshold = Float(i + 1) / Float(steps)
                        let isFilled = value >= threshold - 0.05

                        RoundedRectangle(cornerRadius: 2)
                            .fill(isFilled ? accentColor : accentColor.opacity(0.10))
                            .overlay(
                                isFilled ?
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(accentColor.opacity(0.15))
                                        .blur(radius: 2)
                                    : nil
                            )
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let fraction = Float(gesture.location.x / geo.size.width)
                            let clamped = max(0, min(1, fraction))
                            let snapped = (clamped * Float(steps)).rounded() / Float(steps)
                            if snapped != value {
                                value = snapped
                                onChange()
                                if GameSettings.shared.hapticsEnabled {
                                    HapticEngine.light()
                                }
                            }
                        }
                )
            }
            .frame(height: 28)
        }
    }
}

// MARK: - Haptics Toggle
struct HapticsToggle: View {
    @Binding var enabled: Bool

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: enabled ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))

                Text("VIBRATION")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()

            Button(action: {
                enabled.toggle()
                if enabled { HapticEngine.forceLight() }
            }) {
                Text(enabled ? "ON" : "OFF")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2)
                    .foregroundColor(enabled ? VoidStyle.accent : .white.opacity(0.3))
                    .frame(width: 64, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(enabled ? VoidStyle.accent.opacity(0.12) : .white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        enabled ? VoidStyle.accent.opacity(0.3) : .white.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    )
            }
            .buttonStyle(.arcade)
        }
    }
}

// MARK: - Difficulty Picker
struct DifficultyPicker: View {
    @Binding var difficulty: Difficulty

    private func color(for d: Difficulty) -> Color {
        switch d {
        case .easy:   return .green
        case .normal: return VoidStyle.accent
        case .hard:   return VoidStyle.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))

                Text("DIFFICULTY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.45))
            }

            HStack(spacing: 8) {
                ForEach(Difficulty.allCases, id: \.rawValue) { d in
                    let isSelected = difficulty == d
                    let accent = color(for: d)

                    Button(action: {
                        difficulty = d
                        HapticEngine.light()
                    }) {
                        Text(d.label)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2)
                            .foregroundColor(isSelected ? accent : .white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? accent.opacity(0.12) : .white.opacity(0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                isSelected ? accent.opacity(0.4) : .white.opacity(0.06),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.arcade)
                }
            }
        }
    }
}
