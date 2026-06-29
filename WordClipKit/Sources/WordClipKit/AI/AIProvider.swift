import Foundation

// MARK: - AIEnrichment

public struct AIEnrichment: Sendable {
    public let word: String
    public let enhancedDefinition: String?  // 更丰富的释义
    public let exampleSentences: [String]   // 例句
    public let etymology: String?           // 词根/助记
    public let mnemonics: String?           // 记忆技巧
}

// MARK: - AIProvider

/// AI 功能协议，预留接口，当前不实现。
/// 未来可接入 Claude API 等。
public protocol AIProvider: Sendable {
    func enrich(word: String, context: String?) async throws -> AIEnrichment
}

// MARK: - NoopAIProvider

/// 占位实现，始终抛出「未启用」错误。UI 入口默认关闭。
public struct NoopAIProvider: AIProvider {
    public init() {}

    public func enrich(word: String, context: String?) async throws -> AIEnrichment {
        throw AIError.notEnabled
    }
}

public enum AIError: Error, LocalizedError {
    case notEnabled

    public var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "AI 功能尚未启用"
        }
    }
}
