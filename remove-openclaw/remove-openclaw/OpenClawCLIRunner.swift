import Foundation

@MainActor
struct OpenClawCLIRunner {
    static let cliFlag = "--cli"

    private let service = OpenClawUninstallService()
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    struct Configuration {
        var showHelp = false
        var shouldUninstall = false
        var confirmUninstall = false
        var targetFileURL: URL?
        var strictTargetFile = false
        var failOnWarnings = false
        var shouldListPaths = false
        var terminateRunningProcesses = true
        var dryRun = false
        var exportURL: URL?
        var jsonOutputURL: URL?
    }

    private struct JSONRunReport: Codable {
        let generatedAt: String
        let arguments: [String]
        let options: JSONOptions
        let scan: JSONScan
        var warnings: [String]
        var warningStats: JSONWarningStats?
        var selectedTargetsPath: String?
        var selectedTargets: JSONScan?
        var exportedTargetsPath: String?
        var dryRun: JSONDryRun?
        var uninstall: JSONUninstall?
        var exitCode: Int32
    }

    private struct JSONOptions: Codable {
        let shouldUninstall: Bool
        let confirmUninstall: Bool
        let targetFilePath: String?
        let strictTargetFile: Bool
        let failOnWarnings: Bool
        let shouldListPaths: Bool
        let terminateRunningProcesses: Bool
        let dryRun: Bool
        let exportRequested: Bool
    }

    private struct JSONWarningStats: Codable {
        let duplicatePathCount: Int
        let missingPathCount: Int
    }

    private struct JSONScan: Codable {
        let targetCount: Int
        let totalSizeBytes: Int64
        let targets: [JSONTarget]
    }

    private struct JSONTarget: Codable {
        let path: String
        let sizeBytes: Int64
        let isDirectory: Bool
    }

    private struct JSONDryRun: Codable {
        let terminateRunningProcesses: Bool
        let wouldRemoveCount: Int
        let wouldRemoveSizeBytes: Int64
    }

    private struct JSONUninstall: Codable {
        let terminatedProcessCount: Int
        let forceTerminatedProcessCount: Int
        let failedProcessNames: [String]
        let movedToTrashCount: Int
        let movedToTrashSizeBytes: Int64
        let failedCount: Int
        let failedPaths: [String]
    }

    enum ParseError: LocalizedError {
        case unknownOption(String)
        case missingValue(String)
        case invalidCombination(String)

        var errorDescription: String? {
            switch self {
            case .unknownOption(let option):
                return "未知参数: \(option)"
            case .missingValue(let option):
                return "参数缺少值: \(option)"
            case .invalidCombination(let detail):
                return "参数组合错误: \(detail)"
            }
        }
    }

    static func shouldRunCLI(arguments: [String] = CommandLine.arguments) -> Bool {
        arguments.contains(cliFlag)
    }

