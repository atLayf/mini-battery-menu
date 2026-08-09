import AppKit

/// Renders the README image offscreen, in both appearances, showing the three
/// states the menu bar item can be in. Never captures the screen.
///
///     "Mini Battery Menu.app/Contents/MacOS/MiniBatteryMenu" --render-shot docs/menubar.png
enum Screenshot {

    private struct Sample {
        let percent: Int
        let charging: Bool
        let plugged: Bool
    }

    private static let samples = [
        Sample(percent: 76, charging: true, plugged: true),
        Sample(percent: 45, charging: false, plugged: false),
        Sample(percent: 12, charging: false, plugged: false),
    ]

    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private static let sampleGap: CGFloat = 30
    private static let glyphGap: CGFloat = 3

    static func render(to path: String) {
        let barHeight: CGFloat = 22
        let padX: CGFloat = 18
        let padY: CGFloat = 13

        let contentWidth = samples.reduce(CGFloat(0)) { $0 + width(of: $1) }
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
                    draw(sample, at: x, centreY: bandY + bandHeight / 2)
                    x += width(of: sample) + sampleGap
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

    private static func colour(for sample: Sample) -> NSColor {
        if !sample.plugged, sample.percent <= 10 { return .systemRed }
        if !sample.plugged, sample.percent <= 20 { return .systemOrange }
        return .labelColor
    }

    private static func glyph(for sample: Sample) -> NSImage? {
        guard sample.charging || sample.plugged else { return nil }
        var config = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .bold)
        config = config.applying(NSImage.SymbolConfiguration(paletteColors: [colour(for: sample)]))
        return NSImage(systemSymbolName: sample.charging ? "bolt.fill" : "bolt",
                       accessibilityDescription: nil)?.withSymbolConfiguration(config)
    }

    private static func attributed(_ sample: Sample) -> NSAttributedString {
        NSAttributedString(string: "\(sample.percent)%", attributes: [
            .font: font,
            .foregroundColor: colour(for: sample),
        ])
    }

    private static func width(of sample: Sample) -> CGFloat {
        var total = ceil(attributed(sample).size().width)
        if let glyph = glyph(for: sample) { total += glyph.size.width + glyphGap }
        return total
    }

    private static func draw(_ sample: Sample, at x: CGFloat, centreY: CGFloat) {
        var cursor = x
        if let glyph = glyph(for: sample) {
            glyph.draw(in: NSRect(x: cursor, y: centreY - glyph.size.height / 2,
                                  width: glyph.size.width, height: glyph.size.height))
            cursor += glyph.size.width + glyphGap
        }
        let text = attributed(sample)
        let size = text.size()
        text.draw(at: NSPoint(x: cursor, y: centreY - size.height / 2))
    }
}
