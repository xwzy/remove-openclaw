import AppKit
import Foundation

struct OpenClawCleanupTarget: Identifiable, Hashable, Sendable {
    let path: String
    let size: Int64
    let isDirectory: Bool

    var id: String { path }
}

struct OpenClawCleanupResult: Sendable {
    let movedToTrashCount: Int
    let failedCount: Int
    let movedToTrashSize: Int64
    let failedPaths: [String]
    let terminatedProcessCount: Int
    let forceTerminatedProcessCount: Int
    let failedProcessNames: [String]

    static let empty = OpenClawCleanupResult(
        movedToTrashCount: 0,
        failedCount: 0,
        movedToTrashSize: 0,
        failedPaths: [],
        terminatedProcessCount: 0,
        forceTerminatedProcessCount: 0,
        failedProcessNames: []
    )
}

enum OpenClawScanEvent: Sendable {
    case started(total: Int)
    case variantStarted(index: Int, total: Int, name: String)
    case variantFinished(index: Int, total: Int, result: ClawVariantScanResult)
    case completed(results: [ClawVariantScanResult])
}

struct OpenClawUninstallService: Sendable {
    private struct AppResidueCleanupRequest: Sendable, Equatable {
        let query: String
        let displayName: String
    }

    private struct AppResidueCleanupTarget {
        let url: URL
        let resolvedPath: String
        let size: Int64
        let isDirectory: Bool
    }

    private struct InstalledAppDescriptor {
        let path: String
        let appName: String
        let bundleName: String
        let bundleIdentifier: String?
        let executableName: String?
    }

    private struct AppResidueCleanupIdentity {
        let appBundleNames: Set<String>
        let directoryNames: Set<String>
        let binaryNames: Set<String>
        let preferenceNames: Set<String>
        let savedStateNames: Set<String>
        let bundleIdentifiers: Set<String>
        let normalizedNameTokens: Set<String>
    }

    private struct ProcessTerminationSummary {
        let terminatedCount: Int
        let forceTerminatedCount: Int
        let failedProcessNames: [String]
    }

    // MARK: - Per-Variant Scanning

