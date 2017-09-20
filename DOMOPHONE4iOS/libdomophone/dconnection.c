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

#include "dconnection.h"
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <time.h>
#include <wchar.h>

#ifdef __WIN32__
#include <windows.h>
#elif defined(__APPLE__) || defined(__linux__)

#if defined(__linux__) && !defined(__USE_UNIX98)
    #define __USE_UNIX98 1
#endif

#include <pthread.h>
#endif

#ifdef __linux__
#include <sys/eventfd.h>
#endif

#ifdef __ANDROID__
#include <android/log.h>
#endif 

#define DCS_ONDISCONNECTED   0
#define DCS_DISCONNECTED     1
#define DCS_CONNECTING       2
#define DCS_CONNECTED        3
#define DCS_AUTHORIZING      4
#define DCS_UNAUTHORIZED     5
#define DCS_AUTHORIZED       6

#define ASS_NONE                 0
#define ASS_WAITFORDATA          1
#define ASS_WAITFORRESPONSE      2
#define ASS_DISCONNECT           3
#define ASS_TRYCONNECT           4
#define ASS_PROXYDISCONNECT      5
#define ASS_REGISTER_PUSH_ID     6

#define RECONNECT_MASTERDELAY     1
#define RECONNECT_PROXYDELAY      1
#define CONNECTING_TIMEOUT        5
#define AUTHORIZING_TIMEOUT       5
#define WAITFORRESPONSE_TIMEOUT   5

#define PING_INTERVAL 5

typedef struct {

   int state;
   void *sd;
   char *buff_in;
   int buff_in_size;
   char *buff_out;
   int buff_out_size;
   time_t state_time;
   char AuthKey[AUTHKEY_SIZE];
   unsigned char OsType;
    unsigned char Language;
   char ID[ID_SIZE];
   char *name;
   int Caps;
   TSipData Sip;
   unsigned char useproxy;
   int substate;
   int ping_interval;
   time_t lastPing;
   time_t lastDataReceiveTime;

   TDataPacket sd_dp;
   TDataPacket sd_rr;
   unsigned int next_requestid;
   void *conn;
   unsigned char is_proxy;

   int ActionUniqueID;
   int LastEventIDS[10];
   unsigned char LastEventIDS_size;
   unsigned char LastEventIDS_offset;
    
#ifdef __linux__
   int defd;
   int decounter;
#endif

   #ifdef __WIN32__
   CRITICAL_SECTION CS;
   #elif defined(__APPLE__) || defined(__linux__)
    pthread_mutex_t mutex;
   #else
    ???
   #endif


}TDConnectionData;

void dconnection_initlock(TDConnectionData *dc) {
   #ifdef __WIN32__
     InitializeCriticalSection(&dc->CS);
   #elif defined(__APPLE__) || defined(__linux__)
     pthread_mutexattr_t attr;
     pthread_mutexattr_init(&attr);
     pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
     pthread_mutex_init(&dc->mutex,&attr);
   #else
     ???
   #endif
};

void dconnection_releaselock(TDConnectionData *dc) {

   #ifdef __WIN32__
     DeleteCriticalSection(&dc->CS);
   #elif defined(__APPLE__) || defined(__linux__)
     pthread_mutex_destroy(&dc->mutex);
   #else
    ???
   #endif
};

void dconnection_lock(void *dc) {
   #ifdef __WIN32__
     EnterCriticalSection(&((TDConnectionData *)dc)->CS);
   #elif defined(__APPLE__) || defined(__linux__)
     pthread_mutex_lock(&((TDConnectionData *)dc)->mutex);
   #else
       ???
   #endif
};

void dconnection_unlock(void *dc) {
   #ifdef __WIN32__
     LeaveCriticalSection(&((TDConnectionData *)dc)->CS);
   #elif defined(__APPLE__) || defined(__linux__)
    pthread_mutex_unlock(&((TDConnectionData *)dc)->mutex);
   #else
    ???
   #endif

};

