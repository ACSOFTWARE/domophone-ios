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

#ifndef socketdata_H_
#define socketdata_H_

#include <wchar.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BUFF_SIZE            4096
#define PARAM6_MAX_SIZE      2048
#define MAXQDATA_SIZE        8192
#define AUTHKEY_SIZE         8
#define ID_SIZE              8
#define DP_VERSION           6
#define SENDERNAME_MAXSIZE   (1024-ID_SIZE)

#define CAP_AUDIO           0x0001
#define CAP_VIDEO           0x0002
#define CAP_OPEN1           0x0004
#define CAP_OPEN2           0x0008
#define CAP_STOP2           0x0010
#define CAP_CLOSE2          0x0020
#define CAP_OPEN3           0x0040
#define CAP_STOP3           0x0080
#define CAP_CLOSE3          0x0100
#define CAP_GATESENSOR      0x0200
#define CAP_GATEWAYSENSOR   0x0400


#define ET_ONBEGIN       1
#define ET_ONEND         2

#define ES_SIP           1
#define ES_OPEN          2
#define ES_CLOSE         3
#define ES_STOP          4
#define ES_RING          5

#define EVENTOWNER_FALSE 0
#define EVENTOWNER_TRUE  1

#define SCATTR_SPEAKERON   0x01
#define SCATTR_VIDEO       0x02

#define ACTION_RESULT     0
        // Param1 - RESULT_
#define ACTION_HELLO      1 // [domophone->]
#define ACTION_AUTH       2 // [domophone<-]
        // Param1 - Client OS type (OSTTYPE_)
        // Param2 - Language (LANG_)
        // param5 - Client name
        // Result - [Param1 = RESULT_TRUE/RESULTDEVICENOTFOUND/RESULT_AUTHERROR, Param2 - CAPABILITIES, param5 = TSipData]

#define ACTION_OPEN1      4 // [domophone<-]
#define ACTION_OPEN2      5 // [domophone<-]
#define ACTION_STOP2      6 // [domophone<-]
#define ACTION_CLOSE2     7 // [domophone<-]
#define ACTION_OPEN3      8 // [domophone<-]
#define ACTION_STOP3      9 // [domophone<-]
#define ACTION_CLOSE3     10 // [domophone<-]
        // Param1 - Action uniqueID

#define ACTION_SIPCONNECT 11 // [domophone<-]
        // Param1 - Action uniqueID
        // Param2 - Connection attributes (SCATTR_)

#define ACTION_SIPDISCONNECT 12 // [domophone<-]
        // Param1 - Action uniqueID


#define ACTION_EVENT      13 // [domophone->]
        // Param1 - Event UniqueID
        // Param2 - Event Type ( ET_ )
        // Param3 - Event Scope ( ES_ )
        // Param4 - Event owner (EVENTOWNER_)
        // param6 - Sender Name
    
    
#define ACTION_PING       14 // [domophone<-]
        // Result - [Param1 = RESULT_TRUE / RESULT_FALSE, Param2 = SYS_STATE_] RESULT_TRUE == Param2 is set

       
#define ACTION_REGISTERDEVICE   15 //[proxy<-domophone]
        // param6 - Firmware Version
    

#ifdef _DEBUG

#define ACTION_STREAM           16
        // Param1 - Stream ID
        // Param2 - Data type
        // Param3 - Total size
        // Param4 - Position
        // Param6 - Data

#endif

#define ACTION_DISCONNECT           17
#define ACTION_SET_PUSH_ID          18 //[client->proxy]
#define ACTION_SPEAKER_ONOFF        19 //[client->domophone]
        // Param1 Action UniqueID
        // Param2 1=On 2=Off
    
#define ACTION_WAKEUP           20 //[domophone->]

