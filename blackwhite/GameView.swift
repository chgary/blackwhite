import SwiftUI

struct GameView: View {

    @StateObject private var engine = GameEngine(size: 10, ruleSet: .strictFive)

    private let cellSize: CGFloat = 32
    private let cellSpacing: CGFloat = 2

    var body: some View {
        VStack(spacing: 12) {
            Text(statusText)
                .font(.headline)

            Picker("Rule", selection: $engine.ruleSet) {
                ForEach(GomokuRuleSet.allCases) { rule in
                    Text(rule.displayName).tag(rule)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: engine.ruleSet) { _ in
                engine.reset()
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

            if let reason = engine.lastInvalidMoveReason {
                Text(invalidMoveText(reason))
                    .foregroundColor(.red)
                    .font(.footnote)
            }

            HStack(spacing: 16) {
                Button("Undo") {
                    engine.undo()
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    engine.reset()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var statusText: String {
        if let winner = engine.winner {
            return winner == 1 ? "Black Wins" : "White Wins"
        }
        if engine.isDraw {
            return "Draw"
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
            engine.makeMove(row: row, col: col)
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
