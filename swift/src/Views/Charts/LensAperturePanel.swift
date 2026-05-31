import SwiftUI

struct LensAperturePanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let lens = model.selectedLensForApertureProfile {
                let totals = model.apertureTotals(for: lens)
                if totals.isEmpty {
                    LensApertureEmptyState(icon: "camera.metering.center.weighted.average",
                                           title: "No aperture metadata",
                                           detail: "This lens has shots in the library, but those files do not expose aperture EXIF.")
                } else {
                    ApertureDistributionChart(totals: totals,
                                              tint: model.color(for: lens),
                                              topApertures: model.topApertures(for: lens, limit: 3))
                        .frame(maxHeight: .infinity)
                }
            } else {
                LensApertureEmptyState(icon: "camera.aperture",
                                       title: "Select a lens",
                                       detail: "Click a lens in the ranking list to inspect its aperture usage distribution.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ApertureDistributionChart: View {
    let totals: [ApertureTotal]
    let tint: Color
    let topApertures: [ApertureTotal]

    var body: some View {
        let topLabels = Set(topApertures.map(\.label))

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(totals) { item in
                    let isTopAperture = topLabels.contains(item.label)
                    VStack(spacing: 8) {
                        Text("\(item.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isTopAperture ? tint : Color.secondary)

                        GeometryReader { proxy in
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))

                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(barFill(for: item, isTopAperture: isTopAperture))
                                    .frame(height: max(8, proxy.size.height * CGFloat(item.count) / CGFloat(maxCount)))
                            }
                        }
                        .frame(width: 30)

                        Text(item.label)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(isTopAperture ? tint : Color.secondary)
                            .frame(width: 42)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(width: 42)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.vertical, 4)
        }
    }

    private var maxCount: Int {
        max(totals.map(\.count).max() ?? 1, 1)
    }

    private func barFill(for item: ApertureTotal, isTopAperture: Bool) -> LinearGradient {
        LinearGradient(colors: [
            tint.opacity(isTopAperture ? 0.95 : 0.72),
            tint.opacity(isTopAperture ? 0.72 : 0.48)
        ], startPoint: .top, endPoint: .bottom)
    }
}

private struct LensApertureEmptyState: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppAccent.photo.opacity(0.82))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(AppAccent.photo.opacity(0.10))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
