import AppKit
import ServiceManagement

/// Menu-bar app: a globe icon with a menu; no Dock icon (LSUIElement in Info.plist).
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    private static let thresholdKey = "tapThresholdMs"
    private static let thresholdChoices = Array(stride(from: 100, through: 500, by: 50))

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let detector = FnTapDetector()
    private var paused = false
    private var loginItemError: String?

    private var thresholdMs: Int { UserDefaults.standard.integer(forKey: Self.thresholdKey) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.thresholdKey: 300])
        statusItem.button?.image = NSImage(systemSymbolName: "globe", accessibilityDescription: .localized("app.name"))
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        applyThreshold()
        detector.onTap = {
            InputSources.selectNext()
            FocusNudge.perform()
        }
        detector.start()

        // Sleep and fast user switching: forget a press in progress and start observing afresh.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(restartDetection), name: name, object: nil)
        }
        // Keeps the warning mark current while the menu is closed.
        Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(refreshIcon),
                             userInfo: nil, repeats: true).tolerance = 10
        refreshIcon()
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for line in statusLines() {
            menu.addItem(withTitle: line, action: nil, keyEquivalent: "").isEnabled = false
        }
        menu.addItem(.separator())
        menu.addItem(commandItem("menu.pause", #selector(togglePause), checked: paused))
        menu.addItem(commandItem("menu.launchAtLogin", #selector(toggleLaunchAtLogin), checked: isLoginItem))
        menu.addItem(makeThresholdItem())
        menu.addItem(.separator())
        menu.addItem(withTitle: .localized("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        refreshIcon()
    }

    private func statusLines() -> [String] {
        var lines: [String] = []
        if paused {
            lines.append(.localized("status.paused"))
        } else if detector.isReceivingEvents {
            lines.append(.localized("status.working"))
        } else {
            lines += [.localized("status.noEvents"), .localized("status.noEventsHint")]
        }
        if let conflict = SystemGlobeSetting.conflict { lines += [conflict, .localized("globe.fix")] }
        if SMAppService.mainApp.status == .requiresApproval { lines.append(.localized("login.approval")) }
        if let loginItemError { lines.append(loginItemError) }
        return lines
    }

    private func commandItem(_ key: String, _ action: Selector, checked: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: .localized(key), action: action, keyEquivalent: "")
        item.target = self
        item.state = checked ? .on : .off
        return item
    }

    /// "Tap threshold: 300 ms ▸" with a submenu of 100…500 ms in steps of 50; the current value is checked.
    private func makeThresholdItem() -> NSMenuItem {
        let submenu = NSMenu()
        for ms in Self.thresholdChoices {
            let choice = NSMenuItem(title: String(format: .localized("menu.thresholdChoice"), ms),
                                    action: #selector(chooseThreshold(_:)), keyEquivalent: "")
            choice.target = self
            choice.tag = ms
            choice.state = ms == thresholdMs ? .on : .off
            submenu.addItem(choice)
        }
        let item = NSMenuItem(title: String(format: .localized("menu.threshold"), thresholdMs),
                              action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    // MARK: - Actions

    /// While paused, keyboard events are not observed at all.
    @objc private func togglePause() {
        paused.toggle()
        restartDetection()
    }

    @objc private func restartDetection() {
        detector.stop()
        if !paused { detector.start() }
        refreshIcon()
    }

    @objc private func chooseThreshold(_ item: NSMenuItem) {
        UserDefaults.standard.set(item.tag, forKey: Self.thresholdKey)
        applyThreshold()
    }

    private func applyThreshold() {
        detector.threshold = Double(thresholdMs) / 1000
    }

    private var isLoginItem: Bool { [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) }

    @objc private func toggleLaunchAtLogin() {
        do {
            if isLoginItem { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
    }

    // MARK: - Icon

    /// Dimmed while paused; "!" next to the globe when something prevents normal work.
    @objc private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let problem = !paused && (!detector.isReceivingEvents || SystemGlobeSetting.conflict != nil)
        button.appearsDisabled = paused
        button.title = problem ? .localized("status.problemMark") : ""
        button.imagePosition = problem ? .imageLeading : .imageOnly
    }
}

extension String {
    /// A UI string from Resources/<language>.lproj/Localizable.strings.
    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}