void *dconnection_init(unsigned char OsType, unsigned char Language, char *AuthKey, char *Serial, char *ID, const char *Name, unsigned char useproxy) {

   TDConnectionData *dc = (TDConnectionData*)malloc(sizeof(TDConnectionData));

   dc->state = DCS_ONDISCONNECTED;
   dc->substate = ASS_NONE;
   dc->buff_in = 0;
   dc->buff_in_size = 0;
   dc->buff_out = 0;
   dc->buff_out_size = 0;
   dc->state_time = 0;
   dc->OsType = OsType;
   dc->Language = Language;
   dc->name = 0;
   dc->Caps = 0;
   dc->useproxy = useproxy;
   dc->conn = 0;
   dc->is_proxy = 0;
   dc->ping_interval = PING_INTERVAL;
   #if defined(__APPLE__)
   dc->ActionUniqueID = arc4random();
   #elif defined(__WIN32__)
   dc->ActionUniqueID = rand()+GetTickCount();
   #else
   dc->ActionUniqueID = random();
   #endif
   dc->LastEventIDS_size = 0;
   dc->LastEventIDS_offset = 0;

   memset(dc->AuthKey, 0, AUTHKEY_SIZE);

   dc->sd = sd_init(0, 0, Serial, ID);

   if ( AuthKey ) {
       memcpy(dc->AuthKey, AuthKey, AUTHKEY_SIZE);
   };
    
   if ( ID ) {
        memcpy(dc->ID, ID, ID_SIZE);
   }

   if ( Name
        && strlen(Name) > 0 )
     {
         /*
        #ifdef __WIN32__
        dc->name = (wchar_t*)malloc((wcslen(Name)+1) * sizeof(wchar_t));
        wcscpy(dc->name, Name);
        #else
        dc->name = wcsdup(Name);
        #endif
          */
         dc->name = strdup(Name);
     };

#ifdef __linux__
   dc->defd = eventfd(0, EFD_NONBLOCK);
   dc->decounter = 1;
#endif

   dconnection_initlock(dc);

return (dc);
};

void dconnection_release(void *dc) {

   TDConnectionData *c = (TDConnectionData*)dc;
   if ( c == 0 || c->is_proxy ) return;

   if ( c->buff_in != 0 ) {
      free(c->buff_in);
      c->buff_in = 0;
   };

   if ( c->buff_out != 0 ) {
      free(c->buff_out);
      c->buff_out = 0;
   };

   if ( c->name != 0 ) {
      free(c->name);
      c->name = 0;
   };

   sd_release(c->sd);
   dconnection_releaselock(c);

   if ( c->conn
        && !c->is_proxy )
     {
        ((TDConnectionData*)c->conn)->is_proxy = 0;
        ((TDConnectionData*)c->conn)->conn = 0;        
        dconnection_release(c->conn);
     };

#ifdef __linux__
   if ( c->defd != -1 ) {
	   close(c->defd);
	   c->defd = -1;
   }
#endif

   free(c);
};

#ifdef __linux__
void dconnection_clear_data_events(TDConnectionData *c) {

	int a;
	dconnection_lock(c);

	if ( c->defd != -1 ) {
		uint64_t e;
		for(a=0;a<1000;a++) {
			if ( read(c->defd, &e, sizeof(uint64_t)) < 1 ) break;
		}
	}

	c->decounter = 1;

	dconnection_unlock(c);

}

char dconnection_wait_for_data_event(void *dc, int extrafd)
{
	TDConnectionData *c =  (TDConnectionData*)dc;
	int timeout;
	fd_set rfds;
	struct timeval tv;

	if ( extrafd == -1 && c->defd == -1 ) return (0);

	dconnection_lock(dc);

	if ( c->decounter < 100 ) {
		timeout = c->decounter * 10;
		c->decounter++;
	} else {
		timeout = 500000;
	}

	dconnection_unlock(dc);

	FD_ZERO(&rfds);

	if ( extrafd >= 0 ) {
		FD_SET(extrafd, &rfds);
	}

	if ( c->defd >= 0 ) {
		FD_SET(c->defd, &rfds);
	}


	tv.tv_sec = (int)(timeout/1000000);
	tv.tv_usec = (int)(timeout%1000000);


    int result =  select(extrafd > c->defd ? extrafd+1 : c->defd + 1, &rfds, NULL, NULL, &tv);

    if ( result == -1 ) {

            usleep(10000);

    } else if ( result ) {

    	if ( c->defd != -1 && FD_ISSET(c->defd, &rfds) ) {
    		dconnection_clear_data_events(dc);
    	}

    	return (1);
    }

return (0);

}



void dconnection_raise_data_event(void *dc)
{
	TDConnectionData *c =  (TDConnectionData*)dc;

	dconnection_lock(dc);
	dconnection_clear_data_events(dc);

	if ( c->defd != -1 ) {
		uint64_t e = 1;
		write(c->defd, &e, sizeof(uint64_t));
	}

	dconnection_unlock(dc);


}

#endif

