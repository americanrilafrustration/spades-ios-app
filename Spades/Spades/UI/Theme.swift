import SwiftUI

enum Palette {
    static let cream = Color(red: 0.957, green: 0.937, blue: 0.886)
    static let gold = Color(red: 0.902, green: 0.773, blue: 0.416)
    static let lineGold = Color(red: 0.949, green: 0.831, blue: 0.361)
    static let navyDeep = Color(red: 0.027, green: 0.078, blue: 0.157)
    static let navyHeader = Color(red: 0.043, green: 0.102, blue: 0.220)
    static let navyFelt = Color(red: 0.110, green: 0.310, blue: 0.588)
    static let navyFeltDark = Color(red: 0.051, green: 0.165, blue: 0.369)
    static let teamBlue = Color(red: 0.184, green: 0.420, blue: 1.0)
    static let teamRed = Color(red: 0.898, green: 0.224, blue: 0.208)
    static let seatOrange = Color(red: 0.961, green: 0.486, blue: 0.0)
    static let seatCyan = Color(red: 0.0, green: 0.675, blue: 0.757)
    static let cardRed = Color(red: 0.827, green: 0.184, blue: 0.184)
    static let cardBlack = Color(red: 0.106, green: 0.106, blue: 0.106)
    static let cyanLine = Color(red: 0.478, green: 0.843, blue: 1.0)
    static let hintYellow = Color(red: 1.0, green: 0.757, blue: 0.027)
    static let sheetWhite = Color(red: 0.969, green: 0.980, blue: 1.0)
    static let cardBorder = Color(red: 0.831, green: 0.706, blue: 0.353)
    static let headerTop = Color(red: 0.298, green: 0.553, blue: 1.0)
    static let headerBottom = Color(red: 0.118, green: 0.337, blue: 0.910)
    static let continueTop = Color(red: 0.180, green: 0.878, blue: 0.773)
    static let continueBottom = Color(red: 0.055, green: 0.639, blue: 0.478)
}

func seatAccent(_ seat: Seat, partnership: Bool) -> Color {
    if partnership {
        return (seat == .south || seat == .north) ? Palette.teamBlue : Palette.teamRed
    }
    switch seat {
    case .south: return Palette.teamBlue
    case .west: return Palette.seatOrange
    case .north: return Palette.seatCyan
    case .east: return Palette.teamRed
    }
}

struct NavyBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Palette.navyFelt, Palette.navyFeltDark, Palette.navyDeep],
                center: .center,
                startRadius: 20,
                endRadius: 520
            )
            Text("♠")
                .font(.system(size: 280))
                .foregroundStyle(Color.white.opacity(0.06))
        }
        .ignoresSafeArea()
    }
}

struct EdgeBackSwipe: ViewModifier {
    var action: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.startLocation.x < 28 && value.translation.width > 80 && abs(value.translation.height) < 80 {
                        action()
                    }
                }
        )
    }
}

extension View {
    func onEdgeBack(_ action: @escaping () -> Void) -> some View {
        modifier(EdgeBackSwipe(action: action))
    }
}

struct GoldButtonStyle: ButtonStyle {
    var filled: Bool = true
    var height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(filled ? Palette.lineGold : Color.clear)
            .foregroundStyle(filled ? Palette.navyDeep : Palette.lineGold)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Palette.lineGold, lineWidth: filled ? 0 : 1.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SettingsToggleRow: View {
    var title: String
    var subtitle: String
    var isOn: Bool
    var enabled: Bool = true
    var onChange: (Bool) -> Void

    var body: some View {
        Button {
            if enabled { onChange(!isOn) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.lineGold)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.cream.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { if enabled { onChange($0) } }
                ))
                .labelsHidden()
                .tint(Palette.lineGold)
                .disabled(!enabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.navyFelt.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isOn ? Palette.lineGold : Color.white.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
