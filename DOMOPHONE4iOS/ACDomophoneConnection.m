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

#import "ACDomophoneConnection.h"
#import "ACViewController.h"
#include "dconnection.h"


#define RECV_BUFF_SIZE 2024

@implementation NSString (DOMOPHONE)

- (wchar_t*)getWideString
{
    const char* temp = [self cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned long buflen = strlen(temp)+1; //including NULL terminating char
    wchar_t* buffer = malloc(buflen * sizeof(wchar_t));
    mbstowcs(buffer, temp, buflen);
    return buffer;
}

+ (NSString*)stringWithWideString:(const wchar_t*)ws
{
    unsigned long bufflen = 8*wcslen(ws)+1;
    char* temp = malloc(bufflen);
    wcstombs(temp, ws, bufflen);
    NSString* retVal = [self stringWithUTF8String:temp];
    free(temp);
    return retVal;
}

- (BOOL) isIntegerValue {
    return [self isEqualToString:@"0"] || [self integerValue] > 0;
}

+ (NSString*) keyToString:(char *)key keyLen:(int)len addComma:(BOOL)comma {
    
    NSMutableString *S = [[NSMutableString alloc] init];
    
    for(int a=0;a<len;a++) {
        [S appendString:[NSString stringWithFormat:@"%02X", (unsigned char)key[a]]];
        if ( comma && (a+1)%2 == 0 && a<len-1 )
            [S appendString:@"-"];
    }
    return S;
}


@end

@implementation ACDomophoneConnection {
    void *dc;
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
    char _recv_buffer[RECV_BUFF_SIZE];
    unsigned long _recv_datasize;
    int _tcp_port;
    NSString *_host;
    bool _is_proxy;
    bool _connected;
    ACDomophoneConnection *_Proxy;
}

@synthesize eventObject = _eventObject;
@synthesize onConnect = _onConnect;
@synthesize onDisconnect = _onDisconnect;
@synthesize onAuthorize = _onAuthorize;
@synthesize onUnauthorize = _onUnauthorize;
@synthesize onEvent = _onEvent;
@synthesize onVersionError = _onVersionError;
@synthesize onSysState = _onSysState;
@synthesize onPushRegister = _onPushRegister;
@synthesize onLocked = _onLocked;


-(int)connected {
    int result = 0;
    
    if ( _connected ) {
        result = _is_proxy ? CONNECTION_PROXY : CONNECTION_DIRECT;
    }
    
    if ( !_is_proxy
        && _Proxy ) {
        result |= _Proxy.connected;
    }
    
    return result;
}

-(id)initWithAuthKey:(char *)authkey serialKey:(char *)serialkey clientID:(char*)ID remoteHostName:(NSString *)host tcpPort:(int)port dcStruct:(void*)dcs {

    self = [super init];
    if ( self ) {
        
        _onConnect = nil;
        _onDisconnect = nil;
        _onAuthorize = nil;
        _onUnauthorize = nil;
        _onEvent = nil;
        _onPushRegister = nil;
        _onLocked = nil;
        _inputStream = nil;
        _outputStream = nil;
        _recv_datasize = 0;
        _host = host;
        _tcp_port = port;
        _connected = NO;
        _Proxy = NULL;
        
        if ( dcs == NULL ) {
            
            char OsType = OSTYPE_UNKNOWN;
            NSString *model = [[UIDevice currentDevice] model];
            
            if ( [model rangeOfString:@"iPad"].location != NSNotFound) {
                OsType = OSTYPE_IOS_IPAD;
            } else if ( [model rangeOfString:@"iPhone"].location != NSNotFound)  {
                OsType = OSTYPE_IOS_IPHONE;
            } else if ( [model rangeOfString:@"iPod"].location != NSNotFound)  {
                OsType = OSTYPE_IOS_IPOD;
            }
                
            dc = dconnection_init(OsType, LANG_UNKNOWN, authkey, serialkey, ID, [[UIDevice currentDevice].name UTF8String], USEPROXY_ALWAYS);

        } else {
            dc = dcs;
        };
    }

    return self;
}

- (id)initWithDcStruct:(void*)dcs {
    return [self initWithAuthKey:NULL serialKey:NULL clientID:NULL remoteHostName:NULL tcpPort:0 dcStruct:dcs];
}

- (bool)tryConnect {
    
    [self disconnect];
    
    if ( _is_proxy ) {
        _host = @"";
        _tcp_port = 465;
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: [NSURL URLWithString: [NSString stringWithFormat:@"https://www.acsoftware.pl/support/domophone.php"]]];

        [request setHTTPMethod: @"POST"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
        
        char serial[ID_SIZE];
        dconnection_getserial(dc, serial);
        
        NSMutableString *body = [NSMutableString stringWithFormat:@"Action=GetProxyAddress&SerialKey=%@", [NSString keyToString:serial keyLen:ID_SIZE addComma:YES]];
        [request setHTTPBody:[body dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES]];
        
        NSURLResponse * response = nil;
        NSError * error = nil;
        NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if ( data && error == nil ) {
            
            unsigned long data_size = data.length;
            char *buffer = (char *)malloc(data_size+1);
            buffer[data_size] = 0;
            [data getBytes:buffer length:data_size+1];
            data = nil;
            
        
            for(int a=0;a<data_size;a++) {
                if ( buffer[a] == ':' ) {
                    if ( a < data_size-1 ) {
                        NSString *v = [NSString stringWithFormat:@"%s", &buffer[a+1]];
                        if ( [v isIntegerValue] ) {
                            _tcp_port = [v intValue];
                        }
                        
                    }
                    buffer[a] = 0;
                    break;
                }
            }
            
            _host = [NSString stringWithFormat:@"%s", buffer];
            
        } else {
            NSLog(@"Get proxy address failed. Error: %@", error ? error.userInfo.debugDescription : @"unknown");
        }
    }
    
    _recv_datasize = 0;
    
    if ( _host.length > 0 ) {
        
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        
        
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge_retained  CFStringRef)_host, _tcp_port, &readStream, &writeStream);
        
        //CFReadStreamSetProperty(readStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP);
        //CFWriteStreamSetProperty(writeStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP);
        
        _inputStream = (__bridge NSInputStream *)readStream;
        _outputStream = (__bridge NSOutputStream *)writeStream;
        
        [_inputStream setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
        [_outputStream  setProperty:NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
        
        [_inputStream setDelegate:self];
        [_outputStream setDelegate:self];
        
        [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [_inputStream open];
        [_outputStream open];
        
        return YES;
    }

    return NO;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {

    if ( eventCode == NSStreamEventHasBytesAvailable ) {
        
        if ( aStream == _inputStream ) {
            _recv_datasize = [_inputStream read:(uint8_t*)_recv_buffer maxLength:RECV_BUFF_SIZE];
            //if ( _is_proxy )
            NSLog(@"READ FROM STREAM %lu BYTES", _recv_datasize);
        };

    } else if ( eventCode == NSStreamEventErrorOccurred
               || eventCode == NSStreamEventEndEncountered ) {
        
        //if ( _is_proxy )
        NSLog(@"HANDLE_EVENT_ERROR: %lu, %@ [PROXY=%i]", (unsigned long)eventCode, [[aStream streamError] localizedDescription], _is_proxy );
        
        [_inputStream close];
        [_outputStream close];
        _inputStream = nil;
        _outputStream = nil;
        
        dconnection_setdisconnected(dc, 1);
        
    } else {
        //if ( _is_proxy )
        NSLog(@"HANDLE_EVENT: %lu, %@ [PROXY=%i]", (unsigned long)eventCode, [[aStream streamError] localizedDescription], _is_proxy );
    }

}

- (void)disconnect {
    
    if ( _inputStream || _outputStream ) {
        
        if ( _inputStream ) {
            [_inputStream close];
            _inputStream = nil;
        }

        if ( _outputStream ) {
            [_outputStream close];
            _outputStream = nil;
        }
        
    }
    
    dconnection_setdisconnected(dc, 1);

}

- (void)proxy_disconnect:(BOOL)waitUntilDone {
    if ( _Proxy ) {
        if ( _Proxy ) {
            [_Proxy cancel];
            int TimeOut = 50;
            while((![_Proxy isFinished] || TimeOut < 0) && waitUntilDone == YES) {
                usleep(100000);
                TimeOut--;
            }
            
            if ( TimeOut < 0 ) {
                NSLog(@"Proxy connection cancel timeout!");
            }
            
            _Proxy = nil;
        }
    }
}

- (void)main {
   
    
    int wr;
    _is_proxy = dconnection_isproxy(dc) != 0;
    

    TDataPacket DP;
    
    while(![self isCancelled]) {
        @autoreleasepool {
            
            wr = dconnection_work(dc);
            
            switch(wr) {
                case WRESULT_ONCONNECT:
                    //if ( _is_proxy )
                    NSLog(@"WRESULT_ONCONNECT [PROXY=%i]", _is_proxy);
                    _connected = NO;
                    if ( _onConnect && _eventObject )
                        [_eventObject performSelectorOnMainThread:_onConnect withObject:nil waitUntilDone:NO];
                    break;
                case WRESULT_ONDISCONNECT:
                    //if ( _is_proxy )
                    NSLog(@"WRESULT_ONDISCONNECT [PROXY=%i]", _is_proxy);
                    _connected = NO;
                    [self disconnect];
                    if ( _onDisconnect && _eventObject )
                        [_eventObject performSelectorOnMainThread:self.onDisconnect withObject:nil waitUntilDone:NO];
                    break;
                case WRESULT_ONAUTHORIZE:
                    //if ( _is_proxy )
                    NSLog(@"WRESULT_ONAUTHORIZE [PROXY=%i]", _is_proxy);
                    _connected = YES;
                    if ( _onAuthorize && _eventObject ) {
                        TConnectionSettings Settings;
                        dconnection_getconnectionsettings(dc, &Settings);
                        [_eventObject performSelectorOnMainThread:_onAuthorize withObject:[NSValue valueWithPointer:&Settings] waitUntilDone:YES];
                    }
                    break;
                case WRESULT_ONUNAUTHORIZE:
                    //if ( _is_proxy )
                    NSLog(@"WRESULT_ONUNAUTHORIZE [PROXY=%i]", _is_proxy);
                    if ( _onUnauthorize
                         && _eventObject
                         && !_is_proxy )
                        [_eventObject performSelectorOnMainThread:_onUnauthorize withObject:nil waitUntilDone:NO];
                    break;
                case WRESULT_ONEVENT:
                    if ( _onEvent && _eventObject ) {
                        TdEvent Event;
                        unsigned char dup = 0;
                        if ( dconnection_getevent(dc, &Event, &dup) == 1
                             && dup == 0 ) {
                            
                            if ( Event.SenderName == NULL ) {
                                Event.SenderName = strdup("noname");
                            }
                            
                            [_eventObject performSelectorOnMainThread:_onEvent withObject:[NSValue valueWithPointer:&Event] waitUntilDone:YES];
                            
                            free(Event.SenderName);
                        };
                        
                        //if ( _is_proxy )
                        NSLog(@"WRESULT_ONEVENT [PROXY=%i DUP=%i]", _is_proxy, dup);
                        
                    }
                    break;
                case WRESULT_TRYCONNECT:
                    //if ( _is_proxy )
                    NSLog(@"WRESULT_TRYCONNECT [PROXY=%i]", _is_proxy);
                    if ( [self tryConnect] ) {
                       dconnection_setconnecting(dc);
                    };
                    break;
                case WRESULT_WAITFORDATA:
                    
                    if ( _inputStream ) {
                        
                        if ( _recv_datasize > 0 ) {
                           dconnection_appendrecvbuffer(dc, _recv_buffer, _recv_datasize);
                            _recv_datasize = 0;
                        } else {
                           usleep(10000);
                        }
                        
                    } else {
                        dconnection_setdisconnected(dc, 0);
                    }
                    break;
                case WRESULT_TRYSENDDATA:
                {
                    if ( _outputStream ) {
                        int send_buff_size;
                        char *send_buff = dconnection_getsentbuffer(dc, &send_buff_size);
                     
                        NSInteger w = [_outputStream write:(unsigned char*)send_buff maxLength:send_buff_size];
                        //if ( _is_proxy )
                        NSLog(@"WRITE TO STREAM %li BYTES / %i [PROXY=%i]", (long)w, send_buff_size, _is_proxy);
                        
                        free(send_buff);
                    } else {
                        dconnection_setdisconnected(dc, 0);
                    }
                }
                    break;
                case WRESULT_RESPONSETIMEOUT:
                    //if ( _is_proxy )
                    NSLog(@"WRESULT_RESPONSETIMEOUT [PROXY=%i]", _is_proxy);
                    break;
                case WRESULT_ONRESPONSE:
                    //if ( _is_proxy )
                    NSLog(@"WRESULT_ONRESPONSE [PROXY=%i]", _is_proxy);
                    dconnection_getresponse(dc, &DP);
                    if( DP.Param1 == RESULT_ACTION_UNIQUEID_DUPLICATED ) {
                        NSLog(@"RESULT_ACTION_UNIQUEID_DUPLICATED [PROXY=%i]", _is_proxy);
                    }
                    
                    break;
                case WRESULT_ONSYSSTATE:
                    //if ( _is_proxy ) 
                    NSLog(@"WRESULT_ONSYSSTATE [PROXY=%i]", _is_proxy);
                    
                    if ( _eventObject && _onSysState ) {
                        int state;
                        int firmware_version;
                        if ( dconnection_get_sys_state(dc, &state, &firmware_version) ) {
                            
                            [_eventObject performSelectorOnMainThread:_onSysState withObject:[NSNumber numberWithInt:state] waitUntilDone:NO];
                        }
                         
                    }
                    break;
                case WRESULT_LOCKED:
                    if ( _eventObject && _onLocked ) {
                         dconnection_getresponse(dc, &DP);
                        
                        if ( DP.Param2 == 0 ) {
                            char *SenderName;
                            dconnection_extract_name_and_id(&DP, &SenderName, NULL);
                            
                            [_eventObject performSelectorOnMainThread:_onLocked withObject:SenderName ? [NSString stringWithUTF8String:SenderName] : @"" waitUntilDone:YES];
                            
                            if ( SenderName ) {
                                free(SenderName);
                            }
                        }

                    }
                    break;
                case WRESULT_PROXYCONNECT:
                    
                {
                    NSLog(@"WRESULT_PROXYCONNECT [PROXY=%i]", _is_proxy);
                    
                    _Proxy = [[ACDomophoneConnection alloc] initWithDcStruct:pconnection_proxyinit(dc)];
                    _Proxy.eventObject = self.eventObject;
                    _Proxy.onDisconnect = self.onDisconnect;
                    _Proxy.onAuthorize = self.onAuthorize;
                    _Proxy.onUnauthorize = self.onUnauthorize;
                    _Proxy.onVersionError = self.onVersionError;
                    _Proxy.onPushRegister = self.onPushRegister;
                    _Proxy.onSysState = self.onSysState;
                    _Proxy.onEvent = self.onEvent;
                    _Proxy.onLocked = self.onLocked;
                    [_Proxy start];
                }
                     
                    break;
                case WRESULT_PROXYDISCONNECT:
                    if ( _is_proxy )
                    NSLog(@"WRESULT_PROXYDISCONNECT [PROXY=%i]", _is_proxy);
                    [self proxy_disconnect:NO];
                    break;
                case WRESULT_DEVICENOTFOUND:
                	NSLog(@"WRESULT_DEVICENOTFOUND");
                    break;
                case WRESULT_VERSIONERROR:
                    if ( _onVersionError && _eventObject )
                        [_eventObject performSelectorOnMainThread:_onVersionError withObject:nil waitUntilDone:NO];
                    break;
                case WRESULT_NONE:
                    usleep(100000);
                    break;
                case WRESULT_REGISTER_PUSH_ID:
                    if ( _onPushRegister && _eventObject )
                    [_eventObject performSelectorOnMainThread:_onPushRegister withObject:nil waitUntilDone:NO];
                    break;
                case WRESULT_WAKEUP:
                	NSLog(@"WRESULT_WAKEUP");
                    break;
            };
            
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate date]];
        }
    };
    
    [self proxy_disconnect:YES];
    
    dconnection_release(dc);

}

- (void) openGate {
    dconnection_opengate(dc, 2);
};

- (void) openGateway {
    dconnection_opengate(dc, 1);
};

- (void) SipConnectWithVideo:(BOOL)videoEnabled andSpeakerOn:(BOOL)speaker_on {
    if ( dc )
        dconnection_sipconnect(dc, speaker_on ? 1 : 0, videoEnabled ? 1 : 0);
};

- (void) SipDisconnect {
    if ( dc )
       dconnection_sipdisconnect(dc);
};

- (void) RegisterPushID:(NSData*)push_id {
    if ( dc ) {
        char *buffer = NULL;
        unsigned long data_size = 0;
        
        if ( push_id
            && push_id.length > 0 ) {
            

            const char *c =[[NSString stringWithFormat:@"ring%i.mp3|", [ACViewController getRingToneID]] cStringUsingEncoding:[NSString defaultCStringEncoding]];
            
            unsigned long len = strlen(c);
            
            data_size = push_id.length+len;
            buffer = malloc(data_size);
            memcpy(buffer, c, len);
            [push_id getBytes:&buffer[len] length:push_id.length];
        }
        
        dconnection_set_push_id(dc, buffer, data_size);
        
        if ( buffer ) {
            free(buffer);
        }
    }
        
}

- (BOOL) IsAuthorized {
    return dc && dconnection_is_authorized(dc);
}

- (void) SetSpeakerOn:(BOOL)on {
    if ( dc )
        dconnection_setspeakeronoff(dc, on == YES ? 1 : 0);
}

- (NSString *) SipServer {
    TConnectionSettings cs;
    if ( dc
        && dconnection_getconnectionsettings(dc, &cs) ) {
        return [NSString stringWithFormat:@"%s", cs.Sip.Host];
    }
    return nil;
}


@end
