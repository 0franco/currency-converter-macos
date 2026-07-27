# macOS 货币转换器 (Currency Converter)

<p align="center">
  <img src="media/banner.png" alt="Currency Converter logo" width="1200" />
</p>

一款轻量级的原生 macOS 菜单栏应用，让实时货币兑换变得毫不费力。

## 功能特性

- **实时汇率**：使用免费的汇率 API (`fawazahmed0/exchange-api`)，支持全球 200 多种货币。
- **菜单栏集成**：无需中断工作流，即可在任何位置快速访问实时兑换。
- **离线韧性**：缓存最近成功的汇率报价，并在离线或 API 出现问题时优雅地回退到旧数据。
- **收藏货币对**：保存最常用的货币对，实现一键快速访问。
- **即时转换**：输入金额时，转换结果会立即在本地重新计算。

## 预览

<p align="center">
  <img src="media/preview.png" alt="Currency Converter preview" width="400" />
</p>

## 发行说明

本项目不通过 Mac App Store 分发。由于 Apple 的发布流程对于这样一个小工具来说过于繁琐，因此推荐的安装方式是通过源码在本地构建。

最简单的安装路径是使用 Swift Package Manager (SPM)：

```bash
bash scripts/build_spm.sh
```

该脚本将在 `build/CurrencyConverter.app` 创建一个标准的 `.app` 包，并将其链接到 `/Applications` 文件夹中。

## 安装指南

### 环境要求

- **macOS 14.0** 或更高版本
- **Xcode Command Line Tools**（从源码构建的最低要求）
- **Xcode 15.0** 或更高版本（可选 —— 仅在使用 Xcode 构建路径时需要）

### 快速安装

你只需要安装 **Command Line Tools**，无需安装完整的 Xcode IDE：

```bash
# 1. 安装 Command Line Tools (如果尚未安装)
xcode-select --install

# 2. 克隆并构建
git clone https://github.com/0franco/currency-converter-macos.git
cd currency-converter-macos
bash scripts/build_spm.sh
```

这将通过 Swift Package Manager 构建应用，在 `build/CurrencyConverter.app` 中组装一个正式的 `.app` 包，并将其符号链接到 `/Applications`。

如需安装到其他位置：

```bash
APP_INSTALL_DIR="$HOME/Applications" bash scripts/build_spm.sh
```

### 启动应用

Currency Converter 是一款菜单栏应用，因此不会出现在 Dock 中。启动后，请在 macOS 顶部的菜单栏中寻找应用图标。

```bash
open build/CurrencyConverter.app
```

## 开发指南

本仓库包含 AppKit/SwiftUI 应用目标、位于 `Sources/CurrencyConverterMacOS/` 的共享 Swift 逻辑，以及位于 `Tests/CurrencyConverterMacOSTests/` 的单元测试。

### 使用 Xcode 运行

1. 双击 `CurrencyConverter.xcodeproj` 在 Xcode 中打开项目。
2. 等待项目索引完成。
3. 确保活动 Scheme 设置为 **CurrencyConverter**，并且选择了你的 Mac 作为运行目标。
4. 按 `Cmd + R` 或选择 **Product > Run**。

### 使用 Swift Package Manager 构建

这是推荐的非 Xcode 构建路径：

```bash
bash scripts/build_spm.sh
```

该脚本在底层调用 `swift build`，在 `build/` 目录下组装 `.app` 包，并将其链接到 `/Applications`。

常用覆盖参数：

```bash
CONFIGURATION=debug bash scripts/build_spm.sh
APP_INSTALL_DIR="$HOME/Applications" bash scripts/build_spm.sh
```

### 使用 xcodebuild 构建

需要安装完整的 Xcode IDE：

```bash
bash scripts/build_and_link.sh
```

如需链接到其他位置：

```bash
APP_INSTALL_DIR="$HOME/Applications" bash scripts/build_and_link.sh
```

### 使用 Xcode 归档 (Archive)

如果你安装了完整的 Xcode IDE：

1. 克隆或下载本仓库。
2. 在 Xcode 中打开 `CurrencyConverter.xcodeproj`。
3. 从顶部菜单栏选择 **Product > Archive**。
4. 在 Organizer 窗口中，选择你的归档文件并点击 **Distribute App**。
5. 选择 **Custom**，然后选择 **Copy App**，保存导出的 `CurrencyConverter.app`。
6. 将其移动到 `/Applications`。

## 测试

在终端运行测试套件：

```bash
swift test
```

## 故障排除

**`xcodebuild` 报错 "requires Xcode"：**
这说明你只安装了 Command Line Tools。请从 App Store 安装完整的 Xcode，或者使用 SPM 构建脚本 (`bash scripts/build_spm.sh`)，后者不需要 Xcode。

如果你已经安装了 Xcode，请将开发工具路径指向它：
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**Swift 工具版本不匹配：**
如果你看到 Swift 工具版本错误，请按照 macOS 官方指南更新 Swift：
[swift.org/install/macos](https://www.swift.org/install/macos/)
