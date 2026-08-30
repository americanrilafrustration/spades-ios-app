import Foundation

enum NetMsg: Codable, Equatable {
    case hello(name: String)
    case welcome(seat: Seat, lobby: [LobbySeat])
    case lobby(
        seats: [LobbySeat],
        nilEnabled: Bool,
        bagPenaltyEnabled: Bool,
        targetScore: Int,
        partnership: Bool,
        hostPartnerSeat: Seat?,
        nsTeamName: String,
        ewTeamName: String
    )
    case assign(seat: Seat)
    case state(game: GameState)
    case bid(amount: Int)
    case play(suit: Suit, rank: Rank)
    case `continue`
    case error(message: String)

    var type: String {
        switch self {
        case .hello: return "hello"
        case .welcome: return "welcome"
        case .lobby: return "lobby"
        case .assign: return "assign"
        case .state: return "state"
        case .bid: return "bid"
        case .play: return "play"
        case .continue: return "continue"
        case .error: return "error"
        }
    }

    var card: Card? {
        if case let .play(suit, rank) = self { return Card(suit: suit, rank: rank) }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case type, name, seat, lobby, seats, nilEnabled, bagPenaltyEnabled
        case targetScore, partnership, hostPartnerSeat, nsTeamName, ewTeamName
        case game, amount, suit, rank, message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "hello":
            self = .hello(name: try c.decode(String.self, forKey: .name))
        case "welcome":
            self = .welcome(
                seat: try c.decode(Seat.self, forKey: .seat),
                lobby: try c.decode([LobbySeat].self, forKey: .lobby)
            )
        case "lobby":
            self = .lobby(
                seats: try c.decode([LobbySeat].self, forKey: .seats),
                nilEnabled: try c.decode(Bool.self, forKey: .nilEnabled),
                bagPenaltyEnabled: try c.decodeIfPresent(Bool.self, forKey: .bagPenaltyEnabled) ?? true,
                targetScore: try c.decodeIfPresent(Int.self, forKey: .targetScore) ?? 500,
                partnership: try c.decodeIfPresent(Bool.self, forKey: .partnership) ?? false,
                hostPartnerSeat: try c.decodeIfPresent(Seat.self, forKey: .hostPartnerSeat),
                nsTeamName: try c.decodeIfPresent(String.self, forKey: .nsTeamName) ?? "US",
                ewTeamName: try c.decodeIfPresent(String.self, forKey: .ewTeamName) ?? "THEM"
            )
        case "assign":
            self = .assign(seat: try c.decode(Seat.self, forKey: .seat))
        case "state":
            self = .state(game: try c.decode(GameState.self, forKey: .game))
        case "bid":
            self = .bid(amount: try c.decode(Int.self, forKey: .amount))
        case "play":
            self = .play(
                suit: try c.decode(Suit.self, forKey: .suit),
                rank: try c.decode(Rank.self, forKey: .rank)
            )
        case "continue":
            self = .continue
        case "error":
            self = .error(message: try c.decode(String.self, forKey: .message))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown type \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type, forKey: .type)
        switch self {
        case .hello(let name):
            try c.encode(name, forKey: .name)
        case .welcome(let seat, let lobby):
            try c.encode(seat, forKey: .seat)
            try c.encode(lobby, forKey: .lobby)
        case .lobby(let seats, let nilEnabled, let bagPenaltyEnabled, let targetScore, let partnership, let hostPartnerSeat, let nsTeamName, let ewTeamName):
            try c.encode(seats, forKey: .seats)
            try c.encode(nilEnabled, forKey: .nilEnabled)
            try c.encode(bagPenaltyEnabled, forKey: .bagPenaltyEnabled)
            try c.encode(targetScore, forKey: .targetScore)
            try c.encode(partnership, forKey: .partnership)
            try c.encodeIfPresent(hostPartnerSeat, forKey: .hostPartnerSeat)
            try c.encode(nsTeamName, forKey: .nsTeamName)
            try c.encode(ewTeamName, forKey: .ewTeamName)
        case .assign(let seat):
            try c.encode(seat, forKey: .seat)
        case .state(let game):
            try c.encode(game, forKey: .game)
        case .bid(let amount):
            try c.encode(amount, forKey: .amount)
        case .play(let suit, let rank):
            try c.encode(suit, forKey: .suit)
            try c.encode(rank, forKey: .rank)
        case .continue:
            break
        case .error(let message):
            try c.encode(message, forKey: .message)
        }
    }
}

enum LanEvent {
    case advertisingStarted
    case discoveryStarted
    case endpointFound(id: String, name: String)
    case endpointLost(id: String)
    case connected(id: String, name: String)
    case disconnected(id: String)
    case message(fromId: String, msg: NetMsg)
    case error(String)
}
