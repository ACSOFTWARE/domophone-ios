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

#import "ACViewController.h"
#import "ACDomophoneConnection.h"
#import "ACLinphone.h"
#include "socketdata.h"
#include "dconnection.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>


#define ACBUTTONTYPE_AUDIO      1
#define ACBUTTONTYPE_VIDEO      2
#define ACBUTTONTYPE_GATEWAY    3
#define ACBUTTONTYPE_GATE       4

#define ACButtonsAnimationTypeHorizontal    0
#define ACButtonsAnimationTypeVertical      1

#define ACDEVCAP_AUDIO           0x1
#define ACDEVCAP_VIDEO           0x2
#define ACDEVCAP_GATEWAY         0x4
#define ACDEVCAP_GATE            0x8
#define ACDEVCAP_GATE_SENSOR     0x10
#define ACDEVCAP_GATEWAY_SENSOR  0x20

#define ACDEVSTATUS_GATEISCLOSED          0x1
#define ACDEVSTATUS_GATEWAYISCLOSED       0x2
#define ACDEVSTATUS_CLOUD_CONNECTED       0x3

#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPHONE_5 (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 568.0f)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)


ACViewController *MainVC = nil;

@interface ACViewController () {
    ACDomophoneConnection *_Connection;

    int right_margin;
    int bottom_margin;
    int _Caps;
    int _Status;
    
    NSInteger lastRingTone;
    
    char authKey[AUTHKEY_SIZE];
    char serialKey[ID_SIZE];
    
    NSString *last_IP;
    
    NSTimer *_logTimer1;
    NSTimer *_hideButtonTimer1;
    NSTimer *_timeoutTimer1;
    NSTimer *_updateTimer1;
    NSTimer *_startVideoTimer1;
    NSTimer *_sipErrorTimer1;
    NSTimer *_sipTimeoutTimer1;
    NSDate *_lastAudioVideoTouch;
    NSDate *_lastSysState;
    
    AVAudioPlayer* audioPlayer;
}

@end

@implementation ACViewController

@synthesize lastSysState = _lastSysState;
@synthesize push_token = _push_token;

