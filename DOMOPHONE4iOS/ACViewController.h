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

#import <UIKit/UIKit.h>


#define STATUS_CONNECTING       0
#define STATUS_AUTHERROR        1
#define STATUS_CONNECTIONERROR  2
#define STATUS_COMPATERROR      3
#define STATUS_CONNECTED        4
#define STATUS_OPENING          5
#define STATUS_WAITING          6

@class ACLinphone;
@interface ACViewController : UIViewController 
- (IBAction)infoTouch:(id)sender;
- (IBAction)openTouch:(id)sender;
- (IBAction)gateTouch:(id)sender;
- (IBAction)audioVideoTouch:(id)sender;
- (IBAction)homepageTouch:(id)sender;
- (IBAction)acPageTouch:(id)sender;
- (IBAction)statusTouch:(id)sender;
- (void) connectionInit;
- (void)sipRegistered;
- (void)sipTerminate;
- (void)sipVideoStarted;
- (void)sipCallStarted;
- (void)sipDisconnect;
- (void)disconnect;
- (void)setConnectedStatusWithActInd:(BOOL)ai;
- (void)setWaitingStatus;
- (int)currentStatus;
- (void) PushRegister;
+ (long)getRingToneID;
@property (unsafe_unretained, nonatomic) IBOutlet UIView *statusView;
@property (unsafe_unretained, nonatomic) IBOutlet UIImageView *logoImage;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnGate;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnGateway;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnAudio;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnVideo;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnOpen;
@property (unsafe_unretained, nonatomic) IBOutlet UIView *infoView;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnInfo;
@property (unsafe_unretained, nonatomic) IBOutlet UITextView *logTextView;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnStatus;
@property (unsafe_unretained, nonatomic) IBOutlet UIImageView *statusImage;
@property (unsafe_unretained, nonatomic) IBOutlet UIActivityIndicatorView *actInd;
@property (unsafe_unretained, nonatomic) IBOutlet UIView *videoView;
@property (unsafe_unretained, nonatomic) IBOutlet UIView *videoFrame;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *labelStreet;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *labelCountry;
@property (unsafe_unretained, nonatomic) IBOutlet UILabel *labelVersion;
@property (readonly, nonatomic) NSDate *lastSysState;
@property (nonatomic) NSData *push_token;
@end

extern ACViewController *MainVC;
