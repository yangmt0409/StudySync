import Foundation

extension Date {
    /// 本地化日期格式（中文: "2026年3月19日"，英文: "Mar 19, 2026"）
    var formattedChinese: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }

    /// 格式化为 "MM/dd/yyyy"
    var formattedShort: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: self)
    }

    /// 获取指定时区的小时和分钟
    func timeIn(timeZone: TimeZone) -> (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0, components.minute ?? 0)
    }

    /// 获取指定时区的格式化时间字符串
    func formattedTime(in timeZone: TimeZone, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = style
        formatter.dateStyle = .none
        formatter.timeZone = timeZone
        return formatter.string(from: self)
    }

    /// 获取指定时区的本地化日期字符串（含星期）
    func formattedDate(in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        return formatter.string(from: self)
    }

    /// 距今天数描述（本地化）
    var daysFromNowDescription: String {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: self)
        let days = calendar.dateComponents([.day], from: now, to: target).day ?? 0

        if days == 0 { return L10n.today }
        if days == 1 { return L10n.tomorrow }
        if days == -1 { return L10n.yesterday }
        if days > 0 { return L10n.daysLater(days) }
        return L10n.daysAgo(abs(days))
    }
}
