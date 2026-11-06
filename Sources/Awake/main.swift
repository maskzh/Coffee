import AppKit
import ServiceManagement

let allowDisplaySleepKey = "allowDisplaySleep"
let preventLidSleepKey = "preventLidSleep"

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let defaults = UserDefaults.standard
    var caffeinate: Process?
    var lidSleepDisabled = false

    func applicationDidFinishLaunching(_: Notification) {
        // Restore lid sleep in case a previous run was killed before cleanup.
        if defaults.bool(forKey: preventLidSleepKey) { _ = pmset(disableSleep: false) }

        menu.delegate = self
        item.button?.target = self
        item.button?.action = #selector(click)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
    }

    func applicationWillTerminate(_: Notification) { stop() }

    // Left click toggles, right click (or ⌥ click) opens the menu.
    @objc func click() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.option) == true {
            item.menu = menu
            item.button?.performClick(nil)
        } else {
            caffeinate == nil ? start() : stop()
        }
    }

    func start() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = [defaults.bool(forKey: allowDisplaySleepKey) ? "-i" : "-di", "-w", "\(getpid())"]
        process.terminationHandler = { [weak self] p in
            DispatchQueue.main.async { if self?.caffeinate === p { self?.stop() } }
        }
        guard (try? process.run()) != nil else { return }
        caffeinate = process

        if defaults.bool(forKey: preventLidSleepKey) {
            lidSleepDisabled = pmset(disableSleep: true)
            if !lidSleepDisabled { showSudoersAlert() }
        }
        updateIcon()
    }

    func stop() {
        let process = caffeinate
        caffeinate = nil
        process?.terminate()
        if lidSleepDisabled {
            _ = pmset(disableSleep: false)
            lidSleepDisabled = false
        }
        updateIcon()
    }

    func restartIfActive() {
        guard caffeinate != nil else { return }
        stop()
        start()
    }

    func updateIcon() {
        let name = caffeinate == nil ? "cup.and.saucer" : "cup.and.saucer.fill"
        item.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Awake")
    }

    // MARK: Lid sleep

    func pmset(disableSleep: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", disableSleep ? "1" : "0"]
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    func showSudoersAlert() {
        let rule = "\(NSUserName()) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
        let alert = NSAlert()
        alert.messageText = "合盖保持唤醒需要 sudoers 规则"
        alert.informativeText = "在终端执行：\n\necho '\(rule)' | sudo tee /etc/sudoers.d/awake"
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        addItem("允许显示器睡眠", #selector(toggleDisplaySleep), on: defaults.bool(forKey: allowDisplaySleepKey))
        addItem("合盖时保持唤醒", #selector(toggleLidSleep), on: defaults.bool(forKey: preventLidSleepKey))
        addItem("开机启动", #selector(toggleLaunchAtLogin), on: SMAppService.mainApp.status == .enabled)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate), keyEquivalent: "q")
    }

    func menuDidClose(_: NSMenu) { item.menu = nil }

    func addItem(_ title: String, _ action: Selector, on: Bool) {
        let menuItem = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.state = on ? .on : .off
    }

    @objc func toggleDisplaySleep() {
        defaults.set(!defaults.bool(forKey: allowDisplaySleepKey), forKey: allowDisplaySleepKey)
        restartIfActive()
    }

    @objc func toggleLidSleep() {
        defaults.set(!defaults.bool(forKey: preventLidSleepKey), forKey: preventLidSleepKey)
        restartIfActive()
    }

    @objc func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        try? service.status == .enabled ? service.unregister() : service.register()
    }
}

let delegate = App()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
