import AVFoundation
import AudioToolbox

enum SoundType {
    case thrustIn
    case thrustOut
    case thrustLoop
    case collect
    case hit
    case death
    case wave
    case shield
}

class SoundEngine {
    private var audioEngine: AVAudioEngine?
    private var isReady = false

    // Reverb for spatial feel
    private var reverbNode: AVAudioUnitReverb?

    // ── Node Pool (pre-allocated, permanently connected) ──
    private let poolSize = 8
    private var nodePool: [AVAudioPlayerNode] = []
    private var nextNodeIndex = 0

    // ── Cached Buffers (synthesized once, reused every play) ──
    private var cachedCollect: AVAudioPCMBuffer?
    private var cachedHit: AVAudioPCMBuffer?
    private var cachedDeath: AVAudioPCMBuffer?
    private var cachedWave: AVAudioPCMBuffer?
    private var cachedShield: AVAudioPCMBuffer?
    private var cachedThrustIn: AVAudioPCMBuffer?
    private var cachedThrustOut: AVAudioPCMBuffer?
    private var buffersReady = false

    // Looping thruster sound (dedicated node, not from pool)
    private var thrustPlayerNode: AVAudioPlayerNode?
    private var isThrustPlaying = false
    private var currentThrustType: SoundType?

    // Background music
    private var musicPlayer: AVAudioPlayer?
    private let musicMenuVolume: Float = 0.45     // menu / start screen
    private let musicGameVolume: Float = 0.22     // during gameplay (ducked)
    private let musicPauseVolume: Float = 0.30    // paused
    private var musicTargetVolume: Float = 0.45
    private var musicFadeTimer: Timer?

    init() {
        setupAudioSession()
        // Start music immediately when SoundEngine is created (app launch)
        startBackgroundMusic()
    }

