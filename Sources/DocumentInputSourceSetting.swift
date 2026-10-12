import Foundation

/// Reads (never changes) the system setting "Automatically switch to a document's input source".
/// When it is on, an app restores its document's layout on getting focus back, which undoes a switch
/// made while FocusNudge's panel holds focus (Hide Layout Popup).
enum DocumentInputSourceSetting {
    static var isOn: Bool {
        let domain = "com.apple.HIToolbox" as CFString
        CFPreferencesAppSynchronize(domain)  // pick up changes made in System Settings
        let properties = CFPreferencesCopyAppValue("AppleGlobalTextInputProperties" as CFString, domain)
        let value = (properties as? [String: Any])?["TextInputGlobalPropertyPerContextInput"]
        return value as? Bool ?? false  // not set means off
    }
}
