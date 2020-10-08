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

#import "ACLinphone.h"
#import "ACViewController.h"
#include <mediastreamer2/mscommon.h>
#include <linphone/linphonecore.h>

#define DEFAULT_EXPIRES 600

#if __clang__ && __arm__
extern int __divsi3(int a, int b);
int __aeabi_idiv(int a, int b) {
	return __divsi3(a,b);
}
#endif

extern void libmsamr_init(MSFactory *factory);
extern void libmsx264_init(MSFactory *factory);
extern void libmsopenh264_init(MSFactory *factory);
extern void libmssilk_init(MSFactory *factory);
extern void libmswebrtc_init(MSFactory *factory);

ACLinphone *Linphone = nil;

@implementation ACLinphone {
    LinphoneCore *lc;
    NSTimer *_iterateTimer;
    BOOL _AudioEnabled;
    BOOL _RegistrationInProgress;
    int _retryCounter;
    NSString *lastIdent;
    NSString *lastHost;
    LpConfig *_configDb;
}


static void showVideoView(LinphoneCall* lc, void* user_data);

-(void) onCallState:(LinphoneCore *)lcptr  callPtr:(LinphoneCall*)callptr callState:(LinphoneCallState)state msg:(const char*)message {
    switch(state) {
        case LinphoneCallIncomingReceived:
            self.AudioEnabled = _AudioEnabled;
            
            linphone_call_accept(callptr);
            break;
        case LinphoneCallStreamsRunning:
            [MainVC sipCallStarted];

            
            if (linphone_call_params_video_enabled(linphone_call_get_current_params(callptr))) {
                linphone_core_set_native_video_window_id(lcptr, (__bridge void *)MainVC.videoFrame);
                linphone_call_set_next_video_frame_decoded_callback(callptr, showVideoView, NULL);
            } else {
                LinphoneCallParams *call_params = linphone_core_create_call_params(lc, callptr);
                linphone_call_params_enable_video(call_params, YES);
                linphone_core_update_call(lc, callptr, call_params);
                linphone_call_params_destroy(call_params);
            }
            
            break;
        case LinphoneCallError:
        case LinphoneCallEnd:
            [MainVC sipTerminate];
            break;
        default:
            break;
    }
}

-(void) onRegister:(LinphoneCore *)lc cfg:(LinphoneProxyConfig*) cfg state:(LinphoneRegistrationState) state message:(const char*) message {
    switch(state) {
        case LinphoneRegistrationOk:
            _retryCounter = 0;
            _RegistrationInProgress = NO;
            [MainVC sipRegistered];
            break;
        //case LinphoneRegistrationCleared:
        case LinphoneRegistrationFailed:
            if ( _retryCounter > 0 && lastIdent && lastHost ) {
                _retryCounter--;
                [self registerWithIdent:lastIdent host:lastHost];
            } else {
                _RegistrationInProgress = NO;
                [MainVC sipTerminate];
            };
            break;
        case LinphoneRegistrationProgress:
            [MainVC setConnectedStatusWithActInd:YES];
            break;
        default:
            break;
        
    }
}

static void linphone_iphone_registration_state(LinphoneCore *lc, LinphoneProxyConfig* cfg, LinphoneRegistrationState state,const char* message) {
    if ( Linphone ) {
        [Linphone onRegister:lc cfg:cfg state:state message:message];
    }
}

static void showVideoView(LinphoneCall* call, void* user_data) {
    linphone_call_set_next_video_frame_decoded_callback(call, NULL, NULL);
    [MainVC sipVideoStarted];
}

static void linphone_iphone_call_state(LinphoneCore *lc, LinphoneCall* call, LinphoneCallState state,const char* message) {
    
    if ( Linphone ) {
        [Linphone onCallState:lc callPtr:call callState:state msg:message];
    }
}

void linphone_iphone_log_handler(const char *domain, OrtpLogLevel lev, const char *fmt, va_list args) {
	NSString* format = [[NSString alloc] initWithCString:fmt encoding:[NSString defaultCStringEncoding]];
	NSLogv(format,args);
}

-(void)setAudioEnabled:(BOOL)AudioEnabled {
    _AudioEnabled = AudioEnabled;
    if ( lc ) {
        linphone_core_enable_mic(lc, _AudioEnabled);
    }
}

-(BOOL)AudioEnabled {
    return [self ActiveCall] ? linphone_core_mic_enabled(lc) : _AudioEnabled;
}

