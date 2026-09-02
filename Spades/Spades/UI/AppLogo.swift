import SwiftUI

enum LogoPalette {
    static let green = Color(red: 0.09, green: 0.36, blue: 0.22)
    static let gold = Color(red: 0.91, green: 0.82, blue: 0.56)
}

struct AppLogo: View {
    var size: CGFloat = 96
    var cornerRadius: CGFloat? = nil

    private var radius: CGFloat { cornerRadius ?? size * 0.22 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LogoPalette.green)
            Image(systemName: "suit.spade.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(LogoPalette.gold)
                .padding(size * 0.19)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: size * 0.08, y: size * 0.04)
    }
}

#Preview {
    ZStack {
        Palette.navyDeep.ignoresSafeArea()
        VStack(spacing: 24) {
            AppLogo(size: 120)
            AppLogo(size: 64, cornerRadius: 14)
        }
    }
}
