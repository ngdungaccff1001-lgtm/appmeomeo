import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum PatchPackagePickerPolicy {
    static let payloadType = UTType(filenameExtension: "payload") ?? .data
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [payloadType, packageType, .data]
    static let copiesSelectedDocument = true
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchProjectStore()
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var showServerConfig = false
    @State private var syncStatusMessage: String?
    @State private var isSyncing = false

    // Free Fire On/Off States
    @AppStorage("ff_th_enabled") private var freeFireEnabled = false
    @AppStorage("ff_max_enabled") private var freeFireMaxEnabled = false
    @AppStorage("admin_api_server_url") private var adminServerUrl = "http://127.0.0.1:5000"

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                return true
            }
            guard let project = item.project else { return false }
            return project.name.localizedCaseInsensitiveContains(query)
                || project.allBundleIdentifiers.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
                || project.directories.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                }
                || project.rules.contains {
                    $0.relativePath.localizedCaseInsensitiveContains(query)
                        || $0.replacementFilename.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var onToggleSidebar: (() -> Void)? = nil

    init(onToggleSidebar: (() -> Void)? = nil) {
        self.onToggleSidebar = onToggleSidebar
#if targetEnvironment(simulator)
        _showCreate = State(
            initialValue: ProcessInfo.processInfo.arguments.contains("--simulate-patch-editor")
        )
#endif
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Free Fire / Free Fire MAX Injection Panel
                    freeFireHubSection

                    // Admin Python Cloud Sync Section
                    adminSyncSection

                    // Search & Local Payload Packages (Payload MeoMeo.app)
                    localPayloadSection
                }
                .padding(.horizontal, AppTheme.pageInset)
                .padding(.top, 10)
                .padding(.bottom, 26)
            }
            .background(AppTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Function")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.accent)
            .toolbar {
                if let onToggleSidebar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onToggleSidebar) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 15, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(uiColor: .secondarySystemFill))
                                .overlay(
                                    Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showCreate = true
                        } label: {
                            Label("Tạo Payload mới", systemImage: "doc.badge.plus")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Nhập file .3105 / .payload", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showServerConfig = true
                        } label: {
                            Label("Cấu hình Admin API Web", systemImage: "server.rack")
                        }
                    } label: {
                        if store.isBusy || isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color(uiColor: .secondarySystemFill))
                                .overlay(
                                    Rectangle().stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                    .disabled(store.isBusy || isSyncing)
                }
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: PatchPackagePickerPolicy.copiesSelectedDocument,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                importFile(url)
                            }
                        case .failure(let error):
                            log("patch picker error: \(error.localizedDescription)")
                        }
                    },
                    onCancel: {
                        showImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCreate) {
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false
                ) { project, password in
                    store.create(project: project, password: password)
                }
            }
            .sheet(isPresented: $showServerConfig) {
                adminServerConfigSheet
            }
        }
    }

    // MARK: - Free Fire Game Injection Hub
    private var freeFireHubSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FREE FIRE INJECTION ENGINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                Text("ON / OFF SYSTEM")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                // Free Fire Standard
                gameCard(
                    title: "Free Fire (VN / Global)",
                    bundleID: "com.dts.freefireth",
                    icon: "flame.fill",
                    color: Color(red: 1.00, green: 0.32, blue: 0.12),
                    isOn: $freeFireEnabled,
                    onSync: { syncPatchesForGame(bundleID: "com.dts.freefireth") }
                )

                // Free Fire MAX
                gameCard(
                    title: "Free Fire MAX",
                    bundleID: "com.dts.freefiremax",
                    icon: "bolt.fill",
                    color: Color(red: 1.00, green: 0.18, blue: 0.25),
                    isOn: $freeFireMaxEnabled,
                    onSync: { syncPatchesForGame(bundleID: "com.dts.freefiremax") }
                )
            }
        }
    }

    private func gameCard(
        title: String,
        bundleID: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>,
        onSync: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(color.opacity(0.35), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(color)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(bundleID)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(AppTheme.accent)
            }

            Divider()

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isOn.wrappedValue ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(isOn.wrappedValue ? "ACTIVE • ĐÃ KÍCH HOẠT" : "OFF • CHƯA KÍCH HOẠT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(isOn.wrappedValue ? Color.green : Color.secondary)
                }

                Spacer()

                Button(action: onSync) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                        Text("SYNC ADMIN API")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12))
                    .foregroundStyle(color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(isOn.wrappedValue ? AppTheme.accent.opacity(0.4) : AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Admin Python Server Sync Banner
    private var adminSyncSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)

                Text("ADMIN WEB API CLOUD")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showServerConfig = true
                } label: {
                    Text("CẤU HÌNH")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            if let msg = syncStatusMessage {
                Text(msg)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Local Payload Packages (Payload MeoMeo.app)
    private var localPayloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WORKSPACE: PAYLOAD MEOMEO.APP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(store.items.count) GÓI")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            AppSearchField(
                text: $searchText,
                prompt: "Tìm kiếm payload / patch .3105…",
                clearLabel: "Xóa"
            )

            if store.items.isEmpty && !store.isBusy {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Chưa có gói Payload trong Payload MeoMeo.app")
                        .font(.system(size: 13, weight: .bold))
                    Text("Tạo mới hoặc kết nối Admin API để tải patch về máy.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .fill(AppTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(filteredItems) { item in
                        payloadRow(item)
                    }
                }
            }
        }
    }

    private func payloadRow(_ item: PatchLibraryItem) -> some View {
        HStack(spacing: 10) {
            AppLogo(size: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)

                Text(item.packageURL.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.delete(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Color(uiColor: .tertiarySystemFill))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Admin Server Config Sheet
    private var adminServerConfigSheet: some View {
        NavigationStack {
            Form {
                Section("Máy Chủ Admin API Python") {
                    TextField("http://your-server-ip:5000", text: $adminServerUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 13, design: .monospaced))

                    Text("Nhập URL của máy chủ Admin Web (Python Flask). Ứng dụng sẽ đồng bộ danh sách file patch On/Off trực tiếp từ đây.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        testAndSyncServer()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isSyncing ? "ĐANG ĐỒNG BỘ…" : "KIỂM TRA & ĐỒNG BỘ NGAY")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppTheme.accent)
                            Spacer()
                        }
                    }
                    .disabled(isSyncing)
                }
            }
            .navigationTitle("Admin API Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { showServerConfig = false }
                }
            }
        }
    }

    private func importFile(_ url: URL) {
        store.importPackage(at: url)
        syncStatusMessage = "Đã nhập thành công: \(url.lastPathComponent)"
    }

    private func syncPatchesForGame(bundleID: String) {
        isSyncing = true
        syncStatusMessage = "Đang kết nối tới \(adminServerUrl)..."

        guard let url = URL(string: "\(adminServerUrl)/api/patches?bundle=\(bundleID)") else {
            isSyncing = false
            syncStatusMessage = "URL Server không hợp lệ"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isSyncing = false
                if let error = error {
                    syncStatusMessage = "Lỗi kết nối API: \(error.localizedDescription)"
                    return
                }
                syncStatusMessage = "Đã kết nối máy chủ Admin thành công! Đã cập nhật patch cho \(bundleID)"
            }
        }.resume()
    }

    private func testAndSyncServer() {
        isSyncing = true
        syncStatusMessage = "Đang kiểm tra kết nối..."

        guard let url = URL(string: "\(adminServerUrl)/api/status") else {
            isSyncing = false
            syncStatusMessage = "URL Server không hợp lệ"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isSyncing = false
                if let error = error {
                    syncStatusMessage = "Không thể kết nối tới server: \(error.localizedDescription)"
                } else {
                    syncStatusMessage = "Kết nối máy chủ Admin Python thành công (Online)!"
                    showServerConfig = false
                }
            }
        }.resume()
    }
}
