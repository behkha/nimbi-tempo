import Foundation

/// The three kinds of time Tempo keeps.
public enum Phase: String, Codable, CaseIterable, Sendable {
    case focus, shortBreak, longBreak

    public var isBreak: Bool { self != .focus }

    public var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}

/// Where the timer is. Times are absolute dates, so a sleeping Mac or a relaunch never loses
/// track: the timer is simply over when it wakes.
public enum TimerState: Codable, Equatable, Sendable {
    /// Nothing running; `next` starts with space.
    case idle(next: Phase)
    case running(phase: Phase, endsAt: Date, duration: TimeInterval)
    case paused(phase: Phase, remaining: TimeInterval, duration: TimeInterval, since: Date)
    /// Time's up and the next phase didn't start on its own: waiting for you.
    case finished(phase: Phase, at: Date, next: Phase)
}

/// What just happened, for sounds, the log and the cloud.
public enum TimerEvent: Equatable, Sendable {
    /// A phase started, by you or on its own.
    case started(Phase)
    /// A phase ran to its end.
    case completed(Phase, start: Date, end: Date)
    /// Time's up, and the next phase waits for you.
    case waiting(next: Phase)
}

/// The Pomodoro clock as plain values: every change takes `now`, so tests can drive it.
public struct PomodoroClock: Equatable, Sendable {
    public var settings: TimerSettings
    public private(set) var state: TimerState
    /// Focus sessions finished since the last long break.
    public private(set) var streak: Int
    /// 60 normally; less to try the app out quickly (`TEMPO_FAST`).
    public var secondsPerMinute: TimeInterval

    public init(settings: TimerSettings = TimerSettings(), state: TimerState = .idle(next: .focus), streak: Int = 0,
                secondsPerMinute: TimeInterval = 60) {
        self.settings = settings
        self.state = state
        self.streak = streak
        self.secondsPerMinute = secondsPerMinute
    }

    // MARK: Reading

    /// The phase running, paused or waiting to start.
    public var phase: Phase {
        switch state {
        case .idle(let next): return next
        case .running(let p, _, _), .paused(let p, _, _, _): return p
        case .finished(_, _, let next): return next
        }
    }

    public var isRunning: Bool { if case .running = state { return true } else { return false } }
    public var isPaused: Bool { if case .paused = state { return true } else { return false } }
    public var isWaiting: Bool { if case .finished = state { return true } else { return false } }

    public func duration(_ phase: Phase) -> TimeInterval {
        TimeInterval(settings.minutes(phase)) * secondsPerMinute
    }

    /// Seconds left in the current phase; the full length of the next one while idle.
    public func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .idle(let next): return duration(next)
        case .running(_, let endsAt, _): return max(0, endsAt.timeIntervalSince(now))
        case .paused(_, let remaining, _, _): return remaining
        case .finished: return 0
        }
    }

    /// How far through the current phase, 0…1.
    public func progress(at now: Date) -> Double {
        switch state {
        case .idle: return 0
        case .running(_, _, let d), .paused(_, _, let d, _): return d > 0 ? min(1, max(0, 1 - remaining(at: now) / d)) : 1
        case .finished: return 1
        }
    }

    /// The break after this many focus sessions in a row.
    public func breakAfter(streak n: Int) -> Phase {
        n > 0 && n % settings.longBreakEvery == 0 ? .longBreak : .shortBreak
    }

    /// The position in the cycle, for the session dots: 1-based, up to `longBreakEvery`.
    public var round: Int {
        let every = settings.longBreakEvery
        switch phase {
        case .focus: return streak % every + 1
        case .shortBreak, .longBreak: return max(1, (streak - 1) % every + 1)
        }
    }

    // MARK: Changing

    /// Space: start what's next, pause what's running, carry on what's paused.
    public mutating func toggle(at now: Date) -> [TimerEvent] {
        if isRunning { pause(at: now); return [] }
        return start(at: now)
    }

    @discardableResult
    public mutating func start(at now: Date) -> [TimerEvent] {
        switch state {
        case .idle(let next), .finished(_, _, let next):
            return begin(next, at: now)
        case .paused(let p, let remaining, let d, _):
            state = .running(phase: p, endsAt: now.addingTimeInterval(remaining), duration: d)
            return []
        case .running:
            return []
        }
    }

    public mutating func pause(at now: Date) {
        guard case .running(let p, let endsAt, let d) = state else { return }
        state = .paused(phase: p, remaining: max(0, endsAt.timeIntervalSince(now)), duration: d, since: now)
    }

    /// S: leave this phase for the next one. A skipped focus session doesn't count. A running
    /// timer goes straight on with the next phase; anything else waits for space.
    @discardableResult
    public mutating func skip(at now: Date) -> [TimerEvent] {
        switch state {
        case .running(let p, _, _):
            return begin(following(p), at: now)
        case .paused(let p, _, _, _):
            state = .idle(next: following(p))
        case .idle(let next), .finished(_, _, let next):
            state = .idle(next: following(next))
        }
        return []
    }

    /// R: start the current phase over, stopped. At rest, it starts the whole cycle over.
    public mutating func reset() {
        switch state {
        case .running(let p, _, _), .paused(let p, _, _, _):
            state = .idle(next: p)
        case .finished(_, _, let next):
            state = .idle(next: next)
        case .idle:
            state = .idle(next: .focus)
            streak = 0
        }
    }

    /// Call every second or so: ends the phase when its time is up.
    public mutating func tick(at now: Date) -> [TimerEvent] {
        guard case .running(let p, let endsAt, let d) = state, now >= endsAt else { return [] }
        var events: [TimerEvent] = [.completed(p, start: endsAt.addingTimeInterval(-d), end: endsAt)]
        let next: Phase
        if p == .focus {
            streak += 1
            next = breakAfter(streak: streak)
        } else {
            if p == .longBreak { streak = 0 }
            next = .focus
        }
        if next.isBreak ? settings.autoStartBreaks : settings.autoStartFocus {
            events += begin(next, at: now)
        } else {
            state = .finished(phase: p, at: endsAt, next: next)
            events.append(.waiting(next: next))
        }
        return events
    }

    // MARK: Inside

    private mutating func begin(_ p: Phase, at now: Date) -> [TimerEvent] {
        let d = duration(p)
        state = .running(phase: p, endsAt: now.addingTimeInterval(d), duration: d)
        return [.started(p)]
    }

    /// What comes after `p` when it's skipped: the break a finished session would have earned,
    /// or focus after a break.
    private mutating func following(_ p: Phase) -> Phase {
        switch p {
        case .focus: return breakAfter(streak: streak + 1)
        case .longBreak: streak = 0; return .focus
        case .shortBreak: return .focus
        }
    }
}

/// What a relaunch needs to carry on where the timer was.
public struct ClockSnapshot: Codable, Equatable, Sendable {
    public var state: TimerState
    public var streak: Int

    public init(_ clock: PomodoroClock) {
        state = clock.state
        streak = clock.streak
    }
}
