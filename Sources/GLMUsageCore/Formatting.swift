import Foundation

/// 纯函数格式化：全部注入 calendar（测试注入固定 now/timeZone 以保证确定性）。
public enum HUDFormatting: Sendable {
    private static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    /// 顶栏标题：`10% · 40%`（5h已用% · 周已用%）；任一侧缺失显示 `--%`。
    public static func title(fiveHourUsedPercent: Int?, weekUsedPercent: Int?) -> String {
        let five = fiveHourUsedPercent.map { "\($0)%" } ?? "--%"
        let week = weekUsedPercent.map { "\($0)%" } ?? "--%"
        return "\(five) · \(week)"
    }

    /// 千分位整数：2,934
    public static func grouped(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded) < 1000 { return String(Int(rounded)) }
        let digits = String(Int(abs(rounded)))
        var parts: [String] = []
        var remaining = digits
        while remaining.count > 3 {
            parts.insert(String(remaining.suffix(3)), at: 0)
            remaining = String(remaining.dropLast(3))
        }
        parts.insert(remaining, at: 0)
        let sign = rounded < 0 ? "-" : ""
        return sign + parts.joined(separator: ",")
    }

    /// 5h 重置时刻：今天 → `今天 14:22`；否则 → `9月11日 06:05`。
    public static func shortReset(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "今天 " + hhmm(date, calendar: calendar)
        }
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month!)月\(c.day!)日 " + hhmm(date, calendar: calendar)
    }

    /// 周重置日期：`9月15日 (周二)`。
    public static func weekReset(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekday = weekdayNames[(c.weekday! - 1 + 7) % 7]
        return "\(c.month!)月\(c.day!)日 (\(weekday))"
    }

    /// 套餐档位：max→Max / pro→Pro / lite→Lite，未知原样，空 → 未知。
    public static func planLevel(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "max": "Max"
        case "pro": "Pro"
        case "lite": "Lite"
        case nil, "": "未知"
        case let value?: value
        }
    }

    /// `HH:mm`（24 小时制，注入 calendar 保证确定性）。
    public static func timeHM(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func hhmm(_ date: Date, calendar: Calendar) -> String {
        timeHM(date, calendar: calendar)
    }
}
