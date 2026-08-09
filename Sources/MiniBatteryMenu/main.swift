import AppKit

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
