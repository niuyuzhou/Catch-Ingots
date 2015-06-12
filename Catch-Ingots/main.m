//
//  main.m
//  Catch-Ingots
//
//  Created by niuyuzhou on 12/02/2015.
//  Copyright (c) 2015 YuzhouNiu. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

int main(int argc, char * argv[])
{
    @autoreleasepool {
        @try {
            return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        }
        @catch (NSException *exception) {
            NSLog(@"%s\n%@", __FUNCTION__, exception);
        }
        @finally {
            
        }
        return YES;
    }
}
