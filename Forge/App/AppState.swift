import Foundation
import Observation

@Observable
final class AppState {
    var unitSystem: UnitSystem = .imperial
    var isProUser: Bool = false
}