-(void)linInit {
    if ( !Linphone ) {
        Linphone = [[ACLinphone alloc] init];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.logoImage.hidden = NO;
    CGRect f = [self getLogoImageFrame];
    self.logoImage.frame = f;

    MainVC = self;
    self.btnAudio.tag = self.btnAudio.hidden;
    
    _logTimer1 = nil;
    _hideButtonTimer1 = nil;
    _timeoutTimer1 = nil;
    _updateTimer1 = nil;
    _startVideoTimer1 = nil;
    _sipErrorTimer1 = nil;
    _sipTimeoutTimer1 = nil;
    _Connection = nil;
    _lastSysState = nil;
    last_IP = @"";
    
    lastRingTone = [ACViewController getRingToneID];
    
    self.labelVersion.text = NSLocalizedString(@"Version", nil);
    self.labelStreet.text = [NSString stringWithFormat:@"%@ Armii Krajowej 33", NSLocalizedString(@"st.", nil)];
    self.labelCountry.text = NSLocalizedString(@"Poland", nil);
    
    
    
    if ( [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ) {
        
        right_margin = 20;
        bottom_margin = 50;
        
        if ( [UIScreen mainScreen].bounds.size.height > 480 ) {
            bottom_margin = 100;
        } else {
            bottom_margin = 80;
        }
        
    } else {
        
        right_margin = 40;
        bottom_margin = 120;

    }

    //CGRect f = self.logTextView.frame;
    //CGRect s = [self getScreenSize];
    //f.origin.y = s.size.height - self.btnStatus.frame.origin.y - f.size.height;
    //self.logTextView.frame = f;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(defaultsChanged:)
                   name:NSUserDefaultsDidChangeNotification
                 object:nil];
    
    
    [self connectionInit];

}

- (void)viewDidUnload {
    [self setStatusView:nil];
    [self setLogoImage:nil];
    [self setBtnGate:nil];
    [self setBtnGateway:nil];
    [self setBtnAudio:nil];
    [self setBtnVideo:nil];
    [self setBtnOpen:nil];
    [self setInfoView:nil];
    [self setBtnInfo:nil];
    [self setLogTextView:nil];
    [self setStatusView:nil];
    [self setBtnStatus:nil];
    [self setStatusImage:nil];
    [self setActInd:nil];
    [self setVideoView:nil];
    [self setVideoFrame:nil];
    [self setLabelStreet:nil];
    [self setLabelCountry:nil];
    [self setLabelVersion:nil];
    [super viewDidUnload];
    
}

- (float) logoYpos {
    
    CGRect s = [self getScreenSize];
    
    if ( [self Connected] ) {
        return s.size.height / 4;
    } else {
        return (s.size.height - self.statusView.frame.size.height) / 2 - self.logoImage.frame.size.height;
    }
    
    
}

- (float) btnsYposForVert: (bool) Vert {
    
    if ( Vert ) {
        
        if ( UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ) {
            return bottom_margin;
        } else {
            return [self logoYpos] + self.logoImage.frame.size.height + 10;
        }
        
    } else {
       
        if ( IS_IPHONE_5
             || IS_IPAD
             || SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0") ) {

            return 25;
            
        } else {
            return 2;
        }
    }
    
}

- (float) btnsYpos {
    return [self btnsYposForVert:[self btnsVert]];
}

- (bool) VertForVideoHidden:(bool) hidden {
    if( UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ) {
        return YES;
    } else {
        return hidden;
    }
    
    return NO;
}

- (bool) btnsVert {
    return [self VertForVideoHidden:self.videoView.hidden];
}


#pragma mark Settings Parsers


- (void) keyFromPrefName:(NSString *)pref_name resultBuffer:(char*)result keySize:(int)size keyGenIfEmpty:(BOOL)keyGen {
    
    memset(result, 0, size);
    
    NSString *K = [[NSUserDefaults standardUserDefaults] stringForKey:pref_name];
    
    //if ( [pref_name isEqualToString:@"pref_serialkey"] ) {
    //   K = @"2389-D61F-A67D-1E89";
    //}
    
    if ( K != nil
        && K.length == size*2+size/2-1 ) {
        
        K = [K uppercaseString];
        
        char *kbuff = malloc(K.length+1);
        if ( [K getCString:kbuff maxLength:K.length+1 encoding:NSStringEncodingConversionAllowLossy] ) {
            size = 0;
            for(int a=0;a<K.length;a+=2) {
                
                if ( (a+1)%5 == 0 ) {
                    if ( kbuff[a] != '-' ) {
                        K = nil;
                        break;
                    } else {
                        a++;
                    }
                }
                
                if ( ( kbuff[a] >= 'A' && kbuff[a] <= 'F')
                    || ( kbuff[a] >= '0' && kbuff[a] <= '9' ) ) {
                    kbuff[a]-=kbuff[a]>64 ? 55 : 48;
                    kbuff[a]*=16;
                    kbuff[a+1]-=kbuff[a+1]>64 ? 55 : 48;
                    result[size] = kbuff[a] + kbuff[a+1];
                    size++;
                } else {
                    K = nil;
                    break;
                }
    
            }
        }
        free(kbuff);
        
    } else if ( keyGen ){
 
        for(int a=0;a<size;a++) {
            result[a] = arc4random()%255;
        }
        
        [[NSUserDefaults standardUserDefaults] setValue:[NSString keyToString:result keyLen:size addComma:YES] forKey:pref_name];
    
    } else {
        if ( K == nil ) {
            memset(result, 0, size);
        }
    };
    
}



#pragma mark Connection

- (void) connectionInit {
  
    [self sipTerminate];
    
    if ( _Connection ) {
        [_Connection cancel];
        _Connection = nil;
    }
    
    
    [self keyFromPrefName:@"pref_authkey" resultBuffer:authKey keySize:AUTHKEY_SIZE keyGenIfEmpty:NO];
    [self keyFromPrefName:@"pref_serialkey" resultBuffer:serialKey keySize:ID_SIZE keyGenIfEmpty:NO];
    
    char clientID[ID_SIZE];
    [self keyFromPrefName:@"pref_cid" resultBuffer:clientID keySize:ID_SIZE keyGenIfEmpty:YES];

    NSString *IP = [[NSUserDefaults standardUserDefaults] stringForKey:@"pref_ip"];
    last_IP = [NSString stringWithString:IP == nil ? @"" : IP];
    
    int Port = 465;
    
    if ( IP ) {
        if ( IP.length > 0 ) {
            
            IP = [IP stringByReplacingOccurrencesOfString:@" " withString:@""];
            IP = [IP stringByReplacingOccurrencesOfString:@"," withString:@"."];
            
            NSRange r = [IP rangeOfString:@":"];
            
            if ( r.length > 0 ) {
                NSInteger P = [[IP substringFromIndex:r.location+1] integerValue];
                IP = [IP substringToIndex:r.location];
                if ( P > 0 ) {
                    Port = P;
                }
            }
            
            NSArray *parts = [IP componentsSeparatedByString:@"."];
            if ( !parts
                 || parts.count != 4
                || ![[parts objectAtIndex:0] isIntegerValue]
                || ![[parts objectAtIndex:1] isIntegerValue]
                || ![[parts objectAtIndex:2] isIntegerValue]
                || ![[parts objectAtIndex:3] isIntegerValue] ) {
                IP = nil;
            }

        } else {
            IP = nil;
        }
    }
    
    if ( IP ) {
        _Caps = 0;
        _Status = 0;
        _Connection = [[ACDomophoneConnection alloc] initWithAuthKey:authKey serialKey:serialKey clientID:clientID remoteHostName:IP tcpPort:Port dcStruct:NULL];
        _Connection.eventObject = self;
        _Connection.onDisconnect = @selector(cevent_Disconnected:);
        _Connection.onAuthorize = @selector(cevent_Authorized:);
        _Connection.onUnauthorize = @selector(cevent_Unauthorized:);
        _Connection.onVersionError = @selector(cevent_VersionError:);
        _Connection.onPushRegister = @selector(PushRegister:);
        _Connection.onEvent = @selector(cevent_Event:);
        _Connection.onSysState = @selector(cevent_SysState:);
        _Connection.onLocked = @selector(cevent_Locked:);
        
        [_Connection start];
    } else {
        [self setNotConnectedStatus];
        [self updateLogoAndButtonsPosition];
    }
    
}

- (void) disconnect {
    
    [self sipTerminate];
    
    [_Connection cancel];
    _Connection = nil;
    _Caps = 0;
    _Status = 0;
    
    [self updateLogoAndButtonsPosition];
}

#pragma mark Connection Events

- (void) cevent_Disconnected:(id)obj {
    
    if ( _Connection
        && [_Connection IsAuthorized] ) return;
    
    [self sipTerminate];
    _Caps = 0;
    _Status = 0;
    
    if ( _Connection ) {
        [self setConnectingStatus];
        [self updateLogoAndButtonsPosition];
    }
}

- (void) cevent_Authorized:(id)obj {
    [self setConnectedStatusWithActInd:NO];


    TConnectionSettings *Settings = [obj pointerValue];
    if ( Settings ) {
        
        if ( Settings->Caps & CAP_AUDIO )
            _Caps|=ACDEVCAP_AUDIO;
        
        if ( Settings->Caps & CAP_VIDEO )
            _Caps|=ACDEVCAP_VIDEO;
        
        if ( Settings->Caps & CAP_OPEN1 )
            _Caps|=ACDEVCAP_GATEWAY;
        
        if ( Settings->Caps & CAP_OPEN2 )
            _Caps|=ACDEVCAP_GATE;
        
        if ( Settings->Caps & CAP_GATESENSOR )
            _Caps|=ACDEVCAP_GATE_SENSOR;
        
        if ( Settings->Caps & CAP_GATEWAYSENSOR )
            _Caps|=ACDEVCAP_GATEWAY_SENSOR;
        
        char _serialKey[ID_SIZE];
        [self keyFromPrefName:@"pref_serialkey" resultBuffer:_serialKey keySize:ID_SIZE keyGenIfEmpty:NO];
        if ( memcmp(_serialKey, Settings->SerialKey, ID_SIZE) ) {
            memcpy(serialKey, _serialKey, ID_SIZE);
            [[NSUserDefaults standardUserDefaults] setValue:[NSString keyToString:Settings->SerialKey keyLen:ID_SIZE addComma:YES] forKey:@"pref_serialkey"];
        }
        
    }

    [self updateLogoAndButtonsPosition];
}

- (void) cevent_Unauthorized:(id)obj {
    
    [self disconnect];
    [self setUnauthorizedStatus];

}

- (void) cevent_VersionError:(id)obj {
    
    [self disconnect];
    [self setVersionErrorStatus];
    
}
- (void) cevent_SysState:(id)obj {
   
    _Status = 0;
    int status = [obj intValue];
    _lastSysState = [NSDate date];
    
    if ( [self currentStatus] == STATUS_OPENING
        && !(status & SYS_STATE_OPENING1)
        && !(status & SYS_STATE_OPENING2)
        && !(status & SYS_STATE_OPENING3) ) {
        [self et_onend_es_open];
    }
    
    if ( status & SYS_STATE_GATEISCLOSED ) {
        _Status |= ACDEVSTATUS_GATEISCLOSED;
    }
    
    if ( status & SYS_STATE_GATEWAYISCLOSED ) {
        _Status |= ACDEVSTATUS_GATEWAYISCLOSED;
    }
    
    if ( status & SYS_STATE_PROXYREGISTERED ) {
        _Status |= ACDEVSTATUS_CLOUD_CONNECTED;
    }
     
}

- (void) et_onend_es_open {
    
    self.btnOpen.enabled = YES;
    
    if ( [self currentStatus] == STATUS_OPENING ) {
        [self stopWaitingForOpenTimeoutTimer];
        [self setConnectedStatusWithActInd:NO];
    }
    [self startHideOpenButtonTimer];
}

- (void) et_onend_sip {
    
    if ( [self currentStatus] == STATUS_WAITING
        || [self currentStatus] == STATUS_CONNECTED ) {
        [self setConnectedStatusWithActInd:NO];
    }

}

- (void) cevent_Locked:(id)obj {
    
    [self insertLogItem: [NSString stringWithFormat:NSLocalizedString(@"Locked by %@", NULL), obj]  senderName:nil showLog:YES];
    [self et_onend_es_open];
    [self sipTerminateWithBySendAction:NO];
    
}

+ (long)getRingToneID {
    NSInteger rid = [[NSUserDefaults standardUserDefaults] integerForKey:@"pref_ringtone"];
    if ( rid <= 0 || rid > 18 ) rid = 1;
    
    return rid;
}

- (void) playRingtoneId:(NSInteger) rid {
    audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"ring%li", (long)rid] ofType:@"mp3"]] error:NULL];
    [audioPlayer play];
}

