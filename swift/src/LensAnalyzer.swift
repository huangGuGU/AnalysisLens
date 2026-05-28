import Foundation
import ImageIO

struct AnalysisProgressUpdate {
    let processed: Int
    let total: Int
    let currentFile: String
}

struct LensDayUsage: Identifiable {
    let id = UUID()
    let date: Date
    let dateKey: String
    let counts: [String: Int]

    var total: Int {
        counts.values.reduce(0, +)
    }
}

struct LensTotal: Identifiable {
    let id = UUID()
    let lens: String
    let count: Int
}

struct LensIssue: Identifiable {
    let id = UUID()
    let path: String
    let reason: String
}

struct LensAnalysisResult {
    var totalPhotos = 0
    var analyzedPhotos = 0
    var skipped = 0
    var failed = 0
    var cacheHits = 0
    var cacheWrites = 0
    var dayUsages: [LensDayUsage] = []
    var lensTotals: [LensTotal] = []
    var lensNames: [String] = []
    var elapsedSeconds = 0.0
    var errors: [String] = []
    var skippedIssues: [LensIssue] = []
    var failedIssues: [LensIssue] = []
}

final class LensAnalyzer {
    private let fileManager = FileManager.default
    private let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff"]
    private let lensAliases = [
        "Sony FE PZ 16-35mm F4.0": "FE PZ 16-35mm F4 G"
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
                    if let dayKey = cached.dayKey, let lens = cached.lens {
                        recordUsage(dayKey: dayKey,
                                    lens: lens,
                                    usageByDate: &usageByDate,
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
                let key = dayKey(for: captureDate)
                recordUsage(dayKey: key,
                            lens: lens,
                            usageByDate: &usageByDate,
                            firstSeenLens: &firstSeenLens,
                            result: &result)
                if cache.storeAnalyzed(dayKey: key, lens: lens, for: photo) {
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
        result.elapsedSeconds = Date().timeIntervalSince(start)
        return result
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
                             usageByDate: inout [String: [String: Int]],
                             firstSeenLens: inout [String],
                             result: inout LensAnalysisResult) {
        if !firstSeenLens.contains(lens) {
            firstSeenLens.append(lens)
        }
        usageByDate[dayKey, default: [:]][lens, default: 0] += 1
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

        if let prefix = prefixBeforeKeyword(" back ", in: normalized, lowercased: lowercased) ??
            prefixBeforeKeyword(" front ", in: normalized, lowercased: lowercased) {
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

    private func orderedLensNames(_ firstSeenLens: [String], totals: [LensTotal]) -> [String] {
        let totalNames = Set(totals.map(\.lens))
        var ordered = firstSeenLens.filter { totalNames.contains($0) }
        for total in totals where !ordered.contains(total.lens) {
            ordered.append(total.lens)
        }
        return ordered
    }
}

enum LensAnalysisError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value):
            return value
        }
    }
}

private struct CachedLensMetadata: Codable {
    enum Status: String, Codable {
        case analyzed
        case missingDate
    }

    let fileSize: Int64
    let modificationTime: TimeInterval
    let status: Status
    let dayKey: String?
    let lens: String?
    let reason: String?
}

private struct FileFingerprint {
    let fileSize: Int64
    let modificationTime: TimeInterval
}

private final class LensMetadataCache {
    private let fileManager = FileManager.default
    private var records: [String: CachedLensMetadata]

    private init(records: [String: CachedLensMetadata]) {
        self.records = records
    }

    static func load() -> LensMetadataCache {
        guard let data = try? Data(contentsOf: cacheURL),
              let records = try? JSONDecoder().decode([String: CachedLensMetadata].self, from: data) else {
            return LensMetadataCache(records: [:])
        }
        return LensMetadataCache(records: records)
    }

    func metadata(for url: URL) -> CachedLensMetadata? {
        guard let record = records[url.path],
              let fingerprint = fingerprint(for: url),
              record.fileSize == fingerprint.fileSize,
              abs(record.modificationTime - fingerprint.modificationTime) < 0.001 else {
            return nil
        }
        return record
    }

    func storeAnalyzed(dayKey: String, lens: String, for url: URL) -> Bool {
        guard let fingerprint = fingerprint(for: url) else {
            return false
        }
        records[url.path] = CachedLensMetadata(fileSize: fingerprint.fileSize,
                                               modificationTime: fingerprint.modificationTime,
                                               status: .analyzed,
                                               dayKey: dayKey,
                                               lens: lens,
                                               reason: nil)
        return true
    }

    func storeMissingDate(reason: String, for url: URL) -> Bool {
        guard let fingerprint = fingerprint(for: url) else {
            return false
        }
        records[url.path] = CachedLensMetadata(fileSize: fingerprint.fileSize,
                                               modificationTime: fingerprint.modificationTime,
                                               status: .missingDate,
                                               dayKey: nil,
                                               lens: nil,
                                               reason: reason)
        return true
    }

    func save() {
        do {
            try fileManager.createDirectory(at: Self.cacheDirectory,
                                            withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(records)
            try data.write(to: Self.cacheURL, options: [.atomic])
        } catch {
            // Cache failures should not block analysis.
        }
    }

    private func fingerprint(for url: URL) -> FileFingerprint? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let fileSize = values.fileSize,
              let modificationDate = values.contentModificationDate else {
            return nil
        }
        return FileFingerprint(fileSize: Int64(fileSize),
                               modificationTime: modificationDate.timeIntervalSince1970)
    }

    private static let cacheDirectory = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library", isDirectory: true)
        .appendingPathComponent("Caches", isDirectory: true)
        .appendingPathComponent("AnalysisLens", isDirectory: true)

    private static let cacheURL = cacheDirectory
        .appendingPathComponent("lens-metadata-cache-v2.json")
}
