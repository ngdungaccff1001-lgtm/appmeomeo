import SwiftUI
import UIKit

// MARK: - Main ContentView

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var toastManager = AppToastManager.shared
    @State private var isLoadingFinished: Bool = false
    @State private var showProfileSheet: Bool = false
    @State private var showCheckLogSheet: Bool = false
    @AppStorage("app.appearance") private var appearance = AppAppearance.dark.rawValue

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            // 1. GIAI ĐOẠN VỪA VÀO APP: LOADING TỪ 1% - 100% (RANDOM 4 - 7S)
            if !isLoadingFinished {
                CyberLoadingScreen(isFinished: $isLoadingFinished)
                    .transition(.opacity)
                    .zIndex(100)
            }
            // 2. KHI BẬT "CHẾ ĐỘ ĐÃ BỊ CRACK" TRÊN ADMIN (URL WORKING + EMERGENCY MODE ON)
            else if brandStore.isCrackLockdown || keyEngine.isEmergencyMode {
                CrackLockdownScreen()
                    .transition(.opacity)
                    .zIndex(99)
            }
            // 3. KHI API SERVER KHÔNG CHẠY HOẶC OFFLINE (Hiển thị chính xác 100% như ảnh)
            else if brandStore.isServerOffline {
                ServerMaintenanceScreen()
                    .transition(.opacity)
                    .zIndex(98)
            }
            // 4. KHI CHƯA NHẬP TOKEN: MÀN HÌNH NHẬP TOKEN
            else if !brandStore.isTokenUnlocked {
                TokenEntryScreen()
                    .transition(.opacity)
                    .zIndex(95)
            }
            // 5. KHI ĐÃ CÓ TOKEN: GIAO DIỆN CHÍNH
            else {
                MainBrandScreen(onOpenProfile: {
                    showProfileSheet = true
                }, onOpenCheckLog: {
                    showCheckLogSheet = true
                })
                .transition(.opacity)
                .zIndex(90)
            }
        }
        .overlay(topToastOverlay, alignment: .topTrailing)
        .preferredColorScheme(appearance == "dark" ? .dark : (appearance == "light" ? .light : nil))
        .sheet(isPresented: $showProfileSheet) {
            UserProfileSheetView()
        }
        .sheet(isPresented: $showCheckLogSheet) {
            CheckLogSheetView()
        }
        .onAppear {
            brandStore.checkServerHealth()
        }
    }

    // MARK: - Top-Right Toast Alert Notification (Hiển thị 3s rồi tự out)
    @ViewBuilder
    private var topToastOverlay: some View {
        if let toast = toastManager.currentToast {
            VStack {
                HStack {
                    Spacer()

                    HStack(spacing: 10) {
                        Image(systemName: toast.type.iconName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(toast.type.color)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(toast.title)
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)

                            Text(toast.message)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(2)
                        }

                        Button {
                            toastManager.hide()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .secondarySystemBackground).opacity(0.95))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(toast.type.color.opacity(0.6), lineWidth: 1.5)
                            )
                            .shadow(color: toast.type.color.opacity(0.35), radius: 12, x: 0, y: 4)
                    )
                    .frame(maxWidth: 320)
                }
                .padding(.top, 48)
                .padding(.trailing, 14)

                Spacer()
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
            .zIndex(999)
        }
    }
}

// MARK: - 1. MÀN HÌNH LOADING HÌNH TRÒN (TIÊU ĐỀ: PATH DATA CHEAT)

struct CyberLoadingScreen: View {
    @Binding var isFinished: Bool
    @State private var progress: Double = 1.0
    @State private var rotationDegrees: Double = 0
    @State private var statusText: String = "Đang kiểm tra bảo mật dữ liệu..."

