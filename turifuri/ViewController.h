//
//  ViewController.h
//  turifuri
//
//  Created by 木谷 on 2017/10/01.
//  Copyright © 2017年 木谷. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface ViewController : UIViewController<WKNavigationDelegate, WKUIDelegate>

@property WKWebView *webView;
@property NSString *baseUrl;            // ウェブビューURL（パラメータなし）
@property NSString *loadUrl;            // ロード時のURL（パラメータ付き）
@property NSURL *baseNsUrl;             // ロード時のNSURL
@property NSString *hostName;             // ロード時のNSURL

@end


