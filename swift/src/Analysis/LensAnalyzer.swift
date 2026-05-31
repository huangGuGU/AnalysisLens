import Foundation
import ImageIO

final class LensAnalyzer {
    private let fileManager = FileManager.default
    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff"]
    private let lensAliases = [
        "Sony FE PZ 16-35mm F4.0": "FE PZ 16-35mm F4 G"
    ]
    private let focalRangeNames = [
        "10-24mm",
        "25-40mm",
        "41-60mm",
        "61-135mm",
        "136-200mm",
        "201+mm"
    ]

    func run(photoDirectory: URL,
             progress: @escaping (AnalysisProgressUpdate) -> Void) -> LensAnalysisResult {
        let start = Date()
        var result = LensAnalysisResult()

        guard isDirectory(photoDirectory) else {
            recordFailed(path: photoDirectory.path,
                         reason: "Photo path is not a directory",
                         result: &result)
            return result
        }

        let photos = collectImageFiles(in: photoDirectory)
        result.totalPhotos = photos.count
        progress(AnalysisProgressUpdate(processed: 0, total: photos.count, currentFile: ""))

        var usageByDate: [String: [String: Int]] = [:]
        var focalRangeUsageByDate: [String: [String: Int]] = [:]
        var apertureUsageByLens: [String: [String: Int]] = [:]
        var firstSeenLens: [String] = []
        let cache = LensMetadataCache.load()

        for (index, photo) in photos.enumerated() {
            defer {
                progress(AnalysisProgressUpdate(processed: index + 1,
                                                total: photos.count,
                                                currentFile: photo.lastPathComponent))
            }

            if let cached = cache.metadata(for: photo) {
                switch cached.status {
                case .analyzed:
                    if let dayKey = cached.dayKey,
                       let lens = cached.lens,
                       let focalRange = cached.focalRange {
                        recordUsage(dayKey: dayKey,
                                    lens: lens,
                                    focalRange: focalRange,
                                    apertureLabel: cached.apertureLabel,
                                    usageByDate: &usageByDate,
                                    focalRangeUsageByDate: &focalRangeUsageByDate,
                                    apertureUsageByLens: &apertureUsageByLens,
                                    firstSeenLens: &firstSeenLens,
                                    result: &result)
                        result.cacheHits += 1
                        continue
                    }
                case .missingDate:
                    recordSkipped(path: photo.path,
                                  reason: cached.reason ?? "DateTimeOriginal missing",
                                  result: &result)
                    result.cacheHits += 1
                    continue
                }
            }

            do {
                let metadata = try readMetadata(from: photo)
                guard let captureDate = captureDate(from: metadata) else {
                    let reason = "DateTimeOriginal missing"
                    recordSkipped(path: photo.path, reason: reason, result: &result)
                    if cache.storeMissingDate(reason: reason, for: photo) {
                        result.cacheWrites += 1
                    }
                    continue
                }

                let lens = normalizedLensName(from: metadata)
                let focalRange = focalRangeName(from: metadata)
                let apertureLabel = apertureLabel(from: metadata)
                let key = dayKey(for: captureDate)
                recordUsage(dayKey: key,
                            lens: lens,
                            focalRange: focalRange,
                            apertureLabel: apertureLabel,
                            usageByDate: &usageByDate,
                            focalRangeUsageByDate: &focalRangeUsageByDate,
                            apertureUsageByLens: &apertureUsageByLens,
                            firstSeenLens: &firstSeenLens,
                            result: &result)
                if cache.storeAnalyzed(dayKey: key,
                                       lens: lens,
                                       focalRange: focalRange,
                                       apertureLabel: apertureLabel,
                                       for: photo) {
                    result.cacheWrites += 1
                }
            } catch {
                recordFailed(path: photo.path,
                             reason: error.localizedDescription,
                             result: &result)
            }
        }

        cache.save()
        result.dayUsages = buildDayUsages(from: usageByDate)
        result.lensTotals = buildLensTotals(from: usageByDate)
        result.lensNames = orderedLensNames(firstSeenLens, totals: result.lensTotals)
        result.focalRangeDayUsages = buildDayUsages(from: focalRangeUsageByDate)
        result.focalRangeTotals = buildFocalRangeTotals(from: focalRangeUsageByDate)
        result.focalRangeNames = result.focalRangeTotals.map(\.lens)
        result.apertureTotalsByLens = buildApertureTotalsByLens(from: apertureUsageByLens)
        result.elapsedSeconds = Date().timeIntervalSince(start)
        return result
    }

