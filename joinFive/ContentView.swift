//
//  ContentView.swift
//  joinFive
//
//  Created by Philippe GREZE on 15/07/2026.
//

import SwiftUI
import Combine

private enum GameMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case fiveD = "5D"
    case fiveT = "5T"

    var id: String { rawValue }
}

private enum Direction: String, CaseIterable, Sendable, Codable {
    case horizontal
    case vertical
    case fall
    case rise

    var delta: (x: Int, y: Int) {
        switch self {
        case .horizontal: return (1, 0)
        case .vertical: return (0, 1)
        case .fall: return (1, 1)
        case .rise: return (1, -1)
        }
    }

    var shortLabel: String {
        switch self {
        case .horizontal: return "H"
        case .vertical: return "V"
        case .fall: return "\\"
        case .rise: return "/"
        }
    }
}

private struct GridCoordinate: Hashable, Sendable, Codable {
    let x: Int
    let y: Int
}

private struct MoveLine: Hashable, Identifiable, Sendable, Codable {
    let points: [GridCoordinate]
    let newPoint: GridCoordinate
    let direction: Direction
    var number: Int?

    var id: String {
        let start = points.first ?? newPoint
        let end = points.last ?? newPoint
        return "\(start.x),\(start.y)-\(end.x),\(end.y)-\(newPoint.x),\(newPoint.y)-\(direction.rawValue)"
    }

    static func == (lhs: MoveLine, rhs: MoveLine) -> Bool {
        lhs.points == rhs.points && lhs.newPoint == rhs.newPoint && lhs.direction == rhs.direction
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(points)
        hasher.combine(newPoint)
        hasher.combine(direction)
    }
}

private struct GridState: Sendable, Codable {
    let width: Int
    let height: Int
    var mode: GameMode

    private(set) var points: Set<GridCoordinate>
    private(set) var locks: [GridCoordinate: Set<Direction>]
    private(set) var lines: [MoveLine]

    init(width: Int = 50, height: Int = 50, mode: GameMode = .fiveD) {
        self.width = width
        self.height = height
        self.mode = mode
        self.points = []
        self.locks = [:]
        self.lines = []
        initSeed()
    }

    var score: Int { lines.count }

    mutating func reset(mode: GameMode) {
        self.mode = mode
        points.removeAll(keepingCapacity: true)
        locks.removeAll(keepingCapacity: true)
        lines.removeAll(keepingCapacity: true)
        initSeed()
    }

    mutating func addLine(_ line: MoveLine) {
        var applied = line
        applied.number = lines.count + 1

        points.insert(line.newPoint)
        for point in line.points {
            points.insert(point)
            var currentLocks = locks[point, default: []]
            currentLocks.insert(line.direction)
            locks[point] = currentLocks
        }
        lines.append(applied)
    }

    mutating func undoLastLine() {
        guard let last = lines.popLast() else { return }

        points.remove(last.newPoint)
        for point in last.points {
            guard var currentLocks = locks[point] else { continue }
            currentLocks.remove(last.direction)
            if currentLocks.isEmpty {
                locks.removeValue(forKey: point)
            } else {
                locks[point] = currentLocks
            }
        }
    }

    func isValid(_ coordinate: GridCoordinate) -> Bool {
        coordinate.x >= 0 && coordinate.x < width && coordinate.y >= 0 && coordinate.y < height
    }

    func isOccupied(_ coordinate: GridCoordinate) -> Bool {
        points.contains(coordinate)
    }

    func isLocked(_ coordinate: GridCoordinate, direction: Direction) -> Bool {
        locks[coordinate]?.contains(direction) == true
    }

    func neighbors(of coordinate: GridCoordinate) -> [GridCoordinate] {
        var result: [GridCoordinate] = []
        for dx in -1...1 {
            for dy in -1...1 {
                if dx == 0 && dy == 0 { continue }
                let n = GridCoordinate(x: coordinate.x + dx, y: coordinate.y + dy)
                if isValid(n) {
                    result.append(n)
                }
            }
        }
        return result
    }

