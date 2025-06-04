import Foundation
import SwiftUI

struct AppUsageData: Identifiable {
    let id = UUID()
    let appName: String
    let bundleIdentifier: String
    let totalTime: TimeInterval
    let color: Color
}
