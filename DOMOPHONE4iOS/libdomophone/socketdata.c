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

#include "socketdata.h"
#include "assert.h"
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#ifdef __WIN32__
  #define bzero(a,b) \
          memset(a, 0, b)

#include <winsock.h>

#define	MSG_DONTWAIT	0

#else
#include <sys/socket.h>
#include <unistd.h>
#endif

typedef struct
{
	int sockfd;
	unsigned int dp_datasize;
	unsigned int dp_pos;
	unsigned char disconnected;
	int dp_error;

	TDataPacket dp_data;
	TInOutDataQueue *dataq;
	int RequestID;

	char cid[ID_SIZE];
	char did[ID_SIZE];

	char *recv_buffer;
	int recv_buffer_size;

}TSocketData;

void sd_DataPacketInit(void *sd, TDataPacket *DP, unsigned int Action, unsigned int RequestID) {
    
    assert(sd && DP);
    
	bzero(DP, sizeof(TDataPacket));
	DP->Action = Action;
	DP->Version = DP_VERSION;
	DP->RequestID = RequestID;
	memcpy(DP->DID, ((TSocketData*)sd)->did, ID_SIZE);
	memcpy(DP->CID, ((TSocketData*)sd)->cid, ID_SIZE);
};

void sd_read_int(unsigned int *pos, char *buffer, int buffer_size, unsigned int *i) {
	int n;

	for(n=0; n<buffer_size && *pos <4; n++) {
		((char *)i)[*pos] = buffer[n];
		(*pos)++;
	}

};

void sd_ParseReset(void *sd) {
    
	assert(sd);
    
	((TSocketData*)sd)->dp_datasize = 0;
	((TSocketData*)sd)->dp_pos = 0;
	bzero(&((TSocketData*)sd)->dp_data, sizeof(TDataPacket));
}

unsigned char sd_ParseDataA(void *sd, char *buffer, int buffer_size, int *readed_len, TDataPacket *DP) {

	assert(sd);

	unsigned char result = 0;
	int x=0;
	TSocketData *d = (TSocketData*)sd;
    
	*readed_len = 0;

	if ( d->dp_pos < 4 ) {
		sd_read_int(&d->dp_pos, buffer, buffer_size, &d->dp_datasize);
		x=d->dp_pos;
	};

	if ( d->dp_pos == 4 ) {

		d->dp_data.Version = buffer[x];

		if ( d->dp_datasize > sizeof(TDataPacket) || d->dp_datasize == 0 ) {
			d->dp_error = DPERROR_UNKNOWN;
			sd_ParseReset(sd);
		} else if ( d->dp_data.Version != DP_VERSION ) {
			d->dp_error = DPERROR_VERSION;
			sd_ParseReset(sd);
		} else {
			x++;
			d->dp_pos++;
		}
	}


	if ( d->dp_pos > 4 ) {

		while(x<buffer_size && d->dp_pos-4<d->dp_datasize) {

			((char*)&d->dp_data)[d->dp_pos-4] = buffer[x];
			d->dp_pos++;
			x++;
		}

		if (d->dp_pos-4 == d->dp_datasize) {
			*DP = d->dp_data;
			result = 1;
			sd_ParseReset(sd);
		}


	}

	*readed_len = x;
	return result;
}

unsigned char sd_ParseDataB(void *sd, TDataPacket *DP) {

	assert(sd);

	char buffer[BUFF_SIZE];
	int readed_len;
	unsigned char result = 0;
	TSocketData *d = (TSocketData *)sd;

	ssize_t data_size = 0;

	if ( d->dataq ) {
		data_size = sd_QueueToBuffer(d->dataq, 0, buffer, BUFF_SIZE);
		if ( data_size == 0 ) {
			data_size = -1;
		} else if ( data_size == -1 ) {
			data_size = 0;
		}

	} else {
		data_size = recv(d->sockfd, buffer, BUFF_SIZE, MSG_DONTWAIT);
	}

	if (data_size > 0) {
		sd_appendrecvbuffer(&d->recv_buffer, &d->recv_buffer_size, buffer, data_size);
	} else if ( data_size == 0 ) {
		d->disconnected = 1;
		return 0;
	};

	if ( d->recv_buffer_size > 0
		 && d->recv_buffer ) {

		do {
			result = sd_ParseDataA(sd, d->recv_buffer, d->recv_buffer_size, &readed_len, DP);

			if ( sd_Error(sd) != DPERROR_NONE ) {
				readed_len = d->recv_buffer_size;
			}

			sd_truncaterecvbuffer(&d->recv_buffer, &d->recv_buffer_size, readed_len);
		} while(result == 0 && d->recv_buffer_size > 0);
	}

	return result;
}

