#include "NRPAAlgorithm.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <string>
#include <set>
#include <unordered_set>
#include <vector>

namespace JoinFive {

namespace {
constexpr int kDirectionCount = 4;

std::pair<int, int> deltaForDirection(int direction) {
    switch (direction) {
    case 0:
        return {1, 0};
    case 1:
        return {0, 1};
    case 2:
        return {1, 1};
    case 3:
        return {1, -1};
    default:
        return {0, 0};
    }
}

struct SimpleGrid {
    std::set<std::pair<int, int>> points;
    std::map<std::pair<int, int>, int> lockMasks;
    int score = 0;

    bool isOccupied(int x, int y) const {
        return points.count({x, y}) > 0;
    }

    bool isLocked(int x, int y, int direction) const {
        auto it = lockMasks.find({x, y});
        if (it == lockMasks.end()) {
            return false;
        }
        const int bit = 1 << direction;
        return (it->second & bit) != 0;
    }

    void lockDirection(int x, int y, int direction) {
        lockMasks[{x, y}] |= (1 << direction);
    }

    bool inBounds(int x, int y, int width, int height) const {
        return x >= 0 && x < width && y >= 0 && y < height;
    }

    std::vector<std::pair<int, int>> linePoints(const Move& line) const {
        std::vector<std::pair<int, int>> result;
        result.reserve(5);
        const auto delta = deltaForDirection(line.direction);
        if (delta.first == 0 && delta.second == 0) {
            return result;
        }

        for (int i = 0; i < 5; ++i) {
            result.push_back({line.startX + delta.first * i, line.startY + delta.second * i});
        }

        return result;
    }

    bool isMoveLegal(const Move& move, int width, int height, int maxLocksPerLine) const {
        if (isOccupied(move.newX, move.newY)) {
            return false;
        }

        const auto pointsOnLine = linePoints(move);
        if (pointsOnLine.size() != 5) {
            return false;
        }

        int remainingLocks = std::max(0, maxLocksPerLine);
        bool containsNewPoint = false;

        for (const auto& p : pointsOnLine) {
            if (!inBounds(p.first, p.second, width, height)) {
                return false;
            }

            if (p.first == move.newX && p.second == move.newY) {
                containsNewPoint = true;
                continue;
            }

            if (!isOccupied(p.first, p.second)) {
                return false;
            }

            if (isLocked(p.first, p.second, move.direction)) {
                if (remainingLocks <= 0) {
                    return false;
                }
                remainingLocks--;
            }
        }

        return containsNewPoint;
    }

