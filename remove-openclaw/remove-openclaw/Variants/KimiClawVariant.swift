import Foundation

struct KimiClawVariant: ClawVariant {
    let id = "kimiclaw"
    let displayName = "KimiClaw"
    let description = "月之暗面推出，基于 Kimi 模型的浏览器自动化助手"
    let iconSystemName = "moon"

    let appNames = ["KimiClaw"]
    let bundleIdentifiers = ["com.moonshot.kimiclaw"]
    let cliBinaryNames = ["kimiclaw"]
    let stateDirs = [".kimiclaw", ".config/kimiclaw"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/KimiClaw",
            "\(home)/Library/Caches/KimiClaw",
            "\(home)/Library/Caches/com.moonshot.kimiclaw",
            "\(home)/Library/Logs/KimiClaw",
        ]
    }
}
