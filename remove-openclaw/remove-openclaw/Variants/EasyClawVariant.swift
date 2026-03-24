import Foundation

struct EasyClawVariant: ClawVariant {
    let id = "easyclaw"
    let displayName = "EasyClaw"
    let description = "面向非技术用户的傻瓜式 OpenClaw 客户端"
    let iconSystemName = "hand.thumbsup"

    let appNames = ["EasyClaw"]
    let bundleIdentifiers = ["com.easyclaw.app"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/EasyClaw",
            "\(home)/Library/Application Support/com.easyclaw.app",
            "\(home)/Library/Caches/EasyClaw",
            "\(home)/Library/HTTPStorages/com.easyclaw.app",
            "\(home)/Library/HTTPStorages/com.easyclaw.app.binarycookies",
            "\(home)/Library/WebKit/com.easyclaw.app",
        ]
    }
}
