import Foundation

struct ClawVariantScanResult: Identifiable, Sendable {
    let variant: any ClawVariant
    let targets: [OpenClawCleanupTarget]

    var id: String { variant.id }
    var isDetected: Bool { !targets.isEmpty }
    var totalSize: Int64 { targets.reduce(0) { $0 + max($1.size, 0) } }
}

protocol ClawVariant: Sendable {
    nonisolated var id: String { get }
    nonisolated var displayName: String { get }
    nonisolated var description: String { get }
    nonisolated var iconSystemName: String { get }

    nonisolated var appNames: [String] { get }
    nonisolated var bundleIdentifiers: [String] { get }
    nonisolated var launchAgentLabels: [String] { get }
    nonisolated var cliBinaryNames: [String] { get }
    nonisolated var stateDirs: [String] { get }
    nonisolated var extraExplicitPaths: [String] { get }
}

extension ClawVariant {
    nonisolated var iconSystemName: String { "app.badge" }
    nonisolated var appNames: [String] { [] }
    nonisolated var bundleIdentifiers: [String] { [] }
    nonisolated var launchAgentLabels: [String] { [] }
    nonisolated var cliBinaryNames: [String] { [] }
    nonisolated var stateDirs: [String] { [] }
    nonisolated var extraExplicitPaths: [String] { [] }

    nonisolated func allExplicitPaths(home: String) -> [String] {
        var paths: [String] = []

        for dir in stateDirs {
            if dir.hasPrefix("/") {
                paths.append(dir)
            } else {
                paths.append("\(home)/\(dir)")
            }
        }

        for name in appNames {
            paths.append("/Applications/\(name).app")
            paths.append("\(home)/Applications/\(name).app")
        }

        for bundleID in bundleIdentifiers {
            paths.append("\(home)/Library/Preferences/\(bundleID).plist")
            paths.append("\(home)/Library/Saved Application State/\(bundleID).savedstate")
            paths.append("\(home)/Library/Containers/\(bundleID)")
            paths.append("\(home)/Library/Group Containers/\(bundleID)")
            paths.append("\(home)/Library/Group Containers/group.\(bundleID)")
        }

        for label in launchAgentLabels {
            paths.append("\(home)/Library/LaunchAgents/\(label).plist")
        }

        for bin in cliBinaryNames {
            paths.append("/usr/local/bin/\(bin)")
            paths.append("/opt/homebrew/bin/\(bin)")
            paths.append("\(home)/.local/bin/\(bin)")
            paths.append("\(home)/.cargo/bin/\(bin)")
        }

        for path in extraExplicitPaths {
            if path.hasPrefix("/") {
                paths.append(path)
            } else {
                paths.append("\(home)/\(path)")
            }
        }

        return paths
    }
}

struct ClawVariantRegistry {
    nonisolated static let all: [any ClawVariant] = [
        // Original / rebrands
        OpenClawVariant(),
        ClawdBotVariant(),
        MoltbotVariant(),
        // International third-party
        OneClawVariant(),
        ClawAPIVariant(),
        ClawControlVariant(),
        ClawboxVariant(),
        ClawsterVariant(),
        TinyClawVariant(),
        RemoteClawVariant(),
        CoderClawVariant(),
        MiniClawVariant(),
        NemoClawVariant(),
        BunClawVariant(),
        ZeroClawVariant(),
        IronClawVariant(),
        PicoClawVariant(),
        SuperClawVariant(),
        // 国产变体
        LobsterAIVariant(),
        MaClawVariant(),
        OpenClawXVariant(),
        CoPawVariant(),
        EasyClawVariant(),
        LinclawVariant(),
        WorkBuddyVariant(),
        QClawVariant(),
        KimiClawVariant(),
        ArkClawVariant(),
        DuClawVariant(),
        MaxClawVariant(),
        AutoClawVariant(),
        HiClawVariant(),
        MiClawVariant(),
        NanoClawVariant(),
        OpenClawMUVariant(),
    ]
}
