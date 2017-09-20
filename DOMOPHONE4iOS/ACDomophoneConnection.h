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

#import <Foundation/Foundation.h>

#define CONNECTION_DIRECT 0x1
#define CONNECTION_PROXY  0x2

@interface NSString (DOMOPHONE)
+ (NSString*) stringWithWideString:(const wchar_t*)ws;
+ (NSString*) keyToString:(char *)key keyLen:(int)len addComma:(BOOL)comma;
- (BOOL) isIntegerValue;
- (wchar_t*)getWideString;
@end

@interface ACDomophoneConnection : NSThread <NSStreamDelegate> 

- (id)initWithAuthKey:(char *)authkey serialKey:(char *)serialkey clientID:(char*)ID remoteHostName:(NSString *)host tcpPort:(int)port dcStruct:(void*)dcs;
- (id)initWithDcStruct:(void*)dcs;
- (void)main;
- (void) openGate;
- (void) openGateway;
- (void) SipConnectWithVideo:(BOOL)videoEnabled andSpeakerOn:(BOOL)speaker_on;
- (void) SipDisconnect;
- (void) RegisterPushID:(NSData*)push_id;
- (BOOL) IsAuthorized;
- (void) SetSpeakerOn:(BOOL)on;
- (NSString *) SipServer;

@property id eventObject;

@property SEL onConnect;
@property SEL onDisconnect;
@property SEL onAuthorize;
@property SEL onUnauthorize;
@property SEL onEvent;
@property SEL onVersionError;
@property SEL onSysState;
@property SEL onPushRegister;
@property SEL onLocked;
@property (readonly, atomic)int connected;

@end
