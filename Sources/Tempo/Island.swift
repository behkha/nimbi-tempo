import AppKit
import NimbiKit
import SwiftUI
import TempoCore

/// Tempo at the notch (DESIGN.md 18.2, phase 1): NimbiKit's island, drawn only while the user has
/// picked Tempo as the notch's owner. Closed, the cloud in its current tool and the minutes
/// (option A); open, the page with a ring on the right (option A).
@MainActor
final class TempoIsland {
    let island: NotchIsland
    private let model: TempoModel

    /// Timer ↩: Tempo's panel, hanging from the island.
    var onOpenPanel: (() -> Void)?

    init(model: TempoModel, ownership: NotchOwnership) {
        self.model = model
        var act: (IslandPage.Action) -> Void = { _ in }
        island = NotchIsland(ownership: ownership,
                             closed: { state in ClosedIsland(state: state, model: model) },
                             open: { _ in OpenIsland(model: model, act: { act($0) }) })
        act = { [weak self] action in self?.perform(action) }
        island.onKey = { [weak self] code in self?.key(code) ?? false }
    }

    private func perform(_ action: IslandPage.Action) {
        switch action {
        case .toggle: model.toggle()
        case .skip: model.skip()
        case .openTimer: onOpenPanel?()
        }
    }

    /// space, S and ↩ (the primary action when time is up, the panel otherwise).
    private func key(_ code: UInt16) -> Bool {
        switch code {
        case 49: model.toggle(); return true
        case 1: model.skip(); return true
        case 36, 76:
            if model.clock.isWaiting { model.toggle() } else { onOpenPanel?() }
            return true
        default: return false
        }
    }
}

extension TempoModel {
    var islandPage: IslandPage {
        IslandPage(clock: clock, at: now, urgency: mood.urgency, task: task, today: todayCount,
                   time: { Self.endTime.string(from: $0) })
    }

    static let endTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: .current)
        return f
    }()
}

extension IslandPage.RingColor {
    var color: Color {
        switch self {
        case .focus: return Nimbi.State.working
        case .rest: return Nimbi.State.done
        case .waiting: return Nimbi.State.waiting
        }
    }
}

/// The closed island: the cloud in its tool on the left, the glance on the right, and an amber
/// dot while time is up and waits for you.
private struct ClosedIsland: View {
    @ObservedObject var state: IslandState
    @ObservedObject var model: TempoModel

    var body: some View {
        let mood = model.mood
        let page = model.islandPage
        IslandWings(state: state) {
            NimbiCloud(size: 24, mood: mood.mood, working: mood.working, followsCursor: false, lively: false,
                       form: mood.form, progress: mood.progress)
                .frame(width: 24, height: 24)
        } right: {
            HStack(spacing: 4) {
                Text(page.glance)
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(model.clock.isPaused ? Nimbi.Text.dim : Nimbi.Text.primary)
                    .lineLimit(1)
                if page.urgency == .needsYou {
                    Circle().fill(Nimbi.State.waiting).frame(width: 5, height: 5)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tempo, \(page.title)\(page.urgency == .needsYou ? ", needs you" : "")")
    }
}

/// The open island's page: cloud at 92, TEMPO, title, subtitle, two actions, and the ring.
private struct OpenIsland: View {
    @ObservedObject var model: TempoModel
    var act: (IslandPage.Action) -> Void
    @ObservedObject private var look = NimbiAppearance.shared

    var body: some View {
        let mood = model.mood
        let page = model.islandPage
        let urgent = page.urgency == .needsYou
        HStack(alignment: .center, spacing: 18) {
            NimbiCloud(size: 92, mood: mood.mood, working: mood.working, form: mood.form, progress: mood.progress)
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("TEMPO")
                    .font(.system(size: 11 * look.textScale, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Nimbi.Text.faint)
                Text(page.title)
                    .font(look.font(26, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Nimbi.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(page.subtitle)
                    .font(look.font(13))
                    .foregroundStyle(Nimbi.Text.dim)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    // Primary (white) only when time is up and waits for you (DESIGN.md 18.4).
                    Button { act(page.primary.action) } label: {
                        label(page.primary.title, key: urgent ? "↩" : page.primary.action.key, light: urgent)
                    }
                    .buttonStyle(PillButtonStyle(light: urgent, hint: true))
                    .focusable(false)
                    Button { act(page.secondary.action) } label: {
                        label(page.secondary.title, key: page.secondary.action.key, light: false)
                    }
                    .buttonStyle(PillButtonStyle(hint: true))
                    .focusable(false)
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                ZStack {
                    Ring(left: page.left, color: page.ring.color)
                        .frame(width: 92, height: 92)
                    Text(page.glance)
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Nimbi.Text.primary)
                }
                Text(page.caption)
                    .font(look.font(10.5))
                    .foregroundStyle(Nimbi.Text.faint)
            }
            .frame(width: 132)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(TimeText.spoken(model.remaining)), session \(page.caption)")
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
    }

    private func label(_ text: String, key: String, light: Bool) -> some View {
        HStack(spacing: 6) {
            Text(text)
            KeyHint(key: key, onLight: light)
        }
    }
}
