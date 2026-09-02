import Foundation

enum SpadesEngine {
    private static let suitOrder: [Suit] = [.spades, .hearts, .clubs, .diamonds]

    static func newGame(
        nilEnabled: Bool = false,
        bagPenaltyEnabled: Bool = true,
        roster: [Seat: PlayerState] = soloRoster(),
        partnership: Bool = true,
        targetScore: Int = 500,
        nsTeamName: String = "US",
        ewTeamName: String = "THEM"
    ) -> GameState {
        let tricks = tricksPerHandFor(roster.count)
        var state = GameState()
        state.dealer = initialDealer(Array(roster.keys))
        state.ns = TeamScore()
        state.ew = TeamScore()
        state.playerScores = Dictionary(uniqueKeysWithValues: roster.keys.map { ($0, TeamScore()) })
        state.targetScore = min(max(targetScore, 50), 5_000)
        state.tricksPerHand = tricks
        state.nilEnabled = nilEnabled
        state.bagPenaltyEnabled = bagPenaltyEnabled
        state.partnership = partnership
        state.players = roster
        state.nsTeamName = nsTeamName.isEmpty ? "US" : nsTeamName
        state.ewTeamName = ewTeamName.isEmpty ? "THEM" : ewTeamName
        return startDeal(state)
    }

    static func startDeal(_ state: GameState) -> GameState {
        var next = state
        let active = next.activeSeats()
        let deck = buildDeck(playerCount: active.count, tricksPerHand: next.tricksPerHand)
        var emptyHands = next.players
        for (seat, player) in emptyHands {
            emptyHands[seat] = PlayerState(seat: player.seat, name: player.name, isHuman: player.isHuman)
        }
        let dealer = active.contains(next.dealer) ? next.dealer : initialDealer(active)
        let first = dealer.nextActive(active)
        next.phase = .dealing
        next.players = emptyHands
        next.dealer = dealer
        next.turn = first
        next.trick = []
        next.leadSuit = nil
        next.spadesBroken = false
        next.announceSpadesBroken = false
        next.trickWinner = nil
        next.completedTricks = 0
        next.lastHand = nil
        next.dealQueue = deck
        next.nextDealSeat = first
        next.status = "Shuffling the deck…"
        next.lobbySeats = []
        next.discoveredTables = []
        next.lobbyMessage = ""
        return next
    }

    static func dealNext(_ state: GameState) -> GameState {
        precondition(state.phase == .dealing)
        if state.dealQueue.isEmpty { return finishDeal(state) }
        var next = state
        let active = next.activeSeats()
        let card = next.dealQueue.removeFirst()
        let seat = active.contains(next.nextDealSeat) ? next.nextDealSeat : active[0]
        var player = next.player(seat)
        player.hand.append(card)
        next.players[seat] = player
        let total = next.tricksPerHand * active.count
        let dealt = total - next.dealQueue.count
        next.nextDealSeat = seat.nextActive(active)
        next.status = "Dealing… \(dealt) / \(total)"
        return next.dealQueue.isEmpty ? finishDeal(next) : next
    }

    static func finishDeal(_ state: GameState) -> GameState {
        var next = state
        for (seat, player) in next.players {
            var updated = player
            updated.hand = sortHand(player.hand)
            next.players[seat] = updated
        }
        let first = next.dealer.nextActive(next.activeSeats())
        next.phase = .bidding
        next.dealQueue = []
        next.turn = first
        next.status = "\(next.player(first).name) to bid"
        return next
    }

    static func placeBid(_ state: GameState, seat: Seat, bid: Int) -> GameState {
        precondition(state.phase == .bidding)
        precondition(state.turn == seat)
        precondition((0...state.tricksPerHand).contains(bid))
        var next = state
        var player = next.player(seat)
        player.bid = bid
        next.players[seat] = player
        let allBid = next.players.values.allSatisfy { $0.bid != nil }
        let active = next.activeSeats()
        if allBid {
            let leader = next.dealer.nextActive(active)
            next.phase = .playing
            next.turn = leader
            next.status = "\(next.player(leader).name) leads"
        } else {
            let following = seat.nextActive(active)
            next.turn = following
            next.status = "\(next.player(following).name) to bid"
        }
        return next
    }

