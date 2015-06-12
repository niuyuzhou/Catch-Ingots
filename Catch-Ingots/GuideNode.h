//
//  GuideNode.h
//  Catch-Ingots
//
//  Created by niuyuzhou on 17/02/2015.
//  Copyright (c) 2015 YuzhouNiu. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

typedef void (^AnonBlock)();

@interface GuideNode : SKSpriteNode
-(id) initWithTitleTexture:(SKTexture *)titleTexture andIndicatorTexture:(SKTexture *)indicatorTexture;
-(void) setMethod:(void (^)()) returnMethod;
-(void) runMethod;
@end
