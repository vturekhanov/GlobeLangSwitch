import AppKit

/// Works around a macOS bug: after a layout switch made by a background app (TISSelectInputSource),
/// the indicator next to the text cursor shows the previous layout on the following switches.
/// Moving keyboard focus to an invisible panel and back makes the focused app resync its
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

    /// How long the panel keeps focus after a switch made while it holds focus (`hidingPopup`). The app
    /// you type in learns about that switch only by losing focus and getting it back. Seen on macOS 27.2:
    /// when focus came straight back, the app sometimes kept typing in the old layout. A key pressed
    /// during this time goes to the panel and is lost.
    private static let hiddenSwitchFocusTime: Duration = .milliseconds(50)

    /// How long the app you type in keeps focus after a switch made without `hidingPopup` before focus
    /// moves to the panel and back. Seen on macOS 27.2: when focus left at once, Word and Claude showed no
    /// layout popup, and Claude later restored the old layout on its own.
    private static let visibleSwitchDelay: Duration = .milliseconds(150)

    /// Runs `switchLayout` and nudges focus. Normally the switch comes first, while the app you type in
    /// holds focus, so macOS shows the layout popup next to its text cursor. The app keeps focus for
    /// `visibleSwitchDelay` to handle the switch; then focus goes to the panel and comes back at once,
    /// so no keystroke can end up in the panel. With `hidingPopup` the switch runs while the panel holds
    /// focus: the panel has no text cursor, so no popup appears, and TISSelectInputSource needs no access
    /// to the focused app's com.apple.tsm.portname. The panel then keeps focus for
    /// `hiddenSwitchFocusTime`. But with "Automatically switch to a document's input source" on, the
    /// app restores its document's layout when it gets focus back.
    static func perform(hidingPopup: Bool, _ switchLayout: () -> Void) {
        guard hidingPopup else {
            switchLayout()
            Task {
                try? await Task.sleep(for: visibleSwitchDelay)
                panel.orderFrontRegardless()
                panel.makeKey()
                panel.orderOut(nil)
            }
            return
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        switchLayout()
        Task {
            try? await Task.sleep(for: hiddenSwitchFocusTime)
            panel.orderOut(nil)
        }
    }
}