    // MARK: - Audio Session
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    func ensureReady() {
        guard !isReady else { return }
        let engine = AVAudioEngine()

        // Setup reverb for richer sounds
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 25  // subtle — just enough space
        engine.attach(reverb)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        // Audio format for all synthesized sounds
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        // ── Pre-allocate node pool ──
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: reverb, format: format)
            nodePool.append(node)
        }

        // Start the engine once
        do {
            try engine.start()
        } catch {
            print("Engine start error: \(error)")
        }

        audioEngine = engine
        reverbNode = reverb
        isReady = true

        // Apply user's FX volume setting
        applyFXVolume()

        // ── Pre-synthesize all sound buffers on background thread ──
        preSynthesizeBuffers()
    }

    /// Synthesize all one-shot sound buffers once, cache them for instant playback
    private func preSynthesizeBuffers() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }

            self.cachedCollect = self.synthesizeLayered(layers: [
                ToneLayer(freq: 580, rampTo: 1150, volume: 0.06, waveform: .sine),
                ToneLayer(freq: 870, rampTo: 1730, volume: 0.025, waveform: .sine),
                ToneLayer(freq: 1160, rampTo: 2300, volume: 0.012, waveform: .sine),
            ], duration: 0.18, noiseAmount: 0.008)

            self.cachedHit = self.synthesizeLayered(layers: [
                ToneLayer(freq: 220, rampTo: 40, volume: 0.12, waveform: .sine),
                ToneLayer(freq: 440, rampTo: 90, volume: 0.06, waveform: .sawtooth),
                ToneLayer(freq: 660, rampTo: 120, volume: 0.03, waveform: .sawtooth),
                ToneLayer(freq: 100, rampTo: 18, volume: 0.08, waveform: .sine),
                ToneLayer(freq: 1200, rampTo: 200, volume: 0.015, waveform: .triangle),
            ], duration: 0.4, noiseAmount: 0.07, noiseDecay: 12.0)

            self.cachedDeath = self.synthesizeLayered(layers: [
                ToneLayer(freq: 250, rampTo: 25, volume: 0.08, waveform: .sawtooth),
                ToneLayer(freq: 125, rampTo: 15, volume: 0.06, waveform: .sine),
                ToneLayer(freq: 375, rampTo: 40, volume: 0.03, waveform: .sawtooth),
                ToneLayer(freq: 60, rampTo: 10, volume: 0.05, waveform: .sine),
            ], duration: 1.2, noiseAmount: 0.025, noiseDecay: 3.0)

            self.cachedWave = self.synthesizeArpeggio(
                notes: [
                    (400, 0.05), (500, 0.05), (600, 0.05),
                    (700, 0.05), (800, 0.07), (1000, 0.08)
                ],
                volume: 0.055, harmonicVolume: 0.018
            )

            self.cachedShield = self.synthesizeArpeggio(
                notes: [(800, 0.06), (1000, 0.06), (1200, 0.08)],
                volume: 0.05, harmonicVolume: 0.02
            )

            self.cachedThrustIn = self.synthesizeThrust(isInward: true)
            self.cachedThrustOut = self.synthesizeThrust(isInward: false)

            DispatchQueue.main.async {
                self.buffersReady = true
            }
        }
    }

    // MARK: - Settings Integration

    /// Apply current FX volume setting to the audio engine mixer
    func applyFXVolume() {
        audioEngine?.mainMixerNode.outputVolume = GameSettings.shared.fxVolume
    }

    /// Apply current music volume setting to the music player
    func applyMusicVolume() {
        guard let player = musicPlayer else { return }
        let master = GameSettings.shared.musicVolume
        player.volume = musicTargetVolume * master
    }

    // MARK: - Background Music
    func startBackgroundMusic() {
        guard musicPlayer == nil else { return }

        guard let url = Bundle.main.url(forResource: "Void Vortex", withExtension: "mp3") else {
            print("Background music file not found in bundle")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1  // loop forever
            let master = GameSettings.shared.musicVolume
            player.volume = musicMenuVolume * master
            player.prepareToPlay()
            player.play()
            musicPlayer = player
            musicTargetVolume = musicMenuVolume
        } catch {
            print("Music player error: \(error)")
        }
    }

    /// Smoothly transition music volume over a short duration
    func setMusicVolume(_ target: Float, duration: TimeInterval = 0.8) {
        musicTargetVolume = target
        let master = GameSettings.shared.musicVolume
        let effectiveTarget = target * master
        musicFadeTimer?.invalidate()

        guard let player = musicPlayer else { return }

        let steps = 20
        let interval = duration / Double(steps)
        let startVol = player.volume
        let delta = effectiveTarget - startVol
        var step = 0

        musicFadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            step += 1
            let t = Float(step) / Float(steps)
            // Ease-in-out curve
            let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            player.volume = startVol + delta * eased

            if step >= steps {
                timer.invalidate()
                self?.musicFadeTimer = nil
                player.volume = effectiveTarget
            }
        }
    }

    /// Called when game state changes to adjust music volume
    func musicForMenu() { setMusicVolume(musicMenuVolume) }
    func musicForGameplay() { setMusicVolume(musicGameVolume) }
    func musicForPause() { setMusicVolume(musicPauseVolume) }

    // MARK: - Thrust Sound Management
    func startThrust(type: SoundType) {
        guard isReady, let engine = audioEngine, let reverb = reverbNode else { return }

        if isThrustPlaying && currentThrustType == type { return }
        stopThrust()

        currentThrustType = type
        let buffer = (type == .thrustIn) ? cachedThrustIn : cachedThrustOut

        guard let thrustBuffer = buffer else { return }

        // Ensure engine is running
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }

        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(playerNode, to: reverb, format: format)

        // Schedule BEFORE play — ensures buffer is ready when playback starts
        playerNode.scheduleBuffer(thrustBuffer, at: nil, options: .loops)
        playerNode.play()
        self.thrustPlayerNode = playerNode
        self.isThrustPlaying = true
    }

    func stopThrust() {
        if let node = thrustPlayerNode {
            node.stop()
            audioEngine?.detach(node)
            thrustPlayerNode = nil
        }
        isThrustPlaying = false
        currentThrustType = nil
    }

    // MARK: - Sound Effects
    func play(_ type: SoundType) {
        if type == .thrustIn || type == .thrustOut {
            startThrust(type: type)
            return
        }
        guard buffersReady else { return }

        let buffer: AVAudioPCMBuffer?
        switch type {
        case .thrustLoop, .thrustIn, .thrustOut:
            return
        case .collect:
            buffer = cachedCollect
        case .hit:
            buffer = cachedHit
        case .death:
            buffer = cachedDeath
        case .wave:
            buffer = cachedWave
        case .shield:
            buffer = cachedShield
        }

        if let buf = buffer {
            playFromPool(buf)
        }
    }

    // MARK: - Node Pool Playback

    /// Play a buffer using the next node from the pre-allocated pool (round-robin).
    /// Each node is disconnected and reconnected right before use — guarantees
    /// the node is never in a "disconnected" state when play() is called.
    private func playFromPool(_ buffer: AVAudioPCMBuffer) {
        guard !nodePool.isEmpty, let engine = audioEngine, let reverb = reverbNode else { return }

        // Ensure engine is running
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }

        let node = nodePool[nextNodeIndex]
        nextNodeIndex = (nextNodeIndex + 1) % poolSize

        // Always: stop → disconnect → reconnect → schedule → play
        // This guarantees the node is connected, regardless of engine state changes
        node.stop()
        engine.disconnectNodeOutput(node)
        engine.connect(node, to: reverb, format: buffer.format)
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        node.play()
    }

    // MARK: - Synthesis (pure functions, no playback — called once at startup)

    private struct ToneLayer {
        let freq: Float
        let rampTo: Float
        let volume: Float
        let waveform: Waveform
    }

    private enum Waveform {
        case sine
        case sawtooth
        case triangle
    }

    /// Synthesize a layered tone buffer (returns buffer, doesn't play)
    private func synthesizeLayered(layers: [ToneLayer], duration: Float,
                                    noiseAmount: Float = 0, noiseDecay: Float = 5.0) -> AVAudioPCMBuffer? {
        let sampleRate: Float = 44100
        let sampleCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        // Zero out
        for i in 0..<sampleCount { data[i] = 0 }

        // Render each layer
        for layer in layers {
            var phase: Float = 0
            for i in 0..<sampleCount {
                let t = Float(i) / Float(sampleCount)
                let freq = layer.freq + (layer.rampTo - layer.freq) * t
                // Smoother envelope: attack + exponential decay
                let attack = min(1, t * 80)  // 1.25ms attack (no click)
                let decay = (1 - t) * (1 - t)
                let envelope = layer.volume * attack * decay
                let increment = freq / sampleRate

                var sample: Float
                switch layer.waveform {
                case .sine:
                    sample = sin(phase * .pi * 2) * envelope
                case .sawtooth:
                    // Band-limited sawtooth (softer than raw)
                    let raw = 2 * (phase - floor(phase + 0.5))
                    sample = raw * 0.7 * envelope  // attenuate harshness
                case .triangle:
                    sample = (4 * abs(phase - floor(phase + 0.75) + 0.25) - 1) * envelope
                }

                data[i] += sample
                phase += increment
                if phase > 1 { phase -= 1 }
            }
        }

        // Add filtered noise layer (impact texture)
        if noiseAmount > 0 {
            var prevNoise: Float = 0
            for i in 0..<sampleCount {
                let t = Float(i) / Float(sampleCount)
                let noiseEnv = noiseAmount * exp(-t * noiseDecay)
                let raw = Float.random(in: -1...1)
                let filtered = 0.15 * raw + 0.85 * prevNoise
                prevNoise = filtered
                data[i] += filtered * noiseEnv
            }
        }

        // Boost + soft-clip to prevent distortion from layering
        let gain: Float = 2.5
        for i in 0..<sampleCount {
            let x = data[i] * gain
            data[i] = x / (1 + abs(x) * 0.5)  // gentle saturation
        }

        return buffer
    }

    /// Synthesize a rich arpeggio buffer (returns buffer, doesn't play)
    private func synthesizeArpeggio(notes: [(freq: Float, dur: Float)],
                                     volume: Float, harmonicVolume: Float) -> AVAudioPCMBuffer? {
        let sampleRate: Float = 44100
        let totalDuration = notes.reduce(Float(0)) { $0 + $1.dur } + 0.15
        let sampleCount = Int(sampleRate * totalDuration)

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<sampleCount { data[i] = 0 }

        var phase: Float = 0
        var harmPhase: Float = 0
        var currentStart: Float = 0

        for note in notes {
            let startSample = Int(sampleRate * currentStart)
            let noteSamples = Int(sampleRate * (note.dur + 0.08))

            for i in 0..<noteSamples {
                let si = startSample + i
                guard si < sampleCount else { break }
                let t = Float(i) / Float(noteSamples)
                let attack = min(1, t * 30)
                let decay = (1 - t) * (1 - t)
                let env = attack * decay

                // Fundamental
                let fundamental = sin(phase * .pi * 2) * volume * env
                // 2nd harmonic (octave shimmer)
                let harmonic = sin(harmPhase * .pi * 2) * harmonicVolume * env

                data[si] += fundamental + harmonic

                phase += note.freq / sampleRate
                if phase > 1 { phase -= 1 }
                harmPhase += (note.freq * 2) / sampleRate
                if harmPhase > 1 { harmPhase -= 1 }
            }
            currentStart += note.dur
        }

        // Boost + soft-clip
        let gain: Float = 2.5
        for i in 0..<sampleCount {
            let x = data[i] * gain
            data[i] = x / (1 + abs(x) * 0.5)
        }

        return buffer
    }

    /// Synthesize thrust loop buffer (returns buffer, doesn't play)
    private func synthesizeThrust(isInward: Bool) -> AVAudioPCMBuffer? {
        let sampleRate: Float = 44100
        let duration: Float = 0.3
        let sampleCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        guard let data = buffer.floatChannelData?[0] else { return nil }

        // Richer thruster: layered synthesis
        let baseFreq: Float = isInward ? 80 : 130
        let modFreq: Float = isInward ? 40 : 55
        let sub1Freq: Float = isInward ? 42 : 68     // sub-harmonic layer
        let hissFreq: Float = isInward ? 2200 : 3500  // high hiss band
        let volume: Float = 0.04

        var phase: Float = 0
        var modPhase: Float = 0
        var sub1Phase: Float = 0
        var hissPhase: Float = 0
        var prevNoise: Float = 0  // for low-pass filter

        for i in 0..<sampleCount {
            let t = Float(i) / Float(sampleCount)

            // FM modulation for organic rumble
            let mod = sin(modPhase * .pi * 2) * 0.35
            let freq = baseFreq + baseFreq * mod

            // Layer 1: Main engine tone (sine + slight distortion)
            let rawSine = sin(phase * .pi * 2)
            let mainTone = rawSine * 0.45 + (rawSine * rawSine * rawSine) * 0.15  // soft clip

            // Layer 2: Sub-harmonic rumble
            let sub = sin(sub1Phase * .pi * 2) * 0.25

            // Layer 3: Filtered noise (engine hiss)
            let rawNoise = Float.random(in: -1...1)
            // One-pole low-pass filter: y[n] = alpha * x[n] + (1-alpha) * y[n-1]
            let alpha: Float = isInward ? 0.08 : 0.15
            let filteredNoise = alpha * rawNoise + (1 - alpha) * prevNoise
            prevNoise = filteredNoise
            let hiss = filteredNoise * (isInward ? 0.15 : 0.25)

            // Layer 4: High shimmer (very subtle)
            let shimmer = sin(hissPhase * .pi * 2) * 0.03

            // Smooth loop envelope
            let fadeIn = min(1, t * 20)
            let fadeOut = min(1, (1 - t) * 20)
            let envelope = fadeIn * fadeOut * volume

            data[i] = (mainTone + sub + hiss + shimmer) * envelope

            phase += freq / sampleRate
            if phase > 1 { phase -= 1 }
            modPhase += modFreq / sampleRate
            if modPhase > 1 { modPhase -= 1 }
            sub1Phase += sub1Freq / sampleRate
            if sub1Phase > 1 { sub1Phase -= 1 }
            hissPhase += hissFreq / sampleRate
            if hissPhase > 1 { hissPhase -= 1 }
        }

        return buffer
    }
}
