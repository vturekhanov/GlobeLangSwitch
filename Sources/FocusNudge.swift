import AppKit

/// Works around a macOS bug: after a layout switch made by a background app (TISSelectInputSource),
/// the indicator next to the text cursor shows the previous layout on the following switches.
/// Moving keyboard focus to an invisible panel and straight back makes the focused app resync its
/// input state, as opening and closing a menu does. The app itself is never activated.
@MainActor
enum FocusNudge {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static let panel: Panel = {
        let panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.alphaValue = 0.01
        panel.level = .screenSaver
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }()

    static func perform() {
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.orderOut(nil)  // give focus back at once, so no keystroke can end up in the panel
    }
}
