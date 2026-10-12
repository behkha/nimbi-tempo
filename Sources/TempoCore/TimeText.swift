import Foundation

/// Time in words and digits, the way Tempo shows it.
public enum TimeText {
    /// "18:42": minutes and seconds left, rounded up so the timer never shows 00:00 early.
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds).rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// The menu bar: whole minutes ("18′") so it doesn't twitch every second, then seconds in
    /// the last minute ("0:42").
    public static func menuBar(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds).rounded(.up))
        if s >= 60 { return "\(Int((Double(s) / 60).rounded(.up)))′" }
        return String(format: "0:%02d", min(s, 59))
    }

    /// "25 min", "2 h 5 min", "1 h".
    public static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    /// For VoiceOver and tooltips: "18 minutes left", "42 seconds left".
    public static func spoken(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds).rounded(.up))
        if s >= 60 {
            let m = Int((Double(s) / 60).rounded(.up))
            return m == 1 ? "1 minute left" : "\(m) minutes left"
        }
        return s == 1 ? "1 second left" : "\(s) seconds left"
    }
}
