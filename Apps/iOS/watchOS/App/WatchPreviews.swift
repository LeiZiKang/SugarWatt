import SwiftUI
import KangChargeCore
import KangChargeUI

#Preview("1. Watch Overview") {
    WatchHomeView(model: WatchModel(previewDemo: true), initialTab: 0)
}

#Preview("2. Watch Ports (LED Meters)") {
    WatchHomeView(model: WatchModel(previewDemo: true), initialTab: 1)
}

#Preview("3. Watch Daily Energy") {
    WatchHomeView(model: WatchModel(previewDemo: true), initialTab: 2)
}
