import AppKit

@main
enum TempoMain {
    @MainActor
    static func main() {
        if let i = CommandLine.arguments.firstIndex(of: "--render"), i + 1 < CommandLine.arguments.count {
            _ = NSApplication.shared
            RenderCommand.run(into: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            exit(0)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