char * sd_DataPacketToBuffer(TDataPacket *DP, int *buff_size) {
	char *buffer;
	int datasize = sizeof(TDataPacket) - sizeof(DP->param6) + DP->param6DataSize;
	*buff_size =  datasize+sizeof(datasize);

        buffer = (char*)malloc(*buff_size);
	memcpy(buffer, &datasize, sizeof(datasize));
	memcpy(&buffer[sizeof(datasize)], DP, datasize);

return buffer;
}

int sd_QueueToBuffer(TInOutDataQueue *dataq, char out, char *buffer, int buffer_size) {

	char *qdata;
	int *qdsize;
	int *qdoffset;
        int data_size;

	if ( dataq->lock_func ) {
		dataq->lock_func(dataq->ptr);
	}

	if ( out ) {
		qdata = dataq->out_buff;
		qdsize = &dataq->out_size;
		qdoffset = &dataq->out_offset;
	} else {
		qdata = dataq->in_buff;
		qdsize = &dataq->in_size;
		qdoffset = &dataq->in_offset;
	}

	data_size = (*qdsize) - (*qdoffset);

	if ( data_size > 0 ) {
		if ( data_size > buffer_size ) {
			data_size = buffer_size;
		}
		memcpy(buffer, &qdata[*qdoffset], data_size);
		*qdoffset += data_size;
	} else if ( *qdsize > 0 ) {
		free(qdata);
		qdata = NULL;
		*qdsize = 0;
		*qdoffset = 0;
	}

	if ( out ) {
		dataq->out_buff = qdata;
	} else {
		dataq->in_buff = qdata;
	}

	if ( dataq->unlock_func ) {
		dataq->unlock_func(dataq->ptr);
	}

	return data_size;
}

unsigned char sd_DataAppendQueue(TInOutDataQueue *dataq, char out, char *data, int datasize) {

	char *qdata;
	int *qdsize;
	int *qdoffset;

	unsigned char result = 0;

	if ( dataq->lock_func ) {
		dataq->lock_func(dataq->ptr);
	}

	if ( out ) {
		qdata = dataq->out_buff;
		qdsize = &dataq->out_size;
		qdoffset = &dataq->out_offset;
	} else {
		qdata = dataq->in_buff;
		qdsize = &dataq->in_size;
		qdoffset = &dataq->in_offset;
	}

    if ( ((*qdsize) + datasize) < MAXQDATA_SIZE ) {

    	char *n =  malloc((*qdsize)-(*qdoffset)+datasize);
    	memcpy(n, &qdata[(*qdoffset)], (*qdsize)-(*qdoffset));
    	free(qdata);

    	*qdsize = (*qdsize)-(*qdoffset);
    	*qdoffset = 0;

    	memcpy(&n[*qdsize], data, datasize);
    	qdata = n;

        *qdsize += datasize;

    	if ( out ) {
    		dataq->out_buff = qdata;
    	} else {
    		dataq->in_buff = qdata;
    	}

    	result = 1;
    }

	if ( dataq->unlock_func ) {
		dataq->unlock_func(dataq->ptr);
	}

	if ( result == 1 ) {
		if ( out && dataq->data_out_event_func ) {
			dataq->data_out_event_func(dataq->ptr);
		} else if ( !out && dataq->data_in_event_func ) {
			dataq->data_in_event_func(dataq->ptr);
		}
	}

return result;
}

