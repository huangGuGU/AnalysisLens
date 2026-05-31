import SwiftUI

struct LensStackedBarChart: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    let days: [LensDayUsage]
    let lensNames: [String]
    private let usageCurveDisplayScale = 2.8

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard !days.isEmpty else {
                    return
                }
                drawChart(context: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isDragging(value.translation) {
                            handleChartDrag(at: value.location, size: proxy.size)
                        }
                    }
                    .onEnded { value in
                        if isDragging(value.translation) {
                            handleChartDrag(at: value.location, size: proxy.size)
                        } else {
                            handleChartClick(at: value.location, size: proxy.size)
                        }
                    }
            )
        }
        .overlay {
            if days.isEmpty {
                EmptyChartState()
            }
        }
        .animation(.easeOut(duration: 0.16), value: model.chartHighlightedLens)
        .animation(.easeOut(duration: 0.16), value: model.highlightedLens)
        .animation(.easeOut(duration: 0.16), value: model.highlightedDayKey)
    }

    private func drawChart(context: inout GraphicsContext, size: CGSize) {
        let metrics = chartMetrics(for: size)
        let chartHeight = metrics.chartHeight
        let maxTotal = max(days.map(\.total).max() ?? 1, 1)
        let barWidth = metrics.barWidth

        drawGrid(context: &context, width: size.width, height: chartHeight)

        for (index, day) in days.enumerated() {
            let x = xPosition(forDayIndex: index, metrics: metrics)
            var y = chartHeight
            let barOpacity = dayOpacity(for: day)

            for lens in stackedLensNames() {
                let count = day.counts[lens] ?? 0
                guard count > 0 else {
                    continue
                }

                let height = max(2, chartHeight * CGFloat(count) / CGFloat(maxTotal))
                y -= height

                let rect = CGRect(x: x,
                                  y: max(0, y),
                                  width: barWidth,
                                  height: min(height, chartHeight))
                context.fill(Path(rect), with: .color(model.color(for: lens).opacity(barSegmentOpacity(for: lens) * barOpacity)))
            }
        }

        drawUsageCurve(context: &context, metrics: metrics)
        drawAxisLabels(context: &context, metrics: metrics)
    }

    private func drawGrid(context: inout GraphicsContext, width: CGFloat, height: CGFloat) {
        let opacity = colorScheme == .dark ? 0.10 : 0.07
        for index in 0..<3 {
            let y = height * CGFloat(index) / 3
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
            context.stroke(path, with: .color(Color.primary.opacity(opacity)), lineWidth: 1)
        }
    }

    private func handleChartClick(at location: CGPoint, size: CGSize) {
        guard let selection = chartSelection(at: location, size: size) else {
            model.clearChartSelection()
            return
        }

        if let lens = lens(at: location,
                           day: selection.day,
                           chartHeight: selection.metrics.chartHeight) {
            model.selectDay(selection.day.dateKey, highlightBar: true)
            model.highlightLensOnly(lens)
        } else {
            model.clearChartSelection()
        }
    }

    private func handleChartDrag(at location: CGPoint, size: CGSize) {
        guard let selection = chartDragSelection(at: location, size: size) else {
            model.clearChartSelection()
            return
        }

        model.selectDay(selection.day.dateKey, highlightBar: false)
        model.clearHighlight()
    }

    private func chartSelection(at location: CGPoint, size: CGSize) -> ChartSelection? {
        guard !days.isEmpty else {
            return nil
        }

        let metrics = chartMetrics(for: size)
        guard location.y >= 0, location.y <= size.height else {
            return nil
        }

        let step = metrics.barWidth + metrics.spacing
        guard step > 0 else {
            return nil
        }

        let relativeX = location.x - metrics.leadingInset
        guard relativeX >= 0 else {
            return nil
        }

        let dayIndex = Int(floor(relativeX / step))
        guard days.indices.contains(dayIndex) else {
            return nil
        }

        let barX = xPosition(forDayIndex: dayIndex, metrics: metrics)
        guard location.x >= barX, location.x <= barX + metrics.barWidth else {
            return nil
        }

        guard location.y <= metrics.chartHeight else {
            return nil
        }

        return ChartSelection(day: days[dayIndex], metrics: metrics)
    }

    private func chartDragSelection(at location: CGPoint, size: CGSize) -> ChartSelection? {
        guard !days.isEmpty else {
            return nil
        }

        let metrics = chartMetrics(for: size)
        guard location.y >= 0, location.y <= metrics.chartHeight else {
            return nil
        }

        let step = metrics.barWidth + metrics.spacing
        guard step > 0 else {
            return nil
        }

        let relativeX = location.x - metrics.leadingInset
        guard relativeX >= 0 else {
            return nil
        }

        let dayIndex = Int(floor(relativeX / step))
        guard days.indices.contains(dayIndex) else {
            return nil
        }

        return ChartSelection(day: days[dayIndex], metrics: metrics)
    }

    private func isDragging(_ translation: CGSize) -> Bool {
        abs(translation.width) > 3 || abs(translation.height) > 3
    }

    private func lens(at location: CGPoint, day: LensDayUsage, chartHeight: CGFloat) -> String? {
        let maxTotal = max(days.map(\.total).max() ?? 1, 1)
        var y = chartHeight

        for lens in stackedLensNames() {
            let count = day.counts[lens] ?? 0
            guard count > 0 else {
                continue
            }

            let height = max(2, chartHeight * CGFloat(count) / CGFloat(maxTotal))
            y -= height
            let rect = CGRect(x: 0,
                              y: max(0, y),
                              width: .greatestFiniteMagnitude,
                              height: min(height, chartHeight))
            if rect.contains(CGPoint(x: 0, y: location.y)) {
                return lens
            }
        }

        return nil
    }

    private func chartMetrics(for size: CGSize) -> ChartMetrics {
        let axisHeight: CGFloat = 54
        let sideInset: CGFloat = 22
        let chartHeight = max(1, size.height - axisHeight)
        let spacing = barSpacing(for: days.count)
        let availableWidth = max(1, size.width - sideInset * 2 - spacing * CGFloat(max(0, days.count - 1)))
        let barWidth = max(1, availableWidth / CGFloat(max(1, days.count)))
        return ChartMetrics(chartHeight: chartHeight,
                            barWidth: barWidth,
                            spacing: spacing,
                            leadingInset: sideInset,
                            trailingInset: sideInset)
    }

    private func barSpacing(for count: Int) -> CGFloat {
        if count > 60 {
            return 1
        }
        if count > 30 {
            return 2
        }
        return 4
    }

    private func barSegmentOpacity(for lens: String) -> Double {
        if model.usageCurveEnabled {
            guard let highlightedLens = model.chartHighlightedLens else {
                return 0.44
            }
            return highlightedLens == lens ? 0.72 : 0.10
        }

        guard let highlightedLens = model.chartHighlightedLens else {
            return 1
        }
        return highlightedLens == lens ? 1 : 0.16
    }

    private func dayOpacity(for day: LensDayUsage) -> Double {
        guard let highlightedDayKey = model.highlightedDayKey else {
            return 1
        }
        return highlightedDayKey == day.dateKey ? 1 : 0.22
    }

    private func drawUsageCurve(context: inout GraphicsContext, metrics: ChartMetrics) {
        guard model.usageCurveEnabled else {
            return
        }

        if let highlightedLens = model.highlightedLens,
           lensNames.contains(highlightedLens) {
            for curveKind in UsageCurveKind.allCases {
                let points = usageCurvePoints(for: highlightedLens,
                                              kind: curveKind,
                                              metrics: metrics)
                guard points.count > 1 else {
                    continue
                }

                drawCurve(path: smoothedPath(points),
                          color: model.curveColor(for: highlightedLens, kind: curveKind),
                          kind: curveKind,
                          context: &context,
                          emphasized: true)
            }
            return
        }

        for lens in lensNames {
            let points = usageCurvePoints(for: lens,
                                          kind: .longTerm,
                                          metrics: metrics)
            guard points.count > 1 else {
                continue
            }

            drawCurve(path: smoothedPath(points),
                      color: model.curveColor(for: lens, kind: .longTerm),
                      kind: .longTerm,
                      context: &context,
                      emphasized: false)
        }
    }

    private func drawCurve(path: Path,
                           color: Color,
                           kind: UsageCurveKind,
                           context: inout GraphicsContext,
                           emphasized: Bool) {
        let outlineOpacity = emphasized ? (kind == .longTerm ? 0.20 : 0.16) : 0.12
        let strokeOpacity = emphasized ? (kind == .longTerm ? 0.99 : 0.96) : 0.82
        let lineWidth = emphasized ? kind.lineWidth : max(1.6, kind.lineWidth - 0.55)
        let outlineWidth = emphasized ? lineWidth + 1.4 : lineWidth + 0.9

        context.stroke(path,
                       with: .color(curveOutlineColor.opacity(outlineOpacity)),
                       style: StrokeStyle(lineWidth: outlineWidth,
                                          lineCap: .round,
                                          lineJoin: .round))
        context.stroke(path,
                       with: .color(color.opacity(strokeOpacity)),
                       style: StrokeStyle(lineWidth: lineWidth,
                                          lineCap: .round,
                                          lineJoin: .round))
    }

    private func usageCurvePoints(for lens: String,
                                  kind: UsageCurveKind,
                                  metrics: ChartMetrics) -> [CGPoint] {
        curveAnchorPoints(smoothedTrendPoints(for: lens, kind: kind, metrics: metrics),
                          maxCount: kind.maxAnchorCount)
    }

    private func smoothedTrendPoints(for lens: String,
                                     kind: UsageCurveKind,
                                     metrics: ChartMetrics) -> [CGPoint] {
        let maxTotal = max(days.map(\.total).max() ?? 1, 1)
        let counts = days.map { Double($0.counts[lens] ?? 0) }
        let series = UsageCurveSeries.make(counts: counts,
                                           window: kind.movingAverageWindow,
                                           smoothingRadii: kind.smoothingRadii)
        let displayValues = series.values.map { value in
            min(max(value * usageCurveDisplayScale, 0), Double(maxTotal))
        }
        let drawableValues = UsageCurveSeries.trimmingTrailingNearZero(displayValues: displayValues,
                                                                       rawValues: Array(counts[series.startIndex...]),
                                                                       maxTotal: Double(maxTotal),
                                                                       chartHeight: Double(metrics.chartHeight))

        guard UsageCurveSeries.isVisible(rawTotal: counts.reduce(0, +),
                                         displayValues: drawableValues,
                                         maxTotal: Double(maxTotal),
                                         chartHeight: Double(metrics.chartHeight)) else {
            return []
        }

        return drawableValues.enumerated().map { localIndex, displayValue in
            let index = series.startIndex + localIndex
            let x = xPosition(forDayIndex: index, metrics: metrics) + metrics.barWidth / 2
            let y = metrics.chartHeight - metrics.chartHeight * CGFloat(displayValue) / CGFloat(maxTotal)
            return CGPoint(x: x, y: y)
        }
    }

    private func curveAnchorPoints(_ points: [CGPoint], maxCount: Int) -> [CGPoint] {
        guard points.count > maxCount, maxCount > 2 else {
            return points
        }

        let preservedTailCount = min(32, max(8, maxCount / 2), points.count)
        let tailStart = points.count - preservedTailCount
        let headMaxCount = max(2, maxCount - preservedTailCount)
        let stride = max(1, Int(ceil(Double(max(1, tailStart - 1)) / Double(max(1, headMaxCount - 1)))))
        var anchors: [CGPoint] = []
        anchors.reserveCapacity(maxCount)

        for index in 0..<tailStart where index % stride == 0 {
            anchors.append(points[index])
        }

        for point in points[tailStart...] where anchors.last != point {
            anchors.append(point)
        }

        return anchors
    }

    private func smoothedPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else {
            return path
        }

        path.move(to: first)
        guard points.count > 2,
              let minY = points.map(\.y).min(),
              let maxY = points.map(\.y).max() else {
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            return path
        }

        for index in 0..<(points.count - 1) {
            let previous = points[max(index - 1, 0)]
            let current = points[index]
            let next = points[index + 1]
            let following = points[min(index + 2, points.count - 1)]
            let tension: CGFloat = 0.18
            let control1 = CGPoint(x: current.x + (next.x - previous.x) * tension,
                                   y: clamp(current.y + (next.y - previous.y) * tension, minY, maxY))
            let control2 = CGPoint(x: next.x - (following.x - current.x) * tension,
                                   y: clamp(next.y - (following.y - current.y) * tension, minY, maxY))
            path.addCurve(to: next, control1: control1, control2: control2)
        }

        return path
    }

    private func clamp(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }

    private func stackedLensNames() -> [String] {
        guard let highlightedLens = model.chartHighlightedLens,
              lensNames.contains(highlightedLens) else {
            return lensNames
        }

        return [highlightedLens] + lensNames.filter { $0 != highlightedLens }
    }

    private func drawAxisLabels(context: inout GraphicsContext, metrics: ChartMetrics) {
        let labels = yearAxisLabels(metrics: metrics)
        for label in labels {
            var text = context.resolve(Text(label.text)
                .font(yearAxisFont)
            )
            text.shading = .color(Color.secondary.opacity(0.84))
            context.draw(text, at: CGPoint(x: label.x, y: metrics.chartHeight + 10), anchor: .top)
        }

        guard let selectedDayKey = model.selectedDayKey,
              let selectedIndex = days.firstIndex(where: { $0.dateKey == selectedDayKey }) else {
            return
        }

        let selectedX = xPosition(forDayIndex: selectedIndex, metrics: metrics) + metrics.barWidth / 2
        drawSelectedDayLabel(context: &context,
                             text: dayAxisLabel(selectedDayKey),
                             x: selectedX,
                             chartHeight: metrics.chartHeight)
    }

    private func drawSelectedDayLabel(context: inout GraphicsContext,
                                      text: String,
                                      x: CGFloat,
                                      chartHeight: CGFloat) {
        guard !text.isEmpty else {
            return
        }

        var tick = Path()
        tick.move(to: CGPoint(x: x, y: chartHeight + 4))
        tick.addLine(to: CGPoint(x: x, y: chartHeight + 12))
        context.stroke(tick, with: .color(AppAccent.lens.opacity(0.88)), lineWidth: 1)

        var resolved = context.resolve(Text(text)
            .font(selectedDayAxisFont)
        )
        resolved.shading = .color(AppAccent.lens)
        context.draw(resolved, at: CGPoint(x: x, y: chartHeight + 22), anchor: .top)
    }

    private func yearAxisLabels(metrics: ChartMetrics) -> [AxisLabel] {
        let buckets = yearBuckets()
        guard !buckets.isEmpty else {
            return []
        }

        return buckets.map { bucket in
            let startX = xPosition(forDayIndex: bucket.startIndex, metrics: metrics)
            return AxisLabel(text: shortYear(bucket.year),
                             x: startX + metrics.barWidth / 2)
        }
    }

    private func yearBuckets() -> [YearBucket] {
        var buckets: [YearBucket] = []
        var currentYear: Int?
        var startIndex = 0

        for (index, day) in days.enumerated() {
            guard let yearMonth = yearMonthParts(day.dateKey) else {
                continue
            }

            if currentYear == yearMonth.year {
                continue
            }

            if let year = currentYear {
                buckets.append(YearBucket(year: year,
                                          startIndex: startIndex,
                                          endIndex: max(startIndex, index - 1)))
            }

            currentYear = yearMonth.year
            startIndex = index
        }

        if let year = currentYear {
            buckets.append(YearBucket(year: year,
                                      startIndex: startIndex,
                                      endIndex: max(startIndex, days.count - 1)))
        }

        return buckets
    }

    private func shortYear(_ year: Int) -> String {
        String(format: "%02d", year % 100)
    }

    private func dayAxisLabel(_ value: String) -> String {
        let parts = value.split(separator: ".")
        guard parts.count == 3 else {
            return ""
        }
        return "\(parts[1]).\(parts[2])"
    }

    private var curveOutlineColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var yearAxisFont: Font {
        .system(size: 11, weight: .semibold, design: .rounded)
    }

    private var selectedDayAxisFont: Font {
        .system(size: 10, weight: .bold, design: .rounded)
    }

    private func xPosition(forDayIndex index: Int, metrics: ChartMetrics) -> CGFloat {
        metrics.leadingInset + CGFloat(index) * (metrics.barWidth + metrics.spacing)
    }

    private func yearMonthParts(_ value: String) -> (year: Int, month: Int)? {
        let parts = value.split(separator: ".")
        guard parts.count == 3 else {
            return nil
        }
        guard let year = Int(parts[0]), let month = Int(parts[1]) else {
            return nil
        }
        return (year, month)
    }

    private struct YearBucket {
        let year: Int
        let startIndex: Int
        let endIndex: Int
    }

    private struct AxisLabel {
        let text: String
        let x: CGFloat
    }

    private struct ChartMetrics {
        let chartHeight: CGFloat
        let barWidth: CGFloat
        let spacing: CGFloat
        let leadingInset: CGFloat
        let trailingInset: CGFloat
    }

    private struct ChartSelection {
        let day: LensDayUsage
        let metrics: ChartMetrics
    }
}

