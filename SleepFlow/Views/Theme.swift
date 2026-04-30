import SwiftUI

enum Theme {
    static let bgDeep      = Color(red: 0.04, green: 0.06, blue: 0.13)
    static let bgMid       = Color(red: 0.09, green: 0.12, blue: 0.24)
    static let bgEdge      = Color(red: 0.16, green: 0.13, blue: 0.34)
    static let cardBg      = Color.white.opacity(0.06)
    static let cardBorder  = Color.white.opacity(0.10)
    static let primary     = Color(red: 0.39, green: 0.40, blue: 0.95)   // #6366F1
    static let primarySoft = Color(red: 0.67, green: 0.71, blue: 0.99)
    static let success     = Color(red: 0.13, green: 0.77, blue: 0.37)
    static let danger      = Color(red: 0.94, green: 0.27, blue: 0.27)
    static let warning     = Color(red: 0.98, green: 0.71, blue: 0.20)
    static let heart       = Color(red: 0.94, green: 0.30, blue: 0.51)
    static let textPrimary = Color.white
    static let textSecond  = Color.white.opacity(0.65)
    static let textTertiary = Color.white.opacity(0.40)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.bgDeep, Theme.bgMid, Theme.bgEdge, Theme.bgDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Theme.primary.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )
            RadialGradient(
                colors: [Color.purple.opacity(0.15), .clear],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 24
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}

struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.primary
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(tint)
            )
            .shadow(color: tint.opacity(0.45), radius: 18, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct LabelChip: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.primarySoft)
            Text(title).foregroundStyle(Theme.textSecond)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

struct ProgressBar: View {
    let value: Double      // 0...1
    var tint: Color = Theme.primary

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.6)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * CGFloat(max(0, min(1, value)))))
                    .animation(.easeInOut(duration: 0.6), value: value)
            }
        }
        .frame(height: 10)
    }
}

struct PulsingHeart: View {
    @State private var scale: CGFloat = 1
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(Theme.heart)
            .shadow(color: Theme.heart.opacity(0.6), radius: 16)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    scale = 1.12
                }
            }
    }
}
