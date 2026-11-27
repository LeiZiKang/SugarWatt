# SugarWatt for iOS & watchOS

**A restrained, Apple-native iPhone & Apple Watch companion app, StandBy-style Landscape Desk Dashboard, modular 1×1 / 2×1 Widget Board, and WidgetKit suite for CANDYSIGN (制糖工厂) CoCan smart chargers.**

Free on the App Store and 100% open source under the MIT License. Powered by the shared [KangChargeCore](https://github.com/LeiZiKang/KangChargeCore) Swift Package.

> **Looking for macOS?** See [SugarWatt for macOS (KangCharge)](https://github.com/LeiZiKang/KangCharge).

## Features

- **Modular 1×1 & 2×1 Widget Board**: Long-press any tile to enter SpringBoard-style edit mode with jiggle, haptics, and live auto-reflow drag-and-drop.
- **Hardware LED Pressure Meters & USB-PD Battery Rings**: 8-segment breathing load meters alongside real USB-PD device battery rings and 180-sample device memory logs.
- **StandBy Landscape Desk Dashboard**: Rotate your iPhone sideways for an always-on OLED charging monitor — switch the right panel between all 5 live ports, your Daily Energy Calendar Heatmap, or your custom widget grid.
- **Daily Energy Analytics**: GitHub-style Calendar Heatmap with month & weekday labels, Energy Equivalents, Port Breakdown Donut Chart, and By Hour / By Weekday Charging Rhythm, with optional private iCloud KVS sync to macOS.
- **One-Tap Smart MCP Paste**: Paste the full prompt text copied from the CANDYSIGN app — SugarWatt extracts your `/sse` endpoint automatically.
- **Home & Lock Screen Widgets + Redesigned Apple Watch App**: Circular load rings, LED meters, 3-page Digital Crown watchOS app, and 4 watch face complications.
- **Xcode Cloud Ready**: Includes `ci_scripts/ci_post_clone.sh` — see [docs/XCODE_CLOUD.md](docs/XCODE_CLOUD.md).

## Build from Source

```bash
git clone https://github.com/LeiZiKang/KangCharge-iOS.git
cd KangCharge-iOS
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Fill in your `DEVELOPMENT_TEAM` and `BUNDLE_ID_PREFIX` in `Config/Local.xcconfig`, ensure your developer account has the App Groups `group.<prefix>.kangcharge` and `group.<prefix>.kangcharge.watch`, then run:

```bash
xcodegen generate
open KangChargeiOS.xcodeproj
```

## Privacy

- Your MCP server URL is stored strictly in the iOS/watchOS Keychain (shared only with your own widgets).
- No analytics, no ads, no third-party servers.

## License

[MIT](LICENSE)
