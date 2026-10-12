import AppKit
import NimbiKit
import ServiceManagement
import SwiftUI
import TempoCore

/// `,`: the settings menu (DESIGN.md 8): header, grouped rows in wells, then plain rows.
struct SettingsView: View {
    @ObservedObject var model: TempoModel
    @ObservedObject var notch: NotchOwnership
    var actions: PanelActions
    @ObservedObject private var look = NimbiAppearance.shared
    @ViewState private var loginError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeader(title: "Tempo", subtitle: "Version \(Bundle.main.shortVersion)", back: actions.back)

            Group_ {
                StepperRow(icon: "hourglass", title: "Focus", value: $model.settings.focusMinutes,
                           range: TimerSettings.focusRange, step: 5, unit: "min")
                Divider_()
                StepperRow(icon: "cup.and.saucer", title: "Short break", value: $model.settings.shortBreakMinutes,
                           range: TimerSettings.shortBreakRange, step: 1, unit: "min")
                Divider_()
                StepperRow(icon: "moon", title: "Long break", value: $model.settings.longBreakMinutes,
                           range: TimerSettings.longBreakRange, step: 5, unit: "min")
                Divider_()
                StepperRow(icon: "repeat", title: "Long break after", value: $model.settings.longBreakEvery,
                           range: TimerSettings.longBreakEveryRange, step: 1, unit: "sessions")
                Divider_()
                StepperRow(icon: "flag", title: "Daily goal", value: $model.settings.dailyGoal,
                           range: TimerSettings.dailyGoalRange, step: 1, unit: "sessions")
            }

            Group_ {
                ToggleRow(icon: "play.circle", title: "Start breaks on their own", on: $model.settings.autoStartBreaks)
                Divider_()
                ToggleRow(icon: "arrow.uturn.backward.circle", title: "Start focus after a break", on: $model.settings.autoStartFocus)
            }

            Group_ {
                SettingsRow(icon: "speaker.wave.2", title: "Sounds",
                            value: model.sounds.enabled ? (model.sounds.ambience == .off ? "On" : "On · \(model.sounds.ambience.title)") : "Off",
                            chevron: true) { actions.open(.sounds) }
                Divider_()
                SettingsRow(icon: "circle.lefthalf.filled", title: "Theme", value: look.theme.rawValue) {
                    LookSettings.setTheme(look.theme == .dark ? .black : .dark)
                }
                Divider_()
                SettingsRow(icon: "textformat.size", title: "Text size", value: "\(Int((look.textScale * 100).rounded()))%") {
                    let scales = LookSettings.textScales
                    let i = scales.firstIndex(of: look.textScale) ?? 1
                    LookSettings.setTextScale(scales[(i + 1) % scales.count])
                }
                Divider_()
                SettingsRow(icon: "power", title: "Open at login", value: loginValue) { toggleLogin() }
                Divider_()
                SettingsRow(icon: "keyboard", title: "Start or pause anywhere", value: Hotkey.label) {}
                    .allowsHitTesting(false)
            }

            // DESIGN.md 18.2: Tempo never takes the notch on its own; one click here does.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.topthird.inset.filled")
                        .foregroundStyle(Nimbi.Text.dim)
                        .frame(width: 18)
                    Text(notch.line)
                        .foregroundStyle(Nimbi.Text.strong)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(look.font(12))
                HStack(spacing: 8) {
                    Text(notch.ownedByMe ? "Hover it to see the timer." : "Tempo stays in the menu bar.")
                        .font(look.font(10.5))
                        .foregroundStyle(Nimbi.Text.dim)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if notch.ownedByMe {
                        Button(notch.giveBackTitle) { notch.giveBack() }
                            .buttonStyle(PillButtonStyle())
                            .focusable(false)
                    } else if NSScreen.islandScreen != nil {
                        Button("Use for Tempo") { notch.take() }
                            .buttonStyle(PillButtonStyle())
                            .focusable(false)
                    }
                }
                .padding(.leading, 26)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Nimbi.Radius.group, style: .continuous).fill(Nimbi.Surface.well))

            VStack(spacing: 0) {
                PlainRow(title: "About Tempo", action: actions.about)
                PlainRow(title: "Quit Tempo", key: "⌘Q") { NSApp.terminate(nil) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .frame(width: 300 * look.textScale)
        .onAppear { notch.reread() }
    }

    private var loginValue: String {
        if loginError { return "Can't from here" }
        switch SMAppService.mainApp.status {
        case .enabled: return "On"
        case .requiresApproval: return "Needs approval"
        default: return "Off"
        }
    }

    private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            loginError = false
        } catch {
            loginError = true
        }
        model.objectWillChange.send()
    }
}

