import SwiftUI

enum AppTypography {
    static let sidebarTitle = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 14, weight: .regular)
    static let bodyStrong = Font.system(size: 14, weight: .semibold)
    static let subtitle = Font.system(size: 13, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionStrong = Font.system(size: 12, weight: .medium)
    static let sectionTitle = Font.system(size: 18, weight: .semibold)
    static let pageTitle = Font.system(size: 22, weight: .bold)
    static let statValue = Font.system(size: 24, weight: .bold)
    static let metricValue = Font.system(size: 20, weight: .bold)
}

enum AppLayout {
    static let pagePadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 8
    static let cardPadding: CGFloat = 12
    static let cardCornerRadius: CGFloat = 11
    static let contentMaxWidth: CGFloat = 1020
}

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppLayout.cardPadding)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius, style: .continuous)
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
            .font(AppTypography.captionStrong)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
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
        HStack(alignment: .center, spacing: 12) {
            IconBox(systemImage: systemImage, tint: tint, size: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(AppTypography.captionStrong)
                    .foregroundStyle(.secondary)

                if let footnote {
                    Text(footnote)
                        .font(AppTypography.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            Text(value)
                .font(AppTypography.statValue)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 82)
        .padding(AppLayout.cardPadding)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            HStack(spacing: AppLayout.rowSpacing) {
                IconBox(systemImage: systemImage, tint: isDisabled ? .secondary : tint, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.bodyStrong)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(AppTypography.captionStrong)
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
                .font(AppTypography.subtitle)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct TargetFileRow: View {
    let name: String
    let path: String
    let size: String
    let isDirectory: Bool
    var showsOpenIndicator = false

    var body: some View {
        HStack(spacing: AppLayout.rowSpacing) {
            Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isDirectory ? .orange : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(AppTypography.bodyStrong)
                    .lineLimit(1)
                Text(path)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(isDirectory ? "目录" : "文件")
                    if showsOpenIndicator {
                        Image(systemName: "arrow.up.forward.square")
                    }
                }
                .font(AppTypography.captionStrong)
                .foregroundStyle(showsOpenIndicator ? .orange : .secondary)
                Text(size)
                    .font(AppTypography.subtitle.weight(.semibold))
            }
        }
        .padding(.vertical, 5)
    }
}

struct ResultCountItem: View {
    let label: String
    let count: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(count)")
                .font(AppTypography.metricValue)
                .foregroundStyle(tint)
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
