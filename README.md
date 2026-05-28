# AnalysisLens

AnalysisLens 是一个原生 macOS SwiftUI 工具，用来从照片 EXIF 信息中统计镜头/设备和焦段的使用频率，并按拍摄日期生成可交互的使用图表。递归扫描照片目录并缓存，支持 `jpg`、`jpeg`、`png`、`heic`、`heif`、`tif`、`tiff`。自动跟随 macOS 浅色/深色模式。

## Screenshots

### 主界面

主界面包含照片目录、分析进度、统计摘要、镜头或焦段使用图表和排行。

<img src="docs/images/main-interface.heic" alt="AnalysisLens main interface" style="zoom: 25%;" />



<img src="docs/images/focal.heic" alt="AnalysisLens main interface" style="zoom: 25%;" />

### 焦段统计

点击右侧 `Lens` 标题可以在镜头使用频率和焦段使用频率之间切换。焦段按 `10-24mm`、`24-40mm`、`41-60mm`、`61-135mm`、`135-200mm`、`201+mm` 的固定顺序展示。

### 缓存管理

点击分析控制栏里的 `Cache` 按钮可以删除本地 EXIF 元数据缓存。删除缓存不会修改照片文件，下次分析会重新读取照片元数据。

### 可视化日期

点击图表中的某一天后，X 轴会在对应柱子下方显示当天日期。

<img src="docs/images/main-interface-light.heic" alt="AnalysisLens main interface" style="zoom:25%;" />





### 高亮镜头

点击右侧镜头列表后，左侧图表会突出对应镜头，其余镜头自动变暗。

<img src="docs/images/lens-highlight.heic" alt="AnalysisLens lens highlight" style="zoom:25%;" />



### 异常图片具体信息查看

点击状态行的列表图标后，可以查看 skipped / failed 文件的具体路径和原因。

<img src="docs/images/issue-details.heic" alt="AnalysisLens issue details" style="zoom:25%;" />



## Requirements

- macOS 12.0 或更新版本。
- Apple Silicon Mac。当前 Makefile 默认构建 `arm64`。
- Xcode Command Line Tools，提供 `swiftc` 和 macOS SDK。

## Version

Current version: `v1.3.0`
