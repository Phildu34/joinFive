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

Move NRPAAlgorithm::nextMove(const std::vector<Move>& legalMoves, int maxDuration, int maxSteps) {
    if (legalMoves.empty()) {
        return Move();
    }

    if (maxDuration < 1) {
        maxDuration = 1;
    }
    if (maxSteps < 1) {
        maxSteps = 1;
    }

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(maxDuration);
    Policy policy;

    int bestGlobalScore = -1;
    Move bestGlobalMove = legalMoves.front();

    while (std::chrono::steady_clock::now() < deadline) {
        int bestIterationScore = -1;
        std::vector<Move> bestIterationSequence;
        Move bestIterationMove = legalMoves.front();

        // Recherche explicite sur tous les coups légaux racine.
        for (const auto& rootMove : legalMoves) {
            if (std::chrono::steady_clock::now() >= deadline) {
                break;
            }

            PlayoutResult result = playout(legalMoves, policy, rootMove, maxSteps);
            if (result.score > bestIterationScore) {
                bestIterationScore = result.score;
                bestIterationSequence = result.sequence;
                bestIterationMove = rootMove;
            }
        }

        if (bestIterationScore >= 0 && !bestIterationSequence.empty()) {
            policy = adapt(policy, bestIterationSequence, legalMoves);
            if (bestIterationScore > bestGlobalScore) {
                bestGlobalScore = bestIterationScore;
                bestGlobalMove = bestIterationMove;
            }
        }
    }

    return bestGlobalMove;
}

PlayoutResult NRPAAlgorithm::playout(const std::vector<Move>& allLegalMoves,
                                     const Policy& policy,
                                     const Move& rootMove,
                                     int maxSteps) {
    std::vector<Move> sequence;
    SimpleGrid grid;

    // Seed minimal: points déjà présents.
    for (const auto& move : allLegalMoves) {
        if (move.moveNumber == 0) {
            grid.points.insert({move.newX, move.newY});
        }
    }

    // Coup racine forcé (on évalue chaque coup légal).
    if (!grid.isOccupied(rootMove.newX, rootMove.newY)) {
        sequence.push_back(rootMove);
        grid.addLine(rootMove);
    }

    for (int step = 0; step < maxSteps; ++step) {
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
                            const std::vector<Move>& allLegalMoves) {
    constexpr double alpha = 1.0;
    Policy updated = policy.copy();

    // Approximation de légalité: newPoint non occupé.
    std::set<std::pair<int, int>> occupied;
    for (const auto& move : allLegalMoves) {
        if (move.moveNumber == 0) {
            occupied.insert({move.newX, move.newY});
        }
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
            z += std::exp(policy.weight(move));
        }

        if (z > 0.0) {
            for (const auto& move : legalNow) {
                const double reduction = alpha * std::exp(policy.weight(move)) / z;
                updated.adjust(move, -reduction);
            }
        }

        occupied.insert({chosen.newX, chosen.newY});
    }

    return updated;
}

} // namespace JoinFive
