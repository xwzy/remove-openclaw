import Foundation

struct ClawVariantScanResult: Identifiable, Sendable {
    let variant: any ClawVariant
    let targets: [OpenClawCleanupTarget]

    var id: String { variant.id }
    var isDetected: Bool { !targets.isEmpty }
    var totalSize: Int64 { targets.reduce(0) { $0 + max($1.size, 0) } }
}

protocol ClawVariant: Sendable {
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    var iconSystemName: String { get }

    var appNames: [String] { get }
    var bundleIdentifiers: [String] { get }
    var launchAgentLabels: [String] { get }
    var cliBinaryNames: [String] { get }
    var stateDirs: [String] { get }
    var extraExplicitPaths: [String] { get }
}

extension ClawVariant {
    var iconSystemName: String { "app.badge" }
    var appNames: [String] { [] }
    var bundleIdentifiers: [String] { [] }
    var launchAgentLabels: [String] { [] }
    var cliBinaryNames: [String] { [] }
    var stateDirs: [String] { [] }
    var extraExplicitPaths: [String] { [] }

    func allExplicitPaths(home: String) -> [String] {
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
    static let all: [any ClawVariant] = [
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
