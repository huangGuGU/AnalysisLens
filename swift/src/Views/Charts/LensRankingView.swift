import SwiftUI

struct LensRankingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.activeUsageTotals) { item in
                        LensRankRow(item: item, total: model.activeUsageTotalCount)
                    }

                    Spacer(minLength: 18)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if model.resultsSurfaceMode == .usage {
                        model.clearHighlight()
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct LensRankingHeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button(action: model.toggleUsageMode) {
                    HStack(spacing: 6) {
                        Text(model.usageMode.title)
                            .font(.system(size: 14, weight: .bold))

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(AppAccent.photo)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(model.usageMode.toggleHelp)

                Button(action: model.toggleUsageCurve) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 22)
                        .foregroundStyle(model.usageCurveEnabled ? AppAccent.lens : Color.secondary)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(model.usageCurveEnabled ? AppAccent.lens.opacity(0.16) : Color.primary.opacity(0.06))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder((model.usageCurveEnabled ? AppAccent.lens : Color.secondary).opacity(0.28), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help(model.usageCurveEnabled ? "Hide usage curve" : "Show selected usage curve")
            }
            .opacity(model.resultsSurfaceMode == .usage ? 1 : 0)
            .disabled(model.resultsSurfaceMode != .usage)
            .accessibilityHidden(model.resultsSurfaceMode != .usage)
            .frame(width: 92, alignment: .leading)

            ResultsSurfaceModePicker(selection: model.resultsSurfaceMode,
                                     apertureEnabled: model.hasLensResults,
                                     onSelect: model.setResultsSurfaceMode)
                .fixedSize()

            Spacer(minLength: 0)
        }
        .frame(height: 36)
    }
}

struct LensRankRow: View {
    @EnvironmentObject private var model: AppModel
    let item: LensTotal
    let total: Int

    var body: some View {
        Button {
            if model.resultsSurfaceMode == .aperture {
                model.highlightLensOnly(item.lens)
            } else {
                model.toggleChartHighlight(item.lens)
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.color(for: item.lens))
                        .frame(width: 9, height: 9)

                    Text(item.lens)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 8)

                    Text("\(item.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(model.color(for: item.lens))
                        .monospacedDigit()
                }

                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(model.color(for: item.lens).opacity(0.82))
                                .frame(width: max(4, proxy.size.width * CGFloat(item.count) / CGFloat(total)))
                        }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(model.highlightedLens == item.lens ? model.color(for: item.lens).opacity(0.16) : Color.clear)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(model.color(for: item.lens).opacity(model.highlightedLens == item.lens ? 0.52 : 0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
