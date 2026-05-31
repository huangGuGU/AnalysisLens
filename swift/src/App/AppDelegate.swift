import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = nil
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateApplicationIcon()
            }
        }
    }

    private func updateApplicationIcon() {
        if usesDarkAppearance {
            NSApp.applicationIconImage = iconImage(named: "AppIconDark")
        } else {
            NSApp.applicationIconImage = nil
        }
        NSApp.dockTile.display()
    }

    private var usesDarkAppearance: Bool {
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [
            .aqua,
            .darkAqua,
            .accessibilityHighContrastAqua,
            .accessibilityHighContrastDarkAqua
        ])
        return appearance == .darkAqua || appearance == .accessibilityHighContrastDarkAqua
    }

    private func iconImage(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