- (void) cevent_Event:(id)obj {
    
    TdEvent *Event = [obj pointerValue];

    if ( Event->Type == ET_ONBEGIN
        && Event->Scope == ES_RING ) {
        
         NSInteger rid = [ACViewController getRingToneID];
        
         UILocalNotification* localNotification = [[UILocalNotification alloc] init];
         localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:0];
         localNotification.alertBody = @"Dzwoni...";
          localNotification.soundName = [NSString stringWithFormat:@"ring%li.mp3", (long)rid];
         localNotification.timeZone = [NSTimeZone defaultTimeZone];
         [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        
         [self insertLogItem: NSLocalizedString(@"CALLING...", nil) senderName:@"DOMOPHONE" showLog:YES];
        
         if ( [UIApplication sharedApplication].applicationState == UIApplicationStateActive ) {
            
             [self playRingtoneId:rid];
         }
        
    } else if ( Event->Type == ET_ONBEGIN ) {
        
        if ( Event->Scope == ES_OPEN ) {
            [self setOpeningStatus];
        }
        
        if ( !Event->Owner ) {
            if (  Event->Scope == ES_OPEN
                  && ( Event->Param1 == ACTION_OPEN1
                      || Event->Param1 == ACTION_OPEN2 ) ) {
                [self insertLogItem: Event->Param1 == ACTION_OPEN1 ? NSLocalizedString(@"Gateway opening", nil) : NSLocalizedString(@"Opening / closing the gate", nil) senderName:[NSString stringWithUTF8String:Event->SenderName] showLog:YES];
            } else if ( Event->Scope == ES_SIP ) {
                [self insertLogItem: NSLocalizedString(@"Audio/video connection started", nil) senderName:[NSString stringWithUTF8String:Event->SenderName] showLog:YES];
            }
        }

        
        
    } else if ( Event->Type == ET_ONEND
               && Event->Scope == ES_OPEN ) {
        [self et_onend_es_open];

    } else if ( Event->Type == ET_ONEND
                && Event->Scope == ES_SIP ) {
        if ( Event->Owner == 1 ) {
           [self sipTerminate]; 
        } else {
            [self insertLogItem: NSLocalizedString(@"Audio/video connection finished", nil) senderName:[NSString stringWithUTF8String:Event->SenderName] showLog:YES];
        }
        
    }
}


- (void) PushRegister:(id)obj {
    if ( _Connection ) {
        [_Connection RegisterPushID:self.push_token ? [NSData dataWithData:self.push_token] : nil];
    }
}

- (void) PushRegister {
    [self PushRegister:nil];
}

#pragma mark Status Section

- (int)currentStatus {
    return self.statusImage.tag;
}

- (void)setStatusText:(NSString*)txt {
    [self.btnStatus setTitle:txt forState:UIControlStateNormal];
    [self.btnStatus setTitle:txt forState:UIControlStateHighlighted];
    [self.btnStatus setTitle:txt forState:UIControlStateDisabled];
}

- (void)setStatusColor:(UIColor*) color {
    [self.btnStatus setTitleColor:color forState:UIControlStateNormal];
    [self.btnStatus setTitleColor:color forState:UIControlStateHighlighted];
    [self.btnStatus setTitleColor:color forState:UIControlStateDisabled];
}

- (void)setBaseStatus:(NSString*)txt imageName:(NSString*)img statusId:(int)sid {
    self.statusImage.hidden = NO;
    self.statusImage.tag = sid;
    self.actInd.hidden = YES;
    [self setStatusText:txt];
    [self.statusImage setImage:[UIImage imageNamed:img]];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
}

- (void)setActStatus:(NSString*)txt statusId:(int)sid {
    self.statusImage.hidden = YES;
    self.statusImage.tag = sid;
    self.actInd.hidden = NO;
    [self setStatusText:txt];
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
}

