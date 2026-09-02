import SwiftUI

struct ScorecardOverlay: View {
    var state: GameState
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onQuit: () -> Void

    var body: some View {
        if let result = state.lastHand {
            if !state.partnership && !result.individuals.isEmpty {
                IndividualScorecard(state: state, result: result, onContinue: onContinue, onNewGame: onNewGame, onQuit: onQuit)
            } else {
                PartnershipScorecard(state: state, result: result, onContinue: onContinue, onNewGame: onNewGame, onQuit: onQuit)
            }
        }
    }
}

private struct PartnershipScorecard: View {
    var state: GameState
    var result: HandResult
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onQuit: () -> Void

    @State private var nsNow = 0
    @State private var ewNow = 0
    @State private var counting = true
    @State private var showFinale = false
    @State private var overtake: String?

    var body: some View {
        let gameOver = state.phase == .gameOver
        let nsLabel = state.nsTeamName.isEmpty ? "US" : state.nsTeamName
        let ewLabel = state.ewTeamName.isEmpty ? "THEM" : state.ewTeamName
        ResultsSheet(
            title: gameOver ? "FINAL RESULTS" : "ROUND \(result.handNumber) RESULTS",
            counting: counting,
            gameOver: gameOver,
            showFinale: showFinale,
            isLanGuest: state.isLan && !state.isHost,
            onContinue: onContinue,
            onNewGame: onNewGame,
            onQuit: onQuit
        ) {
            tableHeaders()
            ForEach(sortedTeams, id: \.label) { team in
                resultRow(
                    label: team.label,
                    names: team.names,
                    accent: team.accent,
                    summary: team.summary,
                    total: team.total,
                    leading: team.total == max(nsNow, ewNow) && nsNow != ewNow
                )
            }
            if let overtake {
                leadChip(overtake)
            }
            if gameOver {
                winLose(youWon: localTeamWon(), tied: result.ns.total == result.ew.total, hint: "First to \(state.targetScore)")
            }
        }
        .task(id: result.handNumber) {
            nsNow = result.ns.previousTotal
            ewNow = result.ew.previousTotal
            counting = true
            showFinale = false
            overtake = nil
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 1.5)) {
                nsNow = result.ns.total
                ewNow = result.ew.total
            }
            try? await Task.sleep(nanoseconds: 1_580_000_000)
            counting = false
            if nsNow != ewNow {
                overtake = nsNow > ewNow ? nsLabel : ewLabel
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            overtake = nil
            if gameOver {
                try? await Task.sleep(nanoseconds: 200_000_000)
                showFinale = true
            }
        }
    }

    private func localTeamWon() -> Bool? {
        if result.ns.total == result.ew.total { return nil }
        let onUs = state.localSeat == .south || state.localSeat == .north
        let usWon = result.ns.total > result.ew.total
        return onUs ? usWon : !usWon
    }

    private var sortedTeams: [(label: String, names: [String], accent: Color, summary: TeamHandSummary, total: Int)] {
        let nsLabel = state.nsTeamName.isEmpty ? "US" : state.nsTeamName
        let ewLabel = state.ewTeamName.isEmpty ? "THEM" : state.ewTeamName
        let teams = [
            (nsLabel.uppercased(), result.nsPlayers.map(\.name), Palette.teamBlue, result.ns, nsNow),
            (ewLabel.uppercased(), result.ewPlayers.map(\.name), Color(red: 0.357, green: 0.396, blue: 0.471), result.ew, ewNow)
        ]
        return teams.sorted { $0.4 > $1.4 }.map { (label: $0.0, names: $0.1, accent: $0.2, summary: $0.3, total: $0.4) }
    }
}

private struct IndividualScorecard: View {
    var state: GameState
    var result: HandResult
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onQuit: () -> Void

    @State private var now: [Seat: Int] = [:]
    @State private var counting = true
    @State private var showFinale = false
    @State private var overtake: String?

