import Testing
import Foundation
import GLMUsageCore

// 实测响应 fixture（2026-09-10 用户 key 实测，5h 已用 10%，周已用 40%）
let fixtureJSON = """
{"code":200,"msg":"操作成功","data":{"limits":[
{"type":"CREDIT_LIMIT","unit":3,"number":5,"usage":28000,"currentValue":2934,"remaining":25065,"percentage":10,"nextResetTime":1789038144772},
{"type":"CREDIT_LIMIT","unit":6,"number":1,"usage":140000,"currentValue":56345,"remaining":83654,"percentage":40,"nextResetTime":1789458367978}],"level":"max"},"success":true}
"""

// 周条目在前的乱序 fixture（验证不依赖数组顺序）
let reversedJSON = """
{"code":200,"msg":"操作成功","data":{"limits":[
{"type":"CREDIT_LIMIT","unit":6,"number":1,"usage":140000,"currentValue":56345,"remaining":83654,"percentage":40,"nextResetTime":1789458367978},
{"type":"CREDIT_LIMIT","unit":3,"number":5,"usage":28000,"currentValue":2934,"remaining":25065,"percentage":10,"nextResetTime":1789038144772}],"level":"pro"},"success":true}
"""

// 缺周条目
let missingWeekJSON = """
{"code":200,"msg":"操作成功","data":{"limits":[
{"type":"CREDIT_LIMIT","unit":3,"number":5,"usage":28000,"currentValue":2934,"remaining":25065,"percentage":10,"nextResetTime":1789038144772}],"level":"max"},"success":true}
"""

let businessErrorJSON = """
{"code":1001,"msg":"Header中未收到Authorization参数，无法进行身份验证。","success":false}
"""

private func shanghaiCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    return calendar
}

@Test("实测 fixture 解析：字段与语义")
func parseFixture() throws {
    let snapshot = try UsageSnapshot.parse(fixtureJSON.data(using: .utf8)!)
    #expect(snapshot.planLevel == "max")
    let five = snapshot.fiveHour
    let week = snapshot.week
    #expect(five.usedPercent == 10)          // percentage = 已用%
    #expect(five.used == 2934)
    #expect(five.total == 28000)
    #expect(five.remaining == 25065)
    #expect(week.usedPercent == 40)
    #expect(week.nextReset == Date(timeIntervalSince1970: 1789458367978 / 1000))
}

@Test("乱序响应按 (unit, number) 匹配而非数组顺序")
func parseReversed() throws {
    let snapshot = try UsageSnapshot.parse(reversedJSON.data(using: .utf8)!)
    #expect(snapshot.fiveHour.usedPercent == 10)
    #expect(snapshot.week.usedPercent == 40)
    #expect(snapshot.planLevel == "pro")
}

@Test("缺任一限额条目 → limitMissing")
func limitMissing() {
    #expect(throws: UsageAPIError.limitMissing) {
        try UsageSnapshot.parse(missingWeekJSON.data(using: .utf8)!)
    }
}

@Test("业务码非 200 → business 错误")
func businessError() {
    #expect(throws: UsageAPIError.business(code: 1001, msg: "Header中未收到Authorization参数，无法进行身份验证。")) {
        try UsageSnapshot.parse(businessErrorJSON.data(using: .utf8)!)
    }
}

@Test("顶栏标题格式")
func titleFormat() {
    #expect(HUDFormatting.title(fiveHourUsedPercent: 10, weekUsedPercent: 40) == "10% · 40%")
    #expect(HUDFormatting.title(fiveHourUsedPercent: 100, weekUsedPercent: 0) == "100% · 0%")
    #expect(HUDFormatting.title(fiveHourUsedPercent: nil, weekUsedPercent: nil) == "--% · --%")
}

@Test("重置时间格式（注入固定 now/timeZone，确定性输出）")
func resetTimeFormat() throws {
    let calendar = shanghaiCalendar()
    let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 14, minute: 0)))
    let sameDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 22, minute: 22)))
    let otherDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 6, minute: 5)))
    let weekReset = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))
    #expect(HUDFormatting.shortReset(sameDay, now: now, calendar: calendar) == "今天 22:22")
    #expect(HUDFormatting.shortReset(otherDay, now: now, calendar: calendar) == "9月11日 06:05")
    #expect(HUDFormatting.weekReset(weekReset, calendar: calendar) == "9月15日 (周二)")
}

@Test("千分位格式化")
func groupedNumbers() {
    #expect(HUDFormatting.grouped(2934) == "2,934")
    #expect(HUDFormatting.grouped(83654) == "83,654")
    #expect(HUDFormatting.grouped(140000) == "140,000")
    #expect(HUDFormatting.grouped(999) == "999")
}

@Test("套餐档位映射")
func planLevelMapping() {
    #expect(HUDFormatting.planLevel("max") == "Max")
    #expect(HUDFormatting.planLevel("PRO") == "Pro")
    #expect(HUDFormatting.planLevel("lite") == "Lite")
    #expect(HUDFormatting.planLevel("unknown-tier") == "unknown-tier")
    #expect(HUDFormatting.planLevel(nil) == "未知")
}
