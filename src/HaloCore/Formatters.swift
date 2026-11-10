import Foundation

public enum Format {
    /// "11.7 GB", "512 MB" (decimal units like Finder).
    public static func bytes(_ value: Double, decimal: Bool = true) -> String {
        let base: Double = decimal ? 1000 : 1024
        let units = ["B", "KB", "MB", "GB", "TB", "PB"].map { L($0) }
        var v = max(value, 0)
        var i = 0
        while v >= base && i < units.count - 1 { v /= base; i += 1 }
        if i == 0 { return "\(Int(v)) \(units[0])" }
        return v >= 100 ? String(format: "%.0f %@", v, units[i]) : String(format: "%.1f %@", v, units[i])
    }

    /// Memory sizes use binary units like Activity Monitor ("11.7 GB of 16 GB").
    public static func memory(_ value: Double) -> String {
        bytes(value, decimal: false)
    }

    /// "1 KB/s", "88.8 MB/s".
    public static func rate(_ bytesPerSecond: Double) -> String {
        let units = ["KB/s", "MB/s", "GB/s"].map { L($0) }
        var v = max(bytesPerSecond, 0) / 1000
        var i = 0
        while v >= 1000 && i < units.count - 1 { v /= 1000; i += 1 }
        if i == 0 || v >= 100 { return String(format: "%.0f %@", v, units[i]) }
        return String(format: "%.1f %@", v, units[i])
    }

    /// "2:15" style is avoided; we use "2 h 15 min".
    public static func duration(minutes: Int) -> String {
        guard minutes > 0 else { return "–" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }

    /// "3 days, 4 h" / "5 h 12 min".
    public static func uptime(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let d = total / 86_400, h = (total % 86_400) / 3_600, m = (total % 3_600) / 60
        if d > 0 { return d == 1 ? L("1 day, %d h", h) : L("%d days, %d h", d, h) }
        if h > 0 { return "\(h) h \(m) min" }
        return "\(m) min"
    }

    public static func percent(_ fraction: Double?) -> String {
        guard let f = fraction else { return "–" }
        return "\(Int((min(max(f, 0), 1) * 100).rounded()))%"
    }
}
