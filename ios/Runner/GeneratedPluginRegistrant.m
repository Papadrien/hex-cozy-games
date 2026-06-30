//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<firebase_analytics/FirebaseAnalyticsPlugin.h>)
#import <firebase_analytics/FirebaseAnalyticsPlugin.h>
#else
@import firebase_analytics;
#endif

#if __has_include(<firebase_core/FLTFirebaseCorePlugin.h>)
#import <firebase_core/FLTFirebaseCorePlugin.h>
#else
@import firebase_core;
#endif

#if __has_include(<firebase_crashlytics/FLTFirebaseCrashlyticsPlugin.h>)
#import <firebase_crashlytics/FLTFirebaseCrashlyticsPlugin.h>
#else
@import firebase_crashlytics;
#endif

#if __has_include(<games_services/SwiftGamesServicesPlugin.h>)
#import <games_services/SwiftGamesServicesPlugin.h>
#else
@import games_services;
#endif

#if __has_include(<google_mobile_ads/FLTGoogleMobileAdsPlugin.h>)
#import <google_mobile_ads/FLTGoogleMobileAdsPlugin.h>
#else
@import google_mobile_ads;
#endif

#if __has_include(<in_app_purchase_storekit/InAppPurchasePlugin.h>)
#import <in_app_purchase_storekit/InAppPurchasePlugin.h>
#else
@import in_app_purchase_storekit;
#endif

#if __has_include(<shared_preferences_foundation/SharedPreferencesPlugin.h>)
#import <shared_preferences_foundation/SharedPreferencesPlugin.h>
#else
@import shared_preferences_foundation;
#endif

#if __has_include(<webview_flutter_wkwebview/WebViewFlutterPlugin.h>)
#import <webview_flutter_wkwebview/WebViewFlutterPlugin.h>
#else
@import webview_flutter_wkwebview;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FirebaseAnalyticsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FirebaseAnalyticsPlugin"]];
  [FLTFirebaseCorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
  [FLTFirebaseCrashlyticsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCrashlyticsPlugin"]];
  [SwiftGamesServicesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SwiftGamesServicesPlugin"]];
  [FLTGoogleMobileAdsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTGoogleMobileAdsPlugin"]];
  [InAppPurchasePlugin registerWithRegistrar:[registry registrarForPlugin:@"InAppPurchasePlugin"]];
  [SharedPreferencesPlugin registerWithRegistrar:[registry registrarForPlugin:@"SharedPreferencesPlugin"]];
  [WebViewFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"WebViewFlutterPlugin"]];
}

@end
