import Foundation
import Combine

struct ScanLogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

@MainActor
final class OpenClawUninstallViewModel: ObservableObject {
    @Published private(set) var variantResults: [ClawVariantScanResult] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isUninstalling = false
    @Published private(set) var lastResult: OpenClawCleanupResult?
    @Published private(set) var lastScannedAt: Date?
    @Published var errorMessage: String?
    @Published var selectedVariantIDs: Set<String> = []
    @Published private(set) var scanCompletedCount = 0
    @Published private(set) var scanTotalCount = 0
    @Published private(set) var currentScanVariantName: String?
    @Published private(set) var scanLogEntries: [ScanLogEntry] = []

    private let service = OpenClawUninstallService()

    var hasScanned: Bool { lastScannedAt != nil }
    var scanProgressFraction: Double {
        guard scanTotalCount > 0 else { return 0 }
        return Double(scanCompletedCount) / Double(scanTotalCount)
    }

    var scanProgressLabel: String {
        guard scanTotalCount > 0 else { return "准备中…" }
        return "\(scanCompletedCount)/\(scanTotalCount)"
    }

    var scanStatusText: String {
        if let currentScanVariantName {
            return "正在扫描 \(currentScanVariantName)"
        }
        return isScanning ? "正在准备扫描环境…" : "扫描完成"
    }

    var detectedResults: [ClawVariantScanResult] {
        variantResults.filter { $0.isDetected }
    }

    var notDetectedResults: [ClawVariantScanResult] {
        variantResults.filter { !$0.isDetected }
    }

    var sortedResults: [ClawVariantScanResult] {
        variantResults.sorted { lhs, rhs in
            if lhs.isDetected != rhs.isDetected { return lhs.isDetected }
            if lhs.totalSize != rhs.totalSize { return lhs.totalSize > rhs.totalSize }
            return lhs.variant.displayName < rhs.variant.displayName
        }
    }

    var targets: [OpenClawCleanupTarget] {
        var seen: Set<String> = []
        var result: [OpenClawCleanupTarget] = []
        for r in variantResults {
            for target in r.targets {
                if seen.insert(target.path).inserted {
                    result.append(target)
                }
            }
        }
        return result
    }

    var selectedTargets: [OpenClawCleanupTarget] {
        var seen: Set<String> = []
        var result: [OpenClawCleanupTarget] = []
        for r in variantResults where selectedVariantIDs.contains(r.variant.id) {
            for target in r.targets {
                if seen.insert(target.path).inserted {
                    result.append(target)
                }
            }
        }
        return result
    }

    var selectedResults: [ClawVariantScanResult] {
        variantResults.filter { selectedVariantIDs.contains($0.variant.id) && $0.isDetected }
    }

    var totalTargetSize: Int64 {
        targets.reduce(0) { $0 + max($1.size, 0) }
    }

    var selectedTargetSize: Int64 {
        selectedTargets.reduce(0) { $0 + max($1.size, 0) }
    }

    var selectedDetectedCount: Int {
        detectedResults.filter { selectedVariantIDs.contains($0.id) }.count
    }

    var allDetectedSelected: Bool {
        !detectedResults.isEmpty && detectedResults.allSatisfy { selectedVariantIDs.contains($0.id) }
    }

    func selectAllDetected() {
        for r in detectedResults {
            selectedVariantIDs.insert(r.id)
        }
    }

    func deselectAll() {
        selectedVariantIDs.removeAll()
    }

    func toggleVariant(_ id: String) {
        if selectedVariantIDs.contains(id) {
            selectedVariantIDs.remove(id)
        } else {
            selectedVariantIDs.insert(id)
        }
    }

    func targetsForVariant(_ id: String) -> [OpenClawCleanupTarget] {
        variantResults.first(where: { $0.id == id })?.targets ?? []
    }

    func exportTargets(to rawURL: URL) throws -> URL {
        try OpenClawTargetsExporter.export(targets: selectedTargets.isEmpty ? targets : selectedTargets, to: rawURL)
    }

    func scan() {
        guard !isScanning, !isUninstalling else { return }

        isScanning = true
        errorMessage = nil
        scanCompletedCount = 0
        scanTotalCount = 0
        currentScanVariantName = nil
        scanLogEntries = []

        let service = self.service
        let stream = AsyncStream<OpenClawScanEvent> { continuation in
            Task.detached(priority: .userInitiated) { [service] in
                _ = service.scanAllVariants { event in
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }

        Task {
            for await event in stream {
                handleScanEvent(event)
            }
        }
    }

    func uninstall(terminateRunningProcesses: Bool) {
        guard !isScanning, !isUninstalling else { return }

        isUninstalling = true
        errorMessage = nil

        let toUninstall = selectedResults

        Task {
            let result = await service.uninstallSelectedVariants(
                toUninstall,
                terminateRunningProcesses: terminateRunningProcesses
            )
            self.lastResult = result

            if result.failedCount > 0 {
                self.errorMessage = "有 \(result.failedCount) 项卸载失败，可能被占用或权限不足。"
            }

            let rescannedResults = await Task.detached(priority: .utility) { [service] in
                service.scanAllVariants()
            }.value

            self.variantResults = rescannedResults
            self.lastScannedAt = Date()
            self.isUninstalling = false

            self.selectedVariantIDs = Set(rescannedResults.filter { $0.isDetected }.map { $0.id })
        }
    }

    private func handleScanEvent(_ event: OpenClawScanEvent) {
        switch event {
        case .started(let total):
            scanTotalCount = total
            appendScanLog("开始扫描，共 \(total) 个变体。")

        case .variantStarted(let index, let total, let name):
            scanTotalCount = total
            currentScanVariantName = name
            appendScanLog("[\(index)/\(total)] 正在扫描 \(name)…")

        case .variantFinished(let index, let total, let result):
            scanCompletedCount = index
            scanTotalCount = total
            upsertVariantResult(result)

            if result.isDetected {
                appendScanLog(
                    "完成 \(result.variant.displayName)：发现 \(result.targets.count) 项，约 \(formattedByteCount(result.totalSize))。"
                )
            } else {
                appendScanLog("完成 \(result.variant.displayName)：未发现残留。")
            }

        case .completed(let results):
            variantResults = results
            lastScannedAt = Date()
            isScanning = false
            currentScanVariantName = nil
            scanCompletedCount = results.count
            scanTotalCount = results.count
            selectedVariantIDs = Set(results.filter { $0.isDetected }.map { $0.id })

            let detectedCount = results.filter(\.isDetected).count
            let totalSize = results.reduce(0) { $0 + $1.totalSize }
            appendScanLog("扫描完成：检测到 \(detectedCount)/\(results.count) 个变体，共 \(formattedByteCount(totalSize))。")
        }
    }

    private func upsertVariantResult(_ result: ClawVariantScanResult) {
        if let index = variantResults.firstIndex(where: { $0.id == result.id }) {
            variantResults[index] = result
        } else {
            variantResults.append(result)
        }
    }

    private func appendScanLog(_ message: String) {
        scanLogEntries.append(ScanLogEntry(timestamp: Date(), message: message))
        if scanLogEntries.count > 120 {
            scanLogEntries.removeFirst(scanLogEntries.count - 120)
        }
    }

    private func formattedByteCount(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(size, 0), countStyle: .file)
    }
}