void *pconnection_proxyinit(void *dc) {

    TDConnectionData* c = (TDConnectionData*)dc;

    if ( c->conn == 0
         && c->useproxy != USEPROXY_NONE ) {

        char SerialKey[ID_SIZE];
        sd_GetID(c->sd, SerialKey, 1);

        c->conn = dconnection_init(c->OsType, c->Language, c->AuthKey, SerialKey, c->ID, c->name, 0);
        ((TDConnectionData*)c->conn)->is_proxy = 1;        
        ((TDConnectionData*)c->conn)->conn = c;
    };

return (c->conn);
};

void dconnection_set_ping_interval(void *dc, int interval) {
	if ( interval < 0  || interval > 120 ) return;

    dconnection_lock(dc);
    ((TDConnectionData *)dc)->ping_interval = interval;
    dconnection_unlock(dc);
}

void dconnection_setstate(TDConnectionData *dc, int state) {

    if ( state == DCS_ONDISCONNECTED
         && dc->state == DCS_DISCONNECTED ) {
        return;
    };

    dc->state = state;
};

int dconnection_getstate(TDConnectionData *dc) {
    return (dc->state);
};

void dconnection_setconnecting(void *dc) {
    dconnection_lock(dc);
    ((TDConnectionData *)dc)->state=DCS_CONNECTING;
    ((TDConnectionData *)dc)->state_time = time(0);
    dconnection_unlock(dc);
};

void dconnection_setdisconnected(void *dc, unsigned char wait_for_reconnect) {
    dconnection_lock(dc);
    dconnection_setstate(dc,  DCS_ONDISCONNECTED);
    ((TDConnectionData *)dc)->state_time = wait_for_reconnect == 1 ? time(0) : 0;
    dconnection_unlock(dc);
};

void dconnection_appendrecvbuffer(void *dc, char *in, int in_size) {

   TDConnectionData *c = (TDConnectionData*)dc;
   dconnection_lock(c);

   if ( c->buff_in_size > 2048 ) return; // Buffer overflow

   c->lastDataReceiveTime = time(0);

   sd_appendrecvbuffer(&c->buff_in, &c->buff_in_size, in, in_size);

   dconnection_unlock(c);
};

void dconnection_datapackettobuffer(TDConnectionData *dc, TDataPacket *dp) {

   int buff_size;
   char *buffer;
   TDConnectionData *c = (TDConnectionData*)dc;

   if ( c->buff_out ) {
      free(c->buff_out);
      c->buff_out = 0;
      c->buff_out_size = 0;
   };

   buffer = sd_DataPacketToBuffer(dp, &buff_size);

   if ( buffer
        && buff_size )
     {
        c->buff_out = buffer;
        c->buff_out_size = buff_size;
     };

};
/*
void dump_dc(TDConnectionData *dc) {
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "---------------------------------", (int)dc);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "dc=%i", (int)dc);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "state=%i", dc->state);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "sd=%i", (int)dc->state);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "buff_in=%i", (int)dc->buff_in);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "buff_in_size=%i", dc->buff_in_size);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "buff_out=%i", (int)dc->buff_out);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "buff_out_size=%i", dc->buff_out_size);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "name=%i", (int)dc->name);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "Caps=%i", (int)dc->Caps);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "useproxy=%i", dc->useproxy);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "substate=%i", dc->substate);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "next_requestid=%i", dc->next_requestid);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "conn=%i", (int)dc->conn);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "is_proxy=%i", dc->is_proxy);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "ActionUniqueID=%i", dc->ActionUniqueID);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "LastEventIDS_size=%i", dc->LastEventIDS_size);
    __android_log_print(ANDROID_LOG_DEBUG, "JNI", "LastEventIDS_offset=%i", dc->LastEventIDS_offset);
}
*/

unsigned char dconnection_parseinput(TDConnectionData *dc) {

     int readed_len;
     unsigned char result = 0;

     if (  dc->buff_in && dc->buff_in_size > 0 ) {
         
    	result = sd_ParseDataA(dc->sd, dc->buff_in, dc->buff_in_size, &readed_len, &dc->sd_dp);
         
		if ( sd_Error(dc->sd) != DPERROR_NONE ) {
			readed_len = dc->buff_in_size;
		}

        sd_truncaterecvbuffer(&dc->buff_in, &dc->buff_in_size, readed_len);

     };
return (result);
};


unsigned char dconnection_ping_timeout(TDConnectionData *dc) {
    
    time_t t = time(0);
    if ( difftime(t, dc->lastPing) >= dc->ping_interval ) {
        return (1);
    };
    
    return (0);
}

