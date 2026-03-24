import Foundation

struct MaxClawVariant: ClawVariant {
    let id = "maxclaw"
    let displayName = "MaxClaw"
    let description = "MiniMax 推出的浏览器自动化 AI 助手"
    let iconSystemName = "safari"

    let appNames = ["MaxClaw"]
    let bundleIdentifiers = ["com.minimax.maxclaw"]
    let cliBinaryNames = ["maxclaw"]
    let stateDirs = [".maxclaw", ".config/maxclaw"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/MaxClaw",
            "\(home)/Library/Caches/MaxClaw",
            "\(home)/Library/Caches/com.minimax.maxclaw",
            "\(home)/Library/Logs/MaxClaw",
        ]
    }
}
