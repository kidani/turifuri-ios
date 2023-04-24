//
//  ViewController.m
//  turifuri
//
//  Created by 木谷 on 2017/10/01.
//  Copyright © 2017年 木谷. All rights reserved.
//

#import <StoreKit/StoreKit.h>
#import "ViewController.h"
#import "AppDelegate.h"
#import "RMUniversalAlert.h"
#import "AFNetworking.h"
@import Firebase;

// UUID
#define UNIQUE_ID @"uuid"
// OSバージョン取得
#define OS_VERSION [[[UIDevice currentDevice] systemVersion] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

#ifdef DEBUG
// ログ出力
#define DebugLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#define BASE_URL @"http://dev.turifuri.com/"
#else
#define DebugLog(...)
#define BASE_URL @"https://turifuri.com/"
#endif

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // キャッシュクリア
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
    
    // バッジ数初期化
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    
    // userAgent を加工
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.applicationNameForUserAgent = @"nativeIos";       // これで既存に追記になる。

    // WebView生成、デリゲート
    WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    _webView = webView;
    webView.UIDelegate = self;
    webView.navigationDelegate = self;
    
     // ウェブビューのサイズ調整
    // iPhone 6 でステータスバー上にコンテンツが表示されるのを回避（SafeArea対応？）
    // CGRect rect = self.view.frame;
    // 位置ｘ, 位置y, 幅, 高さ
    CGRect rect = CGRectMake(0, 20, self.view.frame.size.width, self.view.frame.size.height);
    webView.frame = rect;
    
    // インスタンスをビューに追加する
    [self.view addSubview:webView];
    
    // OSバージョン取得（少数点1位まで）
    float sysVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
    NSString *osVersion = [NSString stringWithFormat:@"%.1f", sysVersion];
    
    // バージョン番号取得（ユーザーに公開されるバージョン）
    // NSString *versionName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    // ビルド番号取得（バージョンコード、アップロードの都度カウントアップ必須。）
    NSString *versionCode = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];

    // UUID取得
    NSString *uuid = [self getUniqueId];
    
    _baseUrl = BASE_URL;
    _baseNsUrl = [[NSURL alloc] initWithString:_baseUrl];
    _loadUrl = [NSString stringWithFormat:@"%@?iosUid=%@&osVersion=%@&versionCode=%@", _baseUrl, uuid, osVersion, versionCode];
    DebugLog(@"%@", _loadUrl);
    
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:_loadUrl]];
    [_webView loadRequest:req];
    
    //  デバイストークン取得通知の設定
    NSNotificationCenter* nc1 = [NSNotificationCenter defaultCenter];
    [nc1 addObserver:self selector:@selector(applicationDidRecieveDeviceToken:) name:@"applicationDidRecieveDeviceToken" object:nil];
    
    //  ディープリンク取得通知の設定
    NSNotificationCenter* nc2 = [NSNotificationCenter defaultCenter];
    [nc2 addObserver:self selector:@selector(applicationDidRecieveDeeplink:) name:@"applicationDidRecieveDeeplink" object:nil];
    
    //  プッシュリンク取得通知の設定
    NSNotificationCenter* nc3 = [NSNotificationCenter defaultCenter];
    [nc3 addObserver:self selector:@selector(applicationDidRecievePushlink:) name:@"applicationDidRecievePushlink" object:nil];
}


/**
 *
 * alert ダイアログ
 *
 * サーバ側JSの alert ダイアログ表示
 * WKWebView ではこれが必須。
 *
*/
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
       UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message
                                                                        message:nil
                                                                         preferredStyle:UIAlertControllerStyleAlert];
       [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
                                                             completionHandler();
                                                         }]];
       [self presentViewController:alertController animated:YES completion:^{}];
}

/**
 *
 * confirm ダイアログ
 *
 * サーバ側JSの confirm ダイアログ表示
 * WKWebView ではこれが必須。
 *
*/
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler
{
    NSString *hostString = webView.URL.host;
    NSString *sender = [NSString stringWithFormat:@"%@からの表示", hostString];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message message:sender preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        completionHandler(YES);
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        completionHandler(NO);
    }]];
    [self presentViewController:alertController animated:YES completion:^{}];
}

