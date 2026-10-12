import Foundation
import NimbiKit

/// How urgent Tempo's state is (DESIGN.md 18.5).
public enum Urgency: Int, Comparable, Sendable {
    case none, notice, needsYou

    public static func < (a: Urgency, b: Urgency) -> Bool { a.rawValue < b.rawValue }
}

/// The cloud's state for the timer: its mood, the shape it takes and how far the hourglass has
/// run. The mapping is written down in README.md ("Moods"); keep the two in step.
public struct TempoMood: Equatable, Sendable {
    public var mood: Mood
    public var urgency: Urgency
    /// For `.busy`: how lively the cloud is (NimbiCloud's `working`).
    public var working: Int
    public var form: CloudForm
    /// 0…1 through the phase: the hourglass's sand.
    public var progress: Double

    public init(mood: Mood, urgency: Urgency = .none, working: Int = 0, form: CloudForm = .cloud, progress: Double = 0) {
        self.mood = mood
        self.urgency = urgency
        self.working = working
        self.form = form
        self.progress = progress
    }

    /// Waiting this long, the asking cloud turns impatient.
    public static let impatientAfter: TimeInterval = 45
    /// Waiting this long, it stops pushing: still the bell, but only a notice.
    public static let quietAfter: TimeInterval = 5 * 60
    /// Paused this long, the cloud feels left behind.
    public static let lonelyAfter: TimeInterval = 10 * 60

    /// The first matching row wins.
    /// - Parameter cheerUntil: set for 3 s after a session finishes or the daily goal is reached.
    public static func from(_ clock: PomodoroClock, at now: Date, cheerUntil: Date? = nil) -> TempoMood {
        let progress = clock.progress(at: now)
        // 1. Time's up and nothing started on its own: the bell rings for you.
        if case .finished(_, let at, _) = clock.state {
            let waited = now.timeIntervalSince(at)
            return TempoMood(mood: waited < impatientAfter ? .asking : .impatient,
                             urgency: waited < quietAfter ? .needsYou : .notice,
                             form: .bell, progress: 1)
        }
        let form = runningForm(clock)
        // 2. A session just finished (and the break began), or the day's goal: a moment of joy.
        if let cheerUntil, now < cheerUntil {
            return TempoMood(mood: .happy, form: form, progress: progress)
        }
        switch clock.state {
        case .running(.focus, _, _):
            // 3. Focus: busy, a little livelier with every session in a row.
            return TempoMood(mood: .busy, working: min(clock.streak + 1, 4), form: .hourglass, progress: progress)
        case .running(.shortBreak, _, _):
            return TempoMood(mood: .relaxed, form: .mug, progress: progress)
        case .running(.longBreak, _, _):
            return TempoMood(mood: .asleep, form: .moon, progress: progress)
        case .paused(_, _, _, let since):
            // The tool is set down while paused.
            return TempoMood(mood: now.timeIntervalSince(since) >= lonelyAfter ? .lonely : .relaxed, progress: progress)
        default:
            return TempoMood(mood: .relaxed)
        }
    }

    private static func runningForm(_ clock: PomodoroClock) -> CloudForm {
        guard case .running(let p, _, _) = clock.state else { return .cloud }
        switch p {
        case .focus: return .hourglass
        case .shortBreak: return .mug
        case .longBreak: return .moon
        }
    }
}
