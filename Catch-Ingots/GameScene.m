//
//  GameScene.m
//  Catch-Ingots
//
//  Created by niuyuzhou on 12/02/2015.
//  Copyright (c) 2015 YuzhouNiu. All rights reserved.
//

#import "ViewController.h"
#import "GameScene.h"
#import "HomeScene.h"
#import "CounterHandler.h"
#import "PlayerNode.h"
#import "ButtonNode.h"
#import "GuideNode.h"
#import "SSKeychain.h"

static const uint32_t goldCategory     =  0x1 << 0;
static const uint32_t pandaCategory    =  0x1 << 1;

static const uint8_t MAX_LOST_INGOTS   =  5;

@interface GameScene()  <SKPhysicsContactDelegate>
@property (nonatomic) NSDate * startTime;
@property (nonatomic) NSTimeInterval lastSpawnTimeInterval;
@property (nonatomic) NSTimeInterval lastUpdateTimeInterval;
@property (nonatomic) SKTextureAtlas * atlas;
@end

@implementation GameScene
{
    CounterHandler * _counter;
    CounterHandler * _lifeCounter;
    NSArray        * _waterDroppingFrames;
    PlayerNode     * _player;
    SKSpriteNode   * _ground;
    SKSpriteNode   * _score;
    SKSpriteNode   * _life;
    GuideNode      * _guide;
    
    int _goldCount;
    int _goldDisappearCount;
    int _catchCount;
    BOOL _golddrop;
}

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        // hold golddrop first
        _golddrop = NO;
        
        self.backgroundColor = [SKColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
        self.physicsWorld.gravity = CGVectorMake(0, 0);
        self.physicsWorld.contactDelegate = self;
        
        self.atlas = [SKTextureAtlas atlasNamed:@"sprite"];
        
        // set background
        SKSpriteNode * background = [SKSpriteNode spriteNodeWithTexture:[self.atlas textureNamed:@"background"]];
        background.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
        [self addChild: background];
        
        // set cloud
        SKSpriteNode * cloudDark = [SKSpriteNode spriteNodeWithTexture:[self.atlas textureNamed:@"cloud-dark"]];
        SKSpriteNode * cloudBright = [SKSpriteNode spriteNodeWithTexture:[self.atlas textureNamed:@"cloud-bright"]];
        cloudDark.anchorPoint = CGPointMake(0.5, 1.0);
        cloudBright.anchorPoint = CGPointMake(0.5, 1.0);
        cloudDark.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMaxY(self.frame));
        cloudBright.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMaxY(self.frame));
        [self addChild:cloudBright];
        [self addChild:cloudDark];
        
        
        SKAction * cloudMoveUpDown = [SKAction repeatActionForever:
                                         [SKAction sequence:@[
                                                              [SKAction moveByX:0.0 y:30.0 duration:2.5],
                                                              [SKAction moveByX:0.0 y:-30.0 duration:2.5]
                                                           ]]];
        SKAction * cloudMoveLeftRight = [SKAction repeatActionForever:
                                         [SKAction sequence:@[
                                                              [SKAction moveByX:30.0 y:0.0 duration:3.0],
                                                              [SKAction moveByX:-30.0 y:0.0 duration:3.0]
                                                           ]]];

        [cloudBright runAction:cloudMoveUpDown];
        [cloudDark   runAction:cloudMoveLeftRight];
        
        // set ground
        SKSpriteNode * ground = [SKSpriteNode spriteNodeWithTexture:[self.atlas textureNamed:@"ground"]];
        ground.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMinY(self.frame) - ground.size.height / 4);
        ground.anchorPoint = CGPointMake(0.5, 0.0);
        [self addChild:ground];
        
        _ground = ground;
        
        // set Panda Player
        NSMutableArray * _pandaAnimateTextures = [[NSMutableArray alloc] init];
        
        for (int i = 1; i <= 7; i++) {
            NSString * textureName = [NSString stringWithFormat:@"panda-walk-%d", i];
            SKTexture * texture = [self.atlas textureNamed:textureName];
            [_pandaAnimateTextures addObject:texture];
        }
        
        SKTexture * pandaTexture = [self.atlas textureNamed:@"panda-stop"];
        PlayerNode * player = [[PlayerNode alloc] initWithDefaultTexture:pandaTexture andAnimateTextures:_pandaAnimateTextures];
        
        [player setEndedTexture:[self.atlas textureNamed:@"panda-end"]];
 //       [player setEndedAdditionalTexture:[self.atlas textureNamed:@"wet"]];
        
        player.position = CGPointMake(CGRectGetMidX(self.frame), ground.position.y + ground.size.height + pandaTexture.size.height / 2 - 15.0);
        [player setPhysicsBodyCategoryMask:pandaCategory andContactMask:goldCategory];
        [self addChild: player];
        _player = player;
        
        // set Rain Sprite
        NSMutableArray * _goldTextures = [[NSMutableArray alloc] init];
        
        for (int i = 1; i <= 4; i++) {
            NSString * textureName = [NSString stringWithFormat:@"gold-%d", i];
            SKTexture * texture = [self.atlas textureNamed:textureName];
            [_goldTextures addObject:texture];
        }
        
        _waterDroppingFrames = [[NSArray alloc] initWithArray: _goldTextures];
        
        
        // add Guide
        GuideNode * guide = [[GuideNode alloc] initWithTitleTexture:[_atlas textureNamed:@"text-swipe"]
                                                andIndicatorTexture:[_atlas textureNamed:@"finger"]];
        guide.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
        [guide setMethod:^{
            [self gameStart];
        }];
        [self addChild:guide];
        
        _guide = guide;
        
    }
    return self;
}

