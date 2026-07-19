import SwiftUI

enum TooLongStyle {
    static let surface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.115, alpha: 1)
            : NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.92, alpha: 1)
    })

    static let tomato = Color(red: 0.91, green: 0.28, blue: 0.18)
    static let leaf = Color(red: 0.22, green: 0.46, blue: 0.29)
    static let sunshine = Color(red: 0.98, green: 0.73, blue: 0.23)
    static let sky = Color(red: 0.32, green: 0.64, blue: 0.72)
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(
                .regular.tint(TooLongStyle.tomato).interactive(),
                in: Capsule()
            )
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded, weight: .medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassEffect(.regular.interactive(), in: Capsule())
            .brightness(configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct LiquidBackdrop: View {
    var body: some View {
        ZStack {
            Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.055, alpha: 1)
                    : NSColor(calibratedRed: 0.92, green: 0.91, blue: 0.86, alpha: 1)
            })

            LinearGradient(
                colors: [
                    TooLongStyle.leaf.opacity(0.22),
                    .clear,
                    TooLongStyle.tomato.opacity(0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(TooLongStyle.sunshine.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 54)
                .offset(x: 155, y: -235)

            Circle()
                .fill(TooLongStyle.sky.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 66)
                .offset(x: -170, y: 235)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct LiquidPanelModifier: ViewModifier {
    let tint: Color?
    let cornerRadius: CGFloat
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if let tint {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content.glassEffect(.regular.interactive(interactive), in: shape)
        }
    }
}

extension View {
    func liquidPanel(
        tint: Color? = nil,
        cornerRadius: CGFloat = 22,
        interactive: Bool = false
    ) -> some View {
        modifier(
            LiquidPanelModifier(
                tint: tint,
                cornerRadius: cornerRadius,
                interactive: interactive
            )
        )
    }
}

struct TinyWaveform: View {
    var active = false

    private let heights: [CGFloat] = [8, 15, 23, 12, 28, 18, 10, 22, 14, 7]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(index.isMultiple(of: 3) ? TooLongStyle.tomato : TooLongStyle.leaf)
                    .frame(width: 4, height: active ? height : max(5, height * 0.55))
            }
        }
        .frame(height: 30)
        .animation(.easeInOut(duration: 0.45), value: active)
    }
}
