import AppKit

/// Renders the README image offscreen, in both appearances, showing the three
/// states the menu bar item can be in. Never captures the screen.
///
///     "Mini Battery Menu.app/Contents/MacOS/MiniBatteryMenu" --render-shot docs/menubar.png
enum Screenshot {

    private static let samples = [
        BatteryInfo(percent: 76, isCharging: true, isPlugged: true),
        BatteryInfo(percent: 45, isCharging: false, isPlugged: false),
        BatteryInfo(percent: 12, isCharging: false, isPlugged: false),
    ]

    private static let sampleGap: CGFloat = 30

    /// The real view, so the README image cannot drift from what the menu bar
    /// actually draws.
    private static func view(for info: BatteryInfo) -> BatteryView {
        let view = BatteryView()
        view.info = info
        return view
    }

    static func render(to path: String) {
        let barHeight: CGFloat = 22
        let padX: CGFloat = 18
        let padY: CGFloat = 13

        let contentWidth = samples.reduce(CGFloat(0)) { $0 + view(for: $1).fittingWidth() }
            + sampleGap * CGFloat(samples.count - 1)
        let size = NSSize(width: contentWidth + padX * 2, height: (barHeight + padY * 2) * 2)

        let image = NSImage(size: size)
        image.lockFocus()

        let bands: [(NSAppearance.Name, NSColor)] = [
            (.aqua, NSColor(calibratedWhite: 0.93, alpha: 1)),
            (.darkAqua, NSColor(calibratedWhite: 0.16, alpha: 1)),
        ]

        for (index, band) in bands.enumerated() {
            let (name, backdrop) = band
            let bandHeight = barHeight + padY * 2
            let bandY = size.height - bandHeight * CGFloat(index + 1)

            backdrop.setFill()
            NSRect(x: 0, y: bandY, width: size.width, height: bandHeight).fill()

            guard let appearance = NSAppearance(named: name) else { continue }
            appearance.performAsCurrentDrawingAppearance {
                var x = padX
                for sample in samples {
                    let item = view(for: sample)
                    item.appearance = appearance
                    let width = item.fittingWidth()
                    item.frame = NSRect(x: 0, y: 0, width: width, height: barHeight)

                    NSGraphicsContext.saveGraphicsState()
                    let transform = NSAffineTransform()
                    transform.translateX(by: x, yBy: bandY + padY)
                    transform.concat()
                    item.draw(item.bounds)
                    NSGraphicsContext.restoreGraphicsState()

                    x += width + sampleGap
                }
            }
        }

        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path) (\(Int(size.width))x\(Int(size.height)))")
    }





}
