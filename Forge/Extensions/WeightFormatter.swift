import Foundation

/// Converts and formats weight values between kg and lbs based on the user's unit system.
enum WeightFormatter {

    // MARK: - Conversion constants
    static let kgToLbs: Double = 2.20462
    static let lbsToKg: Double = 1 / kgToLbs

    // MARK: - Display formatting

    /// Format a kg value for display (e.g. "80.0 kg" or "176.4 lbs").
    static func format(_ kg: Double?, unitSystem: UnitSystem) -> String {
        guard let kg else { return "—" }
        switch unitSystem {
        case .metric:
            return kg.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(kg)) kg"
                : String(format: "%.1f kg", kg)
        case .imperial:
            let lbs = kg * kgToLbs
            return lbs.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(lbs)) lbs"
                : String(format: "%.1f lbs", lbs)
        }
    }

    /// Short unit label: "kg" or "lbs".
    static func unitLabel(_ unitSystem: UnitSystem) -> String {
        unitSystem == .metric ? "kg" : "lbs"
    }

    // MARK: - Conversion (always store in kg internally)

    /// Convert a display value (in the user's unit) back to kg for storage.
    static func toKg(_ displayValue: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric: return displayValue
        case .imperial: return displayValue * lbsToKg
        }
    }

    /// Convert a kg storage value to the user's display unit.
    static func fromKg(_ kg: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric: return kg
        case .imperial: return kg * kgToLbs
        }
    }

    // MARK: - Step sizes for pickers

    /// Sensible stepper increment for weight in the user's unit.
    static func stepSize(_ unitSystem: UnitSystem) -> Double {
        unitSystem == .metric ? 2.5 : 5.0
    }

    /// Sensible max for weight pickers.
    static func maxWeight(_ unitSystem: UnitSystem) -> Double {
        unitSystem == .metric ? 500 : 1100
    }
}
