# KLSE Advisor

A Flutter app for researching Bursa Malaysia (KLSE) stocks — live watchlists,
fundamental scoring, technical charts, and optional AI-generated research notes.

## Features

- **Watchlist** — track your favourite KLSE counters with live quotes, day
  change and the FTSE Bursa Malaysia KLCI index at a glance.
- **Discovery** — search Bursa Malaysia equities by name or ticker.
- **Stock detail**
  - Fundamentals: P/E, P/B, dividend yield, ROE, margins, debt, cash flow,
    analyst targets and more (data from Yahoo Finance).
  - **Long-Term Score** — an in-app 0–100 weighted quality/value score
    (yield 25, ROE 20, debt 15, PE 15, growth 10, margins 10, P/B 5) with
    automatic strength/weakness flags.
- **Technical chart** — interactive price chart with 6M / 1Y / 5Y ranges and
  toggleable indicators:
  - SMA 20 / SMA 50 overlays
  - Bollinger Bands (20, 2σ)
  - MACD (12, 26, 9) with signal line and histogram
  - RSI (14) with 70/30 overbought/oversold guides
- **AI research note** — optional. Bring your own OpenAI-compatible LLM
  (OpenAI, DeepSeek, xAI, local Ollama, …): set the base URL, API token and
  model in Settings and generate a structured long-term investment thesis
  from the stock's fundamentals.

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.24+ 
- An Android device or emulator (API 23+)

### Run in debug mode

```sh
flutter pub get
flutter run
```

### Run tests

```sh
flutter test
```

### Build a release APK

```sh
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Download

Release APKs are built automatically by GitHub Actions whenever a `v*` tag is
pushed (or manually via *Run workflow*). Grab the latest APK from the
[Releases](https://github.com/vunloon/klseadvisor/releases) page.

## Project layout

```
lib/
├── data/         # KLSE stock universe
├── models/       # Quote & fundamentals models
├── providers/    # Watchlist + settings state (provider)
├── screens/      # Watchlist, discovery, detail, add, settings
├── services/     # Yahoo Finance & LLM clients
├── util/         # Formatting + technical indicator math
└── widgets/      # Price chart, stat tiles
```

## Disclaimer

This app is for information and education only. Nothing in it is financial
advice. Data may be delayed, incomplete or wrong. Do your own research before
investing.