    func run(arguments: [String] = CommandLine.arguments) async -> Int32 {
        do {
            let config = try parse(arguments: arguments)
            if config.showHelp {
                printUsage()
                return 0
            }

            let targets = service.scanOpenClawTargets()
            printScanSummary(targets)

            var report = JSONRunReport(
                generatedAt: ISO8601DateFormatter().string(from: Date()),
                arguments: arguments,
                options: JSONOptions(
                    shouldUninstall: config.shouldUninstall,
                    confirmUninstall: config.confirmUninstall,
                    targetFilePath: config.targetFileURL?.path,
                    strictTargetFile: config.strictTargetFile,
                    failOnWarnings: config.failOnWarnings,
                    shouldListPaths: config.shouldListPaths,
                    terminateRunningProcesses: config.terminateRunningProcesses,
                    dryRun: config.dryRun,
                    exportRequested: config.exportURL != nil
                ),
                scan: makeJSONScan(from: targets),
                warnings: [],
                warningStats: nil,
                selectedTargetsPath: nil,
                selectedTargets: nil,
                exportedTargetsPath: nil,
                dryRun: nil,
                uninstall: nil,
                exitCode: 0
            )

            let selectedTargets: [OpenClawCleanupTarget]
            if let targetFileURL = config.targetFileURL {
                do {
                    let importResult = try OpenClawTargetsImporter.importTargetsWithReport(
                        from: targetFileURL
                    )
                    selectedTargets = importResult.targets
                    printTargetFileSummary(selectedTargets, sourcePath: targetFileURL.path)
                    report.selectedTargetsPath = targetFileURL.path
                    report.selectedTargets = makeJSONScan(from: selectedTargets)
                    report.warnings.append(contentsOf: importResult.warnings)
                    report.warningStats = JSONWarningStats(
                        duplicatePathCount: importResult.duplicatePathCount,
                        missingPathCount: importResult.missingPathCount
                    )
                    printWarnings(importResult.warnings)
                } catch {
                    fputs("错误: 读取目标清单失败: \(error.localizedDescription)\n", stderr)
                    return finish(report: report, config: config, exitCode: 66)
                }
            } else {
                selectedTargets = targets
            }

            if config.strictTargetFile && selectedTargets.isEmpty {
                fputs("错误: 清单为空且启用了 --strict-target-file。\n", stderr)
                return finish(report: report, config: config, exitCode: 66)
            }

            if config.failOnWarnings && !report.warnings.isEmpty {
                fputs("错误: 检测到导入告警且启用了 --fail-on-warnings。\n", stderr)
                return finish(report: report, config: config, exitCode: 65)
            }

            if config.shouldListPaths {
                printTargetDetails(selectedTargets)
            }

            if let exportURL = config.exportURL {
                let resolvedURL: URL
                do {
                    resolvedURL = try OpenClawTargetsExporter.export(
                        targets: selectedTargets,
                        to: exportURL
                    )
                } catch {
                    fputs("错误: 导出清单失败: \(error.localizedDescription)\n", stderr)
                    return finish(
                        report: report,
                        config: config,
                        exitCode: 74
                    )
                }
                print("已导出清单: \(resolvedURL.path)")
                report.exportedTargetsPath = resolvedURL.path
            }

            guard config.shouldUninstall else {
                return finish(report: report, config: config, exitCode: 0)
            }

            if !config.dryRun && !config.confirmUninstall {
                fputs("错误: 真实卸载需要显式确认，请追加 --confirm（或 --yes）。\n", stderr)
                return finish(report: report, config: config, exitCode: 64)
            }

            if config.dryRun {
                printDryRunSummary(
                    targets: selectedTargets,
                    terminateRunningProcesses: config.terminateRunningProcesses
                )
                let totalBytes = selectedTargets.reduce(Int64(0)) { $0 + max($1.size, 0) }
                report.dryRun = JSONDryRun(
                    terminateRunningProcesses: config.terminateRunningProcesses,
                    wouldRemoveCount: selectedTargets.count,
                    wouldRemoveSizeBytes: totalBytes
                )
                return finish(report: report, config: config, exitCode: 0)
            }

            let uninstallResult = await service.uninstallOpenClawCompletely(
                preferredTargets: selectedTargets,
                terminateRunningProcesses: config.terminateRunningProcesses
            )
            printUninstallSummary(uninstallResult)

            report.uninstall = JSONUninstall(
                terminatedProcessCount: uninstallResult.terminatedProcessCount,
                forceTerminatedProcessCount: uninstallResult.forceTerminatedProcessCount,
                failedProcessNames: uninstallResult.failedProcessNames,
                movedToTrashCount: uninstallResult.movedToTrashCount,
                movedToTrashSizeBytes: uninstallResult.movedToTrashSize,
                failedCount: uninstallResult.failedCount,
                failedPaths: uninstallResult.failedPaths
            )

            if uninstallResult.failedCount > 0 ||
                !uninstallResult.failedProcessNames.isEmpty {
                return finish(report: report, config: config, exitCode: 2)
            }
            return finish(report: report, config: config, exitCode: 0)
        } catch {
            fputs("错误: \(error.localizedDescription)\n", stderr)
            printUsage()
            return 64
        }
    }

    private func parse(arguments: [String]) throws -> Configuration {
        var config = Configuration()
        var index = 1

        while index < arguments.count {
            let arg = arguments[index]

            switch arg {
            case Self.cliFlag, "--scan":
                break
            case "--uninstall":
                config.shouldUninstall = true
            case "--confirm", "--yes":
                config.confirmUninstall = true
            case "--target-file":
                let nextIndex = index + 1
                guard nextIndex < arguments.count else {
                    throw ParseError.missingValue("--target-file")
                }
                let path = arguments[nextIndex]
                config.targetFileURL = URL(fileURLWithPath: path)
                index += 1
            case "--strict-target-file":
                config.strictTargetFile = true
            case "--fail-on-warnings":
                config.failOnWarnings = true
            case "--list":
                config.shouldListPaths = true
            case "--no-terminate-processes":
                config.terminateRunningProcesses = false
            case "--dry-run", "-n":
                config.dryRun = true
            case "--help", "-h":
                config.showHelp = true
            case "--export":
                let nextIndex = index + 1
                guard nextIndex < arguments.count else {
                    throw ParseError.missingValue("--export")
                }
                let path = arguments[nextIndex]
                config.exportURL = URL(fileURLWithPath: path)
                index += 1
            case "--json-output":
                let nextIndex = index + 1
                guard nextIndex < arguments.count else {
                    throw ParseError.missingValue("--json-output")
                }
                let path = arguments[nextIndex]
                config.jsonOutputURL = URL(fileURLWithPath: path)
                index += 1
            default:
                if arg.hasPrefix("-") {
                    throw ParseError.unknownOption(arg)
                }
            }

            index += 1
        }

        if config.strictTargetFile && config.targetFileURL == nil {
            throw ParseError.invalidCombination("--strict-target-file 需要与 --target-file 一起使用")
        }

        return config
    }

