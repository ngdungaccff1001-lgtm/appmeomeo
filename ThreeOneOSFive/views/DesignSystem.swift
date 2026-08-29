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

            Text("SYSTEM LOGIC ONLINE • \(BrandConfigStore.shared.appName.uppercased()) CORE")
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

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 42, 66)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Brand & Seller Token Dynamic Store

@MainActor
final class BrandConfigStore: ObservableObject {
    static let shared = BrandConfigStore()

    @AppStorage("seller_brand_token") var sellerToken: String = ""
    @AppStorage("seller_token_unlocked") var isTokenUnlocked: Bool = false
    @AppStorage("brand_app_name") var appName: String = ""
    @AppStorage("brand_welcome_title") var welcomeTitle: String = ""
    @AppStorage("brand_welcome_subtitle") var welcomeSubtitle: String = ""
    @AppStorage("brand_welcome_color") var welcomeColorHex: String = "#FF2A42"
    @AppStorage("brand_telegram_url") var telegramURL: String = "https://t.me/ioscrackvn"
    @AppStorage("brand_telegram_title") var telegramTitle: String = "LIÊN HỆ TELEGRAM"
    @AppStorage("brand_show_get_key") var showGetKey: Bool = true
    @AppStorage("brand_get_key_title") var getKeyTitle: String = "LẤY KEY 12H"
    @AppStorage("brand_get_key_url") var getKeyURL: String = ""

    @Published var isServerOffline: Bool = false
    @Published var isCrackLockdown: Bool = false
    @Published var crackEmergencyMessage: String = "Phát hiện phiên bản bị can thiệp trái phép, vui lòng tham gia Telegram để nhận hỗ trợ!"
    @Published var crackLinkTitle: String = "THAM GIA TELEGRAM"
    @Published var crackLinkURL: String = "https://t.me/ioscrackvn"

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    var welcomeColor: Color {
        Color(hex: welcomeColorHex.isEmpty ? "#FF2A42" : welcomeColorHex)
    }

    var displayAppName: String {
        appName.isEmpty ? (sellerToken.isEmpty ? "VIP CHEAT" : sellerToken) : appName
    }

    var displayWelcomeTitle: String {
        welcomeTitle.isEmpty ? "CHÀO BẠN ĐẾN VỚI \(displayAppName.uppercased())" : welcomeTitle
    }

    init() {
        checkServerHealth()
        if isTokenUnlocked && !sellerToken.isEmpty {
            fetchBrandConfig(token: sellerToken)
        }
    }

    func checkServerHealth() {
        let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? "http://103.238.234.204:5000"
        guard let url = URL(string: "\(serverUrl)/api/status") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    await MainActor.run {
                        self.isServerOffline = true
                        self.isCrackLockdown = false
                    }
                    return
                }

                let serverOnline = json["server_online"] as? Bool ?? true
                let emergencyMode = json["emergency_mode"] as? Bool ?? false
                let emergencyMsg = json["emergency_message"] as? String ?? "Phát hiện phiên bản bị can thiệp trái phép, vui lòng tham gia Telegram để nhận hỗ trợ!"
                let linkTitle = json["emergency_link_title"] as? String ?? "THAM GIA TELEGRAM"
                let linkURL = json["emergency_link_url"] as? String ?? "https://t.me/ioscrackvn"