    var body: some View {
        let gameOver = state.phase == .gameOver
        let players = sortedPlayers(now: now)
        let best = players.map { now[$0.seat] ?? $0.previousTotal }.max() ?? 0
        ResultsSheet(
            title: gameOver ? "FINAL RESULTS" : "ROUND \(result.handNumber) RESULTS",
            counting: counting,
            gameOver: gameOver,
            showFinale: showFinale,
            isLanGuest: state.isLan && !state.isHost,
            onContinue: onContinue,
            onNewGame: onNewGame,
            onQuit: onQuit
        ) {
            tableHeaders(teamLabel: "PLAYER")
            ForEach(players) { summary in
                let name = summary.seat == state.localSeat ? "YOU" : summary.name.uppercased()
                resultRow(
                    label: name,
                    names: [],
                    accent: seatAccent(summary.seat, partnership: false),
                    playLine: playLine(summary.contract, summary.tricks, summary.made, summary.nilPoints),
                    roundNote: roundNote(summary.bidPoints, summary.bagPoints, summary.nilPoints, summary.bagsTaken, summary.bagPenalty, summary.previousTotal),
                    delta: summary.delta,
                    total: now[summary.seat] ?? summary.previousTotal,
                    bags: summary.bags,
                    bagPenalty: summary.bagPenalty,
                    leading: (now[summary.seat] ?? summary.previousTotal) == best
                )
            }
            if let overtake { leadChip(overtake) }
            if gameOver {
                let topScore = players.map(\.total).max() ?? 0
                let winner = players.first(where: { $0.total == topScore })?.name ?? ""
                let tied = players.filter { $0.total == topScore }.count > 1
                winLose(youWon: players.first(where: { $0.total == topScore })?.seat == state.localSeat && !tied, tied: tied && gameOver, hint: "\(winner) reached \(state.targetScore)")
            }
        }
        .task(id: result.handNumber) {
            let players = result.individuals
            now = Dictionary(uniqueKeysWithValues: players.map { ($0.seat, $0.previousTotal) })
            counting = true
            showFinale = false
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 1.5)) {
                now = Dictionary(uniqueKeysWithValues: players.map { ($0.seat, $0.total) })
            }
            try? await Task.sleep(nanoseconds: 1_580_000_000)
            counting = false
            try? await Task.sleep(nanoseconds: 900_000_000)
            if gameOver {
                try? await Task.sleep(nanoseconds: 200_000_000)
                showFinale = true
            }
        }
    }

    private func sortedPlayers(now: [Seat: Int]) -> [PlayerHandSummary] {
        result.individuals.sorted { a, b in
            let aTotal = now[a.seat] ?? a.previousTotal
            let bTotal = now[b.seat] ?? b.previousTotal
            if aTotal != bTotal { return aTotal > bTotal }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}

private struct ResultsSheet<Content: View>: View {
    var title: String
    var counting: Bool
    var gameOver: Bool
    var showFinale: Bool
    var isLanGuest: Bool
    var onContinue: () -> Void
    var onNewGame: () -> Void
    var onQuit: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color(red: 0.027, green: 0.078, blue: 0.157).opacity(0.8).ignoresSafeArea()
            VStack {
                Spacer(minLength: 56)
                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(1.2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(LinearGradient(colors: [Palette.headerTop, Palette.headerBottom], startPoint: .top, endPoint: .bottom))
                    VStack(alignment: .leading, spacing: 8) {
                        content
                        if gameOver {
                            if !isLanGuest {
                                Button("PLAY AGAIN", action: onNewGame)
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(LinearGradient(colors: [Palette.continueTop, Palette.continueBottom], startPoint: .leading, endPoint: .trailing))
                                    .clipShape(Capsule())
                            } else {
                                Text("Waiting for the host")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.gray)
                                    .frame(maxWidth: .infinity)
                            }
                            Button("Menu", action: onQuit)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.118, green: 0.337, blue: 0.910))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                        } else {
                            Button("CONTINUE", action: onContinue)
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(LinearGradient(colors: [Palette.continueTop, Palette.continueBottom], startPoint: .leading, endPoint: .trailing))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                }
                .background(Palette.sheetWhite)
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(Palette.cardBorder, lineWidth: 1.8))
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .padding(.horizontal, 20)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 56)
            }
        }
    }
}

