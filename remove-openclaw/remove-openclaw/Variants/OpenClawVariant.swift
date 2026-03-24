import Foundation

struct OpenClawVariant: ClawVariant {
    let id = "openclaw"
    let displayName = "OpenClaw"
    let description = "开源 AI 助手，支持多渠道（WhatsApp/Telegram/Slack 等）"
    let iconSystemName = "bubble.left.and.text.bubble.right"

    let appNames = ["OpenClaw"]
    let bundleIdentifiers = [
        "ai.openclaw.mac", "ai.openclaw.mac.debug",
        "ai.openclaw.gateway", "ai.openclaw.node",
        "com.openclaw.gateway",
    ]
    let launchAgentLabels = [
        "ai.openclaw.mac", "ai.openclaw.gateway",
        "ai.openclaw.node", "com.openclaw.gateway",
    ]
    let cliBinaryNames = ["openclaw", "openclaw-cn", "clawhub", "clawdhub"]
    let stateDirs = [".openclaw", ".config/openclaw", ".cache/openclaw"]

    nonisolated var extraExplicitPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var paths: [String] = [
            "\(home)/Library/Application Support/OpenClaw",
            "\(home)/Library/Caches/OpenClaw",
            "\(home)/Library/Logs/OpenClaw",
            "/tmp/openclaw",
            "/tmp/openclaw-\(getuid())",
        ]

        let nodeCliBins = ["openclaw", "openclaw-cn", "clawhub", "clawdhub"]

        let nodenvRoot = "\(home)/.nodenv"
        if FileManager.default.fileExists(atPath: nodenvRoot) {
            if let versions = try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: "\(nodenvRoot)/versions"),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for versionDir in versions {
                    for bin in nodeCliBins {
                        paths.append("\(versionDir.path)/bin/\(bin)")
                        paths.append("\(versionDir.path)/lib/node_modules/\(bin)")
                    }
                }
            }
            for bin in nodeCliBins {
                paths.append("\(nodenvRoot)/shims/\(bin)")
            }
        }

        if let prefix = resolveNpmGlobalPrefix() {
            for bin in nodeCliBins {
                paths.append("\(prefix)/bin/\(bin)")
                paths.append("\(prefix)/lib/node_modules/\(bin)")
            }
        }

        let shimDirs = [
            "\(home)/.volta/bin",
            "\(home)/.asdf/shims",
            "\(home)/.bun/bin",
            "\(home)/.npm-global/bin",
        ]
        for shimDir in shimDirs {
            for bin in nodeCliBins {
                paths.append("\(shimDir)/\(bin)")
            }
        }

        return paths
    }

    private nonisolated func resolveNpmGlobalPrefix() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["npm", "prefix", "-g"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(5)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        if process.isRunning {
            process.terminate()
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let prefix = output, !prefix.isEmpty else { return nil }
        return prefix
    }
}
