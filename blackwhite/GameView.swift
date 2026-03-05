import SwiftUI

struct GameView: View {

    @StateObject private var engine = GameEngine(size: 10, ruleSet: .strictFive)

    @State private var aiEnabled = true
    @State private var aiThinking = false
    @State private var showFireworks = false
    @State private var fireworksTrigger = UUID()

    private let aiPlayer = -1
    private let cellSize: CGFloat = 32
    private let cellSpacing: CGFloat = 2

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Text(statusText)
                    .font(.headline)

                Toggle("Play vs AI (White)", isOn: $aiEnabled)
                    .onChange(of: aiEnabled) { _ in
                        triggerAIMoveIfNeeded()
                    }

                Picker("Rule", selection: $engine.ruleSet) {
                    ForEach(GomokuRuleSet.allCases) { rule in
                        Text(rule.displayName).tag(rule)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: engine.ruleSet) { _ in
                    engine.reset()
                    showFireworks = false
                    triggerAIMoveIfNeeded()
                }

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: engine.size), spacing: cellSpacing) {
                    ForEach(0..<(engine.size * engine.size), id: \.self) { index in
                        let row = index / engine.size
                        let col = index % engine.size
                        cellView(row: row, col: col)
                    }
                }
                .padding(8)
                .background(Color(red: 0.93, green: 0.82, blue: 0.60))
                .cornerRadius(10)

                if aiEnabled && aiThinking {
                    ProgressView("AI is thinking...")
                        .font(.footnote)
                }

                if let reason = engine.lastInvalidMoveReason {
                    Text(invalidMoveText(reason))
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                HStack(spacing: 16) {
                    Button("Undo") {
                        engine.undo()
                        showFireworks = false
                        triggerAIMoveIfNeeded()
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        engine.reset()
                        showFireworks = false
                        triggerAIMoveIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            if showFireworks {
                FireworksOverlay(trigger: fireworksTrigger)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: engine.currentPlayer) { _ in
            triggerAIMoveIfNeeded()
        }
        .onChange(of: engine.winner) { _ in
            handleWinnerStateChange()
        }
    }

    private var statusText: String {
        if let winner = engine.winner {
            return winner == 1 ? "Black Wins" : "White Wins"
        }
        if engine.isDraw {
            return "Draw"
        }
        if aiEnabled && engine.currentPlayer == aiPlayer {
            return "White Turn (AI)"
        }
        return engine.currentPlayer == 1 ? "Black Turn" : "White Turn"
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int) -> some View {
        let value = engine.board[row][col]
        let isWinningCell = engine.winLine.contains { $0.0 == row && $0.1 == col }

        ZStack {
            Rectangle()
                .fill(Color(red: 0.86, green: 0.71, blue: 0.45))
                .frame(width: cellSize, height: cellSize)

            if isWinningCell {
                Rectangle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: cellSize, height: cellSize)
            }

            if value == 1 {
                Circle()
                    .fill(.black)
                    .frame(width: cellSize - 6, height: cellSize - 6)
            } else if value == -1 {
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                    .frame(width: cellSize - 6, height: cellSize - 6)
            }
        }
        .overlay(Rectangle().stroke(Color.black.opacity(0.5), lineWidth: 0.5))
        .onTapGesture {
            guard canHumanMove else { return }
            engine.makeMove(row: row, col: col)
        }
    }

    private var canHumanMove: Bool {
        guard engine.winner == nil, !engine.isDraw else { return false }
        if !aiEnabled { return true }
        return engine.currentPlayer != aiPlayer
    }

    private func triggerAIMoveIfNeeded() {
        guard aiEnabled,
              !aiThinking,
              engine.winner == nil,
              !engine.isDraw,
              engine.currentPlayer == aiPlayer else {
            return
        }

        aiThinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            defer { self.aiThinking = false }

            guard self.aiEnabled,
                  self.engine.winner == nil,
                  !self.engine.isDraw,
                  self.engine.currentPlayer == self.aiPlayer else {
                return
            }

            let aiMove = AIEngine.bestMove(board: self.engine.board,
                                           player: self.aiPlayer,
                                           ruleSet: self.engine.ruleSet)
            let move = aiMove ?? self.engine.legalMoves(for: self.aiPlayer).first
            if let (r, c) = move {
                self.engine.makeMove(row: r, col: c)
            }
        }
    }

    private func handleWinnerStateChange() {
        if engine.winner != nil {
            fireworksTrigger = UUID()
            withAnimation(.easeInOut(duration: 0.25)) {
                showFireworks = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                showFireworks = false
            }
        }
    }

    private func invalidMoveText(_ reason: String) -> String {
        switch reason {
        case "occupied":
            return "This cell is occupied."
        case "forbidden_move":
            return "Forbidden move under current rule."
        case "game_ended":
            return "Game already ended."
        case "out_of_bounds":
            return "Move is out of bounds."
        default:
            return reason
        }
    }
}

