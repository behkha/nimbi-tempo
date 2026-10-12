import AppKit
import TempoCore

/// Wires the pieces: the timer model, the menu bar glyph, the panel, the hot key and About.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = TempoModel()
    private var item: MenuBarItem!
    private var panel: Panel!
    private var hotkey: Hotkey?
    private let about = AboutWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        LookSettings.load()
        item = MenuBarItem(model: model)
        panel = Panel(model: model, item: item)
        panel.onAbout = { [weak self] in self?.about.show() }
        item.onClick = { [weak self] in self?.panel.toggle() }
        item.menu = { [weak self] in self?.shortMenu() ?? NSMenu() }
        hotkey = Hotkey { [weak self] in self?.model.toggle() }
        model.start()
        if Demo.state != nil, ProcessInfo.processInfo.environment["TEMPO_DEMO_SHOW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.panel.showForCapture() }
        }
    }

    /// Right-click: the few things worth reaching without opening the panel.
    private func shortMenu() -> NSMenu {
        let menu = NSMenu()
        let clock = model.clock
        let title: String
        switch clock.state {
        case .running: title = "Pause"
        case .paused: title = "Resume"
        case .idle(let next), .finished(_, _, let next): title = next == .focus ? "Start Focus" : "Start Break"
        }
        menu.addItem(ClosureMenuItem("\(title)  \(Hotkey.label)") { [weak self] in self?.model.toggle() })
        menu.addItem(ClosureMenuItem("Skip") { [weak self] in self?.model.skip() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Settings…") { [weak self] in self?.panel.open(.settings) })
        menu.addItem(ClosureMenuItem("About Tempo") { [weak self] in self?.about.show() })
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tempo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(_ title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { run() }
}
