import Foundation
import Combine

enum GomokuRuleSet: String, CaseIterable, Identifiable {
    case freestyle     // Five or more in a row wins.
    case strictFive    // Exactly five in a row wins.
    case renju         // Black cannot win (or play) with overline.

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .freestyle: return "Freestyle"
        case .strictFive: return "Strict Five"
        case .renju: return "Renju"
        }
    }
}

final class GameEngine: ObservableObject {

    @Published var board: [[Int]]
    @Published var currentPlayer: Int = 1
    @Published var winner: Int? = nil
    @Published var isDraw = false
    @Published var winLine: [(Int, Int)] = []
    @Published var lastInvalidMoveReason: String? = nil

    let size: Int
    @Published var ruleSet: GomokuRuleSet

    private struct Snapshot {
        let board: [[Int]]
        let currentPlayer: Int
        let winner: Int?
        let isDraw: Bool
        let winLine: [(Int, Int)]
    }

    private var history: [Snapshot] = []

    init(size: Int = 10, ruleSet: GomokuRuleSet = .strictFive) {
        self.size = size
        self.ruleSet = ruleSet
        self.board = Array(repeating: Array(repeating: 0, count: size), count: size)
    }

    func reset() {
        board = Array(repeating: Array(repeating: 0, count: size), count: size)
        currentPlayer = 1
        winner = nil
        isDraw = false
        history.removeAll()
        winLine.removeAll()
        lastInvalidMoveReason = nil
    }

    func makeMove(row: Int, col: Int) {
        lastInvalidMoveReason = nil

        guard isInsideBoard(row: row, col: col) else {
            lastInvalidMoveReason = "out_of_bounds"
            return
        }

        guard winner == nil, !isDraw else {
            lastInvalidMoveReason = "game_ended"
            return
        }

        guard board[row][col] == 0 else {
            lastInvalidMoveReason = "occupied"
            return
        }

        if isForbiddenMove(row: row, col: col, player: currentPlayer) {
            lastInvalidMoveReason = "forbidden_move"
            return
        }

        history.append(Snapshot(board: board,
                                currentPlayer: currentPlayer,
                                winner: winner,
                                isDraw: isDraw,
                                winLine: winLine))

        board[row][col] = currentPlayer

        if let line = winningLine(row: row, col: col, player: currentPlayer, board: board) {
            winLine = line
            winner = currentPlayer
            return
        }

        if board.allSatisfy({ $0.allSatisfy { $0 != 0 } }) {
            isDraw = true
            return
        }

        currentPlayer *= -1
    }

    func undo() {
        guard let last = history.popLast() else { return }
        board = last.board
        currentPlayer = last.currentPlayer
        winner = last.winner
        isDraw = last.isDraw
        winLine = last.winLine
        lastInvalidMoveReason = nil
    }

    func legalMoves(for player: Int? = nil) -> [(Int, Int)] {
        let p = player ?? currentPlayer
        var moves: [(Int, Int)] = []
        for r in 0..<size {
            for c in 0..<size where board[r][c] == 0 {
                if !isForbiddenMove(row: r, col: c, player: p) {
                    moves.append((r, c))
                }
            }
        }
        return moves
    }

    private func isInsideBoard(row: Int, col: Int) -> Bool {
        row >= 0 && row < size && col >= 0 && col < size
    }

    private func isForbiddenMove(row: Int, col: Int, player: Int) -> Bool {
        guard ruleSet == .renju, player == 1 else { return false }
        var next = board
        next[row][col] = player
        return hasOverline(row: row, col: col, player: player, board: next)
    }

    private func winningLine(row: Int, col: Int, player: Int, board: [[Int]]) -> [(Int, Int)]? {
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

        for (dr, dc) in directions {
            let backward = collect(fromRow: row, col: col, dr: -dr, dc: -dc, player: player, board: board)
            let forward = collect(fromRow: row, col: col, dr: dr, dc: dc, player: player, board: board)

            var line = Array(backward.reversed())
            line.append((row, col))
            line.append(contentsOf: forward)

            let lineCount = line.count
            switch ruleSet {
            case .freestyle:
                if lineCount >= 5 {
                    return centeredFive(from: Array(line))
                }
            case .strictFive:
                if lineCount == 5 {
                    return Array(line)
                }
            case .renju:
                if player == 1 {
                    if lineCount == 5 { return Array(line) }
                } else if lineCount >= 5 {
                    return centeredFive(from: Array(line))
                }
            }
        }

        return nil
    }

    private func centeredFive(from line: [(Int, Int)]) -> [(Int, Int)] {
        if line.count <= 5 { return line }
        let center = line.count / 2
        let start = max(0, center - 2)
        let end = min(line.count, start + 5)
        return Array(line[start..<end])
    }

    private func hasOverline(row: Int, col: Int, player: Int, board: [[Int]]) -> Bool {
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

        for (dr, dc) in directions {
            let backward = collect(fromRow: row, col: col, dr: -dr, dc: -dc, player: player, board: board)
            let forward = collect(fromRow: row, col: col, dr: dr, dc: dc, player: player, board: board)
            let count = backward.count + 1 + forward.count
            if count > 5 {
                return true
            }
        }

        return false
    }

    private func collect(fromRow row: Int,
                         col: Int,
                         dr: Int,
                         dc: Int,
                         player: Int,
                         board: [[Int]]) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        var r = row + dr
        var c = col + dc

        while isInsideBoard(row: r, col: c), board[r][c] == player {
            result.append((r, c))
            r += dr
            c += dc
        }

        return result
    }
}