unsigned char dconnection_data_timeout(TDConnectionData *dc) {

    time_t t = time(0);
    if ( difftime(t, dc->lastDataReceiveTime ) >= (dc->ping_interval + 10) ) {
        return (1);
    };

    return (0);
}

unsigned char dconnection_timeout(TDConnectionData *dc, int timeout) {

    time_t t = time(0);
    if ( difftime(t, dc->state_time) >= timeout ) {
       return (1);
    };

return (0);
};

char *dconnection_getsentbuffer(void *dc, int *size) {
    TDConnectionData *c = (TDConnectionData*)dc;

    char *result;
    dconnection_lock(c);

    result = c->buff_out;
    c->buff_out = 0;
    *size = c->buff_out_size;
    c->buff_out_size = 0;

    dconnection_unlock(c);

return (result);
};

int dconnection_return(TDConnectionData *c, int result) {

   int state;

   if ( ( result == WRESULT_ONCONNECT
          || result == WRESULT_ONAUTHORIZE )
        && c->conn ) {

        state = dconnection_getstate(c->conn);
        if ( state == DCS_CONNECTED
             || state == DCS_AUTHORIZED  ) {
            result = WRESULT_NONE;
        };

   } else if ( ( result == WRESULT_ONDISCONNECT
          || result == WRESULT_ONUNAUTHORIZE
          || result == WRESULT_DEVICENOTFOUND )
        && c->conn ) {

        state = dconnection_getstate(c->conn);
        if ( state == DCS_CONNECTING
             || state == DCS_AUTHORIZING
             || state == DCS_CONNECTED
             || state == DCS_AUTHORIZED ) {
            result = WRESULT_NONE;
        };
     };
   

   dconnection_unlock(c);
   return (result);
};

