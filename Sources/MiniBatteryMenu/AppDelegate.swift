import AppKit
import IOKit.ps
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var runLoopSource: CFRunLoopSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self

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
        guard let button = statusItem.button else { return }
        let info = Battery.read()
        self.info = info

        guard let info else {
            button.image = nil
            button.attributedTitle = NSAttributedString(string: "--", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
            return
        }

        button.image = chargeGlyph(for: info)
        button.attributedTitle = NSAttributedString(string: "\(info.percent)%", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: color(for: info),
        ])
    }

    /// Filled bolt while charging, hollow while plugged in but held (optimised
    /// charging pauses short of full), nothing on battery.
    private func chargeGlyph(for info: BatteryInfo) -> NSImage? {
        let name: String
        if info.isCharging {
            name = "bolt.fill"
        } else if info.isPlugged {
            name = "bolt"
        } else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .bold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Charging")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        return image
    }

    private func color(for info: BatteryInfo) -> NSColor {
        if info.isCritical { return .systemRed }
        if info.isLow { return .systemOrange }
        return .labelColor
    }

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
