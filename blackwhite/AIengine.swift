import Foundation

struct AIEngine {

    private static let winScore = 10_000_000
    private static let rootMoveLimit = 14
    private static let treeMoveLimit = 10
    private static let defaultDepth = 3

    static func bestMove(board: [[Int]],
                         player: Int,
                         ruleSet: GomokuRuleSet = .strictFive) -> (Int, Int)? {

        let candidates = rankedMoves(board: board,
                                     player: player,
                                     ruleSet: ruleSet,
                                     limit: rootMoveLimit)
        guard !candidates.isEmpty else { return nil }

        // 1) Immediate winning move
        for move in candidates {
            var next = board
            next[move.0][move.1] = player
            if isWinningBoard(next, player: player, ruleSet: ruleSet) {
                return move
            }
        }

        // 2) Immediate block if opponent can win in one move
        let opponent = -player
        let opponentWins = immediateWinningMoves(board: board,
                                                 player: opponent,
                                                 ruleSet: ruleSet)
        if !opponentWins.isEmpty {
            let blocks = candidates.filter { opponentWins.contains([$0.0, $0.1]) }
            if let bestBlock = blocks.max(by: {
                quickMoveScore(board: board, move: $0, player: player, ruleSet: ruleSet)
                < quickMoveScore(board: board, move: $1, player: player, ruleSet: ruleSet)
            }) {
                return bestBlock
            }
        }

        var bestScore = Int.min
        var bestMove: (Int, Int)? = candidates.first

        for move in candidates {
            var next = board
            next[move.0][move.1] = player

            let score = minimax(board: next,
                                depth: defaultDepth - 1,
                                currentPlayer: opponent,
                                maximizingPlayer: player,
                                alpha: Int.min,
                                beta: Int.max,
                                ruleSet: ruleSet)

            if score > bestScore {
                bestScore = score
                bestMove = move
            }
        }

        return bestMove
    }

    private static func minimax(board: [[Int]],
                                depth: Int,
                                currentPlayer: Int,
                                maximizingPlayer: Int,
                                alpha: Int,
                                beta: Int,
                                ruleSet: GomokuRuleSet) -> Int {

        if isWinningBoard(board, player: maximizingPlayer, ruleSet: ruleSet) {
            return winScore + depth
        }
        if isWinningBoard(board, player: -maximizingPlayer, ruleSet: ruleSet) {
            return -winScore - depth
        }

        if depth == 0 {
            return evaluate(board: board, player: maximizingPlayer, ruleSet: ruleSet)
        }

        let moves = rankedMoves(board: board,
                                player: currentPlayer,
                                ruleSet: ruleSet,
                                limit: treeMoveLimit)

        if moves.isEmpty {
            return evaluate(board: board, player: maximizingPlayer, ruleSet: ruleSet)
        }

        var alphaVar = alpha
        var betaVar = beta

        if currentPlayer == maximizingPlayer {
            var best = Int.min
            for move in moves {
                var next = board
                next[move.0][move.1] = currentPlayer

                let score = minimax(board: next,
                                    depth: depth - 1,
                                    currentPlayer: -currentPlayer,
                                    maximizingPlayer: maximizingPlayer,
                                    alpha: alphaVar,
                                    beta: betaVar,
                                    ruleSet: ruleSet)
                best = max(best, score)
                alphaVar = max(alphaVar, best)
                if betaVar <= alphaVar { break }
            }
            return best
        }

        var best = Int.max
        for move in moves {
            var next = board
            next[move.0][move.1] = currentPlayer

            let score = minimax(board: next,
                                depth: depth - 1,
                                currentPlayer: -currentPlayer,
                                maximizingPlayer: maximizingPlayer,
                                alpha: alphaVar,
                                beta: betaVar,
                                ruleSet: ruleSet)
            best = min(best, score)
            betaVar = min(betaVar, best)
            if betaVar <= alphaVar { break }
        }
        return best
    }

    private static func immediateWinningMoves(board: [[Int]],
                                              player: Int,
                                              ruleSet: GomokuRuleSet) -> Set<[Int]> {
        let moves = rankedMoves(board: board,
                                player: player,
                                ruleSet: ruleSet,
                                limit: nil)
        var wins = Set<[Int]>()

        for (r, c) in moves {
            var next = board
            next[r][c] = player
            if isWinningBoard(next, player: player, ruleSet: ruleSet) {
                wins.insert([r, c])
            }
        }

        return wins
    }

