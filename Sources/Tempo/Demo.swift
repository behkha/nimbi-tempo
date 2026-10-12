import Foundation
import TempoCore

/// `TEMPO_DEMO=focus|up|break|long|paused|ready` shows a made-up timer, for checking the look
/// without waiting 25 minutes; `cycle` steps through them every few seconds, to watch the cloud
/// morph. Nothing is saved while it runs.
enum Demo {
    enum Scene: String {
        case ready, focus, up, `break`, long, paused, cycle

        /// The order `cycle` shows them in.
        static let tour: [Scene] = [.ready, .focus, .up, .break, .focus, .long, .paused]

        func state(at now: Date, settings: TimerSettings) -> TimerState {
            let focus = TimeInterval(settings.focusMinutes * 60)
            switch self {
            case .ready, .cycle: return .idle(next: .focus)
            case .focus: return .running(phase: .focus, endsAt: now.addingTimeInterval(18 * 60 + 42), duration: focus)
            case .up: return .finished(phase: .focus, at: now.addingTimeInterval(-5), next: .shortBreak)
            case .break: return .running(phase: .shortBreak, endsAt: now.addingTimeInterval(3 * 60 + 10),
                                         duration: TimeInterval(settings.shortBreakMinutes * 60))
            case .long: return .running(phase: .longBreak, endsAt: now.addingTimeInterval(11 * 60),
                                        duration: TimeInterval(settings.longBreakMinutes * 60))
            case .paused: return .paused(phase: .focus, remaining: 12 * 60, duration: focus, since: now.addingTimeInterval(-11 * 60))
            }
        }
    }

    static let state: Scene? = ProcessInfo.processInfo.environment["TEMPO_DEMO"].flatMap(Scene.init(rawValue:))

    static var log: SessionLog {
        var log = SessionLog()
        let now = Date()
        for i in 1...5 {
            let end = now.addingTimeInterval(-Double(i) * 32 * 60)
            log.add(FocusSession(start: end.addingTimeInterval(-25 * 60), end: end, task: "Release notes"))
        }
        return log
    }
}
