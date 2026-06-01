import Foundation

extension TimeInterval {
    var timerFormatted: String {
        let total = Int(max(0, self))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    var overtimeFormatted: String {
        let total = Int(max(0, self))
        let m = total / 60
        let s = total % 60
        return m > 0
            ? String(format: "+%d:%02d", m, s)
            : String(format: "+%d", s)
    }
}
