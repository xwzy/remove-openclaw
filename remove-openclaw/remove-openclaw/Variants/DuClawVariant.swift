import Foundation

struct DuClawVariant: ClawVariant {
    let id = "duclaw"
    let displayName = "DuClaw"
    let description = "百度推出的 AI 操作助手"
    let iconSystemName = "hand.point.up.left"

    let appNames = ["DuClaw"]
    let bundleIdentifiers = ["com.baidu.duclaw"]
    let cliBinaryNames = ["duclaw"]
    let stateDirs = [".duclaw", ".config/duclaw"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/DuClaw",
            "\(home)/Library/Caches/DuClaw",
            "\(home)/Library/Caches/com.baidu.duclaw",
            "\(home)/Library/Logs/DuClaw",
        ]
    }
}
