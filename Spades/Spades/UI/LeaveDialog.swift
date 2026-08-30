import SwiftUI

struct LeaveTableDialog: View {
    var isHost: Bool
    var inGame: Bool
    var isLan: Bool = true
    var onStay: () -> Void
    var onLeave: () -> Void

    private var title: String {
        if !isLan { return "End this game?" }
        return isHost ? "End this table?" : "Leave this table?"
    }

    private var bodyText: String {
        if !isLan { return "This game will end and you will return to the home screen." }
        if isHost && inGame { return "If you leave, the table ends for everyone and they return to the menu." }
        if isHost { return "If you leave, friends at this table will be disconnected." }
        if inGame { return "If you leave, the others keep playing and an AI takes your seat." }
        return "You will disconnect from the host."
    }

    private var leaveLabel: String {
        if !isLan { return "END GAME" }
        return isHost ? "END TABLE" : "LEAVE"
    }

    var body: some View {
        ZStack {
            Color(red: 0.027, green: 0.078, blue: 0.157).opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture(perform: onStay)
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color(red: 0.118, green: 0.310, blue: 0.847))
                    .multilineTextAlignment(.center)
                Text(bodyText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.290, green: 0.333, blue: 0.408))
                    .multilineTextAlignment(.center)
                Button(action: onLeave) {
                    Text(leaveLabel)
                        .font(.system(size: 15, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.882, green: 0.294, blue: 0.294), Color(red: 0.718, green: 0.110, blue: 0.110)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
                Button("STAY", action: onStay)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.118, green: 0.337, blue: 0.910))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(Capsule().stroke(Color(red: 0.118, green: 0.337, blue: 0.910), lineWidth: 1.4))
            }
            .padding(20)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.cardBorder, lineWidth: 1.6))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 36)
        }
    }
}
