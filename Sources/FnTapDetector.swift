import AppKit

/// Detects a short tap of fn (🌐) pressed on its own, without any macOS permission.
///
/// Event monitors receive only modifier-key changes (Shift, Control, Option, Command,
/// Caps Lock, fn) and can neither change nor block them. Whether another key was pressed
/// while fn was held is taken from system-wide HID event counters and last-press times,
/// which tell how many keys were pressed and when, but not which ones. Nothing is stored or logged.
@MainActor
final class FnTapDetector {
    /// Holding fn this long or longer is not a tap.
    var threshold: TimeInterval = 0.3
    var onTap: () -> Void = {}

    private static let fnKeyCode: UInt16 = 63  // kVK_Function
    private static let otherModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
    /// Presses that make fn part of a combination: ordinary keys (letters, arrows,
    /// Delete, F1–F12) and media/brightness keys (NX_SYSDEFINED, type 14).
    private static let comboEventTypes: [CGEventType] = [.keyDown, CGEventType(rawValue: 14)!]
    /// Releasing fn marks the latest key-down time too; a press this close to the release is that mark.
    private static let releaseMargin: TimeInterval = 0.01

    private var monitor: Any?
    private var localMonitor: Any?
    private var fnDownAt: TimeInterval?
    private var comboCountsAtFnDown: [UInt32] = []
    /// fn is being used together with another key or modifier.
    private var combined = false
    private var anyEventReceived = false
    private var systemModifierCountAtStart: UInt32 = 0

    /// Self-check: false if the system registered many modifier key events but none reached
    /// the app, i.e. macOS no longer delivers them without a permission. The margin is large
    /// because modifiers typed into secure fields (e.g. the lock screen) are not delivered.
    var isReceivingEvents: Bool {
        anyEventReceived || Self.systemModifierCount() &- systemModifierCountAtStart < 20
    }

    func start() {
        guard monitor == nil else { return }
        anyEventReceived = false
        systemModifierCountAtStart = Self.systemModifierCount()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = event.keyCode, flags = event.modifierFlags, time = event.timestamp
            MainActor.assumeIsolated { self?.handle(keyCode: keyCode, flags: flags, time: time) }
        }
        // The global monitor misses events sent to this app itself, e.g. fn pressed while
        // FocusNudge's panel still holds keyboard focus.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = event.keyCode, flags = event.modifierFlags, time = event.timestamp
            MainActor.assumeIsolated { self?.handle(keyCode: keyCode, flags: flags, time: time) }
            return event
        }
    }

    /// Stops observing completely and forgets a press in progress.
    func stop() {
        for monitor in [monitor, localMonitor].compactMap({ $0 }) { NSEvent.removeMonitor(monitor) }
        monitor = nil
        localMonitor = nil
        fnDownAt = nil
    }

    private func handle(keyCode: UInt16, flags: NSEvent.ModifierFlags, time: TimeInterval) {
        anyEventReceived = true
        guard keyCode == Self.fnKeyCode else {
            if fnDownAt != nil { combined = true }
            return
        }
        let withOtherModifier = !flags.isDisjoint(with: Self.otherModifiers)
        if flags.contains(.function) {
            fnDownAt = time
            comboCountsAtFnDown = Self.comboCounts()
            combined = withOtherModifier
        } else if let downAt = fnDownAt {
            fnDownAt = nil
            let isShort = time - downAt < threshold
            let noOtherKeys = Self.comboCounts() == comboCountsAtFnDown && !Self.comboPressed(after: downAt, before: time)
            if isShort && noOtherKeys && !combined && !withOtherModifier { onTap() }
        }
    }

    private static func comboCounts() -> [UInt32] {
        comboEventTypes.map { CGEventSource.counterForEventType(.hidSystemState, eventType: $0) }
    }

    /// Whether a combo key was pressed while fn was held, judged by the latest press of each kind
    /// (uptime, the clock of NSEvent.timestamp). Catches presses the counter snapshot missed
    /// because the fn-down event was handled late, e.g. after a delay of a few hundred ms.
    private static func comboPressed(after downAt: TimeInterval, before upAt: TimeInterval) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        return comboEventTypes.contains { type in
            let pressedAt = now - CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: type)
            return pressedAt >= downAt && pressedAt < upAt - releaseMargin
        }
    }

    private static func systemModifierCount() -> UInt32 {
        CGEventSource.counterForEventType(.hidSystemState, eventType: .flagsChanged)
    }
}