    nonisolated func scanForVariant(_ variant: any ClawVariant) -> [OpenClawCleanupTarget] {
        let identities = makeIdentitiesForVariant(variant)
        var allTargetPaths: Set<String> = []

        for identity in identities {
            let candidatePaths = discoverAppResidueCleanupPaths(for: identity)
            let targets = candidatePaths.compactMap { path in
                prepareAppResidueCleanupTarget(for: path, identity: identity)
            }
            for target in targets {
                allTargetPaths.insert(target.resolvedPath)
            }
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let explicitPaths = variant.allExplicitPaths(home: home)
        for path in explicitPaths {
            let url = URL(fileURLWithPath: path)
            let resolved = url.standardizedFileURL.resolvingSymlinksInPath().path
            if FileManager.default.fileExists(atPath: resolved) {
                allTargetPaths.insert(resolved)
            }
        }

        let collapsed = collapseDescendantCleanupPaths(Array(allTargetPaths))

        return collapsed.compactMap { path -> OpenClawCleanupTarget? in
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
            guard !isDangerousCleanupPath(path, homePath: home) else { return nil }
            let size = estimateCleanupTargetSize(at: url, isDirectory: isDirectory.boolValue)
            return OpenClawCleanupTarget(path: path, size: size, isDirectory: isDirectory.boolValue)
        }
        .sorted { lhs, rhs in
            if lhs.size != rhs.size { return lhs.size > rhs.size }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    nonisolated func scanAllVariants(reportProgress: @escaping @Sendable (OpenClawScanEvent) -> Void) -> [ClawVariantScanResult] {
        let variants = ClawVariantRegistry.all
        reportProgress(.started(total: variants.count))

        var results: [ClawVariantScanResult] = []
        results.reserveCapacity(variants.count)

        for (offset, variant) in variants.enumerated() {
            let index = offset + 1
            reportProgress(.variantStarted(index: index, total: variants.count, name: variant.displayName))

            let result = ClawVariantScanResult(variant: variant, targets: scanForVariant(variant))
            results.append(result)

            reportProgress(.variantFinished(index: index, total: variants.count, result: result))
        }

        reportProgress(.completed(results: results))
        return results
    }

    nonisolated func scanAllVariants() -> [ClawVariantScanResult] {
        scanAllVariants { _ in }
    }

    // MARK: - Aggregated Scanning (for CLI backward compat)

    nonisolated func scanOpenClawTargets() -> [OpenClawCleanupTarget] {
        let results = scanAllVariants()
        var allPaths: Set<String> = []
        for r in results {
            for t in r.targets {
                allPaths.insert(t.path)
            }
        }
        let collapsed = collapseDescendantCleanupPaths(Array(allPaths))
        return collapsed.compactMap { path -> OpenClawCleanupTarget? in
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
            let size = estimateCleanupTargetSize(at: url, isDirectory: isDirectory.boolValue)
            return OpenClawCleanupTarget(path: path, size: size, isDirectory: isDirectory.boolValue)
        }
        .sorted { lhs, rhs in
            if lhs.size != rhs.size { return lhs.size > rhs.size }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    // MARK: - Uninstall

    nonisolated func uninstallOpenClawCompletely(
        preferredTargets: [OpenClawCleanupTarget]? = nil,
        terminateRunningProcesses: Bool = true
    ) async -> OpenClawCleanupResult {
        var totalTerminated = 0
        var totalForceTerminated = 0
        var allFailedProcessNames: [String] = []

        if terminateRunningProcesses {
            for variant in ClawVariantRegistry.all {
                let identities = makeIdentitiesForVariant(variant)
                for identity in identities {
                    let summary = terminateRunningOpenClawProcesses(identity: identity)
                    totalTerminated += summary.terminatedCount
                    totalForceTerminated += summary.forceTerminatedCount
                    allFailedProcessNames.append(contentsOf: summary.failedProcessNames)
                }
            }
        }

        unloadAllClawLaunchAgents()

        let incomingTargets = preferredTargets ?? scanOpenClawTargets()
        let fileResult = await recycleTargets(incomingTargets)

        return OpenClawCleanupResult(
            movedToTrashCount: fileResult.movedToTrashCount,
            failedCount: fileResult.failedCount,
            movedToTrashSize: fileResult.movedToTrashSize,
            failedPaths: fileResult.failedPaths,
            terminatedProcessCount: totalTerminated,
            forceTerminatedProcessCount: totalForceTerminated,
            failedProcessNames: allFailedProcessNames
        )
    }

    nonisolated func uninstallSelectedVariants(
        _ variantResults: [ClawVariantScanResult],
        terminateRunningProcesses: Bool = true
    ) async -> OpenClawCleanupResult {
        var totalTerminated = 0
        var totalForceTerminated = 0
        var allFailedProcessNames: [String] = []

        if terminateRunningProcesses {
            for r in variantResults {
                let identities = makeIdentitiesForVariant(r.variant)
                for identity in identities {
                    let summary = terminateRunningOpenClawProcesses(identity: identity)
                    totalTerminated += summary.terminatedCount
                    totalForceTerminated += summary.forceTerminatedCount
                    allFailedProcessNames.append(contentsOf: summary.failedProcessNames)
                }
            }
        }

        let selectedLabels = variantResults.flatMap { $0.variant.launchAgentLabels }
        unloadSpecificLaunchAgents(labels: selectedLabels)
        dynamicUnloadClawLaunchAgents()

        let allTargets = variantResults.flatMap { $0.targets }
        let fileResult = await recycleTargets(allTargets)

        return OpenClawCleanupResult(
            movedToTrashCount: fileResult.movedToTrashCount,
            failedCount: fileResult.failedCount,
            movedToTrashSize: fileResult.movedToTrashSize,
            failedPaths: fileResult.failedPaths,
            terminatedProcessCount: totalTerminated,
            forceTerminatedProcessCount: totalForceTerminated,
            failedProcessNames: allFailedProcessNames
        )
    }

    private struct FileCleanupResult {
        let movedToTrashCount: Int
        let failedCount: Int
        let movedToTrashSize: Int64
        let failedPaths: [String]
    }

    private nonisolated func recycleTargets(_ targets: [OpenClawCleanupTarget]) async -> FileCleanupResult {
        let uniquePaths = collapseDescendantCleanupPaths(targets.map(\.path))
        guard !uniquePaths.isEmpty else {
            return FileCleanupResult(movedToTrashCount: 0, failedCount: 0, movedToTrashSize: 0, failedPaths: [])
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var movedToTrashCount = 0
        var failedCount = 0
        var movedToTrashSize: Int64 = 0
        var failedPaths: [String] = []

        for path in uniquePaths {
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }
            guard !isDangerousCleanupPath(path, homePath: home) else { continue }
            let size = estimateCleanupTargetSize(at: url, isDirectory: isDirectory.boolValue)
            let success = await recycleItem(at: url)
            if success {
                movedToTrashCount += 1
                movedToTrashSize += size
            } else {
                failedCount += 1
                if failedPaths.count < 5 { failedPaths.append(path) }
            }
        }

        return FileCleanupResult(
            movedToTrashCount: movedToTrashCount,
            failedCount: failedCount,
            movedToTrashSize: movedToTrashSize,
            failedPaths: failedPaths
        )
    }

    // MARK: - Identity Construction from ClawVariant

    private nonisolated func makeIdentitiesForVariant(_ variant: any ClawVariant) -> [AppResidueCleanupIdentity] {
        var identities: [AppResidueCleanupIdentity] = []
        let names = variant.appNames + [variant.displayName]
        for name in names {
            guard let request = makeAppResidueCleanupRequest(from: name) else { continue }
            guard let identity = makeAppResidueCleanupIdentity(from: request) else { continue }
            identities.append(identity)
        }
        for bundleID in variant.bundleIdentifiers {
            guard let request = makeAppResidueCleanupRequest(from: bundleID) else { continue }
            guard let identity = makeAppResidueCleanupIdentity(from: request) else { continue }
            identities.append(identity)
        }
        return identities
    }

    // MARK: - LaunchAgent Management

    private nonisolated func unloadAllClawLaunchAgents() {
        let allLabels = ClawVariantRegistry.all.flatMap { $0.launchAgentLabels }
        unloadSpecificLaunchAgents(labels: allLabels)
        dynamicUnloadClawLaunchAgents()
    }

    private nonisolated func unloadSpecificLaunchAgents(labels: [String]) {
        let uid = getuid()
        for label in labels {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["bootout", "gui/\(uid)/\(label)"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    private nonisolated static let clawPlistKeywords: [String] = [
        "openclaw", "clawdbot", "moltbot", "moldbot", "molt.",
        "oneclaw", "remoteclaw", "coderclaw", "zeroclaw", "ironclaw",
        "picoclaw", "miniclaw", "nemoclaw", "nanoclaw", "bunclaw",
        "lobsterai", "clawster", "clawapi", "clawcontrol", "easyclaw",
        "maclaw", "copaw", "workbuddy", "qclaw", "kimiclaw",
        "arkclaw", "duclaw", "maxclaw", "autoclaw", "hiclaw", "miclaw",
    ]

    private nonisolated func dynamicUnloadClawLaunchAgents() {
        let uid = getuid()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let launchAgentsDir = "\(home)/Library/LaunchAgents"
        if let files = try? FileManager.default.contentsOfDirectory(atPath: launchAgentsDir) {
            for file in files where file.hasSuffix(".plist") {
                let lower = file.lowercased()
                let isClawRelated = Self.clawPlistKeywords.contains { lower.contains($0) }
                if isClawRelated {
                    let label = String(file.dropLast(6))
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                    process.arguments = ["bootout", "gui/\(uid)/\(label)"]
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice
                    try? process.run()
                    process.waitUntilExit()
                }
            }
        }
    }

    // MARK: - Request / Identity Construction

    private nonisolated func makeAppResidueCleanupRequest(from rawInput: String) -> AppResidueCleanupRequest? {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return nil }

        if looksLikeBundleIdentifier(trimmedInput) {
            let bundleID = trimmedInput.lowercased()
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmedInput) {
                let appName = appURL.deletingPathExtension().lastPathComponent
                let displayName = appName.isEmpty ? bundleID : appName
                return AppResidueCleanupRequest(query: bundleID, displayName: displayName)
            }
            let inferredName = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
            return AppResidueCleanupRequest(query: bundleID, displayName: inferredName)
        }

        let normalizedName = normalizedAppDisplayName(from: trimmedInput)
        guard normalizedIdentityToken(normalizedName).count >= 2 else { return nil }
        return AppResidueCleanupRequest(query: normalizedName, displayName: normalizedName)
    }

    private nonisolated func makeAppResidueCleanupIdentity(
        from request: AppResidueCleanupRequest
    ) -> AppResidueCleanupIdentity? {
        var appBundleNames: Set<String> = []
        var directoryNames: Set<String> = []
        var binaryNames: Set<String> = []
        var preferenceNames: Set<String> = []
        var savedStateNames: Set<String> = []
        var bundleIdentifiers: Set<String> = []
        var normalizedNameTokens: Set<String> = []

        if looksLikeBundleIdentifier(request.query) {
            bundleIdentifiers.insert(request.query.lowercased())
        }

        let matchedApps = matchedInstalledApps(for: request)
        for app in matchedApps {
            appBundleNames.insert(app.bundleName.lowercased())
            if let bundleID = app.bundleIdentifier?.lowercased() {
                bundleIdentifiers.insert(bundleID)
            }
            if let executable = app.executableName?.lowercased() {
                binaryNames.insert(executable)
                appendAppResidueIdentityVariants(
                    from: executable,
                    directoryNames: &directoryNames,
                    binaryNames: &binaryNames,
                    normalizedNameTokens: &normalizedNameTokens
                )
            }
        }

        appendAppResidueIdentityVariants(
            from: request.displayName,
            directoryNames: &directoryNames,
            binaryNames: &binaryNames,
            normalizedNameTokens: &normalizedNameTokens
        )
        appendAppResidueIdentityVariants(
            from: request.query,
            directoryNames: &directoryNames,
            binaryNames: &binaryNames,
            normalizedNameTokens: &normalizedNameTokens
        )

        for bundleID in bundleIdentifiers {
            preferenceNames.insert("\(bundleID).plist")
            savedStateNames.insert("\(bundleID).savedstate")
            normalizedNameTokens.insert(normalizedIdentityToken(bundleID))
            if let suffix = bundleID.split(separator: ".").last {
                appendAppResidueIdentityVariants(
                    from: String(suffix),
                    directoryNames: &directoryNames,
                    binaryNames: &binaryNames,
                    normalizedNameTokens: &normalizedNameTokens
                )
            }
        }

        for directoryName in directoryNames {
            appBundleNames.insert("\(directoryName).app")
            preferenceNames.insert("\(directoryName).plist")
            savedStateNames.insert("\(directoryName).savedstate")
        }

        appBundleNames = Set(appBundleNames.filter { $0.count >= 3 && $0.hasSuffix(".app") })
        directoryNames = Set(directoryNames.filter { $0.count >= 2 })
        binaryNames = Set(binaryNames.filter { $0.count >= 2 && !$0.contains(" ") && !$0.contains(".") })
        preferenceNames = Set(preferenceNames.filter { $0.count >= 6 && $0.hasSuffix(".plist") })
        savedStateNames = Set(savedStateNames.filter { $0.count >= 11 && $0.hasSuffix(".savedstate") })
        bundleIdentifiers = Set(bundleIdentifiers.filter { $0.count >= 3 })
        normalizedNameTokens = Set(normalizedNameTokens.filter { $0.count >= 2 })

        guard !appBundleNames.isEmpty ||
            !directoryNames.isEmpty ||
            !binaryNames.isEmpty ||
            !bundleIdentifiers.isEmpty else {
            return nil
        }

        return AppResidueCleanupIdentity(
            appBundleNames: appBundleNames,
            directoryNames: directoryNames,
            binaryNames: binaryNames,
            preferenceNames: preferenceNames,
            savedStateNames: savedStateNames,
            bundleIdentifiers: bundleIdentifiers,
            normalizedNameTokens: normalizedNameTokens
        )
    }

    private nonisolated func appendAppResidueIdentityVariants(
        from rawValue: String,
        directoryNames: inout Set<String>,
        binaryNames: inout Set<String>,
        normalizedNameTokens: inout Set<String>
    ) {
        let normalizedDisplayName = normalizedAppDisplayName(from: rawValue).lowercased()
        guard !normalizedDisplayName.isEmpty else { return }

        var values: Set<String> = []
        values.insert(normalizedDisplayName)

        let components = normalizedDisplayName
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        if !components.isEmpty {
            values.insert(components.joined())
            values.insert(components.joined(separator: "-"))
            values.insert(components.joined(separator: "_"))
        }

        for value in values {
            guard value.count >= 2 else { continue }
            directoryNames.insert(value)
            normalizedNameTokens.insert(normalizedIdentityToken(value))
            if !value.contains(" ") && !value.contains(".") {
                binaryNames.insert(value)
            }
        }
    }

    // MARK: - Installed App Matching

    private nonisolated func matchedInstalledApps(for request: AppResidueCleanupRequest) -> [InstalledAppDescriptor] {
        var matches: [InstalledAppDescriptor] = []
        var seenPaths: Set<String> = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let normalizedQuery = normalizedIdentityToken(request.displayName)

        if looksLikeBundleIdentifier(request.query),
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: request.query),
           let descriptor = installedAppDescriptor(from: appURL) {
            let inserted = seenPaths.insert(descriptor.path).inserted
            if inserted { matches.append(descriptor) }
        }

        guard normalizedQuery.count >= 2 else { return matches }

        let roots = ["/Applications", "\(home)/Applications"]
        for root in roots {
            let rootURL = URL(fileURLWithPath: root)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            while let candidateURL = enumerator.nextObject() as? URL {
                guard candidateURL.pathExtension.lowercased() == "app" else { continue }
                let appName = candidateURL.deletingPathExtension().lastPathComponent
                let normalizedAppName = normalizedIdentityToken(appName)
                guard normalizedAppName.count >= 2 else { continue }
                let matchesQuery =
                    normalizedAppName == normalizedQuery ||
                    normalizedAppName.hasPrefix(normalizedQuery) ||
                    normalizedQuery.hasPrefix(normalizedAppName)
                guard matchesQuery else { continue }
                guard let descriptor = installedAppDescriptor(from: candidateURL) else { continue }
                let inserted = seenPaths.insert(descriptor.path).inserted
                if inserted { matches.append(descriptor) }
            }
        }

        return matches
    }

    private nonisolated func installedAppDescriptor(from appURL: URL) -> InstalledAppDescriptor? {
        let appName = appURL.deletingPathExtension().lastPathComponent
        let bundleName = appURL.lastPathComponent
        guard !appName.isEmpty else { return nil }
        let bundle = Bundle(url: appURL)
        let bundleIdentifier = bundle?.bundleIdentifier
        let executableName = bundle?.object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        return InstalledAppDescriptor(
            path: canonicalPath(appURL.path), appName: appName,
            bundleName: bundleName, bundleIdentifier: bundleIdentifier,
            executableName: executableName
        )
    }

    // MARK: - Path Discovery

    private nonisolated func discoverAppResidueCleanupPaths(for identity: AppResidueCleanupIdentity) -> [String] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        var candidates: Set<String> = []

        let explicitPaths = explicitAppResiduePaths(for: identity, homePath: home)
        for explicitPath in explicitPaths {
            if fileManager.fileExists(atPath: explicitPath) {
                let candidate = canonicalPath(explicitPath)
                if isAppResiduePathAllowedForCleanup(candidate, identity: identity) {
                    candidates.insert(candidate)
                }
            }
        }

        for root in appResidueSearchableRoots(homePath: home) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            guard let children = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: root), includingPropertiesForKeys: nil, options: []
            ) else { continue }

            for child in children {
                appendAppResidueCandidate(child.path, identity: identity, candidates: &candidates)
                if shouldInspectAppResidueGrandchildren(root: root, childURL: child, fileManager: fileManager),
                   let grandchildren = try? fileManager.contentsOfDirectory(
                    at: child, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
                   ) {
                    for grandchild in grandchildren {
                        appendAppResidueCandidate(grandchild.path, identity: identity, candidates: &candidates)
                    }
                }
            }
        }

        let filtered = candidates.filter { isAppResiduePathAllowedForCleanup($0, identity: identity) }
        return collapseDescendantCleanupPaths(Array(filtered))
    }

    private nonisolated func appendAppResidueCandidate(
        _ rawPath: String, identity: AppResidueCleanupIdentity, candidates: inout Set<String>
    ) {
        let normalizedPath = canonicalPath(rawPath)
        guard isAppResiduePathAllowedForCleanup(normalizedPath, identity: identity) else { return }
        candidates.insert(normalizedPath)
    }

    private nonisolated func appResidueSearchableRoots(homePath: String) -> [String] {
        [
            "/Applications",
            "\(homePath)/Applications",
            "\(homePath)/Library/Application Support",
            "\(homePath)/Library/Caches",
            "\(homePath)/Library/Preferences",
            "\(homePath)/Library/Saved Application State",
            "\(homePath)/Library/Logs",
            "\(homePath)/Library/Containers",
            "\(homePath)/Library/Group Containers",
            "\(homePath)/Library/LaunchAgents",
            "\(homePath)/.config",
            "\(homePath)/.cache",
            "\(homePath)/.local/share",
            "\(homePath)/.local/bin",
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/local/share",
            "/opt/homebrew/share",
        ]
    }

    private nonisolated func shouldInspectAppResidueGrandchildren(
        root: String, childURL: URL, fileManager: FileManager
    ) -> Bool {
        let normalizedRoot = canonicalPath(root).lowercased()
        let home = fileManager.homeDirectoryForCurrentUser.path.lowercased()

        let rootsSupportingGrandchildren: Set<String> = [
            "\(home)/library/application support",
            "\(home)/library/caches",
            "\(home)/library/logs",
            "\(home)/library/containers",
            "\(home)/library/group containers",
            "\(home)/.config",
            "\(home)/.cache",
            "\(home)/.local/share",
            "/usr/local/share",
            "/opt/homebrew/share",
        ]

        guard rootsSupportingGrandchildren.contains(normalizedRoot) else { return false }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: childURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return true
    }

    // MARK: - Path Validation

    private nonisolated func isAppResiduePathAllowedForCleanup(
        _ path: String, identity: AppResidueCleanupIdentity
    ) -> Bool {
        let normalizedPath = canonicalPath(path)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for root in appResidueSearchableRoots(homePath: home).map(canonicalPath) {
            guard isSamePathOrDescendant(normalizedPath, of: root) else { continue }
            return appResiduePathIdentityMatches(
                normalizedPath, withinRoot: root, homePath: home, identity: identity
            )
        }
        return false
    }

    private nonisolated func appResiduePathIdentityMatches(
        _ path: String, withinRoot root: String, homePath: String,
        identity: AppResidueCleanupIdentity
    ) -> Bool {
        let lowerPath = path.lowercased()
        let lowerRoot = root.lowercased()
        let lowerHome = homePath.lowercased()

        let pathComponents = URL(fileURLWithPath: lowerPath).pathComponents
        let rootComponents = URL(fileURLWithPath: lowerRoot).pathComponents
        guard pathComponents.count > rootComponents.count else { return false }

        let relativeComponents = Array(pathComponents.dropFirst(rootComponents.count))
        guard let firstComponent = relativeComponents.first else { return false }

        if lowerRoot == "/applications" || lowerRoot == "\(lowerHome)/applications" {
            guard firstComponent.hasSuffix(".app") else { return false }
            if identity.appBundleNames.contains(firstComponent) { return true }
            let bundleName = String(firstComponent.dropLast(4))
            return appResidueComponentMatchesIdentity(bundleName, identity: identity)
        }

        if lowerRoot == "\(lowerHome)/library/preferences" {
            if identity.preferenceNames.contains(firstComponent) { return true }
            if firstComponent.hasSuffix(".plist") {
                let withoutExtension = String(firstComponent.dropLast(6))
                return appResidueComponentMatchesIdentity(withoutExtension, identity: identity)
            }
            return false
        }

        if lowerRoot == "\(lowerHome)/library/saved application state" {
            if identity.savedStateNames.contains(firstComponent) { return true }
            if firstComponent.hasSuffix(".savedstate") {
                let withoutExtension = String(firstComponent.dropLast(11))
                return appResidueComponentMatchesIdentity(withoutExtension, identity: identity)
            }
            return false
        }

        if lowerRoot == "\(lowerHome)/library/containers" {
            return identity.bundleIdentifiers.contains(firstComponent)
        }

        if lowerRoot == "\(lowerHome)/library/group containers" {
            for bundleID in identity.bundleIdentifiers {
                if firstComponent == bundleID || firstComponent == "group.\(bundleID)" || firstComponent.hasSuffix(bundleID) {
                    return true
                }
            }
            return false
        }

        if lowerRoot == "\(lowerHome)/library/launchagents" {
            if identity.preferenceNames.contains(firstComponent) { return true }
            if firstComponent.hasSuffix(".plist") {
                let withoutExtension = String(firstComponent.dropLast(6))
                return appResidueComponentMatchesIdentity(withoutExtension, identity: identity)
            }
            return false
        }

        if lowerRoot == "/usr/local/bin" || lowerRoot == "/opt/homebrew/bin" ||
           lowerRoot == "\(lowerHome)/.local/bin" {
            return identity.binaryNames.contains(firstComponent)
        }

        if lowerRoot == "/usr/local/share" || lowerRoot == "/opt/homebrew/share" {
            let shallowComponents = Array(relativeComponents.prefix(2))
            return shallowComponents.contains {
                appResidueComponentMatchesIdentity($0, identity: identity)
            }
        }

        let managedRoots = [
            "\(lowerHome)/library/application support",
            "\(lowerHome)/library/caches",
            "\(lowerHome)/library/logs",
            "\(lowerHome)/.config",
            "\(lowerHome)/.cache",
            "\(lowerHome)/.local/share",
        ]
        if managedRoots.contains(lowerRoot) {
            let shallowComponents = Array(relativeComponents.prefix(2))
            return shallowComponents.contains {
                appResidueComponentMatchesIdentity($0, identity: identity)
            }
        }

        return false
    }

    private nonisolated func appResidueComponentMatchesIdentity(
        _ rawComponent: String, identity: AppResidueCleanupIdentity
    ) -> Bool {
        let lowerComponent = rawComponent.lowercased()
        if identity.directoryNames.contains(lowerComponent) ||
            identity.binaryNames.contains(lowerComponent) ||
            identity.bundleIdentifiers.contains(lowerComponent) {
            return true
        }
        let normalized = normalizedIdentityToken(lowerComponent)
        guard !normalized.isEmpty else { return false }
        return identity.normalizedNameTokens.contains(normalized)
    }

    private nonisolated func explicitAppResiduePaths(
        for identity: AppResidueCleanupIdentity, homePath: String
    ) -> [String] {
        var paths: Set<String> = []

        for bundleName in identity.appBundleNames {
            guard let safeBundleName = safeCleanupPathComponent(bundleName) else { continue }
            paths.insert("/Applications/\(safeBundleName)")
            paths.insert("\(homePath)/Applications/\(safeBundleName)")
        }

        for directoryName in identity.directoryNames {
            guard let safeDirectoryName = safeCleanupPathComponent(directoryName) else { continue }
            paths.insert("\(homePath)/Library/Application Support/\(safeDirectoryName)")
            paths.insert("\(homePath)/Library/Caches/\(safeDirectoryName)")
            paths.insert("\(homePath)/Library/Logs/\(safeDirectoryName)")
            paths.insert("\(homePath)/.config/\(safeDirectoryName)")
            paths.insert("\(homePath)/.cache/\(safeDirectoryName)")
            paths.insert("\(homePath)/.local/share/\(safeDirectoryName)")
            paths.insert("/usr/local/share/\(safeDirectoryName)")
            paths.insert("/opt/homebrew/share/\(safeDirectoryName)")
        }

        for preferenceName in identity.preferenceNames {
            guard let safePreferenceName = safeCleanupPathComponent(preferenceName) else { continue }
            paths.insert("\(homePath)/Library/Preferences/\(safePreferenceName)")
            paths.insert("\(homePath)/Library/LaunchAgents/\(safePreferenceName)")
        }

        for savedStateName in identity.savedStateNames {
            guard let safeSavedStateName = safeCleanupPathComponent(savedStateName) else { continue }
            paths.insert("\(homePath)/Library/Saved Application State/\(safeSavedStateName)")
        }

        for binaryName in identity.binaryNames {
            guard let safeBinaryName = safeCleanupPathComponent(binaryName) else { continue }
            paths.insert("/usr/local/bin/\(safeBinaryName)")
            paths.insert("/opt/homebrew/bin/\(safeBinaryName)")
            paths.insert("\(homePath)/.local/bin/\(safeBinaryName)")
        }

        for bundleID in identity.bundleIdentifiers {
            guard let safeBundleID = safeCleanupPathComponent(bundleID) else { continue }
            paths.insert("\(homePath)/Library/Containers/\(safeBundleID)")
            paths.insert("\(homePath)/Library/Group Containers/\(safeBundleID)")
            paths.insert("\(homePath)/Library/Group Containers/group.\(safeBundleID)")
        }

        return Array(paths)
    }

    private nonisolated func safeCleanupPathComponent(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains("/") else { return nil }
        guard trimmed != "." && trimmed != ".." else { return nil }
        return trimmed
    }

    private nonisolated func prepareAppResidueCleanupTarget(
        for path: String, identity: AppResidueCleanupIdentity
    ) -> AppResidueCleanupTarget? {
        let fileManager = FileManager.default
        let standardizedURL = URL(fileURLWithPath: path).standardizedFileURL
        let resolvedURL = standardizedURL.resolvingSymlinksInPath()
        let resolvedPath = resolvedURL.path

        guard isAppResiduePathAllowedForCleanup(resolvedPath, identity: identity) else { return nil }

        let home = fileManager.homeDirectoryForCurrentUser.path
        guard !isDangerousCleanupPath(resolvedPath, homePath: home) else { return nil }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) else { return nil }

        let size = estimateCleanupTargetSize(at: resolvedURL, isDirectory: isDirectory.boolValue)
        return AppResidueCleanupTarget(
            url: resolvedURL, resolvedPath: resolvedPath,
            size: size, isDirectory: isDirectory.boolValue
        )
    }

