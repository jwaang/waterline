import SwiftUI
import UIKit

// MARK: - Color Tokens

extension Color {
    /// App background
    static let wlBase = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1) // #111111
            : UIColor(red: 0.941, green: 0.933, blue: 0.918, alpha: 1) // #F0EEEA
    })

    /// Primary text, active fills
    static let wlInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.941, green: 0.933, blue: 0.918, alpha: 1) // #F0EEEA
            : UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1) // #111111
    })

    /// Metadata labels
    static let wlSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.604, green: 0.592, blue: 0.573, alpha: 1) // #9A9792
            : UIColor(red: 0.435, green: 0.424, blue: 0.408, alpha: 1) // #6F6C68
    })

    /// Inactive elements, borders
    static let wlTertiary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.227, green: 0.220, blue: 0.208, alpha: 1) // #3A3835
            : UIColor(red: 0.812, green: 0.796, blue: 0.776, alpha: 1) // #CFCBC6
    })

    /// Section header bands
    static let wlSectionBand = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.106, blue: 0.102, alpha: 1) // #1C1B1A
            : UIColor(red: 0.910, green: 0.906, blue: 0.890, alpha: 1) // #E8E7E3
    })

    /// Sparse threshold warnings
    static let wlWarning = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.906, green: 0.298, blue: 0.235, alpha: 1) // #E74C3C
            : UIColor(red: 0.753, green: 0.224, blue: 0.169, alpha: 1) // #C0392B
    })

    /// Inverted bottom bar
    static let wlCommandBar = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.941, green: 0.933, blue: 0.918, alpha: 1) // #F0EEEA
            : UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1) // #111111
    })

    /// Text on command bar
    static let wlCommandBarText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.067, green: 0.067, blue: 0.067, alpha: 1) // #111111
            : UIColor(red: 0.941, green: 0.933, blue: 0.918, alpha: 1) // #F0EEEA
    })
}

// MARK: - Typography

extension Font {
    /// 48pt bold — hero numerals (waterline value)
    static let wlDisplayLarge = Font.system(size: 48, weight: .bold, design: .default)
    /// 32pt bold — section hero numbers
    static let wlDisplayMedium = Font.system(size: 32, weight: .bold, design: .default)
    /// 20pt bold — screen titles
    static let wlHeadline = Font.system(size: 20, weight: .bold, design: .default)
    /// 15pt regular — body text
    static let wlBody = Font.system(size: 15, weight: .regular, design: .default)
    /// 11pt medium uppercase + tracking — labels
    static let wlTechnical = Font.system(size: 11, weight: .medium, design: .default)
    /// 11pt medium monospaced — timestamps, counts
    static let wlTechnicalMono = Font.system(size: 11, weight: .medium, design: .monospaced)
    /// 28pt bold monospaced — metric values
    static let wlNumeral = Font.system(size: 28, weight: .bold, design: .monospaced)
    /// 15pt semibold — button labels
    static let wlControl = Font.system(size: 15, weight: .semibold, design: .default)
}

// MARK: - Spacing Constants

enum WLSpacing {
    static let grid: CGFloat = 8
    static let screenMargin: CGFloat = 20
    static let sectionPadding: CGFloat = 16
    static let ruleThickness: CGFloat = 0.5
}

// MARK: - Technical Text Modifier

struct WLTechnicalStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.wlTechnical)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(Color.wlSecondary)
    }
}

extension View {
    func wlTechnical() -> some View {
        modifier(WLTechnicalStyle())
    }
}

// MARK: - Screen Modifier

struct WLScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.wlBase)
            .toolbarBackground(Color.wlBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    func wlScreen() -> some View {
        modifier(WLScreenModifier())
    }
}

// MARK: - WLRule

struct WLRule: View {
    var color: Color = .wlTertiary

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: WLSpacing.ruleThickness)
    }
}

// MARK: - WLSectionHeader

