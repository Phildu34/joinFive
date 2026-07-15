#include "NRPAAlgorithm.hpp"

#include <cmath>
#include <set>
#include <vector>

namespace JoinFive {

namespace {
struct SimpleGrid {
    std::set<std::pair<int, int>> points;
    int score = 0;

    bool isOccupied(int x, int y) const {
        return points.count({x, y}) > 0;
    }

    void addLine(const Move& line) {
        points.insert({line.newX, line.newY});
        score++;
    }
};
} // namespace

Move NRPAAlgorithm::nextMove(const std::vector<Move>& legalMoves,
                             const std::vector<OccupiedPoint>& occupiedPoints,
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

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(maxDuration);
    SearchContext context{legalMoves, occupiedPoints, maxSteps, iterationsPerLevel, alpha, deadline};

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
                                     int maxSteps,
                                     std::chrono::steady_clock::time_point deadline) {
    std::vector<Move> sequence;
    SimpleGrid grid;

    // État initial explicite: toutes les cases déjà occupées dans la grille courante.
    for (const auto& point : occupiedPoints) {
        grid.points.insert({point.x, point.y});
    }

    for (int step = 0; step < maxSteps; ++step) {
        if (std::chrono::steady_clock::now() >= deadline) {
            break;
        }

        std::vector<Move> legalNow;
        legalNow.reserve(allLegalMoves.size());

        for (const auto& move : allLegalMoves) {
            if (!grid.isOccupied(move.newX, move.newY)) {
                legalNow.push_back(move);
            }
        }

        if (legalNow.empty()) {
            break;
        }

        Move selected = selectAction(legalNow, policy);
        sequence.push_back(selected);
        grid.addLine(selected);
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
                                  context.alpha);
        }
    }

    if (bestResult.score < 0) {
        return playout(context.legalMoves,
                       context.occupiedPoints,
                       currentPolicy,
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

    double sum = 0.0;
    for (const auto& move : legalMoves) {
        sum += std::exp(policy.weight(move));
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
                            double alpha) {
    Policy updated = policy.copy();

    // Approximation de légalité: newPoint non occupé.
    std::set<std::pair<int, int>> occupied;
    for (const auto& point : occupiedPoints) {
        occupied.insert({point.x, point.y});
    }

    for (const auto& chosen : sequence) {
        updated.adjust(chosen, alpha);

        std::vector<Move> legalNow;
        legalNow.reserve(allLegalMoves.size());
        for (const auto& move : allLegalMoves) {
            if (occupied.count({move.newX, move.newY}) == 0) {
                legalNow.push_back(move);
            }
        }

        double z = 0.0;
        for (const auto& move : legalNow) {
            z += std::exp(updated.weight(move));
        }

        if (z > 0.0) {
            for (const auto& move : legalNow) {
                const double reduction = alpha * std::exp(updated.weight(move)) / z;
                updated.adjust(move, -reduction);
            }
        }

        occupied.insert({chosen.newX, chosen.newY});
    }

    return updated;
}

} // namespace JoinFive
