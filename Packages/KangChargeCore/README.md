# KangChargeCore

Shared Swift Package powering **SugarWatt** ([macOS](https://github.com/LeiZiKang/KangCharge) and [iOS & watchOS](https://github.com/LeiZiKang/KangCharge-iOS)).

## Modules

- **`KangChargeCore`**: HTTP+SSE MCP client for CANDYSIGN `ionbridge-mcp`, smart MCP URL/prompt extractor (`AppConfig.extractMCPInput`), typed models (including USB-PD battery fraction), Keychain & App Group storage, `EnergyEquivalentsCatalog`, and `EnergyLedger` (daily/port/hourly/weekday energy accumulator with optional iCloud KVS cross-device sync).
- **`KangChargeUI`**: Shared ceramic & graphite Apple-native SwiftUI design tokens (`KCStyle`), smart device SF Symbols (`KCDeviceSymbol`), reusable `CalendarHeatmapView` / `EnergyHeatmapView`, `PortEnergyDonutChart`, `EnergyTimePatternChart` (By Hour / By Weekday), `EnergyEquivalentsCard`, and living 8-segment `PowerPressureMeter`.

## Platforms

- macOS 14+
- iOS 17+
- watchOS 10+

## License

[MIT](LICENSE)