    static func clearMetadataCaches() -> (removed: Int, failed: Int) {
        LensMetadataCache.clearAll()
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func collectImageFiles(in directory: URL) -> [URL] {
        collectFiles(in: directory) { url in
            imageExtensions.contains(url.pathExtension.lowercased())
        }
    }

    private func collectFiles(in directory: URL, where predicate: (URL) -> Bool) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            if predicate(url) {
                files.append(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private func recordUsage(dayKey: String,
                             lens: String,
                             focalRange: String,
                             apertureLabel: String?,
                             usageByDate: inout [String: [String: Int]],
                             focalRangeUsageByDate: inout [String: [String: Int]],
                             apertureUsageByLens: inout [String: [String: Int]],
                             firstSeenLens: inout [String],
                             result: inout LensAnalysisResult) {
        if !firstSeenLens.contains(lens) {
            firstSeenLens.append(lens)
        }
        usageByDate[dayKey, default: [:]][lens, default: 0] += 1
        focalRangeUsageByDate[dayKey, default: [:]][focalRange, default: 0] += 1
        if let apertureLabel {
            apertureUsageByLens[lens, default: [:]][apertureLabel, default: 0] += 1
        }
        result.analyzedPhotos += 1
    }

    private func recordSkipped(path: String, reason: String, result: inout LensAnalysisResult) {
        result.skipped += 1
        result.skippedIssues.append(LensIssue(path: path, reason: reason))
        result.errors.append("\(reason): \(path)")
    }

    private func recordFailed(path: String, reason: String, result: inout LensAnalysisResult) {
        result.failed += 1
        result.failedIssues.append(LensIssue(path: path, reason: reason))
        result.errors.append("\(reason): \(path)")
    }

    private func readMetadata(from url: URL) throws -> [String: Any] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            throw LensAnalysisError.message("Cannot read metadata: \(url.path)")
        }
        return metadata
    }

    private func captureDate(from metadata: [String: Any]) -> Date? {
        let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        let candidates = [
            exif?[kCGImagePropertyExifDateTimeOriginal as String],
            exif?[kCGImagePropertyExifDateTimeDigitized as String],
            tiff?[kCGImagePropertyTIFFDateTime as String]
        ]

        for candidate in candidates {
            guard let text = candidate as? String,
                  let date = parseExifDate(text) else {
                continue
            }
            return date
        }
        return nil
    }

    private func normalizedLensName(from metadata: [String: Any]) -> String {
        let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any]

        if let model = normalizedAppleMobileDevice(from: tiff?[kCGImagePropertyTIFFModel as String]) {
            return model
        }

        let value = exif?[kCGImagePropertyExifLensModel as String] as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let model = normalizedAppleMobileDevice(from: trimmed) {
            return model
        }
        guard !trimmed.isEmpty else {
            return "Unknown"
        }
        return lensAliases[trimmed] ?? trimmed
    }

    private func focalRangeName(from metadata: [String: Any]) -> String {
        guard let focalLength = focalLength(from: metadata) else {
            return "Unknown"
        }

        if focalLength <= 24 {
            return focalRangeNames[0]
        }
        if focalLength <= 40 {
            return focalRangeNames[1]
        }
        if focalLength <= 60 {
            return focalRangeNames[2]
        }
        if focalLength <= 135 {
            return focalRangeNames[3]
        }
        if focalLength <= 200 {
            return focalRangeNames[4]
        }
        return focalRangeNames[5]
    }

    private func focalLength(from metadata: [String: Any]) -> Double? {
        let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let candidates = [
            exif?[kCGImagePropertyExifFocalLength as String],
            exif?[kCGImagePropertyExifFocalLenIn35mmFilm as String]
        ]

        for candidate in candidates {
            guard let value = numericFocalLength(from: candidate), value >= 0 else {
                continue
            }
            return value
        }
        return nil
    }

    private func apertureLabel(from metadata: [String: Any]) -> String? {
        guard let aperture = apertureValue(from: metadata), aperture > 0 else {
            return nil
        }
        return formattedAperture(aperture)
    }

    private func apertureValue(from metadata: [String: Any]) -> Double? {
        let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
        if let value = numericValue(from: exif?[kCGImagePropertyExifFNumber as String]), value > 0 {
            return value
        }
        if let apexValue = numericValue(from: exif?[kCGImagePropertyExifApertureValue as String]), apexValue > 0 {
            return pow(2.0, apexValue / 2.0)
        }
        return nil
    }

    private func numericFocalLength(from value: Any?) -> Double? {
        guard let normalized = normalizedNumericString(from: value,
                                                       removing: "mm") else {
            return nil
        }
        return parseNormalizedNumericString(normalized)
    }

    private func numericValue(from value: Any?) -> Double? {
        guard let normalized = normalizedNumericString(from: value,
                                                       removing: nil) else {
            return nil
        }
        return parseNormalizedNumericString(normalized)
    }