#define SYS_STATE_OPENING1                     0x0001
#define SYS_STATE_OPENING2                     0x0002
#define SYS_STATE_OPENING3                     0x0004
#define SYS_STATE_SIPCONNECTED                 0x0008
#define SYS_STATE_GATEISCLOSED                 0x0010
#define SYS_STATE_GATEWAYISCLOSED              0x0020
#define SYS_STATE_PROXYREGISTERED              0x0040


#define RESULT_ACTION_UNIQUEID_DUPLICATED  -5
#define RESULT_DEVICENOTFOUND              -4
#define RESULT_TIMEOUT                     -3
#define RESULT_LOCKED                      -2
        // Param2 Owner 1/0
        // Param6 ID and Name
#define RESULT_AUTHERROR                   -1
#define RESULT_FALSE                        0
#define RESULT_TRUE                         1

    
#define OSTYPE_UNKNOWN        0
#define OSTYPE_LINUX          1
#define OSTYPE_IOS_IPHONE     2
#define OSTYPE_IOS_IPAD       3
#define OSTYPE_IOS_IPOD       4
#define OSTYPE_ANDROID        5
#define OSTYPE_MAC            6
#define OSTYPE_WINDOWS        7
    
#define LANG_UNKNOWN          0
#define LANG_PL               1
#define LANG_EN               2
#define LANG_CZ               3
#define LANG_SK               4
#define LANG_DE               5
#define LANG_FR               6
#define LANG_IT               7
#define LANG_RU               8

#define DPERROR_NONE            0
#define DPERROR_UNKNOWN         1
#define DPERROR_VERSION         2
#define DPERROR_BUFFEROVERFLOW  3

#define SIP_IDENTSIZE         33

#pragma pack(push, 1)

typedef struct
{
	char Version;

	unsigned short Action;
	unsigned int RequestID;

    char CID[ID_SIZE];
	char DID[ID_SIZE];
	char AuthKey[AUTHKEY_SIZE];

	int Param1;
	int Param2;
	int Param3;
	int Param4;
	int Param5;

	unsigned short param6DataSize;
	char param6[PARAM6_MAX_SIZE];


}TDataPacket;

#pragma pack(pop)

typedef struct
{
	char Host[100];
	short Port;
}TSipData;

typedef struct
{
   int in_size;
   int in_offset;
   char *in_buff;

   int out_size;
   int out_offset;
   char *out_buff;

   void *ptr;

   void (*lock_func)(void *data);
   void (*unlock_func)(void *data);
   void (*data_in_event_func)(void *data);
   void (*data_out_event_func)(void *data);

}TInOutDataQueue;

//extern "C" {
void *sd_init(int sfd, TInOutDataQueue *dataq, char *_did, char *_cid);
void sd_release(void *sd);


unsigned char sd_ParseDataA(void *sd, char *buffer, int buffer_size, int *readed_len, TDataPacket *DP);
unsigned char sd_ParseDataB(void *sd, TDataPacket *DP);
char * sd_DataPacketToBuffer(TDataPacket *DP, int *buff_size);
void sd_ParseReset(void *sd);
void sd_DataPacketInit(void *sd, TDataPacket *DP, unsigned int Action, unsigned int RequestID);
void sd_SendPacket(void *sd, TDataPacket *DP);
unsigned char sd_Request(void *sd, TDataPacket *Request, TDataPacket *Response);
void sd_SetID(void *sd, char *_id, char did);
void sd_GetID(void *sd, char *_id, char did);
unsigned char sd_IsDisconnected(void *sd);
int sd_Error(void *sd);
unsigned char sd_DataAppendQueue(TInOutDataQueue *dataq, char out, char *data, int datasize);
int sd_QueueToBuffer(TInOutDataQueue *dataq, char out, char *buffer, int buffer_size);
void sd_appendrecvbuffer(char **recv_buffer, int *recv_buffer_size, char *data, int data_size);
void sd_truncaterecvbuffer(char **recv_buffer, int *recv_buffer_size, int readed_len);

#ifdef __cplusplus
}
#endif

#endif /* socketdata_H_ */
