import SwiftUI

struct FreeFireDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = FreeFirePatchEngine.shared
    @State private var selectedCategory: FFModCategory = .aim
    @AppStorage("admin_api_server_url") private var adminServerUrl = FreeFirePatchEngine.defaultApiServerUrl

    let gameTitle: String
    let bundleID: String

    init(
        gameTitle: String = "Free Fire Max",
        bundleID: String = "com.dts.freefiremax"
    ) {
        self.gameTitle = gameTitle
        self.bundleID = bundleID
    }

    private var filteredPatches: [FFPatchItem] {
        engine.patches.filter { $0.category == selectedCategory.rawValue }
    }

    var body: some View {
        ZStack {
            // Cosmic Cyber Gradient Background
            cosmicBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Custom Navigation Bar
                customTopBar

                ScrollView {
                    VStack(spacing: 16) {
                        // Game Hero Banner
                        gameHeroBanner

                        // Category Filter Tabs
                        categoryTabs

                        // Menu Patch Card
                        menuPatchCard

                        // Target Path Info Card
                        targetPathsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
        }
    }

    // MARK: - Cosmic Cyber Background
    private var cosmicBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.09)

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.25, green: 0.08, blue: 0.50).opacity(0.4),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.20, blue: 0.55).opacity(0.35),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
        }
    }

    // MARK: - Custom Top Bar
    private var customTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }

            Spacer()

            Text(gameTitle)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
            } label: {
                if engine.isFetching {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 38, height: 38)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Game Hero Banner
    private var gameHeroBanner: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), Color.purple.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: Color.purple.opacity(0.35), radius: 15, x: 0, y: 5)

                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.7, blue: 0.2), Color(red: 1.0, green: 0.2, blue: 0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    Text(gameTitle.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 90, height: 90)

            VStack(spacing: 2) {
                Text(gameTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(bundleID)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.45, green: 0.65, blue: 0.95))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Category Filter Tabs
    private var categoryTabs: some View {
        HStack(spacing: 8) {
            ForEach(FFModCategory.allCases) { cat in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedCategory = cat
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(cat.rawValue)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(
                        selectedCategory == cat
                            ? Color(red: 0.15, green: 0.20, blue: 0.45).opacity(0.8)
                            : Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.7)
                    )
                    .foregroundStyle(selectedCategory == cat ? Color.white : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                selectedCategory == cat
                                    ? Color(red: 0.35, green: 0.55, blue: 0.95)
                                    : Color.white.opacity(0.12),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Menu Patch Card
    private var menuPatchCard: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(red: 0.20, green: 0.75, blue: 1.0))
                    .frame(width: 3.5, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 2))

                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.70, green: 0.35, blue: 1.0))

                Text("MENU PATCH")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    engine.autoApplyAll(category: selectedCategory, bundleID: bundleID, serverUrl: adminServerUrl)
                } label: {
                    Text("AUTO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 1.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.10, green: 0.25, blue: 0.40).opacity(0.6))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color(red: 0.20, green: 0.75, blue: 1.0), lineWidth: 1)
                        )
                }
                .disabled(filteredPatches.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.95))

            Divider()
                .background(Color.white.opacity(0.1))

            // Patch Items List
            if filteredPatches.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)

                    Text("Chưa có chức năng \(selectedCategory.rawValue)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Chỉ khi Admin tải file lên Web Admin (http://103.238.234.204:5000) thì mục này mới xuất hiện.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Button {
                        engine.fetchPatchesFromAdmin(serverUrl: adminServerUrl, bundleID: bundleID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("LÀM MỚI TỪ ADMIN API")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 1.0))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.15, green: 0.25, blue: 0.45).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredPatches) { patch in
                        patchRow(patch)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.18, green: 0.25, blue: 0.45), lineWidth: 1)
        )
    }

    // MARK: - Patch Row
    private func patchRow(_ patch: FFPatchItem) -> some View {
        HStack(spacing: 12) {
            // Category-based colored icon
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBackgroundColor(for: patch))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(iconBorderColor(for: patch), lineWidth: 1)
                    )

                Image(systemName: iconSystemName(for: patch))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconTintColor(for: patch))
            }
            .frame(width: 42, height: 42)

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(patch.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(patch.rulesCount) quy tắc thay thế • \(patch.targetPathDisplay)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Smooth On/Off Switch
            Toggle("", isOn: Binding(
                get: { patch.isEnabled },
                set: { _ in engine.togglePatch(id: patch.id, bundleID: bundleID, serverUrl: adminServerUrl) }
            ))
            .labelsHidden()
            .tint(Color(red: 0.20, green: 0.55, blue: 0.95))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(red: 0.09, green: 0.12, blue: 0.20).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    patch.isEnabled
                        ? Color(red: 0.20, green: 0.60, blue: 1.0).opacity(0.4)
                        : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Target Paths Card
    private var targetPathsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ĐƯỜNG DẪN DỮ LIỆU GAME (DATA PATHS)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.40, green: 0.70, blue: 1.0))

            VStack(alignment: .leading, spacing: 6) {
                pathRow(name: "Shaders Bundle", path: "Documents/contentcache/Optional/ios/gameassetbundles/shaders.HPt9DZviTSXL9hpGW9QNOMigNLA~3D")
                pathRow(name: "Cache Res Bundle", path: "Documents/contentcache/Compulsory/ios/gameassetbundles/cache_res.CfnFf59sr1SbsqQ6JqTKsEusjKs~3D")
            }

            if let status = engine.statusMessage {
                Text(status)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.green)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func pathRow(name: String, path: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
            Text(path)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func iconSystemName(for patch: FFPatchItem) -> String {
        switch patch.category {
        case FFModCategory.aim.rawValue: return "bolt.fill"
        case FFModCategory.esp.rawValue: return "eye.fill"
        default: return "gearshape.fill"
        }
    }

    private func iconBackgroundColor(for patch: FFPatchItem) -> Color {
        switch patch.category {
        case FFModCategory.aim.rawValue: return Color(red: 0.35, green: 0.15, blue: 0.10).opacity(0.6)
        case FFModCategory.esp.rawValue: return Color(red: 0.10, green: 0.25, blue: 0.35).opacity(0.6)
        default: return Color(red: 0.25, green: 0.10, blue: 0.35).opacity(0.6)
        }
    }

    private func iconBorderColor(for patch: FFPatchItem) -> Color {
        switch patch.category {
        case FFModCategory.aim.rawValue: return Color.orange.opacity(0.4)
        case FFModCategory.esp.rawValue: return Color.cyan.opacity(0.4)
        default: return Color.purple.opacity(0.4)
        }
    }

    private func iconTintColor(for patch: FFPatchItem) -> Color {
        switch patch.category {
        case FFModCategory.aim.rawValue: return Color.orange
        case FFModCategory.esp.rawValue: return Color.cyan
        default: return Color(red: 0.8, green: 0.5, blue: 1.0)
        }
    }
}
