import SwiftUI
import UIKit

// MARK: - Main ContentView

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @State private var showProfileSheet: Bool = false
    @AppStorage("app.appearance") private var appearance = AppAppearance.dark.rawValue

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            // 1. EMERGENCY MODE (Khi Admin bật Khóa Hệ Thống hoặc Server Offline)
            if keyEngine.isEmergencyMode {
                EmergencyLockdownView()
                    .transition(.opacity)
                    .zIndex(99)
            }
            // 2. TOKEN GATE SCREEN (Khi chưa xác thực Token Đại Lý)
            else if !brandStore.isTokenUnlocked {
                TokenGateScreen()
                    .transition(.opacity)
                    .zIndex(95)
            }
            // 3. KEY LOGIN SCREEN (Khi đã có Token nhưng chưa đăng nhập Key VIP)
            else if !keyEngine.isAuthenticated {
                CleanLoginWindowView(onOpenProfile: {
                    showProfileSheet = true
                })
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                .zIndex(90)
            }
            // 4. MAIN APP SCREEN (Khi đã đăng nhập Key VIP thành công)
            else {
                CleanMainAppView(onOpenProfile: {
                    showProfileSheet = true
                })
                .transition(.opacity)
            }
        }
        .preferredColorScheme(appearance == "dark" ? .dark : (appearance == "light" ? .light : nil))
        .sheet(isPresented: $showProfileSheet) {
            UserProfileSheetView()
        }
    }
}

// MARK: - 1. MÀN HÌNH NHẬP TOKEN (GIAO DIỆN XÁC THỰC TOKEN ĐẸP MẮT)

