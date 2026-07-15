#ifndef NRPA_ALGORITHM_HPP
#define NRPA_ALGORITHM_HPP

#include <vector>
#include <unordered_map>
#include <string>
#include <cmath>
#include <random>
#include <chrono>

namespace JoinFive {

// Représentation d'une action (coup)
struct Move {
    int startX, startY;
    int endX, endY;
    int newX, newY;
    int direction; // 0=H, 1=V, 2=Fall, 3=Rise
    int moveNumber;

    Move()
        : startX(0), startY(0), endX(0), endY(0),
          newX(0), newY(0), direction(0), moveNumber(0) {}

    Move(int sX, int sY, int eX, int eY, int nX, int nY, int dir, int num)
        : startX(sX), startY(sY), endX(eX), endY(eY),
          newX(nX), newY(nY), direction(dir), moveNumber(num) {}

    std::string id() const {
        return std::to_string(startX) + "," + std::to_string(startY) + "-" +
               std::to_string(endX) + "," + std::to_string(endY) + "-" +
               std::to_string(newX) + "," + std::to_string(newY) + "-" +
               std::to_string(direction);
    }

    bool operator==(const Move& other) const {
        return startX == other.startX && startY == other.startY &&
               endX == other.endX && endY == other.endY &&
               newX == other.newX && newY == other.newY &&
               direction == other.direction;
    }
};

// Point déjà occupé dans la grille courante.
struct OccupiedPoint {
    int x;
    int y;
    int lockMask = 0; // bit i => direction i déjà verrouillée sur ce point
};

// Politique avec poids
class Policy {
private:
    std::unordered_map<std::string, double> weights;

public:
    double weight(const Move& move) const {
        auto it = weights.find(move.id());
        return it != weights.end() ? it->second : 0.0;
    }

    void adjust(const Move& move, double value) {
        weights[move.id()] += value;
    }

    Policy copy() const {
        Policy p;
        p.weights = this->weights;
        return p;
    }
};

// Résultat d'un rollout
struct PlayoutResult {
    int score;
    std::vector<Move> sequence;
};

// NRPA Algorithm
class NRPAAlgorithm {
public:
    // Trouvé le prochain meilleur coup
    // grid: état sérialisé (voir plus bas)
    // legalMoves: tous les coups légaux à partir de l'état courant
    // maxDuration: durée max en millisecondes
    // maxSteps: nombre max de coups simulés par playout
    Move nextMove(const std::vector<Move>& legalMoves,
                  const std::vector<OccupiedPoint>& occupiedPoints,
                  int gridWidth,
                  int gridHeight,
                  int maxLocksPerLine,
                  int maxDuration = 2000,
                  int maxSteps = 200,
                  int level = 2,
                  int iterationsPerLevel = 8,
                  double alpha = 0.5);

private:
    struct SearchContext {
        const std::vector<Move>& legalMoves;
        const std::vector<OccupiedPoint>& occupiedPoints;
        int gridWidth;
        int gridHeight;
        int maxLocksPerLine;
        int maxSteps;
        int iterationsPerLevel;
        double alpha;
        std::chrono::steady_clock::time_point deadline;
    };

    std::mt19937 rng{std::random_device{}()};

    // Simule une partie complète (niveau 0 de NRPA).
    PlayoutResult playout(const std::vector<Move>& legalMoves,
                         const std::vector<OccupiedPoint>& occupiedPoints,
                         const Policy& policy,
                         int gridWidth,
                         int gridHeight,
                         int maxLocksPerLine,
                         int maxSteps,
                         std::chrono::steady_clock::time_point deadline);

    // NRPA récursif multi-niveaux.
    PlayoutResult nrpa(int level,
                       const Policy& policy,
                       const SearchContext& context);

    // Sélectionne une action selon la politique softmax
    Move selectAction(const std::vector<Move>& legalMoves, const Policy& policy);

    // Adapte la politique après une bonne séquence en tenant compte
    // de tous les coups légaux encore disponibles à chaque ply.
    Policy adapt(const Policy& policy,
                 const std::vector<Move>& sequence,
                 const std::vector<Move>& allLegalMoves,
                 const std::vector<OccupiedPoint>& occupiedPoints,
                 int gridWidth,
                 int gridHeight,
                 int maxLocksPerLine,
                 double alpha);
};

} // namespace JoinFive

#endif
