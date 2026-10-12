import Foundation
import NimbiKit
import Testing
@testable import TempoCore

private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
private func at(_ minutes: Double) -> Date { t0.addingTimeInterval(minutes * 60) }

private func makeClock(autoBreaks: Bool = true, autoFocus: Bool = false, every: Int = 4) -> PomodoroClock {
    var s = TimerSettings()
    s.autoStartBreaks = autoBreaks
    s.autoStartFocus = autoFocus
    s.longBreakEvery = every
    return PomodoroClock(settings: s)
}

@Suite struct ClockTests {
    @Test func startsIdleOnFocus() {
        let c = makeClock()
        #expect(c.state == .idle(next: .focus))
        #expect(c.remaining(at: t0) == 25 * 60)
        #expect(c.progress(at: t0) == 0)
    }

    @Test func spaceStartsPausesAndResumes() {
        var c = makeClock()
        #expect(c.toggle(at: t0) == [.started(.focus)])
        #expect(c.remaining(at: at(5)) == 20 * 60)
        #expect(c.toggle(at: at(5)) == [])
        #expect(c.isPaused)
        // Paused time doesn't count.
        #expect(c.remaining(at: at(30)) == 20 * 60)
        _ = c.toggle(at: at(30))
        #expect(c.state == .running(phase: .focus, endsAt: at(50), duration: 25 * 60))
        #expect(abs(c.progress(at: at(40)) - 0.6) < 1e-9)
    }

    @Test func focusEndsIntoABreakOnItsOwn() {
        var c = makeClock()
        c.start(at: t0)
        #expect(c.tick(at: at(24.9)) == [])
        let events = c.tick(at: at(25.2))
        #expect(events == [.completed(.focus, start: t0, end: at(25)), .started(.shortBreak)])
        #expect(c.streak == 1)
        // The break starts when the clock noticed, not before.
        #expect(c.state == .running(phase: .shortBreak, endsAt: at(30.2), duration: 5 * 60))
    }

    @Test func breakEndsWaitingForYou() {
        var c = makeClock()
        c.start(at: t0)
        _ = c.tick(at: at(25))
        let events = c.tick(at: at(30))
        #expect(events == [.completed(.shortBreak, start: at(25), end: at(30)), .waiting(next: .focus)])
        #expect(c.state == .finished(phase: .shortBreak, at: at(30), next: .focus))
        #expect(c.progress(at: at(31)) == 1)
        #expect(c.start(at: at(31)) == [.started(.focus)])
    }

    @Test func withoutAutoBreaksFocusWaits() {
        var c = makeClock(autoBreaks: false)
        c.start(at: t0)
        #expect(c.tick(at: at(26)) == [.completed(.focus, start: t0, end: at(25)), .waiting(next: .shortBreak)])
        #expect(c.isWaiting)
        #expect(c.phase == .shortBreak)
    }

    @Test func everyFourthBreakIsLong() {
        var c = makeClock(autoBreaks: true, autoFocus: true)
        var now = t0
        c.start(at: now)
        var breaks: [Phase] = []
        for _ in 0..<8 {
            now = now.addingTimeInterval(c.remaining(at: now))
            for case .started(let p) in c.tick(at: now) where p.isBreak { breaks.append(p) }
        }
        #expect(breaks == [.shortBreak, .shortBreak, .shortBreak, .longBreak])
        // After the long break the count starts over.
        #expect(c.streak == 0)
        #expect(c.phase == .focus)
    }

    @Test func roundCountsWithinTheCycle() {
        var c = makeClock(autoFocus: true)
        #expect(c.round == 1)
        c.start(at: t0)
        _ = c.tick(at: at(25))          // focus 1 done, short break
        #expect(c.round == 1)
        _ = c.tick(at: at(30))          // focus 2
        #expect(c.round == 2)
    }

    @Test func skippedFocusDoesNotCount() {
        var c = makeClock()
        c.start(at: t0)
        #expect(c.skip(at: at(10)) == [.started(.shortBreak)])
        #expect(c.streak == 0)
        #expect(c.skip(at: at(11)) == [.started(.focus)])
    }

    @Test func skippingWhileIdleOrPausedWaits() {
        var c = makeClock()
        #expect(c.skip(at: t0) == [])
        #expect(c.state == .idle(next: .shortBreak))
        c.start(at: t0)
        c.pause(at: at(1))
        c.skip(at: at(2))
        #expect(c.state == .idle(next: .focus))
    }

    @Test func skippingALongBreakStartsTheCycleOver() {
        var c = makeClock(every: 2)
        c.start(at: t0)
        _ = c.tick(at: at(25))           // short break
        _ = c.skip(at: at(26))           // focus
        _ = c.tick(at: at(51))           // focus 2 done: long break
        #expect(c.phase == .longBreak)
        c.skip(at: at(52))
        #expect(c.streak == 0)
        #expect(c.phase == .focus)
    }

    @Test func resetStartsThePhaseOver() {
        var c = makeClock()
        c.start(at: t0)
        c.reset()
        #expect(c.state == .idle(next: .focus))
        c.start(at: t0)
        _ = c.tick(at: at(25))
        c.reset()
        #expect(c.state == .idle(next: .shortBreak))
        #expect(c.streak == 1)
        // At rest, reset starts the whole cycle over.
        c.reset()
        #expect(c.state == .idle(next: .focus))
        #expect(c.streak == 0)
    }

    @Test func aRunningPhaseKeepsItsLengthWhenSettingsChange() {
        var c = makeClock()
        c.start(at: t0)
        c.settings.focusMinutes = 50
        #expect(c.remaining(at: at(5)) == 20 * 60)
        c.reset()
        #expect(c.remaining(at: at(5)) == 50 * 60)
    }

