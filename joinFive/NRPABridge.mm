#import "NRPABridge.h"
#include "NRPAAlgorithm.hpp"

using namespace JoinFive;

@implementation NRPABridge

+ (NSDictionary *)nextMoveWithLegalMoves:(NSArray *)legalMovesArray
                              maxDuration:(NSInteger)ms
                                 maxSteps:(NSInteger)maxSteps {
    
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
    
    if (moves.empty()) {
        return nil;
    }
    
    // Appeler l'algorithme C++
    NRPAAlgorithm algo;
    Move result = algo.nextMove(moves, (int)ms, (int)maxSteps);
    
    // Vérifier que le résultat n'est pas un Move vide
    if (result.newX == 0 && result.newY == 0 && moves.size() > 0 &&
        !(moves[0].newX == 0 && moves[0].newY == 0)) {
        // Retourner le premier coup par défaut
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
