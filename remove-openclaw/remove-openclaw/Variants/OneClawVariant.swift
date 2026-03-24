import Foundation

struct OneClawVariant: ClawVariant {
    let id = "oneclaw"
    let displayName = "OneClaw"
    let description = "零配置桌面包装，内置 Node.js 运行时"
    let iconSystemName = "1.circle"

    let appNames = ["OneClaw"]
    let bundleIdentifiers = ["com.oneclaw.app"]
    let cliBinaryNames = ["oneclaw"]
    let stateDirs: [String] = []

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/OneClaw",
            "\(home)/Library/Application Support/com.oneclaw.app",
            "\(home)/Library/Caches/OneClaw",
            "\(home)/Library/Caches/com.oneclaw.app",
            "\(home)/Library/Logs/OneClaw",
            "\(home)/Library/HTTPStorages/com.oneclaw.app",
            "\(home)/Library/HTTPStorages/com.oneclaw.app.binarycookies",
            "\(home)/Library/WebKit/com.oneclaw.app",
        ]
    }
}
