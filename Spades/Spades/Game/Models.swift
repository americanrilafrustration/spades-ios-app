import Foundation

enum Suit: String, Codable, CaseIterable {
    case spades = "SPADES"
    case hearts = "HEARTS"
    case diamonds = "DIAMONDS"
    case clubs = "CLUBS"

    var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    var isRed: Bool {
        self == .hearts || self == .diamonds
    }
}

enum Rank: String, Codable, CaseIterable {
    case two = "TWO"
    case three = "THREE"
    case four = "FOUR"
    case five = "FIVE"
    case six = "SIX"
    case seven = "SEVEN"
    case eight = "EIGHT"
    case nine = "NINE"
    case ten = "TEN"
    case jack = "JACK"
    case queen = "QUEEN"
    case king = "KING"
    case ace = "ACE"

    var pip: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }

    var value: Int {
        switch self {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 14
        }
    }
}

struct Card: Codable, Hashable, Equatable {
    var suit: Suit
    var rank: Rank
}

enum Seat: String, Codable, CaseIterable {
    case south = "SOUTH"
    case west = "WEST"
    case north = "NORTH"
    case east = "EAST"

    var defaultName: String {
        switch self {
        case .south: return "You"
        case .west: return "Cam"
        case .north: return "Reese"
        case .east: return "Quinn"
        }
    }

    var partner: Seat {
        switch self {
        case .south: return .north
        case .north: return .south
        case .west: return .east
        case .east: return .west
        }
    }

    var next: Seat {
        switch self {
        case .south: return .west
        case .west: return .north
        case .north: return .east
        case .east: return .south
        }
    }

    func nextActive(_ active: [Seat]) -> Seat {
        let set = Set(active)
        var seat = next
        for _ in 0..<4 {
            if set.contains(seat) { return seat }
            seat = seat.next
        }
        return self
    }
}

func tableOrder(_ active: [Seat]) -> [Seat] {
    [Seat.south, .west, .north, .east].filter { active.contains($0) }
}

func tableOrder(_ active: Set<Seat>) -> [Seat] {
    tableOrder(Array(active))
}

func initialDealer(_ active: [Seat]) -> Seat {
    tableOrder(active).last ?? .east
}

func tricksPerHandFor(_ playerCount: Int) -> Int {
    playerCount == 3 ? 17 : 13
}

enum Phase: String, Codable {
    case menu = "MENU"
    case rules = "RULES"
    case lobby = "LOBBY"
    case dealing = "DEALING"
    case bidding = "BIDDING"
    case playing = "PLAYING"
    case handOver = "HAND_OVER"
    case gameOver = "GAME_OVER"
}

struct TrickPlay: Codable, Equatable {
    var seat: Seat
    var card: Card
}

struct PlayerState: Codable, Equatable {
    var seat: Seat
    var name: String
    var isHuman: Bool
    var hand: [Card] = []
    var bid: Int? = nil
    var tricks: Int = 0
}

struct TeamScore: Codable, Equatable {
    var points: Int = 0
    var bags: Int = 0
}

enum NilResult: String, Codable {
    case made = "MADE"
    case failed = "FAILED"
}

struct PlayerHandLine: Codable, Equatable {
    var name: String
    var bid: Int
    var tricks: Int
    var nilResult: NilResult?
}

struct TeamHandSummary: Codable, Equatable {
    var names: String
    var contract: Int
    var tricks: Int
    var made: Bool
    var bidPoints: Int
    var bagsTaken: Int
    var bagPoints: Int
    var nilPoints: Int
    var bagPenalty: Bool
    var delta: Int
    var previousTotal: Int
    var total: Int
    var bags: Int

    static let blank = TeamHandSummary(
        names: "", contract: 0, tricks: 0, made: true, bidPoints: 0,
        bagsTaken: 0, bagPoints: 0, nilPoints: 0, bagPenalty: false,
        delta: 0, previousTotal: 0, total: 0, bags: 0
    )
}

struct PlayerHandSummary: Codable, Equatable, Identifiable {
    var seat: Seat
    var name: String
    var contract: Int
    var tricks: Int
    var made: Bool
    var bidPoints: Int
    var bagsTaken: Int
    var bagPoints: Int
    var nilPoints: Int
    var bagPenalty: Bool
    var delta: Int
    var previousTotal: Int
    var total: Int
    var bags: Int

    var id: Seat { seat }
}

struct HandResult: Codable, Equatable {
    var handNumber: Int
    var ns: TeamHandSummary
    var ew: TeamHandSummary
    var nsPlayers: [PlayerHandLine]
    var ewPlayers: [PlayerHandLine]
    var partnership: Bool = true
    var individuals: [PlayerHandSummary] = []
}

struct LobbySeat: Codable, Equatable, Identifiable {
    var seat: Seat
    var name: String
    var isHuman: Bool
    var isHost: Bool

    var id: Seat { seat }
}

struct DiscoveredTable: Codable, Equatable, Identifiable {
    var endpointId: String
    var hostName: String
    var id: String { endpointId }
}

