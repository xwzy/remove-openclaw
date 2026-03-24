import Foundation

struct MoltbotVariant: ClawVariant {
    let id = "moltbot"
    let displayName = "Moltbot"
    let description = "OpenClaw 另一个早期名称，可能遗留旧配置"
    let iconSystemName = "clock.arrow.circlepath"

    let appNames = ["Moltbot", "MoltBot", "Moldbot"]
    let bundleIdentifiers = [
        "net.moltai.moltbot", "com.moltbot.mac",
        "com.moltbot.mac.debug", "com.moltbot.gateway",
        "bot.molt.gateway",
    ]
    let launchAgentLabels = [
        "net.moltai.moltbot", "com.moltbot.gateway", "bot.molt.gateway",
    ]
    let cliBinaryNames = ["moltbot"]
    let stateDirs = [
        ".moltbot", ".moldbot", ".config/moltbot", ".cache/moltbot",
    ]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Application Support/Moltbot",
            "\(home)/Library/Caches/Moltbot",
            "\(home)/Library/Logs/Moltbot",
        ]
    }
}
