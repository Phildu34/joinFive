#import "NRPABridge.h"
#include "NRPAAlgorithm.hpp"

using namespace JoinFive;

@implementation NRPABridge

+ (NSDictionary *)nextMoveWithLegalMoves:(NSArray *)legalMovesArray
                         occupiedPoints:(NSArray *)occupiedPointsArray
                              maxDuration:(NSInteger)ms
                                 maxSteps:(NSInteger)maxSteps
                                    level:(NSInteger)level
                      iterationsPerLevel:(NSInteger)iterationsPerLevel
                                    alpha:(double)alpha {
    
    // Convertir NSArray en vecteur C++ de Move
    std::vector<Move> moves;
    
    for (NSDictionary *moveDict in legalMovesArray) {
        Move m;
        m.startX = [moveDict[@"startX"] intValue];
        m.startY = [moveDict[@"startY"] intValue];
        m.endX = [moveDict[@"endX"] intValue];
        m.endY = [moveDict[@"endY"] intValue];
        m.newX = [moveDict[@"newX"] intValue];
        m.newY = [moveDict[@"newY"] intValue];
        m.direction = [moveDict[@"direction"] intValue];
        m.moveNumber = [moveDict[@"moveNumber"] intValue];
        moves.push_back(m);
    }

    std::vector<OccupiedPoint> occupiedPoints;
    for (NSDictionary *pointDict in occupiedPointsArray) {
        OccupiedPoint p;
        p.x = [pointDict[@"x"] intValue];
        p.y = [pointDict[@"y"] intValue];
        occupiedPoints.push_back(p);
    }
    
    if (moves.empty()) {
        return nil;
    }
    
    // Appeler l'algorithme C++
    NRPAAlgorithm algo;
    Move result = algo.nextMove(moves,
                                occupiedPoints,
                                (int)ms,
                                (int)maxSteps,
                                (int)level,
                                (int)iterationsPerLevel,
                                alpha);
    
    bool foundInLegalMoves = false;
    for (const Move &candidate : moves) {
        if (candidate.startX == result.startX &&
            candidate.startY == result.startY &&
            candidate.endX == result.endX &&
            candidate.endY == result.endY &&
            candidate.newX == result.newX &&
            candidate.newY == result.newY &&
            candidate.direction == result.direction) {
            foundInLegalMoves = true;
            break;
        }
    }

    // Fallback défensif: si le moteur renvoie un coup non légal, reprendre le premier légal.
    if (!foundInLegalMoves && !moves.empty()) {
        const Move& first = moves[0];
        return @{
            @"startX": @(first.startX),
            @"startY": @(first.startY),
            @"endX": @(first.endX),
            @"endY": @(first.endY),
            @"newX": @(first.newX),
            @"newY": @(first.newY),
            @"direction": @(first.direction),
            @"moveNumber": @(first.moveNumber)
        };
    }
    
    // Convertir le résultat en NSDictionary
    return @{
        @"startX": @(result.startX),
        @"startY": @(result.startY),
        @"endX": @(result.endX),
        @"endY": @(result.endY),
        @"newX": @(result.newX),
        @"newY": @(result.newY),
        @"direction": @(result.direction),
        @"moveNumber": @(result.moveNumber)
    };
}

@end
