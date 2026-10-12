import AppKit
import Combine
import NimbiKit
import SwiftUI
import TempoCore

/// The menu bar glyph (DESIGN.md 11.3, option A): the nimbi cloud with its eyes cut out, as a
/// template image so macOS tints it, then the minutes left ("18′", seconds in the last one). An
/// amber dot shows only while time is up and the next phase waits for you (`needsYou`).
enum MenuBarGlyph {
    static let size = NSSize(width: 18, height: 18)

    static func image() -> NSImage {
        let image = NSImage(size: size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let s: CGFloat = 15
            let origin = CGPoint(x: (size.width - s) / 2, y: (size.height - s) / 2)
            let cloud = CGMutablePath()
            cloud.addPath(CloudShape().path(in: CGRect(origin: origin, size: CGSize(width: s, height: s))).cgPath)
            // The eyes, looking a touch right, cut out with the even-odd rule.
            let face = CGPoint(x: origin.x + s / 2 + s * 0.08, y: origin.y + s / 2 - s * 0.02)
            for (dx, dy) in [(-s * 0.095, 0), (s * 0.095, s * 0.01)] {
                cloud.addEllipse(in: CGRect(x: face.x + dx - s * 0.07, y: face.y + dy - s * 0.1,
                                            width: s * 0.14, height: s * 0.2))
            }
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(cloud)
            context.fillPath(using: .evenOdd)
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Owns the status item: draws the glyph and minutes from the model, and turns clicks into
/// opening the panel (left) or a short menu (right).
@MainActor
final class MenuBarItem: NSObject {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var onClick: (() -> Void)?
    var menu: () -> NSMenu = { NSMenu() }

    private let model: TempoModel
    private let dot = NSView()
    private var bag: Set<AnyCancellable> = []
    private var lastTitle = ""

    init(model: TempoModel) {
        self.model = model
        super.init()
        guard let button = statusItem.button else { return }
        button.image = MenuBarGlyph.image()
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor(Nimbi.State.waiting).cgColor
        dot.layer?.cornerRadius = 2.6
        dot.isHidden = true
        button.addSubview(dot)

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.draw() } }
            .store(in: &bag)
        draw()
    }

    private func draw() {
        guard let button = statusItem.button else { return }
        let clock = model.clock
        let mood = model.mood
        var title = ""
        var dim = false
        switch clock.state {
        case .running: title = TimeText.menuBar(model.remaining)
        case .paused: title = TimeText.menuBar(model.remaining); dim = true
        case .finished: title = "0:00"
        case .idle: title = ""
        }
        let key = title + (dim ? "~" : "")
        if key != lastTitle {
            lastTitle = key
            let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if dim { attributes[.foregroundColor] = NSColor.secondaryLabelColor }
            button.attributedTitle = NSAttributedString(string: title.isEmpty ? "" : " " + title, attributes: attributes)
        }

        let needsYou = mood.urgency == .needsYou
        dot.isHidden = !needsYou
        button.layoutSubtreeIfNeeded()
        if let cell = button.cell {
            let image = cell.imageRect(forBounds: button.bounds)
            let d: CGFloat = 5.2
            let y = button.isFlipped ? image.minY + 0.4 : image.maxY - d - 0.4
            dot.frame = NSRect(x: image.maxX - d + 0.4, y: y, width: d, height: d)
        }

        let line = Self.line(clock, remaining: model.remaining)
        button.toolTip = "Tempo · \(line) · \(Hotkey.label)"
        button.setAccessibilityLabel(["Tempo", line, needsYou ? "needs you" : nil].compactMap { $0 }.joined(separator: ", "))
    }

    /// "Focus · 18 minutes left", "Time's up · break next", "Ready".
    static func line(_ clock: PomodoroClock, remaining: TimeInterval) -> String {
        switch clock.state {
        case .idle(let next): return next == .focus ? "Ready" : "\(next.title) next"
        case .running(let p, _, _): return "\(p.title) · \(TimeText.spoken(remaining))"
        case .paused(let p, _, _, _): return "\(p.title) paused · \(TimeText.spoken(remaining))"
        case .finished(_, _, let next): return "Time's up · \(next.title.lowercased()) next"
        }
    }

    func highlight(_ on: Bool) { statusItem.button?.highlight(on) }

    /// The button's frame on screen, for hanging the panel below it.
    var buttonFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            onClick?()
        }
    }
}
