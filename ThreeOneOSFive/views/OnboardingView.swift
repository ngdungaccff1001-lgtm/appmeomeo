import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 20)

                // App Logo with Cyber Glow
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color(red: 0.8, green: 0.1, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.red.opacity(0.4), radius: 16, x: 0, y: 6)

                    AppLogo(size: 64)
                }
                .frame(width: 88, height: 88)

                // Welcome Header
                VStack(spacing: 6) {
                    Text("Chào Mừng Đến APIMeoMeo")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Hệ Thống Mod & Patch Tối Ưu Hóa Free Fire Chuyên Nghiệp")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 10)

                // Feature Highlights
                VStack(spacing: 12) {
                    featureRow(
                        icon: "flame.fill",
                        color: Color.orange,
                        title: "Free Fire (FFT) & Free Fire MAX (FFM)",
                        subtitle: "Tối ưu hóa dữ liệu game độc quyền"
                    )

                    featureRow(
                        icon: "bolt.horizontal.fill",
                        color: Color.red,
                        title: "Đồng Bộ API Thời Gian Thực",
                        subtitle: "Tự động tải và áp dụng các gói patch mới nhất"
                    )

                    featureRow(
                        icon: "checkmark.shield.fill",
                        color: Color.green,
                        title: "Hỗ Trợ iOS 15 - 27",
                        subtitle: "Hoạt động trực tiếp không cần Jailbreak"
                    )
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)

                // Start Button
                Button(action: onComplete) {
                    HStack(spacing: 8) {
                        Text("BẮT ĐẦU NGAY")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(color.opacity(0.35), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
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

// MARK: - Onboarding Store (Completion Persistence)

enum OnboardingStore {
    private static let key = "meomeopath.onboarding.completed"

    static func shouldShow() -> Bool {
        !UserDefaults.standard.bool(forKey: key)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: key)
    }
}
