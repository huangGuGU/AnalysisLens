import Foundation

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

struct ApertureTotal: Identifiable {
    let label: String
    let value: Double
    let count: Int

    var id: String {
        label
    }
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
    var focalRangeDayUsages: [LensDayUsage] = []
    var focalRangeTotals: [LensTotal] = []
    var focalRangeNames: [String] = []
    var apertureTotalsByLens: [String: [ApertureTotal]] = [:]
    var elapsedSeconds = 0.0
    var errors: [String] = []
    var skippedIssues: [LensIssue] = []
    var failedIssues: [LensIssue] = []
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