-(void) gameStart {
    
    _goldCount = 0;
    _goldDisappearCount = 0;
    _catchCount = 0;
    
    // set count
    SKSpriteNode * score = [SKSpriteNode spriteNodeWithTexture:[_atlas textureNamed:@"score"]];
    score.position = CGPointMake(CGRectGetMidX(self.frame),  _ground.position.y + _ground.size.height * 4 / 4 - 47.0);

    score.alpha = 0.0;
    [self addChild:score];
    
    _score = score;

    CounterHandler * counter = [[CounterHandler alloc] init];
    counter.position = CGPointMake(CGRectGetMidX(self.frame) + 105.0, _ground.position.y + _ground.size.height * 4 / 4 - 65.0);

    counter.alpha = 0.0;
    [self addChild:counter];
    
    _counter = counter;
    
    
    // set count
    SKSpriteNode * life = [SKSpriteNode spriteNodeWithTexture:[_atlas textureNamed:@"lifevalue"]];
    life.position = CGPointMake(CGRectGetMidX(self.frame),  _ground.position.y + _ground.size.height * 3 / 4 - 37.0);

    life.alpha = 0.0;
    [self addChild:life];
    
    _life = life;
    
    CounterHandler * lifeCounter = [[CounterHandler alloc] init];
    lifeCounter.position = CGPointMake(CGRectGetMidX(self.frame) + 105.0, _ground.position.y + _ground.size.height * 3 / 4 - 55.0);
    
    lifeCounter.alpha = 0.0;
    [lifeCounter setNumber:MAX_LOST_INGOTS];
    [self addChild:lifeCounter];
    
    _lifeCounter = lifeCounter;
    

    [self runAction:[SKAction sequence:@[
                                         [SKAction waitForDuration:0.5],
                                         [SKAction runBlock:^{
        
        [score runAction:[SKAction fadeInWithDuration:0.3]];
        [life runAction:[SKAction fadeInWithDuration:0.3]];
        [counter runAction:[SKAction fadeInWithDuration:0.3]];
        [lifeCounter runAction:[SKAction fadeInWithDuration:0.3]];
    }],
                                         [SKAction waitForDuration:0.5],
                                         [SKAction runBlock:^{
                                            _golddrop = YES;
    }]]]];
    
    [self setGameStartTime];
}

-(void) setGameStartTime {
    _startTime = [NSDate date];
}