/// Sounds, one picker per event (click to try the next one; it plays), the volume, and weather
/// to work in.
struct SoundsView: View {
    @ObservedObject var model: TempoModel
    var actions: PanelActions
    @ObservedObject private var look = NimbiAppearance.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PageHeader(title: "Sounds", subtitle: "Click a sound to hear the next one", back: actions.back)

            Group_ {
                ToggleRow(icon: "speaker.wave.2", title: "Sounds", on: $model.sounds.enabled)
                Divider_()
                StepperRow(icon: "speaker.wave.1", title: "Volume", value: percent(\.volume), range: 0...100, step: 10, unit: "%")
            }

            Group_ {
                ForEach(SoundEvent.allCases, id: \.self) { event in
                    if event != SoundEvent.allCases.first { Divider_() }
                    SettingsRow(icon: icon(event), title: event.title, value: model.sounds[event].rawValue) {
                        model.sounds[event] = model.sounds[event].next
                        model.preview(model.sounds[event])
                    }
                }
            }
            .opacity(model.sounds.enabled ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 6) {
                Text("WHILE YOU FOCUS")
                    .font(look.font(10.5, .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Nimbi.Text.faint)
                    .padding(.leading, 4)
                Group_ {
                    SettingsRow(icon: "cloud.rain", title: "Weather", value: model.sounds.ambience.title) {
                        model.sounds.ambience = model.sounds.ambience.next
                        model.previewAmbience()
                    }
                    Divider_()
                    StepperRow(icon: "dial.low", title: "Its volume", value: percent(\.ambienceVolume), range: 0...100, step: 10, unit: "%")
                }
                Text("Made in the app as it plays. It fades in when focus starts and out at the break.")
                    .font(look.font(10.5))
                    .foregroundStyle(Nimbi.Text.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .opacity(model.sounds.enabled ? 1 : 0.4)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .frame(width: 300 * look.textScale)
    }

    private func percent(_ key: WritableKeyPath<SoundSettings, Double>) -> Binding<Int> {
        Binding(get: { Int((model.sounds[keyPath: key] * 100).rounded()) },
                set: { model.sounds[keyPath: key] = Double($0) / 100 })
    }

    private func icon(_ event: SoundEvent) -> String {
        switch event {
        case .focusStarts: return "play"
        case .focusEnds: return "bell"
        case .breakEnds: return "cup.and.saucer"
        case .dailyGoal: return "flag"
        }
    }
}

// MARK: - Rows

private struct PageHeader: View {
    var title: String
    var subtitle: String
    var back: () -> Void
    @ObservedObject private var look = NimbiAppearance.shared

    var body: some View {
        HStack(spacing: 10) {
            NimbiCloud(size: 22, mood: .relaxed, followsCursor: false, lively: false)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(look.font(13.5, .semibold)).foregroundStyle(Nimbi.Text.primary)
                Text(subtitle).font(look.font(10.5)).foregroundStyle(Nimbi.Text.dim)
            }
            Spacer()
            Button(action: back) { KeyHint(key: "esc") }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Back · esc")
                .accessibilityLabel("Back")
        }
    }
}

/// A `well` group, radius 11.
private struct Group_<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: Nimbi.Radius.group, style: .continuous).fill(Nimbi.Surface.well))
    }
}

