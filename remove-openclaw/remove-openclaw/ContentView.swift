import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case overview
    case variant(String)
}

struct ContentView: View {
    @StateObject private var viewModel = OpenClawUninstallViewModel()
    @State private var selection: SidebarItem? = .overview
    @State private var showUninstallConfirm = false
    @State private var exportMessage: String?
    @AppStorage("terminateRunningProcessesBeforeUninstall")
    private var terminateBeforeUninstall = true

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useGB, .useMB, .useKB]
        f.countStyle = .file
        return f
    }()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            detailView
        }
        .frame(minWidth: 820, minHeight: 560)
        .onAppear {
            if !viewModel.hasScanned {
                viewModel.scan()
            }
        }
        .alert("确认卸载选中的 Claw 变体", isPresented: $showUninstallConfirm) {
            Button("取消", role: .cancel) {}
            Button("卸载", role: .destructive) {
                viewModel.uninstall(terminateRunningProcesses: terminateBeforeUninstall)
            }
        } message: {
            Text(confirmMessage)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("总览") {
                NavigationLink(value: SidebarItem.overview) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("全部变体")
                                .font(.body.weight(.medium))
                            if viewModel.hasScanned {
                                Text("检测到 \(viewModel.detectedResults.count)/\(viewModel.variantResults.count) 个")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                            .foregroundStyle(.blue)
                    }
                }
            }

            if !viewModel.detectedResults.isEmpty {
                Section("已检测到 (\(viewModel.detectedResults.count))") {
                    ForEach(viewModel.sortedResults.filter({ $0.isDetected }), id: \.id) { result in
                        variantRow(result)
                    }
                }
            }

            if !viewModel.notDetectedResults.isEmpty {
                Section("未检测到 (\(viewModel.notDetectedResults.count))") {
                    ForEach(viewModel.sortedResults.filter({ !$0.isDetected }), id: \.id) { result in
                        variantRow(result)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func variantRow(_ result: ClawVariantScanResult) -> some View {
        NavigationLink(value: SidebarItem.variant(result.variant.id)) {
            HStack(spacing: 8) {
                Image(systemName: result.variant.iconSystemName)
                    .foregroundStyle(result.isDetected ? .orange : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.variant.displayName)
                        .font(.body.weight(.medium))
                    if result.isDetected {
                        Text("\(result.targets.count) 项 · \(fmt(result.totalSize))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("未检测到")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if result.isDetected && viewModel.selectedVariantIDs.contains(result.variant.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .overview, .none:
            overviewView
        case .variant(let id):
            if let result = viewModel.variantResults.first(where: { $0.variant.id == id }) {
                variantDetailView(result)
            } else {
                Text("未找到变体信息")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Overview

    private var overviewView: some View {
        VStack(spacing: 0) {
            overviewStatsBar
            Divider()
            overviewContent
        }
        .background(.background)
    }

    private var overviewStatsBar: some View {
        HStack(spacing: 16) {
            StatItem(
                label: "已检测变体",
                value: "\(viewModel.detectedResults.count)",
                systemImage: "app.badge",
                tint: viewModel.detectedResults.isEmpty ? .green : .orange
            )
            StatItem(
                label: "已选中",
                value: "\(viewModel.selectedDetectedCount)",
                systemImage: "checkmark.circle",
                tint: .blue
            )
            StatItem(
                label: "预计释放",
                value: fmt(viewModel.selectedTargetSize),
                systemImage: "externaldrive",
                tint: .blue
            )
            StatItem(
                label: "最近扫描",
                value: lastScanTimeShort,
                systemImage: "clock",
                tint: .teal,
                footnote: lastScanDateLong
            )
        }
        .padding(16)
    }

    private var overviewContent: some View {
        VStack(spacing: 0) {
            overviewToolbar
            Divider()

            if viewModel.isScanning || !viewModel.hasScanned {
                Spacer()
                ProgressView("正在扫描所有变体…")
                Spacer()
            } else if viewModel.detectedResults.isEmpty {
                emptyState
            } else {
                overviewList
            }
        }
    }

    private var overviewToolbar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.scan()
            } label: {
                Label(viewModel.hasScanned ? "重新扫描" : "开始扫描", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isScanning || viewModel.isUninstalling)

            Divider().frame(height: 20)

            Button {
                if viewModel.allDetectedSelected {
                    viewModel.deselectAll()
                } else {
                    viewModel.selectAllDetected()
                }
            } label: {
                Label(
                    viewModel.allDetectedSelected ? "取消全选" : "全部选中",
                    systemImage: viewModel.allDetectedSelected ? "xmark.circle" : "checkmark.circle"
                )
            }
            .disabled(viewModel.detectedResults.isEmpty || viewModel.isUninstalling)

            Spacer()

            Button {
                exportTargetsList()
            } label: {
                Label("导出清单", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.isUninstalling || viewModel.targets.isEmpty)

            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                Label("卸载选中 (\(viewModel.selectedDetectedCount))", systemImage: "trash")
            }
            .disabled(viewModel.isScanning || viewModel.isUninstalling || viewModel.selectedDetectedCount == 0)

            if let exportMessage {
                Label(exportMessage, systemImage: exportMessage.hasPrefix("导出失败") ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(exportMessage.hasPrefix("导出失败") ? .orange : .green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var overviewList: some View {
        List {
            ForEach(viewModel.sortedResults.filter({ $0.isDetected }), id: \.id) { result in
                HStack(spacing: 12) {
                    Button {
                        viewModel.toggleVariant(result.variant.id)
                    } label: {
                        Image(systemName: viewModel.selectedVariantIDs.contains(result.variant.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.selectedVariantIDs.contains(result.variant.id)
                                             ? .blue : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)

                    Button {
                        selection = .variant(result.variant.id)
                    } label: {
                        HStack(spacing: 12) {
                            IconBox(systemImage: result.variant.iconSystemName, tint: .orange, size: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.variant.displayName)
                                    .font(.body.weight(.medium))
                                Text(result.variant.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(result.targets.count) 项")
                                    .font(.callout.weight(.semibold).monospacedDigit())
                                Text(fmt(result.totalSize))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            if let result = viewModel.lastResult {
                Section("上次卸载结果") {
                    resultSummaryRows(result)
                }
            }

            settingsSection
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Variant Detail View

    private func variantDetailView(_ result: ClawVariantScanResult) -> some View {
        VStack(spacing: 0) {
            variantDetailHeader(result)
            Divider()

            if result.targets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("未检测到残留")
                        .font(.title2.weight(.semibold))
                    Text("\(result.variant.displayName) 未发现任何相关文件")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(result.targets) { target in
                    let url = URL(fileURLWithPath: target.path)
                    let name = url.lastPathComponent.isEmpty ? target.path : url.lastPathComponent
                    TargetFileRow(
                        name: name,
                        path: target.path,
                        size: fmt(target.size),
                        isDirectory: target.isDirectory
                    )
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .background(.background)
    }

    private func variantDetailHeader(_ result: ClawVariantScanResult) -> some View {
        HStack(spacing: 16) {
            IconBox(systemImage: result.variant.iconSystemName,
                    tint: result.isDetected ? .orange : .secondary, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.variant.displayName)
                    .font(.title2.weight(.bold))
                Text(result.variant.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if result.isDetected {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(result.targets.count) 项待清理")
                        .font(.callout.weight(.semibold))
                    Text(fmt(result.totalSize))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.toggleVariant(result.variant.id)
                } label: {
                    Label(
                        viewModel.selectedVariantIDs.contains(result.variant.id) ? "已选中" : "选中",
                        systemImage: viewModel.selectedVariantIDs.contains(result.variant.id)
                            ? "checkmark.circle.fill" : "circle"
                    )
                }
                .buttonStyle(.bordered)
            } else {
                StatusBadge(title: "无残留", systemImage: "checkmark.circle", tint: .green)
            }
        }
        .padding(16)
    }

    // MARK: - Shared Sections

    private var settingsSection: some View {
        Section("设置") {
            Toggle(isOn: $terminateBeforeUninstall) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("卸载前退出进程")
                        .font(.body)
                    Text("先结束 Claw 系列相关进程再清理文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(viewModel.isUninstalling)
        }
    }

    private func resultSummaryRows(_ result: OpenClawCleanupResult) -> some View {
        Group {
            HStack(spacing: 12) {
                ResultCountItem(label: "已退出", count: result.terminatedProcessCount, tint: .blue)
                ResultCountItem(label: "已清理", count: result.movedToTrashCount, tint: .green)
                ResultCountItem(label: "失败", count: result.failedCount, tint: result.failedCount > 0 ? .orange : .secondary)
            }

            if result.forceTerminatedProcessCount > 0 {
                Label("其中 \(result.forceTerminatedProcessCount) 个进程被强制退出", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Label("已移入废纸篓 \(fmt(result.movedToTrashSize))", systemImage: "trash.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)

            if !result.failedPaths.isEmpty {
                DisclosureGroup("失败路径") {
                    ForEach(result.failedPaths, id: \.self) { path in
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .font(.caption.weight(.medium))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("没有发现残留")
                .font(.title2.weight(.semibold))

            Text("扫描未发现任何 Claw 变体相关文件，当前环境已经干净。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var lastScanTimeShort: String {
        guard let d = viewModel.lastScannedAt else { return "扫描中…" }
        return d.formatted(date: .omitted, time: .shortened)
    }

    private var lastScanDateLong: String? {
        guard let d = viewModel.lastScannedAt else { return nil }
        return d.formatted(date: .abbreviated, time: .omitted)
    }

    private var confirmMessage: String {
        let count = viewModel.selectedDetectedCount
        var msg = "将卸载 \(count) 个变体，共 \(viewModel.selectedTargets.count) 项文件（\(fmt(viewModel.selectedTargetSize))）。"
        if terminateBeforeUninstall {
            msg += "\n\n卸载前会先退出运行中的相关进程并卸载 LaunchAgent。"
        } else {
            msg += "\n\n未开启自动退出进程，部分文件可能删除失败。"
        }
        return msg
    }

    private func fmt(_ size: Int64) -> String {
        byteFormatter.string(fromByteCount: size)
    }

    // MARK: - Export

    private func exportTargetsList() {
        let panel = NSSavePanel()
        panel.title = "导出 Claw 系列待清理清单"
        panel.message = "支持 .txt 或 .json 格式"
        panel.nameFieldStringValue = "claw-cleanup-targets.txt"
        panel.allowedContentTypes = [.plainText, .json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let exported = try viewModel.exportTargets(to: url)
            exportMessage = "已导出：\(exported.path)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