-(void) gameOver {
    
    SKSpriteNode * gameOverText = [SKSpriteNode spriteNodeWithTexture:[_atlas textureNamed:@"text-gameover"]];
    gameOverText.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame) * 3 / 2);
    
    SKSpriteNode * scoreBoard = [SKSpriteNode spriteNodeWithTexture:[_atlas textureNamed:@"scoreboard"]];
    scoreBoard.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    
    SKSpriteNode * newRecord = [SKSpriteNode spriteNodeWithColor:nil size:CGSizeMake(0.0, 0.0)];
    
    if([self storeHighScore:(int) [_counter getNumber]]){
        NSArray * recordAnimate = @[[_atlas textureNamed:@"text-new-record-pink"],
                                    [_atlas textureNamed:@"text-new-record-red"]];
        newRecord = [SKSpriteNode spriteNodeWithTexture: recordAnimate[0]];
        newRecord.position = CGPointMake(self.frame.size.width / 2 + 90, self.frame.size.height / 2 + 45 );
        newRecord.zPosition = 100.0;
        [newRecord runAction:[SKAction repeatActionForever:
                             [SKAction animateWithTextures:recordAnimate
                                              timePerFrame:0.2f
                                                    resize:YES
                                                   restore:YES]] withKey:@"newrecord"];
        
        [newRecord runAction:[SKAction repeatActionForever:
                              [SKAction sequence:@[[SKAction scaleBy:1.2 duration:0.1],
                                                   [SKAction scaleBy:10.0/12.0 duration:0.1]
                                                   ]]]];

        newRecord.alpha = 0.0;
    }
    
    CounterHandler * currentScore = [[CounterHandler alloc] initWithNumber:[_counter getNumber]];
    currentScore.position = CGPointMake(CGRectGetMidX(self.frame) + 105, CGRectGetMidY(self.frame) - 4.0);
    
    CounterHandler * highScore = [[CounterHandler alloc] initWithNumber:[self getHighScore]];
    highScore.position = CGPointMake(CGRectGetMidX(self.frame) + 105, CGRectGetMidY(self.frame) - 55.0);

    CGFloat buttonY = CGRectGetMidY(self.frame) / 2;
    
    SKTexture * homeDefault = [_atlas textureNamed:@"button-home-off"];
    SKTexture * homeTouched = [_atlas textureNamed:@"button-home-on"];
    
    ButtonNode * homeButton = [[ButtonNode alloc] initWithDefaultTexture:homeDefault andTouchedTexture:homeTouched];
    homeButton.position = CGPointMake(CGRectGetMidX(self.frame) - (homeButton.size.width / 2 + 8), buttonY);
    
    [homeButton setMethod: ^ (void) {
        SKTransition * reveal = [SKTransition fadeWithDuration: 0.5];
        SKScene * homeScene = [[HomeScene alloc] initWithSize:self.size];
        [self.view presentScene:homeScene transition:reveal];
    } ];
    
    
    SKTexture * shareDefault = [_atlas textureNamed:@"button-share-off"];
    SKTexture * shareTouched = [_atlas textureNamed:@"button-share-on"];
    
    ButtonNode * shareButton = [[ButtonNode alloc] initWithDefaultTexture:shareDefault andTouchedTexture:shareTouched];
    shareButton.position = CGPointMake(CGRectGetMidX(self.frame) + (shareButton.size.width / 2 + 8), buttonY);
    
    // prepare share action
    UIImage * pointboard = [UIImage imageNamed:@"pointboard.jpg"];
    
    NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [style setAlignment:NSTextAlignmentRight];

    UIFont * font = [UIFont fontWithName:@"Molot" size:40.0];
    
    NSShadow * fontBackgroundShadow = [[NSShadow alloc] init];
    fontBackgroundShadow.shadowBlurRadius = 0.0;
    fontBackgroundShadow.shadowColor = [UIColor colorWithRed:98.0/256.0
                                                       green:93.0/256.0
                                                        blue:89.0/256.0
                                                       alpha:1.0];
    fontBackgroundShadow.shadowOffset = CGSizeMake(0.0, 5.0);
    
    NSDictionary * fontBackgroundAtts = @{ NSFontAttributeName : font,
                                           NSParagraphStyleAttributeName : style,
                                           NSStrokeColorAttributeName : [UIColor whiteColor],
                                           NSStrokeWidthAttributeName : @-20.0f,
                                           NSShadowAttributeName : fontBackgroundShadow
                                           };
    
    NSDictionary * fontAtts = @{ NSFontAttributeName : font,
                                 NSForegroundColorAttributeName : [UIColor colorWithRed:86.0/256.0
                                                                                  green:86.0/256.0
                                                                                   blue:86.0/256.0
                                                                                  alpha:1.0],
                                 NSParagraphStyleAttributeName : style
                                 };
    
    CGRect usernameRect = CGRectMake(0.0, 185.0, 820.0, 80.0);
    CGRect scoreRect = CGRectMake(600.0, 262.0, 220.0, 80.0);
    
    [shareButton setMethod: ^ (void) {
        
        ViewController * viewController = (ViewController *) self.view.window.rootViewController;
        
        NSString * sharetext = [NSString stringWithFormat:@"I just scored %d in #PandaHatesRain!", (int) [_counter getNumber]];

        UIGraphicsBeginImageContext(pointboard.size);
        
        [pointboard drawInRect:CGRectMake(0,0,pointboard.size.width, pointboard.size.height)];
        
        GKPlayer * localPlayer = [viewController localPlayer];
        NSString * username = localPlayer.alias;
        
        [username drawInRect:CGRectIntegral(usernameRect) withAttributes: fontBackgroundAtts];
        [username drawInRect:CGRectIntegral(usernameRect) withAttributes: fontAtts];
        
        NSString * score = [NSString stringWithFormat:@"%d", (int)[_counter getNumber]];
        [score drawInRect:CGRectIntegral(scoreRect) withAttributes: fontBackgroundAtts];
        [score drawInRect:CGRectIntegral(scoreRect) withAttributes: fontAtts];
        
        UIImage * image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [viewController shareText:sharetext andImage:image];
    } ];
    
    
    CGFloat smallButtonY = buttonY - homeButton.size.height;
    
    SKTexture * rateDefault = [_atlas textureNamed:@"button-rate-off"];
    SKTexture * rateTouched = [_atlas textureNamed:@"button-rate-on"];
    
    ButtonNode * rateButton = [[ButtonNode alloc] initWithDefaultTexture:rateDefault andTouchedTexture:rateTouched];
    rateButton.position = CGPointMake(CGRectGetMidX(self.frame) + rateButton.size.width / 2 + 8, smallButtonY);
    
    [rateButton setMethod: ^ (void) {
        ViewController * viewController = (ViewController *) self.view.window.rootViewController;
        [viewController authenticateLocalPlayer];
        [viewController showGameCenterLeaderBoard];
/*
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:
                                                    @"itms-apps://itunes.apple.com/app/id824136867"
                                                    ]];
*/

    } ];
    
    SKTexture * retryDefault = [_atlas textureNamed:@"button-retry-off"];
    SKTexture * retryTouched = [_atlas textureNamed:@"button-retry-on"];
    
    ButtonNode * retryButton = [[ButtonNode alloc] initWithDefaultTexture:retryDefault andTouchedTexture:retryTouched];
    retryButton.position = CGPointMake(CGRectGetMidX(self.frame) - retryButton.size.width / 2 - 8, smallButtonY);
    
    [retryButton setMethod: ^ (void) {
        SKTransition * reveal = [SKTransition fadeWithColor:[UIColor whiteColor] duration:0.5];
        SKScene * gameScene = [[GameScene alloc] initWithSize:self.size];
        [self.view presentScene:gameScene transition:reveal];
    } ];
    
    [self addChild:gameOverText];
    [self addChild:scoreBoard];
    
    SKAction * buttonMove = [SKAction sequence:@[
                                                 [SKAction moveToY:buttonY - 10.0 duration:0.0],
                                                 [SKAction group:@[[SKAction fadeInWithDuration:0.3], [SKAction moveToY:buttonY duration:0.5]]
                                                  ]]];
    
    SKAction * smallButtonMove = [SKAction sequence:@[
                                                 [SKAction waitForDuration:0.3],
                                                 [SKAction moveToY:buttonY - homeButton.size.height - 10.0 duration:0.0],
                                                 [SKAction group:@[[SKAction fadeInWithDuration:0.3], [SKAction moveToY:buttonY - homeButton.size.height duration:0.5]]
                                                  ]]];
    
    gameOverText.alpha = 0.0;
    scoreBoard.alpha = 0.0;
    
    [self runAction:[SKAction sequence:@[[SKAction runBlock:^{
        [gameOverText runAction:
         [SKAction sequence:@[
                              [SKAction group:@[[SKAction scaleBy:2.0 duration:0.0]]],
                              [SKAction group:@[[SKAction fadeInWithDuration:0.5],[SKAction scaleBy:0.5 duration:0.2]]]
                              ]]];
    }],
     [SKAction waitForDuration:0.2],
     [SKAction runBlock:^{
        [scoreBoard runAction:[SKAction fadeInWithDuration:0.5]];
    }],
     [SKAction waitForDuration:0.6],
     [SKAction runBlock:^{
        
        [self addChild:highScore];
        [self addChild:currentScore];
        [self addChild:newRecord];
        [newRecord runAction:[SKAction fadeInWithDuration:0.3]];
    }],
     [SKAction waitForDuration:0.3],
     [SKAction runBlock:^{
        homeButton.alpha = 0.0;
        shareButton.alpha = 0.0;
        [self addChild:homeButton];
        [self addChild:shareButton];
        
        rateButton.alpha = 0.0;
        retryButton.alpha = 0.0;
        [self addChild:rateButton];
        [self addChild:retryButton];
        
        [homeButton runAction:buttonMove];
        [shareButton runAction:buttonMove];
        
        [rateButton runAction:smallButtonMove];
        [retryButton runAction:smallButtonMove];
    }]]]];

}

