import SwiftUI

struct PlayingCardView: View {
    var card: Card
    var faceUp: Bool = true
    var dimmed: Bool = false
    var highlighted: Bool = false
    var width: CGFloat = 58

    var body: some View {
        let height = width * 1.4
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(faceUp ? Color.white : Color.clear)
            if faceUp {
                VStack(spacing: 0) {
                    Text(card.rank.pip)
                        .font(.system(size: width * 0.32, weight: .bold))
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.28))
                }
                .foregroundStyle(card.suit.isRed ? Palette.cardRed : Palette.cardBlack)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.102, green: 0.290, blue: 0.612), Color(red: 0.047, green: 0.165, blue: 0.400)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("♠")
                    .font(.system(size: width * 0.42, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(highlighted ? Palette.hintYellow : Color.white.opacity(faceUp ? 0.2 : 0.55), lineWidth: highlighted ? 2.4 : 1)
        )
        .opacity(dimmed ? 0.38 : 1)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
    }
}

struct CardBackFan: View {
    var count: Int
    var vertical: Bool

    var body: some View {
        let shown = min(count, 8)
        ZStack {
            ForEach(0..<shown, id: \.self) { i in
                PlayingCardView(card: Card(suit: .spades, rank: .ace), faceUp: false, width: vertical ? 28 : 32)
                    .offset(x: vertical ? 0 : CGFloat(i - shown / 2) * 6, y: vertical ? CGFloat(i - shown / 2) * 5 : 0)
                    .rotationEffect(.degrees(vertical ? 90 : Double(i - shown / 2) * 4))
            }
        }
        .frame(width: vertical ? 40 : 90, height: vertical ? 90 : 50)
    }
}
