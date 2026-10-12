import AppKit
import NimbiKit
import SwiftUI

/// Developer check: `TEMPO_DEMO=focus Tempo --render <dir>` draws the panel's pages for the demo
/// timer into PNGs (at 2x), without opening a window or taking the keyboard.
@MainActor
enum RenderCommand {
    static func run(into directory: URL) {
        guard let scene = Demo.state else {
            FileHandle.standardError.write(Data("set TEMPO_DEMO=ready|focus|up|break|long|paused\n".utf8))
            exit(2)
        }
        LookSettings.load()
        let model = TempoModel()
        let state = PanelState()
        let actions = PanelActions(toggle: {}, skip: {}, reset: {}, undo: {}, editTask: {}, endEditing: {},
                                   open: { _ in }, back: {}, about: {})
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        func shot(_ name: String, _ page: PanelState.Page) {
            state.page = page
            let renderer = ImageRenderer(content: PanelRoot(state: state, model: model, actions: actions))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
            let url = directory.appendingPathComponent("\(name).png")
            try? png.write(to: url)
            print(url.path)
        }
        shot("timer-\(scene.rawValue)", .timer)
        shot("settings", .settings)
        shot("sounds", .sounds)
    }
}