    @Test func aSleepingMacCatchesUp() {
        var c = makeClock()
        c.start(at: t0)
        // Asleep for two hours: focus counts as finished at its end, the break starts on waking.
        let events = c.tick(at: at(145))
        #expect(events.first == .completed(.focus, start: t0, end: at(25)))
        #expect(c.state == .running(phase: .shortBreak, endsAt: at(150), duration: 5 * 60))
    }

    @Test func snapshotRoundTrips() throws {
        var c = makeClock()
        c.start(at: t0)
        let data = try JSONEncoder().encode(ClockSnapshot(c))
        let back = try JSONDecoder().decode(ClockSnapshot.self, from: data)
        #expect(back == ClockSnapshot(c))
    }

    @Test func settingsClamp() {
        var s = TimerSettings()
        s.focusMinutes = 500; s.shortBreakMinutes = 0; s.longBreakEvery = 1
        let c = s.clamped
        #expect(c.focusMinutes == 90)
        #expect(c.shortBreakMinutes == 1)
        #expect(c.longBreakEvery == 2)
    }
}

@Suite struct MoodTests {
    @Test func restIsRelaxedAndACloud() {
        let m = TempoMood.from(makeClock(), at: t0)
        #expect(m == TempoMood(mood: .relaxed))
    }

    @Test func focusIsABusyHourglass() {
        var c = makeClock()
        c.start(at: t0)
        let m = TempoMood.from(c, at: at(5))
        #expect(m.mood == .busy)
        #expect(m.form == .hourglass)
        #expect(m.working == 1)
        #expect(abs(m.progress - 0.2) < 1e-9)
    }

    @Test func breaksAreAMugAndAMoon() {
        var c = makeClock(every: 2)
        c.start(at: t0)
        _ = c.tick(at: at(25))
        #expect(TempoMood.from(c, at: at(26)).form == .mug)
        #expect(TempoMood.from(c, at: at(26)).mood == .relaxed)
        _ = c.skip(at: at(26))
        _ = c.tick(at: at(51))
        let long = TempoMood.from(c, at: at(52))
        #expect(long.form == .moon)
        #expect(long.mood == .asleep)
    }

    @Test func timesUpRingsThenWaitsQuietly() {
        var c = makeClock(autoBreaks: false)
        c.start(at: t0)
        _ = c.tick(at: at(25))
        let ask = TempoMood.from(c, at: at(25.2))
        #expect(ask.mood == .asking)
        #expect(ask.urgency == .needsYou)
        #expect(ask.form == .bell)
        #expect(TempoMood.from(c, at: at(26)).mood == .impatient)
        let later = TempoMood.from(c, at: at(31))
        #expect(later.mood == .impatient)
        #expect(later.urgency == .notice)
    }

    @Test func aFinishedSessionCheersForAMoment() {
        var c = makeClock()
        c.start(at: t0)
        _ = c.tick(at: at(25))
        let m = TempoMood.from(c, at: at(25), cheerUntil: at(25.05))
        #expect(m.mood == .happy)
        #expect(m.form == .mug)
        #expect(TempoMood.from(c, at: at(25.1), cheerUntil: at(25.05)).mood == .relaxed)
    }

    @Test func pausedLongIsLonely() {
        var c = makeClock()
        c.start(at: t0)
        c.pause(at: at(1))
        #expect(TempoMood.from(c, at: at(5)).mood == .relaxed)
        #expect(TempoMood.from(c, at: at(12)).mood == .lonely)
        #expect(TempoMood.from(c, at: at(12)).form == .cloud)
    }

    @Test func busierWithEverySessionInARow() {
        var c = makeClock(autoFocus: true)
        c.start(at: t0)
        _ = c.tick(at: at(25))
        _ = c.tick(at: at(30))
        #expect(TempoMood.from(c, at: at(31)).working == 2)
    }
}

@Suite struct TextAndLogTests {
    @Test func clockDigits() {
        #expect(TimeText.clock(25 * 60) == "25:00")
        #expect(TimeText.clock(1121.2) == "18:42")
        #expect(TimeText.clock(0) == "00:00")
    }

    @Test func menuBarMinutesThenSeconds() {
        #expect(TimeText.menuBar(18 * 60) == "18′")
        #expect(TimeText.menuBar(17 * 60 + 1) == "18′")
        #expect(TimeText.menuBar(60) == "1′")
        #expect(TimeText.menuBar(42) == "0:42")
        #expect(TimeText.menuBar(0) == "0:00")
    }

    @Test func durations() {
        #expect(TimeText.duration(minutes: 25) == "25 min")
        #expect(TimeText.duration(minutes: 125) == "2 h 5 min")
        #expect(TimeText.duration(minutes: 60) == "1 h")
        #expect(TimeText.spoken(61) == "2 minutes left")
        #expect(TimeText.spoken(1) == "1 second left")
    }

    @Test func todaysSessions() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var log = SessionLog()
        log.add(FocusSession(start: at(-24 * 60), end: at(-24 * 60 + 25)))
        log.add(FocusSession(start: t0, end: at(25), task: "Release notes"))
        log.add(FocusSession(start: at(30), end: at(55)))
        #expect(log.count(on: at(60), calendar: cal) == 2)
        #expect(log.minutes(on: at(60), calendar: cal) == 50)
        log.prune(now: at(61 * 24 * 60), calendar: cal)
        #expect(log.sessions.isEmpty)
    }

    @Test func storeRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("s.json")
        let store = SessionStore(url: url)
        var log = SessionLog()
        log.add(FocusSession(start: t0, end: at(25), task: "Inbox"))
        store.save(log)
        #expect(store.load() == log)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