    private nonisolated func isDangerousCleanupPath(_ path: String, homePath: String) -> Bool {
        let canonical = canonicalPath(path)
        let protectedRoots = Set(appResidueSearchableRoots(homePath: homePath).map(canonicalPath))
        if protectedRoots.contains(canonical) { return true }

        let extraProtected: Set<String> = [
            canonicalPath("/"),
            canonicalPath(homePath),
            canonicalPath("\(homePath)/Library"),
            canonicalPath("\(homePath)/Library/Application Support"),
            canonicalPath("\(homePath)/Library/Caches"),
            canonicalPath("\(homePath)/Library/Logs"),
            canonicalPath("\(homePath)/Library/Preferences"),
            canonicalPath("\(homePath)/Library/Containers"),
            canonicalPath("\(homePath)/Library/Group Containers"),
            canonicalPath("\(homePath)/Library/Saved Application State"),
            canonicalPath("\(homePath)/Library/LaunchAgents"),
            canonicalPath("\(homePath)/.config"),
            canonicalPath("\(homePath)/.cache"),
            canonicalPath("\(homePath)/.local"),
            canonicalPath("\(homePath)/.local/share"),
            canonicalPath("\(homePath)/.local/bin"),
            canonicalPath("/usr/local"),
            canonicalPath("/opt/homebrew"),
            canonicalPath("/usr/local/share"),
            canonicalPath("/opt/homebrew/share"),
            canonicalPath("/usr/local/bin"),
            canonicalPath("/opt/homebrew/bin"),
        ]
        return extraProtected.contains(canonical)
    }