struct EmptyChartState: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppAccent.lens.opacity(0.72))

            Text("No data")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct UsageCurveSeries: Equatable {
    let startIndex: Int
    let values: [Double]
    private static let minimumRawTotal = 5.0
    private static let minimumPeakPixels = 12.0
    private static let minimumAmplitudePixels = 3.0
    private static let steadyCurveTotalAllowance = 18.0
    private static let trailingNearZeroPixels = 8.0
    private static let trailingNearZeroMinimumPoints = 48
    private static let trailingZeroUseMinimumPoints = 24

    static func make(counts: [Double], window: Int, smoothingRadii: [Int]) -> UsageCurveSeries {
        guard let startIndex = counts.firstIndex(where: { $0 > 0 }) else {
            return UsageCurveSeries(startIndex: 0, values: [])
        }

        var smoothed = movingAverages(Array(counts[startIndex...]), window: window)
        for radius in smoothingRadii {
            smoothed = smoothValues(smoothed, radius: radius)
        }

        return UsageCurveSeries(startIndex: startIndex, values: smoothed)
    }

    static func trimmingTrailingNearZero(displayValues: [Double],
                                         rawValues: [Double],
                                         maxTotal: Double,
                                         chartHeight: Double) -> [Double] {
        guard displayValues.count > 1,
              displayValues.count == rawValues.count,
              maxTotal > 0,
              chartHeight > 0 else {
            return displayValues
        }

        let threshold = maxTotal * trailingNearZeroPixels / chartHeight
        var trailingStart = displayValues.endIndex
        while trailingStart > displayValues.startIndex,
              displayValues[displayValues.index(before: trailingStart)] <= threshold {
            trailingStart = displayValues.index(before: trailingStart)
        }

        let trailingNearZeroCount = displayValues.distance(from: trailingStart, to: displayValues.endIndex)
        var zeroUseStart = rawValues.endIndex
        while zeroUseStart > rawValues.startIndex,
              rawValues[rawValues.index(before: zeroUseStart)] <= 0 {
            zeroUseStart = rawValues.index(before: zeroUseStart)
        }

        let trailingZeroUseCount = rawValues.distance(from: zeroUseStart, to: rawValues.endIndex)
        guard trailingNearZeroCount > trailingNearZeroMinimumPoints,
              trailingZeroUseCount > trailingZeroUseMinimumPoints else {
            return displayValues
        }

        let nearZeroRetainedEnd = displayValues.index(trailingStart, offsetBy: trailingNearZeroMinimumPoints)
        let zeroUseRetainedEnd = displayValues.index(zeroUseStart, offsetBy: trailingZeroUseMinimumPoints)
        let retainedEnd = max(nearZeroRetainedEnd, zeroUseRetainedEnd)
        return Array(displayValues[..<retainedEnd])
    }

    static func isVisible(rawTotal: Double,
                          displayValues: [Double],
                          maxTotal: Double,
                          chartHeight: Double) -> Bool {
        guard rawTotal >= minimumRawTotal,
              displayValues.count > 1,
              maxTotal > 0,
              chartHeight > 0,
              let maxDisplay = displayValues.max(),
              let minDisplay = displayValues.min() else {
            return false
        }

        let peakPixels = chartHeight * maxDisplay / maxTotal
        let amplitudePixels = chartHeight * (maxDisplay - minDisplay) / maxTotal
        guard peakPixels >= minimumPeakPixels else {
            return false
        }

        return amplitudePixels >= minimumAmplitudePixels || rawTotal >= steadyCurveTotalAllowance
    }

    private static func movingAverages(_ values: [Double], window: Int) -> [Double] {
        guard window > 1 else {
            return values
        }

        var averages: [Double] = []
        averages.reserveCapacity(values.count)

        for index in values.indices {
            let start = max(values.startIndex, index - window + 1)
            let slice = values[start...index]
            averages.append(slice.reduce(0, +) / Double(slice.count))
        }

        return averages
    }

    private static func smoothValues(_ values: [Double], radius: Int) -> [Double] {
        guard values.count > 2, radius > 0 else {
            return values
        }

        return values.indices.map { index in
            let lowerBound = max(values.startIndex, index - radius)
            let upperBound = min(values.index(before: values.endIndex), index + radius)
            var weightedTotal = 0.0
            var weightTotal = 0.0

            for valueIndex in lowerBound...upperBound {
                let distance = abs(valueIndex - index)
                let weight = Double(radius + 1 - distance)
                weightedTotal += values[valueIndex] * weight
                weightTotal += weight
            }

            return weightTotal > 0 ? weightedTotal / weightTotal : values[index]
        }
    }
}
