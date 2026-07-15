#include "NRPAAlgorithm.hpp"
#include <algorithm>
#include <cmath>

namespace JoinFive {

Move NRPAAlgorithm::nextMove(const std::vector<Move>& legalMoves, int maxDuration) {
    if (legalMoves.empty()) {
        return Move();
    }

    auto deadline = std::chrono::steady_clock::now() + std::chrono::milliseconds(maxDuration);
    Policy policy;
    int bestScore = 0;
    std::vector<Move> bestSequence;

    while (std::chrono::steady_clock::now() < deadline) {
        PlayoutResult result = playout(legalMoves, policy);
        
        if (result.score >= bestScore) {
            bestScore = result.score;
            bestSequence = result.sequence;
            policy = adapt(policy, bestSequence);
        }
    }

    if (bestSequence.empty()) {
        return legalMoves[0];
    }
    return bestSequence[0];
}

PlayoutResult NRPAAlgorithm::playout(const std::vector<Move>& initialMoves, const Policy& policy) {
    // Simplification : on simule seulement avec les premiers coups légaux
    // Dans la réalité, il faudrait mettre à jour la grille après chaque coup
    // Pour ce prototype, on utilise initialMoves comme référence
    
    std::vector<Move> sequence;
    std::vector<Move> remaining = initialMoves;
    
    while (!remaining.empty()) {
        Move selected = selectAction(remaining, policy);
        sequence.push_back(selected);
        
        // Simpler: réduire les coups restants (dans la vraie implémentation,
        // on recalculerait basé sur la grille)
        remaining.erase(
            std::find_if(remaining.begin(), remaining.end(),
                        [&selected](const Move& m) { return m == selected; })
        );
    }
    
    PlayoutResult result;
    result.score = sequence.size(); // score = nombre de coups joués
    result.sequence = sequence;
    return result;
}

Move NRPAAlgorithm::selectAction(const std::vector<Move>& legalMoves, const Policy& policy) {
    if (legalMoves.empty()) {
        return Move();
    }

    // Calcul des poids exponentiels cumulés (softmax)
    std::vector<double> cumulative;
    cumulative.reserve(legalMoves.size());
    double sum = 0.0;

    for (const auto& move : legalMoves) {
        double weight = std::exp(policy.weight(move));
        sum += weight;
        cumulative.push_back(sum);
    }

    if (sum <= 0.0) {
        std::uniform_int_distribution<size_t> dist(0, legalMoves.size() - 1);
        return legalMoves[dist(rng)];
    }

    // Tirage aléatoire pondéré
    std::uniform_real_distribution<double> dist(0.0, sum);
    double randomValue = dist(rng);

    for (size_t i = 0; i < cumulative.size(); ++i) {
        if (cumulative[i] >= randomValue) {
            return legalMoves[i];
        }
    }

    return legalMoves[legalMoves.size() - 1];
}

Policy NRPAAlgorithm::adapt(const Policy& policy, const std::vector<Move>& sequence) {
    const double alpha = 1.0;
    Policy updated = policy.copy();

    for (const auto& chosen : sequence) {
        updated.adjust(chosen, alpha);

        // Calcul de la normalisation (z = somme des exp(weights))
        double z = 0.0;
        // Note: on devrait avoir tous les coups légaux ici pour la vraie adaptation
        // Pour simplifier, on utilise juste le poids du coup choisi
        z = std::exp(policy.weight(chosen));

        if (z > 0.0) {
            double reduction = alpha * std::exp(policy.weight(chosen)) / z;
            updated.adjust(chosen, -reduction);
        }
    }

    return updated;
}

} // namespace JoinFive
