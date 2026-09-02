import SwiftUI

struct MenuView: View {
    @ObservedObject var store: GameStore
    @State private var showSettings = false
    @State private var now = Date()

    private var rejoinOpen: Bool {
        !store.state.rejoinHostName.isEmpty && store.state.rejoinUntilMillis > Int64(now.timeIntervalSince1970 * 1000)
    }

    private var remainLabel: String {
        let remain = max(0, store.state.rejoinUntilMillis - Int64(now.timeIntervalSince1970 * 1000)) / 1000
        return String(format: "%d:%02d", remain / 60, remain % 60)
    }

    var body: some View {
        ZStack {
            NavyBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Text("⚙")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Palette.teamBlue)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 0) {
                        AppLogo(size: 112)
                            .padding(.bottom, 4)
                        Text("SPADES")
                            .font(.system(size: 44, weight: .bold, design: .serif))
                            .foregroundStyle(Palette.lineGold)
                            .tracking(8)
                        Text(store.state.partnership ? "Partnership trick-taking" : "Every player for themselves")
                            .font(.system(size: 16))
                            .foregroundStyle(Palette.cream.opacity(0.75))
                            .padding(.top, 8)
                            .padding(.bottom, 28)

                        playStyleCard
                        Spacer().frame(height: 20)

                        if rejoinOpen {
                            Button("Rejoin \(store.state.rejoinHostName)  ·  \(remainLabel)") {
                                store.rejoinLastTable()
                            }
                            .buttonStyle(GoldButtonStyle(height: 56))
                            Text("Same name, same table. You have 5 minutes.")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.cream.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.bottom, 12)
                        }

                        Button("Play vs AI") { store.startGame() }
                            .buttonStyle(GoldButtonStyle(height: 56))
                        Spacer().frame(height: 14)
                        Button("Play with friends") { store.openLobby() }
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Palette.teamBlue)
                            .foregroundStyle(Palette.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Spacer().frame(height: 14)
                        Button("How to play") { store.showRules() }
                            .buttonStyle(GoldButtonStyle(filled: false))
                        Spacer().frame(height: 36)
                        Text(store.state.partnership
                             ? "You + Reese  vs  Cam + Quinn\nFirst team to 500 wins"
                             : "You vs Cam, Reese, and Quinn\nFirst player to 500 wins")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.cream.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                }
            }
            if showSettings {
                MenuSettingsSheet(store: store, onClose: { showSettings = false })
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .onEdgeBack { if showSettings { showSettings = false } }
    }

    private var playStyleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vs AI")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.lineGold)
            Text(store.state.partnership
                 ? "Team score — you and Reese share one total"
                 : "Four separate scores on the table")
                .font(.system(size: 13))
                .foregroundStyle(Palette.cream.opacity(0.8))
            HStack(spacing: 8) {
                chip("Team", selected: store.state.partnership) { store.setPartnership(true) }
                chip("Individual", selected: !store.state.partnership) { store.setPartnership(false) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.navyFelt.opacity(0.45))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Palette.lineGold : Palette.navyDeep.opacity(0.7))
                .foregroundStyle(selected ? Palette.navyDeep : Palette.cream)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct MenuSettingsSheet: View {
    @ObservedObject var store: GameStore
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.027, green: 0.078, blue: 0.157).opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                Text("SETTINGS")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Palette.lineGold)
                    .tracking(1.4)
                SettingsToggleRow(
                    title: "Nil scoring",
                    subtitle: store.state.nilEnabled
                        ? "On — bid Nil for +100, or −100 if you take a trick"
                        : "Off — no Nil bid and no ±100 points",
                    isOn: store.state.nilEnabled,
                    onChange: store.setNilEnabled
                )
                SettingsToggleRow(
                    title: "10-bag penalty",
                    subtitle: store.state.bagPenaltyEnabled
                        ? "On — every 10 bags costs 100 points"
                        : "Off — extra tricks are still +1, with no −100",
                    isOn: store.state.bagPenaltyEnabled,
                    onChange: store.setBagPenaltyEnabled
                )
                audioCard
                Button("CLOSE", action: onClose)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.lineGold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 23).stroke(Palette.lineGold, lineWidth: 1.4))
            }
            .padding(18)
            .background(Palette.navyHeader)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.lineGold, lineWidth: 1.6))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)
        }
    }

    private var audioCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            toggle("Music", "Background table music", store.settings.music, store.setMusic)
            toggle("Sound effects", "Shuffle, cards, and Spades broken", store.settings.sfx, store.setSfx)
            toggle("Vibration", "Buzz when it is your turn", store.settings.vibration, store.setVibration)
        }
        .padding(14)
        .background(Palette.navyFelt.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func toggle(_ title: String, _ subtitle: String, _ on: Bool, _ set: @escaping (Bool) -> Void) -> some View {
        Toggle(isOn: Binding(get: { on }, set: set)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Palette.cream).font(.system(size: 15, weight: .medium))
                Text(subtitle).foregroundStyle(Palette.cream.opacity(0.7)).font(.system(size: 12))
            }
        }
        .tint(Palette.lineGold)
    }
}