int dconnection_work(void *dc) {

    int a;

    TDConnectionData *c = (TDConnectionData*)dc;
    dconnection_lock(c);

    switch(dconnection_getstate(c)) {
       case DCS_ONDISCONNECTED:
            
            dconnection_setstate(c,  DCS_DISCONNECTED);
            return (dconnection_return(c, WRESULT_ONDISCONNECT));

       case DCS_DISCONNECTED:
            
            if ( c->substate == ASS_TRYCONNECT ) {

               if ( dconnection_timeout(c, c->is_proxy == 1 ? RECONNECT_PROXYDELAY : RECONNECT_MASTERDELAY ) ) {

                   c->state_time = time(0);
                   return (dconnection_return(c, WRESULT_TRYCONNECT));
               };

            } else {

               c->substate = ASS_TRYCONNECT;

               if ( c->is_proxy == 0
                    && c->useproxy != USEPROXY_NONE ) {
                  return (dconnection_return(c, WRESULT_PROXYCONNECT));
               };

            };
            break;
            
       case DCS_CONNECTING:

            if ( dconnection_parseinput(c) == 1
                 && c->sd_dp.Action == ACTION_HELLO ) {

              dconnection_setstate(c, DCS_CONNECTED);
              c->state_time = time(0);

              return (dconnection_return(c, WRESULT_ONCONNECT));

            } else if ( sd_Error(c->sd) == DPERROR_VERSION ) {
                
                dconnection_setdisconnected(c, 1);
                return (dconnection_return(c, WRESULT_VERSIONERROR));
                
            } else if ( dconnection_timeout(c, CONNECTING_TIMEOUT) == 1 ) {

              dconnection_setdisconnected(c, 1);
              return (dconnection_return(c, WRESULT_NONE));

            };
            return (dconnection_return(c, WRESULT_WAITFORDATA));

       case DCS_CONNECTED:
            
            if ( c->is_proxy == 0 ) {
                c->LastEventIDS_size = 0;
                c->LastEventIDS_offset = 0;
            }
            
            sd_DataPacketInit(c->sd, &c->sd_dp, ACTION_AUTH, 0);
            memcpy(c->sd_dp.AuthKey, c->AuthKey, AUTHKEY_SIZE);

            c->sd_dp.Param1 = c->OsType;
            c->sd_dp.Param2 = c->Language;
            c->sd_dp.param6DataSize = 0;
            
            if ( c->name
                && strlen(c->name) > 0
                && strlen(c->name) <= sizeof(c->sd_dp.param6) ) {
                
                    c->sd_dp.param6DataSize = strlen(c->name);
                    memcpy(c->sd_dp.param6, c->name, c->sd_dp.param6DataSize);
                    // Simple masquerade
                    for(a=0;a<c->sd_dp.param6DataSize;a++) c->sd_dp.param6[a]-=1;

            };

            dconnection_datapackettobuffer(c, &c->sd_dp);

            dconnection_setstate(c, DCS_AUTHORIZING);
            c->state_time = time(0);
            return (dconnection_return(c, WRESULT_TRYSENDDATA));

       case DCS_AUTHORIZING:
          
            if ( dconnection_parseinput(c) == 1
                 && c->sd_dp.Action == ACTION_RESULT ) {

                if ( c->sd_dp.Param1 == RESULT_TRUE ) {
                     c->lastPing = 0;
                     memcpy(c->AuthKey, c->sd_dp.AuthKey, AUTHKEY_SIZE);
                    
                     sd_SetID(c->sd, c->sd_dp.DID, 1);
                    
                     if ( !c->is_proxy && c->conn ) {
                        dconnection_setserial(c->conn, c->sd_dp.DID);
                     }
                    
                     c->Caps = c->sd_dp.Param2;

                     if ( c->sd_dp.param6DataSize == sizeof(TSipData) ) {
                        memcpy(&c->Sip, c->sd_dp.param6, c->sd_dp.param6DataSize);
                     };

                     c->sd_rr.Action = 0;

                     c->next_requestid = 1;
                     c->substate = c->is_proxy ? ASS_REGISTER_PUSH_ID : ASS_WAITFORDATA;
                     dconnection_setstate(c, DCS_AUTHORIZED);
                     return (dconnection_return(c, WRESULT_ONAUTHORIZE));

                } else {

                   dconnection_setstate(c, DCS_UNAUTHORIZED);
                   return (dconnection_return(c, c->sd_dp.Param1 == RESULT_DEVICENOTFOUND ? WRESULT_DEVICENOTFOUND : WRESULT_ONUNAUTHORIZE));
                };

            } else if ( dconnection_timeout(c, AUTHORIZING_TIMEOUT) == 1 ) {
                dconnection_setdisconnected(c, 1);
                return (dconnection_return(c, WRESULT_NONE));
            };
            return (dconnection_return(c, WRESULT_WAITFORDATA));

       case DCS_UNAUTHORIZED:
            dconnection_setdisconnected(c, 1);
            return (dconnection_return(c, WRESULT_NONE));

       case DCS_AUTHORIZED:
            if ( dconnection_parseinput(c) == 1 ) {
               if ( c->sd_dp.Action == ACTION_EVENT ) {
                    return (dconnection_return(c, WRESULT_ONEVENT));
               } else if ( c->sd_dp.Action == ACTION_WAKEUP
                           && dconnection_ping_timeout(c) == 1 ) {
                   
                       c->lastPing = 0;
                       return (dconnection_return(c, WRESULT_WAKEUP));

               } else if ( c->substate == ASS_WAITFORRESPONSE
                           && c->sd_dp.RequestID == c->sd_rr.RequestID ) {

                       c->substate = ASS_WAITFORDATA;
                   
                       if ( c->sd_rr.Action == ACTION_PING ) {
                          return (dconnection_return(c, WRESULT_ONSYSSTATE));
                       } else if ( c->sd_dp.Param1 == RESULT_LOCKED ) {
                          return (dconnection_return(c, WRESULT_LOCKED));
                       } else {
                          return (dconnection_return(c, WRESULT_ONRESPONSE));
					   }
                   
               };
            };

            if ( c->sd_rr.Action > 0
                 && c->sd_rr.RequestID == c->next_requestid ) {

                  dconnection_datapackettobuffer(c, &c->sd_rr);
                  c->substate = ASS_WAITFORRESPONSE;
                  c->lastPing = time(0);
                  c->state_time = time(0);
                  c->next_requestid++;
                  return (dconnection_return(c, WRESULT_TRYSENDDATA));
            };

            if ( dconnection_data_timeout(c) == 1 ) {
            	dconnection_setdisconnected(c, 1);
            	return dconnection_return(c, WRESULT_NONE);
            }

            switch(c->substate) {
               case ASS_WAITFORDATA:
                    c->substate = ( c->is_proxy == 0 && c->useproxy == USEPROXY_INSTANT ) ? ASS_PROXYDISCONNECT : ASS_NONE;
                    return (dconnection_return(c, WRESULT_WAITFORDATA));
               case ASS_NONE:
                    
                    if ( dconnection_ping_timeout(c) == 1 ) {
                        sd_DataPacketInit(c->sd, &c->sd_rr, ACTION_PING, 0);
                        memcpy(c->sd_rr.AuthKey, c->AuthKey, AUTHKEY_SIZE);
                        c->sd_rr.RequestID = c->next_requestid;
                        c->substate = ASS_WAITFORRESPONSE;

                    } else {
                        c->substate = ASS_WAITFORDATA;
                    }
                
                    return (dconnection_return(c, WRESULT_NONE));
                    
               case ASS_WAITFORRESPONSE:
                    if ( dconnection_timeout(c, WAITFORRESPONSE_TIMEOUT) == 1 ) {
                       c->substate = ASS_NONE;
                       return (dconnection_return(c, WRESULT_RESPONSETIMEOUT));
                    };
                    return (dconnection_return(c, WRESULT_WAITFORDATA));
               case ASS_PROXYDISCONNECT:
                    c->substate = ASS_NONE;
                    return (dconnection_return(c, WRESULT_PROXYDISCONNECT));
               case ASS_REGISTER_PUSH_ID:
                    c->substate = ASS_NONE;
                    return (dconnection_return(c, WRESULT_REGISTER_PUSH_ID));
                    
            };

            break;
    };


return (dconnection_return(c, WRESULT_NONE));
};

