import Foundation

struct ArkClawVariant: ClawVariant {
    let id = "arkclaw"
    let displayName = "ArkClaw"
    let description = "字节跳动火山引擎推出，支持 24 小时云运行"
    let iconSystemName = "flame"

    let appNames = ["ArkClaw"]
    let bundleIdentifiers = ["com.volcengine.arkclaw"]
    let cliBinaryNames = ["arkclaw"]
    let stateDirs = [".arkclaw", ".config/arkclaw"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/ArkClaw",
            "\(home)/Library/Caches/ArkClaw",
            "\(home)/Library/Caches/com.volcengine.arkclaw",
            "\(home)/Library/Logs/ArkClaw",
        ]
    }
}
