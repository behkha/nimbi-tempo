import AppKit
import NimbiKit
import SwiftUI
import TempoCore

/// The panel (option A, "the cloud in a ring"): the cloud in the middle of a ring that drains as
/// the phase runs, the minutes under it, the task, the session dots, the controls and today.
struct TimerView: View {
    @ObservedObject var model: TempoModel
    @ObservedObject var panel: PanelState
    var actions: PanelActions
    @ObservedObject private var look = NimbiAppearance.shared
    @FocusState private var taskFocused: Bool

    var body: some View {
        let clock = model.clock
        let mood = model.mood
        VStack(spacing: 10) {
            header(clock)
            ZStack {
                Ring(left: ringLeft(clock), color: ringColor(clock))
                    .frame(width: 196 * look.textScale, height: 196 * look.textScale)
                NimbiCloud(size: 96 * look.textScale, mood: mood.mood, working: mood.working,
                           form: mood.form, progress: mood.progress)
                    .frame(width: 96 * look.textScale, height: 96 * look.textScale)
                    .accessibilityHidden(true)
            }
            .frame(width: 200 * look.textScale, height: 200 * look.textScale)
            .padding(.top, 2)

            VStack(spacing: 4) {
                Text(TimeText.clock(model.remaining))
                    .font(look.font(40, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(clock.isPaused ? Nimbi.Text.dim : Nimbi.Text.primary)
                    .accessibilityLabel(TimeText.spoken(model.remaining))
                Text(status(clock))
                    .font(look.font(11.5))
                    .foregroundStyle(clock.isWaiting ? Nimbi.State.waiting : Nimbi.Text.dim)
            }

            taskLine
            dots(clock)
            controls(clock)

            if let undo = model.undo {
                UndoBar(label: "Timer reset", systemImage: "arrow.counterclockwise.circle.fill",
                        tint: Nimbi.State.working, started: undo.started,
                        duration: Nimbi.Motion.undoWindowDestructive, onUndo: actions.undo)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Text(today)
                .font(look.font(10.5))
                .foregroundStyle(Nimbi.Text.faint)
        }
        .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 12)
        .frame(width: 300 * look.textScale)
        .animation(Nimbi.Motion.enter, value: model.undo?.started)
    }

    // MARK: Pieces

    private func header(_ clock: PomodoroClock) -> some View {
        HStack(spacing: 6) {
            (Text(clock.isWaiting ? "Time's up" : clock.phase.title).foregroundColor(Nimbi.Text.primary)
             + Text(clock.phase == .focus && !clock.isWaiting ? " · \(clock.round) of \(clock.settings.longBreakEvery)" : "")
                .foregroundColor(Nimbi.Text.dim))
                .font(look.font(12, .semibold))
            Spacer()
            Button { actions.open(.settings) } label: { KeyHint(key: ",") }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Settings · ,")
                .accessibilityLabel("Settings")
        }
    }

    @ViewBuilder private var taskLine: some View {
        if panel.editingTask {
            TextField("What are you working on?", text: $model.task)
                .textFieldStyle(.plain)
                .font(look.font(12.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(Nimbi.Text.message)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.07)))
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .focused($taskFocused)
                .onAppear { DispatchQueue.main.async { taskFocused = true } }
                .onSubmit(actions.endEditing)
        } else {
            Button(action: actions.editTask) {
                HStack(spacing: 6) {
                    Text(model.task.isEmpty ? "What are you working on?" : model.task)
                        .font(look.font(12.5))
                        .foregroundStyle(model.task.isEmpty ? Nimbi.Text.faint : Nimbi.Text.dim)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    KeyHint(key: "T")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Name the task · T")
        }
    }

    /// One dot per session in the cycle: done ones filled, the one you're in as a ring.
    private func dots(_ clock: PomodoroClock) -> some View {
        let every = clock.settings.longBreakEvery
        let done: Int
        let current: Int?
        switch clock.phase {
        case .focus:
            done = clock.streak % every
            current = clock.isRunning || clock.isPaused ? done : nil
        case .shortBreak, .longBreak:
            done = (clock.streak - 1) % every + 1
            current = nil
        }
        return HStack(spacing: 6) {
            ForEach(0..<every, id: \.self) { i in
                ZStack {
                    if i < done {
                        Circle().fill(Nimbi.State.working)
                    } else if i == current {
                        Circle().stroke(Nimbi.State.working, lineWidth: 1.5)
                    } else {
                        Circle().fill(Color.white.opacity(0.18))
                    }
                }
                .frame(width: 8, height: 8)
            }
        }
        .animation(Nimbi.Motion.enter, value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(every) sessions before the long break")
    }

    private func controls(_ clock: PomodoroClock) -> some View {
        HStack(spacing: 6) {
            Button(action: actions.toggle) {
                HStack(spacing: 6) {
                    Text(primaryTitle(clock))
                    KeyHint(key: "space", onLight: true)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            Button(action: actions.skip) {
                HStack(spacing: 5) { Text("Skip"); KeyHint(key: "S") }
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("Skip to \(skipTarget(clock)) · S")
            Button(action: actions.reset) {
                HStack(spacing: 5) { Text("Reset"); KeyHint(key: "R") }
            }
            .buttonStyle(SecondaryButtonStyle())
            .help("Start this \(clock.phase.isBreak ? "break" : "session") over · R")
        }
        .focusable(false)
    }

    // MARK: Words

    private func primaryTitle(_ clock: PomodoroClock) -> String {
        switch clock.state {
        case .running: return "Pause"
        case .paused: return "Resume"
        case .idle(let next), .finished(_, _, let next):
            switch next {
            case .focus: return "Start focus"
            case .shortBreak, .longBreak: return "Start break"
            }
        }
    }

    private func skipTarget(_ clock: PomodoroClock) -> String {
        clock.phase == .focus ? "the break" : "focus"
    }

    private func status(_ clock: PomodoroClock) -> String {
        switch clock.state {
        case .idle(let next):
            return next == .focus ? "Ready when you are." : "\(next.title) next."
        case .running(.focus, let endsAt, _):
            return "Until \(Self.time.string(from: endsAt))"
        case .running(_, let endsAt, _):
            return "Back to it at \(Self.time.string(from: endsAt))"
        case .paused:
            return "Paused. The cloud is waiting."
        case .finished(.focus, _, let next):
            return "Time's up. \(next == .longBreak ? "A long break" : "A break") is next."
        case .finished:
            return "Break's over. Back to it?"
        }
    }

    private var today: String {
        let n = model.todayCount
        guard n > 0 else { return "Nothing finished yet today." }
        let sessions = n == 1 ? "1 session" : "\(n) sessions"
        let goal = model.settings.dailyGoal
        let tail = n >= goal ? "Goal reached." : "\(n) of \(goal)"
        return "Today · \(sessions) · \(TimeText.duration(minutes: model.todayMinutes)) · \(tail)"
    }

    private func ringLeft(_ clock: PomodoroClock) -> Double {
        switch clock.state {
        case .idle: return 1
        case .finished: return 1
        default: return 1 - model.progress
        }
    }

    /// Color means state (DESIGN.md 4.5): blue while focus works, green on a break, amber when
    /// the next phase waits for you.
    private func ringColor(_ clock: PomodoroClock) -> Color {
        if clock.isWaiting { return Nimbi.State.waiting }
        if clock.phase.isBreak { return Nimbi.State.done }
        return Nimbi.State.working
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: .current)
        return f
    }()
}

/// The ring round the cloud: a faint track, and the time left as an arc from the top.
struct Ring: View {
    var left: Double
    var color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, left)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: left)
                .animation(.easeOut(duration: 0.3), value: color)
        }
        .padding(3)
        .accessibilityHidden(true)
    }
}