    func possibleLines(at coordinate: GridCoordinate) -> [MoveLine] {
        guard isValid(coordinate), !isOccupied(coordinate) else { return [] }
        return Direction.allCases.flatMap { possibleLines(at: coordinate, direction: $0) }
    }

    func possibleLines(at coordinate: GridCoordinate, direction: Direction) -> [MoveLine] {
        guard !isOccupied(coordinate) else { return [] }
        let delta = direction.delta
        let maxLocksAllowed = mode == .fiveT ? 1 : 0
        var result: [MoveLine] = []

        for i in -4...0 {
            var remainingLocks = maxLocksAllowed
            var candidate: [GridCoordinate] = []
            var isValidLine = true

            for j in 0..<5 {
                let x = coordinate.x + delta.x * (i + j)
                let y = coordinate.y + delta.y * (i + j)
                let point = GridCoordinate(x: x, y: y)

                guard isValid(point) else {
                    isValidLine = false
                    break
                }

                if point == coordinate {
                    candidate.append(point)
                } else if isOccupied(point) && !isLocked(point, direction: direction) {
                    candidate.append(point)
                } else if isOccupied(point), remainingLocks > 0 {
                    candidate.append(point)
                    remainingLocks -= 1
                } else {
                    isValidLine = false
                    break
                }
            }

            if isValidLine {
                result.append(MoveLine(points: candidate, newPoint: coordinate, direction: direction, number: nil))
            }
        }

        return result
    }

    func possibleLinesAroundExistingPoints() -> [MoveLine] {
        var candidateCells: Set<GridCoordinate> = []
        for point in points {
            for neighbor in neighbors(of: point) where !isOccupied(neighbor) {
                candidateCells.insert(neighbor)
            }
        }

        var allLines: Set<MoveLine> = []
        for cell in candidateCells {
            for line in possibleLines(at: cell) {
                allLines.insert(line)
            }
        }
        return Array(allLines)
    }

    private mutating func initSeed() {
        let startX = (width - 10) / 2
        let startY = (height - 10) / 2

        for i in 0..<10 {
            for j in 0..<10 {
                if i < 3 && (j < 3 || j > 6) { continue }
                if i > 6 && (j < 3 || j > 6) { continue }
                if i > 0 && i < 9 && j > 3 && j < 6 { continue }
                if j > 0 && j < 9 && i > 3 && i < 6 { continue }

                points.insert(GridCoordinate(x: startX + i, y: startY + j))
            }
        }
    }

    // MARK: - Codable (clé GridCoordinate dans locks nécessite un codage manuel)

    private struct LockEntry: Codable {
        let x: Int
        let y: Int
        let directions: [Direction]
    }

    private enum CodingKeys: String, CodingKey {
        case width, height, mode, points, locks, lines
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(mode, forKey: .mode)
        try c.encode(Array(points), forKey: .points)
        let lockEntries = locks.map { LockEntry(x: $0.key.x, y: $0.key.y, directions: Array($0.value)) }
        try c.encode(lockEntries, forKey: .locks)
        try c.encode(lines, forKey: .lines)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width  = try c.decode(Int.self,      forKey: .width)
        height = try c.decode(Int.self,      forKey: .height)
        mode   = try c.decode(GameMode.self, forKey: .mode)
        let pointsArray = try c.decode([GridCoordinate].self, forKey: .points)
        points = Set(pointsArray)
        let lockEntries = try c.decode([LockEntry].self, forKey: .locks)
        var locksDict: [GridCoordinate: Set<Direction>] = [:]
        for entry in lockEntries {
            locksDict[GridCoordinate(x: entry.x, y: entry.y)] = Set(entry.directions)
        }
        locks = locksDict
        lines = try c.decode([MoveLine].self, forKey: .lines)
    }
}