struct WLSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .wlTechnical()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, WLSpacing.screenMargin)
            .background(Color.wlSectionBand)
    }
}

// MARK: - WLHeaderBar

struct WLHeaderBar: View {
    let title: String
    var subtitle: String?
    var status: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.wlHeadline)
                .foregroundStyle(Color.wlInk)

            if let subtitle {
                Text(subtitle)
                    .wlTechnical()
            }

            Spacer()

            if let status {
                Text(status)
                    .wlTechnical()
            }
        }
        .padding(.horizontal, WLSpacing.screenMargin)
        .padding(.vertical, 12)
    }
}

// MARK: - WLActionBlock

enum WLActionStyle {
    case primary
    case secondary
}

struct WLActionBlock: View {
    let label: String
    var style: WLActionStyle = .primary
    var warningText: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.wlControl)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(backgroundColor)
                .overlay(
                    Rectangle()
                        .strokeBorder(borderColor, lineWidth: style == .secondary ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if warningText { return .wlWarning }
        switch style {
        case .primary: return .wlBase
        case .secondary: return .wlInk
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .wlInk
        case .secondary: return .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return .clear
        case .secondary: return .wlTertiary
        }
    }
}

// MARK: - WLCommandBar

struct WLCommandBar<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: WLSpacing.sectionPadding) {
            content()
        }
        .padding(.horizontal, WLSpacing.screenMargin)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.wlCommandBar)
    }
}

// MARK: - WLGridCell

struct WLGridCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.wlNumeral)
                .foregroundStyle(Color.wlInk)
            Text(label)
                .wlTechnical()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .strokeBorder(Color.wlTertiary, lineWidth: 1)
        )
    }
}

// MARK: - WLChip

struct WLChip: View {
    let label: String
    var detail: String?
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? Color.wlBase : Color.wlInk)
                if let detail {
                    Text(detail)
                        .font(.wlTechnicalMono)
                        .foregroundStyle(isActive ? Color.wlBase.opacity(0.7) : Color.wlSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? Color.wlInk : Color.clear)
            .overlay(
                Rectangle()
                    .strokeBorder(isActive ? Color.clear : Color.wlTertiary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WLGauge

struct WLGauge: View {
    let value: Double
    var warningThreshold: Int = 2

    private var isWarning: Bool { value >= Double(warningThreshold) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track
                Rectangle()
                    .fill(Color.wlSectionBand)
                    .frame(width: 56, height: 200)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.wlTertiary, lineWidth: 1)
                    )

                // Center line
                Rectangle()
                    .fill(Color.wlTertiary)
                    .frame(width: 56, height: 1)

                // Fill from center
                GeometryReader { geo in
                    let midY = geo.size.height / 2
                    let maxOffset: CGFloat = geo.size.height / 2 - 8
                    let clampedValue = min(max(value, -5), 5)
                    let fillHeight = abs(clampedValue) / 5.0 * maxOffset
                    let fillColor: Color = isWarning ? .wlWarning : .wlInk

                    Rectangle()
                        .fill(fillColor)
                        .frame(width: 40, height: fillHeight)
                        .position(
                            x: geo.size.width / 2,
                            y: value >= 0
                                ? midY - fillHeight / 2
                                : midY + fillHeight / 2
                        )
                }
                .frame(width: 56, height: 200)
                .clipped()
            }

            Text(value, format: .number.precision(.fractionLength(1)))
                .font(.wlDisplayLarge)
                .monospacedDigit()
                .foregroundStyle(isWarning ? Color.wlWarning : Color.wlInk)

            if isWarning {
                Text("WARNING: HYDRATE")
                    .wlTechnical()
                    .foregroundStyle(Color.wlWarning)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Waterline level \(value, format: .number.precision(.fractionLength(1)))"))
        .accessibilityValue(isWarning ? "Warning: drink water" : "Normal")
    }
}

// MARK: - WLToggle

struct WLToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.wlBody)
                .foregroundStyle(Color.wlInk)
            Spacer()
            Button {
                isOn.toggle()
            } label: {
                Rectangle()
                    .fill(isOn ? Color.wlInk : Color.clear)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.wlTertiary, lineWidth: 1)
                    )
                    .overlay(
                        Rectangle()
                            .fill(isOn ? Color.wlBase : Color.wlTertiary)
                            .frame(width: 16, height: 16)
                            .offset(x: isOn ? 8 : -8)
                    )
                    .frame(width: 44, height: 24)
                    .animation(.easeInOut(duration: 0.15), value: isOn)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityAddTraits(.isToggle)
        }
    }
}

