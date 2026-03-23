import Foundation

struct MiClawVariant: ClawVariant {
    let id = "miclaw"
    let displayName = "MiClaw"
    let description = "小米推出的 AI 操作助手"
    let iconSystemName = "iphone"

    let appNames = ["MiClaw"]
    let bundleIdentifiers = ["com.xiaomi.miclaw"]
    let cliBinaryNames = ["miclaw"]
    let stateDirs = [".miclaw", ".config/miclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/MiClaw",
            "\(home)/Library/Caches/MiClaw",
            "\(home)/Library/Caches/com.xiaomi.miclaw",
        ]
    }
}
