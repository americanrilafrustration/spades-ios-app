import Foundation

enum SpadesAi {
    static func chooseBid(hand: [Card], nilEnabled: Bool) -> Int {
        var estimate = 0.0
        let spades = hand.filter { $0.suit == .spades }
        for card in hand {
            switch card.rank {
            case .ace: estimate += 1.0
            case .king: estimate += 0.8
            case .queen: estimate += card.suit == .spades ? 0.55 : 0.35
            case .jack: estimate += card.suit == .spades ? 0.35 : 0.1
            default:
                if card.suit == .spades && card.rank.value >= 10 { estimate += 0.2 }
            }
        }
        if spades.count >= 4 {
            estimate += Double(spades.count - 3) * 0.45
        }
        let voids = [Suit.hearts, .diamonds, .clubs].filter { suit in
            !hand.contains { $0.suit == suit }
        }.count
        estimate += Double(voids) * 0.25

        let highSpade = spades.contains { $0.rank.value >= Rank.queen.value }
        let aces = hand.filter { $0.rank == .ace }.count
        let rounded = min(max(Int((estimate).rounded()), 0), 9)
        if rounded == 0 {
            if !nilEnabled { return 1 }
            return (!highSpade && aces == 0) ? 0 : 1
        }
        return rounded
    }

    static func chooseCard(state: GameState, seat: Seat) -> Card {
        let legal = SpadesEngine.legalCards(state, seat: seat)
        precondition(!legal.isEmpty, "No legal cards")
        let me = state.player(seat)
        let need = (me.bid ?? 0) - me.tricks
        let partner = seat.partner
        let avoidBags = state.bagPenaltyEnabled && need <= 0

        if state.trick.isEmpty {
            let nonSpades = legal.filter { $0.suit != .spades }
            let pool = nonSpades.isEmpty ? legal : nonSpades
            if avoidBags {
                return lowest(pool)
            }
            return highest(pool)
        }

        let lead = state.leadSuit!
        let partnerWinning = SpadesEngine.currentlyWinning(state.trick, lead: lead) == partner
        let winners = legal.filter { wouldWin(state: state, seat: seat, card: $0) }
        let losers = legal.filter { !winners.contains($0) }

        if avoidBags {
            if partnerWinning && state.trick.count == 3 {
                return lowest(legal)
            }
            return lowest(losers.isEmpty ? legal : losers)
        }

        if need > 0 {
            if !winners.isEmpty && !partnerWinning {
                return lowest(winners)
            }
            return lowest(legal)
        }

        if partnerWinning && state.trick.count == 3 {
            return lowest(legal)
        }
        if !winners.isEmpty && !partnerWinning {
            return lowest(winners)
        }
        return lowest(legal)
    }

    private static func wouldWin(state: GameState, seat: Seat, card: Card) -> Bool {
        let lead = state.leadSuit ?? card.suit
        let projected = state.trick + [TrickPlay(seat: seat, card: card)]
        return SpadesEngine.trickWinner(projected, lead: lead) == seat
    }

    private static func lowest(_ cards: [Card]) -> Card {
        cards.min { a, b in
            let asSpade = a.suit == .spades ? 1 : 0
            let bsSpade = b.suit == .spades ? 1 : 0
            if asSpade != bsSpade { return asSpade < bsSpade }
            return a.rank.value < b.rank.value
        }!
    }

    private static func highest(_ cards: [Card]) -> Card {
        cards.max { a, b in
            let asSpade = a.suit == .spades ? 1 : 0
            let bsSpade = b.suit == .spades ? 1 : 0
            if asSpade != bsSpade { return asSpade < bsSpade }
            return a.rank.value < b.rank.value
        }!
    }
}