// デバイストークン取得
-(void)applicationDidRecieveDeviceToken:(NSNotification*)center {
    
    // スリープ
    // アプリ起動時のウェブビューからのアクセスより先に、このデバイストークン通信処理が
    // 走るのを回避するためにスリープを追加しておく。
    // 先に走ると Users や UsersTemp に行追加される前なので登録対象の行が存在しないため。
     [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    
    // delegate で取得する方法の場合
    // AppDelegate* delegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
    // NSString *token = delegate.gDeviceToken;
    
    // NSNotification で取得
    NSString *token = [[center userInfo] objectForKey:@"token"];
    
    // デバイストークンをサーバ側に直接送信
    // AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    // UserAgent に nativeIos を追記
    NSString *userAgent = [manager.requestSerializer  valueForHTTPHeaderField:@"User-Agent"];
    userAgent = [userAgent stringByAppendingPathComponent:@" nativeIos"];
    [manager.requestSerializer setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    NSString *authUrl = [NSString stringWithFormat:@"%@&p=Regist/NativeInfo&deviceToken=%@", _loadUrl, token];
    // ここで送信実行
    [manager GET:authUrl parameters:nil headers:nil progress:nil success:^(NSURLSessionTask *task, id responseObject){
        // DebugLog(@"JSON: %@", responseObject);
        NSString *responseStr = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        DebugLog(@"%@", responseStr);
    } failure:^(NSURLSessionTask *operation, NSError *error){
        DebugLog(@"通信エラー: %@", error);
        // エラーページへ
        // NSString *buyUrl = [NSString stringWithFormat:@"%@&p=Regist/NativeInfo&error=%@", _loadUrl, @"AFHTTPRequestOperationError"];
    }];
    
    // 通知の監視を終了
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"applicationDidRecieveDeviceToken" object:nil];
}

// ディープリンク取得
-(void)applicationDidRecieveDeeplink:(NSNotification*)center {
    
    // クエリ取得
    NSString *deepQuery = [[center userInfo] objectForKey:@"deepQuery"];
    if ([deepQuery length] == 0) {
        deepQuery = @"";
    }
    
    NSString *loadUrl = [NSString stringWithFormat:@"%@&%@", _loadUrl, deepQuery];
    DebugLog(@"%@", _loadUrl);
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:loadUrl]];
    [_webView loadRequest:req];

    // 通知の監視を終了
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"applicationDidRecieveDeeplink" object:nil];
}

// プッシュリンク取得
-(void)applicationDidRecievePushlink:(NSNotification*)center {
    
    // クエリ取得
    NSString *pushQuery = [[center userInfo] objectForKey:@"pushQuery"];
    NSString *loadUrl = _loadUrl;
    if ([pushQuery length] != 0) {
         // 指定されたページへ
         loadUrl = [NSString stringWithFormat:@"%@&p=%@", _loadUrl, pushQuery];
    } else {
         // お知らせ画面へ
         // loadUrl = [NSString stringWithFormat:@"%@&p=Info/AlertList", _loadUrl];
    }
    DebugLog(@"%@", loadUrl);
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:loadUrl]];
    [_webView loadRequest:req];
    
    // 通知の監視を終了
    // コメントしないとプッシュ通知が複数回来た際にここを通らなくなる！何かしらの仕様変更かも
    // [[NSNotificationCenter defaultCenter] removeObserver:self name:@"applicationDidRecievePushlink" object:nil];
}

- (void)viewDidUnload {
    
}

- (void)dealloc {
    _webView.UIDelegate = nil;
}