- (void)setConnectingStatus {
    [self setActStatus:NSLocalizedString(@"Connecting...", nil) statusId:STATUS_CONNECTING];
}

- (void)setUnauthorizedStatus {
    [self setBaseStatus:NSLocalizedString(@"Invalid authorization key", nil) imageName:@"key.3png" statusId:STATUS_AUTHERROR];
}

- (void)setNotConnectedStatus {
    [self setBaseStatus:NSLocalizedString(@"No connection", nil) imageName:@"error@x2.png" statusId:STATUS_CONNECTIONERROR];
}

- (void)setVersionErrorStatus {
    [self setBaseStatus:NSLocalizedString(@"Compatibility Error", nil) imageName:@"error@x2.png" statusId:STATUS_COMPATERROR];
}

- (void)setConnectedStatusWithActInd:(BOOL)ai {
    if ( ai ) {
        [self setActStatus:NSLocalizedString(@"Connected", nil) statusId:STATUS_CONNECTED];
    } else {
        [self setBaseStatus:NSLocalizedString(@"Connected", nil) imageName:@"ok@x2.png" statusId:STATUS_CONNECTED];    
    }
}

- (void)setOpeningStatus {
    [self setActStatus:NSLocalizedString(@"Opening...", nil) statusId:STATUS_OPENING];
}

- (void)setWaitingStatus {
    [self setActStatus:NSLocalizedString(@"Waiting...", nil) statusId:STATUS_WAITING];
}

#pragma mark Animations

- (void)showActionButtons:(BOOL)show completion:(void (^)(BOOL finished))Completion {
    
    if ( ![self Connected] ) {
        show = NO;
    }
    
    if ( !show && self.btnAudio.tag ) {
        if ( Completion ) Completion(YES);
        return;
    }

    CGRect s = [self getScreenSize];
    CGRect f = self.btnAudio.frame;
    
    float start;
    float end;
    
    int bcount = 1;
    int spaceing;
    
    if ( _Caps & ACDEVCAP_VIDEO ) bcount++;
    if ( _Caps & ACDEVCAP_GATEWAY ) bcount++;
    if ( _Caps & ACDEVCAP_GATE ) bcount++;
    

    bool vert = [self btnsVert];
    float btnsYpos = [self btnsYpos];
    
    if ( vert ) {
        
        start = show ? s.size.width + f.size.width : s.size.width - f.size.width - right_margin;
        end = show ? s.size.width - f.size.width - right_margin : s.size.width + f.size.width;
       
        
        f.origin.x = f.origin.x == end ? end : start;
        f.origin.y =  s.size.height - f.size.height - bottom_margin;

        spaceing = ((s.size.height - btnsYpos - bottom_margin ) - ( bcount * f.size.height )) / (bcount-1) + f.size.height;
        
        
    } else {
        start = show ? f.size.height*-1 : btnsYpos;
        end = show ? btnsYpos : f.size.height*-1;
        
        f.origin.y = f.origin.y == end && f.origin.x == 260 ? end : start;
        f.origin.x = s.size.width - right_margin - f.size.width;
        spaceing = ((s.size.width - right_margin * 2 ) - ( bcount * f.size.width )) / (bcount-1) + f.size.width;
    };
    

    if ( _Caps & ACDEVCAP_VIDEO ) {
        self.btnVideo.frame = f;
        
        if ( vert ) {
            f.origin.y -= spaceing;
        } else {
            f.origin.x -= spaceing;
        }
        
    }

    self.btnAudio.frame = f;
    
    if ( vert ) {
        f.origin.y -= spaceing;
    } else {
        f.origin.x -= spaceing;
    }
    
    if ( _Caps & ACDEVCAP_GATEWAY ) {
        self.btnGateway.frame = f;
        
        if ( vert ) {
            f.origin.y -= spaceing;
        } else {
            f.origin.x -= spaceing;
        }
    }
    
    if ( _Caps & ACDEVCAP_GATE ) {
        self.btnGate.frame = f;
    }
    
    
    self.btnGate.hidden = !(_Caps & ACDEVCAP_GATE);
    self.btnGateway.hidden = !(_Caps & ACDEVCAP_GATEWAY);
    self.btnAudio.hidden = !(_Caps & ACDEVCAP_AUDIO);
    self.btnVideo.hidden = !(_Caps & ACDEVCAP_VIDEO);
    
    
    [UIView animateWithDuration:0.5 animations:^{
        

        CGRect f = self.btnGate.frame;
        if ( vert ) {
           f.origin.x = end;
        } else {
           f.origin.y = end;
        }
        self.btnGate.frame = f;
        
        f = self.btnGateway.frame;
        if ( vert ) {
            f.origin.x = end;
        } else {
            f.origin.y = end;
        }
        self.btnGateway.frame = f;
        
        f = self.btnAudio.frame;
        if ( vert ) {
            f.origin.x = end;
        } else {
            f.origin.y = end;
        }
        self.btnAudio.frame = f;
        
        f = self.btnVideo.frame;
        if ( vert ) {
            f.origin.x = end;
        } else {
            f.origin.y = end;
        }
        self.btnVideo.frame = f;

    } completion:^(BOOL finished){
        
        self.btnGate.hidden =  self.btnGate.hidden || !show;
        self.btnGateway.hidden = self.btnGateway.hidden || !show;
        self.btnAudio.hidden = self.btnAudio.hidden || !show;
        self.btnAudio.tag = !show;
        self.btnVideo.hidden = self.btnVideo.hidden || !show;
        
        if ( Completion ) Completion(YES);
    }];
    
};

- (CGRect) getLogoImageFrame {
    
    CGRect f = self.logoImage.frame;
    f.origin.x = [self getScreenSize].size.width / 2 - f.size.width / 2;
    f.origin.y = [self logoYpos];
    
    return f;
}

- (void)moveLogoWithAnimationFromYposition:(float)startPos toYposition:(float)endPos completion:(void (^)(BOOL finished))Completion {
    
    if ( self.logoImage.frame.origin.y == endPos ) {
        if ( Completion ) Completion(YES);
        return;
    }
     
    CGRect f = [self getLogoImageFrame];
    f.origin.y = startPos;
    
    self.logoImage.frame = f;
    self.logoImage.hidden = NO;
    
    [UIView animateWithDuration:0.5 animations:^{
        CGRect f = self.logoImage.frame;
        f.origin.y = endPos;
        self.logoImage.frame = f;
    } completion:Completion];
    

};