// MARK: - WLStepper

struct WLStepper: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...10
    var step: Int = 1
    var displaySuffix: String = ""
    var snapStops: [Int]? = nil

    private func decrement() {
        if let stops = snapStops, let idx = stops.firstIndex(of: value), idx > 0 {
            value = stops[idx - 1]
        } else if let stops = snapStops, let lower = stops.last(where: { $0 < value }) {
            value = lower
        } else {
            let newValue = value - step
            if newValue >= range.lowerBound { value = newValue }
        }
    }

    private func increment() {
        if let stops = snapStops, let idx = stops.firstIndex(of: value), idx < stops.count - 1 {
            value = stops[idx + 1]
        } else if let stops = snapStops, let upper = stops.first(where: { $0 > value }) {
            value = upper
        } else {
            let newValue = value + step
            if newValue <= range.upperBound { value = newValue }
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.wlBody)
                .foregroundStyle(Color.wlInk)
            Spacer()
            HStack(spacing: 4) {
                Button {
                    decrement()
                } label: {
                    Text("−")
                        .font(.wlControl)
                        .foregroundStyle(value > range.lowerBound ? Color.wlInk : Color.wlTertiary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Color.wlTertiary, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text("\(value)\(displaySuffix)")
                    .font(.wlTechnicalMono)
                    .foregroundStyle(Color.wlInk)
                    .frame(minWidth: 56)
                    .padding(.horizontal, 8)
                    .frame(height: 36)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color.wlTertiary, lineWidth: 1)
                    )

                Button {
                    increment()
                } label: {
                    Text("+")
                        .font(.wlControl)
                        .foregroundStyle(value < range.upperBound ? Color.wlInk : Color.wlTertiary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Color.wlTertiary, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - WLSegmentedPicker

struct WLSegmentedPicker<T: Hashable>: View {
    let options: [(label: String, value: T)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                WLChip(
                    label: option.label,
                    isActive: selection == option.value
                ) {
                    selection = option.value
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - WLStatusFlag

struct WLStatusFlag: View {
    let text: String
    var color: Color = .wlSecondary

    init(_ text: String, color: Color = .wlSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text("[ \(text) ]")
            .font(.wlTechnical)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

// MARK: - WLDoubleStepper (for Double values)

struct WLDoubleStepper: View {
    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0.5...5.0
    var step: Double = 0.5
    var format: String = "%.1f"
    var displaySuffix: String = ""

    var body: some View {
        VStack(spacing: 8) {
            if !label.isEmpty {
                Text(label)
                    .wlTechnical()
            }
            HStack(spacing: 4) {
                Button {
                    if value > range.lowerBound { value = max(range.lowerBound, value - step) }
                } label: {
                    Text("−")
                        .font(.wlControl)
                        .foregroundStyle(value > range.lowerBound ? Color.wlInk : Color.wlTertiary)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Color.wlTertiary, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text(String(format: format, value) + displaySuffix)
                    .font(.wlNumeral)
                    .foregroundStyle(Color.wlInk)
                    .frame(minWidth: 72)
                    .frame(height: 44)

                Button {
                    if value < range.upperBound { value = min(range.upperBound, value + step) }
                } label: {
                    Text("+")
                        .font(.wlControl)
                        .foregroundStyle(value < range.upperBound ? Color.wlInk : Color.wlTertiary)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Color.wlTertiary, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
