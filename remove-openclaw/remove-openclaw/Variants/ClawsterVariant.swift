import Foundation

struct ClawsterVariant: ClawVariant {
    let id = "clawster"
    let displayName = "Clawster"
    let description = "Electron 桌面客户端，支持多窗口管理"

    let appNames = ["Clawster"]
    let bundleIdentifiers = ["com.clawster.app"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/Clawster",
            "\(home)/Library/Application Support/com.clawster.app",
            "\(home)/Library/Caches/Clawster",
            "\(home)/Library/Caches/com.clawster.app",
            "\(home)/Library/HTTPStorages/com.clawster.app",
            "\(home)/Library/HTTPStorages/com.clawster.app.binarycookies",
            "\(home)/Library/WebKit/com.clawster.app",
        ]
    }
}
