import SwiftUI

struct GameView: View {
    @ObservedObject var store: GameStore
    @State private var confirmLeave = false
    @State private var showSettings = false
    @State private var hintCard: Card?
    @State private var selectedBid: Int?

    private var state: GameState { store.state }
    private var local: Seat { state.localSeat }
    private var legal: [Card] {
        state.turn == local ? SpadesEngine.legalCards(state, seat: local) : []
    }
    private var showBidPad: Bool { state.phase == .bidding && state.turn == local }
    private var gameInProgress: Bool { state.phase != .gameOver }

    var body: some View {
        ZStack {
            Palette.navyDeep.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Rectangle().fill(Palette.lineGold).frame(height: 2)
                table
                handArea
            }
            if showBidPad { bidPad }
            if state.phase == .handOver || state.phase == .gameOver {
                ScorecardOverlay(
                    state: state,
                    onContinue: store.continueNextHand,
                    onNewGame: {
                        if store.state.isLan { store.startLanGame() } else { store.startGame() }
                    },
                    onQuit: requestLeave
                )
            }
            if showSettings {
                gameSettings
            }
            if confirmLeave {
                LeaveTableDialog(
                    isHost: state.isHost,
                    inGame: true,
                    isLan: state.isLan,
                    onStay: { confirmLeave = false },
                    onLeave: { confirmLeave = false; store.backToMenu() }
                )
            }
        }
        .onEdgeBack {
            if confirmLeave {
                confirmLeave = false
            } else if showSettings {
                showSettings = false
            } else {
                requestLeave()
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(state.isLan ? "LEAVE" : "NEW GAME", action: requestLeave)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.lineGold)
            Spacer()
            scoreBar
            Spacer()
            Button { showSettings = true } label: {
                Text("⚙").font(.system(size: 18)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Palette.teamBlue)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.navyHeader)
    }

