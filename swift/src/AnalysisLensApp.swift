import AppKit
import SwiftUI

@main
struct AnalysisLensApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 920,
                       idealWidth: 980,
                       maxWidth: .infinity,
                       minHeight: 620,
                       idealHeight: 680,
                       maxHeight: .infinity)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = nil
    }
}

enum AppAccent {
    static let photo = Color(red: 0.16, green: 0.45, blue: 0.66)
    static let lens = Color(red: 0.18, green: 0.61, blue: 0.55)
    static let analyzed = Color(red: 0.12, green: 0.58, blue: 0.52)
    static let warning = Color(red: 0.85, green: 0.49, blue: 0.18)

    static let palette: [Color] = [
        Color(red: 0.16, green: 0.45, blue: 0.66),
        Color(red: 0.18, green: 0.61, blue: 0.55),
        Color(red: 0.89, green: 0.54, blue: 0.24),
        Color(red: 0.53, green: 0.41, blue: 0.70),
        Color(red: 0.79, green: 0.33, blue: 0.38),
        Color(red: 0.41, green: 0.58, blue: 0.31),
        Color(red: 0.28, green: 0.52, blue: 0.75),
        Color(red: 0.66, green: 0.47, blue: 0.31)
    ]
}

final class AppModel: ObservableObject {
    @Published var photoPath = AppModel.defaultPhotoPath()
    @Published var processed = 0
    @Published var total = 0
    @Published var analyzed = 0
    @Published var skipped = 0
    @Published var failed = 0
    @Published var phase = "Ready"
    @Published var isRunning = false
    @Published var result = LensAnalysisResult()
    @Published var highlightedLens: String?

    var progressFraction: Double {
        guard total > 0 else {
            return 0
        }
        return min(1, max(0, Double(processed) / Double(total)))
    }

    var percentText: String {
        "\(Int((progressFraction * 100).rounded()))%"
    }

    var dayCount: Int {
        result.dayUsages.count
    }

    var lensCount: Int {
        result.lensTotals.count
    }

    func choosePhotoDirectory() {
        chooseDirectory(startingAt: photoPath) { [weak self] path in
            self?.photoPath = path
        }
    }

    func run() {
        guard !isRunning else {
            return
        }

        isRunning = true
        processed = 0
        total = 0
        analyzed = 0
        skipped = 0
        failed = 0
        result = LensAnalysisResult()
        highlightedLens = nil
        phase = "Scanning photos"

        let photoURL = URL(fileURLWithPath: photoPath)

        DispatchQueue.global(qos: .userInitiated).async {
            let analyzer = LensAnalyzer()
            let output = analyzer.run(photoDirectory: photoURL) { [weak self] update in
                DispatchQueue.main.async {
                    self?.apply(update)
                }
            }

            DispatchQueue.main.async {
                self.result = output
                self.total = output.totalPhotos
                self.processed = output.totalPhotos
                self.analyzed = output.analyzedPhotos
                self.skipped = output.skipped
                self.failed = output.failed
                self.phase = self.summary(for: output)
                self.isRunning = false
            }
        }
    }

    func color(for lens: String) -> Color {
        guard let index = result.lensNames.firstIndex(of: lens) else {
            return .secondary
        }
        return AppAccent.palette[index % AppAccent.palette.count]
    }

    func toggleHighlight(_ lens: String) {
        highlightedLens = highlightedLens == lens ? nil : lens
    }

    func clearHighlight() {
        highlightedLens = nil
    }

    private func apply(_ update: AnalysisProgressUpdate) {
        total = update.total
        processed = update.processed

        if update.currentFile.isEmpty {
            phase = update.total == 0 ? "No photos found yet" : "0 / \(update.total) preparing"
        } else {
            phase = "\(update.processed) / \(update.total)  \(update.currentFile)"
        }
    }

    private func summary(for result: LensAnalysisResult) -> String {
        let title: String
        if result.failed > 0 || result.skipped > 0 {
            title = result.analyzedPhotos > 0 ? "Complete with warnings" : "Needs attention"
        } else {
            title = "Complete"
        }

        var message = "\(title). Photos \(result.totalPhotos)  Lens \(result.lensTotals.count)  Days \(result.dayUsages.count)  Cache \(result.cacheHits)  Skipped \(result.skipped)  Failed \(result.failed)  \(String(format: "%.1fs", result.elapsedSeconds))"
        if let first = result.errors.first {
            message += "  \(first)"
            if result.errors.count > 1 {
                message += "  +\(result.errors.count - 1) more"
            }
        }
        return message
    }