    let totalDuration: Double = Double.random(in: 4.0...7.0)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // TIÊU ĐỀ: PATH DATA CHEAT
                VStack(spacing: 6) {
                    Text("PATH DATA CHEAT")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color(red: 0.95, green: 0.25, blue: 0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.red.opacity(0.6), radius: 10, x: 0, y: 0)

                    Text("HỆ THỐNG TỐI ƯU DỮ LIỆU GAME")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                // LOADING HÌNH TRÒN CÔNG NGHỆ CAO
                ZStack {
                    // Vòng tròn nền
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 130, height: 130)

                    // Vòng xoay dash trang trí ngoài
                    Circle()
                        .stroke(
                            Color.red.opacity(0.35),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 10])
                        )
                        .frame(width: 154, height: 154)
                        .rotationEffect(.degrees(rotationDegrees))

                    // Vòng tiến trình chính hình tròn (1% - 100%)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(1.0, progress / 100.0)))
                        .stroke(
                            LinearGradient(
                                colors: [Color.red, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color.red.opacity(0.8), radius: 8, x: 0, y: 0)

                    // Phần trăm ở chính giữa vòng tròn
                    VStack(spacing: 2) {
                        Text("\(Int(progress))%")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)

                        Text("LOADING")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.red)
                    }
                }
                .padding(.vertical, 10)

                // Dòng trạng thái
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 20)

                Spacer()

                Text("INITIALIZING SYSTEM • PLEASE WAIT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                rotationDegrees = 360
            }
            runLoadingAnimation()
        }
    }

    private func runLoadingAnimation() {
        let startTime = Date()
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let percent = min(100.0, (elapsed / totalDuration) * 100.0)
            self.progress = percent

            if percent < 30 {
                self.statusText = "Đang kiểm tra dữ liệu hệ thống..."
            } else if percent < 60 {
                self.statusText = "Đang kết nối máy chủ API..."
            } else if percent < 90 {
                self.statusText = "Đang tải cấu hình..."
            } else {
                self.statusText = "Khởi tạo hoàn tất!"
            }

            if elapsed >= totalDuration {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isFinished = true
                }
            }
        }
    }
}

// MARK: - 2A. MÀN HÌNH MÁY CHỦ BẢO TRÌ (KHI API KHÔNG CHẠY / OFFLINE - GIỐNG ẢNH 100%)

struct ServerMaintenanceScreen: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @State private var isChecking: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                // Icon Bảo Trì Phát Sáng Cam Cyber
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Circle()
                        .stroke(Color.orange.opacity(0.4), lineWidth: 2)
                        .frame(width: 110, height: 110)

                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(Color.orange)
                }
                .shadow(color: Color.orange.opacity(0.4), radius: 18, x: 0, y: 5)

                // Tiêu Đề & Thông Báo
                VStack(spacing: 10) {
                    Text("MÁY CHỦ ĐANG BẢO TRÌ")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("Máy chủ đang bảo trì nâng cấp hệ thống!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Nút Thử Lại Kết Nối
                Button {
                    isChecking = true
                    Task {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        brandStore.checkServerHealth()
                        isChecking = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isChecking {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                            Text("THỬ LẠI KẾT NỐI")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.orange)
                    .foregroundStyle(.black)
                    .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 36)

                Spacer()

                Text("PROTECTED BY APIMEOMEO • SYSTEM ENGINE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - 2B. MÀN HÌNH CHẾ ĐỘ ĐÃ BỊ CRACK (KHI URL WORKING MÀ BẬT EMERGENCY MODE TRÊN ADMIN)

struct CrackLockdownScreen: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var keyEngine = KeyAuthEngine.shared

    private var emergencyMessage: String {
        let msg = keyEngine.emergencyMessage ?? brandStore.crackEmergencyMessage
        return msg.isEmpty ? "Phát hiện phiên bản bị can thiệp trái phép, vui lòng tham gia Telegram để nhận hỗ trợ!" : msg
    }

    private var linkTitle: String {
        let title = keyEngine.emergencyLinkTitle ?? brandStore.crackLinkTitle
        return title.isEmpty ? "THAM GIA TELEGRAM" : title
    }

    private var linkURL: String {
        let url = keyEngine.emergencyLinkURL ?? brandStore.crackLinkURL
        return url.isEmpty ? "https://t.me/ioscrackvn" : url
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                // Icon Khiên Cảnh Báo Đỏ Cyber
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 110, height: 110)
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: 110, height: 110)

                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(Color.red)
                }
                .shadow(color: Color.red.opacity(0.5), radius: 20, x: 0, y: 5)

                // Tiêu Đề & Thông Báo Khẩn Cấp Từ Admin
                VStack(spacing: 10) {
                    Text("CẢNH BÁO KHẨN CẤP")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text(emergencyMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineSpacing(4)
                }

                // 1 NÚT DUY NHẤT DẪN VÀO LINK TELEGRAM TỪ ADMIN
                if let url = URL(string: linkURL), !linkURL.isEmpty {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text(linkTitle.uppercased())
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.20, blue: 0.28), Color(red: 0.70, green: 0.08, blue: 0.18)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .shadow(color: Color.red.opacity(0.5), radius: 12, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 36)
                }

                Spacer()

                Text("PROTECTED BY APIMEOMEO • ANTI-CRACK ENGINE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - 3. MÀN HÌNH NHẬP TOKEN (CHỈ CÓ INPUT VÀ NÚT NHẬP TOKEN)

struct TokenEntryScreen: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @State private var inputToken: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo App
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 90, height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: Color.red.opacity(0.35), radius: 15, x: 0, y: 5)

                    AppLogo(size: 76)
                }

                Text("NHẬP TOKEN")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                // Khối Nhập Token Tinh Gọn
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
                        Image(systemName: "key.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))

                        TextField("Nhập Token...", text: $inputToken)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
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
                    .background(Color(uiColor: .secondarySystemBackground))
                    .border(AppTheme.cardBorder, width: 1)

                    // Nút Nhập Token
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
                                Text("NHẬP TOKEN")
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
                }
                .padding(18)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(Color.red.opacity(0.3), width: 1)

                Spacer()
            }
            .padding(.horizontal, 22)
        }
    }
}

