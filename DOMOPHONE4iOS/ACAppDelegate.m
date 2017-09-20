/*
 Copyright (C) AC SOFTWARE SP. Z O.O.
 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "ACAppDelegate.h"
#import "ACViewController.h"

@implementation ACAppDelegate {
    unsigned long BgTask;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    BgTask = 0;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[ACViewController alloc] initWithNibName:@"ACViewController" bundle:nil];
    } else {
        self.viewController = [[ACViewController alloc] initWithNibName:@"ACViewController_iPad" bundle:nil];
    }
    
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    #if !TARGET_IPHONE_SIMULATOR
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    #endif
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)connectionCheck {
    if ( MainVC
        && MainVC.lastSysState
        && [[NSDate date] timeIntervalSinceDate: MainVC.lastSysState] >= 10 ) {
        [MainVC connectionInit];
    };
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    [MainVC sipDisconnect];
    
    NSNumber *bg = [[NSUserDefaults standardUserDefaults] valueForKey:@"pref_bg"];
    
    if ( bg == NULL || [bg boolValue] == YES ) {
        
        BgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: ^{
            NSLog(@"bgTimeOut");
        }];
        
        [[UIApplication sharedApplication] setKeepAliveTimeout:600
                                                       handler:^{
                                                           
                                                           [self connectionCheck];
                                                           
                                                       }];
    }
    

    
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    if (BgTask) {
        [[UIApplication sharedApplication]  endBackgroundTask:BgTask];
        BgTask=0;
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [self connectionCheck];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [MainVC disconnect];
    
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    #ifdef CONSOLE_DEBUG
    NSLog(@"Did register for remote notifications: %@", deviceToken);
    #endif
    self.viewController.push_token = deviceToken;
    [self.viewController PushRegister];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    #ifdef CONSOLE_DEBUG
    NSLog(@"Fail to register for remote notifications: %@", error);
    #endif
    self.viewController.push_token = nil;
    [self.viewController PushRegister];
}

@end
