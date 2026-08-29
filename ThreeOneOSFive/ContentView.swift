import SwiftUI
import UIKit

// MARK: - Main ContentView

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
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
            // 2. CỬA SỔ LOGIN (Khi chưa đăng nhập Key VIP)
            else if !keyEngine.isAuthenticated {
                CleanLoginWindowView()
                    .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                    .zIndex(90)
            }
            // 3. CỬA SỔ CHÍNH MENU CHỨC NĂNG (Khi đã đăng nhập Key VIP thành công)
            else {
                CleanMainAppView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(appearance == "dark" ? .dark : (appearance == "light" ? .light : nil))
    }
}

// MARK: - 1. CỬA SỔ ĐĂNG NHẬP (CLEAN & DỄ HIỂU 100%)

struct CleanLoginWindowView: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @State private var inputKey: String = ""
    @State private var inputToken: String = ""
    @State private var showTokenModal: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 40)

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

                // Tiêu Đề Thương Hiệu & Lời Chào
                VStack(spacing: 6) {
                    Text(brandStore.appName.uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)

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
                    // Thông Báo Lỗi Nếu Có
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

                    // Nút Lấy Key 12H (Tùy Chọn)
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

                // Nút Đổi Token Đại Lý
                Button {
                    inputToken = brandStore.sellerToken
                    showTokenModal = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 10))
                        Text(brandStore.sellerToken.isEmpty ? "CÀI ĐẶT TOKEN ĐẠI LÝ" : "TOKEN: \(brandStore.sellerToken) (ĐỔI)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .border(AppTheme.cardBorder, width: 1)
                }
                .buttonStyle(.plain)

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
            if brandStore.sellerToken.isEmpty {
                // Tự động gán token mặc định nếu chưa có
                Task {
                    _ = await brandStore.verifyToken("SELLER-MEO")
                }
            }
            if !keyEngine.currentKey.isEmpty {
                inputKey = keyEngine.currentKey
            }
        }
        .sheet(isPresented: $showTokenModal) {
            tokenModalView
        }
    }

    // Modal Đổi Token
    private var tokenModalView: some View {
        VStack(spacing: 16) {
            Text("CẤU HÌNH TOKEN ĐẠI LÝ")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.top, 20)

            Text("Nhập mã Token để tải giao diện riêng của đại lý.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("Nhập Token (VD: SELLER-MEO)...", text: $inputToken)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)
                .padding(.horizontal, 20)

            Button {
                Task {
                    let ok = await brandStore.verifyToken(inputToken)
                    if ok { showTokenModal = false }
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
                showTokenModal = false
            } label: {
                Text("ĐÓNG")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - 2. CỬA SỔ CHÍNH MENU CHỨC NĂNG (GIAO DIỆN HIỆN ĐẠI, DỄ DÙNG)

struct CleanMainAppView: View {
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var patchEngine = FreeFirePatchEngine.shared
    @AppStorage("selected_game_bundle_id") private var selectedBundleID: String = "com.dts.freefiremax"
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl
    @State private var selectedCategory: String = "ALL"
    @State private var showCleanAlert: Bool = false

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
            // Header: Thông tin App & Hạn Dùng
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
            AppLogo(size: 34)

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

// MARK: - 3. EMERGENCY LOCKDOWN VIEW (Chống Crack / Khóa Toàn Bộ App)

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