    // MARK: - Size Estimation

    private nonisolated func estimateCleanupTargetSize(at url: URL, isDirectory: Bool) -> Int64 {
        if !isDirectory {
            let resources = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            return Int64(resources?.totalFileAllocatedSize ?? resources?.fileSize ?? 0)
        }

        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        while let fileURL = enumerator.nextObject() as? URL {
            let resources = try? fileURL.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]
            )
            if resources?.isDirectory == true { continue }
            totalSize += Int64(resources?.totalFileAllocatedSize ?? resources?.fileSize ?? 0)
        }

        return totalSize
    }

    // MARK: - Recycle

    private nonisolated func recycleItem(at url: URL) async -> Bool {
        let workspaceSucceeded = await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle([url]) { _, error in
                continuation.resume(returning: error == nil)
            }
        }

        if workspaceSucceeded { return true }

        do {
            _ = try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Process Termination

    private nonisolated func terminateRunningOpenClawProcesses(
        identity: AppResidueCleanupIdentity
    ) -> ProcessTerminationSummary {
        let runningApps = NSWorkspace.shared.runningApplications
        let targets = runningApps.filter { isRunningAppMatched($0, identity: identity) }

        guard !targets.isEmpty else {
            return ProcessTerminationSummary(
                terminatedCount: 0, forceTerminatedCount: 0, failedProcessNames: []
            )
        }

        var terminatedCount = 0
        var forceTerminatedCount = 0
        var failedProcessNames: [String] = []

        for app in targets {
            if app.isTerminated { continue }
            let processLabel = processDisplayName(for: app)

            if app.terminate(), waitForTermination(of: app, timeout: 1.5) {
                terminatedCount += 1
                continue
            }

            if app.forceTerminate(), waitForTermination(of: app, timeout: 1.5) {
                terminatedCount += 1
                forceTerminatedCount += 1
                continue
            }

            if failedProcessNames.count < 5 {
                failedProcessNames.append(processLabel)
            }
        }

        return ProcessTerminationSummary(
            terminatedCount: terminatedCount,
            forceTerminatedCount: forceTerminatedCount,
            failedProcessNames: failedProcessNames
        )
    }

    private nonisolated func isRunningAppMatched(
        _ app: NSRunningApplication, identity: AppResidueCleanupIdentity
    ) -> Bool {
        if let bundleID = app.bundleIdentifier?.lowercased(),
           identity.bundleIdentifiers.contains(bundleID) {
            return true
        }
        if let bundleName = app.bundleURL?.lastPathComponent.lowercased(),
           identity.appBundleNames.contains(bundleName) {
            return true
        }
        if let localizedName = app.localizedName?.lowercased(),
           appResidueComponentMatchesIdentity(localizedName, identity: identity) {
            return true
        }
        if let executableURL = app.executableURL {
            let executableName = executableURL.lastPathComponent.lowercased()
            if identity.binaryNames.contains(executableName) { return true }
            if appResidueComponentMatchesIdentity(executableName, identity: identity) { return true }
        }
        return false
    }

    private nonisolated func processDisplayName(for app: NSRunningApplication) -> String {
        if let name = app.localizedName, !name.isEmpty { return name }
        if let bundleID = app.bundleIdentifier, !bundleID.isEmpty { return bundleID }
        if let path = app.bundleURL?.path { return path }
        return "pid:\(app.processIdentifier)"
    }

    private nonisolated func waitForTermination(of app: NSRunningApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !app.isTerminated && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return app.isTerminated
    }

    // MARK: - Utility

    private nonisolated func normalizedAppDisplayName(from rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.contains("/") {
            value = URL(fileURLWithPath: value).deletingPathExtension().lastPathComponent
        }
        if value.lowercased().hasSuffix(".app") {
            value = String(value.dropLast(4))
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private nonisolated func normalizedIdentityToken(_ rawValue: String) -> String {
        let lowered = rawValue.lowercased()
        let scalars = lowered.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private nonisolated func looksLikeBundleIdentifier(_ rawValue: String) -> Bool {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.count >= 5 else { return false }
        guard value.contains(".") else { return false }
        let parts = value.split(separator: ".")
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { character in
                character.isLetter || character.isNumber || character == "-" || character == "_"
            }
        }
    }

    private nonisolated func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    private nonisolated func isSamePathOrDescendant(_ path: String, of parentPath: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        let normalizedParent = URL(fileURLWithPath: parentPath).standardizedFileURL.pathComponents
        guard normalizedParent.count <= normalizedPath.count else { return false }
        return zip(normalizedParent, normalizedPath).allSatisfy(==)
    }

    private nonisolated func collapseDescendantCleanupPaths(_ paths: [String]) -> [String] {
        let sorted = Array(Set(paths.map(canonicalPath))).sorted {
            if $0.count == $1.count {
                return $0.localizedStandardCompare($1) == .orderedAscending
            }
            return $0.count < $1.count
        }
        var kept: [String] = []
        for path in sorted {
            if kept.contains(where: { isSamePathOrDescendant(path, of: $0) }) { continue }
            kept.append(path)
        }
        return kept
    }
}
