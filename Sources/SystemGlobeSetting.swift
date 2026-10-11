import Foundation

/// Reads (never changes) the system setting "Press 🌐 key to". Anything but "Do Nothing"
/// makes macOS react to the same tap too: switch the layout a second time, show emoji, etc.
enum SystemGlobeSetting {
    /// Why the setting interferes, or nil if it is "Do Nothing".
    static var conflict: String? {
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)  // pick up changes made in System Settings
        switch CFPreferencesCopyAppValue("AppleFnUsageType" as CFString, domain) as? Int {
        case 0: return nil
        case 1: return .localized("globe.changesInputSource")
        case 2: return .localized("globe.showsEmoji")
        case 3: return .localized("globe.startsDictation")
        default: return .localized("globe.mayReact")  // not set yet, or an unknown value
        }
    }
}