    private func printUsage() {
        let variants = ClawVariantRegistry.all.map(\.displayName).joined(separator: ", ")
        let usage = """
        用法:
          remove-openclaw --cli [选项]

        覆盖变体 (\(ClawVariantRegistry.all.count) 个): \(variants)

        选项:
          --scan                     扫描待清理项（默认行为）
          --list                     打印每条待清理路径
          --export <path>            导出清单到 .txt/.json（扩展名缺省默认 .txt）
          --json-output <path>       将执行结果写入 JSON 文件
          --target-file <path>       从 .txt/.json 清单读取目标（用于 list/export/uninstall）
          --strict-target-file       清单为空时返回错误（需与 --target-file 搭配）
          --fail-on-warnings         导入清单出现告警时直接失败（建议自动化场景使用）
          --uninstall                执行卸载（移入废纸篓）
          --confirm, --yes           与 --uninstall 搭配，确认执行真实卸载
          --dry-run, -n              预演卸载，不执行任何删除动作
          --no-terminate-processes   卸载前不自动退出相关进程
          --help, -h                 显示帮助
        """
        print(usage)
    }

    private func printScanSummary(_ targets: [OpenClawCleanupTarget]) {
        let totalBytes = targets.reduce(Int64(0)) { $0 + max($1.size, 0) }
        print("扫描完成: \(targets.count) 项, \(byteFormatter.string(fromByteCount: totalBytes))")
    }

    private func printTargetDetails(_ targets: [OpenClawCleanupTarget]) {
        if targets.isEmpty {
            print("无待清理路径。")
            return
        }

        print("待清理路径列表:")
        for target in targets {
            let kind = target.isDirectory ? "dir" : "file"
            print("- [\(kind)] \(target.path) (\(target.size) bytes)")
        }
    }

    private func printTargetFileSummary(
        _ targets: [OpenClawCleanupTarget],
        sourcePath: String
    ) {
        let totalBytes = targets.reduce(Int64(0)) { $0 + max($1.size, 0) }
        print("清单读取完成: \(targets.count) 项, \(byteFormatter.string(fromByteCount: totalBytes))")
        print("清单文件: \(sourcePath)")
    }

    private func printWarnings(_ warnings: [String]) {
        guard !warnings.isEmpty else { return }
        for warning in warnings {
            print("警告: \(warning)")
        }
    }

    private func printUninstallSummary(_ result: OpenClawCleanupResult) {
        print("卸载完成:")
        print("- 退出进程: \(result.terminatedProcessCount)")
        if result.forceTerminatedProcessCount > 0 {
            print("- 强制退出进程: \(result.forceTerminatedProcessCount)")
        }
        print("- 移入废纸篓: \(result.movedToTrashCount) 项, \(byteFormatter.string(fromByteCount: result.movedToTrashSize))")
        print("- 失败项: \(result.failedCount)")

        if !result.failedProcessNames.isEmpty {
            print("进程退出失败:")
            for name in result.failedProcessNames {
                print("- \(name)")
            }
        }

        if !result.failedPaths.isEmpty {
            print("文件删除失败:")
            for path in result.failedPaths {
                print("- \(path)")
            }
        }
    }

    private func printDryRunSummary(
        targets: [OpenClawCleanupTarget],
        terminateRunningProcesses: Bool
    ) {
        let totalBytes = targets.reduce(Int64(0)) { $0 + max($1.size, 0) }
        print("Dry Run 预演结果:")
        if terminateRunningProcesses {
            print("- 将尝试退出正在运行的 Claw 系列进程并卸载 LaunchAgent")
        } else {
            print("- 不会尝试退出进程（已关闭自动退出）")
        }
        print("- 将移入废纸篓: \(targets.count) 项, \(byteFormatter.string(fromByteCount: totalBytes))")
        print("- 预演模式下不会实际修改任何文件")
    }

    private func makeJSONScan(from targets: [OpenClawCleanupTarget]) -> JSONScan {
        let totalBytes = targets.reduce(Int64(0)) { $0 + max($1.size, 0) }
        return JSONScan(
            targetCount: targets.count,
            totalSizeBytes: totalBytes,
            targets: targets.map {
                JSONTarget(
                    path: $0.path,
                    sizeBytes: $0.size,
                    isDirectory: $0.isDirectory
                )
            }
        )
    }

    private func finish(
        report: JSONRunReport,
        config: Configuration,
        exitCode: Int32
    ) -> Int32 {
        var finalReport = report
        finalReport.exitCode = exitCode

        guard let jsonOutputURL = config.jsonOutputURL else {
            return exitCode
        }

        do {
            let resolvedURL = try writeJSONReport(finalReport, to: jsonOutputURL)
            print("已输出结果 JSON: \(resolvedURL.path)")
            return exitCode
        } catch {
            fputs("错误: 写入 JSON 输出失败: \(error.localizedDescription)\n", stderr)
            return 74
        }
    }

    private func writeJSONReport(_ report: JSONRunReport, to rawURL: URL) throws -> URL {
        let resolvedURL = resolvedJSONOutputURL(from: rawURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(to: resolvedURL, options: .atomic)
        return resolvedURL
    }

    private func resolvedJSONOutputURL(from rawURL: URL) -> URL {
        let ext = rawURL.pathExtension.lowercased()
        if ext == "json" {
            return rawURL
        }
        return rawURL.appendingPathExtension("json")
    }
}
