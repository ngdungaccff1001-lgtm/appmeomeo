import SwiftUI
import UIKit

// MARK: - Primary App Tab Enum

enum AppPrimaryTab: Int, CaseIterable, Identifiable {
    case home = 0
    case function = 1
    case settings = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "Tổng Quan"
        case .function: return "Chức Năng"
        case .settings: return "Hệ Thống"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .function: return "bolt.shield.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main ContentView

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @State private var selectedTab: AppPrimaryTab = .home
    @AppStorage("app.appearance") private var appearance = AppAppearance.dark.rawValue

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            // 1. EMERGENCY MODE (Khi Admin bật Chế Độ Bị Crack hoặc Server Offline)
            if keyEngine.isEmergencyMode {
                EmergencyLockdownView()
                    .transition(.opacity)
                    .zIndex(99)
            }
            // 2. LOGIN WINDOW (Khi chưa nhập Token hoặc chưa đăng nhập Key VIP)
            else if !brandStore.isTokenUnlocked || !keyEngine.isAuthenticated {
                LoginAuthWindowView()
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    .zIndex(90)
            }
            // 3. MAIN APP WINDOW (Khi đã xác thực đầy đủ Token & Key VIP)
            else {
                VStack(spacing: 0) {
                    // Nội dung Cửa Sổ theo Tab đang chọn
                    Group {
                        switch selectedTab {
                        case .home:
                            HomeDashboardWindowView(onNavigateToFunction: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = .function
                                }
                            })
                        case .function:
                            FunctionPatchWindowView()
                        case .settings:
                            SettingsSystemView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Thanh Điều Hướng Cyber TabBar Hiện Đại
                    customCyberTabBar
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(appearance == "dark" ? .dark : (appearance == "light" ? .light : nil))
    }

    // MARK: - Custom Cyber TabBar
    private var customCyberTabBar: some View {
        HStack(spacing: 0) {
            ForEach(AppPrimaryTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? brandStore.welcomeColor : Color.secondary)

                        Text(tab.title)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? brandStore.welcomeColor.opacity(0.12)
                            : Color.clear
                    )
                    .overlay(alignment: .top) {
                        if selectedTab == tab {
                            Rectangle()
                                .fill(brandStore.welcomeColor)
                                .frame(height: 2)
                                .shadow(color: brandStore.welcomeColor.opacity(0.8), radius: 4, x: 0, y: 0)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(
            Rectangle()
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - 1. CỬA SỔ LOGIN (Token Gate & Key VIP Authentication)

struct LoginAuthWindowView: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @State private var inputToken: String = ""
    @State private var inputKey: String = ""
    @State private var isPasting: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 30)

                // App Logo with Glowing Cyber Accent
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(brandStore.welcomeColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(brandStore.welcomeColor.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: brandStore.welcomeColor.opacity(0.35), radius: 15, x: 0, y: 5)

                    AppLogo(size: 68)
                }

                // GIAI ĐOẠN 1: Chưa Nhập / Chưa Mở Khóa Token Đại Lý
                if !brandStore.isTokenUnlocked {
                    tokenEntryCard
                }
                // GIAI ĐOẠN 2: Đã Mở Khóa Token -> Nhập Key VIP & Get Key 12H
                else {
                    keyEntryCard
                }

                Spacer(minLength: 40)

                // Device & Protection Tag
                VStack(spacing: 4) {
                    Text("PROTECTED BY APIMEOMEO CORE SECURITY")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.7))

                    Text("HWID: \(keyEngine.hwid.prefix(12))... • iOS \(keyEngine.osVersion)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .background(
            ZStack {
                Color.black.ignoresSafeArea()
                // Cyber Grid Background Effect
                LinearGradient(
                    colors: [brandStore.welcomeColor.opacity(0.08), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .onAppear {
            if !brandStore.sellerToken.isEmpty {
                inputToken = brandStore.sellerToken
            }
            if !keyEngine.currentKey.isEmpty {
                inputKey = keyEngine.currentKey
            }
        }
    }

    // MARK: - Token Entry Card (Giai đoạn 1)
    private var tokenEntryCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("XÁC THỰC THƯƠNG HIỆU")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("Nhập mã Token của Đại Lý để kích hoạt cấu hình và mở khóa giao diện.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }

            if let err = brandStore.errorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.12))
                    .border(Color.red.opacity(0.3), width: 1)
            }

            // Input Token
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))

                TextField("Nhập Token Đại Lý (VD: SELLER-MEO)...", text: $inputToken)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                if let clip = UIPasteboard.general.string, !clip.isEmpty {
                    Button {
                        inputToken = clip.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    } label: {
                        Text("DÁN")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.15))
                            .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.3), width: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(uiColor: .tertiarySystemBackground))
            .border(AppTheme.cardBorder, width: 1)