void dconnection_getauthkey(void *dc, void *AuthKey) {

     dconnection_lock(dc);
     memcpy(AuthKey, ((TDConnectionData*)dc)->AuthKey, AUTHKEY_SIZE);
     dconnection_unlock(dc);

};

unsigned char dconnection_getconnectionsettings(void *dc, TConnectionSettings *cs) {
    
    TDConnectionData *c = (TDConnectionData*)dc;
    unsigned char result = 0;

     dconnection_lock(c);

     if ( c->state == DCS_AUTHORIZED ) {
         
         memcpy(cs->AuthKey, c->AuthKey, AUTHKEY_SIZE);

         sd_GetID(c->sd, cs->SerialKey, 1);
         
         memcpy(&cs->Sip, &c->Sip, sizeof(TSipData));
         cs->Caps = c->Caps;
         result = 1;
         cs->proxy = c->is_proxy;
         
     } else if ( !c->is_proxy
                && c->conn ) {
         result = dconnection_getconnectionsettings(c->conn, cs);
     }


     dconnection_unlock(c);
    
    return (result);
};

wchar_t* dconnection_get_wchar(char *buffer, size_t buffer_size) {

    wchar_t* out;

    if ( buffer == 0
        || buffer_size < 1 ) return (0);

    out = malloc(buffer_size * sizeof(wchar_t) + sizeof(wchar_t));
    buffer_size = mbstowcs (out, buffer, buffer_size+1);
    
    if ( buffer_size > 0 ) {
        return (out);
    } else {
        free(out);
    }
    
    return (0);
}

void dconnection_extract_name_and_id(TDataPacket *dp, char **name, char *_id) {
    
    int a;
    char buff[PARAM6_MAX_SIZE];
    int size;
    
    if ( name ) {
      *name = 0;  
    }
    
    if ( dp->param6DataSize >= ID_SIZE ) {
        
        if ( _id ) {
            memcpy(_id, dp->param6, ID_SIZE);
        }
    
        if ( name
             && dp->param6DataSize > ID_SIZE ) {
            
            for(a=0; a<dp->param6DataSize-ID_SIZE;a++)
                buff[a] = dp->param6[a+ID_SIZE];
            
            size = dp->param6DataSize-ID_SIZE;
            buff[size] = 0;
            
            // Simple demasquerade
            for(a=0;a<size;a++) buff[a]+=1;
            
            *name = strdup(buff);
        
        };
    }
}