// MARK: - Persistence

private struct ScoreEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var playerName: String
    var score: Int
    var mode: GameMode
    var date: Date
}

private enum PersistenceService {
    static var containerURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("joinFive", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var bestGridURL: URL { containerURL.appendingPathComponent("best.json") }
    static var historyURL:  URL { containerURL.appendingPathComponent("history.json") }

    static func saveBestGrid(_ grid: GridState) {
        guard let data = try? JSONEncoder().encode(grid) else { return }
        try? data.write(to: bestGridURL)
    }

    static func loadBestGrid() -> GridState? {
        guard let data = try? Data(contentsOf: bestGridURL) else { return nil }
        return try? JSONDecoder().decode(GridState.self, from: data)
    }

    static func appendScore(_ entry: ScoreEntry) {
        var history = loadHistory()
        history.append(entry)
        history.sort { $0.score > $1.score }
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyURL)
        }
    }

    static func loadHistory() -> [ScoreEntry] {
        guard let data = try? Data(contentsOf: historyURL) else { return [] }
        return (try? JSONDecoder().decode([ScoreEntry].self, from: data)) ?? []
    }
}

// MARK: - Algorithms

private protocol JoinFiveAlgorithm: Sendable {
    var name: String { get }
    func nextMove(on grid: GridState) -> MoveLine?
}

private struct RandomSearchAlgorithm: JoinFiveAlgorithm {
    let name = "Random Search"

    func nextMove(on grid: GridState) -> MoveLine? {
        let possible = grid.possibleLinesAroundExistingPoints()
        guard !possible.isEmpty else { return nil }
        return possible.randomElement()
    }
}

private struct NMCSAlgorithm: JoinFiveAlgorithm {
    let name = "NMCS"
    private let maxDuration: TimeInterval = 1.5
    private let level: Int = 2

    private struct SearchResult {
        let score: Int
        let lines: [MoveLine]
    }

    func nextMove(on grid: GridState) -> MoveLine? {
        let deadline = Date().addingTimeInterval(maxDuration)
        let result = search(grid: grid, depth: level, deadline: deadline)
        return result.lines.first
    }

    private func rollout(from grid: GridState) -> SearchResult {
        var state = grid
        var moves: [MoveLine] = []
        let random = RandomSearchAlgorithm()

        while let line = random.nextMove(on: state) {
            moves.append(line)
            state.addLine(line)
        }
        return SearchResult(score: state.score, lines: moves)
    }

    private func search(grid: GridState, depth: Int, deadline: Date) -> SearchResult {
        if depth < 1 || Date() >= deadline {
            return rollout(from: grid)
        }

        var runningGrid = grid
        var globalBest = SearchResult(score: runningGrid.score, lines: [])
        var visited: [MoveLine] = []

        while Date() < deadline {
            let possible = runningGrid.possibleLinesAroundExistingPoints()
            if possible.isEmpty { break }

            var currentBestLine: MoveLine?
            var currentBestResult = SearchResult(score: Int.min, lines: [])

            // Limite le nombre de branches examinées pour rester fluide
            let candidates = possible.count > 30 ? Array(possible.shuffled().prefix(30)) : possible

            for line in candidates {
                var child = runningGrid
                child.addLine(line)
                let candidate = search(grid: child, depth: depth - 1, deadline: deadline)
                if candidate.score > currentBestResult.score {
                    currentBestLine = line
                    currentBestResult = candidate
                }
                if Date() >= deadline { break }
            }

            guard let chosenLine = currentBestLine else { break }

            if currentBestResult.score < globalBest.score, visited.count < globalBest.lines.count {
                let fallback = globalBest.lines[visited.count]
                visited.append(fallback)
                runningGrid.addLine(fallback)
            } else {
                visited.append(chosenLine)
                globalBest = SearchResult(score: currentBestResult.score, lines: visited + currentBestResult.lines)
                runningGrid.addLine(chosenLine)
            }
        }

        return globalBest
    }
}

