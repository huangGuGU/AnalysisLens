import Foundation

@main
struct AppModelRegressionTests {
    static func main() {
        testDefaultModeUsesLensData()
        testUsageModeToggleClearsHighlightAndSwitchesData()
        testChartHighlightToggleCanClearItself()
        testDaySelectionRespectsHighlightFlag()
        testClearChartSelectionResetsSelections()
        testApertureHelpersUseSelectedLens()
        testResultsSurfaceModeSwitchesToApertureAndSelectsLens()
        testUsageCurveStartsAtFirstUse()
        testUsageCurveVisibilitySkipsNearZeroLines()
        testUsageCurveTrimsTrailingNearZeroValues()
    }

    private static func testDefaultModeUsesLensData() {
        let model = AppModel()
        model.result = sampleResult()

        assert(model.usageMode == .lens, "Default mode should be lens")
        assert(model.activeUsageNames == ["Lens A", "Lens B"], "Lens mode should expose lens names")
        assert(model.activeUsageTotals.map(\.lens) == ["Lens A", "Lens B"], "Lens mode should expose lens totals")
    }

    private static func testUsageModeToggleClearsHighlightAndSwitchesData() {
        let model = AppModel()
        model.result = sampleResult()
        model.highlightedLens = "Lens A"
        model.chartHighlightedLens = "Lens A"

        model.toggleUsageMode()

        assert(model.usageMode == .focalRange, "Toggle should switch to focal mode")
        assert(model.activeUsageNames == ["25-40mm", "41-60mm"], "Focal mode should expose focal names")
        assert(model.highlightedLens == nil, "Toggle should clear highlighted lens")
        assert(model.chartHighlightedLens == nil, "Toggle should clear chart highlight")
    }

    private static func testChartHighlightToggleCanClearItself() {
        let model = AppModel()

        model.toggleChartHighlight("Lens A")
        assert(model.highlightedLens == "Lens A", "First tap should highlight the lens")
        assert(model.chartHighlightedLens == "Lens A", "First tap should highlight the chart lens")

        model.toggleChartHighlight("Lens A")
        assert(model.highlightedLens == nil, "Second tap should clear the lens highlight")
        assert(model.chartHighlightedLens == nil, "Second tap should clear the chart highlight")
    }

    private static func testDaySelectionRespectsHighlightFlag() {
        let model = AppModel()

        model.selectDay("2026.5.31", highlightBar: false)
        assert(model.selectedDayKey == "2026.5.31", "Selection should store the day key")
        assert(model.highlightedDayKey == nil, "Drag selection should not highlight the bar")

        model.selectDay("2026.5.30", highlightBar: true)
        assert(model.selectedDayKey == "2026.5.30", "Click selection should replace the day key")
        assert(model.highlightedDayKey == "2026.5.30", "Click selection should highlight the bar")
    }

    private static func testClearChartSelectionResetsSelections() {
        let model = AppModel()
        model.highlightedLens = "Lens A"
        model.chartHighlightedLens = "Lens A"
        model.selectedDayKey = "2026.5.31"
        model.highlightedDayKey = "2026.5.31"

        model.clearChartSelection()

        assert(model.highlightedLens == nil, "Clear should reset highlighted lens")
        assert(model.chartHighlightedLens == nil, "Clear should reset chart highlight")
        assert(model.selectedDayKey == nil, "Clear should reset selected day")
        assert(model.highlightedDayKey == nil, "Clear should reset highlighted day")
    }

    private static func testApertureHelpersUseSelectedLens() {
        let model = AppModel()
        model.result = sampleResult()
        model.highlightedLens = "Lens A"

        assert(model.selectedLensForApertureProfile == "Lens A", "Selected lens should drive aperture profile in lens mode")
        assert(model.apertureMetadataCount(for: "Lens A") == 3, "Lens A should expose tagged aperture shots")
        assert(model.favoriteAperture(for: "Lens A")?.label == "f/2.8", "Favorite aperture should be the most-used stop")
        assert(model.apertureRangeLabel(for: "Lens A") == "f/2.8 - f/4", "Range should reflect sorted aperture bounds")
    }

    private static func testResultsSurfaceModeSwitchesToApertureAndSelectsLens() {
        let model = AppModel()
        model.result = sampleResult()
        model.usageMode = .focalRange

        model.setResultsSurfaceMode(.aperture)

        assert(model.resultsSurfaceMode == .aperture, "Results surface should switch to aperture")
        assert(model.usageMode == .lens, "Aperture surface should force lens mode")
        assert(model.selectedLensForApertureProfile == "Lens A", "Aperture surface should preselect the first lens")
    }

    private static func testUsageCurveStartsAtFirstUse() {
        let series = UsageCurveSeries.make(counts: [0, 0, 4, 0, 2],
                                           window: 5,
                                           smoothingRadii: [])

        assert(series.startIndex == 2, "Usage curve should start at the first non-zero count")
        assert(series.values == [4, 2, 2], "Moving average should ignore leading zero-count days")

        let emptySeries = UsageCurveSeries.make(counts: [0, 0, 0],
                                                window: 5,
                                                smoothingRadii: [])
        assert(emptySeries.values.isEmpty, "Curve should not draw for unused lenses")
    }