private func tableHeaders(teamLabel: String = "TEAM") -> some View {
    HStack {
        Text(teamLabel).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.gray)
        Spacer()
        Text("THIS ROUND").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.gray)
        Text("TOTAL").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.gray).frame(width: 64, alignment: .trailing)
    }
}

private func resultRow(label: String, names: [String], accent: Color, summary: TeamHandSummary, total: Int, leading: Bool) -> some View {
    resultRow(
        label: label,
        names: names,
        accent: accent,
        playLine: playLine(summary.contract, summary.tricks, summary.made, summary.nilPoints),
        roundNote: roundNote(summary.bidPoints, summary.bagPoints, summary.nilPoints, summary.bagsTaken, summary.bagPenalty, summary.previousTotal),
        delta: summary.delta,
        total: total,
        bags: summary.bags,
        bagPenalty: summary.bagPenalty,
        leading: leading
    )
}

private func resultRow(
    label: String,
    names: [String],
    accent: Color,
    playLine: String,
    roundNote: String?,
    delta: Int,
    total: Int,
    bags: Int,
    bagPenalty: Bool,
    leading: Bool
) -> some View {
    HStack(alignment: .top) {
        RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 6)
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 14, weight: .black)).foregroundStyle(Color(red: 0.11, green: 0.14, blue: 0.22))
            if !names.isEmpty {
                Text(names.joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(Color.gray)
            }
            Text(playLine).font(.system(size: 12)).foregroundStyle(Color(red: 0.25, green: 0.28, blue: 0.35))
            if let roundNote {
                Text(roundNote).font(.system(size: 11)).foregroundStyle(Color.gray)
            }
        }
        Spacer()
        Text(delta > 0 ? "+\(delta)" : "\(delta)")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(delta >= 0 ? Color(red: 0.106, green: 0.420, blue: 0.271) : Color(red: 0.608, green: 0.173, blue: 0.173))
        VStack {
            Text("\(total)").font(.system(size: 20, weight: .black)).foregroundStyle(leading ? Palette.headerBottom : Color.primary)
            Text(bagPenalty ? "\(bags) bags" : "\(bags)")
                .font(.system(size: 10))
                .foregroundStyle(Color.gray)
        }
        .frame(width: 64)
    }
    .padding(10)
    .background(Color(red: 0.165, green: 0.200, blue: 0.282).opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 12))
}

private func leadChip(_ name: String) -> some View {
    Text("\(name.uppercased()) TAKES THE LEAD")
        .font(.system(size: 12, weight: .black))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Palette.headerBottom)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
}

private func winLose(youWon: Bool?, tied: Bool, hint: String) -> some View {
    VStack(spacing: 4) {
        Text(tied ? "TIE GAME" : (youWon == true ? "YOU WIN" : "YOU LOSE"))
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(tied ? Palette.headerBottom : (youWon == true ? Color(red: 0.055, green: 0.639, blue: 0.478) : Color(red: 0.882, green: 0.294, blue: 0.294)))
        Text(hint).font(.system(size: 13)).foregroundStyle(Color.gray)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 6)
}

private func playLine(_ contract: Int, _ tricks: Int, _ made: Bool, _ nilPoints: Int) -> String {
    let outcome: String
    if nilPoints > 0 { outcome = "nil" }
    else if nilPoints < 0 { outcome = "nil set" }
    else { outcome = made ? "made" : "set" }
    let word = tricks == 1 ? "trick" : "tricks"
    return "Bid \(contract) · \(tricks) \(word) · \(outcome)"
}

private func roundNote(_ bidPoints: Int, _ bagPoints: Int, _ nilPoints: Int, _ bagsTaken: Int, _ bagPenalty: Bool, _ previousTotal: Int) -> String? {
    let hand = bidPoints + bagPoints + nilPoints
    let bags = bagsTaken == 1 ? "1 bag this hand" : "\(bagsTaken) bags this hand"
    if bagPenalty { return "\(hand > 0 ? "+" : "")\(hand) · \(bags) · 10-bag −100" }
    if previousTotal != 0 { return "was \(previousTotal)" }
    return nil
}