    private static func rankedMoves(board: [[Int]],
                                    player: Int,
                                    ruleSet: GomokuRuleSet,
                                    limit: Int?) -> [(Int, Int)] {
        let size = board.count
        var moves = Set<[Int]>()

        for r in 0..<size {
            for c in 0..<size where board[r][c] != 0 {
                for dr in -2...2 {
                    for dc in -2...2 {
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

        let sorted = moves.map { ($0[0], $0[1]) }
            .sorted {
                quickMoveScore(board: board, move: $0, player: player, ruleSet: ruleSet)
                > quickMoveScore(board: board, move: $1, player: player, ruleSet: ruleSet)
            }

        guard let limit, sorted.count > limit else {
            return sorted
        }
        return Array(sorted.prefix(limit))
    }

    private static func quickMoveScore(board: [[Int]],
                                       move: (Int, Int),
                                       player: Int,
                                       ruleSet: GomokuRuleSet) -> Int {
        let opponent = -player

        var attackBoard = board
        attackBoard[move.0][move.1] = player

        var defendBoard = board
        defendBoard[move.0][move.1] = opponent

        let attack = localBestLine(board: attackBoard, row: move.0, col: move.1, player: player)
        let defense = localBestLine(board: defendBoard, row: move.0, col: move.1, player: opponent)

        let center = board.count / 2
        let centerBias = 20 - (abs(center - move.0) + abs(center - move.1))

        var tactical = attack * 1000 + defense * 900 + centerBias

        if isWinningBoard(attackBoard, player: player, ruleSet: ruleSet) {
            tactical += winScore / 2
        }

        return tactical
    }

    private static func localBestLine(board: [[Int]], row: Int, col: Int, player: Int) -> Int {
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
        var best = 1

        for (dr, dc) in directions {
            var count = 1

            var r = row + dr
            var c = col + dc
            while r >= 0, r < board.count, c >= 0, c < board.count, board[r][c] == player {
                count += 1
                r += dr
                c += dc
            }

            r = row - dr
            c = col - dc
            while r >= 0, r < board.count, c >= 0, c < board.count, board[r][c] == player {
                count += 1
                r -= dr
                c -= dc
            }

            best = max(best, count)
        }

        return best
    }

    private static func isWinningBoard(_ board: [[Int]],
                                       player: Int,
                                       ruleSet: GomokuRuleSet) -> Bool {
        let size = board.count
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

        for r in 0..<size {
            for c in 0..<size where board[r][c] == player {
                for (dr, dc) in directions {
                    let prevR = r - dr
                    let prevC = c - dc
                    if prevR >= 0, prevR < size, prevC >= 0, prevC < size,
                       board[prevR][prevC] == player {
                        continue
                    }

                    var length = 0
                    var rr = r
                    var cc = c
                    while rr >= 0, rr < size,
                          cc >= 0, cc < size,
                          board[rr][cc] == player {
                        length += 1
                        rr += dr
                        cc += dc
                    }

                    switch ruleSet {
                    case .freestyle:
                        if length >= 5 { return true }
                    case .strictFive:
                        if length == 5 { return true }
                    case .renju:
                        if player == 1 {
                            if length == 5 { return true }
                        } else if length >= 5 {
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    private static func evaluate(board: [[Int]],
                                 player: Int,
                                 ruleSet: GomokuRuleSet) -> Int {
        let myScore = evaluatePlayer(board: board, player: player, ruleSet: ruleSet)
        let oppScore = evaluatePlayer(board: board, player: -player, ruleSet: ruleSet)
        return myScore - oppScore
    }

    private static func evaluatePlayer(board: [[Int]],
                                       player: Int,
                                       ruleSet: GomokuRuleSet) -> Int {
        let size = board.count
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
        var score = 0

        for r in 0..<size {
            for c in 0..<size where board[r][c] == player {
                for (dr, dc) in directions {
                    let prevR = r - dr
                    let prevC = c - dc
                    if prevR >= 0, prevR < size,
                       prevC >= 0, prevC < size,
                       board[prevR][prevC] == player {
                        continue
                    }

                    var count = 0
                    var rr = r
                    var cc = c
                    while rr >= 0, rr < size,
                          cc >= 0, cc < size,
                          board[rr][cc] == player {
                        count += 1
                        rr += dr
                        cc += dc
                    }

                    let forwardOpen = rr >= 0 && rr < size && cc >= 0 && cc < size && board[rr][cc] == 0
                    let backwardOpen = prevR >= 0 && prevR < size && prevC >= 0 && prevC < size && board[prevR][prevC] == 0
                    let openEnds = (forwardOpen ? 1 : 0) + (backwardOpen ? 1 : 0)

                    score += patternScore(count: count,
                                          openEnds: openEnds,
                                          player: player,
                                          ruleSet: ruleSet)
                }
            }
        }

        return score
    }

    private static func patternScore(count: Int,
                                     openEnds: Int,
                                     player: Int,
                                     ruleSet: GomokuRuleSet) -> Int {
        if count >= 5 {
            if ruleSet == .renju, player == 1, count > 5 {
                return 0
            }
            return winScore / 4
        }

        switch (count, openEnds) {
        case (4, 2): return 300_000
        case (4, 1): return 70_000
        case (3, 2): return 12_000
        case (3, 1): return 2_000
        case (2, 2): return 1_000
        case (2, 1): return 250
        case (1, 2): return 40
        default: return 0
        }
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
}
