import Foundation

struct AIEngine {

    // Weights for local pattern count (1...5)
    private static let weightTable = [0, 1, 10, 100, 1000, 100000]

    static func bestMove(board: [[Int]],
                         player: Int,
                         ruleSet: GomokuRuleSet = .strictFive) -> (Int, Int)? {

        let candidates = nearbyMoves(board: board,
                                     player: player,
                                     ruleSet: ruleSet)

        var bestScore = Int.min
        var bestMove: (Int, Int)?

        for (r, c) in candidates {
            var newBoard = board
            newBoard[r][c] = player

            let score = minimax(board: newBoard,
                                depth: 2,
                                maximizing: false,
                                player: player,
                                ruleSet: ruleSet)

            if score > bestScore {
                bestScore = score
                bestMove = (r, c)
            }
        }

        return bestMove
    }

    private static func minimax(board: [[Int]],
                                depth: Int,
                                maximizing: Bool,
                                player: Int,
                                ruleSet: GomokuRuleSet) -> Int {

        if depth == 0 {
            return evaluate(board: board, player: player)
        }

        let current = maximizing ? player : -player
        let moves = nearbyMoves(board: board, player: current, ruleSet: ruleSet)

        if moves.isEmpty {
            return evaluate(board: board, player: player)
        }

        if maximizing {
            var best = Int.min
            for (r, c) in moves {
                var b = board
                b[r][c] = player
                best = max(best,
                           minimax(board: b,
                                   depth: depth - 1,
                                   maximizing: false,
                                   player: player,
                                   ruleSet: ruleSet))
            }
            return best
        }

        var best = Int.max
        for (r, c) in moves {
            var b = board
            b[r][c] = -player
            best = min(best,
                       minimax(board: b,
                               depth: depth - 1,
                               maximizing: true,
                               player: player,
                               ruleSet: ruleSet))
        }
        return best
    }

    // Search only around existing stones.
    private static func nearbyMoves(board: [[Int]],
                                    player: Int,
                                    ruleSet: GomokuRuleSet) -> [(Int, Int)] {
        let size = board.count
        var moves = Set<[Int]>()

        for r in 0..<size {
            for c in 0..<size where board[r][c] != 0 {
                for dr in -1...1 {
                    for dc in -1...1 {
                        let nr = r + dr
                        let nc = c + dc
                        if nr >= 0, nr < size,
                           nc >= 0, nc < size,
                           board[nr][nc] == 0,
                           !isForbiddenMove(board: board,
                                            row: nr,
                                            col: nc,
                                            player: player,
                                            ruleSet: ruleSet) {
                            moves.insert([nr, nc])
                        }
                    }
                }
            }
        }

        if moves.isEmpty {
            let center = (size / 2, size / 2)
            if !isForbiddenMove(board: board,
                                row: center.0,
                                col: center.1,
                                player: player,
                                ruleSet: ruleSet) {
                return [center]
            }

            for r in 0..<size {
                for c in 0..<size where board[r][c] == 0 {
                    if !isForbiddenMove(board: board,
                                        row: r,
                                        col: c,
                                        player: player,
                                        ruleSet: ruleSet) {
                        return [(r, c)]
                    }
                }
            }
            return []
        }

        return moves.map { ($0[0], $0[1]) }
    }

    private static func isForbiddenMove(board: [[Int]],
                                        row: Int,
                                        col: Int,
                                        player: Int,
                                        ruleSet: GomokuRuleSet) -> Bool {
        guard ruleSet == .renju, player == 1 else { return false }
        var next = board
        next[row][col] = player
        return hasOverline(board: next, row: row, col: col, player: player)
    }

    private static func hasOverline(board: [[Int]], row: Int, col: Int, player: Int) -> Bool {
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
        let size = board.count

        for (dr, dc) in directions {
            var count = 1

            var r = row + dr
            var c = col + dc
            while r >= 0, r < size, c >= 0, c < size, board[r][c] == player {
                count += 1
                r += dr
                c += dc
            }

            r = row - dr
            c = col - dc
            while r >= 0, r < size, c >= 0, c < size, board[r][c] == player {
                count += 1
                r -= dr
                c -= dc
            }

            if count > 5 {
                return true
            }
        }

        return false
    }

    // Heuristic evaluator
    private static func evaluate(board: [[Int]], player: Int) -> Int {

        var score = 0
        let size = board.count
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

        for r in 0..<size {
            for c in 0..<size {
                for (dr, dc) in directions {

                    var count = 0
                    var rr = r
                    var cc = c

                    for _ in 0..<5 {
                        if rr >= 0, rr < size,
                           cc >= 0, cc < size,
                           board[rr][cc] == player {
                            count += 1
                        }
                        rr += dr
                        cc += dc
                    }

                    if count > 0, count < weightTable.count {
                        score += weightTable[count]
                    }
                }
            }
        }

        return score
    }
}