    private func normalizedNumericString(from value: Any?, removing unit: String?) -> String? {
        if let number = value as? NSNumber {
            return String(number.doubleValue)
        }

        guard let text = value as? String else {
            return nil
        }

        let normalizedText: String
        if let unit {
            normalizedText = text.replacingOccurrences(of: unit, with: "", options: .caseInsensitive)
        } else {
            normalizedText = text
        }

        return normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseNormalizedNumericString(_ normalized: String) -> Double? {
        if let number = Double(normalized) {
            return number
        }

        let fraction = normalized.split(separator: "/")
        if fraction.count == 2,
           let numerator = Double(fraction[0]),
           let denominator = Double(fraction[1]),
           denominator != 0 {
            return numerator / denominator
        }

        return nil
    }

    private func formattedAperture(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let nearestInteger = rounded.rounded()
        if abs(rounded - nearestInteger) < 0.05 {
            return String(format: "f/%.0f", nearestInteger)
        }
        return String(format: "f/%.1f", rounded)
    }

    private func normalizedAppleMobileDevice(from value: Any?) -> String? {
        guard let text = value as? String else {
            return nil
        }
        let normalized = normalizeWhitespace(text)
        guard !normalized.isEmpty else {
            return nil
        }

        let lowercased = normalized.lowercased()
        guard lowercased.contains("iphone") || lowercased.contains("ipad") else {
            return nil
        }

        if let prefix = prefixBeforeKeyword(" back ", in: normalized, lowercased: lowercased)
            ?? prefixBeforeKeyword(" front ", in: normalized, lowercased: lowercased) {
            return prefix
        }
        if let prefix = prefixBeforeKeyword(" camera", in: normalized, lowercased: lowercased) {
            return prefix
        }
        return normalized
    }

    private func prefixBeforeKeyword(_ keyword: String, in text: String, lowercased: String) -> String? {
        guard let range = lowercased.range(of: keyword) else {
            return nil
        }
        let offset = lowercased.distance(from: lowercased.startIndex, to: range.lowerBound)
        let endIndex = text.index(text.startIndex, offsetBy: offset)
        return String(text[..<endIndex])
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseExifDate(_ text: String) -> Date? {
        let normalized = String(text.prefix(19))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: normalized)
    }

    private func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(year).\(month).\(day)"
    }

    private func date(fromDayKey key: String) -> Date {
        let parts = key.split(separator: ".").compactMap { Int($0) }
        var components = DateComponents()
        components.year = parts.indices.contains(0) ? parts[0] : 1970
        components.month = parts.indices.contains(1) ? parts[1] : 1
        components.day = parts.indices.contains(2) ? parts[2] : 1
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func buildDayUsages(from usageByDate: [String: [String: Int]]) -> [LensDayUsage] {
        usageByDate
            .map { key, counts in
                LensDayUsage(date: date(fromDayKey: key), dateKey: key, counts: counts)
            }
            .sorted { $0.date < $1.date }
    }

    private func buildLensTotals(from usageByDate: [String: [String: Int]]) -> [LensTotal] {
        var totals: [String: Int] = [:]
        for counts in usageByDate.values {
            for (lens, count) in counts {
                totals[lens, default: 0] += count
            }
        }
        return totals
            .map { LensTotal(lens: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.lens < $1.lens
                }
                return $0.count > $1.count
            }
    }

    private func buildFocalRangeTotals(from usageByDate: [String: [String: Int]]) -> [LensTotal] {
        var totals: [String: Int] = [:]
        for counts in usageByDate.values {
            for (lens, count) in counts {
                totals[lens, default: 0] += count
            }
        }
        return totals
            .map { LensTotal(lens: $0.key, count: $0.value) }
            .sorted {
                focalRangeSortIndex(for: $0.lens) < focalRangeSortIndex(for: $1.lens)
            }
    }

    private func buildApertureTotalsByLens(from usageByLens: [String: [String: Int]]) -> [String: [ApertureTotal]] {
        var totalsByLens: [String: [ApertureTotal]] = [:]

        for (lens, counts) in usageByLens {
            totalsByLens[lens] = counts
                .compactMap { label, count in
                    guard let value = apertureSortValue(for: label) else {
                        return nil
                    }
                    return ApertureTotal(label: label, value: value, count: count)
                }
                .sorted {
                    if $0.value == $1.value {
                        return $0.count > $1.count
                    }
                    return $0.value < $1.value
                }
        }

        return totalsByLens
    }

    private func focalRangeSortIndex(for name: String) -> Int {
        focalRangeNames.firstIndex(of: name) ?? focalRangeNames.count
    }

    private func apertureSortValue(for label: String) -> Double? {
        guard label.hasPrefix("f/") else {
            return nil
        }
        return Double(label.dropFirst(2))
    }

    private func orderedLensNames(_ firstSeenLens: [String], totals: [LensTotal]) -> [String] {
        let totalNames = Set(totals.map(\.lens))
        var ordered = firstSeenLens.filter { totalNames.contains($0) }
        for total in totals where !ordered.contains(total.lens) {
            ordered.append(total.lens)
        }
        return ordered
    }
}