// MARK: - 4. MÀN HÌNH CHÍNH CỦA ĐẠI LÝ (CHỌN GAME VÀ NẠP CHỨC NĂNG)

struct MainBrandScreen: View {
    @StateObject private var brandStore = BrandConfigStore.shared
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var patchEngine = FreeFirePatchEngine.shared
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl
    @State private var selectedGame: String? = nil // nil = Màn hình chọn game, "max" hoặc "th"
    @State private var inputKey: String = ""
    @State private var selectedCategory: String = "ALL"
    @State private var showCleanAlert: Bool = false

    let onOpenProfile: () -> Void
    let onOpenCheckLog: () -> Void

    private var activeBundleID: String {
        selectedGame == "max" ? "com.dts.freefiremax" : "com.dts.freefireth"
    }

    private var filteredPatches: [FFPatchItem] {
        patchEngine.patches.filter { patch in
            let matchCategory = (selectedCategory == "ALL") || (patch.category == selectedCategory)
            return matchCategory
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar Có Nút Avatar (Avt)
            headerBar

            // NẾU CHƯA NHẬP KEY VIP ➔ HIỆN FORM NHẬP KEY VIP
            if !keyEngine.isAuthenticated {
                keyLoginView
            }
            // NẾU ĐÃ NHẬP KEY NHƯNG CHƯA CHỌN GAME ➔ HIỆN MÀN HÌNH CHỌN GAME (FF MAX HAY FF THƯỜNG)
            else if selectedGame == nil {
                gameSelectorScreen
            }
            // NẾU ĐÃ CHỌN GAME ➔ HIỆN MENU CHỨC NĂNG CỦA GAME ĐÓ
            else {
                modMenuView
            }
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
            // Nút Avatar (Bấm vào xem Profile)
            Button(action: onOpenProfile) {
                ZStack {
                    Circle()
                        .fill(brandStore.welcomeColor.opacity(0.2))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle().stroke(brandStore.welcomeColor.opacity(0.6), lineWidth: 1.5)
                        )

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(brandStore.welcomeColor)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(brandStore.displayAppName.uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)

                    Text("TOKEN: \(brandStore.sellerToken)")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                }

                if keyEngine.isAuthenticated {
                    Text("Hạn: \(keyEngine.formattedRemainingTime)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                } else {
                    Text("Bấm Avt xem Profile ❯")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(brandStore.welcomeColor)
                }
            }

            Spacer()

            if selectedGame != nil {
                Button {
                    patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: activeBundleID)
                    AppToastManager.shared.show(type: .info, title: "LÀM MỚI", message: "Đang tải danh sách gói mới nhất...")
                    AppLogManager.shared.addLog(type: .info, message: "Làm mới danh sách patch từ máy chủ")
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .border(AppTheme.cardBorder, width: 1)
    }

    // MARK: - Key Login View (Khi chưa đăng nhập Key)
    private var keyLoginView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
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
                    Text(brandStore.displayWelcomeTitle)
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NHẬP MÃ KEY VIP CỦA BẠN:")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(brandStore.welcomeColor)

                            TextField("Nhập mã Key (VD: MEO-XXXX-XXXX)...", text: $inputKey)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                        }
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .border(AppTheme.cardBorder, width: 1)
                    }

