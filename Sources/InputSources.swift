import Carbon

/// Switches keyboard input sources like the system action "Select next source in Input menu".
@MainActor
enum InputSources {
    /// Kinds of sources listed in the Input menu (an input method with modes is listed as its modes).
    private static let menuTypes: Set<String> = [
        kTISTypeKeyboardLayout as String,
        kTISTypeKeyboardInputMode as String,
        kTISTypeKeyboardInputMethodWithoutModes as String,
    ]

    /// Selects the enabled input source that follows the current one, wrapping around.
    static func selectNext() {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ] as CFDictionary
        guard let enabled = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
        else { return }
        let sources = enabled.filter { menuTypes.contains(string($0, kTISPropertyInputSourceType) ?? "") }
        guard sources.count > 1 else { return }
        let current = currentID()
        let next = sources[((sources.firstIndex { id($0) == current } ?? -1) + 1) % sources.count]
        TISSelectInputSource(next)
    }

    private static func currentID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return id(source)
    }

    private static func id(_ source: TISInputSource) -> String? {
        string(source, kTISPropertyInputSourceID)
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }
}