    static func legalCards(_ state: GameState, seat: Seat) -> [Card] {
        let hand = state.player(seat).hand
        if state.phase != .playing || state.turn != seat || state.trickWinner != nil {
            return []
        }
        if state.trick.isEmpty {
            if !state.spadesBroken {
                let nonSpades = hand.filter { $0.suit != .spades }
                if !nonSpades.isEmpty { return nonSpades }
            }
            return hand
        }
        guard let lead = state.leadSuit else { return hand }
        let matching = hand.filter { $0.suit == lead }
        return matching.isEmpty ? hand : matching
    }

    static func playCard(_ state: GameState, seat: Seat, card: Card) -> GameState {
        let legal = legalCards(state, seat: seat)
        precondition(legal.contains(card), "Illegal play")
        var next = state
        var player = next.player(seat)
        if let index = player.hand.firstIndex(of: card) {
            player.hand.remove(at: index)
        }
        next.players[seat] = player

        let leadSuit = next.leadSuit ?? card.suit
        var spadesBroken = next.spadesBroken
        var announce = false
        if card.suit == .spades {
            let breaksNow = !next.spadesBroken && (next.trick.isEmpty || leadSuit != .spades)
            if breaksNow {
                spadesBroken = true
                announce = true
            } else if next.announceSpadesBroken {
                announce = true
            }
        } else if next.announceSpadesBroken {
            announce = true
        }

        next.trick.append(TrickPlay(seat: seat, card: card))
        next.leadSuit = leadSuit
        next.spadesBroken = spadesBroken
        next.announceSpadesBroken = announce
        let active = next.activeSeats()
        if next.trick.count < active.count {
            let following = seat.nextActive(active)
            next.turn = following
            next.status = "\(next.player(following).name)'s turn"
            return next
        }

        let winner = trickWinner(next.trick, lead: leadSuit)
        var winnerPlayer = next.player(winner)
        winnerPlayer.tricks += 1
        next.players[winner] = winnerPlayer
        next.trickWinner = winner
        next.completedTricks += 1
        next.turn = winner
        next.status = "\(next.player(winner).name) takes the trick"
        return next
    }

    static func collectTrick(_ state: GameState) -> GameState {
        guard let winner = state.trickWinner else { return state }
        if state.completedTricks >= state.tricksPerHand {
            return finishHand(state)
        }
        var next = state
        next.trick = []
        next.leadSuit = nil
        next.trickWinner = nil
        next.announceSpadesBroken = false
        next.status = "\(next.player(winner).name) leads"
        return next
    }

    static func nextHand(_ state: GameState) -> GameState {
        if state.phase == .gameOver { return state }
        var next = state
        next.dealer = state.dealer.nextActive(state.activeSeats())
        return startDeal(next)
    }

    static func trickWinner(_ trick: [TrickPlay], lead: Suit) -> Seat {
        var best = trick[0]
        for play in trick.dropFirst() {
            if beats(challenger: play.card, current: best.card, lead: lead) {
                best = play
            }
        }
        return best.seat
    }

    static func currentlyWinning(_ trick: [TrickPlay], lead: Suit?) -> Seat? {
        guard !trick.isEmpty, let lead else { return nil }
        return trickWinner(trick, lead: lead)
    }

    private static func beats(challenger: Card, current: Card, lead: Suit) -> Bool {
        if challenger.suit == .spades && current.suit != .spades { return true }
        if challenger.suit != .spades && current.suit == .spades { return false }
        if challenger.suit == current.suit { return challenger.rank.value > current.rank.value }
        return challenger.suit == lead && current.suit != lead
    }

    private static func finishHand(_ state: GameState) -> GameState {
        state.partnership ? finishPartnershipHand(state) : finishIndividualHand(state)
    }

