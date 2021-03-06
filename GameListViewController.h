//
//  GameListViewController.h
//  Puzzles
//
//  Created by Greg Hewgill on 8/03/13.
//  Copyright (c) 2013 Greg Hewgill. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PSTCollectionView.h"

#import "GameViewController.h"

@interface GameListViewController : PSUICollectionViewController <GameViewControllerSaver>

- (GameViewController *)savedGameViewController;
- (void)saveGame:(NSString *)name state:(NSString *)save inprogress:(BOOL)inprogress;

@end