- (void)showLogoImage:(BOOL)show completion:(void (^)(BOOL finished))Completion{
    
    float s = [self logoYpos];
    
    [self moveLogoWithAnimationFromYposition:(show ? (self.logoImage.frame.size.height*-1) : s) toYposition:(show ? s : (self.logoImage.frame.size.height*-1) ) completion:^(BOOL finished){
        self.logoImage.hidden = !show;
        if ( Completion ) {
            Completion(YES);
        }
    }];

}


- (BOOL)Connected {
    return _Connection && _Connection.connected;
}

- (void)updateLogoAndButtonsPosition {
    
    if ( self.infoView.hidden == NO && self.videoView.hidden == NO ) {
        [self updateWithDelay];
        [self infoTouch:self.btnInfo];
        return;
    }
    
    if ( self.infoView.hidden == NO || !self.btnInfo.enabled ) return;
    
    if ( self.logoImage.tag == 1 ) {
        [self updateWithDelay];
        return;
    }
    
    self.logoImage.tag = 1;
    
    if ([self Connected]) {
        
        if ( self.videoView.hidden ) {
            self.logoImage.hidden = NO;
            [self moveLogoWithAnimationFromYposition:self.logoImage.frame.origin.y toYposition:[self logoYpos] completion:^(BOOL finished){
                [self showActionButtons:YES completion:^(BOOL finished){
                    self.logoImage.tag = 0;
                }];
            }];
        } else {
            self.logoImage.hidden = YES;
            [self showActionButtons:YES completion:^(BOOL finished){
                self.logoImage.tag = 0;
            }];
        }
        
    } else {
        
        if ( !self.btnOpen.hidden ) {
            self.btnOpen.hidden = YES;
        };
        
        if ( self.infoView.hidden == NO ) {
            self.infoView.hidden = YES;
        };
        
        [self showActionButtons:NO completion:^(BOOL finished){
            [self moveLogoWithAnimationFromYposition:self.logoImage.frame.origin.y toYposition:[self logoYpos] completion:^(BOOL finished){
                self.logoImage.tag = 0;
            }];
        }];
    }
    

}

- (void)moveOpenButton:(int)type andHide:(BOOL)hide completion:(void (^)(void))Completion {
    
    if ( self.btnGate.enabled == NO || self.btnOpen.hidden == hide ) return;
    
    CGRect f = self.btnOpen.frame;
    
    /*
    if ( [UIScreen mainScreen].bounds.size.height <= 480
        && !self.videoView.hidden ) {
        f.size.width = 90;
        f.size.height = 90;
    } else {
        f.size.width = 120;
        f.size.height = 120;
    }
     */
    
    self.btnGate.enabled = NO;
    self.btnGateway.enabled = NO;
    
    CGRect s = [self getScreenSize];
    
    float y = [self logoYpos] + self.logoImage.frame.size.height;

    if ( y < [self btnsYpos] ) {
        y = [self btnsYpos];
    }
    
    float centerPoint = ( self.videoView.hidden ? ( self.btnAudio.frame.origin.x + self.btnAudio.frame.size.width / 2 ) / 2 : s.size.width/2 ) - f.size.width/2;
    float n = self.videoView.hidden ? y : self.videoView.frame.origin.y + self.videoView.frame.size.height;

    f.origin.x = hide ? centerPoint : f.size.width * -1;
    f.origin.y = ( s.size.height - n - self.statusView.frame.size.height ) / 2 + n - f.size.height/2 - 10;
    self.btnOpen.frame = f;
    self.btnOpen.hidden = NO;

    if ( hide == NO ) {
        if ( self.btnOpen.tag != type ) {
            switch(type) {
                case ACBUTTONTYPE_GATE:
                    [self.btnOpen setImage:[UIImage imageNamed:@"gate512x512_g.png"] forState:UIControlStateNormal];
                    [self.btnOpen setImage:[UIImage imageNamed:@"gate512x512_hl.png"] forState:UIControlStateHighlighted];
                    [self.btnOpen setImage:[UIImage imageNamed:@"gate512x512_hl.png"] forState:UIControlStateDisabled];
                    break;
                case ACBUTTONTYPE_GATEWAY:
                    [self.btnOpen setImage:[UIImage imageNamed:@"gateway512x512_g.png"] forState:UIControlStateNormal];
                    [self.btnOpen setImage:[UIImage imageNamed:@"gateway512x512_hl.png"] forState:UIControlStateHighlighted];
                    [self.btnOpen setImage:[UIImage imageNamed:@"gateway512x512_hl.png"] forState:UIControlStateDisabled];
                    break;
            }
            self.btnOpen.tag = type;
        }
        
        [self startHideOpenButtonTimer];
        self.btnOpen.enabled = YES;
    }


    
    [UIView animateWithDuration:0.25 animations:^{
        CGRect f = self.btnOpen.frame;
        f.origin.x = hide ? -200 : centerPoint;
        self.btnOpen.frame = f;
    } completion:^(BOOL finished){
        self.btnOpen.hidden = hide;
        self.btnGate.enabled = YES;
        self.btnGateway.enabled = YES;
        if ( Completion ) Completion();
    }];
}

#pragma mark Touch Events


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if ( !self.btnOpen.enabled ) {
        for (UITouch *touch in touches) {
            CGPoint location = [touch locationInView:touch.view];
            if( CGRectContainsPoint(self.btnOpen.frame, location) )
               return;
        };
    };
    
    if ( touches )
    [self moveOpenButton:0 andHide:YES completion:nil];
    
    if ( !self.infoView.hidden ) {
        [self infoTouch:self.btnInfo];
    }
    
    [self hideLogTextView];
    
    [super touchesBegan:touches withEvent:event];
}