-(BOOL) storeHighScore:(int) score {

    int highRecord = 0;
    
    if ([SSKeychain passwordForService:@"Catch-Ingots" account:@"Catch-Ingots"] != nil) {
        highRecord = [[SSKeychain passwordForService:@"Catch-Ingots" account:@"Catch-Ingots"] intValue];
    }
    
    if (highRecord < score) {
        [SSKeychain setPassword:[NSString stringWithFormat:@"%d",score] forService:@"Catch-Ingots" account:@"Catch-Ingots"];
        
        ViewController * viewController = (ViewController *) self.view.window.rootViewController;
        if (viewController.gameCenterLogged) {
            [viewController reportScore: (int64_t) score];
        }

        return true;
    }
    return false;
}

-(int) getHighScore {
    int highRecord = 0;
    if ([SSKeychain passwordForService:@"Catch-Ingots" account:@"Catch-Ingots"] != nil) {
        highRecord = [[SSKeychain passwordForService:@"Catch-Ingots" account:@"Catch-Ingots"] intValue];
    }
    return (int) highRecord;
}

-(void) addRaindrop {

    SKTexture *temp = _waterDroppingFrames[0];
    SKSpriteNode * golddrop = [SKSpriteNode spriteNodeWithTexture:temp];
    int minX = golddrop.size.width / 2;
    int maxX = self.frame.size.width - golddrop.size.width / 2;

    CGFloat s = - ceil(_startTime.timeIntervalSinceNow);
    if ((s < 20 && _goldCount % 4 == 0) ||
        (s >= 20 && _goldCount % 4 == 0)) {
        int x = [_player position].x + self.frame.size.width / 2;
        minX = x - 10.0;
        maxX = x + 10.0;
    }
    
    int rangeX = maxX - minX;
    int actualX = (arc4random() % rangeX) + minX;
    
    if (actualX > self.frame.size.width - golddrop.size.width / 2) {
        actualX = self.frame.size.width - golddrop.size.width / 2;
    }else if (actualX < golddrop.size.width / 2) {
        actualX = golddrop.size.width / 2;
    }
    
    golddrop.name = @"golddrop";
    
    // set golddrop physicsbody
    golddrop.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:golddrop.size];
    golddrop.physicsBody.dynamic = YES;
    golddrop.physicsBody.categoryBitMask = goldCategory;
    golddrop.physicsBody.contactTestBitMask = pandaCategory;
    golddrop.physicsBody.collisionBitMask = 0;
    golddrop.physicsBody.usesPreciseCollisionDetection = YES;

    golddrop.position = CGPointMake(actualX, self.frame.size.height + golddrop.size.height / 2);
    
    [golddrop runAction:[SKAction repeatActionForever:
                          [SKAction animateWithTextures:_waterDroppingFrames
                                           timePerFrame:0.1f
                                                 resize:YES
                                                restore:YES]] withKey:@"goldingWaterDrop"];
    
    [self addChild:golddrop];
    
    int minDuration = 10;
    int maxDuration = 20;
    
    if(s >= 40 && _goldCount % 8 == 0){
        minDuration = 20;
        maxDuration = 30;
    }else if(s >= 20 && _goldCount % 6 == 0){
        minDuration = 20;
        maxDuration = 25;
    }
    
    int rangeDuration = maxDuration - minDuration;
    float actualDuration = ((arc4random() % rangeDuration) + minDuration) / 10;
    
    SKAction * actionMove = [SKAction moveTo:CGPointMake(actualX, _ground.position.y + _ground.size.height)
                                    duration:actualDuration];

    SKAction * endStateJudgeAndProc = [SKAction runBlock:^{
        _goldDisappearCount++;
        [_lifeCounter decrese];
        [self endStateJudgeAndProc];
    }];
    
    SKAction * actionMoveDone = [SKAction removeFromParent];