struct GameState: Equatable {
    var phase: Phase = .menu
    var players: [Seat: PlayerState] = soloRoster()
    var dealer: Seat = .east
    var turn: Seat = .south
    var trick: [TrickPlay] = []
    var leadSuit: Suit? = nil
    var spadesBroken: Bool = false
    var announceSpadesBroken: Bool = false
    var trickWinner: Seat? = nil
    var completedTricks: Int = 0
    var ns: TeamScore = TeamScore()
    var ew: TeamScore = TeamScore()
    var playerScores: [Seat: TeamScore] = emptyPlayerScores()
    var lastHand: HandResult? = nil
    var scoreHistory: [HandResult] = []
    var targetScore: Int = 500
    var tricksPerHand: Int = 13
    var nsTeamName: String = "US"
    var ewTeamName: String = "THEM"
    var hostPartnerSeat: Seat? = nil
    var status: String = ""
    var dealQueue: [Card] = []
    var nextDealSeat: Seat = .south
    var nilEnabled: Bool = false
    var bagPenaltyEnabled: Bool = true
    var partnership: Bool = true
    var handNumber: Int = 0
    var lobbySeats: [LobbySeat] = []
    var discoveredTables: [DiscoveredTable] = []
    var playerName: String = ""
    var lobbyMessage: String = ""
    var notice: String = ""
    var localSeat: Seat = .south
    var isHost: Bool = true
    var isLan: Bool = false
    var rejoinHostName: String = ""
    var rejoinUntilMillis: Int64 = 0

    func player(_ seat: Seat) -> PlayerState {
        players[seat] ?? PlayerState(seat: seat, name: seat.defaultName, isHuman: false)
    }

    func hasSeat(_ seat: Seat) -> Bool {
        players[seat] != nil
    }

    func activeSeats() -> [Seat] {
        tableOrder(Array(players.keys))
    }

    func scoreOf(_ seat: Seat) -> TeamScore {
        if partnership {
            return (seat == .south || seat == .north) ? ns : ew
        }
        return playerScores[seat] ?? TeamScore()
    }
}

