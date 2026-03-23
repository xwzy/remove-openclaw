import Foundation

struct AutoClawVariant: ClawVariant {
    let id = "autoclaw"
    let displayName = "AutoClaw"
    let description = "智谱推出的自动化浏览器操作 AI 工具"
    let iconSystemName = "gearshape.2"

    let appNames = ["AutoClaw"]
    let bundleIdentifiers = ["com.zhipu.autoclaw"]
    let cliBinaryNames = ["autoclaw"]
    let stateDirs = [".autoclaw", ".config/autoclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/AutoClaw",
            "\(home)/Library/Caches/AutoClaw",
            "\(home)/Library/Caches/com.zhipu.autoclaw",
            "\(home)/Library/Logs/AutoClaw",
        ]
    }
}
