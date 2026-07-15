#ifndef NRPA_BRIDGE_H
#define NRPA_BRIDGE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRPABridge : NSObject

// Appelle NRPA en C++ et retourne le meilleur coup trouvé
// legalMovesArray: array de dictionnaires avec {startX, startY, endX, endY, newX, newY, direction, moveNumber}
// maxDuration: durée max en millisecondes
+ (nullable NSDictionary *)nextMoveWithLegalMoves:(NSArray<NSDictionary *> *)legalMovesArray
                                       maxDuration:(NSInteger)ms
                                          maxSteps:(NSInteger)maxSteps;

@end

NS_ASSUME_NONNULL_END

#endif
