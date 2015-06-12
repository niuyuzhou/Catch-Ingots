//
//  CounterHandler.h
//  Catch-Ingots
//
//  Created by niuyuzhou on 13/02/2015.
//  Copyright (c) 2015 YuzhouNiu. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>
#import <Foundation/Foundation.h>

@interface CounterHandler : SKNode

-(CounterHandler *) initWithNumber:(NSInteger) initNumber;
-(void) setNumber:(NSInteger) number;
-(NSInteger) getNumber;

-(void) resetNumber;
-(void) increse;
-(void) decrese;

@end
