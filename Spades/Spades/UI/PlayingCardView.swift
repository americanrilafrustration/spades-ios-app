import SwiftUI

struct PlayingCardView: View {
    var card: Card
    var faceUp: Bool = true
    var dimmed: Bool = false
    var highlighted: Bool = false
    var highlightColor: Color = Palette.hintYellow
    var showCenterPip: Bool = false
    var width: CGFloat = 58

    private var height: CGFloat { width * 1.45 }
    private var cornerFontSize: CGFloat {
        card.rank == .ten ? width * 0.21 : width * 0.26
    }
    private var suitFontSize: CGFloat { width * 0.22 }
    private var cornerPadding: CGFloat { width * 0.1 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(faceUp ? Color.white : Color.clear)
            if faceUp {
                let color = card.suit.isRed ? Palette.cardRed : Palette.cardBlack
                cornerIndex(color: color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, cornerPadding)
                    .padding(.top, cornerPadding * 0.75)
                cornerIndex(color: color)
                    .rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, cornerPadding)
                    .padding(.bottom, cornerPadding * 0.75)
                if showCenterPip {
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.44))
                        .foregroundStyle(color)
                }
            } else {
                RoundedRectangle(cornerRadius: 5)
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
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(highlighted ? highlightColor : Palette.cardBorder.opacity(faceUp ? 0.55 : 0.35), lineWidth: highlighted ? 3 : 0.8)
        )
        .shadow(color: highlighted ? highlightColor.opacity(0.45) : .black.opacity(0.22), radius: highlighted ? 6 : 2, y: highlighted ? 0 : 1)
        .opacity(dimmed ? 0.38 : 1)
    }

    private func cornerIndex(color: Color) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(card.rank.pip)
                .font(.system(size: cornerFontSize, weight: .bold))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .fixedSize()
            Text(card.suit.symbol)
                .font(.system(size: suitFontSize))
                .fixedSize()
        }
        .foregroundStyle(color)
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
