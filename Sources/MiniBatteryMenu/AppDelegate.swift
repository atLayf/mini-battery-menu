import AppKit
import IOKit.ps
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var runLoopSource: CFRunLoopSource?
    private let view = BatteryView()

    private let compactKey = "minibattery.compact"
    private var compact: Bool {
        get { UserDefaults.standard.bool(forKey: compactKey) }
        set { UserDefaults.standard.set(newValue, forKey: compactKey); refresh() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Without this the system picks a name ("Item-0") and the dragged
        // position is persisted against an index rather than something stable.
        statusItem.autosaveName = "MiniBatteryMenu"

        // Command drag the item off the bar to remove it. The status item is
        // the whole app, so an invisible running copy would be a bug rather
        // than a state: quit instead, and reopening puts it back. Removal
        // persists visible = NO against the autosave name, so undo that here,
        // which is the re-add path the API asks applications to provide.
        statusItem.behavior = .terminationOnRemoval
        statusItem.isVisible = true

        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
        statusItem.button?.addSubview(view)
        view.autoresizingMask = [.width, .height]

        refresh()

        // The power source posts a change the instant anything moves, which
        // beats polling for the plug being pulled.
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { delegate.refresh() }
        }, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }

        // Backstop, because the percentage drifts down without an event.
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Menu bar

    private var info: BatteryInfo?

    private func refresh() {
        info = Battery.read()
        view.info = info
        view.compact = compact

        let width = view.fittingWidth()
        statusItem.length = width
        view.frame = NSRect(x: 0, y: 0, width: width, height: NSStatusBar.system.thickness)
    }

    @objc private func toggleCompact() { compact.toggle() }

    // MARK: - Login item

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Menu

extension AppDelegate: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
        menu.removeAllItems()

        guard let info else {
            menu.addItem(disabled("No battery found"))
            menu.addItem(.separator())
            addFooter(to: menu)
            return
        }

        menu.addItem(heading("\(info.percent)%  \(stateLabel(info))"))

        if let minutes = remainingMinutes(info) {
            let suffix = info.isCharging ? "until full" : "remaining"
            menu.addItem(disabled("\(Battery.duration(minutes)) \(suffix)"))
        } else if info.isCharged, info.isPlugged {
            menu.addItem(disabled("Fully charged"))
        } else {
            menu.addItem(disabled("Estimating time…"))
        }

        menu.addItem(.separator())

        if let health = info.health { menu.addItem(disabled("Capacity  \(health)% of design")) }
        if let cycles = info.cycleCount { menu.addItem(disabled("Cycles  \(cycles)")) }
        if let condition = info.condition { menu.addItem(disabled("Condition  \(condition)")) }

        menu.addItem(.separator())
        addFooter(to: menu)
    }

    private func remainingMinutes(_ info: BatteryInfo) -> Int? {
        info.isCharging ? info.minutesToFull : info.minutesToEmpty
    }

    private func stateLabel(_ info: BatteryInfo) -> String {
        if info.isCharging { return "Charging" }
        if info.isPlugged { return info.isCharged ? "Charged" : "Plugged in" }
        return "On battery"
    }

    private func addFooter(to menu: NSMenu) {
        let compactItem = NSMenuItem(title: "Compact Spacing", action: #selector(toggleCompact),
                                     keyEquivalent: "")
        compactItem.target = self
        compactItem.state = compact ? .on : .off
        compactItem.toolTip = "Tightens the padding inside this item. The gap between menu bar items is set by macOS and cannot be changed."
        menu.addItem(compactItem)

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let quitItem = NSMenuItem(title: "Quit Mini Battery Menu", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func heading(_ text: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        ])
        item.isEnabled = false
        return item
    }

    private func disabled(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
