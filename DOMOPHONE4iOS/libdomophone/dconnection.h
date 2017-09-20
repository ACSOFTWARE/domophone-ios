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

#ifndef dconnectionH
#define dconnectionH
//---------------------------------------------------------------------------

#include <wchar.h>
#include "socketdata.h"

#ifdef __cplusplus
extern "C" {
#endif

#define WRESULT_NONE                 0
#define WRESULT_ONCONNECT            1
#define WRESULT_ONDISCONNECT         2
#define WRESULT_ONAUTHORIZE          3
#define WRESULT_ONUNAUTHORIZE        4
#define WRESULT_ONEVENT              5
#define WRESULT_TRYCONNECT           6
#define WRESULT_WAITFORDATA          7
#define WRESULT_TRYSENDDATA          8
#define WRESULT_TRYDISCONNECT        9
#define WRESULT_RESPONSETIMEOUT      10
#define WRESULT_ONRESPONSE           11
#define WRESULT_SYNCHMODE            12
#define WRESULT_PROXYCONNECT         13
#define WRESULT_PROXYDISCONNECT      14
#define WRESULT_VERSIONERROR         15
#define WRESULT_DEVICENOTFOUND       16
#define WRESULT_ONSYSSTATE           17
#define WRESULT_REGISTER_PUSH_ID     18
#define WRESULT_LOCKED               19
#define WRESULT_WAKEUP               20
    
#define DCSTATE_CONNECTING           1
#define DCSTATE_CONNECTED            2
#define DCSTATE_DISCONNECTED         3

#define USEPROXY_NONE                0
#define USEPROXY_INSTANT             1
#define USEPROXY_ALWAYS              2

typedef struct
{
   TSipData Sip;
   char AuthKey[AUTHKEY_SIZE];
   char SerialKey[ID_SIZE];
   int Caps;
   unsigned char proxy;
}TConnectionSettings;

typedef struct
{
   int ID;
   int Type;
   int Scope;
   unsigned char Owner;
   int Param1;
   char SenderID[ID_SIZE];
   char *SenderName;

}TdEvent;

void *dconnection_init(unsigned char OsType, unsigned char Language, char *AuthKey, char *Serial, char *ID, const char *Name, unsigned char useproxy);
void *pconnection_proxyinit(void *dc);
void dconnection_set_ping_interval(void *dc, int interval);
int dconnection_work(void *dc);
void dconnection_appendrecvbuffer(void *dc, char *in, int in_len);
char *dconnection_getsentbuffer(void *dc, int *size);
void dconnection_setconnecting(void *dc);
void dconnection_release(void *dc);
void dconnection_getauthkey(void *dc, void *AuthKey);
void dconnection_setdisconnected(void *dc, unsigned char wait_for_reconnect);
void dconnection_getlastdatapacket(void *dc, TDataPacket *dp);
int dconnection_request(void *dc, TDataPacket *dp);
void dconnection_getresponse(void *dc, TDataPacket *dp);
unsigned char dconnection_getconnectionsettings(void *dc, TConnectionSettings *cs);
unsigned char dconnection_getevent(void *dc, TdEvent *event, unsigned char *duplicate);
int dconnection_request_action(void *dc, int action, int param2, int param3, int param4, int param5);
int dconnection_opengate(void *dc, int num);
int dconnection_sipconnect(void *dc, unsigned char speaker_on, unsigned char video);
int dconnection_sipdisconnect(void *dc);
void dconnection_send_disconnect(void *dc);
unsigned char dconnection_isproxy(void *dc);
void dconnection_getserial(void *dc, char *serial);
void dconnection_setserial(void *dc, char *serial);
unsigned char dconnection_get_sys_state(void *dc, int *state, int *firmware_version);
void dconnection_set_push_id(void *dc, char *push_id, int push_id_size);
void dconnection_setspeakeronoff(void *dc, unsigned char on);
unsigned char dconnection_is_authorized(void *dc);
wchar_t* dconnection_get_wchar(char *buffer, size_t buffer_size);
void dconnection_extract_name_and_id(TDataPacket *dp, char **name, char *_id);
void dconnection_ping(void *dc);
#ifdef __linux__
char dconnection_wait_for_data_event(void *dc, int extrafd);
void dconnection_raise_data_event(void *dc);
#endif
#ifdef _DEBUG
int dconnection_stream(void *dc, int ID, int DataType, int TotalSize, char *data, int data_size, int pos);
#endif

#ifdef __cplusplus
}
#endif

#endif
