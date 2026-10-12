import AppKit
import NimbiKit
import SwiftUI

/// "Tempo by nimbi" (DESIGN.md 1, 16): the cloud, the name and the version.
@MainActor
final class AboutWindow {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.appearance = NSAppearance(named: .darkAqua)
            w.backgroundColor = NSColor(Nimbi.Surface.window)
            w.contentView = NSHostingView(rootView: AboutView())
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct AboutView: View {
    /// The cloud cycles through its tools, slowly, to show off.
    @ViewState private var form = CloudForm.cloud

    var body: some View {
        VStack(spacing: 12) {
            NimbiCloud(size: 64, mood: .relaxed, form: form, progress: 0.4)
                .frame(width: 64, height: 64)
                .padding(.top, 22)
                .onTapGesture {
                    let all = CloudForm.allCases
                    form = all[(all.firstIndex(of: form)! + 1) % all.count]
                }
                .accessibilityLabel("The Tempo cloud")
            VStack(spacing: 3) {
                (Text("Tempo").foregroundColor(Nimbi.Text.primary)
                 + Text(" by nimbi").foregroundColor(Nimbi.Text.dim))
                    .font(.system(size: 17, weight: .semibold))
                Text("Version \(Bundle.main.shortVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(Nimbi.Text.faint)
            }
            Text("A little cloud that keeps time while you work.")
                .font(.system(size: 12.5))
                .foregroundStyle(Nimbi.Text.message)
                .multilineTextAlignment(.center)
            Text("Tap the cloud to see its tools.")
                .font(.system(size: 11))
                .foregroundStyle(Nimbi.Text.dim)
            Text("Made by behkha")
                .font(.system(size: 10.5))
                .foregroundStyle(Nimbi.Text.faint)
                .padding(.bottom, 20)
        }
        .frame(width: 300)
        .environment(\.colorScheme, .dark)
    }
}