-(BOOL)ActiveCall {
    if ( lc ) {
        return linphone_core_get_current_call(lc) != NULL;
    }
    return NO;
}

-(void) resetRetryCounter {
    _retryCounter = 5;
}

- (void)overrideDefaultSettings {
    NSString *factory = [[NSBundle mainBundle] pathForResource: @"lprc-factory" ofType: nil];
    NSString *factoryIpad = [[NSBundle mainBundle] pathForResource: @"lprc-factory-ipad" ofType: nil];
    if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) && [[NSFileManager defaultManager] fileExistsAtPath:factoryIpad]) {
        factory = factoryIpad;
    }
    NSString *confiFileName = [[NSBundle mainBundle] pathForResource: @"lprc" ofType: nil];
    _configDb = lp_config_new_with_factory([confiFileName UTF8String], [factory UTF8String]);
}

-(id)init {
    self = [super init];
    if ( self ) {
        _AudioEnabled = NO;
        _RegistrationInProgress = NO;
        [self resetRetryCounter];

        linphone_core_set_log_handler(linphone_iphone_log_handler);
        linphone_core_set_log_level(ORTP_DEBUG);
        NSLog(@"Linphone initializing start");
        
        lc = nil;
        _iterateTimer = nil;
      
        NSString *sessionCfgFile = [NSTemporaryDirectory() stringByAppendingString:@".lprc_sess"];
        [[NSFileManager defaultManager] removeItemAtPath:sessionCfgFile error: NULL];
        
        [self overrideDefaultSettings];
        
        LinphoneFactory *factory = linphone_factory_get();
        LinphoneCoreCbs *cbs = linphone_factory_create_core_cbs(factory);
        linphone_core_cbs_set_call_state_changed(cbs, linphone_iphone_call_state);
        linphone_core_cbs_set_registration_state_changed(cbs,linphone_iphone_registration_state);
        linphone_core_cbs_set_user_data(cbs, (__bridge void *)(self));
        
        lc = linphone_factory_create_core_with_config(factory, cbs, _configDb);
        linphone_core_cbs_unref(cbs);

        MSFactory *f = linphone_core_get_ms_factory(lc);
        libmssilk_init(f);
        libmsamr_init(f);
        libmsx264_init(f);
        libmsopenh264_init(f);
        libmswebrtc_init(f);
        linphone_core_reload_ms_plugins(lc, NULL);
        
        [self timerInitialize];
         //Configure Codecs

         NSString* path = [[NSBundle mainBundle] pathForResource:@"nowebcamCIF" ofType:@"jpg"];
         if (path) {
            const char* imagePath = [path cStringUsingEncoding:[NSString defaultCStringEncoding]];
            linphone_core_set_static_picture(lc, imagePath);
         }
        
        linphone_core_set_video_device(lc, "StaticImage: Static picture");
        linphone_core_enable_video_capture(lc, YES); // Bez transmisji w obu kierunkach pojawiają się problemy z NAT-em i RTP/video
        linphone_core_enable_video_display(lc, YES);
        
        //linphone_core_set_media_encryption(theLinphoneCore, enableSrtp?LinphoneMediaEncryptionSRTP:LinphoneMediaEncryptionZRTP);
        
        NSLog(@"Linphone initializing done");
        

        
    }
    return self;
}

-(void) timerInitialize {
    if ( _iterateTimer == nil ) {
    _iterateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                     target:self
                                                   selector:@selector(iterate)
                                                   userInfo:nil
                                                    repeats:YES];
    };
}

-(void) iterate {
    if ( lc ) {
        linphone_core_iterate(lc);
    };
}

-(void) clean {
    _retryCounter = 0;
    _RegistrationInProgress = NO;
    lastIdent = nil;
    lastHost = nil;
    self.AudioEnabled = NO;
    [self terminateCall];
    [self unregister];
    
    if ( lc ) {
        linphone_core_set_network_reachable(lc, NO);
    };
    
    [_iterateTimer invalidate];
    _iterateTimer = nil;
}

