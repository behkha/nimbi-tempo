import Foundation

/// Tempo's page for the notch island, in DESIGN.md 18.4's page format (option A in
/// docs/design-choices.md): the glance for the closed island, a title and subtitle, two actions,
/// and a ring as the detail block.
public struct IslandPage: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case toggle, skip, openTimer

        public var key: String {
            switch self {
            case .toggle: return "space"
            case .skip: return "S"
            case .openTimer: return "↩"
            }
        }
    }

    public enum RingColor: Equatable, Sendable { case focus, rest, waiting }

    /// At most 14 characters: "18′", "0:42", "0:00", "Ready".
    public var glance: String
    /// At most 28 characters, like "Focus · 18 min left".
    public var title: String
    /// At most 60 characters.
    public var subtitle: String
    /// The first action, white only when `urgency` is `needsYou` (18.4).
    public var primary: (title: String, action: Action)
    public var secondary: (title: String, action: Action)
    /// Time left, 0…1, for the ring.
    public var left: Double
    public var ring: RingColor
    /// Under the ring: "2 of 4".
    public var caption: String
    public var urgency: Urgency

    public static func == (a: IslandPage, b: IslandPage) -> Bool {
        a.glance == b.glance && a.title == b.title && a.subtitle == b.subtitle && a.primary == b.primary
            && a.secondary == b.secondary && a.left == b.left && a.ring == b.ring && a.caption == b.caption
            && a.urgency == b.urgency
    }

    /// - Parameters:
    ///   - task: what you're working on (T), if anything.
    ///   - today: focus sessions finished today.
    ///   - time: formats an end time ("16:55").
    public init(clock: PomodoroClock, at now: Date, urgency: Urgency, task: String = "", today: Int = 0,
                time: (Date) -> String) {
        let remaining = clock.remaining(at: now)
        let every = clock.settings.longBreakEvery
        let task = task.trimmingCharacters(in: .whitespacesAndNewlines)
        let phase = clock.phase
        let start = phase == .focus ? "Start focus" : "Start break"
        self.urgency = urgency
        caption = "\(min(clock.round, every)) of \(every)"
        ring = phase == .focus ? .focus : .rest
        left = 1 - clock.progress(at: now)
        secondary = ("Timer", .openTimer)

        switch clock.state {
        case .idle(let next):
            glance = "Ready"
            title = next == .focus ? "Ready when you are" : "\(next.title) next"
            subtitle = today == 0 ? "Nothing finished yet today." : "Today · \(Self.sessions(today))"
            primary = (start, .toggle)
            left = 1
        case .running(let p, let endsAt, _):
            glance = TimeText.menuBar(remaining)
            title = "\(p.title) · \(Self.short(remaining)) left"
            switch p {
            case .focus: subtitle = task.isEmpty ? "Until \(time(endsAt))" : "\(task) · until \(time(endsAt))"
            case .shortBreak: subtitle = "Back to it at \(time(endsAt))"
            case .longBreak: subtitle = "\(every) done. Back to it at \(time(endsAt))"
            }
            primary = ("Pause", .toggle)
        case .paused(let p, _, _, _):
            glance = TimeText.menuBar(remaining)
            title = "\(p.title) paused · \(Self.short(remaining))"
            subtitle = task.isEmpty || p.isBreak ? "The cloud is waiting." : task
            primary = ("Resume", .toggle)
        case .finished(let p, _, let next):
            glance = "0:00"
            title = "Time's up"
            subtitle = p == .focus
                ? "\(next == .longBreak ? "A long break" : "A break") is next · \(Self.sessions(today)) today"
                : "Back to focus next."
            primary = (start, .toggle)
            secondary = ("Skip", .skip)
            ring = .waiting
            left = 1
        }
        title = Self.clip(title, 28)
        subtitle = Self.clip(subtitle, 60)
        glance = Self.clip(glance, 14)
    }

    /// "18 min", "42 s".
    static func short(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds).rounded(.up))
        return s >= 60 ? "\(Int((Double(s) / 60).rounded(.up))) min" : "\(s) s"
    }

    static func sessions(_ n: Int) -> String { n == 1 ? "1 session" : "\(n) sessions" }

    static func clip(_ text: String, _ limit: Int) -> String {
        text.count <= limit ? text : String(text.prefix(limit - 1)) + "…"
    }
}