//    [golddrop runAction:[SKAction sequence:@[actionMove, countMove, actionMoveDone]] withKey:@"gold"];
    [golddrop runAction:[SKAction sequence:@[actionMove, endStateJudgeAndProc, actionMoveDone]] withKey:@"gold"];
    _goldCount++;
}

-(void) stopAllRaindrop{
    for (SKSpriteNode * node in [self children]) {
        if ([node actionForKey:@"gold"]) {
            [node removeActionForKey:@"gold"];
        }
    }
}

-(void) didBeginContact:(SKPhysicsContact *) contact {
    SKPhysicsBody *firstBody, *secondBody;
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask) {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }else{
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }

    if ((firstBody.categoryBitMask & goldCategory) != 0 &&
        (secondBody.categoryBitMask & pandaCategory) != 0) {
        
        SKAction * actionMoveDone = [SKAction removeFromParent];
        [(SKSpriteNode *) firstBody.node runAction:[SKAction sequence:@[actionMoveDone]]];
        [self player:(SKSpriteNode *) secondBody.node didCollideWithRaindrop:(SKSpriteNode *)firstBody.node];
    }
}

-(void) player:(SKSpriteNode *)playerNode didCollideWithRaindrop:(SKSpriteNode *)golddropNode {
    [_counter increse];
    _catchCount++;
    
#if 0
    if (_player.isLive) {
        
        [_player ended];
        [self stopAllRaindrop];
        
        [golddropNode runAction:[SKAction fadeOutWithDuration:0.3]];
        
        [_counter runAction:[SKAction fadeOutWithDuration:0.3]];
        [_score runAction:[SKAction fadeOutWithDuration:0.3]];
        
        [self runAction:
         [SKAction sequence:@[
                              [SKAction waitForDuration:1.0],
                              [SKAction runBlock:^{
                                 // call gameover screen
                                 [self gameOver];
                              }],
        ]]];
    }
#endif
}

