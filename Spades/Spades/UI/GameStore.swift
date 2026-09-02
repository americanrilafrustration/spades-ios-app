import Foundation

@MainActor
final class GameStore: ObservableObject {
    @Published var state = GameState()
    @Published var settings = AppSettings.load()

    private enum Role { case none, host, guest }
    private struct RejoinSlot { var seat: Seat; var name: String; var leftAt: Int64 }

    private var role: Role = .none
    private var session: LanSession?
    private var hostEndpointId: String?
    private var connectedHostName: String = ""
    private var endpointSeats: [String: Seat] = [:]
    private var endpointNames: [String: String] = [:]
    private var rejoinSeats: [String: RejoinSlot] = [:]
    private var autoRejoinAttempted = false

    private var aiTask: Task<Void, Never>?
    private var collectTask: Task<Void, Never>?
    private var dealTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var rejoinWatch: Task<Void, Never>?
    private var continueAcks: Set<String> = []
    private var pendingDisconnects: [String: Task<Void, Never>] = [:]

    private var lastPhase: Phase = .menu
    private var lastHand = -1
    private var lastSpades = false
    private var lastTrick = 0
    private var wasYourTurn = false

    private static let guestSeats: [Seat] = [.west, .north, .east]
    private static let inGamePhases: Set<Phase> = [.dealing, .bidding, .playing, .handOver, .gameOver]
    private static let rejoinWindowMs: Int64 = 5 * 60 * 1000

    init() {
        let loaded = AppSettings.load()
        settings = loaded
        state.nilEnabled = loaded.nilEnabled
        state.bagPenaltyEnabled = loaded.bagPenaltyEnabled
    }

    func setMusic(_ enabled: Bool) {
        var next = settings
        next.music = enabled
        saveSettings(next)
    }

    func setSfx(_ enabled: Bool) {
        var next = settings
        next.sfx = enabled
        saveSettings(next)
    }

    func setVibration(_ enabled: Bool) {
        var next = settings
        next.vibration = enabled
        saveSettings(next)
    }

    private func saveSettings(_ next: AppSettings) {
        settings = next
        next.persist()
    }

    func showRules() {
        state.phase = .rules
    }

    func setPlayerName(_ name: String) {
        state.playerName = String(name.prefix(18))
    }

    private func currentName() -> String {
        let trimmed = state.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Player" : trimmed
    }

    func openLobby() {
        cancelJobs()
        let current = state
        let kept = preservedRejoin(current)
        var next = GameState()
        next.phase = .lobby
        next.nilEnabled = settings.nilEnabled
        next.bagPenaltyEnabled = settings.bagPenaltyEnabled
        next.partnership = false
        next.playerName = current.playerName
        next.targetScore = 500
        next.nsTeamName = "US"
        next.ewTeamName = "THEM"
        next.lobbyMessage = kept.0.isEmpty
            ? "Host a table or find one on this Wi‑Fi."
            : "Rejoin \(kept.0) within 5 minutes, or host a new table."
        next.isLan = true
        next.isHost = false
        next.rejoinHostName = kept.0
        next.rejoinUntilMillis = kept.1
        state = next
    }

    func rejoinLastTable() {
        openLobby()
        findTables()
    }

    func backToMenu() {
        let current = state
        let leavingGame = current.isLan && !current.isHost && Self.inGamePhases.contains(current.phase)
        let hostName: String
        let until: Int64
        if leavingGame {
            hostName = current.players[.south]?.name ?? ""
            until = nowMs() + Self.rejoinWindowMs
        } else {
            let kept = preservedRejoin(current)
            hostName = kept.0
            until = kept.1
        }
        teardownLan()
        cancelJobs()
        var next = GameState()
        next.nilEnabled = settings.nilEnabled
        next.bagPenaltyEnabled = settings.bagPenaltyEnabled
        next.partnership = current.partnership
        next.playerName = current.playerName
        next.rejoinHostName = hostName
        next.rejoinUntilMillis = until
        state = next
    }

    func setPartnership(_ enabled: Bool) {
        guard state.phase == .menu else { return }
        state.partnership = enabled
    }