                await MainActor.run {
                    if !serverOnline {
                        self.isServerOffline = true
                        self.isCrackLockdown = false
                    } else if emergencyMode {
                        self.isServerOffline = false
                        self.isCrackLockdown = true
                        self.crackEmergencyMessage = emergencyMsg
                        self.crackLinkTitle = linkTitle
                        self.crackLinkURL = linkURL
                    } else {
                        self.isServerOffline = false
                        self.isCrackLockdown = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isServerOffline = true
                    self.isCrackLockdown = false
                }
            }
        }
    }

    func verifyToken(_ input: String) async -> Bool {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.isEmpty {
            self.errorMessage = "Vui lòng nhập mã Token!"
            return false
        }

        self.isLoading = true
        self.errorMessage = nil

        let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? "http://103.238.234.204:5000"
        guard let url = URL(string: "\(serverUrl)/api/brand?token=\(clean)") else {
            self.isLoading = false
            self.errorMessage = "Địa chỉ máy chủ không hợp lệ!"
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.isLoading = false
                self.errorMessage = "Không thể kết nối đến máy chủ Token!"
                return false
            }

            let success = json["success"] as? Bool ?? false
            let isServerOnline = json["server_online"] as? Bool ?? true
            let isEmergency = json["emergency_mode"] as? Bool ?? false

            if !isServerOnline || isEmergency {
                self.isLoading = false
                KeyAuthEngine.shared.isEmergencyMode = true
                KeyAuthEngine.shared.emergencyMessage = json["message"] as? String ?? "Máy chủ đang bảo trì nâng cấp hệ thống!"
                KeyAuthEngine.shared.emergencyLinkURL = json["telegram_url"] as? String ?? self.telegramURL
                return false
            }

            if success {
                self.sellerToken = clean
                self.isTokenUnlocked = true
                self.appName = json["app_name"] as? String ?? clean
                self.welcomeTitle = json["welcome_title"] as? String ?? "CHÀO BẠN ĐẾN VỚI \(clean)"
                self.welcomeSubtitle = json["welcome_subtitle"] as? String ?? ""
                self.welcomeColorHex = json["welcome_color"] as? String ?? "#FF2A42"
                self.telegramURL = json["telegram_url"] as? String ?? "https://t.me/ioscrackvn"
                self.telegramTitle = json["telegram_title"] as? String ?? "LIÊN HỆ TELEGRAM"
                self.showGetKey = json["show_get_key"] as? Bool ?? true
                self.getKeyTitle = json["get_key_title"] as? String ?? "LẤY KEY 12H"
                self.getKeyURL = json["get_key_url"] as? String ?? ""
                self.isLoading = false
                self.errorMessage = nil
                return true
            } else {
                self.isLoading = false
                self.errorMessage = "Mã Token không tồn tại hoặc đã bị tắt trên hệ thống!"
                return false
            }
        } catch {
            self.isLoading = false
            self.errorMessage = "Lỗi kết nối máy chủ: \(error.localizedDescription)"
            return false
        }
    }

    func fetchBrandConfig(token: String? = nil) {
        let activeToken = (token ?? sellerToken).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !activeToken.isEmpty else { return }

        let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? "http://103.238.234.204:5000"
        guard let url = URL(string: "\(serverUrl)/api/brand?token=\(activeToken)") else { return }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                let isServerOnline = json["server_online"] as? Bool ?? true
                let isEmergency = json["emergency_mode"] as? Bool ?? false

                if !isServerOnline || isEmergency {
                    KeyAuthEngine.shared.isEmergencyMode = true
                    KeyAuthEngine.shared.emergencyMessage = json["message"] as? String ?? "Máy chủ đang bảo trì nâng cấp hệ thống!"
                    KeyAuthEngine.shared.emergencyLinkURL = json["telegram_url"] as? String ?? self.telegramURL
                    return
                }

                let success = json["success"] as? Bool ?? false
                if success {
                    self.appName = json["app_name"] as? String ?? activeToken
                    self.welcomeTitle = json["welcome_title"] as? String ?? "CHÀO BẠN ĐẾN VỚI \(activeToken)"
                    self.welcomeSubtitle = json["welcome_subtitle"] as? String ?? ""
                    self.welcomeColorHex = json["welcome_color"] as? String ?? "#FF2A42"
                    self.telegramURL = json["telegram_url"] as? String ?? "https://t.me/ioscrackvn"
                    self.telegramTitle = json["telegram_title"] as? String ?? "LIÊN HỆ TELEGRAM"
                    self.showGetKey = json["show_get_key"] as? Bool ?? true
                    self.getKeyTitle = json["get_key_title"] as? String ?? "LẤY KEY 12H"
                    self.getKeyURL = json["get_key_url"] as? String ?? ""
                } else {
                    // Token bị xóa hoặc tắt trên admin
                    self.logoutToken()
                }
            } catch {}
        }
    }

    func logoutToken() {
        self.sellerToken = ""
        self.isTokenUnlocked = false
        self.appName = ""
        self.welcomeTitle = ""
        self.welcomeSubtitle = ""
        self.welcomeColorHex = "#FF2A42"
        self.telegramURL = "https://t.me/ioscrackvn"
        self.telegramTitle = "LIÊN HỆ TELEGRAM"
        self.showGetKey = true
        self.getKeyTitle = "LẤY KEY 12H"
        self.getKeyURL = ""
        self.errorMessage = nil
        KeyAuthEngine.shared.logout()
        FreeFirePatchEngine.shared.cleanAllPatches()
    }
}

// MARK: - Toast Alert Notification Manager (Bay từ góc trên bên phải, hiển thị 3s)

enum ToastType {
    case success
    case error
    case warning
    case info

    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return Color.green
        case .error: return Color.red
        case .warning: return Color.orange
        case .info: return Color(red: 0.20, green: 0.65, blue: 1.0)
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String
}

@MainActor
final class AppToastManager: ObservableObject {
    static let shared = AppToastManager()

    @Published var currentToast: ToastMessage? = nil
    private var dismissTask: Task<Void, Never>? = nil

    func show(type: ToastType, title: String, message: String) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            self.currentToast = ToastMessage(type: type, title: title, message: message)
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // Tự động ẩn sau 3 giây
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.currentToast = nil
                }
            }
        }
    }

    func hide() {
        dismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentToast = nil
        }
    }
}

// MARK: - System Log & Error Tracker Manager (Nhật ký lỗi & tiến trình hệ thống)

enum LogType {
    case info
    case success
    case error
    case warning

    var prefix: String {
        switch self {
        case .info: return "[INFO]"
        case .success: return "[SUCCESS]"
        case .error: return "[ERROR]"
        case .warning: return "[WARN]"
        }
    }

    var color: Color {
        switch self {
        case .info: return Color(red: 0.20, green: 0.65, blue: 1.0)
        case .success: return Color.green
        case .error: return Color.red
        case .warning: return Color.orange
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let time: String
    let type: LogType
    let message: String
}

@MainActor
final class AppLogManager: ObservableObject {
    static let shared = AppLogManager()

    @Published var logs: [LogEntry] = []

    init() {
        addLog(type: .info, message: "Hệ thống bảo mật PATH DATA CHEAT đã khởi tạo")
    }

    func addLog(type: LogType, message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: Date())
        let newEntry = LogEntry(time: timeStr, type: type, message: message)
        logs.append(newEntry)
    }

    func clearLogs() {
        logs.removeAll()
        addLog(type: .info, message: "Đã làm sạch toàn bộ nhật ký log hệ thống")
    }

    var fullLogsText: String {
        logs.map { "[\($0.time)] \($0.type.prefix) \($0.message)" }.joined(separator: "\n")
    }
}


