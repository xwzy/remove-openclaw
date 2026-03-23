import Foundation

struct ClawdBotVariant: ClawVariant {
    let id = "clawdbot"
    let displayName = "ClawdBot"
    let description = "OpenClaw 早期名称（已更名），仍可能存留旧数据"
    let iconSystemName = "clock.arrow.circlepath"

    let appNames = ["ClawdBot", "Clawdbot"]
    let bundleIdentifiers = [
        "com.clawdbot.gateway", "com.clawdbot.mac",
    ]
    let launchAgentLabels = ["com.clawdbot.gateway"]
    let cliBinaryNames = ["clawdbot"]
    let stateDirs = [
        ".clawdbot", ".config/clawdbot", ".cache/clawdbot",
    ]

    var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/clawdbot",
            "\(home)/Library/Application Support/ClawdBot",
            "\(home)/Library/Caches/ClawdBot",
            "\(home)/Library/Logs/ClawdBot",
            "/tmp/clawdbot",
        ]
    }
}
