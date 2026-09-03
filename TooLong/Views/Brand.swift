import SwiftUI

// MARK: - Palette

/// Color tokens for the JetBrains-inspired redesign. Unlike the previous
/// fixed brand colors, these are resolved against the active `ColorScheme`
/// so the whole app (including a user-forced dark mode) stays consistent.
enum TooLongPalette {
    static let accent = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)

    struct Tokens {
        let bg: Color
        let washA: Color
        let washB: Color
        let washC: Color
        let hair: Color
        let dash: Color
        let ink: Color
        let ink2: Color
        let ink3: Color
    }

    static let dark = Tokens(
        bg: Color(red: 0x17 / 255, green: 0x17 / 255, blue: 0x1A / 255),
        washA: .white.opacity(0.06),
        washB: accent.opacity(0.10),
        washC: accent.opacity(0.045),
        hair: .white.opacity(0.12),
        dash: .white.opacity(0.16),
        ink: Color(red: 0xF4 / 255, green: 0xF4 / 255, blue: 0xF5 / 255),
        ink2: .white.opacity(0.62),
        ink3: .white.opacity(0.45)
    )

    static let light = Tokens(
        bg: Color(red: 0xE9 / 255, green: 0xE9 / 255, blue: 0xEC / 255),
        washA: .white.opacity(0.75),
        washB: accent.opacity(0.11),
        washC: accent.opacity(0.05),
        hair: .black.opacity(0.09),
        dash: .black.opacity(0.16),
        ink: Color(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1F / 255),
        ink2: Color(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1F / 255).opacity(0.66),
        ink3: Color(red: 0x1B / 255, green: 0x1B / 255, blue: 0x1F / 255).opacity(0.48)
    )

    static func tokens(for scheme: ColorScheme) -> Tokens {
        scheme == .dark ? dark : light
    }
}

// MARK: - Fonts

enum TooLongFont {
    /// Body copy and UI chrome: JetBrains Mono.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium: name = "JetBrainsMono-Medium"
        case .semibold: name = "JetBrainsMono-SemiBold"
        case .bold, .heavy, .black: name = "JetBrainsMono-Bold"
        default: name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: size)
    }

    /// Headline moments ("Drop the long version.", "Settings"): Space Mono.
    static func heading(_ size: CGFloat) -> Font {
        .custom("SpaceMono-Bold", size: size)
    }
}

// MARK: - Backdrop

struct LiquidBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let t = TooLongPalette.tokens(for: colorScheme)
        ZStack {
            t.bg

            LinearGradient(
                colors: [t.washA, .clear],
                startPoint: UnitPoint(x: 0.1, y: -0.1),
                endPoint: UnitPoint(x: 0.7, y: 0.46)
            )

            RadialGradient(
                colors: [t.washB, .clear],
                center: UnitPoint(x: 0.9, y: -0.06),
                startRadius: 0,
                endRadius: 340
            )

            RadialGradient(
                colors: [t.washC, .clear],
                center: UnitPoint(x: 0.04, y: 1.05),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - App logo

/// The bundled wordmark, switching automatically between the black and
/// white artwork via the asset catalog's Any/Dark appearance variants.
struct AppLogoImage: View {
    var height: CGFloat = 19

    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - Icon badge

/// The small rounded-square accent-tinted icon used to anchor the empty,
/// processing, failure, and result-header states.
///
/// Set `glass: false` when the badge already sits inside a `liquidPanel` —
/// stacking a second `.glassEffect` region on top of another one reads as
/// flat/opaque rather than liquid, and is the nested-glass composition the
/// redesign is meant to avoid. Leave it `true` for badges placed directly on
/// the backdrop, which need their own surface.
struct IconBadge: View {
    var systemImage: String
    var size: CGFloat = 60
    var cornerRadius: CGFloat = 20
    var glass: Bool = true

    var body: some View {
        let icon = Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(TooLongPalette.accent)
            .frame(width: size, height: size)

        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if glass {
            icon.glassEffect(.clear.tint(TooLongPalette.accent.opacity(0.16)), in: shape)
        } else {
            icon.background(TooLongPalette.accent.opacity(0.16), in: shape)
        }
    }
}

// MARK: - Panels

/// A single, un-nested sheet of native liquid glass. Deliberately never
/// stacked on top of another `.glassEffect` region (Apple's own materials
/// don't compose well when nested — it reads as flat/opaque instead of
/// liquid, and costs extra compositing every frame it's on screen).
private struct LiquidPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func liquidPanel(cornerRadius: CGFloat = 20) -> some View {
        modifier(LiquidPanelModifier(cornerRadius: cornerRadius))
    }
}

// Buttons and toggles use SwiftUI's native `.glass` / `.glassProminent`
// button styles and the native `.switch` toggle style directly at each call
// site — Apple's own implementations, correctly behaved on a glass surface,
// rather than a hand-rolled approximation.
