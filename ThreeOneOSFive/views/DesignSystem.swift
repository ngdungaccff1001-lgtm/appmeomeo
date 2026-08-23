import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Hệ thống"
        case .dark: return "Tối"
        case .light: return "Sáng"
        }
    }

    var iconName: String {
        switch self {
        case .system: return "gearshape.2"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

enum AppTheme {
    // Đổi màu chủ đạo sang Màu Đỏ (Cyber Crimson Red)
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.20, blue: 0.26, alpha: 1.00)
                : UIColor(red: 0.88, green: 0.10, blue: 0.18, alpha: 1.00)
        }
    )

    static let redGradient = LinearGradient(
        colors: [Color(red: 1.00, green: 0.22, blue: 0.28), Color(red: 0.82, green: 0.08, blue: 0.16)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let filesTint = Color(red: 0.20, green: 0.60, blue: 0.95)
    static let patchesTint = Color(red: 1.00, green: 0.22, blue: 0.28)
    static let freeFireTint = Color(red: 1.00, green: 0.30, blue: 0.10)
    static let successTint = Color(red: 0.18, green: 0.82, blue: 0.45)

    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardBorder = Color.primary.opacity(0.12)

    static let pageInset: CGFloat = 14
    static let cardCornerRadius: CGFloat = 4
    static let rowIconSize: CGFloat = 16
    static let rowIconFrame: CGFloat = 26
    static let fileRowIconSize: CGFloat = 16
    static let fileRowIconFrame: CGFloat = 28
    static let fileRowHeight: CGFloat = 58
    static let appIconSize: CGFloat = 30
    static let emptyIconSize: CGFloat = 28
    static let selectionIconSize: CGFloat = 16
}

// MARK: - Cyber Pulse Scanner Effect (Hiệu ứng logic công nghệ cao lúc vào app)
struct AppCyberPulseScanner: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isAnimating ? 1.5 : 0.8)
                    .opacity(isAnimating ? 0 : 1)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: isAnimating)

                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 7, height: 7)
            }

            Text("SYSTEM LOGIC ONLINE • MEOMEOPATH CORE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.accent)

            Spacer()

            Text("v1.1.1")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(AppTheme.accent.opacity(0.08))
                .overlay(
                    Rectangle().stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Sharp Industrial Card Container
struct AppCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Sharp Status Badge
struct AppStatusBadge: View {
    enum StatusType {
        case success
        case warning
        case error
        case neutral
        case running

        var color: Color {
            switch self {
            case .success: return Color.green
            case .warning: return Color.orange
            case .error: return Color.red
            case .neutral: return Color.secondary
            case .running: return AppTheme.accent
            }
        }
    }

    let title: String
    var systemImage: String? = nil
    var type: StatusType = .neutral

    var body: some View {
        HStack(spacing: 5) {
            if type == .running {
                ProgressView()
                    .controlSize(.mini)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            } else {
                Rectangle()
                    .fill(type.color)
                    .frame(width: 6, height: 6)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(type.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(type.color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(type.color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Sharp Quick Action Card
struct AppQuickActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(tint.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(tint.opacity(0.35), lineWidth: 1)
                            )

                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 32, height: 32)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 95, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(AppScaleButtonStyle())
    }
}

// MARK: - Scale Button Style
struct AppScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - App Row Icon
struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                )
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

// MARK: - Sharp Search Field
struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.system(size: 14, weight: .regular))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - App Logo
struct AppLogo: View {
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.redGradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.4), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}