    private func chooseDirectory(startingAt path: String, completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.directoryURL = URL(fileURLWithPath: existingDirectoryOrFallback(path))

        panel.begin { response in
            guard response == .OK, let selected = panel.url else {
                return
            }
            completion(selected.path)
        }
    }

    private func existingDirectoryOrFallback(_ path: String) -> String {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            return path
        }
        return NSHomeDirectory()
    }

    private static func defaultPhotoPath() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let pictures = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Pictures", isDirectory: true)
        let spaced = pictures.appendingPathComponent("\(year) 照片", isDirectory: true)
        let compact = pictures.appendingPathComponent("\(year)照片", isDirectory: true)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: spaced.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return spaced.path
        }
        if FileManager.default.fileExists(atPath: compact.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return compact.path
        }
        return spaced.path
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            LiquidBackdrop()

            VStack(spacing: 14) {
                HeaderView()

                PathPanel(title: "Photo Path",
                          icon: "photo.on.rectangle",
                          path: model.photoPath,
                          action: model.choosePhotoDirectory)

                RunPanel()

                ResultsPanel()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct LiquidBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            Color(nsColor: colorScheme == .dark ? .black : .white)
                .opacity(colorScheme == .dark ? 0.26 : 0.34)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04),
                    Color.clear,
                    Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GlassPanel(padding: 14) {
            HStack(spacing: 10) {
                MetricPill(label: "Photo", value: model.total, tint: AppAccent.photo)
                MetricPill(label: "Lens", value: model.lensCount, tint: AppAccent.lens)
                MetricPill(label: "Days", value: model.dayCount, tint: AppAccent.warning)
            }
        }
        .frame(height: 72)
    }
}

struct PathPanel: View {
    let title: String
    let icon: String
    let path: String
    let action: () -> Void

    @EnvironmentObject private var model: AppModel

    var body: some View {
        GlassPanel(fillHeight: true) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppAccent.photo)
                    .frame(width: 42, height: 42)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.thinMaterial)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(AppAccent.photo.opacity(0.22), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppAccent.photo)

                    Text(path)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 18)

                Button(action: action) {
                    Label("Choose", systemImage: "folder")
                        .frame(width: 102)
                }
                .buttonStyle(IconButtonStyle(tint: AppAccent.photo))
                .disabled(model.isRunning)
            }
        }
        .frame(minHeight: 78, maxHeight: 86)
    }
}

struct RunPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GlassPanel(fillHeight: true) {
            VStack(spacing: 18) {
                HStack(spacing: 18) {
                    Button(action: model.run) {
                        Label(model.isRunning ? "Running" : "Analyze",
                              systemImage: model.isRunning ? "hourglass" : "chart.bar.xaxis")
                            .frame(width: 120)
                    }
                    .buttonStyle(IconButtonStyle(tint: AppAccent.analyzed))
                    .disabled(model.isRunning)

                    LiquidProgressBar(value: model.progressFraction)
                        .frame(height: 14)

                    Text(model.percentText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    StatusDot(active: model.isRunning,
                              warning: model.failed > 0 || model.skipped > 0)

                    Text(model.phase)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
            }
        }
        .frame(minHeight: 112, maxHeight: 124)
    }
}

struct ResultsPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GlassPanel(fillHeight: true) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Lens Usage")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppAccent.lens)

                        Spacer()
                    }

                    LensStackedBarChart(days: model.result.dayUsages,
                                        lensNames: model.result.lensNames)
                        .frame(minHeight: 260)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                LensRankingView()
                    .frame(width: 260)
            }
        }
    }
}