    func setLanPartnership(_ enabled: Bool) {
        guard state.phase == .lobby, state.isHost else { return }
        let humans = state.lobbySeats.filter(\.isHuman).count
        if enabled && humans < 4 { return }
        state.partnership = enabled
        state.hostPartnerSeat = enabled ? (state.hostPartnerSeat ?? firstGuestSeat()) : nil
        publishLobby()
    }

    func setTargetScore(_ score: Int) {
        guard state.phase == .lobby, state.isHost else { return }
        state.targetScore = min(max(score, 50), 5_000)
        publishLobby()
    }

    func setHostPartner(_ seat: Seat) {
        guard state.phase == .lobby, state.isHost else { return }
        guard endpointSeats.values.contains(seat) else { return }
        state.partnership = true
        state.hostPartnerSeat = seat
        publishLobby()
    }

    func setNsTeamName(_ name: String) {
        guard state.phase == .lobby, state.isHost else { return }
        state.nsTeamName = String(name.prefix(16))
        publishLobby()
    }

    func setEwTeamName(_ name: String) {
        guard state.phase == .lobby, state.isHost else { return }
        state.ewTeamName = String(name.prefix(16))
        publishLobby()
    }

    func setNilEnabled(_ enabled: Bool) {
        guard state.phase == .menu || state.phase == .lobby else { return }
        state.nilEnabled = enabled
        var next = settings
        next.nilEnabled = enabled
        saveSettings(next)
        if role == .host {
            state.lobbySeats = lobbySnapshot(currentName())
            publishLobby()
        }
    }

    func setBagPenaltyEnabled(_ enabled: Bool) {
        guard state.phase == .menu || state.phase == .lobby else { return }
        if state.phase == .lobby && !state.isHost && role != .host { return }
        state.bagPenaltyEnabled = enabled
        var next = settings
        next.bagPenaltyEnabled = enabled
        saveSettings(next)
        if role == .host {
            state.lobbySeats = lobbySnapshot(currentName())
            publishLobby()
        }
    }

    func startGame() {
        teardownLan()
        cancelJobs()
        let current = state
        var next = SpadesEngine.newGame(
            nilEnabled: current.nilEnabled,
            bagPenaltyEnabled: current.bagPenaltyEnabled,
            partnership: current.partnership
        )
        next.playerName = current.playerName
        state = next
        runDeal()
    }

    func hostTable() {
        session?.shutdown()
        session = nil
        role = .host
        endpointSeats.removeAll()
        endpointNames.removeAll()
        rejoinSeats.removeAll()
        hostEndpointId = nil
        ensureSession()
        state.phase = .lobby
        state.isLan = true
        state.isHost = true
        state.localSeat = .south
        state.lobbySeats = lobbySnapshot(currentName())
        state.lobbyMessage = "Waiting for friends on this Wi‑Fi…"
        state.discoveredTables = []
        state.rejoinHostName = ""
        state.rejoinUntilMillis = 0
        session?.startHosting(currentName())
    }

    func findTables() {
        session?.shutdown()
        session = nil
        let kept = preservedRejoin(state)
        role = .guest
        endpointSeats.removeAll()
        endpointNames.removeAll()
        hostEndpointId = nil
        autoRejoinAttempted = false
        ensureSession()
        state.phase = .lobby
        state.isLan = true
        state.isHost = false
        state.lobbyMessage = kept.0.isEmpty ? "Looking for tables nearby…" : "Looking for \(kept.0)'s table to rejoin…"
        state.discoveredTables = []
        state.lobbySeats = []
        state.rejoinHostName = kept.0
        state.rejoinUntilMillis = kept.1
        session?.startDiscovery()
    }

    func joinTable(_ endpointId: String) {
        session?.join(endpointId, name: currentName())
        state.lobbyMessage = "Joining table…"
    }

