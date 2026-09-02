import SwiftUI

enum LogoPalette {
    static let green = Color(red: 0.09, green: 0.36, blue: 0.22)
    static let gold = Color(red: 0.91, green: 0.82, blue: 0.56)
}

struct SpadeMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        var body = Path()
        body.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.93))
        body.addLine(to: CGPoint(x: x + w * 0.5, y: y + h * 0.56))
        body.addCurve(
            to: CGPoint(x: x + w * 0.1, y: y + h * 0.36),
            control1: CGPoint(x: x + w * 0.5, y: y + h * 0.56),
            control2: CGPoint(x: x + w * 0.1, y: y + h * 0.52)
        )
        body.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y + h * 0.06),
            control1: CGPoint(x: x + w * 0.1, y: y + h * 0.12),
            control2: CGPoint(x: x + w * 0.26, y: y + h * 0.06)
        )
        body.addCurve(
            to: CGPoint(x: x + w * 0.9, y: y + h * 0.36),
            control1: CGPoint(x: x + w * 0.74, y: y + h * 0.06),
            control2: CGPoint(x: x + w * 0.9, y: y + h * 0.12)
        )
        body.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y + h * 0.56),
            control1: CGPoint(x: x + w * 0.9, y: y + h * 0.52),
            control2: CGPoint(x: x + w * 0.5, y: y + h * 0.56)
        )
        body.closeSubpath()

        var base = Path()
        base.move(to: CGPoint(x: x + w * 0.26, y: y + h * 0.76))
        base.addLine(to: CGPoint(x: x + w * 0.74, y: y + h * 0.76))
        base.addLine(to: CGPoint(x: x + w * 0.64, y: y + h * 0.93))
        base.addLine(to: CGPoint(x: x + w * 0.36, y: y + h * 0.93))
        base.closeSubpath()

        body.addPath(base)
        return body
    }
}

struct AppLogo: View {
    var size: CGFloat = 96
    var cornerRadius: CGFloat? = nil

    private var radius: CGFloat { cornerRadius ?? size * 0.22 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LogoPalette.green)
            SpadeMark()
                .fill(LogoPalette.gold)
                .padding(size * 0.2)
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
