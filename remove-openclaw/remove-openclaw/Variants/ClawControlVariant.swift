import Foundation

struct ClawControlVariant: ClawVariant {
    let id = "clawcontrol"
    let displayName = "ClawControl"
    let description = "带可视化面板的 OpenClaw 管理工具"

    let appNames = ["ClawControl"]
    let bundleIdentifiers = ["com.claw.control"]
    let cliBinaryNames = ["clawcontrol"]
    let stateDirs = [".config/clawcontrol"]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/ClawControl",
            "\(home)/Library/Application Support/clawcontrol",
            "\(home)/Library/Caches/ClawControl",
            "\(home)/Library/Logs/ClawControl",
            "\(home)/Library/HTTPStorages/com.claw.control",
            "\(home)/Library/HTTPStorages/com.claw.control.binarycookies",
            "\(home)/Library/WebKit/com.claw.control",
        ]
    }
}
