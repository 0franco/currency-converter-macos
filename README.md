# Currency Converter for macOS

<p align="center">
  <img src="media/logo.png" alt="Currency Converter logo" width="120" />
</p>

A lightweight, native macOS menu bar app that makes live currency conversion effortless.

## Features
- **Live Exchange Rates**: Uses the free exchange-rate API (`fawazahmed0/exchange-api`) for over 200 world currencies.
- **Menu Bar Integration**: Quick access to live conversions from anywhere without breaking your workflow.
- **Offline Resilience**: Caches recent successful quotes and gracefully falls back to stale data when offline or experiencing API issues.
- **Favorite Pairs**: Save your most frequently used currency pairs for quick, one-click access.
- **Instant Conversions**: Converted amounts are re-calculated locally instantly as you type.

## Preview

<p align="center">
  <img src="media/preview.png" alt="Currency Converter preview" width="400" />
</p>

## Prerequisites
- **macOS 14.0** or later
- **Xcode Command Line Tools** (minimum for building from source)
- **Xcode 15.0** or later (optional — only needed for the Xcode build path)

## Installation

### Quick Install (no Xcode required)

You only need the **Command Line Tools** — no full Xcode IDE:

```bash
# 1. Install Command Line Tools (if you haven't already)
xcode-select --install

# 2. Clone and build
git clone https://github.com/0franco/currency-converter-macos.git
cd currency-converter-macos
bash scripts/build_spm.sh
```

This builds the app via Swift Package Manager, assembles a proper `.app` bundle in
`build/CurrencyConverter.app`, and symlinks it into `/Applications`.

To install elsewhere: `APP_INSTALL_DIR="$HOME/Applications" bash scripts/build_spm.sh`

### Install via Xcode

If you have the full Xcode IDE installed:

1. Clone or download this repository.
2. Open `CurrencyConverter.xcodeproj` in Xcode.
3. From the top menu bar, select **Product > Archive**.
4. In the Organizer window, select your archive and click **Distribute App**.
5. Select **Custom**, then **Copy App**, and save the exported `CurrencyConverter.app`.
6. Move it into `/Applications`.

Alternatively, use the xcodebuild script:
```bash
bash scripts/build_and_link.sh
```

> **Troubleshooting "Damaged or Incomplete" Error**:
> Without a paid Apple Developer account, the app is ad-hoc signed. macOS Gatekeeper
> may flag it as "damaged". Fix it with:
> ```bash
> xattr -cr /Applications/CurrencyConverter.app
> codesign --force --deep --sign - /Applications/CurrencyConverter.app
> ```

## How to Build and Run (Development)

### Option 1: Using Xcode (Recommended)
1. Double-click `CurrencyConverter.xcodeproj` to open the project in Xcode.
2. Wait for the project indexer to finish.
3. Ensure the active scheme is set to **CurrencyConverter** and your Mac is selected as the run destination.
4. Press `Cmd + R` (or go to **Product > Run**).
5. Since this is a menu bar accessory app, it will **not** appear in your Dock. Look for the application icon (a circle with a dollar sign and arrows) in the top-right macOS menu bar.

### Option 2: Using the SPM Script (no Xcode required)
```bash
bash scripts/build_spm.sh
```

This uses `swift build` under the hood — only the Command Line Tools are needed.
The script assembles a proper `.app` bundle in `build/` and symlinks it into `/Applications`.

### Option 3: Using xcodebuild
Requires the full Xcode IDE:

```bash
bash scripts/build_and_link.sh
```

If you want the link somewhere else, override `APP_INSTALL_DIR`, for example `APP_INSTALL_DIR="$HOME/Applications" bash scripts/build_and_link.sh`.

## Development & Testing

The repository contains the main AppKit/SwiftUI application target, alongside shared Swift logic located in `Sources/CurrencyConverterMacOS/` and unit tests in `Tests/CurrencyConverterMacOSTests/`.

To run the test suite from the terminal:
```bash
swift test
```

### Troubleshooting

**`xcodebuild` fails with "requires Xcode" error:**
You only have Command Line Tools installed. Either install full Xcode from the App Store, or use the SPM build script (`bash scripts/build_spm.sh`) which doesn't need Xcode.

If you do have Xcode installed, point the developer tools to it:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
