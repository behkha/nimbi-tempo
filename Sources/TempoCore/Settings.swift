import Foundation

/// How long things last and what starts on its own. Saved as JSON in the user defaults.
public struct TimerSettings: Codable, Equatable, Sendable {
    public var focusMinutes = 25
    public var shortBreakMinutes = 5
    public var longBreakMinutes = 15
    /// A long break after this many focus sessions in a row.
    public var longBreakEvery = 4
    public var autoStartBreaks = true
    public var autoStartFocus = false
    /// Focus sessions a day that count as a good day.
    public var dailyGoal = 8

    public init() {}

    public static let focusRange = 5...90
    public static let shortBreakRange = 1...30
    public static let longBreakRange = 5...60
    public static let longBreakEveryRange = 2...8
    public static let dailyGoalRange = 1...16

    public func minutes(_ phase: Phase) -> Int {
        switch phase {
        case .focus: return focusMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    /// Every value pulled back inside its range, for settings saved by an older or edited build.
    public var clamped: TimerSettings {
        var s = self
        s.focusMinutes = Self.clamp(focusMinutes, Self.focusRange)
        s.shortBreakMinutes = Self.clamp(shortBreakMinutes, Self.shortBreakRange)
        s.longBreakMinutes = Self.clamp(longBreakMinutes, Self.longBreakRange)
        s.longBreakEvery = Self.clamp(longBreakEvery, Self.longBreakEveryRange)
        s.dailyGoal = Self.clamp(dailyGoal, Self.dailyGoalRange)
        return s
    }

    static func clamp(_ v: Int, _ r: ClosedRange<Int>) -> Int { min(max(v, r.lowerBound), r.upperBound) }
}

/// The macOS system sounds DESIGN.md 10 allows, plus silence for one event.
public enum SystemSound: String, CaseIterable, Codable, Sendable {
    case none = "None"
    case tink = "Tink", pop = "Pop", glass = "Glass", ping = "Ping", purr = "Purr"
    case submarine = "Submarine", funk = "Funk", bottle = "Bottle"

    public var next: SystemSound {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// When a sound plays.
public enum SoundEvent: String, CaseIterable, Codable, Sendable {
    case focusStarts, focusEnds, breakEnds, dailyGoal

    public var title: String {
        switch self {
        case .focusStarts: return "Focus starts"
        case .focusEnds: return "Focus ends"
        case .breakEnds: return "Break ends"
        case .dailyGoal: return "Daily goal"
        }
    }
}

/// Weather to work in: a soft loop under focus, made in the app from noise. Never a notification.
public enum Ambience: String, CaseIterable, Codable, Sendable {
    case off, rain, storm, wind, brown

    public var title: String {
        switch self {
        case .off: return "Off"
        case .rain: return "Soft rain"
        case .storm: return "Distant storm"
        case .wind: return "Wind"
        case .brown: return "Brown noise"
        }
    }

    public var next: Ambience {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

public struct SoundSettings: Codable, Equatable, Sendable {
    /// The one switch that silences everything.
    public var enabled = true
    /// 0…1
    public var volume = 0.7
    public var focusStarts = SystemSound.purr
    public var focusEnds = SystemSound.glass
    public var breakEnds = SystemSound.tink
    public var dailyGoal = SystemSound.pop
    public var ambience = Ambience.off
    /// 0…1, on top of `volume`.
    public var ambienceVolume = 0.3

    public init() {}

    public subscript(event: SoundEvent) -> SystemSound {
        get {
            switch event {
            case .focusStarts: return focusStarts
            case .focusEnds: return focusEnds
            case .breakEnds: return breakEnds
            case .dailyGoal: return dailyGoal
            }
        }
        set {
            switch event {
            case .focusStarts: focusStarts = newValue
            case .focusEnds: focusEnds = newValue
            case .breakEnds: breakEnds = newValue
            case .dailyGoal: dailyGoal = newValue
            }
        }
    }
}

/// Codable values kept as JSON in the user defaults.
public enum Saved {
    public static func load<T: Decodable>(_ type: T.Type, _ key: String, _ defaults: UserDefaults = .standard) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    public static func store<T: Encodable>(_ value: T, _ key: String, _ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
