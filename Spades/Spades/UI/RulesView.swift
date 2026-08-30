import SwiftUI

struct RulesView: View {
    var onBack: () -> Void

    var body: some View {
        ZStack {
            NavyBackground()
            VStack(alignment: .leading, spacing: 0) {
                Text("♠")
                    .font(.system(size: 36))
                    .foregroundStyle(Palette.lineGold)
                Text("HOW TO PLAY")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.lineGold)
                    .tracking(1.4)
                    .padding(.bottom, 16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        rule("Partnerships", "Vs AI you can play as a team or as an individual. Team: you sit South, Reese is your partner (North), Cam is West and Quinn is East. Individual: every player keeps their own score.")
                        rule("Bidding", "Each player bids the number of tricks they expect to take. In team play, your contract is the sum of both bids. In individual play, you only score your own bid.")
                        rule("Play", "Follow suit if you can. Spades are trump. You cannot lead spades until they are broken, unless you only have spades.")
                        rule("Scoring", "Make your bid: 10 points per bid trick, plus 1 bag per extra trick. Miss the bid: minus 10 per bid trick.")
                        rule("Nil", "Optional. Turn Nil on from the menu before you start. Then you can bid Nil: +100 if you take zero tricks, −100 if you take any. If Nil is off, those ±100 points are not used.")
                        rule("Bags", "Extra tricks are +1 each. Optional 10-bag penalty: every 10 bags costs 100 points. Turn that off from Settings (gear) or the friends lobby if you do not want the −100.")
                        rule("Win", "Vs AI, first to 500 at the end of a hand wins. With friends, the host picks the winning score before the deal.")
                        rule("Friends", "On the same Wi‑Fi, iPhone and Android can sit at one table. One person hosts and the others join. 2 or 3 players play individually with no AI at the start. 4 players can play individually or as teams — the host picks partners and team names. Only the host can end the table. If a player leaves mid-game, the others are notified and an AI takes that seat. That player can rejoin the same table within 5 minutes.")
                    }
                }
                Button("Back", action: onBack)
                    .buttonStyle(GoldButtonStyle(height: 56))
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .onEdgeBack(onBack)
    }

    private func rule(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.lineGold)
                .padding(.top, 12)
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(Palette.cream.opacity(0.88))
                .lineSpacing(4)
                .padding(.bottom, 8)
        }
    }
}
