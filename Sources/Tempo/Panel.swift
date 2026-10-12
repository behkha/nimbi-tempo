import AppKit
import Combine
import NimbiKit
import SwiftUI
import TempoCore

@MainActor
final class PanelState: ObservableObject {
    enum Page { case timer, settings, sounds }
    @Published var page = Page.timer
    /// T: the task line is a text field while this is on.
    @Published var editingTask = false
}

/// What the panel's pages can ask for.
struct PanelActions {
    var toggle: () -> Void
    var skip: () -> Void
    var reset: () -> Void
    var undo: () -> Void
    var editTask: () -> Void
    var endEditing: () -> Void
    var open: (PanelState.Page) -> Void
    var back: () -> Void
    var about: () -> Void
}

/// Borderless panel that takes keys without making Tempo the active app.
final class PanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true   // the cloud's eyes follow the cursor
    }
}

/// The panel under the menu bar glyph: opens on click, closes on esc, a second click or a click
/// anywhere else. Keys are bound to physical key codes (DESIGN.md 2.6).
@MainActor
final class Panel: NSObject, NSWindowDelegate {
    private let window = PanelWindow()
    private let state = PanelState()
    private let model: TempoModel
    private let item: MenuBarItem
    private var host: SizeReportingHostingView<AnyView>!
    private var keyMonitor: Any?
    private var closedAt = Date.distantPast
    var onAbout: (() -> Void)?

    init(model: TempoModel, item: MenuBarItem) {
        self.model = model
        self.item = item
        super.init()
        window.delegate = self
        let actions = PanelActions(
            toggle: { [weak self] in self?.model.toggle() },
            skip: { [weak self] in self?.model.skip() },
            reset: { [weak self] in self?.model.reset() },
            undo: { [weak self] in self?.model.undoReset() },
            editTask: { [weak self] in self?.state.editingTask = true },
            endEditing: { [weak self] in self?.endEditing() },
            open: { [weak self] page in self?.show(page) },
            back: { [weak self] in self?.back() },
            about: { [weak self] in self?.close(); self?.onAbout?() }
        )
        host = SizeReportingHostingView(rootView: AnyView(PanelRoot(state: state, model: model, actions: actions)))
        host.onFittingSizeChange = { [weak self] in self?.place() }
        window.contentView = host
    }

    var isOpen: Bool { window.isVisible }

    func toggle() {
        if isOpen { close(); return }
        // The click that closed the panel (by taking key away) shouldn't open it again.
        guard Date().timeIntervalSince(closedAt) > 0.25 else { return }
        open(.timer)
    }

    func open(_ page: PanelState.Page) {
        state.page = page
        place()
        window.makeKeyAndOrderFront(nil)
        item.highlight(true)
        startKeys()
    }

    /// Demo only (`TEMPO_DEMO_SHOW=1`): shows the panel near the top of the screen without
    /// taking the keyboard, for screenshots of the real window.
    func showForCapture(_ page: PanelState.Page = .timer) {
        state.page = page
        guard let screen = NSScreen.main else { return }
        let size = host.fittingSize
        window.setFrame(NSRect(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height,
                               width: size.width, height: size.height), display: true)
        window.orderFrontRegardless()
    }

    func close() {
        guard isOpen else { return }
        endEditing()
        window.orderOut(nil)
        item.highlight(false)
        stopKeys()
        closedAt = Date()
        state.page = .timer
    }

    private func show(_ page: PanelState.Page) {
        endEditing()
        withAnimation(Nimbi.Motion.swap) { state.page = page }
    }

    private func back() {
        switch state.page {
        case .timer: close()
        case .settings: show(.timer)
        case .sounds: show(.settings)
        }
    }

    private func endEditing() {
        guard state.editingTask else { return }
        state.editingTask = false
        window.makeFirstResponder(nil)
    }

    /// Hangs the panel from the glyph: centred under it, kept on screen, top fixed as the
    /// content grows or shrinks.
    private func place() {
        guard let button = item.buttonFrame else { return }
        let screen = NSScreen.screens.first { $0.frame.intersects(button) } ?? NSScreen.main
        let size = host.fittingSize
        // The shadow's room (floatingPanelShadow): 16 around, 8 more below.
        let inset: CGFloat = 16
        var x = button.midX - size.width / 2
        if let visible = screen?.visibleFrame {
            x = min(max(x, visible.minX + 6 - inset), visible.maxX - 6 - size.width + inset)
        }
        let top = button.minY - 4 + inset
        window.setFrame(NSRect(x: x.rounded(), y: (top - size.height).rounded(), width: size.width, height: size.height),
                        display: true)
    }

    // MARK: Keys

    private func startKeys() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func stopKeys() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private enum Key {
        static let space: UInt16 = 49, s: UInt16 = 1, r: UInt16 = 15, t: UInt16 = 17, comma: UInt16 = 43
        static let q: UInt16 = 12, esc: UInt16 = 53, enter: UInt16 = 36, padEnter: UInt16 = 76
    }

    private func handle(_ event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection([.command, .control, .option])
        if mods == .command, event.keyCode == Key.q { NSApp.terminate(nil); return true }
        // The task field takes the keyboard; return or esc hands it back.
        if state.editingTask {
            if event.keyCode == Key.esc || event.keyCode == Key.enter || event.keyCode == Key.padEnter {
                endEditing(); return true
            }
            return false
        }
        guard mods.isEmpty else { return false }
        if event.keyCode == Key.esc {
            if model.undoReset() { return true }
            back(); return true
        }
        guard state.page == .timer else {
            if event.keyCode == Key.comma { show(.settings); return true }
            return false
        }
        switch event.keyCode {
        case Key.space: model.toggle(); return true
        case Key.s: model.skip(); return true
        case Key.r: model.reset(); return true
        case Key.t: state.editingTask = true; return true
        case Key.comma: show(.settings); return true
        default: return false
        }
    }

    // MARK: NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) { close() }
}

struct PanelRoot: View {
    @ObservedObject var state: PanelState
    var model: TempoModel
    var actions: PanelActions
    @ObservedObject private var look = NimbiAppearance.shared

    var body: some View {
        page
            .background(PanelBackground(cornerRadius: Nimbi.Radius.panel))
            .clipShape(RoundedRectangle(cornerRadius: Nimbi.Radius.panel, style: .continuous))
            .floatingPanelShadow()
            .environment(\.colorScheme, .dark)
            .fixedSize()
    }

    @ViewBuilder private var page: some View {
        switch state.page {
        case .timer: TimerView(model: model, panel: state, actions: actions)
        case .settings: SettingsView(model: model, actions: actions)
        case .sounds: SoundsView(model: model, actions: actions)
        }
    }
}