unsigned char dconnection_getevent(void *dc, TdEvent *event, unsigned char *duplicate) {
     TDConnectionData *ce;
     TDConnectionData *c = (TDConnectionData*)dc;

     int a;
     unsigned char result = 0;

     if ( duplicate ) {
       *duplicate = 0;
     }   

     dconnection_lock(c);

     event->SenderName = 0;

     if ( c->sd_dp.Action == ACTION_EVENT ) {
         
        event->ID = c->sd_dp.Param1;
         
        ce = c->is_proxy ? (TDConnectionData*)c->conn : c;
         
        if ( ce ) {
            if ( duplicate ) {
                for(a=0;a<ce->LastEventIDS_size;a++) {
                    if ( ce->LastEventIDS[a] == event->ID ) {
                        *duplicate = 1;
                        break;
                    }
                }
            }
            
            if ( !duplicate || !*duplicate ) {
                ce->LastEventIDS[ce->LastEventIDS_offset] = event->ID;
                if ( ce->LastEventIDS_size < sizeof(ce->LastEventIDS)/sizeof(int) ) {
                    ce->LastEventIDS_size++;
                }
                
                ce->LastEventIDS_offset++;
                if ( ce->LastEventIDS_offset >= sizeof(ce->LastEventIDS)/sizeof(int) ) {
                    ce->LastEventIDS_offset = 0;
                }
            }
        }


         

        event->Type = c->sd_dp.Param2;
        event->Scope = c->sd_dp.Param3;
        event->Owner = c->sd_dp.Param4 == EVENTOWNER_TRUE ? 1 : 0;
        event->Param1 = c->sd_dp.Param5;
        
        dconnection_extract_name_and_id(&c->sd_dp, &event->SenderName, event->SenderID);
         
         /*
        event->SenderName = 0;
        if ( c->sd_dp.param6DataSize >= ID_SIZE ) {
            memcpy(event->SenderID, c->sd_dp.param6, ID_SIZE);
            if ( c->sd_dp.param6DataSize > ID_SIZE ) {

            	for(a=0; a<c->sd_dp.param6DataSize-ID_SIZE;a++)
            		c->sd_dp.param6[a] = c->sd_dp.param6[a+ID_SIZE];

            	c->sd_dp.param6DataSize-=ID_SIZE;
            	c->sd_dp.param6[c->sd_dp.param6DataSize] = 0;
                
                // Simple demasquerade
                for(a=0;a<c->sd_dp.param6DataSize;a++) c->sd_dp.param6[a]+=1;
                
                event->SenderName = dconnection_get_wchar(c->sd_dp.param6, c->sd_dp.param6DataSize+1);

            	buff = malloc(c->sd_dp.param6DataSize * sizeof(wchar_t) + sizeof(wchar_t));
            	buff_size = mbstowcs (buff, c->sd_dp.param6, c->sd_dp.param6DataSize+1);

            	if ( buff_size > 0 ) {
                	event->SenderName = wcsdup(buff);
            	}

            	free(buff);
            };
        }
         */

        result = 1;
     };

     dconnection_unlock(c);

return (result);
};

void dconnection_getlastdatapacket(void *dc, TDataPacket *dp) {
    dconnection_lock(dc);
    memcpy(dp, &((TDConnectionData*)dc)->sd_dp, sizeof(TDataPacket));
    dconnection_unlock(dc);
};

int dconnection_request(void *dc, TDataPacket *dp) {
   TDConnectionData* c = (TDConnectionData*)dc;

   int result = 0;
   dconnection_lock(dc);

   if ( c->state == DCS_AUTHORIZED ) {
      memcpy(&c->sd_rr, dp, sizeof(TDataPacket));
      c->sd_rr.RequestID = c->next_requestid;
      result = c->sd_rr.RequestID;
   };

   
   if ( !c->is_proxy
        && c->conn
        && ( dp->Action != ACTION_SIPCONNECT
             || c->state != DCS_AUTHORIZED ) ) {
       dconnection_request(c->conn, dp);
   };

#ifdef __linux__
   dconnection_raise_data_event(dc);
#endif
   dconnection_unlock(dc);

return (result);
};

#ifdef _DEBUG
int dconnection_stream(void *dc, int ID, int DataType, int TotalSize, char *data, int data_size, int pos) {

    TDataPacket rr;
    TDConnectionData *c;

    if ( data_size > PARAM6_MAX_SIZE
     	|| data_size == 0 ) return (-1);

    c =  (TDConnectionData*)dc;
    sd_DataPacketInit(c->sd, &rr, ACTION_STREAM, 0);
    memcpy(rr.AuthKey, c->AuthKey, AUTHKEY_SIZE);

    rr.Param1 = ID;
    rr.Param2 = DataType;
    rr.Param3 = TotalSize;
    rr.Param4 = pos;
    rr.param6DataSize = data_size;

    memcpy(rr.param6, data, data_size);

    return (dconnection_request(dc, &rr));
}
#endif