    @ViewBuilder
    private var scoreBar: some View {
        if state.partnership {
            HStack(spacing: 8) {
                scorePill(state.nsTeamName, state.ns, Palette.teamBlue)
                Text("\(state.targetScore)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.lineGold)
                scorePill(state.ewTeamName, state.ew, Palette.teamRed)
            }
        } else {
            HStack(spacing: 4) {
                ForEach(state.activeSeats(), id: \.self) { seat in
                    let score = state.scoreOf(seat)
                    Text("\(seat == local ? "You" : state.player(seat).name.prefix(4)) \(score.points)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(seatAccent(seat, partnership: false))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func scorePill(_ name: String, _ score: TeamScore, _ color: Color) -> some View {
        Text("\(name) \(score.points) · \(score.bags)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    private var table: some View {
        let north = TableLayout.actualSeat(visual: .north, local: local)
        let west = TableLayout.actualSeat(visual: .west, local: local)
        let east = TableLayout.actualSeat(visual: .east, local: local)
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(RadialGradient(colors: [Palette.navyFelt, Palette.navyFeltDark, Color(red: 0.027, green: 0.094, blue: 0.200)], center: .center, startRadius: 20, endRadius: 420))
            Text("♠").font(.system(size: 220)).foregroundStyle(Color.white.opacity(0.06))
            if state.hasSeat(north) {
                VStack {
                    CardBackFan(count: state.player(north).hand.count, vertical: false)
                    seatMarker(state.player(north), active: state.turn == north)
                    Spacer()
                }
                .padding(.top, 8)
            }
            if state.hasSeat(west) {
                HStack {
                    VStack {
                        CardBackFan(count: state.player(west).hand.count, vertical: true)
                        seatMarker(state.player(west), active: state.turn == west)
                    }
                    Spacer()
                }
                .padding(.leading, 8)
            }
            if state.hasSeat(east) {
                HStack {
                    Spacer()
                    VStack {
                        CardBackFan(count: state.player(east).hand.count, vertical: true)
                        seatMarker(state.player(east), active: state.turn == east)
                    }
                }
                .padding(.trailing, 8)
            }
            centerPlay
            banners
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var centerPlay: some View {
        ZStack {
            ForEach(state.trick, id: \.seat) { play in
                let visual = TableLayout.visualSeat(actual: play.seat, local: local)
                PlayingCardView(card: play.card, width: 52)
                    .offset(trickOffset(visual))
            }
        }
    }

    private func trickOffset(_ visual: Seat) -> CGSize {
        switch visual {
        case .south: return CGSize(width: 0, height: 36)
        case .north: return CGSize(width: 0, height: -36)
        case .west: return CGSize(width: -40, height: 0)
        case .east: return CGSize(width: 40, height: 0)
        }
    }

    @ViewBuilder
    private var banners: some View {
        VStack {
            Spacer()
            if !state.notice.isEmpty {
                banner(state.notice)
            } else if state.announceSpadesBroken && state.phase == .playing {
                banner("♠  Spades Broken!")
            } else if !showBidPad && (state.phase == .dealing || (!state.status.isEmpty && state.phase != .playing)) {
                banner(state.status)
            }
            Spacer().frame(height: 8)
        }
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.45))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.cyanLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func seatMarker(_ player: PlayerState, active: Bool) -> some View {
        let bidText: String = {
            if let bid = player.bid {
                return bid == 0 && state.nilEnabled ? "Nil" : "\(player.tricks) / \(bid)"
            }
            return "—"
        }()
        return VStack(spacing: 2) {
            Text(player.seat == local ? "You" : player.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(bidText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.lineGold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? Palette.lineGold : Color.clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var handArea: some View {
        VStack(spacing: 6) {
            HStack {
                Text(state.phase == .dealing ? "Dealing…" : (state.phase == .bidding ? "Your hand" : "Tricks: \(state.player(local).tricks) / \(state.player(local).bid ?? 0)"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.cream)
                Spacer()
                if state.phase == .playing && state.turn == local && state.trickWinner == nil {
                    Button("💡") {
                        hintCard = SpadesAi.chooseCard(state: state, seat: local)
                    }
                    .font(.system(size: 16))
                    .padding(6)
                    .background(Palette.hintYellow)
                    .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -18) {
                    ForEach(Array(state.player(local).hand.enumerated()), id: \.offset) { _, card in
                        let canPlay = state.phase == .playing && state.turn == local && state.trickWinner == nil
                        let allowed = legal.contains(card)
                        Button {
                            if canPlay && allowed {
                                hintCard = nil
                                store.play(card)
                            }
                        } label: {
                            PlayingCardView(
                                card: card,
                                dimmed: canPlay && !allowed,
                                highlighted: hintCard == card,
                                width: 62
                            )
                            .offset(y: hintCard == card ? -10 : 0)
                        }
                        .disabled(!(canPlay && allowed))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 8)
        .background(Palette.navyHeader)
    }

    private var bidPad: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("How many tricks do you think you will take?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.28))
                    .multilineTextAlignment(.center)
                if state.nilEnabled {
                    Text("0 is Nil · ±100").font(.system(size: 13)).foregroundStyle(Color.gray)
                }
                let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0...state.tricksPerHand, id: \.self) { n in
                        Button {
                            selectedBid = n
                        } label: {
                            Text(n == 0 && state.nilEnabled ? "Nil" : "\(n)")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 52, height: 44)
                                .background(
                                    LinearGradient(
                                        colors: selectedBid == n
                                            ? [Color(red: 0.847, green: 1, blue: 0.353), Color(red: 0.490, green: 1, blue: 0.831)]
                                            : [Color(red: 0.353, green: 0.608, blue: 1), Color(red: 0.118, green: 0.337, blue: 0.910)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .foregroundStyle(selectedBid == n ? Palette.navyDeep : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                Text("Count your Aces, Kings and Spades!")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray)
                Button("PLACE BID") {
                    if let selectedBid { store.bid(selectedBid) }
                }
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(LinearGradient(colors: [Color(red: 0.102, green: 0.831, blue: 0.722), Color(red: 0.055, green: 0.639, blue: 0.478)], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .opacity(selectedBid == nil ? 0.45 : 1)
                .disabled(selectedBid == nil)
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20)
        }
        .onAppear { selectedBid = nil }
    }

    private var gameSettings: some View {
        ZStack {
            Color(red: 0.027, green: 0.078, blue: 0.157).opacity(0.8).ignoresSafeArea().onTapGesture { showSettings = false }
            VStack(spacing: 12) {
                Text("SETTINGS").font(.system(size: 18, weight: .black)).foregroundStyle(Color(red: 0.118, green: 0.310, blue: 0.847))
                Toggle("Music", isOn: Binding(get: { store.settings.music }, set: store.setMusic)).tint(Palette.headerBottom)
                Toggle("Sound effects", isOn: Binding(get: { store.settings.sfx }, set: store.setSfx)).tint(Palette.headerBottom)
                Toggle("Vibration", isOn: Binding(get: { store.settings.vibration }, set: store.setVibration)).tint(Palette.headerBottom)
                Button {
                    showSettings = false
                    requestLeave()
                } label: {
                    Text(!state.isLan ? "NEW GAME" : (state.isHost ? "END TABLE" : "LEAVE TABLE"))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color(red: 0.882, green: 0.294, blue: 0.294))
                        .clipShape(Capsule())
                }
                Button("CLOSE") { showSettings = false }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.118, green: 0.337, blue: 0.910))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(Capsule().stroke(Color(red: 0.118, green: 0.337, blue: 0.910), lineWidth: 1.4))
            }
            .padding(18)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.cardBorder, lineWidth: 1.6))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 28)
        }
    }

    private func requestLeave() {
        if gameInProgress { confirmLeave = true } else { store.backToMenu() }
    }
}
