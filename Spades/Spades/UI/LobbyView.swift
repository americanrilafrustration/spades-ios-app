import SwiftUI
import UIKit

struct LobbyView: View {
    @ObservedObject var store: GameStore
    @State private var confirmLeave = false

    private var humans: Int { store.state.lobbySeats.filter(\.isHuman).count }
    private var guests: [LobbySeat] { store.state.lobbySeats.filter { $0.isHuman && !$0.isHost } }
    private var atTable: Bool { store.state.isHost || store.state.lobbySeats.contains(where: \.isHuman) }

    var body: some View {
        ZStack {
            NavyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("♠").font(.system(size: 36)).foregroundStyle(Palette.lineGold)
                    Text("PLAY WITH FRIENDS")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(Palette.lineGold)
                        .tracking(1.4)
                    Text("Same Wi‑Fi. iPhone or Android. 2–4 people. If someone leaves mid-game, an AI takes their seat and they can rejoin for 5 minutes.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.cream.opacity(0.75))

                    if !store.state.rejoinHostName.isEmpty {
                        Text("Rejoin \(store.state.rejoinHostName) with the same name. Find their table within 5 minutes.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.lineGold)
                    }

                    field("Your name", text: Binding(
                        get: { store.state.playerName },
                        set: store.setPlayerName
                    ), placeholder: "e.g. Sam")

                    HStack(spacing: 10) {
                        Button("Host table") { store.hostTable() }
                            .buttonStyle(GoldButtonStyle())
                        Button("Find table") { store.findTables() }
                            .buttonStyle(GoldButtonStyle(filled: false))
                    }

                    Text(store.state.lobbyMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.cream.opacity(0.85))

                    if !store.state.lobbySeats.isEmpty {
                        section("TABLE")
                        ForEach(store.state.lobbySeats) { seat in
                            seatRow(seat)
                        }
                    }

                    if !store.state.discoveredTables.isEmpty {
                        section("NEARBY TABLES")
                        ForEach(store.state.discoveredTables) { table in
                            Button { store.joinTable(table.endpointId) } label: {
                                HStack {
                                    Text(table.hostName).foregroundStyle(Palette.cream).font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Text("Join").foregroundStyle(Palette.lineGold).fontWeight(.bold)
                                }
                                .padding(14)
                                .background(Palette.navyFelt.opacity(0.45))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.lineGold.opacity(0.45), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }

                    if !store.state.lobbySeats.isEmpty {
                        section("WINNING SCORE")
                        if store.state.isHost {
                            HStack(spacing: 6) {
                                ForEach([200, 250, 300, 500, 1000], id: \.self) { score in
                                    chip("\(score)", selected: store.state.targetScore == score) {
                                        store.setTargetScore(score)
                                    }
                                }
                            }
                            field("Custom", text: Binding(
                                get: { "\(store.state.targetScore)" },
                                set: { if let n = Int($0.filter(\.isNumber).prefix(4)) { store.setTargetScore(n) } }
                            ), keyboard: .numberPad)
                        } else {
                            Text("First to \(store.state.targetScore)")
                                .foregroundStyle(Palette.cream)
                                .font(.system(size: 16, weight: .medium))
                        }

                        SettingsToggleRow(
                            title: "10-bag penalty",
                            subtitle: store.state.bagPenaltyEnabled
                                ? "On — 10 bags costs 100 points"
                                : "Off — extra tricks stay +1 only",
                            isOn: store.state.bagPenaltyEnabled,
                            enabled: store.state.isHost,
                            onChange: store.setBagPenaltyEnabled
                        )

                        if humans < 4 {
                            Text(humans <= 1
                                 ? "Waiting for friends. 2 or 3 play individually."
                                 : "This table will play individually — no bots.")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.cream.opacity(0.75))
                        } else {
                            section("FOUR PLAYERS")
                            if store.state.isHost {
                                HStack(spacing: 8) {
                                    chip("Individual", selected: !store.state.partnership) { store.setLanPartnership(false) }
                                    chip("Teams", selected: store.state.partnership) { store.setLanPartnership(true) }
                                }
                            } else {
                                Text(store.state.partnership ? "Host chose team play" : "Host chose individual play")
                                    .foregroundStyle(Palette.cream.opacity(0.8))
                            }
                            if store.state.partnership {
                                Text("Partners").foregroundStyle(Palette.lineGold).font(.system(size: 14, weight: .semibold))
                                Text("Host picks a partner. The other two are the second team.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.cream.opacity(0.7))
                                ForEach(guests) { guest in
                                    let selected = store.state.hostPartnerSeat == guest.seat
                                    Button { store.setHostPartner(guest.seat) } label: {
                                        HStack {
                                            Text(guest.name).foregroundStyle(Palette.cream)
                                            Spacer()
                                            Text(selected ? "YOUR TEAM" : "OTHER TEAM")
                                                .foregroundStyle(Palette.lineGold)
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .padding(12)
                                        .background(selected ? Palette.lineGold.opacity(0.22) : Palette.navyFelt.opacity(0.35))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Palette.lineGold : Color.white.opacity(0.22), lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    }
                                    .disabled(!store.state.isHost)
                                }
                                field("Your team name", text: Binding(get: { store.state.nsTeamName }, set: store.setNsTeamName))
                                    .disabled(!store.state.isHost)
                                field("Other team name", text: Binding(get: { store.state.ewTeamName }, set: store.setEwTeamName))
                                    .disabled(!store.state.isHost)
                            }
                        }
                    }

                    if store.state.isHost {
                        let startLabel: String = {
                            if humans < 2 { return "Need at least 2 players" }
                            if humans < 4 { return "Start \(humans)-player individual" }
                            return store.state.partnership ? "Start team game" : "Start 4-player individual"
                        }()
                        Button(startLabel) { store.startLanGame() }
                            .buttonStyle(GoldButtonStyle(height: 56))
                            .disabled(humans < 2)
                            .opacity(humans < 2 ? 0.45 : 1)
                    }

                    Button("Back") {
                        if atTable { confirmLeave = true } else { store.backToMenu() }
                    }
                    .buttonStyle(GoldButtonStyle(filled: false))
                }
                .padding(24)
            }
            if confirmLeave {
                LeaveTableDialog(
                    isHost: store.state.isHost,
                    inGame: false,
                    isLan: true,
                    onStay: { confirmLeave = false },
                    onLeave: { confirmLeave = false; store.backToMenu() }
                )
            }
        }
        .onEdgeBack {
            if confirmLeave {
                confirmLeave = false
            } else if atTable {
                confirmLeave = true
            } else {
                store.backToMenu()
            }
        }
    }

    private func section(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Palette.lineGold)
            .tracking(2)
            .padding(.top, 8)
    }

    private func seatRow(_ seat: LobbySeat) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(seat.seat.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.cream.opacity(0.55))
                    .tracking(1)
                Text(seat.name).foregroundStyle(Palette.cream).font(.system(size: 16, weight: .medium))
            }
            Spacer()
            Text(seat.isHost ? "HOST" : (seat.isHuman ? "FRIEND" : "OPEN"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(seat.isHost ? Palette.teamBlue : Palette.lineGold)
        }
        .padding(12)
        .background(Palette.navyFelt.opacity(0.45))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(seat.isHuman ? Palette.lineGold.opacity(0.7) : Color.white.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Palette.lineGold : Palette.navyDeep.opacity(0.7))
                .foregroundStyle(selected ? Palette.navyDeep : Palette.cream)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String = "", keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13)).foregroundStyle(Palette.cream.opacity(0.7))
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.words)
                .keyboardType(keyboard)
                .foregroundStyle(Palette.cream)
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.lineGold.opacity(0.7), lineWidth: 1))
        }
    }
}
