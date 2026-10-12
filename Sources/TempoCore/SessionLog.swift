import Foundation

/// One finished focus session.
public struct FocusSession: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    /// What you said you were working on (T), if anything.
    public var task: String?

    public init(start: Date, end: Date, task: String? = nil) {
        self.start = start
        self.end = end
        self.task = task
    }

    public var minutes: Int { Int((end.timeIntervalSince(start) / 60).rounded()) }
}

/// Finished focus sessions, newest last. Kept for 60 days; only counts and minutes are shown.
public struct SessionLog: Codable, Equatable, Sendable {
    public private(set) var sessions: [FocusSession] = []

    public init(sessions: [FocusSession] = []) { self.sessions = sessions }

    public static let keepDays = 60

    public mutating func add(_ session: FocusSession) {
        sessions.append(session)
    }

    public mutating func prune(now: Date, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.keepDays, to: now) else { return }
        sessions.removeAll { $0.end < cutoff }
    }

    /// Sessions that ended on `now`'s day.
    public func day(of now: Date, calendar: Calendar = .current) -> [FocusSession] {
        sessions.filter { calendar.isDate($0.end, inSameDayAs: now) }
    }

    public func count(on now: Date, calendar: Calendar = .current) -> Int { day(of: now, calendar: calendar).count }

    public func minutes(on now: Date, calendar: Calendar = .current) -> Int {
        day(of: now, calendar: calendar).reduce(0) { $0 + $1.minutes }
    }
}

/// Reads and writes the log as JSON in Application Support.
public struct SessionStore {
    public let url: URL

    public init(url: URL) { self.url = url }

    public static var standard: SessionStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return SessionStore(url: base.appendingPathComponent("Tempo", isDirectory: true).appendingPathComponent("sessions.json"))
    }

    public func load() -> SessionLog {
        guard let data = try? Data(contentsOf: url) else { return SessionLog() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(SessionLog.self, from: data)) ?? SessionLog()
    }

    public func save(_ log: SessionLog) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(log) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