-(void) registerWithIdent:(NSString *)Ident host:(NSString*)Host {
    
    if ( _RegistrationInProgress ) return;
    
    [self timerInitialize];
    
    if ( [self registered:Ident host:Host] != 2 ) {
        
        _RegistrationInProgress = YES;
        lastIdent = Ident;
        lastHost = Host;
        
        [MainVC setConnectedStatusWithActInd:YES];
        [self terminateCall];
        [self unregister];
        
	    linphone_core_clear_all_auth_info(lc);
        linphone_core_clear_proxy_config(lc);
        
        LinphoneSipTransports transportValue;
        linphone_core_get_sip_transports(lc, &transportValue);

        if (transportValue.tcp_port == 0) transportValue.tcp_port=transportValue.udp_port + transportValue.tls_port;
        transportValue.udp_port=0;
        transportValue.tls_port=0;
        linphone_core_set_sip_transports(lc, &transportValue);
        
        LinphoneProxyConfig* proxy_cfg = linphone_core_create_proxy_config(lc);
        
        LinphoneAddress *addr = linphone_address_new(NULL);
        linphone_address_set_username(addr, Ident.UTF8String);
        linphone_address_set_domain(addr, Host.UTF8String);
        
        linphone_proxy_config_set_identity_address(proxy_cfg, addr);
        linphone_proxy_config_set_server_addr(proxy_cfg, [[NSString stringWithFormat:@"sip:%@", Host] cStringUsingEncoding:[NSString defaultCStringEncoding]]);
        linphone_proxy_config_enable_register(proxy_cfg,TRUE);
        linphone_proxy_config_expires(proxy_cfg, DEFAULT_EXPIRES);
        linphone_core_add_proxy_config(lc,proxy_cfg);
        linphone_core_set_default_proxy(lc,proxy_cfg);

        linphone_core_set_network_reachable(lc, true);
        
    
    } else {
        [MainVC sipRegistered];
    }
    
};

-(void) unregister {

     NSLog(@"unregister");

    LinphoneProxyConfig* proxy_cfg = linphone_core_get_default_proxy_config(lc);
    
    if ( proxy_cfg
        && linphone_proxy_config_get_state(proxy_cfg) == LinphoneRegistrationOk ) {
        linphone_proxy_config_edit(proxy_cfg);
        linphone_proxy_config_enable_register(proxy_cfg, FALSE);
        linphone_proxy_config_done(proxy_cfg);
    };
    
    linphone_core_clear_proxy_config(lc);

}

-(int) registered:(NSString*) Ident host:(NSString*)Host {
    
    if ( lc ) {
        
        LinphoneProxyConfig *proxy_cfg = linphone_core_get_default_proxy_config(lc);
        
        if ( proxy_cfg
            && linphone_proxy_config_get_state(proxy_cfg) == LinphoneRegistrationOk )
        {
            if ( ![Ident isEqualToString:@""] || ![Host isEqualToString:@""] ) {
                
                LinphoneAddress *addr = linphone_proxy_config_get_identity_address(proxy_cfg);
            
                const char *cident = linphone_address_get_username(addr);
                const char *chost = linphone_address_get_domain(addr);
                
                if ( strcmp(cident, [[NSString stringWithFormat:@"sip:%@@%@", Ident, Host] cStringUsingEncoding:[NSString defaultCStringEncoding]]) == 0
                    && strcmp(chost, [[NSString stringWithFormat:@"sip:%@", Host] cStringUsingEncoding:[NSString defaultCStringEncoding]]) == 0 )
                    return 2;
            };
            
            return 1;
        };
    };
    
    return 0;
};

- (bool)allowSpeaker {
    if (([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad))
        return true;
    
    bool allow = true;
    AVAudioSessionRouteDescription *newRoute = [AVAudioSession sharedInstance].currentRoute;
    if (newRoute) {
        NSString *route = newRoute.outputs[0].portType;
        allow = !([route isEqualToString:AVAudioSessionPortLineOut] ||
                  [route isEqualToString:AVAudioSessionPortHeadphones] ||
                  [@[ AVAudioSessionPortBluetoothA2DP, AVAudioSessionPortBluetoothLE, AVAudioSessionPortBluetoothHFP ] containsObject:route]);
    }
    return allow;
}

- (void) speakerOn {
    
    if ( [self allowSpeaker] ) {
        NSError *err = nil;
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&err];
        [[UIDevice currentDevice] setProximityMonitoringEnabled:FALSE];

    } else {
        NSLog(@"Speaker not allowed");
    }
    
    

}

- (void) setMicGain:(float) gain {
    if ( lc ) {
       linphone_core_set_mic_gain_db(lc, gain);
    }
   
}


-(void) terminateCall {
    
    NSLog(@"terminate call");
    
    if ( lc ) {
        linphone_core_terminate_all_calls(lc);
    };

};

@end