private struct Divider_: View {
    var body: some View {
        Rectangle().fill(Nimbi.Line.row).frame(height: 0.5).padding(.leading, 36)
    }
}

private struct RowLabel: View {
    var icon: String
    var title: String
    @ObservedObject private var look = NimbiAppearance.shared

    var body: some View {
        Image(systemName: icon)
            .font(look.font(12, .medium))
            .foregroundStyle(Nimbi.Text.dim)
            .frame(width: 18)
        Text(title)
            .font(look.font(12.5))
            .foregroundStyle(Nimbi.Text.message)
            .lineLimit(1)
    }
}

private struct SettingsRow: View {
    var icon: String
    var title: String
    var value: String
    var chevron = false
    var action: () -> Void
    @ObservedObject private var look = NimbiAppearance.shared
    @ViewState private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RowLabel(icon: icon, title: title)
                Spacer(minLength: 6)
                Text(value)
                    .font(look.font(12))
                    .foregroundStyle(Nimbi.Text.dim)
                    .lineLimit(1)
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(look.font(10, .semibold))
                        .foregroundStyle(Nimbi.Text.faint)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 30 * look.textScale)
            .background(RoundedRectangle(cornerRadius: Nimbi.Radius.menuRow, style: .continuous)
                .fill(hover ? Color.white.opacity(0.06) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hover = $0 }
        .accessibilityLabel("\(title), \(value)")
    }
}

/// A number with − and + beside it.
private struct StepperRow: View {
    var icon: String
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int
    var unit: String
    @ObservedObject private var look = NimbiAppearance.shared

    var body: some View {
        HStack(spacing: 6) {
            RowLabel(icon: icon, title: title)
            Spacer(minLength: 4)
            nudge("minus", by: -step, label: "Less")
            Text(unit == "%" ? "\(value)%" : "\(value) \(value == 1 && unit == "sessions" ? "session" : unit)")
                .font(look.font(12))
                .monospacedDigit()
                .foregroundStyle(Nimbi.Text.strong)
                .frame(minWidth: 50 * look.textScale)
            nudge("plus", by: step, label: "More")
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30 * look.textScale)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func nudge(_ symbol: String, by delta: Int, label: String) -> some View {
        // Off-step values (a 7-minute break) snap to the step first.
        var next = step > 1 && value % step != 0 ? (delta > 0 ? (value / step + 1) * step : (value / step) * step) : value + delta
        next = min(max(next, range.lowerBound), range.upperBound)
        return Button {
            value = next
        } label: {
            Image(systemName: symbol)
                .font(look.font(10, .bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(value == (delta < 0 ? range.lowerBound : range.upperBound))
        .opacity(value == (delta < 0 ? range.lowerBound : range.upperBound) ? 0.35 : 1)
        .foregroundStyle(Nimbi.Text.strong)
        .accessibilityLabel("\(label) \(title.lowercased())")
    }
}

private struct ToggleRow: View {
    var icon: String
    var title: String
    @Binding var on: Bool
    @ObservedObject private var look = NimbiAppearance.shared

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                RowLabel(icon: icon, title: title)
                Spacer(minLength: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture { on.toggle() }
            Toggle("", isOn: $on)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .tint(Nimbi.State.done)
                .focusable(false)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30 * look.textScale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(on ? "on" : "off")")
    }
}

private struct PlainRow: View {
    var title: String
    var key: String?
    var action: () -> Void
    @ObservedObject private var look = NimbiAppearance.shared
    @ViewState private var hover = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(look.font(12.5))
                    .foregroundStyle(Nimbi.Text.message)
                Spacer()
                if let key { KeyHint(key: key) }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 28 * look.textScale)
            .background(RoundedRectangle(cornerRadius: Nimbi.Radius.menuRow, style: .continuous)
                .fill(hover ? Color.white.opacity(0.06) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hover = $0 }
    }
}