void sd_SendPacket(void *sd, TDataPacket *DP) {

	assert(sd && DP);

	int buff_size;

	char *buff = sd_DataPacketToBuffer(DP, &buff_size);
	TSocketData *d = (TSocketData*)sd;

	if ( buff ) {
        
        if ( buff_size > 0 ) {
            if ( d->dataq ) {
                sd_DataAppendQueue(d->dataq, 1, buff, buff_size);
            } else {
                send(((TSocketData*)sd)->sockfd, buff, buff_size, 0);
            }
        }

		free(buff);
	}
}


unsigned char sd_Request(void *sd, TDataPacket *Request, TDataPacket *Response) {

	assert(sd);

	TDataPacket R;
	unsigned char Result = 0;
	int timeout = 3000; // ~ 3 sec.

	((TSocketData *)sd)->RequestID++;
	Request->RequestID = ((TSocketData *)sd)->RequestID;
	sd_SendPacket(sd, Request);

	do {

		if ( sd_ParseDataB(sd, &R)
			 && R.Action == ACTION_RESULT
			 && R.RequestID == Request->RequestID ) {

			*Response = R;
			Result = 1;

		} else {
			timeout--;
                        #ifdef __WIN32__
                        Sleep(1);
                        #else
			usleep(1000);
                        #endif
		}


	}while(timeout > 0 && Result == 0 );

return Result;
}

void sd_SetID(void *sd, char *_id, char did) {
    
	assert(sd);
    
	if ( _id == NULL ) {
		bzero(did == 0 ? ((TSocketData *)sd)->cid : ((TSocketData *)sd)->did, ID_SIZE);
	} else {
	  memcpy(did == 0 ? ((TSocketData *)sd)->cid : ((TSocketData *)sd)->did, _id, ID_SIZE);
	};
}

void sd_GetID(void *sd, char *_id, char did) {

   assert(sd);

   if ( (did == 0 ? ((TSocketData *)sd)->cid : ((TSocketData *)sd)->did) != NULL ) {
     memcpy(_id, did == 0 ? ((TSocketData *)sd)->cid : ((TSocketData *)sd)->did, ID_SIZE);
   };
};

unsigned char sd_IsDisconnected(void *sd) {

	assert(sd);

	return ((TSocketData *)sd)->disconnected;
}

int sd_Error(void *sd) {

	assert(sd);

	return ((TSocketData *)sd)->dp_error;
}

void *sd_init(int sfd, TInOutDataQueue *dataq, char *_did, char *_cid) {

	TSocketData *sd = (TSocketData*)malloc(sizeof(TSocketData));
	sd->disconnected = 0;
	sd->dp_error = DPERROR_NONE;
	sd->RequestID = 0;
	sd->sockfd = sfd;
	sd->dataq = dataq;
	sd_SetID(sd, _did, 1);
	sd_SetID(sd, _cid, 0);
	sd_ParseReset(sd);

	sd->recv_buffer = NULL;
	sd->recv_buffer_size = 0;

return sd;
};

void sd_release(void *sd) {

	if ( sd ) {

	  if ( ((TSocketData*)sd)->recv_buffer ) {
		  free(((TSocketData*)sd)->recv_buffer);
		  ((TSocketData*)sd)->recv_buffer = NULL;
	  }

	  free(sd);
	}

}

void sd_appendrecvbuffer(char **recv_buffer, int *recv_buffer_size, char *data, int data_size) {

   if ( data != 0
        && data_size > 0 )
     {
	     *recv_buffer = (char *)realloc(*recv_buffer, data_size+(*recv_buffer_size));
         memcpy(&((*recv_buffer)[*recv_buffer_size]), data, data_size);
         *recv_buffer_size+=data_size;
     };
};

void sd_truncaterecvbuffer(char **recv_buffer, int *recv_buffer_size, int readed_len) {

   char *buff;

   if ( readed_len > 0 )
     {
       if ( readed_len >= *recv_buffer_size ) {
          free(*recv_buffer);
          *recv_buffer = 0;
          *recv_buffer_size = 0;
       } else {
    	   *recv_buffer_size = *recv_buffer_size-readed_len;
          buff = (char*)malloc(*recv_buffer_size);
          memcpy(buff, &((*recv_buffer)[readed_len]), *recv_buffer_size);
          free(*recv_buffer);
          *recv_buffer = buff;
       };
     };
};
