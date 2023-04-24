//
//  AppDelegate.h
//  turifuri
//
//  Created by 木谷 on 2017/10/01.
//  Copyright © 2017年 木谷. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, retain) NSString *gDeviceToken;   // デバイストークン（PUSH通知用）
@property (strong, nonatomic) UIWindow *window;

@end