- (IBAction)infoTouch:(id)sender {

    // Może być wywołane z touchesBegan
    if (!self.btnInfo.enabled) return;
    //---------------------------------
    
    bool hidden = self.infoView.hidden;
    self.btnInfo.enabled = NO;
    
    [self showActionButtons:!hidden completion:nil];
    [self showLogoImage:!hidden completion:nil];
    [self hideLogTextView];
    
    if ( !self.btnOpen.hidden ) {
        self.btnOpen.hidden = YES;
    };
    
    CGRect f = self.infoView.frame;
    CGRect s = [self getScreenSize];
    f.origin.x = hidden ? self.infoView.frame.size.width * -1 : s.size.width / 2 - self.infoView.frame.size.width / 2;
    f.origin.y = ( s.size.height / 2 - f.size.height / 2 ) -20;
    self.infoView.frame = f;
    
    self.infoView.hidden = NO;
    
    [UIView animateWithDuration:0.5 animations:^{
        CGRect f = self.infoView.frame;
        f.origin.x = hidden ? s.size.width / 2 - self.infoView.frame.size.width / 2 : self.infoView.frame.size.width * -1;
        self.infoView.frame = f;
    } completion:^(BOOL finished){
        self.infoView.hidden = !hidden;
        self.btnInfo.enabled = YES;
    }];
    
}
- (IBAction)openTouch:(id)sender {
    if ( _Connection ) {
        
        self.btnOpen.enabled = NO;
        [self setOpeningStatus];
        [self startWaitingForOpenTimeoutTimer];
        
        if ( self.btnOpen.tag == ACBUTTONTYPE_GATE ) {
            [_Connection openGate];
        } else if ( self.btnOpen.tag == ACBUTTONTYPE_GATEWAY ) {
            [_Connection openGateway];
        }
    }
}

- (IBAction)gateTouch:(id)sender {
    
    int type = sender == self.btnGate ? ACBUTTONTYPE_GATE : ACBUTTONTYPE_GATEWAY;
    
    if ( self.btnOpen.tag == type && !self.btnOpen.hidden ) {
      [self moveOpenButton:type andHide:YES completion:nil];
    } else {
        if ( self.btnOpen.hidden == NO ) {
            [self moveOpenButton:type andHide:YES completion:^{
                [self moveOpenButton:type andHide:NO completion:nil];
            }];
        } else {
            [self moveOpenButton:type andHide:NO completion:nil];
        }
    }
    
}

-(void)startAudioVideoConnection:(NSTimer*)timer {
    NSString *SipServer = _Connection ? [_Connection SipServer] : nil;
    if ( SipServer
         && SipServer.length > 0 ) {
        
        NSLog(@"SipServer=%@", SipServer);
        
        [self startSipTimeoutTimer];
        [self linInit];
        if ( timer.userInfo == self.btnAudio ) {
            Linphone.AudioEnabled = YES;
            if ( Linphone.ActiveCall ) {
                [_Connection SipConnectWithVideo:YES andSpeakerOn:Linphone.AudioEnabled];
            }
        }

        [Linphone resetRetryCounter];
        [Linphone registerWithIdent:[self getSipIdent] host:SipServer];
    }

}

-(void)setMicrophoneGain {
    
    NSNumber *n = [[NSUserDefaults standardUserDefaults] valueForKey:@"pref_mic_gain"];
    
    [Linphone setMicGain:n == NULL ? 3 : [n intValue]];
    
}

- (IBAction)audioVideoTouch:(id)sender {
    
    
    float Diff = 4;
    
    if ( _lastAudioVideoTouch )
        Diff = [[NSDate date] timeIntervalSinceDate: _lastAudioVideoTouch];
    
    _lastAudioVideoTouch = [NSDate date];
       
    if ( ( sender == self.btnVideo
            && self.videoView.hidden )
        || ( sender == self.btnAudio
            &&  Linphone.AudioEnabled == NO )) {
            
        if ( _Connection ) {
            
            BOOL ActiveCall = Linphone && [Linphone ActiveCall];
            
            [self setConnectedStatusWithActInd:!ActiveCall];
            
            if ( sender == self.btnAudio ) {
                 [self changeBtnImage:self.btnAudio imageName:@"mic_on.png"];
                
                [self setMicrophoneGain];
                [_Connection SetSpeakerOn:YES];
                
                if ( ActiveCall ) {
                    Linphone.AudioEnabled = YES;
                    return;
                };
                
                
            }
            
            [self changeBtnImage:self.btnVideo imageName:@"video_on.png"];
            if ( Diff > 3 ) {
                Diff = 0.25;
            }
            
            if ( _startVideoTimer1 ) {
                [_startVideoTimer1 invalidate];
            }
            _startVideoTimer1 = [NSTimer scheduledTimerWithTimeInterval:Diff target:self selector:@selector(startAudioVideoConnection:) userInfo:sender repeats:NO];
        }
    } else {
        NSLog(@"audioVideoTouch:sipDisconnect");
        [self sipDisconnect];
    }
    

    
    _lastAudioVideoTouch = [NSDate date];
}



- (IBAction)homepageTouch:(id)sender {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.domophone.eu"]]; 
}

- (IBAction)acPageTouch:(id)sender {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.acsoftware.pl"]]; 
}


- (IBAction)statusTouch:(id)sender {

    if ( self.logTextView.tag ) return;
    
    self.logTextView.tag = 1;
    
    self.logTextView.tag = self.logTextView.hidden ? 2 : 3;
    
    self.logTextView.alpha = self.logTextView.tag == 2 ? 0 : 0.5;
    self.logTextView.hidden = NO;
    
    [UIView animateWithDuration:1 animations:^{
        self.logTextView.alpha = self.logTextView.tag == 2 ? 0.5 : 0;
    } completion:^(BOOL finished){
        
        self.logTextView.hidden = self.logTextView.tag == 3;
        self.logTextView.tag = 0;
        if ( self.logTextView.hidden ) {
            self.logTextView.text = @"";
        }
        [self startLogTimer1];
        
    }];
    
}



#pragma mark Memory Warning

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Notifications

- (void)defaultsChanged:(NSNotification *)notification {

    char _authKey[AUTHKEY_SIZE];
    char _serialKey[ID_SIZE];
    
    NSString *IP = [[NSUserDefaults standardUserDefaults] stringForKey:@"pref_ip"];
    
    
    [self keyFromPrefName:@"pref_authkey" resultBuffer:_authKey keySize:AUTHKEY_SIZE keyGenIfEmpty:NO];
    [self keyFromPrefName:@"pref_serialkey" resultBuffer:_serialKey keySize:ID_SIZE keyGenIfEmpty:NO];
    
    if ( ![IP isEqual:last_IP]
        || memcmp(_authKey, authKey, AUTHKEY_SIZE) != 0
        || memcmp(_serialKey, serialKey, ID_SIZE) != 0 ) {
        
       [self connectionInit]; 
    }
    
    
    NSInteger rid = [ACViewController getRingToneID];
    
    if ( lastRingTone != rid ) {
        lastRingTone = rid;
        
        [self playRingtoneId:rid];
    }
}



