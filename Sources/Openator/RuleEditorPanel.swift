import AppKit

enum RuleEditorResult {
    case save(URLRule)
    case delete
    case cancel
}

final class RuleEditorPanel {
    static func show(rule: URLRule?, browsers: [BrowserInfo]) -> RuleEditorResult {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = rule != nil ? "Edit Rule" : "Add Rule"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.center()

        let cv = panel.contentView!
        let fieldW: CGFloat = 380

        let urlLabel = NSTextField(labelWithString: "URL includes:")
        urlLabel.frame = NSRect(x: 20, y: 160, width: fieldW, height: 17)
        cv.addSubview(urlLabel)

        let urlField = NSTextField(frame: NSRect(x: 20, y: 132, width: fieldW, height: 24))
        urlField.placeholderString = "e.g. github.com"
        urlField.stringValue = rule?.urlContains ?? ""
        cv.addSubview(urlField)

        let browserLabel = NSTextField(labelWithString: "Open with:")
        browserLabel.frame = NSRect(x: 20, y: 100, width: fieldW, height: 17)
        cv.addSubview(browserLabel)

        let popup = NSPopUpButton(
            frame: NSRect(x: 20, y: 70, width: fieldW, height: 26),
            pullsDown: false
        )
        for b in browsers {
            popup.addItem(withTitle: b.name)
            popup.lastItem?.representedObject = b.bundleId
        }
        if let r = rule {
            if let idx = browsers.firstIndex(where: {
                $0.bundleId.caseInsensitiveCompare(r.browserBundleId) == .orderedSame
            }) {
                popup.selectItem(at: idx)
            } else {
                popup.addItem(withTitle: "Unavailable browser (\(r.browserBundleId))")
                popup.lastItem?.representedObject = r.browserBundleId
                popup.selectItem(at: popup.numberOfItems - 1)
            }
        }
        cv.addSubview(popup)

        let handler = ModalHandler(
            panel: panel, urlField: urlField, popup: popup, existing: rule
        )
        objc_setAssociatedObject(panel, "handler", handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        panel.delegate = handler

        let cancelBtn = NSButton(
            title: "Cancel", target: handler, action: #selector(ModalHandler.doCancel)
        )
        cancelBtn.frame = NSRect(x: 20, y: 16, width: 80, height: 32)
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cv.addSubview(cancelBtn)

        if rule != nil {
            let delBtn = NSButton(
                title: "Delete", target: handler, action: #selector(ModalHandler.doDelete)
            )
            delBtn.frame = NSRect(x: 110, y: 16, width: 80, height: 32)
            delBtn.bezelStyle = .rounded
            cv.addSubview(delBtn)
        }

        let saveBtn = NSButton(
            title: "Save", target: handler, action: #selector(ModalHandler.doSave)
        )
        saveBtn.frame = NSRect(x: 320, y: 16, width: 80, height: 32)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        cv.addSubview(saveBtn)

        panel.makeFirstResponder(urlField)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.runModal(for: panel)

        return handler.result
    }
}

private final class ModalHandler: NSObject, NSWindowDelegate {
    let panel: NSPanel
    let urlField: NSTextField
    let popup: NSPopUpButton
    let existing: URLRule?
    var result: RuleEditorResult = .cancel

    init(panel: NSPanel, urlField: NSTextField, popup: NSPopUpButton, existing: URLRule?) {
        self.panel = panel
        self.urlField = urlField
        self.popup = popup
        self.existing = existing
    }

    @objc func doSave() {
        let pattern = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else {
            NSSound.beep()
            panel.makeFirstResponder(urlField)
            return
        }
        guard let bid = popup.selectedItem?.representedObject as? String else { return }
        result = .save(URLRule(
            id: existing?.id ?? UUID(),
            urlContains: pattern,
            browserBundleId: bid
        ))
        panel.close()
    }

    @objc func doCancel() {
        panel.close()
    }

    @objc func doDelete() {
        result = .delete
        panel.close()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
    }
}
