# AnalysisLens

AnalysisLens 是一个原生 macOS SwiftUI 工具，用来从照片 EXIF 信息中统计镜头/设备使用频率，并按拍摄日期生成可交互的镜头使用图表。

## Screenshots

### 可视化日期

点击图表中的某一天后，X 轴会在对应柱子下方显示当天日期。

![AnalysisLens visualized date](docs/images/visualized-date.png)

### 主界面

主界面包含照片目录、分析进度、统计摘要、镜头使用图表和镜头排行。

![AnalysisLens main interface](docs/images/main-interface.png)

### 高亮镜头

点击右侧镜头列表后，左侧图表会突出对应镜头，其余镜头自动变暗。

![AnalysisLens lens highlight](docs/images/lens-highlight.png)

### 异常图片具体信息查看

点击状态行的列表图标后，可以查看 skipped / failed 文件的具体路径和原因。

![AnalysisLens issue details](docs/images/issue-details.png)

## Features

- 递归扫描照片目录，支持 `jpg`、`jpeg`、`png`、`heic`、`heif`、`tif`、`tiff`。
- 读取 EXIF `DateTimeOriginal` / `DateTimeDigitized`，必要时回退 TIFF `DateTime`。
- 读取 EXIF `LensModel` 并按镜头统计。
- iPhone / iPad 照片按设备型号归类，例如 `iPhone 15 Pro`，不再按手机焦段拆分。
- 按日期绘制堆叠柱状图，按镜头显示总量排行。
- 默认 X 轴只显示年份，点击某一天的柱子后显示当天 `月.日`。
- 点击右侧镜头列表可高亮左侧图表中对应镜头，其余镜头自动变暗。
- 点击左侧图表中的颜色块可高亮右侧对应镜头框，但不压暗图表。
- 点击状态行的列表图标可查看 skipped / failed 文件路径和原因。
- 自动跟随 macOS 浅色/深色模式。
- 使用 `Canvas` 绘制大图表，减少大量 SwiftUI 节点导致的卡顿。
- 缓存照片元数据，重复分析同一批照片时会复用有效缓存。

## Photo Path

首次启动时照片目录为空。每次点击 Analyze 后，当前分析目录会保存为下次启动时的默认目录。

## Requirements

- macOS 12.0 或更新版本。
- Apple Silicon Mac。当前 Makefile 默认构建 `arm64`。
- Xcode Command Line Tools，提供 `swiftc` 和 macOS SDK。

## Build

开发构建：

```sh
make app
```

生成的 app bundle 位于：

```text
build/AnalysisLens.app
```

发布构建：

```sh
make dist CONFIG=release
```

发布包位于：

```text
dist/AnalysisLens.app
```

DMG 打包：

```sh
make dmg CONFIG=release
```

DMG 位于：

```text
dist/AnalysisLens.dmg
```

App 图标由 `swift/resources/AppIcon.png` 和 `swift/resources/AppIconDark.png` 生成，运行时会按 macOS 浅色/深色外观切换 Dock 图标。

清理构建产物：

```sh
make clean
```

清理 Swift 模块缓存：

```sh
make clean-cache
```

## Run

```sh
make run
```

也可以直接打开：

```text
build/AnalysisLens.app
```

## Cache

Swift 模块缓存保存在项目内：

```text
.build-cache/module-cache
```

照片 EXIF 元数据缓存保存在用户缓存目录：

```text
~/Library/Caches/AnalysisLens/lens-metadata-cache-v2.json
```

缓存按文件路径、文件大小和修改时间校验。照片发生变化时会重新读取 EXIF。

## Version

Current version: `v1.2.0`