#pragma mark SIP

-(NSString *)getSipIdent {
    
    char clientID[ID_SIZE];
    [self keyFromPrefName:@"pref_cid" resultBuffer:clientID keySize:ID_SIZE keyGenIfEmpty:NO];
    
    return [NSString stringWithFormat:@"%@-%@", [NSString keyToString:clientID keyLen:ID_SIZE addComma:NO], [NSString keyToString:serialKey keyLen:ID_SIZE addComma:NO]];
}

-(void)sipRegistered {
    if ( _Connection
        && Linphone
        && ![Linphone ActiveCall] ) {
            [self setConnectedStatusWithActInd:YES];
            [_Connection SipConnectWithVideo:YES andSpeakerOn:Linphone.AudioEnabled];
    };
}


-(void)sipTerminateWithBySendAction:(BOOL)SendAction {
    
    [self stopSipTimeoutTimer];
    [self sipDisconnectWithouthTerminate:YES bySendAction:SendAction];
    
    if ( Linphone ) {
        [Linphone clean];
        Linphone.AudioEnabled = NO;
    };
    

    [self et_onend_sip];
}

-(void)sipTerminate {
    [self sipTerminateWithBySendAction:YES];
}

- (void) sipDisconnect {
    [self sipDisconnectWithouthTerminate:NO bySendAction:YES];
}

- (void) sipDisconnectWithouthTerminate:(BOOL)wt bySendAction:(BOOL)sa {
    
    if ( _startVideoTimer1 ) {
        [_startVideoTimer1 invalidate];
        _startVideoTimer1 = nil;
    }
    
    [self changeBtnImage:self.btnAudio imageName:@"mic_g.png"];
    [self sipVideoStopped];
    
    if ( sa && _Connection ) {
        NSLog(@"sipDisconnectWithouthTerminate:SipDisconnect, wt=%i, sa=%i", wt, sa);
        [_Connection SipDisconnect];
    } else if ( wt == NO ) {
        [self sipTerminate];
    };
    
    if ( Linphone ) {
        [Linphone terminateCall];
    }
    
}

-(void)sipCallStarted {
    
    if ( !self.videoView.hidden ) {
        return;
    }
    
    [self videoWindowVisible:YES];
    
    [self stopSipTimeoutTimer];
    if ( !Linphone || !self.videoView.hidden ) {
        [self setConnectedStatusWithActInd:NO];
    };
    
    if ( Linphone.AudioEnabled ) {
        [self setMicrophoneGain];
    }

    [Linphone speakerOn];
    [self lpDelayedSpeakerOn];
    [MainVC updateLogoAndButtonsPosition];
}

-(void)sipVideoStarted {
    
    [self videoWindowVisible:YES];
    /*
    if ( self.currentStatus == STATUS_WAITING
        || [self currentStatus] == STATUS_CONNECTED) {
        [self setConnectedStatusWithActInd:NO];
    }
    [MainVC updateLogoAndButtonsPosition];
    [Linphone speakerOn];
    [self lpDelayedSpeakerOn];
    */
    
}

- (void)lpSpeakerOn:(NSTimer*)timer {
    if ( Linphone ) {
        [Linphone speakerOn];
    }
}

-(void)lpDelayedSpeakerOn {
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(lpSpeakerOn:) userInfo:nil repeats:NO];
}

-(void)sipVideoStopped {
    
    [self changeBtnImage:self.btnVideo imageName:@"video_g.png"];
    
    [self videoWindowVisible:NO];
    [self updateLogoAndButtonsPosition];
}


#pragma mark Video Window

-(void)changeBtnImage:(UIButton*)btn imageName:(NSString *)img {
    [btn setImage:[UIImage imageNamed:img] forState:UIControlStateNormal];
    [btn setImage:[UIImage imageNamed:img] forState:UIControlStateHighlighted];
    [btn setImage:[UIImage imageNamed:img] forState:UIControlStateDisabled];
}

-(void)videoWindowVisible:(BOOL)visible {

    if ( self.videoView.hidden == YES ) {
        [self.videoFrame setBackgroundColor:[UIColor lightGrayColor]];
        self.labelVideoInit.hidden = NO;
    } else {
        [self.videoFrame setBackgroundColor:[UIColor blackColor]];
        self.labelVideoInit.hidden = YES;
    }
    
    if ( visible != self.videoView.hidden ) {
        return;
    }
    
    if ( visible ) {
        
        /*
        if (  _lastAudioVideoTouch ) {
            
            [self insertLogItem: [NSString stringWithFormat:@"Czas: %f", [[NSDate date] timeIntervalSinceDate:_lastAudioVideoTouch]]  senderName:nil showLog:YES];
        };
         */
        
        self.btnGate.hidden = YES;
        self.btnGateway.hidden = YES;
        self.btnVideo.hidden = YES;
        self.btnAudio.hidden = YES;
        self.btnOpen.hidden = YES;
        self.logTextView.hidden = YES;
        self.btnInfo.hidden = YES;
        
        CGRect s = [self getScreenSize];
        
        CGRect f = self.videoView.frame;
        
        if ( UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ) {
            
            f.origin.y = 40;
            f.origin.x = 120;
            
        } else {
            
            if ( SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")
                 && IS_IPHONE
                 && ! IS_IPHONE_5 ) {
                f.origin.y = [self btnsYposForVert: [self VertForVideoHidden:NO]] + self.btnVideo.frame.size.height;
            } else {
                f.origin.y = [self btnsYposForVert: [self VertForVideoHidden:NO]] * 2 + self.btnVideo.frame.size.height;
            }
            
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                
                f.origin.x = s.size.width / 2 - self.videoFrame.frame.size.width / 2;
                
            }
        
            
        }

        self.videoView.frame = f;
        self.videoView.hidden = NO;
    } else {
        self.btnInfo.hidden = NO;
        self.videoView.hidden = YES;
        
        if ( self.btnOpen.hidden == NO ) {
            self.btnOpen.hidden = YES;
        }
    }

}