                    if let err = keyEngine.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                            Text(err)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Nút Đăng Nhập Key
                    Button {
                        keyEngine.verifyKey(inputKey)
                    } label: {
                        HStack(spacing: 8) {
                            if keyEngine.isVerifying {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 14, weight: .black))
                                Text("XÁC NHẬN KEY VIP")
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

                    // Nút Lấy Key 12H (CHỈ HIỆN KHI TOKEN ĐƯỢC BẬT ON)
                    if brandStore.showGetKey {
                        Button {
                            if let url = URL(string: brandStore.getKeyURL.isEmpty ? "http://103.238.234.204:5000/getkey" : brandStore.getKeyURL) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12))
                                Text(brandStore.getKeyTitle.uppercased())
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.15))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                            .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.4), width: 1)
                        }
                        .buttonStyle(.plain)
                    }

                    // Nút Telegram
                    Button {
                        if let url = URL(string: brandStore.telegramURL) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12))
                            Text(brandStore.telegramTitle.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .foregroundStyle(Color(red: 0.20, green: 0.60, blue: 0.95))
                        .border(AppTheme.cardBorder, width: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .background(Color(uiColor: .secondarySystemBackground))
                .border(AppTheme.cardBorder, width: 1)

                Spacer(minLength: 30)

                Text("PROTECTED BY APIMEOMEO SECURITY ENGINE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
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
    }

    // MARK: - Game Selector Screen (Chọn Free Fire hay Free Fire MAX)
    private var gameSelectorScreen: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 6) {
                Text("CHỌN PHIÊN BẢN GAME")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("Vui lòng chọn bản Free Fire bạn đang chơi để nạp dữ liệu")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 16) {
                // Card Free Fire MAX
                GameArtworkCardView(
                    title: "FREE FIRE MAX",
                    subtitle: "Gói Mod Tối Ưu Cho Bản MAX (FFM)",
                    isMAX: true
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGame = "max"
                        patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: "com.dts.freefiremax")
                        AppToastManager.shared.show(type: .info, title: "FREE FIRE MAX", message: "Đã chọn phiên bản Free Fire MAX")
                        AppLogManager.shared.addLog(type: .info, message: "Chọn phiên bản game: Free Fire MAX (com.dts.freefiremax)")
                    }
                }

                // Card Free Fire Thường
                GameArtworkCardView(
                    title: "FREE FIRE THƯỜNG",
                    subtitle: "Gói Mod Tối Ưu Cho Bản Thường (FFT)",
                    isMAX: false
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGame = "th"
                        patchEngine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: "com.dts.freefireth")
                        AppToastManager.shared.show(type: .info, title: "FREE FIRE THƯỜNG", message: "Đã chọn phiên bản Free Fire Thường")
                        AppLogManager.shared.addLog(type: .info, message: "Chọn phiên bản game: Free Fire Thường (com.dts.freefireth)")
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("SELECT GAME TO LOAD MOD FUNCTION")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, 20)
        }
    }

    // MARK: - Mod Menu View (Khi đã chọn Game)
    private var modMenuView: some View {
        VStack(spacing: 0) {
            // Thanh Trạng Thái Game Đang Chọn & Nút Đổi Game
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    if let uiImg = UIImage(named: selectedGame == "max" ? "FFMaxIcon" : "FFNormalIcon") {
                        Image(uiImage: uiImg)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }

                    Text(selectedGame == "max" ? "FREE FIRE MAX" : "FREE FIRE THƯỜNG")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedGame = nil // Quay lại màn hình chọn game
                        AppLogManager.shared.addLog(type: .info, message: "Quay lại màn hình chọn phiên bản game")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                        Text("ĐỔI GAME")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.10))
                    .border(Color(red: 0.95, green: 0.75, blue: 0.10).opacity(0.4), width: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))

            // Bộ Lọc Mục
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

            // Danh Sách Chức Năng
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

            // Thanh Tiện Ích Dưới Cùng: NÚT MỞ GAME + CHECK LOG + DỌN SẠCH + TELEGRAM
            VStack(spacing: 6) {
                // HÀNG 1: NÚT MỞ GAME + NÚT CHECK LOG (XEM BÁO LỖI)
                HStack(spacing: 8) {
                    // NÚT MỞ GAME (OPEN GAME) NỔI BẬT
                    Button {
                        openSelectedGame()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .black))
                            Text("🚀 MỞ GAME")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            LinearGradient(
                                colors: selectedGame == "max"
                                    ? [Color(red: 0.95, green: 0.20, blue: 0.28), Color(red: 0.70, green: 0.08, blue: 0.18)]
                                    : [Color(red: 0.95, green: 0.55, blue: 0.10), Color(red: 0.80, green: 0.35, blue: 0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .shadow(color: (selectedGame == "max" ? Color.red : Color.orange).opacity(0.5), radius: 10, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)

                    // NÚT CHECK LOG
                    Button {
                        onOpenCheckLog()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("📋 CHECK LOG")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                        }
                        .frame(width: 125, height: 44)
                        .background(Color(red: 0.10, green: 0.14, blue: 0.22))
                        .foregroundStyle(Color(red: 0.38, green: 0.75, blue: 1.0))
                        .border(Color(red: 0.20, green: 0.50, blue: 0.85).opacity(0.5), width: 1)
                    }
                    .buttonStyle(.plain)
                }

                // Nút Dọn Sạch Game
                Button {
                    patchEngine.cleanAllPatches()
                    AppToastManager.shared.show(type: .warning, title: "ĐÃ TẮT TOÀN BỘ", message: "Game đã về trạng thái gốc an toàn 100%!")
                    AppLogManager.shared.addLog(type: .warning, message: "Đã làm sạch toàn bộ file mod, khôi phục game gốc 100%")
                    showCleanAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.shield.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("🧹 TẮT TOÀN BỘ CHỨC NĂNG (GAME GỐC)")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
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
                        AppToastManager.shared.show(type: .info, title: "ĐĂNG XUẤT", message: "Đã đăng xuất mã Key VIP!")
                        AppLogManager.shared.addLog(type: .info, message: "Người dùng đăng xuất Key VIP")
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                            Text("ĐĂNG XUẤT KEY")
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

    private func openSelectedGame() {
        let isMax = selectedGame == "max"
        let schemes = isMax ? ["freefiremax://", "com.dts.freefiremax://"] : ["freefire://", "freefireth://", "com.dts.freefireth://"]

        AppToastManager.shared.show(type: .info, title: "KHỞI CHẠY GAME", message: "Đang mở \(isMax ? "Free Fire MAX" : "Free Fire")...")
        AppLogManager.shared.addLog(type: .info, message: "Khởi chạy ứng dụng game: \(activeBundleID)")

        for s in schemes {
            if let url = URL(string: s), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback open
        if let fallback = URL(string: isMax ? "freefiremax://" : "freefire://") {
            UIApplication.shared.open(fallback)
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

    private func patchRow(patch: FFPatchItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(patch.isEnabled ? brandStore.welcomeColor.opacity(0.2) : Color.black.opacity(0.3))
                    .frame(width: 36, height: 36)
                    .border(patch.isEnabled ? brandStore.welcomeColor.opacity(0.5) : AppTheme.cardBorder, width: 1)

                Image(systemName: patch.category.contains("Aim") ? "bolt.fill" : (patch.category.contains("Định Vị") ? "eye.fill" : "gearshape.fill"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(patch.isEnabled ? brandStore.welcomeColor : Color.secondary)
            }

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

            Toggle("", isOn: Binding(
                get: { patch.isEnabled },
                set: { newVal in
                    patchEngine.togglePatch(id: patch.id, bundleID: activeBundleID, serverUrl: adminServerUrl)
                    let name = cleanPatchName(patch.name)
                    if newVal {
                        AppToastManager.shared.show(type: .success, title: "ĐÃ HOẠT ĐỘNG", message: "Đã nạp thành công [\(name)]!")
                        AppLogManager.shared.addLog(type: .success, message: "Kích hoạt nạp [\(name)] vào game \(activeBundleID)")
                    } else {
                        AppToastManager.shared.show(type: .warning, title: "ĐÃ TẮT", message: "Đã tắt chức năng [\(name)]!")
                        AppLogManager.shared.addLog(type: .warning, message: "Đã tắt chức năng [\(name)] và khôi phục gốc")
                    }
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
}

// MARK: - 5. THẺ ARTWORK HÌNH ẢNH CHỌN GAME (FF MAX / FF THƯỜNG - PNG THỰC TẾ)

struct GameArtworkCardView: View {
    let title: String
    let subtitle: String
    let isMAX: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: isMAX
                                ? [Color(red: 0.70, green: 0.08, blue: 0.18), Color(red: 0.20, green: 0.02, blue: 0.05), Color.black]
                                : [Color(red: 0.85, green: 0.40, blue: 0.05), Color(red: 0.25, green: 0.08, blue: 0.02), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isMAX ? Color.red.opacity(0.6) : Color.orange.opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: (isMAX ? Color.red : Color.orange).opacity(0.35), radius: 12, x: 0, y: 4)

                HStack(spacing: 14) {
                    // HÌNH ẢNH PNG THỰC TẾ 100% CỦA GAME
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 60, height: 60)

                        if let uiImg = UIImage(named: isMAX ? "FFMaxIcon" : "FFNormalIcon") {
                            Image(uiImage: uiImg)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                        } else {
                            AsyncImage(url: URL(string: isMAX
                                ? "https://play-lh.googleusercontent.com/SDYv1Th3VdjfM0MwObMIvH3L2I2owroB3leEtbMrFJZYRklHroxw_AspZZmno_8DBdiar3d03kHsyjBsnvcdlg=s300"
                                : "https://dl.memuplay.com/new_market/img/com.dts.freefireth.icon.2026-07-17-17-19-29.png")) { phase in
                                if let img = phase.image {
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 58, height: 58)
                                        .clipShape(RoundedRectangle(cornerRadius: 11))
                                } else {
                                    ProgressView().tint(.white)
                                }
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isMAX ? Color.red : Color.orange, lineWidth: 1.5)
                    )
                    .shadow(color: (isMAX ? Color.red : Color.orange).opacity(0.5), radius: 8, x: 0, y: 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)

                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("SẴN SÀNG NẠP CHỨC NĂNG")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.green)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(isMAX ? Color.red : Color.orange)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 6. CỬA SỔ PROFILE (HIỂN THỊ SUPPORT MÁY XANH/ĐỎ, SUPPORT IOS XANH/ĐỎ, HWID)

struct UserProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyEngine = KeyAuthEngine.shared
    @StateObject private var brandStore = BrandConfigStore.shared
    @State private var showCopiedHwid: Bool = false

    private var isDeviceSupported: Bool {
        return true
    }

    private var isIOSSupported: Bool {
        let v = AppInfo.versionTuple
        return ExploitSupportPolicy.isSupported(major: v.major, minor: v.minor, patch: v.patch, build: AppInfo.osBuild) || v.major >= 15
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Header Avatar Card
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

                            Text(brandStore.displayAppName)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(brandStore.welcomeColor)
                        }
                    }
                    .padding(.top, 10)

                    // CARD 1: SUPPORT MÁY & SUPPORT IOS (XANH / ĐỎ)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TƯƠNG THÍCH & HỖ TRỢ HỆ THỐNG")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Divider()

                        // Support Máy
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

                        // Support iOS
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

                    // CARD 2: MÃ HWID
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BẢO MẬT & MÃ HWID")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Divider()

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
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .border(AppTheme.cardBorder, width: 1)

                    // CARD 3: TOKEN ĐẠI LÝ & NÚT ĐỔI TOKEN
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TOKEN ĐẠI LÝ")
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

                        // Nút Đổi Token
                        Button {
                            brandStore.logoutToken()
                            dismiss()
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
        }
    }
}

// MARK: - 7. CỬA SỔ XEM LOG & BÁO LỖI HỆ THỐNG (TERMINAL LOGS)

struct CheckLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logManager = AppLogManager.shared
    @State private var isCopied: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Information
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NHẬT KÝ & BÁO LỖI HỆ THỐNG")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("Theo dõi trạng thái nạp file, hoạt động chức năng và lỗi game")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))

                // Terminal Log Console View
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            if logManager.logs.isEmpty {
                                Text("Chưa có nhật ký ghi nhận.")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(16)
                            } else {
                                ForEach(logManager.logs) { entry in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("[\(entry.time)]")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.secondary)

                                        Text(entry.type.prefix)
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(entry.type.color)

                                        Text(entry.message)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.white)
                                    }
                                    .id(entry.id)
                                }
                            }
                        }
                        .padding(14)
                    }
                    .background(Color(red: 0.04, green: 0.05, blue: 0.07))
                    .border(AppTheme.cardBorder, width: 1)
                    .padding(12)
                }

                // Bottom Actions
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = logManager.fullLogsText
                        isCopied = true
                        AppToastManager.shared.show(type: .info, title: "ĐÃ SAO CHÉP", message: "Đã copy toàn bộ nhật ký log vào bộ nhớ tạm!")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc.fill")
                            Text(isCopied ? "ĐÃ COPY LOG" : "COPY TOÀN BỘ LOG")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Color(red: 0.08, green: 0.55, blue: 0.85))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        logManager.clearLogs()
                        AppToastManager.shared.show(type: .warning, title: "ĐÃ XÓA LOG", message: "Đã làm sạch nhật ký console!")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("XÓA LOG")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                        }
                        .frame(width: 110, height: 40)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .foregroundStyle(.red)
                        .border(Color.red.opacity(0.4), width: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("CHECK LOG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
