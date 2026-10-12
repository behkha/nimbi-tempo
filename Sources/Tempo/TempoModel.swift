import AppKit
import Combine
import NimbiKit
import TempoCore

/// The timer, the log and the sounds, ticking once a second. Everything the views and the menu
/// bar show comes from here.
@MainActor
final class TempoModel: ObservableObject {
    @Published private(set) var clock: PomodoroClock
    @Published private(set) var now = Date()
    @Published private(set) var log: SessionLog
    /// What you're working on (T). Saved with each finished session.
    @Published var task: String {
        didSet { if !demo { UserDefaults.standard.set(task, forKey: Keys.task) } }
    }
    @Published var settings: TimerSettings {
        didSet {
            settings = settings.clamped
            clock.settings = settings
            if !demo { Saved.store(settings, Keys.settings) }
        }
    }
    @Published var sounds: SoundSettings {
        didSet {
            if !demo { Saved.store(sounds, Keys.sounds) }
            syncAmbience()
        }
    }
    /// A moment of joy after a session or the daily goal (DESIGN.md 3.3: happy for 2.5–3.5 s).
    @Published private(set) var cheerUntil: Date?
    /// R waits behind the undo bar (DESIGN.md 2.8): the clock as it was, and when.
    @Published private(set) var undo: (clock: PomodoroClock, started: Date)?

    let player = SoundPlayer()
    let ambience = AmbiencePlayer()
    private let store = SessionStore.standard
    private var ticker: Timer?
    private var wake: NSObjectProtocol?
    /// A made-up state for checking the look (`TEMPO_DEMO`), or minutes squeezed into seconds
    /// (`TEMPO_FAST`): nothing is saved, so the real log and timer stay untouched.
    private let demo: Bool

    private enum Keys {
        static let settings = "TimerSettings", sounds = "SoundSettings", clock = "Clock", task = "Task"
    }

    init() {
        let env = ProcessInfo.processInfo.environment
        let settings = (Saved.load(TimerSettings.self, Keys.settings) ?? TimerSettings()).clamped
        // TEMPO_FAST=2 makes a minute last two seconds, to watch a whole cycle quickly.
        let minute = env["TEMPO_FAST"].flatMap(Double.init).map { max(0.5, $0) } ?? 60
        var clock = PomodoroClock(settings: settings, secondsPerMinute: minute)
        if minute == 60, let saved = Saved.load(ClockSnapshot.self, Keys.clock) {
            clock = PomodoroClock(settings: settings, state: saved.state, streak: saved.streak, secondsPerMinute: minute)
        }
        self.settings = settings
        self.sounds = Saved.load(SoundSettings.self, Keys.sounds) ?? SoundSettings()
        self.task = UserDefaults.standard.string(forKey: Keys.task) ?? ""
        self.log = store.load()
        self.demo = Demo.state != nil || minute != 60
        if let state = Demo.state {
            clock = PomodoroClock(settings: settings, state: state.state(at: Date(), settings: settings), streak: 2)
            task = "Writing the release notes"
            log = Demo.log
        }
        self.clock = clock
    }

    func start() {
        // A phase that ended while Tempo was closed or the Mac was asleep.
        tick()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        t.tolerance = 0.15
        RunLoop.main.add(t, forMode: .common)
        ticker = t
        wake = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                                 queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        syncAmbience()
        if Demo.state == .cycle { tour(0) }
    }

    /// `TEMPO_DEMO=cycle`: the next made-up state every 3.5 s.
    private func tour(_ i: Int) {
        let scene = Demo.Scene.tour[i % Demo.Scene.tour.count]
        clock = PomodoroClock(settings: settings, state: scene.state(at: Date(), settings: settings), streak: 2)
        now = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in self?.tour(i + 1) }
    }

    // MARK: Reading

    var mood: TempoMood { TempoMood.from(clock, at: now, cheerUntil: cheerUntil) }
    var remaining: TimeInterval { clock.remaining(at: now) }
    var progress: Double { clock.progress(at: now) }
    var todayCount: Int { log.count(on: now) }
    var todayMinutes: Int { log.minutes(on: now) }

    // MARK: Acting

    /// Space, or ⌃⌥P from anywhere.
    func toggle() {
        flushUndo()
        now = Date()
        apply(clock.toggle(at: now))
    }

    /// S
    func skip() {
        flushUndo()
        now = Date()
        apply(clock.skip(at: now))
    }

    /// R, behind the undo bar.
    func reset() {
        flushUndo()
        now = Date()
        let before = clock
        clock.reset()
        guard clock != before else { return }
        undo = (before, now)
        saveClock()
        syncAmbience()
        let started = now
        DispatchQueue.main.asyncAfter(deadline: .now() + Nimbi.Motion.undoWindowDestructive) { [weak self] in
            guard let self, let undo = self.undo, undo.started == started else { return }
            self.undo = nil
        }
    }

    /// esc while the undo bar shows: the clock as it was (a running timer kept running).
    @discardableResult
    func undoReset() -> Bool {
        guard let undo else { return false }
        clock = undo.clock
        self.undo = nil
        tick()
        saveClock()
        syncAmbience()
        return true
    }

    private func flushUndo() { undo = nil }

    // MARK: Inside

    private func tick() {
        now = Date()
        apply(clock.tick(at: now))
    }

    private func apply(_ events: [TimerEvent]) {
        guard !events.isEmpty else { return }
        var completedFocus = false
        for event in events {
            switch event {
            case .started(.focus):
                if !events.contains(where: { if case .completed = $0 { return true } else { return false } }) {
                    play(.focusStarts)
                }
            case .started:
                break
            case .completed(.focus, let start, let end):
                completedFocus = true
                let name = task.trimmingCharacters(in: .whitespacesAndNewlines)
                if !demo {
                    log.add(FocusSession(start: start, end: end, task: name.isEmpty ? nil : name))
                    log.prune(now: now)
                    store.save(log)
                }
            case .completed:
                play(.breakEnds)
            case .waiting:
                break
            }
        }
        if completedFocus {
            // The goal's own sound on the session that reaches it; the usual one otherwise.
            play(todayCount == settings.dailyGoal ? .dailyGoal : .focusEnds)
            if !clock.isWaiting { cheer() }
        }
        saveClock()
        syncAmbience()
    }

    private func cheer() {
        let until = now.addingTimeInterval(3)
        cheerUntil = until
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.05) { [weak self] in
            guard let self, self.cheerUntil == until else { return }
            self.cheerUntil = nil
            self.now = Date()
        }
    }

    private func play(_ event: SoundEvent) {
        guard sounds.enabled else { return }
        player.play(sounds[event], volume: sounds.volume)
    }

    private func saveClock() {
        if !demo { Saved.store(ClockSnapshot(clock), Keys.clock) }
    }

    /// Weather to work in: only while focus runs, and only if it's on.
    private func syncAmbience() {
        let on = sounds.enabled && clock.isRunning && clock.phase == .focus
        ambience.play(on ? sounds.ambience : .off, volume: sounds.volume * sounds.ambienceVolume)
    }

    /// Picking a sound in settings plays it (DESIGN.md 10).
    func preview(_ sound: SystemSound) { player.play(sound, volume: sounds.volume) }

    /// A few seconds of the ambience, from settings.
    func previewAmbience() {
        guard sounds.ambience != .off else { syncAmbience(); return }
        ambience.play(sounds.ambience, volume: sounds.volume * sounds.ambienceVolume)
        let picked = sounds.ambience
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.sounds.ambience == picked else { return }
            self.syncAmbience()
        }
    }
}
