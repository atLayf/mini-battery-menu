import AppKit
import ServiceManagement

// Open at login, scriptable so an install does not need a trip to the menu.
//     "Mini Battery Menu.app/Contents/MacOS/MiniBatteryMenu" --enable-login
if CommandLine.arguments.contains("--enable-login")
    || CommandLine.arguments.contains("--disable-login") {
    let enable = CommandLine.arguments.contains("--enable-login")
    do {
        if enable {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        print("open at login: \(SMAppService.mainApp.status == .enabled ? "on" : "off")")
        exit(0)
    } catch {
        print("failed: \(error.localizedDescription)")
        exit(1)
    }
}

// Render the README image offscreen rather than capturing the screen.
if let index = CommandLine.arguments.firstIndex(of: "--render-shot"),
   index + 1 < CommandLine.arguments.count {
    Screenshot.render(to: CommandLine.arguments[index + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