private struct NRPAAlgorithm: JoinFiveAlgorithm {
    let name = "NRPA"

    private struct Policy {
        private var weights: [String: Double] = [:]

        mutating func adjust(_ line: MoveLine, by value: Double) {
            let key = line.id
            weights[key] = (weights[key] ?? 0.0) + value
        }

        func weight(for line: MoveLine) -> Double {
            weights[line.id] ?? 0.0
        }
    }

    func nextMove(on grid: GridState) -> MoveLine? {
        let deadline = Date().addingTimeInterval(2.0)
        var policy = Policy()
        var bestScore = grid.score
        var bestSequence: [MoveLine] = []

        while Date() < deadline {
            let (score, sequence) = playout(from: grid, policy: policy)
            if score >= bestScore {
                bestScore = score
                bestSequence = sequence
                policy = adapt(policy: policy, from: grid, sequence: sequence)
            }
        }

        return bestSequence.first
    }

    private func playout(from grid: GridState, policy: Policy) -> (Int, [MoveLine]) {
        var state = grid
        var sequence: [MoveLine] = []

        while true {
            let legal = state.possibleLinesAroundExistingPoints()
            guard !legal.isEmpty else { break }

            let selected = selectAction(from: legal, policy: policy)
            sequence.append(selected)
            state.addLine(selected)
        }

        return (state.score, sequence)
    }

    private func selectAction(from legal: [MoveLine], policy: Policy) -> MoveLine {
        var cumulative: [Double] = []
        cumulative.reserveCapacity(legal.count)
        var sum = 0.0

        for line in legal {
            let weight = exp(policy.weight(for: line))
            sum += weight
            cumulative.append(sum)
        }

        guard sum > 0 else {
            return legal.randomElement() ?? legal[0]
        }

        let randomValue = Double.random(in: 0..<sum)
        for (index, value) in cumulative.enumerated() where value >= randomValue {
            return legal[index]
        }

        return legal[legal.count - 1]
    }

    private func adapt(policy: Policy, from grid: GridState, sequence: [MoveLine]) -> Policy {
        let alpha = 1.0
        var updated = policy
        var state = grid

        for chosen in sequence {
            updated.adjust(chosen, by: alpha)

            let legal = state.possibleLinesAroundExistingPoints()
            let z = legal.reduce(0.0) { partial, line in
                partial + exp(policy.weight(for: line))
            }

            if z > 0 {
                for line in legal {
                    let reduction = alpha * exp(policy.weight(for: line)) / z
                    updated.adjust(line, by: -reduction)
                }
            }

            state.addLine(chosen)
        }

        return updated
    }
}

@MainActor
private final class JoinFiveViewModel: ObservableObject {
    enum PlayerType: String, CaseIterable, Identifiable {
        case human = "Humain"
        case computer = "Ordinateur"

        var id: String { rawValue }
    }

    enum ComputerType: String, CaseIterable, Identifiable {
        case random = "Random Search"
        case nmcs = "NMCS"
        case nrpa = "NRPA"

        var id: String { rawValue }
    }

    @Published var grid = GridState()
    @Published var mode: GameMode = .fiveD
    @Published var player: PlayerType = .human
    @Published var computer: ComputerType = .random
    @Published var showHints = false
    @Published var lineChoices: [MoveLine] = []
    @Published var elapsedTime: TimeInterval = 0
    @Published var isComputerRunning = false
    @Published var bestSessionScore = 0
    @Published var playerName: String = "Joueur"
    @Published var bestGrid: GridState? = nil
    @Published var scoreHistory: [ScoreEntry] = []
    @Published var showBestGrid = false
    @Published var showHistory = false

    private var timerTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?
    private var simulationStartDate: Date?

