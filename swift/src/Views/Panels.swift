import AppKit
import SwiftUI

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

                    Text(path.placeholderIfEmpty)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(path.isEmpty ? Color.secondary : Color.primary)
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
    @State private var showingIssueList = false

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
                    .disabled(model.resultsSurfaceMode != .usage || model.isRunning || !model.canAnalyze)
                    .opacity(model.resultsSurfaceMode == .usage ? 1 : 0)
                    .accessibilityHidden(model.resultsSurfaceMode != .usage)

                    LiquidProgressBar(value: model.progressFraction)
                        .frame(height: 14)

                    Text(model.percentText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }

                if model.hasIssues {
                    Button {
                        showingIssueList = true
                    } label: {
                        StatusLine(showDetailsIcon: true)
                    }
                    .buttonStyle(.plain)
                    .help("Show skipped and failed files")
                } else {
                    StatusLine(showDetailsIcon: false)
                }
            }
        }
        .frame(minHeight: 112, maxHeight: 124)
        .sheet(isPresented: $showingIssueList) {
            IssueListSheet(result: model.result)
                .frame(minWidth: 760, idealWidth: 860, minHeight: 420, idealHeight: 520)
        }
    }
}

struct StatusLine: View {
    @EnvironmentObject private var model: AppModel
    let showDetailsIcon: Bool

    var body: some View {
        HStack(spacing: 12) {
            StatusDot(active: model.isRunning,
                      warning: model.failed > 0 || model.skipped > 0)

            Text(model.phase)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if showDetailsIcon {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppAccent.warning.opacity(0.88))
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

struct IssueListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: LensAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skipped and Failed Files")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Text("Skipped \(result.skippedIssues.count)  Failed \(result.failedIssues.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(IconButtonStyle(tint: AppAccent.photo))
            }

            HStack(alignment: .top, spacing: 14) {
                IssueSection(title: "Skipped",
                             count: result.skippedIssues.count,
                             tint: AppAccent.warning,
                             issues: result.skippedIssues)

                IssueSection(title: "Failed",
                             count: result.failedIssues.count,
                             tint: Color.red.opacity(0.86),
                             issues: result.failedIssues)
            }
        }
        .padding(18)
    }
}

struct IssueSection: View {
    let title: String
    let count: Int
    let tint: Color
    let issues: [LensIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))

                Text("\(count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)

                Spacer()
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if issues.isEmpty {
                        Text("No files")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        ForEach(issues) { issue in
                            IssueRow(issue: issue, tint: tint)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
        }
    }
}

struct IssueRow: View {
    let issue: LensIssue
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(issue.reason)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)

            Text(issue.path)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
    }
}

struct ResultsPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GlassPanel(fillHeight: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Text(model.resultsPanelTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(model.resultsSurfaceMode == .usage ? AppAccent.lens : AppAccent.photo)

                        Spacer()

                        if model.resultsSurfaceMode == .usage,
                           model.usageCurveEnabled,
                           let highlightedLens = model.highlightedLens {
                            UsageCurveLegend(shortTermColor: model.curveColor(for: highlightedLens, kind: .shortTerm),
                                             longTermColor: model.curveColor(for: highlightedLens, kind: .longTerm))
                        }
                    }
                    .frame(maxWidth: .infinity)

                    LensRankingHeaderView()
                        .frame(width: 260)
                }

                HStack(alignment: .top, spacing: 16) {
                    Group {
                        if model.resultsSurfaceMode == .usage {
                            LensStackedBarChart(days: model.activeDayUsages,
                                                lensNames: model.activeUsageNames)
                        } else {
                            LensAperturePanel()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 320)

                    LensRankingView()
                        .frame(width: 260)
                }
            }
        }
    }
}

struct ResultsSurfaceModePicker: View {
    let selection: ResultsSurfaceMode
    let apertureEnabled: Bool
    let onSelect: (ResultsSurfaceMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ResultsSurfaceMode.allCases, id: \.rawValue) { mode in
                Button {
                    guard mode == .usage || apertureEnabled else {
                        return
                    }
                    onSelect(mode)
                } label: {
                    Text(mode.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(foregroundColor(for: mode))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selection == mode ? backgroundTint(for: mode).opacity(0.16) : Color.clear)
                        }
                }
                .buttonStyle(.plain)
                .disabled(mode == .aperture && !apertureEnabled)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func foregroundColor(for mode: ResultsSurfaceMode) -> Color {
        if mode == .aperture && !apertureEnabled {
            return Color.secondary.opacity(0.55)
        }
        return selection == mode ? backgroundTint(for: mode) : Color.secondary
    }

    private func backgroundTint(for mode: ResultsSurfaceMode) -> Color {
        mode == .usage ? AppAccent.lens : AppAccent.photo
    }
}

private extension String {
    var placeholderIfEmpty: String {
        isEmpty ? "Choose a photo folder" : self
    }
}
