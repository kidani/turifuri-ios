//
//  AppDelegate.m
//  turifuri
//
//  Created by 木谷 on 2017/10/01.
//  Copyright © 2017年 木谷. All rights reserved.
//

#import "AppDelegate.h"
#import "RMUniversalAlert.h"
@import UIKit;
@import Firebase;
@import WebKit;

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // スプラッシュ表示用にスリープ
    // [NSThread sleepForTimeInterval:2.0];
    
    // Firebase
    [FIRApp configure];
    
    // PUSH通知設定の許可ダイアログ表示
    [application unregisterForRemoteNotifications];
    [application registerForRemoteNotifications];
    UIUserNotificationType types = (UIUserNotificationTypeBadge |
                                    UIUserNotificationTypeSound |
                                    UIUserNotificationTypeAlert);
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [application registerUserNotificationSettings:settings];

    return YES;
}

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // iOS13 以降のデバイストークン取得仕様変更対応
    
    //NSString *token = deviceToken.description;
    //token = [token stringByReplacingOccurrencesOfString:@"<" withString:@""];
    //token = [token stringByReplacingOccurrencesOfString:@">" withString:@""];
    //token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *token = [self hexadecimalStringFromData:deviceToken];
    
    // デバイストークンを保存
    _gDeviceToken = token;
    NSLog(@"deviceToken: %@", token);
    
    // デバイストークン取得通知
    NSDictionary *dic = [NSDictionary dictionaryWithObject:token forKey:@"token"];
    NSNotification* n = [NSNotification notificationWithName:@"applicationDidRecieveDeviceToken" object:self userInfo:dic];
    [[NSNotificationCenter defaultCenter] postNotification:n];
}

// iOS13 以降のデバイストークン取得仕様変更対応
// https://yara-shimizu.com/2019/10/05/ios-ver13/
- (NSString *)hexadecimalStringFromData:(NSData *)data {
    NSUInteger dataLength = data.length;
    if (dataLength == 0) {
        return nil;
    }

    const unsigned char *dataBuffer = data.bytes;
    NSMutableString *hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for (int i = 0; i < dataLength; ++i) {
        [hexString appendFormat:@"%02x", dataBuffer[i]];
    }
    return [hexString copy];
}

// FirebaseCloudMessaging の初期設定（FIXME：これ未使用かも）
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [application registerForRemoteNotifications];
    //[[FIRMessaging messaging] subscribeToTopic:@"/topics/foo"];
}

/* fetchCompletionHandler 側で処理すれば不要（というか入って来ない）
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    if(application.applicationState == UIApplicationStateActive) {
        NSLog(@"フォアグラウンドで起動中の場合");
    }
    if(application.applicationState == UIApplicationStateInactive) {
        NSLog(@"バックグラウンドで起動中の場合");
    }
    // バッジの削除などの処理を行う。
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}
*/

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    if (userInfo) {
        // サーバ側で指定した Key-Value を取得
        // key      : aps
        // value    : alert: メッセージ
        //          : badge: バッジ数
        //          : sound: default
        //NSString *userInfoStr = (NSString*)userInfo;
        //NSDictionary* userInfoNew = [NSJSONSerialization JSONObjectWithData:[userInfoStr dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
        //NSLog(@"%@", dic[@"id"]);
        //NSLog(@"%@", dic[@"name"]);
        
        //NSDictionary *aps = [userInfoNew objectForKey:@"aps"];
        NSDictionary *aps = [userInfo objectForKey:@"aps"];
        NSDictionary *alert = [aps objectForKey:@"alert"];
        NSString *messageTitle = [alert objectForKey:@"title"];
        NSString *messageBody = [alert objectForKey:@"body"];
        NSString *messageCategory = [aps objectForKey:@"category"];
        int badge = [[aps objectForKey:@"badge"] intValue];

        // バッジ更新
        [UIApplication sharedApplication].applicationIconBadgeNumber = badge;

        // ダイアログ表示（OKボタンのみ）
        [RMUniversalAlert showAlertInViewController:(UIViewController*)self.window.rootViewController
                                          withTitle: messageTitle
                                            message: messageBody
                                  cancelButtonTitle:nil
                             destructiveButtonTitle:nil
                                  otherButtonTitles:@[@"OK"]
                                           tapBlock:^(RMUniversalAlert *alert, NSInteger buttonIndex){
                                               // ボタン押下時処理
                                               if (buttonIndex == alert.firstOtherButtonIndex){
                                                   // ボタン押下時処理
                                                    // ViewController にてお知らせ画面に遷移させる。
                                                   NSDictionary *dic = [NSDictionary dictionaryWithObject:messageCategory forKey:@"pushQuery"];
                                                   NSNotification* n = [NSNotification notificationWithName:@"applicationDidRecievePushlink" object:self userInfo:dic];
                                                   [[NSNotificationCenter defaultCenter] postNotification:n];
                                               }
                                           }];
        
        UIApplicationState appState = application.applicationState;
        NSString *appStateString = @"unknown";
        if (appState == UIApplicationStateActive) {
            // フォアグラウンドの場合
            appStateString = @"active";
        } else if (appState == UIApplicationStateInactive) {
            // バックグラウンドから通知クリックで復帰した場合
            appStateString = @"inactive";
        } else if (appState == UIApplicationStateBackground) {
            // 未起動から通知クリックで復帰した場合（確認してないが恐らく）
            appStateString = @"background";
        }
        NSLog(@"Receive remote notification. State:%@", appStateString);
    }

    // completionHandlerはダウンロードのような時間がかかる処理では非同期に呼ぶ。
    // 同期処理でも呼ばないとログにWarning出力されるので注意。
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    // Track Installs, updates & sessions(app opens) (You must include this API to enable tracking)
    // [[AppsFlyerTracker sharedTracker] trackAppLaunch];
    
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

// ディープリンク取得（Universal Links）
-(BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity
restorationHandler:(void (^)(NSArray *restorableObjects))restorationHandler{
    // Universal Links でアプリが起動された場合
    if ([userActivity.activityType isEqualToString: NSUserActivityTypeBrowsingWeb]) {
        // WEBから起動された場合
        // NSURL *url = userActivity.webpageURL;
        NSString *deepQuery = userActivity.webpageURL.query;
        if ([deepQuery length] == 0) {
            deepQuery = @"";
        }
        // ViewController にディープリンク取得通知
        NSDictionary *dic = [NSDictionary dictionaryWithObject:deepQuery forKey:@"deepQuery"];
        NSNotification* n = [NSNotification notificationWithName:@"applicationDidRecieveDeeplink" object:self userInfo:dic];
        [[NSNotificationCenter defaultCenter] postNotification:n];
    }
    return YES;
}

@end





