import AppKit
import NimbiKit
import SwiftUI

/// Tempo's look settings: saved here, mirrored into NimbiKit's `NimbiAppearance`.
enum LookSettings {
    private static let themeKey = "Theme"
    private static let textScaleKey = "TextScale"
    static let textScales: [Double] = [0.9, 1, 1.1, 1.25]

    static func load(_ defaults: UserDefaults = .standard) {
        let look = NimbiAppearance.shared
        look.theme = defaults.string(forKey: themeKey).flatMap(NimbiTheme.init(rawValue:)) ?? .dark
        let scale = defaults.double(forKey: textScaleKey)
        look.textScale = textScales.contains(scale) ? scale : 1
        // Tempo lives in the menu bar; panels never hang from the notch (DESIGN.md 18.2).
        look.dock = .right
    }

    static func setTheme(_ theme: NimbiTheme, _ defaults: UserDefaults = .standard) {
        NimbiAppearance.shared.theme = theme
        defaults.set(theme.rawValue, forKey: themeKey)
    }

    static func setTextScale(_ scale: Double, _ defaults: UserDefaults = .standard) {
        NimbiAppearance.shared.textScale = scale
        defaults.set(scale, forKey: textScaleKey)
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev" }
}