    private static func testUsageCurveVisibilitySkipsNearZeroLines() {
        let rareVisible = UsageCurveSeries.isVisible(rawTotal: 2,
                                                     displayValues: [0.4, 0.3, 0.2],
                                                     maxTotal: 50,
                                                     chartHeight: 300)
        assert(!rareVisible, "Very rare lenses should not draw a near-zero curve")

        let usefulVisible = UsageCurveSeries.isVisible(rawTotal: 30,
                                                       displayValues: [4, 9, 5],
                                                       maxTotal: 50,
                                                       chartHeight: 300)
        assert(usefulVisible, "Visible curves with enough signal should still draw")
    }

    private static func testUsageCurveTrimsTrailingNearZeroValues() {
        let shortTail = UsageCurveSeries.trimmingTrailingNearZero(displayValues: [12, 7, 2, 0.4, 0.1],
                                                                  rawValues: [1, 1, 0, 0, 0],
                                                                  maxTotal: 60,
                                                                  chartHeight: 300)
        assert(shortTail == [12, 7, 2, 0.4, 0.1], "Curve should not trim before a long near-zero tail")

        let aboveZeroTail = UsageCurveSeries.trimmingTrailingNearZero(displayValues: [12, 7, 2, 2.2, 2.1, 2.0, 2.0, 2.0],
                                                                      rawValues: [1, 1, 0, 0, 0, 0, 0, 0],
                                                                      maxTotal: 60,
                                                                      chartHeight: 300)
        assert(aboveZeroTail == [12, 7, 2, 2.2, 2.1, 2.0, 2.0, 2.0], "Curve should not trim while the tail is still visibly above zero")

        let stillActive = UsageCurveSeries.trimmingTrailingNearZero(displayValues: [12, 7, 2, 0.4, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
                                                                    rawValues: [1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
                                                                    maxTotal: 60,
                                                                    chartHeight: 300)
        assert(stillActive == [12, 7, 2, 0.4, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1], "Curve should not trim if raw usage returns inside the tail")

        let longNearZeroTail = [12, 7, 2] + Array(repeating: 0.1, count: 52)
        let longZeroUseTail = [1, 1, 1] + Array(repeating: 0.0, count: 52)
        let expectedTrimmedTail = [12, 7, 2] + Array(repeating: 0.1, count: 48)
        let trimmed = UsageCurveSeries.trimmingTrailingNearZero(displayValues: longNearZeroTail,
                                                               rawValues: longZeroUseTail,
                                                               maxTotal: 60,
                                                               chartHeight: 300)
        assert(trimmed == expectedTrimmedTail, "Curve should keep a long near-zero tail before trimming")

        let retained = UsageCurveSeries.trimmingTrailingNearZero(displayValues: [12, 0.2, 7],
                                                                rawValues: [1, 0, 1],
                                                                maxTotal: 60,
                                                                chartHeight: 300)
        assert(retained == [12, 0.2, 7], "Intermediate dips should remain when signal returns later")
    }

    private static func sampleResult() -> LensAnalysisResult {
        LensAnalysisResult(
            totalPhotos: 4,
            analyzedPhotos: 4,
            skipped: 0,
            failed: 0,
            cacheHits: 0,
            cacheWrites: 0,
            dayUsages: [
                LensDayUsage(date: Date(timeIntervalSince1970: 0),
                             dateKey: "2026.5.30",
                             counts: ["Lens A": 2]),
                LensDayUsage(date: Date(timeIntervalSince1970: 86400),
                             dateKey: "2026.5.31",
                             counts: ["Lens A": 1, "Lens B": 1])
            ],
            lensTotals: [
                LensTotal(lens: "Lens A", count: 3),
                LensTotal(lens: "Lens B", count: 1)
            ],
            lensNames: ["Lens A", "Lens B"],
            focalRangeDayUsages: [
                LensDayUsage(date: Date(timeIntervalSince1970: 0),
                             dateKey: "2026.5.30",
                             counts: ["25-40mm": 2]),
                LensDayUsage(date: Date(timeIntervalSince1970: 86400),
                             dateKey: "2026.5.31",
                             counts: ["41-60mm": 2])
            ],
            focalRangeTotals: [
                LensTotal(lens: "25-40mm", count: 2),
                LensTotal(lens: "41-60mm", count: 2)
            ],
            focalRangeNames: ["25-40mm", "41-60mm"],
            apertureTotalsByLens: [
                "Lens A": [
                    ApertureTotal(label: "f/2.8", value: 2.8, count: 2),
                    ApertureTotal(label: "f/4", value: 4, count: 1)
                ]
            ],
            elapsedSeconds: 0,
            errors: [],
            skippedIssues: [],
            failedIssues: []
        )
    }

    private static func assert(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            Foundation.exit(1)
        }
    }
}