    init() {
        bestGrid = PersistenceService.loadBestGrid()
        scoreHistory = PersistenceService.loadHistory()
    }

    var scoreText: String {
        isGameOver ? "Partie terminee: \(grid.score)" : "Score: \(grid.score)"
    }

    var isGameOver: Bool {
        grid.possibleLinesAroundExistingPoints().isEmpty
    }

    var hintLines: [MoveLine] {
        showHints ? grid.possibleLinesAroundExistingPoints() : []
    }

    func resetGame() {
        stopComputerIfNeeded()
        grid.reset(mode: mode)
        lineChoices = []
        elapsedTime = 0
    }

    func toggleHints() {
        showHints.toggle()
    }

    func undo() {
        stopComputerIfNeeded()
        grid.undoLastLine()
    }

    func handleBoardTap(_ coordinate: GridCoordinate) {
        guard !isComputerRunning else { return }

        let possible = grid.possibleLines(at: coordinate)
        switch possible.count {
        case 0:
            return
        case 1:
            applyMove(possible[0])
            checkGameOverAndPersist()
        default:
            lineChoices = possible
        }
    }

    func chooseLine(_ line: MoveLine) {
        lineChoices = []
        applyMove(line)
        checkGameOverAndPersist()
    }

    func toggleComputerSimulation() {
        if isComputerRunning {
            stopComputerIfNeeded()
            return
        }

        isComputerRunning = true
        simulationStartDate = Date()
        startTimer()

        simulationTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                // Lecture de l'état sur le MainActor
                let (snapshot, computerType, isRunning) = await MainActor.run {
                    (self.grid, self.computer, self.isComputerRunning)
                }
                guard isRunning else { break }

                // Calcul du prochain coup sur le thread courant (background)
                let algo = JoinFiveViewModel.buildAlgorithm(for: computerType)
                let next = algo.nextMove(on: snapshot)

                // Mise à jour de l'état sur le MainActor
                let shouldContinue = await MainActor.run { () -> Bool in
                    guard self.isComputerRunning else { return false }
                    guard let line = next else {
                        self.stopComputerIfNeeded()
                        self.persistGameResult()
                        return false
                    }
                    self.applyMove(line)
                    return true
                }
                if !shouldContinue { break }
            }
        }
    }

    func stopComputerIfNeeded() {
        isComputerRunning = false
        simulationTask?.cancel()
        simulationTask = nil
        timerTask?.cancel()
        timerTask = nil
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if let start = self.simulationStartDate {
                    self.elapsedTime = Date().timeIntervalSince(start)
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func applyMove(_ line: MoveLine) {
        grid.addLine(line)
        bestSessionScore = max(bestSessionScore, grid.score)
    }

    private func checkGameOverAndPersist() {
        guard isGameOver else { return }
        persistGameResult()
    }

    private func persistGameResult() {
        let entry = ScoreEntry(
            playerName: playerName.isEmpty ? "Anonyme" : playerName,
            score: grid.score,
            mode: mode,
            date: Date()
        )
        PersistenceService.appendScore(entry)
        scoreHistory = PersistenceService.loadHistory()

        if grid.score > (bestGrid?.score ?? -1) {
            PersistenceService.saveBestGrid(grid)
            bestGrid = grid
        }
    }

    private func makeAlgorithm() -> any JoinFiveAlgorithm {
        JoinFiveViewModel.buildAlgorithm(for: computer)
    }

    nonisolated static func buildAlgorithm(for computer: ComputerType) -> any JoinFiveAlgorithm {
        switch computer {
        case .random: return RandomSearchAlgorithm()
        case .nmcs:   return NMCSAlgorithm()
        case .nrpa:   return NRPAAlgorithm()
        }
    }
}

private struct JoinFiveBoardView: View {
    let grid: GridState
    let hintLines: [MoveLine]
    let onTap: (GridCoordinate) -> Void

    private let cellSize: CGFloat = 50
    private let offset: CGFloat = 50
    private let tolerance: CGFloat = 0.25

    var body: some View {
        let boardWidth = offset * 2 + CGFloat(grid.width - 1) * cellSize
        let boardHeight = offset * 2 + CGFloat(grid.height - 1) * cellSize

        Canvas { context, size in
            drawBoard(context: &context, size: size)
        }
        .frame(width: boardWidth, height: boardHeight)
        .background(Color(red: 0.25, green: 0.26, blue: 0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { gesture in
                    if let coord = coordinate(from: gesture.location) {
                        onTap(coord)
                    }
                }
        )
    }

    private func coordinate(from location: CGPoint) -> GridCoordinate? {
        let rawX = (location.x - offset) / cellSize
        let rawY = (location.y - offset) / cellSize

        let roundedX = rawX.rounded()
        let roundedY = rawY.rounded()

        if abs(rawX - roundedX) > tolerance || abs(rawY - roundedY) > tolerance {
            return nil
        }

        let coord = GridCoordinate(x: Int(roundedX), y: Int(roundedY))
        return grid.isValid(coord) ? coord : nil
    }

    private func drawBoard(context: inout GraphicsContext, size: CGSize) {
        for x in 0..<grid.width {
            let xPos = offset + CGFloat(x) * cellSize
            var path = Path()
            path.move(to: CGPoint(x: xPos, y: offset))
            path.addLine(to: CGPoint(x: xPos, y: offset + CGFloat(grid.height - 1) * cellSize))
            context.stroke(path, with: .color(Color.white.opacity(0.15)), lineWidth: 1)
        }

        for y in 0..<grid.height {
            let yPos = offset + CGFloat(y) * cellSize
            var path = Path()
            path.move(to: CGPoint(x: offset, y: yPos))
            path.addLine(to: CGPoint(x: offset + CGFloat(grid.width - 1) * cellSize, y: yPos))
            context.stroke(path, with: .color(Color.white.opacity(0.15)), lineWidth: 1)
        }

        for line in hintLines {
            draw(line: line, color: .yellow.opacity(0.4), lineWidth: 1.5, context: &context)
        }

        for line in grid.lines {
            draw(line: line, color: .orange, lineWidth: 2.5, context: &context)
        }

        for point in grid.points {
            let center = CGPoint(x: offset + CGFloat(point.x) * cellSize, y: offset + CGFloat(point.y) * cellSize)
            let rect = CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
        }

        for line in grid.lines {
            if let number = line.number {
                drawNumber(number, at: line.newPoint, context: &context)
            }
        }
    }

    private func draw(line: MoveLine, color: Color, lineWidth: CGFloat, context: inout GraphicsContext) {
        guard let first = line.points.first, let last = line.points.last else { return }
        var path = Path()
        path.move(to: CGPoint(x: offset + CGFloat(first.x) * cellSize, y: offset + CGFloat(first.y) * cellSize))
        path.addLine(to: CGPoint(x: offset + CGFloat(last.x) * cellSize, y: offset + CGFloat(last.y) * cellSize))
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private func drawNumber(_ number: Int, at point: GridCoordinate, context: inout GraphicsContext) {
        let center = CGPoint(x: offset + CGFloat(point.x) * cellSize, y: offset + CGFloat(point.y) * cellSize)
        let radius: CGFloat = 14
        let bubble = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        context.fill(Path(ellipseIn: bubble), with: .color(.black.opacity(0.85)))
        context.draw(
            Text("\(number)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white),
            at: center
        )
    }
}

struct ContentView: View {
    @StateObject private var viewModel = JoinFiveViewModel()

    private var elapsedLabel: String {
        let total = Int(viewModel.elapsedTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(viewModel.scoreText)
                    .font(.title3.weight(.bold))
                Spacer()
                Text("Temps: \(elapsedLabel)")
                    .font(.title3.monospacedDigit())
                Spacer()
                Text("Best session: \(viewModel.bestSessionScore)")
                    .font(.title3.weight(.semibold))
            }

            HStack(spacing: 12) {
                TextField("Nom", text: $viewModel.playerName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)

                Picker("Joueur", selection: $viewModel.player) {
                    ForEach(JoinFiveViewModel.PlayerType.allCases) { player in
                        Text(player.rawValue).tag(player)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(GameMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(width: 90)
                .onChange(of: viewModel.mode) { _, _ in
                    viewModel.resetGame()
                }

                Picker("Algo", selection: $viewModel.computer) {
                    ForEach(JoinFiveViewModel.ComputerType.allCases) { algo in
                        Text(algo.rawValue).tag(algo)
                    }
                }
                .frame(width: 170)
                .disabled(viewModel.player == .human)

                Button(viewModel.isComputerRunning ? "Stop" : "Simuler") {
                    viewModel.toggleComputerSimulation()
                }
                .disabled(viewModel.player == .human && !viewModel.isComputerRunning)

                Button("Undo") {
                    viewModel.undo()
                }
                .disabled(viewModel.grid.lines.isEmpty || viewModel.isComputerRunning)

                Button(viewModel.showHints ? "Masquer hint" : "Afficher hint") {
                    viewModel.toggleHints()
                }

                Button("Reset") {
                    viewModel.resetGame()
                }

                Button("Meilleur") {
                    viewModel.showBestGrid = true
                }
                .disabled(viewModel.bestGrid == nil)

                Button("Historique") {
                    viewModel.showHistory = true
                }
                .disabled(viewModel.scoreHistory.isEmpty)
            }

            ScrollView([.horizontal, .vertical]) {
                JoinFiveBoardView(grid: viewModel.grid, hintLines: viewModel.hintLines) { coordinate in
                    viewModel.handleBoardTap(coordinate)
                }
                .padding(8)
            }
            .background(Color.black.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .sheet(isPresented: Binding(
            get: { !viewModel.lineChoices.isEmpty },
            set: { isPresented in
                if !isPresented {
                    viewModel.lineChoices = []
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Plusieurs lignes possibles")
                    .font(.headline)
                ForEach(viewModel.lineChoices) { line in
                    let start = line.points.first ?? line.newPoint
                    let end = line.points.last ?? line.newPoint
                    Button {
                        viewModel.chooseLine(line)
                    } label: {
                        Text("\(line.direction.shortLabel) - [\(start.x),\(start.y)] -> [\(end.x),\(end.y)]")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Annuler") {
                    viewModel.lineChoices = []
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .frame(minWidth: 340)
        }
        // Feuille meilleure grille
        .sheet(isPresented: $viewModel.showBestGrid) {
            if let best = viewModel.bestGrid {
                VStack(spacing: 12) {
                    Text("Meilleure grille — Score : \(best.score)")
                        .font(.title2.weight(.bold))
                    ScrollView([.horizontal, .vertical]) {
                        JoinFiveBoardView(grid: best, hintLines: []) { _ in }
                            .padding(8)
                    }
                    Button("Fermer") { viewModel.showBestGrid = false }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(minWidth: 600, minHeight: 500)
            }
        }
        // Feuille historique
        .sheet(isPresented: $viewModel.showHistory) {
            VStack(spacing: 12) {
                Text("Historique des scores")
                    .font(.title2.weight(.bold))
                Table(viewModel.scoreHistory) {
                    TableColumn("Joueur", value: \.playerName)
                    TableColumn("Score") { entry in
                        Text("\(entry.score)")
                    }
                    TableColumn("Mode", value: \.mode.rawValue)
                    TableColumn("Date") { entry in
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .frame(minHeight: 300)
                Button("Fermer") { viewModel.showHistory = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(minWidth: 600, minHeight: 400)
        }
    }
}

#Preview {
    ContentView()
}
