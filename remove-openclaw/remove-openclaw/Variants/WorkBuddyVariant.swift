import Foundation

struct WorkBuddyVariant: ClawVariant {
    let id = "workbuddy"
    let displayName = "WorkBuddy"
    let description = "腾讯出品，微信直连的 AI 工作助手"
    let iconSystemName = "person.2"

    let appNames = ["WorkBuddy"]
    let bundleIdentifiers = ["com.tencent.workbuddy"]
    let stateDirs = [".workbuddy", ".config/workbuddy"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/WorkBuddy",
            "\(home)/Library/Caches/WorkBuddy",
            "\(home)/Library/Caches/com.tencent.workbuddy",
            "\(home)/Library/Logs/WorkBuddy",
        ]
    }
}
