import Foundation

/// 智谱用量端点返回的单条限额（CREDIT_LIMIT）。
/// 语义：unit==3 && number==5 → 5 小时窗口；unit==6 && number==1 → 周额度。
public struct LimitEntry: Codable, Equatable, Sendable {
    public let type: String
    public let unit: Int
    public let number: Int
    public let usage: Double
    public let currentValue: Double
    public let remaining: Double
    /// 已用百分比（服务端口径）
    public let percentage: Int
    /// 毫秒 epoch
    public let nextResetTime: Double?
}

struct QuotaLimitEnvelope: Codable, Sendable {
    let limits: [LimitEntry]?
    let level: String?
}

struct QuotaLimitResponse: Codable, Sendable {
    let code: Int
    let msg: String?
    let success: Bool?
    let data: QuotaLimitEnvelope?
}

/// 单个限额窗口的归一化用量。
public struct WindowUsage: Equatable, Sendable {
    /// 已用数值（currentValue）
    public let used: Double
    /// 总额度（usage）
    public let total: Double
    public let remaining: Double
    /// 已用百分比（响应 percentage 字段，已取整）
    public let usedPercent: Int
    public let nextReset: Date?

    public init(entry: LimitEntry) {
        used = entry.currentValue
        total = entry.usage
        remaining = entry.remaining
        usedPercent = entry.percentage
        nextReset = entry.nextResetTime.map { Date(timeIntervalSince1970: $0 / 1000) }
    }
}

/// 一次成功拉取的用量快照。parse 成功即保证两个窗口都在。
public struct UsageSnapshot: Equatable, Sendable {
    /// 套餐档位原始值（max/pro/lite…）
    public let planLevel: String
    public let fiveHour: WindowUsage
    public let week: WindowUsage
    public let fetchedAt: Date

    public init(planLevel: String, fiveHour: WindowUsage, week: WindowUsage, fetchedAt: Date) {
        self.planLevel = planLevel
        self.fiveHour = fiveHour
        self.week = week
        self.fetchedAt = fetchedAt
    }

    /// 解析并校验端点响应：业务码校验 + (unit, number) 语义匹配（不依赖数组顺序）。
    public static func parse(_ data: Data, fetchedAt: Date = Date()) throws -> UsageSnapshot {
        let response: QuotaLimitResponse
        do {
            response = try JSONDecoder().decode(QuotaLimitResponse.self, from: data)
        } catch {
            throw UsageAPIError.decode("响应解析失败：\(error.localizedDescription)")
        }
        guard response.code == 200, response.success != false else {
            throw UsageAPIError.business(code: response.code, msg: response.msg ?? "未知业务错误")
        }
        let limits = response.data?.limits ?? []
        guard let fiveHourEntry = limits.first(where: { $0.unit == 3 && $0.number == 5 }),
              let weekEntry = limits.first(where: { $0.unit == 6 && $0.number == 1 })
        else {
            throw UsageAPIError.limitMissing
        }
        return UsageSnapshot(
            planLevel: response.data?.level ?? "",
            fiveHour: WindowUsage(entry: fiveHourEntry),
            week: WindowUsage(entry: weekEntry),
            fetchedAt: fetchedAt
        )
    }
}
