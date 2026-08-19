import AppKit
import CoreServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.bundleURL as CFURL? {
            LSRegisterURL(url, true)
        }
        setupMainMenu()
        setupStatusBar()
        registerURLHandler()
        DispatchQueue.main.async { self.promptDefaultBrowserIfNeeded() }
    }

    // MARK: - Main Menu (enables Cmd+C/V/X/A in text fields)

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        guard let button = statusItem.button else { return }
        button.image = makeStatusBarIcon()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func makeStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let path = NSBezierPath()
            path.lineWidth = 1.7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            // Y-fork: stem at bottom, branches pointing up
            path.move(to: NSPoint(x: 9, y: 3))
            path.line(to: NSPoint(x: 9, y: 9))
            path.move(to: NSPoint(x: 9, y: 9))
            path.line(to: NSPoint(x: 4, y: 15))
            path.move(to: NSPoint(x: 9, y: 9))
            path.line(to: NSPoint(x: 14, y: 15))

            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - URL Handling

    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(
            forKeyword: AEKeyword(keyDirectObject)
        )?.stringValue,
              let url = URL(string: urlString)
        else { return }

        let browserId: String
        if let rule = RuleStore.shared.matchingRule(for: url) {
            browserId = rule.browserBundleId
        } else {
            browserId = UserDefaults.standard.string(forKey: "defaultBrowserId")
                ?? "com.apple.Safari"
        }

        if !BrowserManager.shared.openURL(url, withBrowser: browserId),
           browserId.caseInsensitiveCompare("com.apple.Safari") != .orderedSame {
            BrowserManager.shared.openURL(url, withBrowser: "com.apple.Safari")
        }
    }

    // MARK: - Menu

    func menuWillOpen(_ menu: NSMenu) {
        guard menu == self.menu else { return }
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        // Default Browser submenu
        let browserItem = NSMenuItem(title: "Default Browser", action: nil, keyEquivalent: "")
        let browserSub = NSMenu()
        let browsers = BrowserManager.shared.availableBrowsers()
        let currentDefault = (
            UserDefaults.standard.string(forKey: "defaultBrowserId") ?? "com.apple.Safari"
        ).lowercased()

        for browser in browsers {
            let item = NSMenuItem(
                title: browser.name,
                action: #selector(selectDefaultBrowser(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = browser.bundleId
            item.state = browser.bundleId.lowercased() == currentDefault ? .on : .off
            browserSub.addItem(item)
        }
        browserItem.submenu = browserSub
        menu.addItem(browserItem)

        menu.addItem(.separator())

        // Open on System Start
        let loginItem = NSMenuItem(
            title: "Open on System Start",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // Rules submenu
        let rulesItem = NSMenuItem(title: "Rules", action: nil, keyEquivalent: "")
        let rulesSub = NSMenu()
        let rules = RuleStore.shared.rules

        for rule in rules {
            let name = BrowserManager.shared.browserName(for: rule.browserBundleId)
            let item = NSMenuItem(
                title: "\"\(rule.urlContains)\" \u{2192} \(name)",
                action: #selector(editRule(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = rule.id
            rulesSub.addItem(item)
        }

        if !rules.isEmpty { rulesSub.addItem(.separator()) }

        let addItem = NSMenuItem(
            title: "Add Rule\u{2026}",
            action: #selector(addRule),
            keyEquivalent: ""
        )
        addItem.target = self
        rulesSub.addItem(addItem)

        if !rules.isEmpty {
            let removeAllItem = NSMenuItem(
                title: "Remove All Rules",
                action: #selector(removeAllRules),
                keyEquivalent: ""
            )
            removeAllItem.target = self
            rulesSub.addItem(removeAllItem)
        }

        rulesItem.submenu = rulesSub
        menu.addItem(rulesItem)

        menu.addItem(.separator())

        // Set as Default Browser (only if not already)
        if !isDefaultBrowser() {
            let setDefault = NSMenuItem(
                title: "Set as Default Browser\u{2026}",
                action: #selector(requestSetDefault),
                keyEquivalent: ""
            )
            setDefault.target = self
            menu.addItem(setDefault)
            menu.addItem(.separator())
        }

        // Quit
        menu.addItem(NSMenuItem(
            title: "Quit Openator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    // MARK: - Actions

    @objc private func selectDefaultBrowser(_ sender: NSMenuItem) {
        guard let bundleId = sender.representedObject as? String else { return }
        UserDefaults.standard.set(bundleId, forKey: "defaultBrowserId")
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {}
    }

    @objc private func addRule() {
        let browsers = BrowserManager.shared.availableBrowsers()
        guard !browsers.isEmpty else { return }
        let result = RuleEditorPanel.show(rule: nil, browsers: browsers)
        if case .save(let rule) = result {
            RuleStore.shared.addRule(rule)
        }
    }

    @objc private func editRule(_ sender: NSMenuItem) {
        guard let ruleId = sender.representedObject as? UUID else { return }
        guard let rule = RuleStore.shared.rules.first(where: { $0.id == ruleId }) else { return }
        let browsers = BrowserManager.shared.availableBrowsers()
        guard !browsers.isEmpty else { return }

        switch RuleEditorPanel.show(rule: rule, browsers: browsers) {
        case .save(let updated):
            RuleStore.shared.updateRule(updated)
        case .delete:
            RuleStore.shared.removeRule(id: ruleId)
        case .cancel:
            break
        }
    }

    @objc private func removeAllRules() {
        let alert = NSAlert()
        alert.messageText = "Remove All Rules"
        alert.informativeText = "Are you sure you want to remove all URL routing rules?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove All")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            RuleStore.shared.removeAll()
        }
    }

    @objc private func requestSetDefault() {
        setAsDefaultBrowser()
    }

    // MARK: - Default Browser

    private func isDefaultBrowser() -> Bool {
        guard let own = Bundle.main.bundleIdentifier?.lowercased() else { return false }
        let testURL = URL(string: "https://example.com")!
        guard let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: testURL),
              let defaultId = Bundle(url: defaultApp)?.bundleIdentifier?.lowercased()
        else { return false }
        return defaultId == own
    }

    private func setAsDefaultBrowser() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultHandlerForURLScheme("http" as CFString, id as CFString)
        LSSetDefaultHandlerForURLScheme("https" as CFString, id as CFString)
    }

    private func promptDefaultBrowserIfNeeded() {
        guard !isDefaultBrowser() else { return }

        let alert = NSAlert()
        alert.messageText = "Set Openator as Default Browser"
        alert.informativeText = """
            Openator needs to be your default web browser to intercept and route URLs \
            to the appropriate browser based on your rules.

            You can change this later in System Settings.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Set as Default")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            setAsDefaultBrowser()
        }
    }
}