/**
 *
 * 画面遷移のフック
 *
 */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    #ifdef DEBUG
        //キャッシュを全消去
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
    #endif
   
    // NSURL *url = [webView URL];
    // NSString *pageTitle = [webView title];
    NSURLRequest *request = [navigationAction request];
    NSString *absoluteURL = [request.URL absoluteString];   // リクエスト全体
    DebugLog(@"★%@", absoluteURL);
    // NSString *hostName = [[request URL] host];           // ドメイン
    //DebugLog(@"★%@", hostName);
    NSString *query = [[request URL] query];                // クエリ
    //DebugLog(@"★%@", query);
    
    // UUID取得
    if ([query containsString:@"getUuid=1"]) {
        // パラメータ「getUuid=1」あリの場合
        //     UUID付加してトップへ遷移
        //     セッション切れルート
        NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:_loadUrl]];
        [_webView loadRequest:req];
        // サーバ遷移なし
        decisionHandler(WKNavigationActionPolicyCancel);
    }
    
    // バッジ数取得
    if ([query containsString:@"badge="]) {
        // パラメータ「badge=NN」あリの場合
        
        // クエリ文字列をパース
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        for (NSString *param in [query componentsSeparatedByString:@"&"]) {
            NSArray *elts = [param componentsSeparatedByString:@"="];
            if ([elts count] < 2) continue;
            [params setObject:[elts objectAtIndex:1] forKey:[elts objectAtIndex:0]];
        }
        
        int badge = [params[@"badge"] intValue];
        
        // バッジ更新
        [UIApplication sharedApplication].applicationIconBadgeNumber = badge;
    }
    
    // レビュー誘導ダイアログ表示
    if ([query containsString:@"showReviewAlert=1"]) {
        // パラメータ「showReviewAlert=1」あリの場合
        float iOSVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        if (iOSVersion > 10.2f) {
            // iOS 10.3 以上の場合
            [RMUniversalAlert showAlertInViewController:self
                                              withTitle:@"アプリ評価のお願い"
                                                message:@"このアプリへの評価にご協力お願い致します！"
                                      cancelButtonTitle:@"今は評価しない"
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:@[@"評価する"]
                                               tapBlock:^(RMUniversalAlert *alert, NSInteger buttonIndex){
                                                   // ボタン押下時処理
                                                   NSString *answerNo = @"0";
                                                   if (buttonIndex == alert.cancelButtonIndex) {
                                                       // 「今は評価しない」ボタン押下時
                                                   } else if (buttonIndex >= alert.firstOtherButtonIndex) {
                                                       // 「評価する」ボタン押下時
                                                       answerNo = @"1";
                                                       // レビュー誘導ダイアログ表示
                                                       [SKStoreReviewController requestReview];
                                                   }
                                                   // サーバに通知
                                                   NSString *url = [NSString stringWithFormat:@"%@?p=Regist/NativeReview&answerNo=%@", _baseUrl, answerNo];
                                                   DebugLog(@"%@", url);
                                                   NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
                                                   [_webView loadRequest:req];
                                               }];
        }
    
    }

    // ◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆
    // 通常遷移以外の各種リクエストが来るので navigationType での振り分け必須！
    // iframe で Google を表示している場合や、広告タグを設置している場合などは1アクセスで複数回呼ばれる。
    // target="_blank" で開いた場合も何故か hostName が「about:blank」になり複数回呼ばれるので注意！
    // ◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        // Aタグによる遷移（GETの場合、リンクがクリックされた場合）
        if (![absoluteURL containsString: _baseNsUrl.host]) {
            // 外部リンクの場合はブラウザで開く
            // この処理を WKNavigationTypeLinkActivated 以外の場所でやらないよう注意！
            // もしやると iframe 内や広告タグのリクエストで外部リンクを開きまくってしまう。
            [[UIApplication sharedApplication] openURL:request.URL];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        if (!navigationAction.targetFrame || !navigationAction.targetFrame.isMainFrame) {
            // target="_blank" の場合は同じウィンドウで開く（子ウィンドウを開きまくらない）
            NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:absoluteURL]];
            [_webView loadRequest:req];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
        
        // 商品購入完了
        if ([query containsString:@"Buy/BuyHistory"]) {
            if ([query containsString:@"mode=finish"]) {
                // クエリ文字列をパース
                NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
                for (NSString *param in [query componentsSeparatedByString:@"&"]) {
                    NSArray *elts = [param componentsSeparatedByString:@"="];
                    if ([elts count] < 2) continue;
                    [params setObject:[elts objectAtIndex:1] forKey:[elts objectAtIndex:0]];
                }
                NSString *price = params[@"price"];
                NSString *buyId = params[@"userBuyHistoryId"];
                
                // Firebase
                [FIRAnalytics logEventWithName:kFIREventSelectContent
                        parameters:@{
                                     kFIRParameterItemID: buyId,
                                     kFIRParameterItemName: @"buy",
                                     kFIRParameterPrice: price,
                                     kFIRParameterContentType: @"buy"
                                     }];
            }
        }
    } else if (navigationAction.navigationType == WKNavigationTypeFormSubmitted) {
        // フォームの送信による遷移（POSTの場合）
        //     POST直後のリダイレクトでもこちらに入るかも知れないので注意！
    } else if (navigationAction.navigationType == WKNavigationTypeBackForward) {
        // 進む／戻るによる遷移
    } else if (navigationAction.navigationType == WKNavigationTypeReload) {
        // 更新による遷移
    } else if (navigationAction.navigationType == WKNavigationTypeFormResubmitted) {
        // フォームの再送信による遷移
    } else if (navigationAction.navigationType == WKNavigationTypeOther) {
        // リダイレクトの場合
    }
    // 通常のブラウザ遷移へ
    decisionHandler(WKNavigationActionPolicyAllow);
}


