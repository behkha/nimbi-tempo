import AVFoundation
import AppKit
import TempoCore

/// The macOS system sounds (DESIGN.md 10), one per event.
@MainActor
final class SoundPlayer {
    private var playing: NSSound?

    func play(_ sound: SystemSound, volume: Double) {
        guard sound != .none, let base = NSSound(named: NSSound.Name(sound.rawValue)),
              let copy = base.copy() as? NSSound else { return }
        playing?.stop()
        copy.volume = Float(max(0, min(1, volume)))
        copy.play()
        playing = copy
    }
}

/// Weather to work in, made from noise on the spot: no audio files. It fades in when focus
/// starts and out when it stops, and the engine sleeps while it's silent.
@MainActor
final class AmbiencePlayer {
    private let engine = AVAudioEngine()
    private let voice = NoiseVoice()
    private var node: AVAudioSourceNode?
    private var stopWork: DispatchWorkItem?
    private(set) var current = Ambience.off

    func play(_ ambience: Ambience, volume: Double) {
        if ambience == .off {
            current = .off
            voice.target = 0
            scheduleStop()
            return
        }
        stopWork?.cancel()
        stopWork = nil
        if ambience != current { voice.kind = ambience }
        current = ambience
        voice.target = Float(max(0, min(1, volume)))
        startEngine()
    }

    private func startEngine() {
        if node == nil {
            let format = engine.outputNode.inputFormat(forBus: 0)
            let rate = format.sampleRate > 0 ? format.sampleRate : 44_100
            voice.sampleRate = Float(rate)
            let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
            let voice = self.voice
            let n = AVAudioSourceNode(format: mono) { _, _, frames, buffers -> OSStatus in
                let list = UnsafeMutableAudioBufferListPointer(buffers)
                guard let out = list.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
                voice.render(into: out, count: Int(frames))
                return noErr
            }
            engine.attach(n)
            engine.connect(n, to: engine.mainMixerNode, format: mono)
            node = n
        }
        if !engine.isRunning { try? engine.start() }
    }

    /// Lets the fade finish, then stops the engine so it costs nothing while silent.
    private func scheduleStop() {
        guard stopWork == nil, engine.isRunning else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.current == .off else { return }
            self.engine.pause()
            self.stopWork = nil
        }
        stopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
}

/// The sound itself, run on the audio thread. Plain filters over white noise:
/// - soft rain: noise between about 900 Hz and 7 kHz, with now and then a nearer drop,
/// - distant storm: deep brown noise that swells slowly, like thunder far off,
/// - wind: brown noise through a resonant band that sweeps slowly up and down,
/// - brown noise: as it is.
final class NoiseVoice: @unchecked Sendable {
    var kind = Ambience.rain
    /// 0…1: the level it fades toward.
    var target: Float = 0
    var sampleRate: Float = 44_100

    private var gain: Float = 0
    private var seed: UInt32 = 0x9E37_79B9
    private var brown: Float = 0
    private var low1: Float = 0, low2: Float = 0
    private var band: Float = 0, bandLow: Float = 0
    private var t: Float = 0
    private var drop: Float = 0, dropFilter: Float = 0

    private func white() -> Float {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    private func onePole(_ hz: Float) -> Float { 1 - exp(-2 * .pi * hz / sampleRate) }

    func render(into out: UnsafeMutablePointer<Float>, count: Int) {
        // About 1.5 s to fade in, 1 s to fade out.
        let up = 1 / (1.5 * sampleRate), down = 1 / (1.0 * sampleRate)
        let lp7k = onePole(7_000), lp900 = onePole(900), lp380 = onePole(380)
        let dt = 1 / sampleRate
        for i in 0..<count {
            gain += gain < target ? min(up, target - gain) : -min(down, gain - target)
            if gain <= 0.0001 && target == 0 { out[i] = 0; continue }
            let w = white()
            brown = (brown + 0.02 * w) / 1.02
            var s: Float
            switch kind {
            case .off:
                s = 0
            case .rain:
                low1 += lp7k * (w - low1)              // below 7 kHz
                low2 += lp900 * (low1 - low2)          // what's below 900 Hz, taken away
                s = (low1 - low2) * 0.5
                // A nearer drop now and then: a short, bright tick.
                if drop < 0.001, white() > 0.9993 { drop = 0.6 + 0.4 * abs(white()) }
                drop *= 0.9965
                dropFilter += onePole(2_400) * (white() * drop - dropFilter)
                s += dropFilter * 0.5
            case .storm:
                low1 += lp380 * (brown * 3.5 - low1)
                let swell = 0.55 + 0.45 * sin(2 * .pi * 0.07 * t)
                s = low1 * 2.2 * swell
            case .wind:
                // A state-variable band-pass whose centre drifts between ~250 and ~800 Hz.
                let centre = 520 + 270 * sin(2 * .pi * 0.11 * t) + 60 * sin(2 * .pi * 0.37 * t)
                let f = 2 * sin(.pi * centre / sampleRate)
                let input = brown * 3.5 + w * 0.08
                bandLow += f * band
                let high = input - bandLow - 0.9 * band
                band += f * high
                s = band * 0.9
            case .brown:
                s = brown * 3.5
            }
            t += dt
            if t > 10_000 { t = 0 }
            out[i] = max(-1, min(1, s * gain))
        }
    }
}