    func startLanGame() {
        guard role == .host else { return }
        if endpointSeats.isEmpty {
            startGame()
            return
        }
        let humanCount = endpointSeats.count + 1
        guard (2...4).contains(humanCount) else { return }
        cancelJobs()
        let partnership = humanCount == 4 && state.partnership
        let seated = lanSeating(hostName: currentName(), partnership: partnership, partnerSeat: state.hostPartnerSeat)
        endpointSeats = seated.1
        for (id, seat) in seated.1 {
            session?.send(id, .assign(seat: seat))
        }
        var started = SpadesEngine.newGame(
            nilEnabled: state.nilEnabled,
            bagPenaltyEnabled: state.bagPenaltyEnabled,
            roster: rosterFromHumans(seated.0),
            partnership: partnership,
            targetScore: state.targetScore,
            nsTeamName: state.nsTeamName,
            ewTeamName: state.ewTeamName
        )
        started.playerName = state.playerName
        started.isLan = true
        started.isHost = true
        started.localSeat = .south
        started.hostPartnerSeat = partnership ? .north : nil
        state = started
        session?.broadcast(.state(game: stateForBroadcast(started)))
        runDeal()
    }

    func bid(_ amount: Int) {
        let current = state
        let local = current.localSeat
        guard current.phase == .bidding, current.turn == local else { return }
        if current.isLan && !current.isHost {
            if let host = hostEndpointId {
                session?.send(host, .bid(amount: amount))
            }
            return
        }
        applyHost { SpadesEngine.placeBid($0, seat: local, bid: amount) }
        scheduleAi()
    }

    func play(_ card: Card) {
        let current = state
        let local = current.localSeat
        guard current.phase == .playing, current.turn == local else { return }
        guard SpadesEngine.legalCards(current, seat: local).contains(card) else { return }
        if current.isLan && !current.isHost {
            if let host = hostEndpointId {
                session?.send(host, .play(suit: card.suit, rank: card.rank))
            }
            return
        }
        applyPlay(current, card: card)
    }

    func continueNextHand() {
        guard state.phase == .handOver else { return }
        if state.isLan && !state.isHost {
            if let host = hostEndpointId {
                session?.send(host, .continue)
            }
            return
        }
        if state.isLan && state.isHost {
            continueAcks.insert("host")
            tryAdvanceAfterContinue()
            return
        }
        startNextHandAfterContinue()
    }

    private func onRemoteContinue(_ fromId: String) {
        guard state.phase == .handOver else { return }
        guard endpointSeats[fromId] != nil else { return }
        continueAcks.insert(fromId)
        tryAdvanceAfterContinue()
    }

    private func requiredContinueIds() -> Set<String> {
        var ids = Set(endpointSeats.keys)
        ids.insert("host")
        return ids
    }

    private func allPlayersContinued() -> Bool {
        requiredContinueIds().isSubset(of: continueAcks)
    }

    private func tryAdvanceAfterContinue() {
        guard state.phase == .handOver, allPlayersContinued() else { return }
        continueAcks.removeAll()
        startNextHandAfterContinue()
    }

    private func startNextHandAfterContinue() {
        cancelJobs()
        applyHost { SpadesEngine.nextHand($0) }
        runDeal()
    }

