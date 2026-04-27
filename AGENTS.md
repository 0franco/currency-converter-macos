# AGENTS.md — Currency Converter macOS

> Follow this file at the start of every session. It is the authoritative guide for
> navigating, building, and extending this codebase.

---

## Project Overview

A lightweight macOS menu bar app that shows a live currency conversion popover. The
user enters an amount, picks source/target currencies, and immediately sees a converted
result fetched from a free, no-auth exchange-rate CDN.

**Platform:** macOS 14+ (Sonoma)  
**Language:** Swift 6 (strict concurrency)  
**UI framework:** SwiftUI (popover) + AppKit (status bar item)  
**Exchange-rate API:** [`fawazahmed0/exchange-api`](https://github.com/fawazahmed0/exchange-api) — free, no key needed

---

## Repository Layout

```
.
├── CurrencyConverter/               # macOS app target (AppKit entry point + SwiftUI views)
│   ├── CurrencyConverterApp.swift   # @main entry point
│   ├── AppComposition.swift         # Wires stores + ViewModel; injected at startup
│   ├── MenuBarView.swift            # Root SwiftUI view rendered inside the popover
│   └── Info.plist
│
├── Sources/CurrencyConverterMacOS/  # Framework target — all domain logic lives here
│   ├── CurrencyConversionViewModel.swift  # @MainActor ObservableObject; all UI state
│   ├── CurrencySelection.swift            # CurrencySelectionState + CurrencyConversionContext
│   ├── CurrencyCatalog.swift              # Locale-derived currency list; CurrencyCatalogProviding
│   ├── FavoriteCurrencyPair.swift         # Value type (Codable, Hashable, Identifiable)
│   ├── FavoriteCurrencyPairStore.swift    # UserDefaults persistence for favorites
│   └── QuoteCacheStore.swift              # UserDefaults cache of latest successful quote per pair
│
├── Tests/CurrencyConverterMacOSTests/
│   ├── CurrencyCatalogTests.swift
│   └── FavoriteCurrencyPairStoreTests.swift
│
├── project.yml          # XcodeGen spec — source of truth for the Xcode project
├── Package.swift        # SPM manifest — library + executable targets
├── scripts/
│   ├── build_and_link.sh  # Release build via xcodebuild (requires full Xcode)
│   └── build_spm.sh       # Release build via swift build (Command Line Tools only)
```

---

## Architecture — Critical Rules

The codebase enforces a strict layer separation. **Never collapse these layers.**

| Layer | Files | Allowed to import |
|---|---|---|
| App | `CurrencyConverter/` | `CurrencyConverterMacOS`, SwiftUI, AppKit |
| Domain / State | `Sources/CurrencyConverterMacOS/` | Foundation, Combine only |
| Tests | `Tests/` | `CurrencyConverterMacOS`, XCTest |

**Do not:**
- Put fetch or persistence logic inside `MenuBarView`.
- Put SwiftUI types inside `Sources/CurrencyConverterMacOS/`.
- Add a third-party dependency without discussing it first — the project is
  intentionally zero-dependency.

**Do:**
- Add new domain types to `Sources/CurrencyConverterMacOS/`.
- Add new views or AppKit wiring to `CurrencyConverter/`.
- Keep `AppComposition.swift` as the only place that constructs real stores and
  injects them into the ViewModel.

---

## Key Types

### `CurrencyConversionViewModel` (`CurrencyConversionViewModel.swift`)

`@MainActor` `ObservableObject`. The single source of truth for all UI state.

| Published property | Meaning |
|---|---|
| `sourceCode` / `targetCode` | Selected ISO currency codes (uppercase) |
| `sourceAmountText` | User-entered text (sanitised; always valid or empty) |
| `currentQuote: CurrencyQuote?` | Most recent successful quote for the active pair |
| `isRefreshing: Bool` | Network request in-flight |
| `isStale: Bool` | Current quote is from cache, not a fresh fetch |
| `refreshErrorMessage: String?` | User-visible error or stale warning |
| `favoritePairs: Set<FavoriteCurrencyPair>` | Active favorite pairs |

Important computed properties: `convertedAmountText`, `conversionSummaryText`,
`isCurrentPairFavorite`, `parsedAmount`, `convertedAmount`.

Public mutating methods: `updateSourceAmount(_:)`, `selectSourceCurrency(code:)`,
`selectTargetCurrency(code:)`, `swapCurrencies()`, `requestRefresh()`,
`toggleCurrentFavoritePair()`, `removeFavoritePair(_:)`.

The ViewModel is dependency-injected at init via:
- `quoteLoader: (CurrencyConversionContext) async throws -> QuoteLoadResult`
- `favoritePairsChanged: (Set<FavoriteCurrencyPair>) -> Void`
- `refreshAction: () async -> Void`

Pass mock closures in tests. Never call `LiveExchangeRateProvider` directly from tests.

### `LiveExchangeRateProvider` (inside `CurrencyConversionViewModel.swift`)

Stateless `enum`. Fetches from two CDN hosts with retry:
- Primary: `cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/{code}.json`
- Fallback: `latest.currency-api.pages.dev/v1/currencies/{code}.json`

`retryCount` defaults to `2` (attempts each host up to 3 times total). Same-currency
pair short-circuits to rate `1` without a network call.

**Response shape:**
```json
{ "date": "2026-04-24", "eur": { "usd": 1.13, "cny": 8.20 } }
```

### `QuoteLoadResult`

```swift
enum QuoteLoadResult {
    case fresh(CurrencyQuote)
    case stale(CurrencyQuote, warning: String)
}
```

The `AppComposition` closure catches network errors, falls back to `QuoteCacheStore`,
and returns `.stale(...)` if a cached quote exists, or re-throws if none.

### `CurrencySelectionState` (`CurrencySelection.swift`)

Value type. Owns `supportedCurrencies`, `featuredCurrencies`, `sourceCode`,
`targetCode`. Defaults to USD → EUR on first launch (first two of
`CurrencyCatalog.live.defaultPreselectedCodes`). All selection mutations go through
the ViewModel, which copies and re-applies the state.

### `FavoriteCurrencyPair` (`FavoriteCurrencyPair.swift`)

`Codable, Hashable, Identifiable`. `id` is derived from `"<source>-<target>"`.
Equality is code-pair equality (case-insensitive at construction, stored uppercase).

### `FavoriteCurrencyPairStore` (`FavoriteCurrencyPairStore.swift`)

Reads/writes `[FavoriteCurrencyPair]` to `UserDefaults` under a fixed key.
`loadFavoritePairs() -> [FavoriteCurrencyPair]`  
`saveFavoritePairs(_ pairs: [FavoriteCurrencyPair]) throws`

### `QuoteCacheStore` (`QuoteCacheStore.swift`)

Reads/writes `CurrencyQuote` per pair to `UserDefaults`.
`loadQuote(for pair: FavoriteCurrencyPair) -> CurrencyQuote?`  
`saveQuote(_ quote: CurrencyQuote) throws`

---

## Build System

The project supports **two build paths**:

### 1. SPM build (no Xcode required)

`Package.swift` defines both the `CurrencyConverterMacOS` library and a
`CurrencyConverterApp` executable target. The SPM build script assembles a proper
`.app` bundle from the `swift build` output.

```bash
bash scripts/build_spm.sh
```

| Variable | Default | Purpose |
|---|---|---|
| `CONFIGURATION` | `release` | `debug` or `release` |
| `BUILD_DIR` | `./build` | Output directory for the `.app` bundle |
| `APP_INSTALL_DIR` | `/Applications` | Symlink destination |

### 2. xcodebuild (requires full Xcode IDE)

The **XcodeGen** spec (`project.yml`) generates `CurrencyConverter.xcodeproj`.

**Regenerate the Xcode project after editing `project.yml`:**
```bash
xcodegen generate
```

**Build and install:**
```bash
bash scripts/build_and_link.sh
```

| Variable | Default | Purpose |
|---|---|---|
| `CONFIGURATION` | `Release` | `Debug` or `Release` |
| `BUILD_DIR` | `./build` | Output directory for the `.app` bundle |
| `APP_INSTALL_DIR` | `/Applications` | Symlink destination |
| `ARCHITECTURE` | `uname -m` | `arm64` or `x86_64` |
| `QUIET_BUILD` | `1` | Set `0` for full xcodebuild output |
| `KEEP_DERIVED_DATA` | `0` | Set `1` to keep derived data after build |

### Unit tests (both paths)

```bash
swift test
```

---

## Concurrency Rules (Swift 6 Strict)

- The ViewModel is `@MainActor`. All `@Published` writes must happen on the main actor.
- `LiveExchangeRateProvider.quote(for:)` is a `static async throws` — call it from
  any `Task`; it is `Sendable`-safe.
- Closures stored in the ViewModel (`quoteLoader`, `favoritePairsChanged`,
  `refreshAction`) must be `@Sendable`.
- Do not add `nonisolated` to ViewModel methods that access `@Published` properties.
- `Task { [quoteLoader] in ... }` is the established pattern for background work inside
  `requestRefresh()` — follow the same capture-list style.

---

## Exchange Rate API — Integration Rules

1. URL path uses the **lowercase** currency code: `.../currencies/eur.json`
2. Response key for rates uses **lowercase** codes: `payload["eur"]["usd"]`
3. Always implement **both** CDN hosts (jsDelivr primary, Cloudflare fallback).
4. Do not expose raw `URL` construction or host strings outside `LiveExchangeRateProvider.API`.
5. Cache only **successful** quotes (`QuoteCacheStore.saveQuote`).
6. Fresh/stale distinction must reach the UI via `QuoteLoadResult`, not ad-hoc strings.

---

## Persistence

All persistence uses `UserDefaults` (Suite: none — uses `.standard`).  
Keys are private constants inside each store. Do not read these keys outside the store.

| Store | What it persists |
|---|---|
| `FavoriteCurrencyPairStore` | Ordered array of favorite currency pairs |
| `QuoteCacheStore` | Latest `CurrencyQuote` per source-target pair |

There is no CoreData, SQLite, or keychain dependency.

---

## Testing Conventions

- Test target: `CurrencyConverterMacOSTests` (SPM + Xcode)
- Run with: `swift test`
- Tests must not make real network requests. Inject mock `quoteLoader` closures.
- Use `UserDefaults(suiteName: UUID().uuidString)` for isolated store tests.
- Existing test files: `CurrencyCatalogTests.swift`, `FavoriteCurrencyPairStoreTests.swift`
- `CurrencyConversionViewModel` tests should go in a new
  `CurrencyConversionViewModelTests.swift` in the same directory.

---

## Common Tasks — How To

### Add a new currency field or metadata
1. Update `CurrencyDescriptor` in `CurrencyCatalog.swift`.
2. Update `CurrencyCatalog.live` if the catalog generation logic needs to change.
3. Update `CurrencySelectionState` if the new field affects selection logic.
4. Update `MenuBarView` to display it.

### Add a new ViewModel state
1. Add a `@Published public private(set) var` property to `CurrencyConversionViewModel`.
2. Mutate it only inside `@MainActor` methods or `await MainActor.run { }` blocks.
3. Expose a computed property or method if the UI needs to derive from it.
4. Add a test in `CurrencyConversionViewModelTests.swift`.

### Add a new persistent field
1. Add the field to the relevant `Codable` type.
2. Handle migration if old persisted data won't decode (provide a default).
3. Update the store's encode/decode logic if it uses custom serialisation.

### Add a new menu bar UI section
1. Add it to `MenuBarView.swift` inside the root `VStack`.
2. Bind exclusively via the `viewModel` — never add local `@State` for data that
   belongs in the ViewModel.
3. Keep the popover width at `360` pt (set in `.frame(width: 360)`).

### Change the retry count or CDN hosts
- Edit `LiveExchangeRateProvider.API.endpoints(for:)` for hosts.
- Change the `retryCount` default parameter on `quote(for:session:retryCount:)`.
- The `AppComposition` closure does not pass a custom `retryCount` — it uses the
  default. Override at the call site if needed.

### Change default currencies
- Edit `CurrencyCatalog.live.defaultPreselectedCodes` in `CurrencyCatalog.swift`.
- The first two valid codes become the default source and target.