int dconnection_request_action(void *dc, int action, int param2, int param3, int param4, int param5) {

    TDataPacket rr;
    TDConnectionData *c =  (TDConnectionData*)dc;
    sd_DataPacketInit(c->sd, &rr, action, 0);
    memcpy(rr.AuthKey, c->AuthKey, AUTHKEY_SIZE);

    dconnection_lock(dc);

    if ( c->is_proxy && (TDConnectionData*)c->conn )
    	c = (TDConnectionData*)c->conn;

    rr.Param1 = c->ActionUniqueID;
	c->ActionUniqueID++;

    dconnection_unlock(dc);

    rr.Param2 = param2;
    rr.Param3 = param3;
    rr.Param4 = param4;
    rr.Param5 = param5;
    rr.param6DataSize = 0;

    return (dconnection_request(dc, &rr));
};

void dconnection_send_disconnect(void *dc) {
	dconnection_request_action(dc, ACTION_DISCONNECT, 0, 0, 0, 0);
}

int dconnection_opengate(void *dc, int num) {
    int action = 0;

    switch(num) {
      case 1:
           action = ACTION_OPEN1;
           break;
      case 2:
           action = ACTION_OPEN2;
           break;
      case 3:
           action = ACTION_OPEN3;
           break;
    };

    return (dconnection_request_action(dc, action, 0, 0, 0, 0));
};

int dconnection_sipconnect(void *dc, unsigned char speaker_on, unsigned char video) {
    
    int param1 = 0;
    
    if ( speaker_on == 1 )
        param1|= SCATTR_SPEAKERON;
    
    if ( video == 1 )
        param1|= SCATTR_VIDEO;
    
    return (dconnection_request_action(dc, ACTION_SIPCONNECT, param1, 0, 0, 0));
};


int dconnection_sipdisconnect(void *dc) {
   return dconnection_request_action(dc, ACTION_SIPDISCONNECT, 0, 0, 0, 0);
};

void dconnection_getresponse(void *dc, TDataPacket *dp) {
    dconnection_lock(dc);
    memcpy(dp, &((TDConnectionData*)dc)->sd_dp, sizeof(TDataPacket));
    dconnection_unlock(dc);
};

unsigned char dconnection_isproxy(void *dc) {
    return (((TDConnectionData*)dc)->is_proxy);
}

void dconnection_getserial(void *dc, char *serial) {
    sd_GetID(((TDConnectionData*)dc)->sd, serial, 1);
}

void dconnection_setserial(void *dc, char *serial) {
    sd_SetID(((TDConnectionData*)dc)->sd, serial, 1);
}

unsigned char dconnection_get_sys_state(void *dc, int *state, int *firmware_version) {

    unsigned char result = 0;
    TDConnectionData* c = (TDConnectionData*)dc;
    
    dconnection_lock(c);
    
    if ( state ) *state = 0;
    if ( firmware_version ) *firmware_version = 0;
    
    if ( c->sd_rr.Action == ACTION_PING
         && c->sd_rr.RequestID == c->sd_dp.RequestID
         && c->sd_dp.Param1 == RESULT_TRUE ) {

    	if ( state ) *state = c->sd_dp.Param2;
    	if ( firmware_version ) *firmware_version = c->sd_dp.Param3;

    	result = 1;
    }
    
    dconnection_unlock(c);
    
    return (result);   
}

void dconnection_set_push_id(void *dc, char *push_id, int push_id_size) {
    TDataPacket rr;
    TDConnectionData *c =  (TDConnectionData*)dc;
    
    if ( !push_id
        || push_id_size == 0
        || push_id_size > 2048
        || push_id_size > PARAM6_MAX_SIZE ) return;
    
    if ( !c->is_proxy && c->conn ) {
        
        dconnection_set_push_id(c->conn, push_id, push_id_size);
        
    } else if ( c->is_proxy ) {
        
        sd_DataPacketInit(c->sd, &rr, ACTION_SET_PUSH_ID, 0);
        memcpy(rr.AuthKey, c->AuthKey, AUTHKEY_SIZE);
        
        memcpy(rr.param6, push_id, push_id_size);
        rr.param6DataSize = push_id_size;
        
        dconnection_request(dc, &rr);
    }
    

}

void dconnection_setspeakeronoff(void *dc, unsigned char on) {
    dconnection_request_action(dc, ACTION_SPEAKER_ONOFF, on ? 1 : 0, 0, 0, 0);
}

unsigned char dconnection_is_authorized(void *dc) {
    
    TDConnectionData *c;
    
    if ( dconnection_getstate(dc) == DCS_AUTHORIZED ) {
        return (1);
    } else {
        c = (TDConnectionData*)dc;
        if ( c->conn
            && dconnection_getstate(c->conn) == DCS_AUTHORIZED  ) {
            return (1);
        }
    }
    return (0);
}



