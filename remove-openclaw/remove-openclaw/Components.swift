import SwiftUI

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.separator, lineWidth: 0.5)
            )
    }
}

struct StatusBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct IconBox: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let systemImage: String
    let tint: Color
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                IconBox(systemImage: systemImage, tint: tint, size: 28)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator, lineWidth: 0.5)
        )
    }
}

struct ActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                IconBox(systemImage: systemImage, tint: isDisabled ? .secondary : tint, size: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.quaternary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct NoticeRow: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct TargetFileRow: View {
    let name: String
    let path: String
    let size: String
    let isDirectory: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                .font(.title3)
                .foregroundStyle(isDirectory ? .orange : .blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(isDirectory ? "目录" : "文件")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(size)
                    .font(.callout.weight(.semibold).monospacedDigit())
            }
        }
        .padding(.vertical, 6)
    }
}

struct ResultCountItem: View {
    let label: String
    let count: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
