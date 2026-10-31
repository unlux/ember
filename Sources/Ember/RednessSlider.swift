import AppKit

/// "Redness" label, a slider and the percentage, sized to sit in a menu.
@MainActor
final class RednessSlider: NSView {
    private let slider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let percent = NSTextField(labelWithString: "100%")
    private let onChange: (Double) -> Void

    var value: Double {
        get { slider.doubleValue }
        set {
            slider.doubleValue = newValue
            updatePercent()
        }
    }

    init(onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))

        let label = NSTextField(labelWithString: "Redness")
        label.font = .menuFont(ofSize: 0)
        percent.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        percent.alignment = .right
        percent.textColor = .secondaryLabelColor

        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved)
        slider.controlSize = .small
        slider.setAccessibilityLabel("Redness")

        let row = NSStackView(views: [label, slider, percent])
        row.orientation = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            // 20 pt on the left lines the label up with menu item titles.
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            percent.widthAnchor.constraint(equalToConstant: 38),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func sliderMoved() {
        updatePercent()
        onChange(slider.doubleValue)
    }

    private func updatePercent() {
        percent.stringValue = "\(Int((slider.doubleValue * 100).rounded()))%"
    }
}
