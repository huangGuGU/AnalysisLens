import SwiftUI

struct GlassPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    var fillHeight = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity,
                   maxHeight: fillHeight ? CGFloat.infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.10),
                radius: 16,
                x: 0,
                y: 10
            )
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
}

struct MetricPill: View {
    let label: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(label)
                .foregroundStyle(.secondary)

            Text("\(value)")
                .foregroundStyle(tint)
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

struct LiquidProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * value

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))

                Capsule()
                    .fill(
                        LinearGradient(colors: [
                            AppAccent.photo.opacity(0.94),
                            AppAccent.lens.opacity(0.94),
                            AppAccent.analyzed.opacity(0.92)
                        ], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(0, width))
                    .shadow(color: AppAccent.lens.opacity(colorScheme == .dark ? 0.34 : 0.18), radius: 10, x: 0, y: 0)
            }
        }
        .animation(.easeOut(duration: 0.18), value: value)
    }
}

struct StatusDot: View {
    let active: Bool
    let warning: Bool

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .shadow(color: color.opacity(active ? 0.7 : 0.25), radius: active ? 8 : 2)
    }

    private var color: Color {
        if warning {
            return AppAccent.warning
        }
        return active ? AppAccent.analyzed : AppAccent.photo.opacity(0.85)
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = .accentColor
    var role: ButtonRole?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.primary.opacity(isEnabled ? 0.92 : 0.48))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(configuration: configuration))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(tint.opacity(configuration.isPressed ? 0.44 : 0.28), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.62)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if role == .destructive {
            return Color.red.opacity(configuration.isPressed ? 0.24 : 0.14)
        }
        return tint.opacity(configuration.isPressed ? 0.22 : 0.13)
    }
}

struct UsageCurveLegend: View {
    let shortTermColor: Color
    let longTermColor: Color

    var body: some View {
        HStack(spacing: 10) {
            UsageCurveLegendItem(label: UsageCurveKind.shortTerm.label,
                                 helpText: UsageCurveKind.shortTerm.helpText,
                                 color: shortTermColor,
                                 lineWidth: UsageCurveKind.shortTerm.lineWidth)

            UsageCurveLegendItem(label: UsageCurveKind.longTerm.label,
                                 helpText: UsageCurveKind.longTerm.helpText,
                                 color: longTermColor,
                                 lineWidth: UsageCurveKind.longTerm.lineWidth)
        }
    }
}

private struct UsageCurveLegendItem: View {
    let label: String
    let helpText: String
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: max(2, lineWidth))

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .help(helpText)
    }
}