-(CGFloat) getFireTime {
    CGFloat s = - ceil(_startTime.timeIntervalSinceNow);
    CGFloat fireTime = 1.0;
#if 0
    if (s < 15) {
        fireTime = (25 - s) * 0.02;
    }else {
        fireTime = 0.2;
    }
#endif
    return fireTime;
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [ButtonNode doButtonsActionEnded:self touches:touches withEvent:event];
    [_player touchesEnded:touches withEvent:event];
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [_player touchesMoved:touches withEvent:event];
    [_guide touchesMoved:touches withEvent:event];
}

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [ButtonNode doButtonsActionBegan:self touches:touches withEvent:event];
    [_player touchesBegan:touches withEvent:event];
}

-(void)updateWithTimeSinceLastUpdate:(CFTimeInterval)timeSinceLast {
    if(_player.isLive && _golddrop){
        self.lastSpawnTimeInterval += timeSinceLast;
        if(self.lastSpawnTimeInterval > [self getFireTime]){
            self.lastSpawnTimeInterval = 0;
            [self addRaindrop];
        }
    }
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    CFTimeInterval timeSinceLast = currentTime - self.lastUpdateTimeInterval;
    self.lastUpdateTimeInterval = currentTime;
    if (timeSinceLast > 1.0) {
        timeSinceLast = 1.0 / 60.0;
        self.lastUpdateTimeInterval = currentTime;
    }

    [self updateWithTimeSinceLastUpdate:timeSinceLast];
    [_player update:currentTime];
}

-(void)endStateJudgeAndProc {
    int lostCount = _goldDisappearCount;
    if(lostCount >= MAX_LOST_INGOTS)
    {
        if (_player.isLive) {
            
            [_player ended];
            [self stopAllRaindrop];
            
            [_counter runAction:[SKAction fadeOutWithDuration:0.3]];
            [_score runAction:[SKAction fadeOutWithDuration:0.3]];
            
            [_lifeCounter runAction:[SKAction fadeOutWithDuration:0.3]];
            [_life runAction:[SKAction fadeOutWithDuration:0.3]];
            [self runAction:
                [SKAction sequence:@[
                                    [SKAction waitForDuration:1.0],
                                    [SKAction runBlock:^{
                                    // call gameover screen
                                    [self gameOver];
                }],
            ]]];
        }
    }
}

@end