    private static func finishPartnershipHand(_ state: GameState) -> GameState {
        let nsBreak = scoreContract(state, seats: [.south, .north])
        let ewBreak = scoreContract(state, seats: [.west, .east])
        let nsApplied = applyBags(state.ns, delta: nsBreak.points, newBags: nsBreak.bagsTaken, penaltyEnabled: state.bagPenaltyEnabled)
        let ewApplied = applyBags(state.ew, delta: ewBreak.points, newBags: ewBreak.bagsTaken, penaltyEnabled: state.bagPenaltyEnabled)
        let ns = nsApplied.0
        let ew = ewApplied.0
        let handNumber = state.handNumber + 1
        let result = HandResult(
            handNumber: handNumber,
            ns: teamSummary(
                names: "\(state.nsTeamName) · \(state.player(.south).name) & \(state.player(.north).name)",
                breakdown: nsBreak,
                bagPenalty: nsApplied.1,
                previous: state.ns,
                next: ns
            ),
            ew: teamSummary(
                names: "\(state.ewTeamName) · \(state.player(.west).name) & \(state.player(.east).name)",
                breakdown: ewBreak,
                bagPenalty: ewApplied.1,
                previous: state.ew,
                next: ew
            ),
            nsPlayers: [playerLine(state, .south), playerLine(state, .north)],
            ewPlayers: [playerLine(state, .west), playerLine(state, .east)],
            partnership: true
        )
        let over = ns.points >= state.targetScore || ew.points >= state.targetScore
        let winnerText: String
        if !over {
            winnerText = "Hand \(handNumber)"
        } else if ns.points > ew.points {
            winnerText = "\(state.nsTeamName) win"
        } else if ew.points > ns.points {
            winnerText = "\(state.ewTeamName) win"
        } else {
            winnerText = "Tie game"
        }
        var next = state
        next.phase = over ? .gameOver : .handOver
        next.ns = ns
        next.ew = ew
        next.playerScores[.south] = ns
        next.playerScores[.north] = ns
        next.playerScores[.west] = ew
        next.playerScores[.east] = ew
        next.lastHand = result
        next.scoreHistory.append(result)
        next.handNumber = handNumber
        next.trick = []
        next.trickWinner = nil
        next.status = winnerText
        return next
    }

    private static func finishIndividualHand(_ state: GameState) -> GameState {
        let handNumber = state.handNumber + 1
        var nextScores = state.playerScores
        let summaries = state.activeSeats().map { seat -> PlayerHandSummary in
            let breakdown = scoreContract(state, seats: [seat])
            let previous = state.playerScores[seat] ?? TeamScore()
            let applied = applyBags(previous, delta: breakdown.points, newBags: breakdown.bagsTaken, penaltyEnabled: state.bagPenaltyEnabled)
            nextScores[seat] = applied.0
            return PlayerHandSummary(
                seat: seat,
                name: state.player(seat).name,
                contract: breakdown.contract,
                tricks: breakdown.tricks,
                made: breakdown.made,
                bidPoints: breakdown.bidPoints,
                bagsTaken: breakdown.bagsTaken,
                bagPoints: breakdown.bagPoints,
                nilPoints: breakdown.nilPoints,
                bagPenalty: applied.1,
                delta: applied.0.points - previous.points,
                previousTotal: previous.points,
                total: applied.0.points,
                bags: applied.0.bags
            )
        }
        let result = HandResult(
            handNumber: handNumber,
            ns: .blank,
            ew: .blank,
            nsPlayers: state.activeSeats().filter { $0 == .south || $0 == .north }.map { playerLine(state, $0) },
            ewPlayers: state.activeSeats().filter { $0 == .west || $0 == .east }.map { playerLine(state, $0) },
            partnership: false,
            individuals: summaries
        )
        let totals = Dictionary(uniqueKeysWithValues: summaries.map { ($0.seat, $0.total) })
        let best = totals.values.max() ?? 0
        let over = totals.values.contains { $0 >= state.targetScore }
        let leaders = totals.filter { $0.value == best }.map(\.key)
        let winnerText: String
        if !over {
            winnerText = "Hand \(handNumber)"
        } else if leaders.count > 1 {
            winnerText = "Tie game"
        } else {
            winnerText = "\(state.player(leaders[0]).name) wins"
        }
        var next = state
        next.phase = over ? .gameOver : .handOver
        next.playerScores = nextScores
        next.lastHand = result
        next.scoreHistory.append(result)
        next.handNumber = handNumber
        next.trick = []
        next.trickWinner = nil
        next.status = winnerText
        return next
    }

