import Foundation

struct ClawAPIVariant: ClawVariant {
    let id = "clawapi"
    let displayName = "ClawAPI"
    let description = "API 代理客户端，用于本地管理多个 AI 模型接口"

    let appNames = ["ClawAPI"]
    let bundleIdentifiers = ["com.clawapi.app"]
    let stateDirs: [String] = []

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/ClawAPI",
            "\(home)/Library/Caches/ClawAPI",
        ]
    }
}