#pragma mark Timers

- (NSTimer*)startTimer:(NSTimer*)timer withTimeInterval:(int)interval selector:(SEL)_sel{
    if ( timer ) {
        [timer invalidate];
    }
    
    return [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:_sel userInfo:nil repeats:NO];
}

- (void)startLogTimer1 {
    if ( !self.logTextView.hidden ) {
        _logTimer1 = [self startTimer:_logTimer1 withTimeInterval:15 selector:@selector(hideLogTextView)];
    }
};

- (void)hideLogTextView {
    if ( !self.logTextView.hidden )  
        [self statusTouch:self.btnStatus];

}

- (void)startHideOpenButtonTimer {
    if ( !self.btnOpen.hidden )
        _hideButtonTimer1 = [self startTimer:_hideButtonTimer1 withTimeInterval:5 selector:@selector(hideOpenButton)];
}

- (void)updateWithDelay {
    _updateTimer1 = [self startTimer:_updateTimer1 withTimeInterval:1 selector:@selector(updateLogoAndButtonsPosition)];
}

- (void)hideOpenButton {
    if ( !self.btnOpen.hidden )  {
        if ( [self currentStatus] != STATUS_OPENING ) {
            [self moveOpenButton:0 andHide:YES completion:nil];
            _hideButtonTimer1 = nil;
        }
    }
}


- (void)showSipTimeoutError:(NSTimer*)timer {
    
    if ( self.btnVideo.tag < 10 ) {
        
        NSString *v = ((self.btnVideo.tag & 1) == 1) ? @"w" : @"r";
        
        [self.btnVideo setImage:[UIImage imageNamed:[NSString stringWithFormat:@"video_%@.png", v]] forState:UIControlStateDisabled];
        [self.btnAudio setImage:[UIImage imageNamed:[NSString stringWithFormat:@"mic_%@.png", v]] forState:UIControlStateDisabled];
        
        self.btnVideo.tag = self.btnVideo.tag+1;
    } else {
        
        self.btnVideo.enabled = YES;
        self.btnAudio.enabled = YES;
        
        if ( _sipErrorTimer1 ) {
            [_sipErrorTimer1 invalidate];
            _sipErrorTimer1 = nil;
        };
    }
    
}

- (void)startSipShowErrorTimer {
    
    if ( _sipErrorTimer1 ) {
        [_sipErrorTimer1 invalidate];
    }
    
    self.btnVideo.tag = 0;
    self.btnVideo.enabled = NO;
    self.btnAudio.enabled = NO;
    
    _sipErrorTimer1 = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(showSipTimeoutError:) userInfo:nil repeats:YES];
}

- (void)onSipTimeout:(NSTimer*)timer {

    [self startSipShowErrorTimer];
    [self sipTerminate];

}

- (void)stopSipTimeoutTimer {
    if ( _sipTimeoutTimer1 ) {
        [_sipTimeoutTimer1 invalidate];
    }
    _sipTimeoutTimer1 = nil;
};

- (void)startSipTimeoutTimer {
    if ( Linphone == nil || Linphone.ActiveCall == NO ) {
        _sipTimeoutTimer1 = [self startTimer:_sipTimeoutTimer1 withTimeInterval:20 selector:@selector(onSipTimeout:)];
    }
}

-(void)startWaitingForOpenTimeoutTimer {
    _timeoutTimer1 = [self startTimer:_timeoutTimer1 withTimeInterval:30 selector:@selector(waitingForOpenTimeout)];
}

-(void)stopWaitingForOpenTimeoutTimer {
    if ( _timeoutTimer1 ) {
        [_timeoutTimer1 invalidate];
    }
    _timeoutTimer1 = nil;
};

-(void)waitingForOpenTimeout {
    
    TdEvent Event;
    Event.Scope = ES_OPEN;
    Event.Type = ET_ONEND;
    
    [self cevent_Event:[NSValue valueWithPointer:&Event]];

}

#pragma mark Others

-(void)insertLogItem:(NSString *)text senderName:(NSString*)name showLog:(BOOL)show{
    if ( self.logTextView.hidden
        && show) {
        [self statusTouch:self.btnStatus];
    } else {
        [self startLogTimer1];
    }
    
    
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"hh:mm"];
    
    if ( name ) {
        self.logTextView.text = [NSString stringWithFormat:@"%@\n%@ %@ - %@", self.logTextView.text, [dateFormatter stringFromDate:[NSDate date]], name, text];
    } else {
         self.logTextView.text = [NSString stringWithFormat:@"%@\n%@ - %@", self.logTextView.text, [dateFormatter stringFromDate:[NSDate date]], text];
    }
    
    
    CGRect f = self.logTextView.frame;
    
    if ( self.logTextView.contentSize.height >= 75 ) {
        f.size.height = 75;
    } else {
        f.size.height = self.logTextView.contentSize.height;
    }
    
    f.origin.y = self.statusView.frame.origin.y - f.size.height;
    self.logTextView.frame = f;
    
    [self.logTextView scrollRangeToVisible:NSMakeRange([self.logTextView.text length], 0)];
   

}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    self.logoImage.hidden = YES;
    self.btnAudio.hidden = YES;
    self.btnVideo.hidden = YES;
    self.btnGateway.hidden = YES;
    self.btnGate.hidden = YES;
    self.infoView.hidden = YES;
    self.btnOpen.hidden = YES;

    CGRect f = self.btnGate.frame;
    CGRect s = [self getScreenSize];
    f.origin.x = s.size.width + f.size.width;
    self.btnAudio.frame = f;
    self.btnVideo.frame = f;
    self.btnGateway.frame = f;
    self.btnGate.frame = f;
    
    f = self.logoImage.frame;
    f.origin.y = f.size.height * -1;
    self.logoImage.frame = f;
    
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
    [self videoWindowVisible:!self.videoView.hidden];
    [self updateLogoAndButtonsPosition];
    
    
}

- (CGRect)getScreenSize {
    
    CGRect s = [[UIScreen mainScreen] bounds];
    
    if( UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ) {
        float w = s.size.width;
        s.size.width = s.size.height;
        s.size.height = w;
    }
    
    return s;
}

@end
