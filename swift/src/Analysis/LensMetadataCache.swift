import Foundation

struct CachedLensMetadata: Codable {
    enum Status: String, Codable {
        case analyzed
        case missingDate
    }

    let fileSize: Int64
    let modificationTime: TimeInterval
    let status: Status
    let dayKey: String?
    let lens: String?
    let focalRange: String?
    let apertureLabel: String?
    let reason: String?
}

private struct FileFingerprint {
    let fileSize: Int64
    let modificationTime: TimeInterval
}

final class LensMetadataCache {
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

    static func clearAll() -> (removed: Int, failed: Int) {
        var removed = 0
        var failed = 0
        let fileManager = FileManager.default

        for url in cacheURLs {
            guard fileManager.fileExists(atPath: url.path) else {
                continue
            }

            do {
                try fileManager.removeItem(at: url)
                removed += 1
            } catch {
                failed += 1
            }
        }

        return (removed, failed)
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

    func storeAnalyzed(dayKey: String,
                       lens: String,
                       focalRange: String,
                       apertureLabel: String?,
                       for url: URL) -> Bool {
        guard let fingerprint = fingerprint(for: url) else {
            return false
        }
        records[url.path] = CachedLensMetadata(fileSize: fingerprint.fileSize,
                                               modificationTime: fingerprint.modificationTime,
                                               status: .analyzed,
                                               dayKey: dayKey,
                                               lens: lens,
                                               focalRange: focalRange,
                                               apertureLabel: apertureLabel,
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
                                               focalRange: nil,
                                               apertureLabel: nil,
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
        .appendingPathComponent("lens-metadata-cache-v6.json")

    private static let cacheURLs = [
        "lens-metadata-cache-v2.json",
        "lens-metadata-cache-v3.json",
        "lens-metadata-cache-v4.json",
        "lens-metadata-cache-v5.json",
        "lens-metadata-cache-v6.json"
    ].map { cacheDirectory.appendingPathComponent($0) }
}
