import AppKit

/// Draws the status item contents. A custom view rather than the button's own
/// title so the padding is ours to control: macOS owns the gap between status
/// items, the padding inside one is the only width an app can give back.
final class BatteryView: NSView {

    var info: BatteryInfo? { didSet { needsDisplay = true } }
    var compact: Bool = false { didSet { needsDisplay = true } }
    var isHighlighted: Bool = false { didSet { needsDisplay = true } }

    private var sidePadding: CGFloat { compact ? 2 : 6 }
    private var glyphGap: CGFloat { compact ? 2 : 3 }

    private let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

    // MARK: presentation

    private var textColor: NSColor {
        guard let info else { return .secondaryLabelColor }
        if isHighlighted { return .selectedMenuItemTextColor }
        if info.isCritical { return .systemRed }
        if info.isLow { return .systemOrange }
        return .labelColor
    }

    private var label: String {
        guard let info else { return "--" }
        return "\(info.percent)%"
    }

    /// Filled bolt while charging, hollow while plugged but held short of full,
    /// nothing on battery.
    private var glyph: NSImage? {
        guard let info, info.isCharging || info.isPlugged else { return nil }
        var config = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .bold)
        config = config.applying(NSImage.SymbolConfiguration(paletteColors: [textColor]))
        return NSImage(systemSymbolName: info.isCharging ? "bolt.fill" : "bolt",
                       accessibilityDescription: info.isCharging ? "Charging" : "Connected")?
            .withSymbolConfiguration(config)
    }

    private var attributed: NSAttributedString {
        NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: textColor])
    }

    // MARK: measurement

    func fittingWidth() -> CGFloat {
        var content = ceil(attributed.size().width)
        if let glyph { content += glyph.size.width + glyphGap }
        return ceil(content + sidePadding * 2)
    }

    // MARK: drawing

    override func draw(_ dirtyRect: NSRect) {
        var x = sidePadding
        let centreY = bounds.midY

        if let glyph {
            glyph.draw(in: NSRect(x: x, y: (centreY - glyph.size.height / 2).rounded(),
                                  width: glyph.size.width, height: glyph.size.height))
            x += glyph.size.width + glyphGap
        }

        let text = attributed
        let size = text.size()
        text.draw(at: NSPoint(x: x, y: (centreY - size.height / 2).rounded()))
    }

    /// Clicks belong to the status item button, which owns the menu.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
