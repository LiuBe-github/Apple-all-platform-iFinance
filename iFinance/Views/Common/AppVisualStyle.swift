import SwiftUI

struct AppBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.10, blue: 0.14),
                        Color(red: 0.10, green: 0.09, blue: 0.14),
                        Color(red: 0.06, green: 0.11, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.97, blue: 1.0),
                        Color(red: 0.97, green: 0.95, blue: 0.99),
                        Color(red: 0.95, green: 0.99, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 36)
                .offset(x: -120, y: -300)

            Circle()
                .fill(Color.cyan.opacity(colorScheme == .dark ? 0.16 : 0.1))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 130, y: -210)

            Circle()
                .fill(Color.pink.opacity(colorScheme == .dark ? 0.14 : 0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 100, y: 360)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func appGlassCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.42), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
            }
    }
}