    private static func teamSummary(
        names: String,
        breakdown: ScoreBreakdown,
        bagPenalty: Bool,
        previous: TeamScore,
        next: TeamScore
    ) -> TeamHandSummary {
        TeamHandSummary(
            names: names,
            contract: breakdown.contract,
            tricks: breakdown.tricks,
            made: breakdown.made,
            bidPoints: breakdown.bidPoints,
            bagsTaken: breakdown.bagsTaken,
            bagPoints: breakdown.bagPoints,
            nilPoints: breakdown.nilPoints,
            bagPenalty: bagPenalty,
            delta: next.points - previous.points,
            previousTotal: previous.points,
            total: next.points,
            bags: next.bags
        )
    }

    private static func playerLine(_ state: GameState, _ seat: Seat) -> PlayerHandLine {
        let player = state.player(seat)
        let bid = player.bid ?? 0
        let nilResult: NilResult?
        if !state.nilEnabled || bid != 0 {
            nilResult = nil
        } else {
            nilResult = player.tricks == 0 ? .made : .failed
        }
        return PlayerHandLine(name: player.name, bid: bid, tricks: player.tricks, nilResult: nilResult)
    }

    private struct ScoreBreakdown {
        var contract: Int
        var tricks: Int
        var made: Bool
        var bidPoints: Int
        var bagsTaken: Int
        var bagPoints: Int
        var nilPoints: Int
        var points: Int
    }

    private static func scoreContract(_ state: GameState, seats: [Seat]) -> ScoreBreakdown {
        let players = seats.map { state.player($0) }
        let contract = players.reduce(0) { $0 + ($1.bid ?? 0) }
        let tricks = players.reduce(0) { $0 + $1.tricks }
        let made = contract == 0 ? tricks == 0 : tricks >= contract
        let bidPoints = made ? contract * 10 : -contract * 10
        let bagsTaken = made ? tricks - contract : 0
        var nilPoints = 0
        for player in players where state.nilEnabled && player.bid == 0 {
            nilPoints += player.tricks == 0 ? 100 : -100
        }
        return ScoreBreakdown(
            contract: contract,
            tricks: tricks,
            made: made,
            bidPoints: bidPoints,
            bagsTaken: bagsTaken,
            bagPoints: bagsTaken,
            nilPoints: nilPoints,
            points: bidPoints + bagsTaken + nilPoints
        )
    }

    private static func applyBags(
        _ current: TeamScore,
        delta: Int,
        newBags: Int,
        penaltyEnabled: Bool
    ) -> (TeamScore, Bool) {
        var points = current.points + delta
        var bags = current.bags + newBags
        var penalty = false
        if penaltyEnabled {
            while bags >= 10 {
                bags -= 10
                points -= 100
                penalty = true
            }
        }
        return (TeamScore(points: points, bags: bags), penalty)
    }

    private static func sortHand(_ cards: [Card]) -> [Card] {
        cards.sorted {
            let left = suitOrder.firstIndex(of: $0.suit) ?? 0
            let right = suitOrder.firstIndex(of: $1.suit) ?? 0
            if left != right { return left < right }
            return $0.rank.value > $1.rank.value
        }
    }

    private static func buildDeck(playerCount: Int, tricksPerHand: Int) -> [Card] {
        var deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit: suit, rank: $0) } }
        if playerCount == 3 {
            deck.removeAll { $0.suit == .clubs && $0.rank == .two }
        }
        deck.shuffle()
        let needed = playerCount * tricksPerHand
        return deck.count > needed ? Array(deck.prefix(needed)) : deck
    }
}