private struct FireworksOverlay: View {

    let trigger: UUID

    @State private var bursts: [FireworkBurst] = []
    @State private var timer: Timer?

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for burst in bursts {
                    let elapsed = timeline.date.timeIntervalSince(burst.start)
                    let progress = elapsed / burst.duration
                    guard progress >= 0, progress <= 1 else { continue }

                    let cx = burst.position.x * size.width
                    let cy = burst.position.y * size.height
                    let alpha = max(0, 1 - progress)
                    let radius = CGFloat(progress) * burst.maxRadius

                    for i in 0..<burst.particleCount {
                        let angle = (Double(i) / Double(burst.particleCount)) * .pi * 2 + burst.phase
                        let x = cx + CGFloat(cos(angle)) * radius
                        let y = cy + CGFloat(sin(angle)) * radius
                        let dotSize = CGFloat(2.5 + (1 - progress) * 3)

                        let dotRect = CGRect(x: x - dotSize / 2,
                                             y: y - dotSize / 2,
                                             width: dotSize,
                                             height: dotSize)
                        context.fill(Path(ellipseIn: dotRect),
                                     with: .color(burst.color.opacity(alpha)))
                    }

                    let coreSize = CGFloat(4 + (1 - progress) * 8)
                    let coreRect = CGRect(x: cx - coreSize / 2,
                                          y: cy - coreSize / 2,
                                          width: coreSize,
                                          height: coreSize)
                    context.fill(Path(ellipseIn: coreRect),
                                 with: .color(.white.opacity(alpha * 0.8)))
                }
            }
        }
        .onAppear {
            restart()
        }
        .onChange(of: trigger) { _ in
            restart()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func restart() {
        timer?.invalidate()
        bursts = []

        for i in 0..<10 {
            let delay = Double(i) * 0.12
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.bursts.append(.random())
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: true) { _ in
            self.bursts.removeAll { Date().timeIntervalSince($0.start) > $0.duration }
            self.bursts.append(.random())
            if self.bursts.count > 30 {
                self.bursts.removeFirst(self.bursts.count - 30)
            }
        }
    }
}

private struct FireworkBurst: Identifiable {

    let id = UUID()
    let start: Date
    let position: CGPoint
    let color: Color
    let phase: Double
    let duration: Double
    let maxRadius: CGFloat
    let particleCount: Int

    static func random() -> FireworkBurst {
        let colors: [Color] = [.red, .yellow, .orange, .pink, .blue, .green, .mint, .white]
        return FireworkBurst(start: Date(),
                             position: CGPoint(x: CGFloat.random(in: 0.12...0.88),
                                               y: CGFloat.random(in: 0.08...0.68)),
                             color: colors.randomElement() ?? .white,
                             phase: Double.random(in: 0...(2 * .pi)),
                             duration: Double.random(in: 0.9...1.4),
                             maxRadius: CGFloat.random(in: 42...105),
                             particleCount: Int.random(in: 18...34))
    }
}