    void addLine(const Move& line) {
        const auto pointsOnLine = linePoints(line);
        for (const auto& p : pointsOnLine) {
            points.insert(p);
            lockDirection(p.first, p.second, line.direction);
        }
        score++;
    }
};

std::vector<Move> generateLegalMoves(const SimpleGrid& grid,
                                     int gridWidth,
                                     int gridHeight,
                                     int maxLocksPerLine) {
    std::set<std::pair<int, int>> candidateCells;

    for (const auto& point : grid.points) {
        for (int dx = -1; dx <= 1; ++dx) {
            for (int dy = -1; dy <= 1; ++dy) {
                if (dx == 0 && dy == 0) {
                    continue;
                }

                const int nx = point.first + dx;
                const int ny = point.second + dy;
                if (!grid.inBounds(nx, ny, gridWidth, gridHeight)) {
                    continue;
                }
                if (!grid.isOccupied(nx, ny)) {
                    candidateCells.insert({nx, ny});
                }
            }
        }
    }

    std::vector<Move> result;
    std::unordered_set<std::string> seen;

    for (const auto& candidate : candidateCells) {
        for (int direction = 0; direction < kDirectionCount; ++direction) {
            const auto delta = deltaForDirection(direction);

            for (int i = -4; i <= 0; ++i) {
                int remainingLocks = std::max(0, maxLocksPerLine);
                bool isValidLine = true;
                std::vector<std::pair<int, int>> linePoints;
                linePoints.reserve(5);

                for (int j = 0; j < 5; ++j) {
                    const int x = candidate.first + delta.first * (i + j);
                    const int y = candidate.second + delta.second * (i + j);

                    if (!grid.inBounds(x, y, gridWidth, gridHeight)) {
                        isValidLine = false;
                        break;
                    }

                    if (x == candidate.first && y == candidate.second) {
                        linePoints.push_back({x, y});
                        continue;
                    }

                    if (!grid.isOccupied(x, y)) {
                        isValidLine = false;
                        break;
                    }

                    if (grid.isLocked(x, y, direction)) {
                        if (remainingLocks <= 0) {
                            isValidLine = false;
                            break;
                        }
                        remainingLocks--;
                    }

                    linePoints.push_back({x, y});
                }

                if (!isValidLine || linePoints.size() != 5) {
                    continue;
                }

                Move move(linePoints.front().first,
                          linePoints.front().second,
                          linePoints.back().first,
                          linePoints.back().second,
                          candidate.first,
                          candidate.second,
                          direction,
                          0);

                if (!grid.isMoveLegal(move, gridWidth, gridHeight, maxLocksPerLine)) {
                    continue;
                }

                const std::string key = move.id();
                if (seen.insert(key).second) {
                    result.push_back(move);
                }
            }
        }
    }

    return result;
}

std::vector<Move> filterLegalMoves(const std::vector<Move>& moves,
                                   const SimpleGrid& grid,
                                   int gridWidth,
                                   int gridHeight,
                                   int maxLocksPerLine) {
    std::vector<Move> filtered;
    filtered.reserve(moves.size());
    for (const auto& move : moves) {
        if (grid.isMoveLegal(move, gridWidth, gridHeight, maxLocksPerLine)) {
            filtered.push_back(move);
        }
    }
    return filtered;
}
} // namespace

Move NRPAAlgorithm::nextMove(const std::vector<Move>& legalMoves,
                             const std::vector<OccupiedPoint>& occupiedPoints,
                             int gridWidth,
                             int gridHeight,
                             int maxLocksPerLine,
                             int maxDuration,
                             int maxSteps,
                             int level,
                             int iterationsPerLevel,
                             double alpha) {
    if (legalMoves.empty()) {
        return Move();
    }

    if (maxDuration < 1) {
        maxDuration = 1;
    }
    if (maxSteps < 1) {
        maxSteps = 1;
    }
    if (level < 0) {
        level = 0;
    }
    if (iterationsPerLevel < 1) {
        iterationsPerLevel = 1;
    }
    if (alpha <= 0.0) {
        alpha = 0.01;
    }
    if (gridWidth < 1) {
        gridWidth = 1;
    }
    if (gridHeight < 1) {
        gridHeight = 1;
    }
    if (maxLocksPerLine < 0) {
        maxLocksPerLine = 0;
    }

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(maxDuration);
    SearchContext context{legalMoves,
                          occupiedPoints,
                          gridWidth,
                          gridHeight,
                          maxLocksPerLine,
                          maxSteps,
                          iterationsPerLevel,
                          alpha,
                          deadline};

    Policy initialPolicy;
    PlayoutResult result = nrpa(level, initialPolicy, context);

    if (!result.sequence.empty()) {
        return result.sequence.front();
    }

    return legalMoves.front();
}

PlayoutResult NRPAAlgorithm::playout(const std::vector<Move>& allLegalMoves,
                                     const std::vector<OccupiedPoint>& occupiedPoints,
                                     const Policy& policy,
                                     int gridWidth,
                                     int gridHeight,
                                     int maxLocksPerLine,
                                     int maxSteps,
                                     std::chrono::steady_clock::time_point deadline) {
    std::vector<Move> sequence;
    SimpleGrid grid;

    // État initial explicite: toutes les cases déjà occupées dans la grille courante.
    for (const auto& point : occupiedPoints) {
        grid.points.insert({point.x, point.y});
        if (point.lockMask != 0) {
            grid.lockMasks[{point.x, point.y}] = point.lockMask;
        }
    }

    auto legalNow = filterLegalMoves(allLegalMoves, grid, gridWidth, gridHeight, maxLocksPerLine);

    for (int step = 0; step < maxSteps; ++step) {
        if (std::chrono::steady_clock::now() >= deadline) {
            break;
        }

        if (legalNow.empty()) {
            break;
        }

        Move selected = selectAction(legalNow, policy);
        sequence.push_back(selected);
        grid.addLine(selected);

        legalNow = generateLegalMoves(grid, gridWidth, gridHeight, maxLocksPerLine);
    }

    return PlayoutResult{grid.score, sequence};
}

PlayoutResult NRPAAlgorithm::nrpa(int level,
                                  const Policy& policy,
                                  const SearchContext& context) {
    if (std::chrono::steady_clock::now() >= context.deadline) {
        return PlayoutResult{-1, {}};
    }

    if (level <= 0) {
        return playout(context.legalMoves,
                       context.occupiedPoints,
                       policy,
                       context.gridWidth,
                       context.gridHeight,
                       context.maxLocksPerLine,
                       context.maxSteps,
                       context.deadline);
    }

    Policy currentPolicy = policy.copy();
    PlayoutResult bestResult{-1, {}};

    for (int iteration = 0; iteration < context.iterationsPerLevel; ++iteration) {
        if (std::chrono::steady_clock::now() >= context.deadline) {
            break;
        }

        PlayoutResult candidate = nrpa(level - 1, currentPolicy, context);
        if (candidate.score > bestResult.score) {
            bestResult = candidate;
        }

        if (!bestResult.sequence.empty()) {
            currentPolicy = adapt(currentPolicy,
                                  bestResult.sequence,
                                  context.legalMoves,
                                  context.occupiedPoints,
                                  context.gridWidth,
                                  context.gridHeight,
                                  context.maxLocksPerLine,
                                  context.alpha);
        }
    }

    if (bestResult.score < 0) {
        return playout(context.legalMoves,
                       context.occupiedPoints,
                       currentPolicy,
                       context.gridWidth,
                       context.gridHeight,
                       context.maxLocksPerLine,
                       context.maxSteps,
                       context.deadline);
    }

    return bestResult;
}

Move NRPAAlgorithm::selectAction(const std::vector<Move>& legalMoves, const Policy& policy) {
    if (legalMoves.empty()) {
        return Move();
    }

    std::vector<double> cumulative;
    cumulative.reserve(legalMoves.size());

    double maxWeight = -std::numeric_limits<double>::infinity();
    for (const auto& move : legalMoves) {
        maxWeight = std::max(maxWeight, policy.weight(move));
    }

    double sum = 0.0;
    for (const auto& move : legalMoves) {
        sum += std::exp(policy.weight(move) - maxWeight);
        cumulative.push_back(sum);
    }

    if (sum <= 0.0) {
        std::uniform_int_distribution<size_t> dist(0, legalMoves.size() - 1);
        return legalMoves[dist(rng)];
    }

    std::uniform_real_distribution<double> dist(0.0, sum);
    const double r = dist(rng);

    for (size_t i = 0; i < cumulative.size(); ++i) {
        if (cumulative[i] >= r) {
            return legalMoves[i];
        }
    }

    return legalMoves.back();
}

Policy NRPAAlgorithm::adapt(const Policy& policy,
                            const std::vector<Move>& sequence,
                            const std::vector<Move>& allLegalMoves,
                            const std::vector<OccupiedPoint>& occupiedPoints,
                            int gridWidth,
                            int gridHeight,
                            int maxLocksPerLine,
                            double alpha) {
    Policy updated = policy.copy();

    SimpleGrid grid;
    for (const auto& point : occupiedPoints) {
        grid.points.insert({point.x, point.y});
        if (point.lockMask != 0) {
            grid.lockMasks[{point.x, point.y}] = point.lockMask;
        }
    }

    for (size_t step = 0; step < sequence.size(); ++step) {
        const Move& chosen = sequence[step];
        std::vector<Move> legalNow;
        if (step == 0) {
            legalNow = filterLegalMoves(allLegalMoves, grid, gridWidth, gridHeight, maxLocksPerLine);
        } else {
            legalNow = generateLegalMoves(grid, gridWidth, gridHeight, maxLocksPerLine);
        }

        if (legalNow.empty()) {
            break;
        }

        updated.adjust(chosen, alpha);

        // Le gradient softmax doit être calculé à partir de la politique
        // d'origine (pol dans l'article de Rosin), et non à partir de la
        // politique en cours de mise à jour (polp) : sinon le poids du coup
        // choisi, déjà incrémenté de alpha ci-dessus, biaise la distribution.
        double maxWeight = -std::numeric_limits<double>::infinity();
        for (const auto& move : legalNow) {
            maxWeight = std::max(maxWeight, policy.weight(move));
        }

        double z = 0.0;
        std::vector<double> expValues;
        expValues.reserve(legalNow.size());
        for (const auto& move : legalNow) {
            const double v = std::exp(policy.weight(move) - maxWeight);
            expValues.push_back(v);
            z += v;
        }

        if (z > 0.0) {
            for (size_t i = 0; i < legalNow.size(); ++i) {
                const double reduction = alpha * expValues[i] / z;
                const Move& move = legalNow[i];
                updated.adjust(move, -reduction);
            }
        }

        if (!grid.isMoveLegal(chosen, gridWidth, gridHeight, maxLocksPerLine)) {
            break;
        }
        grid.addLine(chosen);
    }

    return updated;
}

} // namespace JoinFive