/**
 *
 * 画面遷移のフック
 *
 */
/*
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
#ifdef DEBUG
    //キャッシュを全消去
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
#endif
    
    // クエリ取得
    NSString *query = [[request URL] query];

    // UUID取得
    if ([query containsString:@"getUuid=1"]) {
        // パラメータ「getUuid=1」あリの場合
        //     UUID付加してトップへ遷移
        //     セッション切れルート
        NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:_loadUrl]];
        [_webView loadRequest:req];
        
        // サーバ遷移なし
        return NO;
    }
    
    // バッジ数取得
    if ([query containsString:@"badge="]) {
        // パラメータ「badge=NN」あリの場合
        
        // クエリ文字列をパース
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        for (NSString *param in [query componentsSeparatedByString:@"&"]) {
            NSArray *elts = [param componentsSeparatedByString:@"="];
            if ([elts count] < 2) continue;
            [params setObject:[elts objectAtIndex:1] forKey:[elts objectAtIndex:0]];
        }
        
        int badge = [params[@"badge"] intValue];
        
        // バッジ更新
        [UIApplication sharedApplication].applicationIconBadgeNumber = badge;
    }
    
    // 商品購入完了
    if ([query containsString:@"Buy/BuyHistory"]) {
        if ([query containsString:@"mode=finish"]) {
            // クエリ文字列をパース
            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            for (NSString *param in [query componentsSeparatedByString:@"&"]) {
                NSArray *elts = [param componentsSeparatedByString:@"="];
                if ([elts count] < 2) continue;
                [params setObject:[elts objectAtIndex:1] forKey:[elts objectAtIndex:0]];
            }
            NSString *price = params[@"price"];
            NSString *buyId = params[@"userBuyHistoryId"];
            
            // Firebase
            [FIRAnalytics logEventWithName:kFIREventSelectContent
                    parameters:@{
                                 kFIRParameterItemID: buyId,
                                 kFIRParameterItemName: @"buy",
                                 kFIRParameterPrice: price,
                                 kFIRParameterContentType: @"buy"
                                 }];
        }
    }
    
    if (navigationType == UIWebViewNavigationTypeFormSubmitted) {
        // POSTの場合
        //     何故かPOST直後のリダイレクトでもこちらに入るので注意！
    } else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        // GETの場合
    } else if (navigationType == UIWebViewNavigationTypeOther) {
        // リダイレクトの場合
    }
    
    // 通常のブラウザ遷移へ
    return YES;
}
*/

/**
 *
 * ファイル選択ダイアログ表示
 *
 * 画像アップロード時のファイル選択ダイアログ表示
 *
 */
-(void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    if (self.presentedViewController) {
        [super dismissViewControllerAnimated:flag completion:completion];
    }
}

/**
 *
 * UUID取得
 *
 * 端末に保存したユニークIDを取得する。
 *
 */
- (NSString*)getUniqueId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults stringForKey: UNIQUE_ID]) {
        return [defaults stringForKey: UNIQUE_ID];
    } else {
        NSString *iosVersion = OS_VERSION;
        NSString *uuid;
        if ([iosVersion floatValue] >= 6.0) {
            uuid = [[NSUUID UUID] UUIDString];
        } else {
            CFUUIDRef uuidRef = CFUUIDCreate(NULL);
            uuid = (__bridge_transfer NSString*)CFUUIDCreateString(NULL, uuidRef);
            CFRelease(uuidRef);
        }
        // userDefaultsに保存
        [defaults setObject: uuid forKey: UNIQUE_ID];

        return uuid;
    }
}

/**
 *
 * ダイアログ表示
 *
 */
- (void)rmAlert: (NSString*)message arg2:(NSString*)title {
    [RMUniversalAlert showAlertInViewController:self
                                      withTitle: title
                                        message: message
                              cancelButtonTitle:nil
                         destructiveButtonTitle:nil
                              otherButtonTitles:@[@"OK"]
                                       tapBlock:^(RMUniversalAlert *alert, NSInteger buttonIndex){
                                           // ボタン押下時処理
                                           if (buttonIndex == alert.firstOtherButtonIndex) {
                                               
                                           } else {
                                              
                                           }
                                       }];
}




@end







