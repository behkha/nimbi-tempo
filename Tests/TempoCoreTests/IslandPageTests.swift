import Foundation
import Testing
@testable import TempoCore

private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }
private let hhmm: (Date) -> String = { d in
    let f = DateFormatter()
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "HH:mm"
    return f.string(from: d)
}

private func page(_ clock: PomodoroClock, _ now: Date, task: String = "", today: Int = 0) -> IslandPage {
    IslandPage(clock: clock, at: now, urgency: TempoMood.from(clock, at: now).urgency, task: task, today: today, time: hhmm)
}

@Suite struct IslandPageTests {
    @Test func readyAtRest() {
        let p = page(PomodoroClock(), t0)
        #expect(p.glance == "Ready")
        #expect(p.title == "Ready when you are")
        #expect(p.subtitle == "Nothing finished yet today.")
        #expect(p.primary == ("Start focus", .toggle))
        #expect(p.secondary == ("Timer", .openTimer))
        #expect(p.urgency == .none)
    }

    @Test func focusShowsMinutesTaskAndEnd() {
        var c = PomodoroClock()
        c.start(at: t0)
        let p = page(c, at(6.5), task: "Release notes")
        #expect(p.glance == "19′")
        #expect(p.title == "Focus · 19 min left")
        #expect(p.subtitle == "Release notes · until \(hhmm(at(25)))")
        #expect(p.primary == ("Pause", .toggle))
        #expect(p.ring == .focus)
        #expect(abs(p.left - 0.74) < 1e-9)
        #expect(p.caption == "1 of 4")
    }

    @Test func lastMinuteInSeconds() {
        var c = PomodoroClock()
        c.start(at: t0)
        let p = page(c, at(24.3))
        #expect(p.glance == "0:42")
        #expect(p.title == "Focus · 42 s left")
    }

    @Test func timesUpAsksWithAWhiteStart() {
        var s = TimerSettings(); s.autoStartBreaks = false
        var c = PomodoroClock(settings: s)
        c.start(at: t0)
        _ = c.tick(at: at(25))
        let p = page(c, at(25.1), today: 3)
        #expect(p.glance == "0:00")
        #expect(p.title == "Time's up")
        #expect(p.subtitle == "A break is next · 3 sessions today")
        #expect(p.primary == ("Start break", .toggle))
        #expect(p.secondary == ("Skip", .skip))
        #expect(p.ring == .waiting)
        #expect(p.urgency == .needsYou)
    }

    @Test func breaksSayWhenBackToIt() {
        var c = PomodoroClock()
        c.start(at: t0)
        _ = c.tick(at: at(25))
        let p = page(c, at(26))
        #expect(p.title == "Short break · 4 min left")
        #expect(p.subtitle == "Back to it at \(hhmm(at(30)))")
        #expect(p.ring == .rest)
    }

    @Test func pausedAndClipped() {
        var c = PomodoroClock()
        c.start(at: t0)
        c.pause(at: at(13))
        let p = page(c, at(14), task: String(repeating: "a very long task name ", count: 5))
        #expect(p.title == "Focus paused · 12 min")
        #expect(p.primary == ("Resume", .toggle))
        #expect(p.subtitle.count == 60)
        #expect(p.subtitle.hasSuffix("…"))
    }
}