    private func runDeal() {
        dealTask?.cancel()
        dealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard let self, !Task.isCancelled else { return }
            while self.state.phase == .dealing {
                self.applyHost { SpadesEngine.dealNext($0) }
                self.reactAudio()
                if self.state.phase == .dealing {
                    try? await Task.sleep(nanoseconds: 42_000_000)
                }
            }
            self.scheduleAi()
        }
    }

    private func applyPlay(_ current: GameState, card: Card) {
        let next = SpadesEngine.playCard(current, seat: current.turn, card: card)
        publish(next)
        if next.trickWinner != nil {
            collectTask?.cancel()
            collectTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard let self, !Task.isCancelled else { return }
                self.applyHost { SpadesEngine.collectTrick($0) }
                self.scheduleAi()
            }
        } else {
            scheduleAi()
        }
    }

    private func scheduleAi() {
        aiTask?.cancel()
        let snapshot = state
        guard snapshot.isHost else { return }
        guard let turnPlayer = snapshot.players[snapshot.turn], !turnPlayer.isHuman else { return }
        guard snapshot.phase == .bidding || snapshot.phase == .playing else { return }
        guard snapshot.trickWinner == nil else { return }
        let delayNs: UInt64 = snapshot.phase == .bidding ? 650_000_000 : 700_000_000
        aiTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard let self, !Task.isCancelled else { return }
            let current = self.state
            guard current.isHost, let acting = current.players[current.turn], !acting.isHuman else { return }
            switch current.phase {
            case .bidding:
                let amount = SpadesAi.chooseBid(hand: current.player(current.turn).hand, nilEnabled: current.nilEnabled)
                self.applyHost { SpadesEngine.placeBid($0, seat: $0.turn, bid: amount) }
                self.scheduleAi()
            case .playing:
                let card = SpadesAi.chooseCard(state: current, seat: current.turn)
                self.applyPlay(current, card: card)
            default:
                break
            }
        }
    }

    private func ensureSession() {
        if session != nil { return }
        session = LanSession(displayName: currentName()) { [weak self] event in
            Task { @MainActor in self?.handleLan(event) }
        }
    }

    private func handleLan(_ event: LanEvent) {
        switch event {
        case .advertisingStarted:
            if state.phase == .lobby {
                state.lobbyMessage = "Table is open. Friends can join."
            }
        case .discoveryStarted:
            state.lobbyMessage = "Searching this Wi‑Fi…"
        case .endpointFound(let id, let name):
            state.discoveredTables.removeAll { $0.endpointId == id }
            state.discoveredTables.append(DiscoveredTable(endpointId: id, hostName: name))
            maybeAutoRejoin(id, tableName: name)
        case .endpointLost(let id):
            state.discoveredTables.removeAll { $0.endpointId == id }
        case .connected(let id, let name):
            onConnected(id, name: name)
        case .disconnected(let id):
            onDisconnected(id)
        case .message(let fromId, let msg):
            onMessage(fromId, msg)
        case .error(let message):
            state.lobbyMessage = message
        }
    }

    private func onConnected(_ id: String, name: String) {
        if role == .guest {
            hostEndpointId = id
            if let table = state.discoveredTables.first(where: { $0.endpointId == id }) {
                connectedHostName = table.hostName
            }
            session?.stopDiscovery()
            session?.send(id, .hello(name: currentName()))
            let looking = connectedHostName.isEmpty ? state.rejoinHostName : connectedHostName
            state.lobbyMessage = looking.isEmpty ? "Connected. Waiting for the host to deal." : "Rejoining \(looking)…"
            return
        }
        if role == .host {
            endpointNames[id] = name
            if state.phase == .lobby && endpointSeats.count >= 3 {
                session?.send(id, .error(message: "This table is full."))
                session?.disconnect(id)
            }
        }
    }

    private func onDisconnected(_ id: String) {
        if role == .guest && id == hostEndpointId {
            let current = state
            let hostName = connectedHostName.isEmpty ? current.rejoinHostName : connectedHostName
            teardownLan()
            var next = GameState()
            next.nilEnabled = settings.nilEnabled
            next.bagPenaltyEnabled = settings.bagPenaltyEnabled
            next.partnership = current.partnership
            next.playerName = current.playerName
            next.phase = .menu
            if !hostName.isEmpty && Self.inGamePhases.contains(current.phase) {
                next.rejoinHostName = hostName
                next.rejoinUntilMillis = nowMs() + Self.rejoinWindowMs
            }
            state = next
            return
        }
        guard role == .host else { return }
        guard endpointSeats[id] != nil else { return }
        pendingDisconnects[id]?.cancel()
        pendingDisconnects[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run { self.finalizeHostDisconnect(id) }
        }
    }

    private func finalizeHostDisconnect(_ id: String) {
        pendingDisconnects.removeValue(forKey: id)
        guard let seat = endpointSeats.removeValue(forKey: id) else { return }
        let leftName = endpointNames.removeValue(forKey: id) ?? state.players[seat]?.name ?? "A player"
        if state.phase == .lobby {
            if state.hostPartnerSeat == seat {
                state.hostPartnerSeat = firstGuestSeat()
            }
            state.partnership = endpointSeats.count >= 3 && state.partnership
            publishLobby()
            return
        }
        if state.phase == .handOver {
            tryAdvanceAfterContinue()
        }
        replaceSeatWithAi(seat, leftName: leftName)
    }

    private func cancelPendingDisconnect(forSeat seat: Seat, keepId: String) {
        if let oldId = endpointSeats.first(where: { $0.value == seat && $0.key != keepId })?.key {
            pendingDisconnects[oldId]?.cancel()
            pendingDisconnects.removeValue(forKey: oldId)
            endpointSeats.removeValue(forKey: oldId)
            endpointNames.removeValue(forKey: oldId)
            session?.disconnect(oldId)
        }
    }

    private func replaceSeatWithAi(_ seat: Seat, leftName: String) {
        guard var player = state.players[seat], player.isHuman else { return }
        let clean = leftName.components(separatedBy: " (AI)").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (clean?.isEmpty == false ? clean! : seat.defaultName)
        let notice = "\(name) left. An AI is playing that seat. They can rejoin for 5 minutes."
        player.isHuman = false
        player.name = "\(name) (AI)"
        state.players[seat] = player
        rejoinSeats[normalizeName(name)] = RejoinSlot(seat: seat, name: name, leftAt: nowMs())
        publish({
            var next = state
            next.notice = notice
            return next
        }())
        session?.resumeAdvertising(currentName())
        watchRejoinExpiry()
        scheduleAi()
        flashNotice(notice)
    }

    private func acceptRejoin(_ fromId: String, slot: RejoinSlot) {
        guard var player = state.players[slot.seat] else { return }
        rejoinSeats.removeValue(forKey: normalizeName(slot.name))
        cancelPendingDisconnect(forSeat: slot.seat, keepId: fromId)
        endpointSeats[fromId] = slot.seat
        endpointNames[fromId] = slot.name
        player.isHuman = true
        player.name = slot.name
        state.players[slot.seat] = player
        let notice = "\(slot.name) rejoined the table."
        session?.send(fromId, .assign(seat: slot.seat))
        var next = state
        next.notice = notice
        publish(next)
        session?.send(fromId, .state(game: stateForBroadcast(state)))
        if rejoinSeats.isEmpty && state.phase == .lobby {
            session?.stopAdvertising()
            rejoinWatch?.cancel()
        }
        aiTask?.cancel()
        scheduleAi()
        flashNotice(notice)
    }

    private func onMessage(_ fromId: String, _ msg: NetMsg) {
        switch msg {
        case .hello(let name):
            if role == .host { onHello(fromId, name: name) }
        case .welcome(let seat, let lobby):
            state.localSeat = seat
            state.lobbySeats = lobby
            state.isLan = true
            state.isHost = false
            state.lobbyMessage = "Joined. Waiting for the host to start."
        case .assign(let seat):
            state.localSeat = seat
        case .lobby(let seats, let nilEnabled, let bagPenaltyEnabled, let targetScore, let partnership, let hostPartnerSeat, let nsTeamName, let ewTeamName):
            state.phase = .lobby
            state.lobbySeats = seats
            state.nilEnabled = nilEnabled
            state.bagPenaltyEnabled = bagPenaltyEnabled
            state.targetScore = targetScore
            state.partnership = partnership
            state.hostPartnerSeat = hostPartnerSeat
            state.nsTeamName = nsTeamName
            state.ewTeamName = ewTeamName
            state.isLan = true
            state.isHost = false
            state.lastHand = nil
            state.lobbyMessage = "Table updated. Waiting for the host."
        case .state(let game):
            applyRemote(game)
        case .bid(let amount):
            if role == .host { onRemoteBid(fromId, amount: amount) }
        case .play:
            if role == .host, let card = msg.card { onRemotePlay(fromId, card: card) }
        case .continue:
            if role == .host { onRemoteContinue(fromId) }
        case .error(let message):
            state.lobbyMessage = message
        }
    }

    private func onHello(_ fromId: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = trimmed.isEmpty ? "Friend" : trimmed
        if state.phase != .lobby {
            pruneExpiredRejoin()
            if let slot = rejoinSeats[normalizeName(clean)] {
                acceptRejoin(fromId, slot: slot)
                return
            }
            if let seated = state.players.first(where: {
                $0.value.isHuman && normalizeName($0.value.name) == normalizeName(clean)
            }) {
                cancelPendingDisconnect(forSeat: seated.key, keepId: fromId)
                endpointSeats[fromId] = seated.key
                endpointNames[fromId] = clean
                session?.send(fromId, .assign(seat: seated.key))
                session?.send(fromId, .state(game: stateForBroadcast(state)))
                return
            }
            session?.send(fromId, .error(message: "This table already started. Rejoin only works for 5 minutes with the same name."))
            session?.disconnect(fromId)
            return
        }
        guard let seat = Self.guestSeats.first(where: { candidate in !endpointSeats.values.contains(candidate) }) else {
            session?.send(fromId, .error(message: "This table is full."))
            session?.disconnect(fromId)
            return
        }
        endpointSeats[fromId] = seat
        endpointNames[fromId] = clean
        let lobby = lobbySnapshot(currentName())
        session?.send(fromId, .welcome(seat: seat, lobby: lobby))
        publishLobby()
        state.lobbySeats = lobby
        state.lobbyMessage = "\(clean) joined. \(endpointSeats.count + 1) of 4 players."
    }

    private func onRemoteBid(_ fromId: String, amount: Int) {
        guard let seat = endpointSeats[fromId] else { return }
        guard state.phase == .bidding, state.turn == seat else { return }
        applyHost { SpadesEngine.placeBid($0, seat: seat, bid: amount) }
        scheduleAi()
    }

    private func onRemotePlay(_ fromId: String, card: Card) {
        guard let seat = endpointSeats[fromId] else { return }
        guard state.phase == .playing, state.turn == seat else { return }
        guard SpadesEngine.legalCards(state, seat: seat).contains(card) else { return }
        applyPlay(state, card: card)
    }

    private func publishLobby() {
        let seats = lobbySnapshot(currentName())
        state.lobbySeats = seats
        state.phase = .lobby
        session?.broadcast(.lobby(
            seats: seats,
            nilEnabled: state.nilEnabled,
            bagPenaltyEnabled: state.bagPenaltyEnabled,
            targetScore: state.targetScore,
            partnership: state.partnership,
            hostPartnerSeat: state.hostPartnerSeat,
            nsTeamName: state.nsTeamName,
            ewTeamName: state.ewTeamName
        ))
    }

    private func lobbySnapshot(_ hostName: String) -> [LobbySeat] {
        var result = [LobbySeat(seat: .south, name: hostName.isEmpty ? "Host" : hostName, isHuman: true, isHost: true)]
        for seat in Self.guestSeats {
            if let occupant = endpointSeats.first(where: { $0.value == seat })?.key {
                result.append(LobbySeat(seat: seat, name: endpointNames[occupant] ?? "Friend", isHuman: true, isHost: false))
            } else {
                result.append(LobbySeat(seat: seat, name: "Open", isHuman: false, isHost: false))
            }
        }
        return result
    }

    private func firstGuestSeat() -> Seat? {
        Self.guestSeats.first { seat in endpointSeats.values.contains(seat) }
    }

    private func lanSeating(hostName: String, partnership: Bool, partnerSeat: Seat?) -> ([Seat: String], [String: Seat]) {
        let guests = endpointSeats.map { id, seat in (id, seat, endpointNames[id] ?? "Friend") }
        var humans: [Seat: String] = [.south: hostName]
        var seated: [String: Seat] = [:]
        switch guests.count {
        case 1:
            humans[.north] = guests[0].2
            seated[guests[0].0] = .north
        case 2:
            humans[.west] = guests[0].2
            seated[guests[0].0] = .west
            humans[.east] = guests[1].2
            seated[guests[1].0] = .east
        default:
            if partnership {
                let partner = guests.first { $0.1 == partnerSeat } ?? guests[0]
                let others = guests.filter { $0.0 != partner.0 }
                humans[.north] = partner.2
                seated[partner.0] = .north
                humans[.west] = others[0].2
                seated[others[0].0] = .west
                humans[.east] = others[1].2
                seated[others[1].0] = .east
            } else {
                for (seat, guest) in zip([Seat.west, .north, .east], guests) {
                    humans[seat] = guest.2
                    seated[guest.0] = seat
                }
            }
        }
        return (humans, seated)
    }

    private func applyHost(_ transform: (GameState) -> GameState) {
        var next = transform(state)
        next.isHost = true
        next.isLan = state.isLan
        next.localSeat = state.localSeat
        next.playerName = state.playerName
        next.notice = state.notice
        publish(next)
    }

    private func publish(_ next: GameState) {
        let previous = state
        if next.phase == .handOver && previous.phase != .handOver {
            continueAcks.removeAll()
        }
        state = next
        reactAudio()
        guard next.isLan && next.isHost && next.phase != .lobby else { return }
        // Dealing animates locally card-by-card; guests only need start + end snapshots.
        if previous.phase == .dealing && next.phase == .dealing { return }
        session?.broadcast(.state(game: stateForBroadcast(next)))
    }

    private func stateForBroadcast(_ game: GameState) -> GameState {
        var copy = game
        copy.discoveredTables = []
        copy.lobbySeats = []
        copy.lobbyMessage = ""
        copy.rejoinHostName = ""
        copy.rejoinUntilMillis = 0
        copy.scoreHistory = []
        return copy
    }

    private func applyRemote(_ game: GameState) {
        let name = state.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = game.players.first { _, player in
            player.isHuman && !name.isEmpty && player.name.compare(name, options: .caseInsensitive) == .orderedSame
        }?.key
        var next = game
        next.localSeat = matched ?? state.localSeat
        next.isHost = false
        next.isLan = true
        next.playerName = state.playerName
        next.discoveredTables = []
        next.lobbySeats = []
        next.rejoinHostName = ""
        next.rejoinUntilMillis = 0
        state = next
        reactAudio()
    }

    private func teardownLan() {
        noticeTask?.cancel()
        rejoinWatch?.cancel()
        pendingDisconnects.values.forEach { $0.cancel() }
        pendingDisconnects.removeAll()
        continueAcks.removeAll()
        rejoinSeats.removeAll()
        autoRejoinAttempted = false
        session?.shutdown()
        session = nil
        role = .none
        hostEndpointId = nil
        connectedHostName = ""
        endpointSeats.removeAll()
        endpointNames.removeAll()
    }

    private func maybeAutoRejoin(_ endpointId: String, tableName: String) {
        guard !autoRejoinAttempted, role == .guest, rejoinStillOpen(state) else { return }
        guard tableName.compare(state.rejoinHostName, options: .caseInsensitive) == .orderedSame else { return }
        autoRejoinAttempted = true
        joinTable(endpointId)
    }

    private func rejoinStillOpen(_ game: GameState) -> Bool {
        !game.rejoinHostName.isEmpty && game.rejoinUntilMillis > nowMs()
    }

    private func preservedRejoin(_ game: GameState) -> (String, Int64) {
        rejoinStillOpen(game) ? (game.rejoinHostName, game.rejoinUntilMillis) : ("", 0)
    }

    private func normalizeName(_ name: String) -> String {
        (name.components(separatedBy: " (AI)").first ?? name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func pruneExpiredRejoin() {
        let now = nowMs()
        rejoinSeats = rejoinSeats.filter { now - $0.value.leftAt <= Self.rejoinWindowMs }
        if rejoinSeats.isEmpty && state.phase == .lobby {
            session?.stopAdvertising()
            rejoinWatch?.cancel()
        }
    }

    private func watchRejoinExpiry() {
        rejoinWatch?.cancel()
        rejoinWatch = Task { [weak self] in
            while true {
                guard let self, !self.rejoinSeats.isEmpty else { return }
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                await MainActor.run { self.pruneExpiredRejoin() }
            }
        }
    }

    private func flashNotice(_ notice: String) {
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard let self, !Task.isCancelled, self.state.notice == notice else { return }
            var next = self.state
            next.notice = ""
            self.publish(next)
        }
    }

    private func cancelJobs() {
        aiTask?.cancel()
        collectTask?.cancel()
        dealTask?.cancel()
        aiTask = nil
        collectTask = nil
        dealTask = nil
    }

    private func reactAudio() {
        let s = state
        if s.phase == .dealing && (lastPhase != .dealing || s.handNumber != lastHand) {
            GameAudio.playShuffle(enabled: settings.sfx)
        }
        if s.announceSpadesBroken && !lastSpades {
            GameAudio.playSpades(enabled: settings.sfx)
        }
        if s.trick.count > lastTrick {
            GameAudio.playCard(enabled: settings.sfx)
        }
        let yourTurn = s.turn == s.localSeat && s.trickWinner == nil && (s.phase == .bidding || s.phase == .playing)
        if yourTurn && !wasYourTurn {
            GameAudio.vibrateTurn(enabled: settings.vibration)
        }
        lastPhase = s.phase
        lastHand = s.handNumber
        lastSpades = s.announceSpadesBroken
        lastTrick = s.trick.count
        wasYourTurn = yourTurn
    }

    private func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