extension GameState: Codable {
    enum CodingKeys: String, CodingKey {
        case phase, players, dealer, turn, trick, leadSuit, spadesBroken
        case announceSpadesBroken, trickWinner, completedTricks, ns, ew
        case playerScores, lastHand, scoreHistory, targetScore, tricksPerHand
        case nsTeamName, ewTeamName, hostPartnerSeat, status, dealQueue
        case nextDealSeat, nilEnabled, bagPenaltyEnabled, partnership, handNumber
        case lobbySeats, discoveredTables, playerName, lobbyMessage, notice
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        phase = try c.decodeIfPresent(Phase.self, forKey: .phase) ?? .menu
        if let dict = try? c.decode([String: PlayerState].self, forKey: .players) {
            players = Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in
                Seat(rawValue: key).map { ($0, value) }
            })
        } else if let list = try? c.decode([PlayerState].self, forKey: .players) {
            players = Dictionary(uniqueKeysWithValues: list.map { ($0.seat, $0) })
        } else {
            players = soloRoster()
        }
        dealer = try c.decodeIfPresent(Seat.self, forKey: .dealer) ?? .east
        turn = try c.decodeIfPresent(Seat.self, forKey: .turn) ?? .south
        trick = try c.decodeIfPresent([TrickPlay].self, forKey: .trick) ?? []
        leadSuit = try c.decodeIfPresent(Suit.self, forKey: .leadSuit)
        spadesBroken = try c.decodeIfPresent(Bool.self, forKey: .spadesBroken) ?? false
        announceSpadesBroken = try c.decodeIfPresent(Bool.self, forKey: .announceSpadesBroken) ?? false
        trickWinner = try c.decodeIfPresent(Seat.self, forKey: .trickWinner)
        completedTricks = try c.decodeIfPresent(Int.self, forKey: .completedTricks) ?? 0
        ns = try c.decodeIfPresent(TeamScore.self, forKey: .ns) ?? TeamScore()
        ew = try c.decodeIfPresent(TeamScore.self, forKey: .ew) ?? TeamScore()
        if let dict = try? c.decode([String: TeamScore].self, forKey: .playerScores) {
            playerScores = Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in
                Seat(rawValue: key).map { ($0, value) }
            })
        } else if let pairs = try? c.decode([SeatScorePair].self, forKey: .playerScores), !pairs.isEmpty {
            playerScores = Dictionary(uniqueKeysWithValues: pairs.map { ($0.seat, $0.score) })
        } else {
            playerScores = emptyPlayerScores()
        }
        lastHand = try c.decodeIfPresent(HandResult.self, forKey: .lastHand)
        scoreHistory = try c.decodeIfPresent([HandResult].self, forKey: .scoreHistory) ?? []
        targetScore = try c.decodeIfPresent(Int.self, forKey: .targetScore) ?? 500
        tricksPerHand = try c.decodeIfPresent(Int.self, forKey: .tricksPerHand) ?? 13
        nsTeamName = try c.decodeIfPresent(String.self, forKey: .nsTeamName) ?? "US"
        ewTeamName = try c.decodeIfPresent(String.self, forKey: .ewTeamName) ?? "THEM"
        hostPartnerSeat = try c.decodeIfPresent(Seat.self, forKey: .hostPartnerSeat)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        dealQueue = try c.decodeIfPresent([Card].self, forKey: .dealQueue) ?? []
        nextDealSeat = try c.decodeIfPresent(Seat.self, forKey: .nextDealSeat) ?? .south
        nilEnabled = try c.decodeIfPresent(Bool.self, forKey: .nilEnabled) ?? false
        bagPenaltyEnabled = try c.decodeIfPresent(Bool.self, forKey: .bagPenaltyEnabled) ?? true
        partnership = try c.decodeIfPresent(Bool.self, forKey: .partnership) ?? true
        handNumber = try c.decodeIfPresent(Int.self, forKey: .handNumber) ?? 0
        lobbySeats = try c.decodeIfPresent([LobbySeat].self, forKey: .lobbySeats) ?? []
        discoveredTables = try c.decodeIfPresent([DiscoveredTable].self, forKey: .discoveredTables) ?? []
        playerName = try c.decodeIfPresent(String.self, forKey: .playerName) ?? ""
        lobbyMessage = try c.decodeIfPresent(String.self, forKey: .lobbyMessage) ?? ""
        notice = try c.decodeIfPresent(String.self, forKey: .notice) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(phase, forKey: .phase)
        try c.encode(Dictionary(uniqueKeysWithValues: players.map { ($0.key.rawValue, $0.value) }), forKey: .players)
        try c.encode(dealer, forKey: .dealer)
        try c.encode(turn, forKey: .turn)
        try c.encode(trick, forKey: .trick)
        try c.encode(leadSuit, forKey: .leadSuit)
        try c.encode(spadesBroken, forKey: .spadesBroken)
        try c.encode(announceSpadesBroken, forKey: .announceSpadesBroken)
        try c.encode(trickWinner, forKey: .trickWinner)
        try c.encode(completedTricks, forKey: .completedTricks)
        try c.encode(ns, forKey: .ns)
        try c.encode(ew, forKey: .ew)
        try c.encode(Dictionary(uniqueKeysWithValues: playerScores.map { ($0.key.rawValue, $0.value) }), forKey: .playerScores)
        try c.encode(lastHand, forKey: .lastHand)
        try c.encode(scoreHistory, forKey: .scoreHistory)
        try c.encode(targetScore, forKey: .targetScore)
        try c.encode(tricksPerHand, forKey: .tricksPerHand)
        try c.encode(nsTeamName, forKey: .nsTeamName)
        try c.encode(ewTeamName, forKey: .ewTeamName)
        try c.encode(hostPartnerSeat, forKey: .hostPartnerSeat)
        try c.encode(status, forKey: .status)
        try c.encode(dealQueue, forKey: .dealQueue)
        try c.encode(nextDealSeat, forKey: .nextDealSeat)
        try c.encode(nilEnabled, forKey: .nilEnabled)
        try c.encode(bagPenaltyEnabled, forKey: .bagPenaltyEnabled)
        try c.encode(partnership, forKey: .partnership)
        try c.encode(handNumber, forKey: .handNumber)
        try c.encode(lobbySeats, forKey: .lobbySeats)
        try c.encode(discoveredTables, forKey: .discoveredTables)
        try c.encode(playerName, forKey: .playerName)
        try c.encode(lobbyMessage, forKey: .lobbyMessage)
        try c.encode(notice, forKey: .notice)
    }
}

private struct SeatScorePair: Codable {
    var seat: Seat
    var score: TeamScore
}

func emptyPlayerScores() -> [Seat: TeamScore] {
    Dictionary(uniqueKeysWithValues: Seat.allCases.map { ($0, TeamScore()) })
}

func soloRoster() -> [Seat: PlayerState] {
    Dictionary(uniqueKeysWithValues: Seat.allCases.map { seat in
        (seat, PlayerState(
            seat: seat,
            name: seat == .south ? "You" : seat.defaultName,
            isHuman: seat == .south
        ))
    })
}

func rosterFromHumans(_ names: [Seat: String]) -> [Seat: PlayerState] {
    Dictionary(uniqueKeysWithValues: names.map { seat, name in
        (seat, PlayerState(seat: seat, name: name, isHuman: true))
    })
}

enum TableLayout {
    private static let order: [Seat] = [.south, .west, .north, .east]

    static func actualSeat(visual: Seat, local: Seat) -> Seat {
        let offset = order.firstIndex(of: local) ?? 0
        let index = order.firstIndex(of: visual) ?? 0
        return order[(index + offset) % 4]
    }

    static func visualSeat(actual: Seat, local: Seat) -> Seat {
        let offset = order.firstIndex(of: local) ?? 0
        let index = order.firstIndex(of: actual) ?? 0
        return order[(index - offset + 4) % 4]
    }
}
