import AppKit
import SwiftUI

final class AppModel: ObservableObject {
    @Published var photoPath = AppModel.savedPhotoPath()
    @Published var processed = 0
    @Published var total = 0
    @Published var analyzed = 0
    @Published var skipped = 0
    @Published var failed = 0
    @Published var phase = "Ready"
    @Published var isRunning = false
    @Published var result = LensAnalysisResult()
    @Published var highlightedLens: String?
    @Published var chartHighlightedLens: String?
    @Published var selectedDayKey: String?
    @Published var highlightedDayKey: String?
    @Published var usageMode = UsageMode.lens
    @Published var usageCurveEnabled = false
    @Published var resultsSurfaceMode = ResultsSurfaceMode.usage

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

    var hasLensResults: Bool {
        !result.lensTotals.isEmpty
    }

    var activeDayUsages: [LensDayUsage] {
        switch usageMode {
        case .lens:
            return result.dayUsages
        case .focalRange:
            return result.focalRangeDayUsages
        }
    }

    var activeUsageTotals: [LensTotal] {
        switch usageMode {
        case .lens:
            return result.lensTotals
        case .focalRange:
            return result.focalRangeTotals
        }
    }

    var activeUsageNames: [String] {
        switch usageMode {
        case .lens:
            return result.lensNames
        case .focalRange:
            return result.focalRangeNames
        }
    }

    var activeUsageTotalCount: Int {
        max(1, activeUsageTotals.map(\.count).reduce(0, +))
    }

    var resultsPanelTitle: String {
        switch resultsSurfaceMode {
        case .usage:
            return usageMode.chartTitle
        case .aperture:
            return "Aperture Profile"
        }
    }

    var selectedLensForApertureProfile: String? {
        guard usageMode == .lens,
              let highlightedLens,
              result.lensNames.contains(highlightedLens) else {
            return nil
        }
        return highlightedLens
    }

    var issueCount: Int {
        result.skippedIssues.count + result.failedIssues.count
    }

    var hasIssues: Bool {
        issueCount > 0
    }

    var canAnalyze: Bool {
        AppModel.isExistingDirectory(photoPath)
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
        guard canAnalyze else {
            phase = "Choose a photo folder"
            return
        }

        let analysisPath = photoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        photoPath = analysisPath
        AppModel.savePhotoPath(analysisPath)
        isRunning = true
        processed = 0
        total = 0
        analyzed = 0
        skipped = 0
        failed = 0
        result = LensAnalysisResult()
        highlightedLens = nil
        chartHighlightedLens = nil
        selectedDayKey = nil
        highlightedDayKey = nil
        phase = "Scanning photos"

        let photoURL = URL(fileURLWithPath: analysisPath, isDirectory: true)

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
        guard let index = activeUsageNames.firstIndex(of: lens) else {
            return .secondary
        }
        return AppAccent.palette[index % AppAccent.palette.count]
    }

    func curveColor(for lens: String, kind: UsageCurveKind) -> Color {
        guard let index = activeUsageNames.firstIndex(of: lens) else {
            return kind == .longTerm ? AppAccent.lens.opacity(0.96) : AppAccent.lens.opacity(0.72)
        }

        let palette = AppAccent.curvePalettes[index % AppAccent.curvePalettes.count]
        switch kind {
        case .shortTerm:
            return palette.shortTerm
        case .longTerm:
            return palette.longTerm
        }
    }

    func toggleChartHighlight(_ lens: String) {
        if highlightedLens == lens, chartHighlightedLens == lens {
            highlightedLens = nil
            chartHighlightedLens = nil
            return
        }
        highlightedLens = lens
        chartHighlightedLens = lens
    }

    func highlightLensOnly(_ lens: String) {
        highlightedLens = lens
        chartHighlightedLens = nil
    }

    func clearHighlight() {
        highlightedLens = nil
        chartHighlightedLens = nil
    }

    func selectDay(_ dateKey: String, highlightBar: Bool) {
        selectedDayKey = dateKey
        highlightedDayKey = highlightBar ? dateKey : nil
    }

    func clearChartSelection() {
        selectedDayKey = nil
        highlightedDayKey = nil
        highlightedLens = nil
        chartHighlightedLens = nil
    }

    func toggleUsageMode() {
        usageMode = usageMode == .lens ? .focalRange : .lens
        if usageMode != .lens {
            resultsSurfaceMode = .usage
        }
        clearHighlight()
    }

    func toggleUsageCurve() {
        usageCurveEnabled.toggle()
    }

    func setResultsSurfaceMode(_ mode: ResultsSurfaceMode) {
        if mode == .aperture {
            usageMode = .lens
            if highlightedLens == nil, let firstLens = result.lensTotals.first?.lens {
                highlightLensOnly(firstLens)
            }
        }
        resultsSurfaceMode = mode
    }

    func clearMetadataCache() {
        guard !isRunning else {
            return
        }

        let result = LensAnalyzer.clearMetadataCaches()
        if result.failed > 0 {
            phase = "Cache clear failed. Removed \(result.removed), failed \(result.failed)"
        } else if result.removed > 0 {
            phase = "Cache cleared. Removed \(result.removed) file\(result.removed == 1 ? "" : "s")"
        } else {
            phase = "No cache files to clear"
        }
    }

    func apertureTotals(for lens: String) -> [ApertureTotal] {
        result.apertureTotalsByLens[lens] ?? []
    }

    func apertureMetadataCount(for lens: String) -> Int {
        apertureTotals(for: lens).map(\.count).reduce(0, +)
    }

    func totalShotCount(for lens: String) -> Int {
        result.lensTotals.first(where: { $0.lens == lens })?.count ?? 0
    }

    func favoriteAperture(for lens: String) -> ApertureTotal? {
        apertureTotals(for: lens)
            .sorted {
                if $0.count == $1.count {
                    return $0.value < $1.value
                }
                return $0.count > $1.count
            }
            .first
    }

    func apertureRangeLabel(for lens: String) -> String {
        let totals = apertureTotals(for: lens)
        guard let first = totals.first,
              let last = totals.last else {
            return "No EXIF"
        }
        return first.label == last.label ? first.label : "\(first.label) - \(last.label)"
    }

    func topApertures(for lens: String, limit: Int) -> [ApertureTotal] {
        Array(apertureTotals(for: lens)
            .sorted {
                if $0.count == $1.count {
                    return $0.value < $1.value
                }
                return $0.count > $1.count
            }
            .prefix(limit))
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

        return "\(title). Photos \(result.totalPhotos)  Lens \(result.lensTotals.count)  Days \(result.dayUsages.count)  Cache \(result.cacheHits)  Skipped \(result.skipped)  Failed \(result.failed)  \(String(format: "%.1fs", result.elapsedSeconds))"
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
        if AppModel.isExistingDirectory(path) {
            return path
        }
        return NSHomeDirectory()
    }

    private static func savedPhotoPath() -> String {
        guard let path = UserDefaults.standard.string(forKey: photoPathDefaultsKey),
              isExistingDirectory(path) else {
            return ""
        }
        return path
    }

    private static func savePhotoPath(_ path: String) {
        UserDefaults.standard.set(path, forKey: photoPathDefaultsKey)
    }

    private static func isExistingDirectory(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static let photoPathDefaultsKey = "lastAnalyzedPhotoPath"
}
