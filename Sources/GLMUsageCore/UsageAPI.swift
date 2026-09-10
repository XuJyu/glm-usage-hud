import Foundation

public enum UsageAPIError: Error, Equatable, Sendable, CustomStringConvertible {
    case http(Int)
    case business(code: Int, msg: String)
    case network(String)
    case decode(String)
    case noKey
    case limitMissing

    public var description: String {
        switch self {
        case .http(let code):
            "服务端返回 HTTP \(code)"
        case .business(let code, let msg):
            "智谱业务错误（code \(code)）：\(msg)"
        case .network(let message):
            "网络错误：\(message)"
        case .decode(let message):
            message
        case .noKey:
            "尚未配置 API Key"
        case .limitMissing:
            "响应中缺少 5 小时/周限额条目（端点结构可能已变更）"
        }
    }
}

/// 智谱 GLM Coding Plan 用量查询客户端。
/// 端点为智谱控制台内部接口（非官方公开 API），仅用 Bearer key 认证。
public struct UsageAPI: Sendable {
    public let baseURL: URL

    public init(baseURL: URL = URL(string: "https://open.bigmodel.cn/api/monitor/usage/quota/limit")!) {
        self.baseURL = baseURL
    }

    public func fetch(apiKey: String) async throws -> UsageSnapshot {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw UsageAPIError.noKey }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageAPIError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw UsageAPIError.http(http.statusCode)
        }
        return try UsageSnapshot.parse(data)
    }
}
