import Foundation

struct LobsterAIVariant: ClawVariant {
    let id = "lobsterai"
    let displayName = "LobsterAI"
    let description = "龙虾 AI 助手，Electron 桌面端"
    let iconSystemName = "sparkle"

    let appNames = ["LobsterAI"]
    let bundleIdentifiers = ["com.lobsterai.app"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/LobsterAI",
            "\(home)/Library/Application Support/com.lobsterai.app",
            "\(home)/Library/Caches/LobsterAI",
            "\(home)/Library/Caches/com.lobsterai.app",
            "\(home)/Library/Logs/LobsterAI",
            "\(home)/Library/HTTPStorages/com.lobsterai.app",
            "\(home)/Library/HTTPStorages/com.lobsterai.app.binarycookies",
            "\(home)/Library/WebKit/com.lobsterai.app",
        ]
    }
}