            // Submit Button
            Button {
                Task {
                    _ = await brandStore.verifyToken(inputToken)
                }
            } label: {
                HStack(spacing: 6) {
                    if brandStore.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("XÁC NHẬN & TIẾP TỤC")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(AppTheme.accent)
                .foregroundStyle(.white)
                .shadow(color: AppTheme.accent.opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(brandStore.isLoading)

            // Quick Default Token Button
            Button {
                inputToken = "SELLER-MEO"
                Task {
                    _ = await brandStore.verifyToken("SELLER-MEO")
                }
            } label: {
                Text("DÙNG THƯƠNG HIỆU MẶC ĐỊNH (MEO)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .border(AppTheme.cardBorder, width: 1)
    }

    // MARK: - Key Entry Card (Giai đoạn 2)
    private var keyEntryCard: some View {
        VStack(spacing: 16) {
            // Dynamic Brand Header
            VStack(spacing: 4) {
                Text(brandStore.appName.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(brandStore.welcomeTitle)
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(brandStore.welcomeColor)
                    .multilineTextAlignment(.center)

                if !brandStore.welcomeSubtitle.isEmpty {
                    Text(brandStore.welcomeSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
            }

            // Token Info Tag & Change Token Button
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                    Text("TOKEN: \(brandStore.sellerToken)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                }

                Spacer()

                Button {
                    brandStore.logoutToken()
                } label: {
                    Text("ĐỔI TOKEN")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.12))
                        .border(Color.red.opacity(0.3), width: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.3))
            .border(AppTheme.cardBorder, width: 1)

            // Error Message
            if let err = keyEngine.errorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.12))
                    .border(Color.red.opacity(0.3), width: 1)
            }

            // Key Input Field
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(brandStore.welcomeColor)

                TextField("Nhập mã Key VIP (VD: MEO-XXXX)...", text: $inputKey)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                if let clip = UIPasteboard.general.string, !clip.isEmpty {
                    Button {
                        inputKey = clip.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    } label: {
                        Text("DÁN")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(brandStore.welcomeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(brandStore.welcomeColor.opacity(0.15))
                            .border(brandStore.welcomeColor.opacity(0.3), width: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(uiColor: .tertiarySystemBackground))
            .border(AppTheme.cardBorder, width: 1)

            // Button 1: Đăng Nhập Key
            Button {
                keyEngine.verifyKey(inputKey)
            } label: {
                HStack(spacing: 6) {
                    if keyEngine.isVerifying {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("🚀 ĐĂNG NHẬP HỆ THỐNG")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(brandStore.welcomeColor)
                .foregroundStyle(.white)
                .shadow(color: brandStore.welcomeColor.opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(keyEngine.isVerifying)

            // Button 2: Lấy Key 12H (Tùy biến hiển thị theo Token)
            if brandStore.showGetKey {
                Button {
                    let serverUrl = UserDefaults.standard.string(forKey: "admin_api_server_url") ?? "http://103.238.234.204:5000"
                    let targetUrlStr = brandStore.getKeyURL.isEmpty
                        ? "\(serverUrl)/getkey?hwid=\(keyEngine.hwid)&token=\(brandStore.sellerToken)"
                        : brandStore.getKeyURL

                    if let url = URL(string: targetUrlStr) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 13, weight: .bold))
                        Text(brandStore.getKeyTitle.uppercased())
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.75, blue: 0.10), Color(red: 0.85, green: 0.50, blue: 0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.black)
                    .shadow(color: Color.orange.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }

            // Button 3: Telegram Support
            Button {
                if let url = URL(string: brandStore.telegramURL) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(brandStore.telegramTitle.uppercased())
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Color(red: 0.08, green: 0.55, blue: 0.85))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemBackground))
        .border(brandStore.welcomeColor.opacity(0.3), width: 1)
    }
}

// MARK: - 2. CỬA SỔ HOME (Dashboard Tổng Quan)

struct HomeDashboardWindowView: View {
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var patchEngine = FreeFirePatchEngine.shared
    @AppStorage("selected_game_bundle_id") private var selectedBundleID: String = "com.dts.freefiremax"
    @State private var showCleanSuccessAlert: Bool = false

    let onNavigateToFunction: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Top Status Header
                HStack(spacing: 10) {
                    AppLogo(size: 36)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(brandStore.appName.uppercased())
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("HỆ THỐNG ONLINE • ĐÃ BẢO VỆ")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.green)
                        }
                    }

                    Spacer()

                    // Quick Jump to Telegram
                    Button {
                        if let url = URL(string: brandStore.telegramURL) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(red: 0.08, green: 0.55, blue: 0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)

                // Welcome Title Banner
                VStack(spacing: 4) {
                    Text(brandStore.welcomeTitle)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(brandStore.welcomeColor)
                        .multilineTextAlignment(.center)

                    if !brandStore.welcomeSubtitle.isEmpty {
                        Text(brandStore.welcomeSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 6)

                // Card 1: Thông Tin Bản Quyền Key VIP
                VStack(spacing: 12) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                            Text("BẢN QUYỀN KEY VIP")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Text("● HOẠT ĐỘNG")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .border(Color.green.opacity(0.3), width: 1)
                    }

                    Divider()

                    // Key String Box
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MÃ KEY:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(keyEngine.currentKey)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Button {
                            UIPasteboard.general.string = keyEngine.currentKey
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 10))
                                Text("COPY")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .foregroundStyle(.white)
                            .border(AppTheme.cardBorder, width: 1)
                        }
                        .buttonStyle(.plain)
                    }

                    // Remaining Time & Device Count
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("THỜI GIAN CÒN LẠI:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(keyEngine.formattedRemainingTime)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("THIẾT BỊ:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("\(keyEngine.devicesUsed)/\(keyEngine.deviceLimit) Thiết Bị")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.20, green: 0.60, blue: 0.95))
                        }
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.3), width: 1)

                // Card 2: Chọn Game Mục Tiêu (Target Game Selector)
                VStack(alignment: .leading, spacing: 10) {
                    Text("CHỌN PHIÊN BẢN GAME FREE FIRE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        // Free Fire MAX
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedBundleID = "com.dts.freefiremax"
                            }
                        } label: {
                            HStack(spacing: 8) {
                                GameAsyncIconView(bundleID: "com.dts.freefiremax", size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("FF MAX")
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(selectedBundleID.contains("max") ? Color.white : Color.primary)
                                    Text("Free Fire MAX")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedBundleID.contains("max") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                            .padding(10)
                            .background(selectedBundleID.contains("max") ? AppTheme.accent.opacity(0.12) : Color(uiColor: .secondarySystemBackground))
                            .border(selectedBundleID.contains("max") ? AppTheme.accent : AppTheme.cardBorder, width: 1)
                        }
                        .buttonStyle(.plain)

                        // Free Fire Standard
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedBundleID = "com.dts.freefireth"
                            }
                        } label: {
                            HStack(spacing: 8) {
                                GameAsyncIconView(bundleID: "com.dts.freefireth", size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("FF THƯỜNG")
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(!selectedBundleID.contains("max") ? Color.white : Color.primary)
                                    Text("Free Fire TH")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !selectedBundleID.contains("max") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.orange)
                                }
                            }
                            .padding(10)
                            .background(!selectedBundleID.contains("max") ? Color.orange.opacity(0.12) : Color(uiColor: .secondarySystemBackground))
                            .border(!selectedBundleID.contains("max") ? Color.orange : AppTheme.cardBorder, width: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)

                // Card 3: Quick Action Hub
                VStack(spacing: 10) {
                    // Button: Mở Menu Function
                    Button {
                        onNavigateToFunction()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(brandStore.welcomeColor.opacity(0.2))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(brandStore.welcomeColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("MỞ MENU CHỨC NĂNG (GÓI PATCH)")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("Aim Lock, Định Vị ESP, ModSkin .3105")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(brandStore.welcomeColor)
                        }
                        .padding(12)
                        .background(brandStore.welcomeColor.opacity(0.08))
                        .border(brandStore.welcomeColor.opacity(0.35), width: 1)
                    }
                    .buttonStyle(.plain)

                    // Button: Dọn sạch tất cả Patch
                    Button {
                        patchEngine.cleanAllPatches()
                        showCleanSuccessAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("🧹 DỌN SẠCH TẤT CẢ PATCH (GAME GỐC)")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .border(Color.red.opacity(0.3), width: 1)
                    }
                    .buttonStyle(.plain)

                    // Action Buttons Row: Đăng Xuất & Đổi Token
                    HStack(spacing: 10) {
                        Button {
                            keyEngine.logout()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                Text("ĐĂNG XUẤT KEY")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .foregroundStyle(.white)
                            .border(AppTheme.cardBorder, width: 1)
                        }
                        .buttonStyle(.plain)

                        Button {
                            brandStore.logoutToken()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                Text("ĐỔI TOKEN")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                            .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.3), width: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .alert("Đã Dọn Sạch Game", isPresented: $showCleanSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Toàn bộ file mod đã được gỡ bỏ an toàn, game đã trở về trạng thái gốc 100%.")
        }
    }
}

// MARK: - 3. CỬA SỔ FUNCTION (Menu Gói Patch .3105)

struct FunctionPatchWindowView: View {
    @StateObject private var patchEngine = FreeFirePatchEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @AppStorage("selected_game_bundle_id") private var selectedBundleID: String = "com.dts.freefiremax"
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl
    @State private var selectedCategory: String = "ALL"
    @State private var showCleanAlert: Bool = false

    private var filteredPatches: [FFPatchItem] {
        patchEngine.patches.filter { patch in
            let matchCategory = (selectedCategory == "ALL") || (patch.category == selectedCategory)
            return matchCategory
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MENU FUNCTION .3105")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text(selectedBundleID.contains("max") ? "⚡ Free Fire MAX" : "🔥 Free Fire Standard")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(brandStore.welcomeColor)
                }

                Spacer()

                Button {
                    patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                        Text("TẢI LẠI")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .foregroundStyle(.white)
                    .border(AppTheme.cardBorder, width: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .border(AppTheme.cardBorder, width: 1)

            // Game Switcher Segment
            HStack(spacing: 8) {
                Button {
                    selectedBundleID = "com.dts.freefiremax"
                    patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
                } label: {
                    Text("⚡ FREE FIRE MAX")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(selectedBundleID.contains("max") ? brandStore.welcomeColor : Color(uiColor: .tertiarySystemBackground))
                        .foregroundStyle(selectedBundleID.contains("max") ? Color.white : Color.secondary)
                        .border(selectedBundleID.contains("max") ? brandStore.welcomeColor : AppTheme.cardBorder, width: 1)
                }
                .buttonStyle(.plain)

                Button {
                    selectedBundleID = "com.dts.freefireth"
                    patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
                } label: {
                    Text("🔥 FF THƯỜNG")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(!selectedBundleID.contains("max") ? Color.orange : Color(uiColor: .tertiarySystemBackground))
                        .foregroundStyle(!selectedBundleID.contains("max") ? Color.white : Color.secondary)
                        .border(!selectedBundleID.contains("max") ? Color.orange : AppTheme.cardBorder, width: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Category Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    categoryChip(title: "TẤT CẢ", tag: "ALL")
                    categoryChip(title: "⚡ Aim File", tag: "Aim File")
                    categoryChip(title: "👁️ Định Vị (ESP)", tag: "Định Vị")
                    categoryChip(title: "⚙️ ModSkin File", tag: "ModSkin File")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            // Patch List
            if patchEngine.isFetching {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                        .tint(brandStore.welcomeColor)
                    Text("Đang tải danh sách chức năng từ Server...")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if filteredPatches.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Chưa có gói Patch nào trong mục này.")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Admin có thể upload gói .3105 trên Web Admin để hiển thị tại đây!")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredPatches) { patch in
                            patchRowCard(patch: patch)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            // Bottom Action Bar: Tắt Toàn Bộ Patch
            Button {
                patchEngine.cleanAllPatches()
                showCleanAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("🧹 TẮT TOÀN BỘ PATCH (RESTORE GỐC)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .border(Color.red.opacity(0.35), width: 1)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .onAppear {
            patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
        }
        .alert("Đã Tắt Toàn Bộ Patch", isPresented: $showCleanAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Đã gỡ bỏ toàn bộ file can thiệp, game đã trở về trạng thái gốc an toàn 100%.")
        }
    }

    private func categoryChip(title: String, tag: String) -> some View {
        Button {
            selectedCategory = tag
        } label: {
            Text(title)
                .font(.system(size: 11, weight: selectedCategory == tag ? .black : .semibold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == tag ? brandStore.welcomeColor.opacity(0.18) : Color(uiColor: .tertiarySystemBackground))
                .foregroundStyle(selectedCategory == tag ? brandStore.welcomeColor : Color.secondary)
                .border(selectedCategory == tag ? brandStore.welcomeColor : AppTheme.cardBorder, width: 1)
        }
        .buttonStyle(.plain)
    }

    private func patchRowCard(patch: FFPatchItem) -> some View {
        HStack(spacing: 12) {
            // Category Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(patch.isEnabled ? brandStore.welcomeColor.opacity(0.2) : Color.black.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .border(patch.isEnabled ? brandStore.welcomeColor.opacity(0.5) : AppTheme.cardBorder, width: 1)

                Image(systemName: patch.category.contains("Aim") ? "bolt.fill" : (patch.category.contains("Định Vị") ? "eye.fill" : "gearshape.fill"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(patch.isEnabled ? brandStore.welcomeColor : Color.secondary)
            }

            // Patch Info
            VStack(alignment: .leading, spacing: 2) {
                Text(patch.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(patch.category)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(brandStore.welcomeColor)

                    if patch.password != nil && !patch.password!.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                            Text("PASS")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                        }
                        .foregroundStyle(Color(red: 0.20, green: 0.60, blue: 0.95))
                    }
                }
            }

            Spacer()

            // Smooth Toggle Switch
            Toggle("", isOn: Binding(
                get: { patch.isEnabled },
                set: { _ in
                    patchEngine.togglePatch(id: patch.id, bundleID: selectedBundleID, serverUrl: adminServerUrl)
                }
            ))
            .labelsHidden()
            .tint(brandStore.welcomeColor)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .border(patch.isEnabled ? brandStore.welcomeColor.opacity(0.4) : AppTheme.cardBorder, width: 1)
    }
}

// MARK: - 4. CỬA SỔ SETTINGS (Hệ Thống & Cài Đặt)

struct SettingsSystemView: View {
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @AppStorage("app.appearance") private var appearance = AppAppearance.dark.rawValue
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl
    @State private var showCopiedHwid: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 2) {
                    Text("CÀI ĐẶT HỆ THỐNG")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("Cấu hình thiết bị, giao diện & kết nối máy chủ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)

                // Card: Hardware & HWID
                VStack(alignment: .leading, spacing: 10) {
                    Text("THÔNG TIN THIẾT BỊ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Divider()

                    infoRow(title: "THIẾT BỊ", value: "\(AppInfo.displayMachineName) (\(AppInfo.hardwareDisplayName))")
                    infoRow(title: "PHIÊN BẢN IOS", value: AppInfo.osVersion)

                    // HWID with Copy Button
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MÃ HWID KHÓA MÁY:")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(keyEngine.hwid)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(red: 0.20, green: 0.60, blue: 0.95))
                                .lineLimit(1)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = keyEngine.hwid
                                showCopiedHwid = true
                            } label: {
                                Text(showCopiedHwid ? "ĐÃ COPY" : "COPY HWID")
                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.20, green: 0.60, blue: 0.95))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 0.20, green: 0.60, blue: 0.95).opacity(0.12))
                                    .border(Color(red: 0.20, green: 0.60, blue: 0.95).opacity(0.3), width: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)

                // Card: Server Connection
                VStack(alignment: .leading, spacing: 10) {
                    Text("KẾT NỐI MÁY CHỦ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Divider()

                    infoRow(title: "MÁY CHỦ API", value: adminServerUrl)
                    infoRow(title: "TRẠNG THÁI", value: "● ĐANG KẾT NỐI (ONLINE)")
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)

                // Card: Theme / Appearance
                VStack(alignment: .leading, spacing: 10) {
                    Text("GIAO DIỆN / THEME")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(spacing: 8) {
                        ForEach(AppAppearance.allCases) { item in
                            Button {
                                appearance = item.rawValue
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: item.iconName)
                                        .font(.system(size: 11, weight: .bold))
                                    Text(item.displayName)
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(appearance == item.rawValue ? brandStore.welcomeColor : Color(uiColor: .tertiarySystemBackground))
                                .foregroundStyle(appearance == item.rawValue ? Color.white : Color.primary)
                                .border(appearance == item.rawValue ? brandStore.welcomeColor : AppTheme.cardBorder, width: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(14)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)

                // Danger Actions
                VStack(spacing: 10) {
                    Button {
                        keyEngine.logout()
                    } label: {
                        Text("🔒 ĐĂNG XUẤT KEY VIP")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color.red.opacity(0.12))
                            .foregroundStyle(.red)
                            .border(Color.red.opacity(0.3), width: 1)
                    }
                    .buttonStyle(.plain)

                    Button {
                        brandStore.logoutToken()
                    } label: {
                        Text("🔄 ĐỔI TOKEN ĐẠI LÝ")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.12))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                            .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.3), width: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 5. EMERGENCY LOCKDOWN VIEW (Chống Crack / Khóa Toàn Bộ App)

struct EmergencyLockdownView: View {
    @StateObject private var keyEngine = KeyAuthEngine.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 90, height: 90)
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                        .frame(width: 90, height: 90)

                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(Color.red)
                }

                VStack(spacing: 8) {
                    Text("HỆ THỐNG ĐÃ BỊ KHÓA")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text(keyEngine.emergencyMessage ?? "Phát hiện phiên bản bị can thiệp trái phép hoặc hệ thống đang bảo trì. Vui lòng bấm vào nút bên dưới để nhận hỗ trợ!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .lineSpacing(3)
                }

                if let urlStr = keyEngine.emergencyLinkURL,
                   let url = URL(string: urlStr), !urlStr.isEmpty {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 15, weight: .bold))
                            Text(keyEngine.emergencyLinkTitle ?? "THAM GIA TELEGRAM")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .shadow(color: Color.red.opacity(0.5), radius: 12, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                }

                Spacer()

                Text("PROTECTED BY APIMEOMEO • ANTI-CRACK ENGINE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.bottom, 20)
            }
        }
    }
}
