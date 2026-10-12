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

    /// Runs `switchLayout` and nudges focus. Normally the switch comes first, while the app you type in
    /// holds focus, so macOS shows the layout popup next to its text cursor. With `hidingPopup` the
    /// switch runs while the panel holds focus: the panel has no text cursor, so no popup appears, and
    /// TISSelectInputSource needs no access to the focused app's com.apple.tsm.portname. But with
    /// "Automatically switch to a document's input source" on, the app restores its document's layout
    /// when it gets focus back.
    static func perform(hidingPopup: Bool, _ switchLayout: () -> Void) {
        if !hidingPopup { switchLayout() }
        panel.orderFrontRegardless()
        panel.makeKey()
        if hidingPopup { switchLayout() }
        panel.orderOut(nil)  // give focus back at once, so no keystroke can end up in the panel
    }
}
