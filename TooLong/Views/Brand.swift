import SwiftUI

enum TooLongStyle {
    static let background = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.045, green: 0.05, blue: 0.075, alpha: 1)
            : NSColor(calibratedRed: 0.94, green: 0.945, blue: 0.975, alpha: 1)
    })

    static let surface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.10, green: 0.105, blue: 0.145, alpha: 1)
            : NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.998, alpha: 1)
    })

    static let indigo = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.49, green: 0.46, blue: 1.0, alpha: 1)
            : NSColor(calibratedRed: 0.384, green: 0.357, blue: 1.0, alpha: 1)
    })

    static let aqua = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.20, green: 0.88, blue: 0.80, alpha: 1)
            : NSColor(calibratedRed: 0.13, green: 0.73, blue: 0.68, alpha: 1)
    })

    static let success = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 0.24, green: 0.88, blue: 0.74, alpha: 1)
            : NSColor(calibratedRed: 0.04, green: 0.47, blue: 0.40, alpha: 1)
    })

    static let danger = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.48, alpha: 1)
            : NSColor(calibratedRed: 0.76, green: 0.12, blue: 0.20, alpha: 1)
    })
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(
                .regular.tint(TooLongStyle.indigo).interactive(),
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
            .font(.callout.weight(.medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassEffect(
                .regular.tint(TooLongStyle.indigo.opacity(0.08)).interactive(),
                in: Capsule()
            )
            .brightness(configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct LiquidBackdrop: View {
    var body: some View {
        ZStack {
            TooLongStyle.background

            LinearGradient(
                colors: [
                    TooLongStyle.indigo.opacity(0.20),
                    .clear,
                    TooLongStyle.aqua.opacity(0.12),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(TooLongStyle.indigo.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 68)
                .offset(x: 170, y: -245)

            Circle()
                .fill(TooLongStyle.aqua.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 74)
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

struct AppLogoMark: View {
    var width: CGFloat

    var body: some View {
        Image("LogoMark")
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFill()
            .frame(width: width, height: width * 0.72)
            .clipped()
            .accessibilityHidden(true)
    }
}

struct TinyWaveform: View {
    var active = false

    private let heights: [CGFloat] = [8, 15, 23, 12, 28, 18, 10, 22, 14, 7]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(index.isMultiple(of: 3) ? TooLongStyle.aqua : TooLongStyle.indigo)
                    .frame(width: 4, height: active ? height : max(5, height * 0.55))
            }
        }
        .frame(height: 30)
        .animation(.easeInOut(duration: 0.45), value: active)
    }
}
