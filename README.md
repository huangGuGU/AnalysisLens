# AnalysisLens

AnalysisLens 是一个原生 macOS SwiftUI 照片分析工具。它会递归扫描照片目录，从 EXIF 里读取镜头、焦距、光圈和拍摄日期，然后生成镜头使用频率、焦段使用频率、趋势曲线和单镜头光圈分布。

应用只读取本地照片元数据，不会修改照片文件。为了加快后续分析，它会缓存已经读取过的 EXIF 结果。



### Lens Usage

`Usage` 视图按日期展示镜头使用情况。右侧列表按使用次数从多到少排列，顶部可以在 `Lens` / `Focal` 和 `Usage` / `Aperture` 之间切换。

<img src="docs/images/img_2026-05-31_15-06-24.heic" alt="AnalysisLens lens usage overview" width="900">

### 镜头高亮

点击右侧镜头列表后，左侧图表会高亮对应镜头，其他镜头自动变暗。点击图表空白处会恢复全量显示。

<img src="docs/images/img_2026-05-31_15-06-31.heic" alt="AnalysisLens highlighted lens usage" width="900">

### 日期交互

点击柱状图会在底部显示对应日期

<img src="docs/images/img_2026-05-31_15-06-54.heic" alt="AnalysisLens selected chart date" width="900">

<img src="docs/images/img_2026-05-31_15-06-59.heic" alt="AnalysisLens dragged chart date" width="900">

### Avg 5 / Avg 30 趋势线

点击右上角折线按钮后，图表会叠加平滑的 `Avg 5` 和 `Avg 30` 趋势线。选择某个镜头时显示该镜头的两条平均线；未选择镜头时，可以把多个镜头的 `Avg 30` 曲线叠加在同一区域，便于比较长期使用趋势。

<img src="docs/images/img_2026-05-31_15-06-38.heic" alt="AnalysisLens Avg 5 and Avg 30 usage curves" width="900">

### Focal Usage

点击右上角 `Lens` 可以切换到 `Focal`。焦段按固定区间展示，按使用次数重排：`10-24mm`、`25-40mm`、`41-60mm`、`61-135mm`、`136-200mm`、`201+mm`。

<img src="docs/images/img_2026-05-31_15-06-44.heic" alt="AnalysisLens focal usage curves" width="900">

### Aperture Profile

点击右上角 `Aperture` 会把左侧图表切换成光圈分布。点击不同镜头可以查看该镜头在不同光圈下的使用频率。

<img src="docs/images/img_2026-05-31_15-06-19.heic" alt="AnalysisLens aperture profile" width="900">

### 异常详情

如果扫描时出现 skipped / failed 文件，点击状态行的详情入口可以查看具体路径和原因。

<img src="docs/images/issue-details.heic" alt="AnalysisLens issue details" width="900">

## Requirements

- macOS 12.0 或更新版本。
- Apple Silicon Mac。当前 Makefile 默认构建 `arm64`。
- Xcode Command Line Tools，提供 `swiftc` 和 macOS SDK。

## Version

Current version: `v2.0.0`