struct LensStackedBarChart: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    let days: [LensDayUsage]
    let lensNames: [String]

    var body: some View {
        Canvas { context, size in
            guard !days.isEmpty else {
                return
            }
            drawChart(context: &context, size: size)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.clearHighlight()
        }
        .overlay {
            if days.isEmpty {
                EmptyChartState()
            }
        }
        .animation(.easeOut(duration: 0.16), value: model.highlightedLens)
    }

    private func drawChart(context: inout GraphicsContext, size: CGSize) {
        let axisHeight: CGFloat = 54
        let chartHeight = max(1, size.height - axisHeight)
        let maxTotal = max(days.map(\.total).max() ?? 1, 1)
        let spacing = barSpacing(for: days.count)
        let availableWidth = max(1, size.width - spacing * CGFloat(max(0, days.count - 1)))
        let barWidth = max(1, availableWidth / CGFloat(max(1, days.count)))

        drawGrid(context: &context, width: size.width, height: chartHeight)

        for (index, day) in days.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            var y = chartHeight

            for lens in lensNames {
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
                context.fill(Path(rect), with: .color(model.color(for: lens).opacity(segmentOpacity(for: lens))))
            }
        }

        drawAxisLabels(context: &context,
                       chartHeight: chartHeight,
                       barWidth: barWidth,
                       spacing: spacing)
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

    private func barSpacing(for count: Int) -> CGFloat {
        if count > 60 {
            return 1
        }
        if count > 30 {
            return 2
        }
        return 4
    }

    private func segmentOpacity(for lens: String) -> Double {
        guard let highlightedLens = model.highlightedLens else {
            return 1
        }
        return highlightedLens == lens ? 1 : 0.16
    }

    private func drawAxisLabels(context: inout GraphicsContext,
                                chartHeight: CGFloat,
                                barWidth: CGFloat,
                                spacing: CGFloat) {
        let labels = axisLabels(barWidth: barWidth, spacing: spacing)
        for label in labels {
            var text = context.resolve(Text(label.text)
                .font(axisLabelFont)
            )
            text.shading = .color(Color.secondary.opacity(0.92))

            var labelContext = context
            labelContext.translateBy(x: label.x + 2, y: chartHeight + 44)
            labelContext.rotate(by: .degrees(-45))
            labelContext.draw(text, at: .zero, anchor: .topLeading)
        }
    }

    private func axisLabels(barWidth: CGFloat, spacing: CGFloat) -> [AxisLabel] {
        let buckets = monthBuckets()
        guard !buckets.isEmpty else {
            return []
        }

        let minimumLabelGap: CGFloat = 108
        var labels: [AxisLabel] = []
        var start = 0

        while start < buckets.count {
            var end = start
            let startX = xPosition(forDayIndex: buckets[start].startIndex,
                                   barWidth: barWidth,
                                   spacing: spacing)

            while end + 1 < buckets.count {
                let nextX = xPosition(forDayIndex: buckets[end + 1].startIndex,
                                      barWidth: barWidth,
                                      spacing: spacing)
                if nextX - startX >= minimumLabelGap {
                    break
                }
                end += 1
            }

            labels.append(AxisLabel(text: labelText(from: buckets[start], to: buckets[end]),
                                    x: startX))
            start = end + 1
        }

        return labels
    }

    private func monthBuckets() -> [MonthBucket] {
        var buckets: [MonthBucket] = []
        var current: (year: Int, month: Int)?
        var startIndex = 0

        for (index, day) in days.enumerated() {
            guard let yearMonth = yearMonthParts(day.dateKey) else {
                continue
            }

            if let value = current, value.year == yearMonth.year, value.month == yearMonth.month {
                continue
            }

            if let value = current {
                buckets.append(MonthBucket(year: value.year,
                                           month: value.month,
                                           startIndex: startIndex,
                                           endIndex: max(startIndex, index - 1)))
            }

            current = yearMonth
            startIndex = index
        }

        if let value = current {
            buckets.append(MonthBucket(year: value.year,
                                       month: value.month,
                                       startIndex: startIndex,
                                       endIndex: max(startIndex, days.count - 1)))
        }

        return buckets
    }

    private func labelText(from start: MonthBucket, to end: MonthBucket) -> String {
        let startYear = shortYear(start.year)
        let endYear = shortYear(end.year)
        let startMonth = englishMonth(start.month)
        let endMonth = englishMonth(end.month)

        if start.year == end.year {
            if start.month == end.month {
                return "\(startMonth) '\(startYear)"
            }
            return "\(startMonth)-\(endMonth) '\(startYear)"
        }

        return "\(startMonth) '\(startYear)-\(endMonth) '\(endYear)"
    }

    private func shortYear(_ year: Int) -> String {
        String(format: "%02d", year % 100)
    }

    private func englishMonth(_ month: Int) -> String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard (1...12).contains(month) else {
            return ""
        }
        return names[month - 1]
    }

    private var axisLabelFont: Font {
        .system(size: 10, weight: .medium, design: .rounded)
    }

    private func xPosition(forDayIndex index: Int, barWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        CGFloat(index) * (barWidth + spacing)
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

    private struct MonthBucket {
        let year: Int
        let month: Int
        let startIndex: Int
        let endIndex: Int
    }

    private struct AxisLabel {
        let text: String
        let x: CGFloat
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

struct LensRankingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lens")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppAccent.photo)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.result.lensTotals) { item in
                        LensRankRow(item: item, total: max(1, model.analyzed))
                    }

                    Spacer(minLength: 18)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.clearHighlight()
                        }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct LensRankRow: View {
    @EnvironmentObject private var model: AppModel
    let item: LensTotal
    let total: Int

    var body: some View {
        Button {
            model.toggleHighlight(item.lens)
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
