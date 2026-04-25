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
- **Xcode 15.0** or later (for building from source)

## Installation

To permanently install the app on your Mac so it runs independently of Xcode:

1. Clone or download this repository to your local machine.
2. Open `CurrencyConverter.xcodeproj` in Xcode.
3. From the top menu bar, select **Product > Archive**.
4. When the archive finishes and the Organizer window opens, select your archive and click **Distribute App**.
5. Select **Custom**, then **Copy App**, and proceed to save the exported `CurrencyConverter.app` file.
6. Move the exported `CurrencyConverter.app` into your Mac's **Applications** (`/Applications`) folder.
7. Double-click the app from your Applications folder to launch it.

> **Troubleshooting "Damaged or Incomplete" Error**: 
> If you do not have a paid Apple Developer account, Xcode exports the app with an ad-hoc signature. macOS Gatekeeper may flag this exported app as "damaged" when you try to open it from Finder.
> To fix this, open your Terminal and run the following commands to bypass Gatekeeper and re-sign the app locally:
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

### Option 2: Using the Command Line
You can build the project from your terminal using `xcodebuild`:

```bash
# Build the project in Debug mode
xcodebuild -project CurrencyConverter.xcodeproj -scheme CurrencyConverter -configuration Debug build
```

*Note: To run the built product from the command line, you will need to locate the `.app` bundle inside Xcode's DerivedData folder (e.g., `~/Library/Developer/Xcode/DerivedData/`). For everyday use, building through Xcode and archiving it to your `Applications` folder is recommended.*

To build the app into the repository `build/` folder and create or update a symlink in `/Applications`, run:

```bash
./scripts/build_and_link.sh
```

If you want the link somewhere else, override `APP_INSTALL_DIR`, for example `APP_INSTALL_DIR="$HOME/Applications" ./scripts/build_and_link.sh`.

## Development & Testing

The repository contains the main AppKit/SwiftUI application target, alongside shared Swift logic located in `Sources/CurrencyConverterMacOS/` and unit tests in `Tests/CurrencyConverterMacOSTests/`.

To run the test suite from the terminal:
```bash
swift test
```

### Troubleshooting
If `xcodebuild` or `swift test` fails with a command line tools error, ensure your active developer directory is pointing to the full Xcode installation and not just the Command Line Tools:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