struct TokenGateScreen: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @State private var inputToken: String = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 40)

                // Logo Phát Sáng
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 86, height: 86)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: Color.red.opacity(0.35), radius: 15, x: 0, y: 5)

                    AppLogo(size: 72)
                }

                // Tiêu Đề
                VStack(spacing: 6) {
                    Text("XÁC THỰC THƯƠNG HIỆU")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("Vui lòng nhập Token Đại Lý để tải giao diện và kích hoạt hệ thống.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Card Nhập Token
                VStack(spacing: 14) {
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

                    // Ô Nhập Token
                    HStack(spacing: 8) {
                        Image(systemName: "shield.fill")
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

                    // Nút Xác Nhận Token
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
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 14, weight: .bold))
                                Text("⚡ XÁC NHẬN TOKEN")
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.20, blue: 0.28), Color(red: 0.70, green: 0.08, blue: 0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(brandStore.isLoading)

                    // Nút Dùng Token Mặc Định
                    Button {
                        inputToken = "SELLER-MEO"
                        Task {
                            _ = await brandStore.verifyToken("SELLER-MEO")
                        }
                    } label: {
                        Text("🌐 DÙNG TOKEN MẶC ĐỊNH (SELLER-MEO)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(18)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(Color.red.opacity(0.3), width: 1)

                Spacer(minLength: 40)

                Text("PROTECTED BY APIMEOMEO CORE SECURITY")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .background(
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(
                    colors: [Color.red.opacity(0.08), Color.black],
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
        }
    }
}

// MARK: - 2. CỬA SỔ ĐĂNG NHẬP KEY (CÓ AVATAR MỞ PROFILE & ẨN HIỆN GETKEY CHUẨN)

struct CleanLoginWindowView: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @State private var inputKey: String = ""

    let onOpenProfile: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Top Header Bar: Avatar Button (Bấm vào xem Profile)
                HStack {
                    Button(action: onOpenProfile) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(brandStore.welcomeColor.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().stroke(brandStore.welcomeColor.opacity(0.5), lineWidth: 1.5)
                                    )

                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(brandStore.welcomeColor)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(brandStore.appName.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)

                                Text("Bấm xem Profile ❯")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(brandStore.welcomeColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Huy hiệu Token
                    Text("TOKEN: \(brandStore.sellerToken)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.12))
                        .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.3), width: 1)
                }
                .padding(.horizontal, 4)
                .padding(.top, 10)

                Spacer(minLength: 20)

                // Logo App
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(brandStore.welcomeColor.opacity(0.15))
                        .frame(width: 82, height: 82)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(brandStore.welcomeColor.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: brandStore.welcomeColor.opacity(0.3), radius: 12, x: 0, y: 4)

                    AppLogo(size: 70)
                }

                // Tiêu Đề Chào Mừng
                VStack(spacing: 6) {
                    Text(brandStore.welcomeTitle)
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(brandStore.welcomeColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)

                    if !brandStore.welcomeSubtitle.isEmpty {
                        Text(brandStore.welcomeSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }

                // Card Nhập Key VIP
                VStack(spacing: 14) {
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

                    // Ô Nhập Key
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(brandStore.welcomeColor)

                        TextField("Nhập mã Key VIP của bạn...", text: $inputKey)
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

                    // Nút Đăng Nhập Key
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
                                Text("ĐĂNG NHẬP")
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

                    // Nút Lấy Key 12H (CHỈ HIỆN KHI TOKEN ĐƯỢC ADMIN BẬT ON)
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
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.75, blue: 0.10), Color(red: 0.85, green: 0.50, blue: 0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(.black)
                            .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }

                    // Nút Telegram Hỗ Trợ
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
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Color(red: 0.08, green: 0.55, blue: 0.85))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(brandStore.welcomeColor.opacity(0.3), width: 1)

                Spacer(minLength: 30)

                // Footer
                Text("PROTECTED BY APIMEOMEO SECURITY ENGINE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 18)
        }
        .background(
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(
                    colors: [brandStore.welcomeColor.opacity(0.08), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .onAppear {
            if !keyEngine.currentKey.isEmpty {
                inputKey = keyEngine.currentKey
            }
        }
    }
}

// MARK: - 3. CỬA SỔ CHÍNH MENU CHỨC NĂNG (GIAO DIỆN HIỆN ĐẠI & AVATAR PROFILE)

struct CleanMainAppView: View {
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var patchEngine = FreeFirePatchEngine.shared
    @AppStorage("selected_game_bundle_id") private var selectedBundleID: String = "com.dts.freefiremax"
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl
    @State private var selectedCategory: String = "ALL"
    @State private var showCleanAlert: Bool = false

    let onOpenProfile: () -> Void

    private var isFFM: Bool {
        selectedBundleID.contains("max")
    }

    private var filteredPatches: [FFPatchItem] {
        patchEngine.patches.filter { patch in
            let matchCategory = (selectedCategory == "ALL") || (patch.category == selectedCategory)
            return matchCategory
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar Có Avatar (Avt)
            headerBar

            // Nút Chọn Game: FF MAX | FF THƯỜNG
            gameSelectorBar

            // Bộ Lọc Mục: TẤT CẢ | AIM | ĐỊNH VỊ | MODSKIN
            categoryBar

            // Danh Sách Chức Năng
            patchListView

            // Thanh Tiện Ích Dưới Cùng (Dọn Sạch, Telegram, Đăng Xuất)
            bottomActionBar
        }
        .onAppear {
            patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
        }
        .alert("Đã Tắt Toàn Bộ Chức Năng", isPresented: $showCleanAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Đã khôi phục game về trạng thái gốc an toàn 100%.")
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Bấm vào Avatar mở Profile
            Button(action: onOpenProfile) {
                ZStack {
                    Circle()
                        .fill(brandStore.welcomeColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(brandStore.welcomeColor.opacity(0.6), lineWidth: 1.5)
                        )

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(brandStore.welcomeColor)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(brandStore.appName.uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("● VIP")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .border(Color.green.opacity(0.3), width: 1)
                }

                Text("Hạn: \(keyEngine.formattedRemainingTime)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
            }

            Spacer()

            // Nút Tải Lại
            Button {
                patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .border(AppTheme.cardBorder, width: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .border(AppTheme.cardBorder, width: 1)
    }

    // MARK: - Game Selector Bar
    private var gameSelectorBar: some View {
        HStack(spacing: 8) {
            // Nút Free Fire MAX
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedBundleID = "com.dts.freefiremax"
                    patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("FREE FIRE MAX")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isFFM ? brandStore.welcomeColor : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(isFFM ? Color.white : Color.secondary)
                .border(isFFM ? brandStore.welcomeColor : AppTheme.cardBorder, width: 1)
            }
            .buttonStyle(.plain)

            // Nút Free Fire Thường
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedBundleID = "com.dts.freefireth"
                    patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: selectedBundleID)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("FF THƯỜNG")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(!isFFM ? Color.orange : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(!isFFM ? Color.white : Color.secondary)
                .border(!isFFM ? Color.orange : AppTheme.cardBorder, width: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Category Filter Bar
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryTab(title: "TẤT CẢ", tag: "ALL")
                categoryTab(title: "⚡ Aim File", tag: "Aim File")
                categoryTab(title: "👁️ Định Vị (ESP)", tag: "Định Vị")
                categoryTab(title: "⚙️ ModSkin", tag: "ModSkin File")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
    }

    private func categoryTab(title: String, tag: String) -> some View {
        Button {
            selectedCategory = tag
        } label: {
            Text(title)
                .font(.system(size: 11, weight: selectedCategory == tag ? .black : .semibold, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedCategory == tag ? brandStore.welcomeColor.opacity(0.18) : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(selectedCategory == tag ? brandStore.welcomeColor : Color.secondary)
                .border(selectedCategory == tag ? brandStore.welcomeColor : AppTheme.cardBorder, width: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Patch List View
    private var patchListView: some View {
        Group {
            if patchEngine.isFetching {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .tint(brandStore.welcomeColor)
                    Text("Đang tải danh sách chức năng...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if filteredPatches.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "tray.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Chưa có chức năng nào trong mục này.")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredPatches) { patch in
                            patchRow(patch: patch)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private func patchRow(patch: FFPatchItem) -> some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(patch.isEnabled ? brandStore.welcomeColor.opacity(0.2) : Color.black.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .border(patch.isEnabled ? brandStore.welcomeColor.opacity(0.5) : AppTheme.cardBorder, width: 1)

                Image(systemName: patch.category.contains("Aim") ? "bolt.fill" : (patch.category.contains("Định Vị") ? "eye.fill" : "gearshape.fill"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(patch.isEnabled ? brandStore.welcomeColor : Color.secondary)
            }

            // Tên Chức Năng (Ẩn hoàn toàn đuôi .3105 & PASS)
            VStack(alignment: .leading, spacing: 2) {
                Text(cleanPatchName(patch.name))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(patch.category)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(brandStore.welcomeColor)
            }

            Spacer()

            // Công Tắc Gạt Bật / Tắt
            Toggle("", isOn: Binding(
                get: { patch.isEnabled },
                set: { _ in
                    patchEngine.togglePatch(id: patch.id, bundleID: selectedBundleID, serverUrl: adminServerUrl)
                }
            ))
            .labelsHidden()
            .tint(brandStore.welcomeColor)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .border(patch.isEnabled ? brandStore.welcomeColor.opacity(0.4) : AppTheme.cardBorder, width: 1)
    }

    private func cleanPatchName(_ raw: String) -> String {
        return raw.replacingOccurrences(of: ".3105", with: "")
            .replacingOccurrences(of: ".zip", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 6) {
            // Nút Dọn Sạch Game
            Button {
                patchEngine.cleanAllPatches()
                showCleanAlert = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("🧹 TẮT TOÀN BỘ CHỨC NĂNG (GAME GỐC)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                }
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Color.red.opacity(0.15))
                .foregroundStyle(.red)
                .border(Color.red.opacity(0.35), width: 1)
            }
            .buttonStyle(.plain)

            // Nút Telegram & Đăng Xuất
            HStack(spacing: 8) {
                Button {
                    if let url = URL(string: brandStore.telegramURL) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 10))
                        Text(brandStore.telegramTitle.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Color(red: 0.08, green: 0.55, blue: 0.85).opacity(0.2))
                    .foregroundStyle(Color(red: 0.38, green: 0.75, blue: 1.0))
                    .border(Color(red: 0.08, green: 0.55, blue: 0.85).opacity(0.4), width: 1)
                }
                .buttonStyle(.plain)

                Button {
                    keyEngine.logout()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("ĐĂNG XUẤT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .foregroundStyle(.white)
                    .border(AppTheme.cardBorder, width: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .border(AppTheme.cardBorder, width: 1)
    }
}

// MARK: - 4. MÀN HÌNH PROFILE (BẤM VÀO AVATAR XEM THÔNG TIN MÁY / HỖ TRỢ IOS / HWID)

struct UserProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @State private var showCopiedHwid: Bool = false
    @State private var showTokenEditModal: Bool = false
    @State private var inputEditToken: String = ""

    // Kiểm tra tương thích máy & iOS
    private var isDeviceSupported: Bool {
        return true // Hỗ trợ toàn bộ dòng máy 64-bit iPhone/iPad
    }

    private var isIOSSupported: Bool {
        let v = AppInfo.versionTuple
        return ExploitSupportPolicy.isSupported(major: v.major, minor: v.minor, patch: v.patch, build: AppInfo.osBuild) || v.major >= 15
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Avatar Header Card
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(brandStore.welcomeColor.opacity(0.18))
                                .frame(width: 76, height: 76)
                                .overlay(
                                    Circle().stroke(brandStore.welcomeColor, lineWidth: 2)
                                )
                                .shadow(color: brandStore.welcomeColor.opacity(0.4), radius: 10, x: 0, y: 3)

                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 46, weight: .bold))
                                .foregroundStyle(brandStore.welcomeColor)
                        }

                        VStack(spacing: 2) {
                            Text(AppInfo.hardwareDisplayName.uppercased())
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)

                            Text(brandStore.appName)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(brandStore.welcomeColor)
                        }
                    }
                    .padding(.top, 10)

                    // CARD 1: THÔNG TIN HỖ TRỢ MÁY & HỖ TRỢ IOS
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TƯƠNG THÍCH & HỖ TRỢ HỆ THỐNG")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Divider()

                        // Support Máy (Thiết Bị)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SUPPORT MÁY:")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(AppInfo.displayMachineName)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            if isDeviceSupported {
                                Text("● HỖ TRỢ")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .border(Color.green.opacity(0.3), width: 1)
                            } else {
                                Text("● KHÔNG HỖ TRỢ")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.15))
                                    .border(Color.red.opacity(0.3), width: 1)
                            }
                        }

                        // Support iOS (Phiên Bản iOS)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SUPPORT IOS:")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text("iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            if isIOSSupported {
                                Text("● HỖ TRỢ")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .border(Color.green.opacity(0.3), width: 1)
                            } else {
                                Text("● KHÔNG HỖ TRỢ")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.15))
                                    .border(Color.red.opacity(0.3), width: 1)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .border(AppTheme.cardBorder, width: 1)

                    // CARD 2: THÔNG TIN HWID & KHÓA THIẾT BỊ
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BẢO MẬT & MÃ HWID")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("MÃ HWID KHÓA THIẾT BỊ:")
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
                                    Text(showCopiedHwid ? "ĐÃ COPY" : "COPY")
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

                        if keyEngine.isAuthenticated {
                            HStack {
                                Text("THỜI HẠN KEY VIP:")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(keyEngine.formattedRemainingTime)
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .border(AppTheme.cardBorder, width: 1)

                    // CARD 3: TOKEN ĐẠI LÝ & QUYỀN GETKEY
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THƯƠNG HIỆU & TOKEN ĐẠI LÝ")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Divider()

                        HStack {
                            Text("MÃ TOKEN:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(brandStore.sellerToken)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                        }

                        HStack {
                            Text("QUYỀN GET KEY 12H:")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if brandStore.showGetKey {
                                Text("● ĐÃ MỞ (ON)")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.green)
                            } else {
                                Text("● TẮT (OFF)")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.secondary)
                            }
                        }

                        // Nút Đổi Token
                        Button {
                            inputEditToken = brandStore.sellerToken
                            showTokenEditModal = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                Text("🔄 ĐỔI TOKEN ĐẠI LÝ KHÁC")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.12))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                            .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.3), width: 1)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .border(AppTheme.cardBorder, width: 1)

                    // Nút Đăng Xuất Key
                    if keyEngine.isAuthenticated {
                        Button {
                            keyEngine.logout()
                            dismiss()
                        } label: {
                            Text("🔒 ĐĂNG XUẤT KEY VIP")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .border(Color.red.opacity(0.35), width: 1)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("THÔNG TIN PROFILE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(brandStore.welcomeColor)
                }
            }
            .sheet(isPresented: $showTokenEditModal) {
                VStack(spacing: 16) {
                    Text("ĐỔI TOKEN ĐẠI LÝ")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.top, 20)

                    TextField("Nhập Token Đại Lý mới...", text: $inputEditToken)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .border(AppTheme.cardBorder, width: 1)
                        .padding(.horizontal, 20)

                    Button {
                        Task {
                            let ok = await brandStore.verifyToken(inputEditToken)
                            if ok {
                                showTokenEditModal = false
                                dismiss()
                            }
                        }
                    } label: {
                        Text("LƯU TOKEN")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(brandStore.welcomeColor)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showTokenEditModal = false
                    } label: {
                        Text("HỦY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 20)
                }
                .background(Color.black.ignoresSafeArea())
            }
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

                    Text(keyEngine.emergencyMessage ?? "Hệ thống đang bảo trì hoặc phát hiện can thiệp. Vui lòng bấm vào nút bên dưới để nhận hỗ trợ!")
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
