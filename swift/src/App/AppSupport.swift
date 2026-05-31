import SwiftUI

struct UsageCurvePalette {
    let shortTerm: Color
    let longTerm: Color
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

    static let curvePalettes: [UsageCurvePalette] = [
        UsageCurvePalette(shortTerm: Color(red: 0.12, green: 0.54, blue: 0.92),
                          longTerm: Color(red: 0.28, green: 0.67, blue: 0.95)),
        UsageCurvePalette(shortTerm: Color(red: 0.10, green: 0.66, blue: 0.58),
                          longTerm: Color(red: 0.23, green: 0.79, blue: 0.69)),
        UsageCurvePalette(shortTerm: Color(red: 0.88, green: 0.53, blue: 0.12),
                          longTerm: Color(red: 0.97, green: 0.66, blue: 0.24)),
        UsageCurvePalette(shortTerm: Color(red: 0.55, green: 0.38, blue: 0.92),
                          longTerm: Color(red: 0.69, green: 0.52, blue: 0.98)),
        UsageCurvePalette(shortTerm: Color(red: 0.88, green: 0.30, blue: 0.44),
                          longTerm: Color(red: 0.98, green: 0.44, blue: 0.58)),
        UsageCurvePalette(shortTerm: Color(red: 0.40, green: 0.70, blue: 0.18),
                          longTerm: Color(red: 0.55, green: 0.82, blue: 0.30)),
        UsageCurvePalette(shortTerm: Color(red: 0.16, green: 0.62, blue: 0.92),
                          longTerm: Color(red: 0.30, green: 0.75, blue: 0.97)),
        UsageCurvePalette(shortTerm: Color(red: 0.82, green: 0.48, blue: 0.16),
                          longTerm: Color(red: 0.93, green: 0.61, blue: 0.28))
    ]
}

enum UsageCurveKind: CaseIterable {
    case shortTerm
    case longTerm

    var label: String {
        switch self {
        case .shortTerm:
            return "Avg 5"
        case .longTerm:
            return "Avg 30"
        }
    }

    var helpText: String {
        switch self {
        case .shortTerm:
            return "5-day average"
        case .longTerm:
            return "30-day average"
        }
    }

    var movingAverageWindow: Int {
        switch self {
        case .shortTerm:
            return 5
        case .longTerm:
            return 30
        }
    }

    var smoothingRadii: [Int] {
        switch self {
        case .shortTerm:
            return [22, 20, 18, 14]
        case .longTerm:
            return [26, 24, 20, 16]
        }
    }

    var maxAnchorCount: Int {
        switch self {
        case .shortTerm:
            return 48
        case .longTerm:
            return 64
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .shortTerm:
            return 2.1
        case .longTerm:
            return 2.8
        }
    }
}

enum UsageMode: Equatable {
    case lens
    case focalRange

    var title: String {
        switch self {
        case .lens:
            return "Lens"
        case .focalRange:
            return "Focal"
        }
    }

    var chartTitle: String {
        "\(title) Usage"
    }

    var toggleHelp: String {
        switch self {
        case .lens:
            return "Show focal length usage"
        case .focalRange:
            return "Show lens usage"
        }
    }
}

enum ResultsSurfaceMode: String, CaseIterable, Equatable {
    case usage
    case aperture

    var title: String {
        switch self {
        case .usage:
            return "Usage"
        case .aperture:
            return "Aperture"
        }
    }
}
