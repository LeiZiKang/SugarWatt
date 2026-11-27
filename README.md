<div align="center">

# ⚡ SugarWatt

**An Apple-native macOS, iOS & watchOS companion suite for CANDYSIGN (制糖工厂) CoCan smart desk chargers.**

[![Platforms](https://img.shields.io/badge/Platforms-macOS%2014+%20%7C%20iOS%2017+%20%7C%20watchOS%2010+-111111?style=flat-square&logo=apple)](ARCHITECTURE.md)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=flat-square&logo=swift&logoColor=white)](Packages/KangChargeCore/Package.swift)
[![License](https://img.shields.io/badge/License-MIT-059669?style=flat-square)](LICENSE)
[![Zero Backend](https://img.shields.io/badge/Backend-Zero%20Relay%20%C2%B7%20Keychain%20Only-2563EB?style=flat-square)](ARCHITECTURE.md)

[macOS App](Apps/macOS) · [iOS & watchOS App](Apps/iOS) · [Shared SPM (`KangChargeCore`)](Packages/KangChargeCore) · [Architecture](ARCHITECTURE.md) · [Energy Equivalents JSON](https://github.com/LeiZiKang/sugarwatt-equivalents)

</div>

---

SugarWatt is an independent, MIT open-source SwiftUI suite that talks **directly** to your CANDYSIGN smart desk charger over its official `ionbridge-mcp` endpoint — no custom relay server, no user accounts, no firmware flashing, and no third-party analytics.

<p align="center">
  <img src="Apps/macOS/docs/screenshots/dashboard-light.png" alt="SugarWatt for macOS — Light Mode" width="88%" />
</p>

## Visual Tour

### macOS · Dark Mode, Menu Bar & Desktop Widgets

| Dark Mode Dashboard | Menu Bar Presence |
| :---: | :---: |
| <img src="Apps/macOS/docs/screenshots/dashboard-dark.png" alt="macOS Dark Mode" width="100%" /> | <img src="Apps/macOS/docs/screenshots/menubar-light.png" alt="macOS Menu Bar" width="100%" /> |

| Large Interactive Power Widget | Daily Energy Heatmap Widget |
| :---: | :---: |
| <img src="Apps/macOS/docs/screenshots/widget-large-light.png" alt="Large Power Widget" width="100%" /> | <img src="Apps/macOS/docs/screenshots/widget-heatmap-medium-light.png" alt="Daily Energy Heatmap Widget" width="100%" /> |

### iPhone & Apple Watch · Modular Board, StandBy Desk & Watch Companion

| iPhone Live Dashboard | Daily Energy Analytics | Apple Watch Companion |
| :---: | :---: | :---: |
| <img src="docs/screenshots/ios-portrait-light.png" alt="iOS Portrait Dashboard" width="230" /> | <img src="docs/screenshots/ios-daily-energy.png" alt="iOS Daily Energy Analytics" width="230" /> | <img src="docs/screenshots/watch-overview.png" alt="watchOS Companion" width="170" /> |

<p align="center">
  <img src="docs/screenshots/ios-landscape-desk.png" alt="iOS StandBy-Style Landscape Desk Dashboard" width="76%" />
</p>

---

## Inside This Monorepo

Click any directory below to jump straight into its source code and documentation:

| Directory / Repo | Platform / Role | Highlights |
| --- | --- | --- |
| [**`Apps/macOS/`**](Apps/macOS) | macOS 14+ App & Desktop Widgets | Menu bar & Dock presence, live Swift Charts load curve, safe per-port switches, Shortcuts App Intents, Desktop WidgetKit suite |
| [**`Apps/iOS/`**](Apps/iOS) | iOS 17+ & watchOS 10+ Apps & Widgets | Modular `1×1` / `2×1` Widget Board, StandBy-style Landscape Desk Dashboard, Home/Lock Screen widgets, 3-page Digital Crown Watch app |
| [**`Packages/KangChargeCore/`**](Packages/KangChargeCore) | Shared Swift Package (`KangChargeCore` + `KangChargeUI`) | HTTP+SSE `ionbridge-mcp` client, typed USB-PD models, `EnergyLedger`, offline Demo simulator, shared SwiftUI components & unit tests |
| [**`ARCHITECTURE.md`**](ARCHITECTURE.md) | System Architecture & How It Works | End-to-end Mermaid diagram, data-flow walkthrough, App Group & optional iCloud KVS sync model |
| [**`sugarwatt-equivalents`**](https://github.com/LeiZiKang/sugarwatt-equivalents) | Community JSON Catalog (Public PRs) | Read-only `equivalents.json` turning raw `kWh` into intuitive comparisons (iPhone charges, espresso cups, EV km) with bundled offline fallback |

---

## Architecture & How It Works

```mermaid
flowchart TB
    MCP["CANDYSIGN Charger<br/>Official ionbridge-mcp (HTTP + SSE)"] <-->|"Direct HTTPS/SSE<br/>(Keychain token)"| CORE["Packages/KangChargeCore<br/>(KangChargeCore + KangChargeUI)"]
    EQ["Read-Only Static JSON<br/>sugarwatt-equivalents"] -.->|"Optional GET + offline fallback"| CORE
    CORE --> MAC["Apps/macOS<br/>macOS 14+ · Menu Bar · Widgets"]
    CORE --> IOS["Apps/iOS<br/>iOS 17+ · watchOS 10+ · StandBy Desk · Widgets"]
    MAC <--> SYNC["Apple Keychain · App Groups · Optional Private iCloud KVS"]
    IOS <--> SYNC
```

- **Zero relay backend**: Paste your charger's MCP URL once; SugarWatt stores it strictly in your local **Apple Keychain** and polls your device directly over HTTP+SSE.
- **Instant offline Demo Mode**: No physical charger on hand? Toggle **Demo Mode** to explore realistic live multi-port wattage, charts, and widgets completely offline.
- **Single local Swift Package**: Both [`Apps/macOS`](Apps/macOS) and [`Apps/iOS`](Apps/iOS) depend directly on [`Packages/KangChargeCore`](Packages/KangChargeCore) via relative path — edit shared code once and both platforms update immediately.

Read the full walkthrough in **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

## Build from Source

**Requirements:** macOS 14+, Xcode 16+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
git clone https://github.com/LeiZiKang/SugarWatt.git
cd SugarWatt

# 1. Run shared Swift Package unit tests
swift test --package-path Packages/KangChargeCore

# 2. Generate & open macOS app
cd Apps/macOS
cp Config/Local.xcconfig.example Config/Local.xcconfig
xcodegen generate && open KangCharge.xcodeproj

# 3. Generate & open iOS & watchOS app
cd ../iOS
cp Config/Local.xcconfig.example Config/Local.xcconfig
xcodegen generate && open KangChargeiOS.xcodeproj
```

> Fill in your Apple Developer `DEVELOPMENT_TEAM` (a free personal team works) and `BUNDLE_ID_PREFIX` inside `Config/Local.xcconfig` before running on physical hardware.

---

## Privacy & Disclaimer

- **No telemetry, no ads, no custom servers.** Your MCP URL contains your charger serial and access token and never leaves your Apple Keychain except to talk directly to your charger.
- Daily energy history stays in your local App Group and optionally syncs only through your private Apple iCloud Key-Value Store.
- SugarWatt is an independent open-source project and is not affiliated with, endorsed by, or sponsored by CANDYSIGN (制糖工厂).

## License

Released under the [MIT License](LICENSE).
