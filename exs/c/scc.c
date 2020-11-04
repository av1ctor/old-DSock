/*
 * scc.c -- client for Simple Chat protocol
 * copyleft 2002 by v1ctor (av1ctor@yahoo.com.br)
 */

#include <stdio.h>
#include <stdlib.h>
#include "..\..\inc\dsock.h"
#include "queue.h"
#include "string.h"
#include "schat.h"

#define SCP_TICKS		1

#define SCP_OFFLINE		0
#define SCP_ONLINE		1
#define SCP_CONNECTING	2
#define SCP_CONNECTED 	3
#define SCP_JOINING		4
#define SCP_JOINED		5
#define SCP_STATES		6

#define BUFF_LEN		(SCP_MAXLEN+SCP_HDRLEN+1)

typedef struct _TSC {
	int					state;
	char 				nick[SCP_NICKLEN+1];
	SOCKET				hostSocket;
	SOCKADDR_IN 		sa;
	int					cmd;
} TSC, far *PSC;

typedef struct _TUSER {
	int					state;
	char 				nick[SCP_NICKLEN+1];
	int					mode;
} TUSER, far *PUSER;

typedef struct _TMSG {
	int					id;
	int					completed;
	int					start;
	int					length;

	int					cmd;
	char				msg[SCP_MAXLEN+1];
} TMSG, far *PMSG;

// globals :::
TSC 	ctx;

QUEUE	user_q = { 0 },
		imsg_q = { 0 },
		omsg_q = { 0 };

#define SCP_STATES 6

char 	sttTB[SCP_STATES][16] = { "OFFLINE", "ONLINE", "CONNECTING",
							     "CONNECTED", "JOINING", "JOINED" };


int 			sccReceive 		( void );
void 			sccIncoming 	( char *buffer, int len );
void 			sccMain 		( void );
void 			sccEnd 			( void );
int 			sccInit 		( void );
void 			sccProcess 		( void );
int 			sccSend 		( void );
void 			sccDisconnect 	( void );
int 			sccConnect 		( char *server );
int 			sccConnecting 	( void );

PUSER 			userByNick 		( char far *nick );
void 			userDel 		( PUSER u );
PUSER 			userAdd 		( char far *nick );

PMSG 			msgByID 		( QUEUE *q, int id );
void 			msgDel 			( QUEUE *q, PMSG m );
void 			msgDelHead 		( QUEUE *q );
void 			msgDelTail 		( QUEUE *q );
void 			iMsgAdd 		( PMSG m, int id, int start, int length, int cmd,
							  	  int completed, char far *message, int msglen );
void 			oMsgAdd 		( PMSG m, int length, int cmd, char far *message );
PMSG 			msgNew 			( QUEUE *q );

void 			tokenize 		( char *text, int *tokenc, char *tokenv[], int tokenp[], int maxc );
unsigned short 	hwtoi 			( unsigned char far *hex );
unsigned char 	hbtoi 			( unsigned char far *hex );
unsigned long 	itohw 			( unsigned short num );
unsigned short 	itohb 			( unsigned short num );

#define printw printf


/**********************************************************/
int main ( int arc, void *argv[] )
{
	if ( !sccInit( ) ) return -1;

	sccMain( );

	sccEnd( );

	return 0;
}

/***************************************************************************/
/* client routines														   */
/***************************************************************************/

/**********************************************************/
int sccInit ( void )
{
	int 		nRet;
	WORD 		wVersionRequested = MAKEWORD( 1,1 );
	WSADATA 	wsaData;

	ctx.state 		= SCP_OFFLINE;
	ctx.hostSocket 	= INVALID_SOCKET;
	ctx.cmd 		= 0;
	ctx.nick[0]		= '\0';

	printf( "starting...\n" );

	//
	// create/initialize queues
	//
	if ( !queue_create( &user_q, SCP_MAXUSERS, sizeof( TUSER ) ) ||
		 !queue_create( &imsg_q, SCP_MAXMSGS, sizeof( TMSG ) )   ||
		 !queue_create( &omsg_q, SCP_MAXMSGS, sizeof( TMSG ) )   )
		return 0;

	//
	// Initialize WinSock.dll
	//
	nRet = WSAStartup( wVersionRequested, &wsaData );
	if ( nRet != 0 )
	{
		report_error( "WSAStartup()", nRet );
		return 0;
	}

	//
	// Check WinSock version
	//
	if ( wsaData.wVersion != wVersionRequested )
	{
		report_error( "WinSock version not supported", 0 );
		WSACleanup( );
		return 0;
	}

	clrscr() ;

    return 1;
}

/**********************************************************/
void sccEnd ( void )
{

	printf( "closing...\n" );

	//
	// close socket
	//
	if ( ctx.hostSocket != INVALID_SOCKET )
	{
		shutdown( ctx.hostSocket, 2 );
		closesocket( ctx.hostSocket );
		ctx.hostSocket = INVALID_SOCKET;
	}

	//
	// Release WinSock
	//
	WSACleanup( );

	// delete queues
	queue_destroy( &user_q );
	queue_destroy( &imsg_q );
	queue_destroy( &omsg_q );
}

/**********************************************************/
void sccMain ( void )
{
    int 	finish;

    finish = 0;
	while ( finish == 0 )
	{
		if ( sccReceive( ) )
		{
			report_error( "sccReceive()", WSAGetLastError( ) );
			break;
		}

		finish = sccUI( );

		sccProcess( );

		if ( sccSend( ) )
		{
			report_error( "sccSend ()", WSAGetLastError( ) );
			break;
		}

		if ( ctx.cmd == SCP_QUIT )
			sccDisconnect( );

		ctx.cmd = 0;
	}
}

/**********************************************************/
void sccIncoming ( char *buffer, int len )
{
    int		p, id, start, length, cmd, complete, msglen;
	char	*emark, *imark;
	PMSG	m;

	buffer[len] = '\0';

	// add messages to incoming queue
    p = 0;
	while ( len >= SCP_HDRLEN )
	{
        id      = hwtoi( &buffer[p+SCP_IDPOS] );
        start   = hbtoi( &buffer[p+SCP_STARTPOS] );
        length  = hbtoi( &buffer[p+SCP_LENPOS] );
        cmd     = hbtoi( &buffer[p+SCP_CMDPOS] );

        emark   = strchr( &buffer[p+SCP_MSGPOS], SCP_ENDMARK );
        imark   = strchr( &buffer[p+SCP_MSGPOS], SCP_INIMARK );

		if ( emark != NULL )
		{
			if ( imark != NULL )
			{
				if ( emark < imark )
				{
					msglen = (emark-buffer-1)-(p+SCP_MSGPOS);
					complete = 1;
				}
				else
				{
					msglen = (imark-buffer-1)-(p+SCP_MSGPOS);
					complete = 0;
				}
			}
			else
			{
				msglen = (emark-buffer-1)-(p+SCP_MSGPOS);
				complete = 1;
			}
		}
		else
		{
			if ( imark != NULL )
				msglen = (imark-buffer-1)-(p+SCP_MSGPOS);
			else
				msglen = len;

			complete = 0;
		}

		m = msgByID( &imsg_q, id );
		if ( m == NULL )
			m = msgNew( &imsg_q );
		if ( m != NULL )
			iMsgAdd( m, id, start, length, cmd, complete,
                     &buffer[p+SCP_MSGPOS], msglen );

        p += (SCP_HDRLEN + msglen);
       	len -= (SCP_HDRLEN + msglen);
	}
}

/**********************************************************/
int sccReceive ( void )
{
	fd_set 		rfds,
				efds;
	TIMEVAL 	tv;
	int 		nRet;

    static long lastTimer,
    			currTimer;

	static char buffer[BUFF_LEN];

	// not connected?
	if ( ctx.state == SCP_OFFLINE )
		return 0;

	// enough time elapsed (do not do polling too much times p/ sec)?
	currTimer = clock( );
	if ( abs(currTimer - lastTimer) < SCP_TICKS )
		return 0;
	lastTimer = currTimer;

	// poll host socket, checking for incoming messages
	tv.tv_sec = 0; tv.tv_usec = 0;

	FD_ZERO( &rfds );
	FD_SET( ctx.hostSocket, &rfds );
	FD_ZERO( &efds );
	FD_SET( ctx.hostSocket, &efds );
    nRet = select( 0, &rfds, 0, &efds, &tv );

	// nothing new?
	if ( nRet == 0 )
		return 0;

    // error? dang!
    if ( (nRet < 0) || (efds.fd_count != 0) )
        return 1;

	nRet = recv( ctx.hostSocket, (char far *)&buffer, SCP_MAXLEN+SCP_HDRLEN, 0 );
	if ( nRet == SOCKET_ERROR )
		return 1;

	if ( nRet == 0 ) 	 				// connection closed?
	{
		sccDisconnect( );
		return 0;
	}

	sccIncoming( buffer, nRet );

	return 0;
}

/**********************************************************/
int sccConnecting ( void )
{
	fd_set 		wfds,
				efds;
	TIMEVAL 	tv;
	int 		nRet;

	// not connecting?
	if ( (ctx.state != SCP_CONNECTING) ||
		 (ctx.hostSocket == INVALID_SOCKET) )
		return 0;

	tv.tv_sec = 0; tv.tv_usec = 0;

	FD_ZERO( &wfds );
	FD_SET( ctx.hostSocket, &wfds );
	FD_ZERO( &efds );
	FD_SET( ctx.hostSocket, &efds );
	nRet = select( 0, 0, &wfds, &efds, &tv );

	if ( nRet == 0 )
		return 0;

	if ( (nRet < 0) || (efds.fd_count != 0) )
	{
	   	ctx.state = SCP_OFFLINE;
    	closesocket( ctx.hostSocket );
    	ctx.hostSocket = INVALID_SOCKET;
	   	if ( efds.fd_count != 0 ) WSASetLastError( WSAEHOSTUNREACH );
	   	return 1;
	}

	ctx.state = SCP_CONNECTED;
	return 0;
}

/**********************************************************/
int sccConnect ( char *server )
{
	int			nRet,
				port;
	char		*p;
	LPHOSTENT 	host;
	IN_ADDR     ia;
	SOCKADDR_IN	sa;
	u_long		tmp;

	if ( ctx.state != SCP_OFFLINE )
	{
		printw( "*** Already connected or connecting" );
		return 0;
	}

	p = strchr( server, ':' );
	if ( p != NULL )
	{
		port = atoi( &p[1] );
		*p = '\0';
	}
	else
		port = SCP_DEFPORT;

	//
	// Resolve host name
	//
	ia.s_addr = inet_addr( server );
	if ( ia.s_addr == INADDR_NONE )
	{
		host = gethostbyname( server );
		if ( host == NULL )
		{
			printw( "[ERROR] gethostbyname(): %d", WSAGetLastError( ) );
			return 1;
		}
	}
	else
	{
		host = gethostbyaddr( (const char * )&ia,
							  sizeof( struct in_addr ), AF_INET );
		if ( host == NULL )
		{
			printw( "[ERROR] gethostbyaddr(): %d", WSAGetLastError( ) );
			return 1;
		}
	}

	//
	// Fill in the address structure
	//
	sa.sin_family = AF_INET;
	sa.sin_addr = *( (LPIN_ADDR )*host->h_addr_list );
	sa.sin_port = htons( port );

    //
    // Create a TCP/IP stream socket
    //
    ctx.hostSocket = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
    if ( ctx.hostSocket == INVALID_SOCKET )
    {
        printw( "[ERROR] socket(): %d", WSAGetLastError( ) );
        return 1;
    }

    //
    // Put socket in non-blocking mode
    //
    tmp = 1;
    if ( ioctlsocket( ctx.hostSocket, FIONBIO, &tmp ) == SOCKET_ERROR )
    {
    	printw( "[ERROR] ioctlsocket(): %d", WSAGetLastError( ) );
    	closesocket( ctx.hostSocket );
    	ctx.hostSocket = INVALID_SOCKET;
    	return 1;
    }

	//
	//
	//
	nRet = connect( ctx.hostSocket, (struct sockaddr far *)&sa, sizeof( sa ) );
	if ( nRet == SOCKET_ERROR )
	{
		if ( WSAGetLastError( ) != WSAEWOULDBLOCK )
		{
    		printw( "[ERROR] connect(): %d", WSAGetLastError( ) );
    		closesocket( ctx.hostSocket );
    		ctx.hostSocket = INVALID_SOCKET;
    		return 1;
    	}
	}

	ctx.state = SCP_CONNECTING;
	return 0;
}

/**********************************************************/
void sccDisconnect ( void )
{

	if ( ctx.hostSocket == INVALID_SOCKET )
		return;

	if ( ctx.state == SCP_OFFLINE )
	{
		printw( "*** Not connected" );
		return;
	}

	if ( ctx.hostSocket != INVALID_SOCKET )
	{
		shutdown( ctx.hostSocket, 2 );
		closesocket( ctx.hostSocket );
		ctx.hostSocket = INVALID_SOCKET;
	}

	// reinitialize queues
	queue_del_nodes( &user_q );
	queue_del_nodes( &imsg_q );
	queue_del_nodes( &omsg_q );

	ctx.state = SCP_OFFLINE;

	printw( "*** Disconnected" );
}

/**********************************************************/
int sccSend ( void )
{
	fd_set 		wfds,
				efds;
	TIMEVAL 	tv;
	int 		nRet,
				length;
	PMSG		m;

	static SCP_STREAM buffer;

	if ( (omsg_q.items == 0) )
		return 0;

	if ( (ctx.state == SCP_OFFLINE) || (ctx.state == SCP_CONNECTING) )
	{
		queue_del_all( &omsg_q );
		return 0;
	}

    // check if can send w/out blocking
	tv.tv_sec = 0; tv.tv_usec = 0;
	FD_ZERO( &wfds );
	FD_SET( ctx.hostSocket, &wfds );
	FD_ZERO( &efds );
	FD_SET( ctx.hostSocket, &efds );
    nRet = select( 0, 0, &wfds, &efds, &tv );

	if ( nRet == 0 )
		return 0;

    if ( (nRet < 0) || (efds.fd_count != 0) )
    	return 1;

	while ( 1 )
	{
		m = queue_peek( &omsg_q );
		if ( m == NULL ) break;

		length = m->length - m->start;

		buffer.imark	= SCP_INIMARK;
		buffer.id 		= itohw( m->id );
		buffer.start 	= itohb( m->start );
		buffer.length 	= itohb( length );
		buffer.cmd 		= itohb( m->cmd );

		if ( length > 0 )
            _fstrncpy( &buffer.msg[0], &m->msg[m->start], length );

		buffer.msg[length] = SCP_ENDMARK;

		nRet = send( ctx.hostSocket, (char far *)&buffer, SCP_HDRLEN + length, 0 );
		if ( nRet == SOCKET_ERROR )
			return 1;

		nRet = nRet - SCP_HDRLEN;
		if ( nRet >= 0 ) m->start += nRet;
		if ( m->start < m->length ) break;

		queue_del( &omsg_q );
	}

	return 0;
}

/**********************************************************/
void sccProcess ( void )
{
	int 	i, cmd, users;
	PMSG	m, q;
	PUSER	u;
	char	nick[SCP_NICKLEN+1],
			newnick[SCP_NICKLEN+1],
			far *p;

	// check states
	switch ( ctx.state )
	{
		case SCP_CONNECTING:
			if ( sccConnecting )
			{
				printw( "[ERROR] sccConnecting(): ", WSAGetLastError() );
				return;
			}
		break;

		case SCP_CONNECTED:
			q = msgNew( &omsg_q );
			if ( q != NULL )
			{
				oMsgAdd( q, SCP_NICKLEN, SCP_JOIN, (char far *)&ctx.nick );
        		ctx.state = SCP_JOINING;
        	}
        break;

        case SCP_JOINED:
			q = msgNew( &omsg_q );
			if ( q != NULL )
			{
				oMsgAdd( q, 0, SCP_LIST, NULL );
        		ctx.state = SCP_ONLINE;
        	}
		break;
    }

	// check messages
	while ( TRUE )
	{
		m = queue_peek( &imsg_q );
		if ( m == NULL ) break;

		if ( m->completed )
		{

			switch ( m->cmd )
			{
				////////////////////////////
				case SCP_JOIN:					// <nick>
					_fstrncpy( (char far *)&nick, (char far *)&m->msg, SCP_NICKLEN );

					if ( (ctx.state == SCP_JOINING) &&
						 (_fstrcmp( (char far *)&nick, (char far *)&ctx.nick ) == 0) )
						 ctx.state = SCP_JOINED;

					if ( userByNick( (char far *)&nick ) == NULL )
						if ( !userAdd( (char far *)&nick ) )
						{
						}
				break;

				////////////////////////////
				case SCP_REFUSED:				// .
					printw( "*** Nick already in use" );
					if ( ctx.state != SCP_ONLINE )
						sccDisconnect( );
                break;

				////////////////////////////
				case SCP_QUIT:					// <nick>
					u = userByNick( _fstrncpy( (char far *)&nick, (char far *)&m->msg, SCP_NICKLEN ) );
					if ( u != NULL )
						userDel( u );
                break;

				////////////////////////////
				case SCP_LIST:					// <hexa-users><nicks list>
					users = hbtoi( m->msg );
					p = &m->msg[2];
					while ( users > 0 )
					{
				    	_fstrncpy( (char far *)&nick, (char far *)p, SCP_NICKLEN );
				    	if ( userByNick( (char far *)&nick ) == NULL )
				    		if ( !userAdd( (char far *)&nick ) )
				    		{
							}
				    	p += SCP_NICKLEN;
				    	users -= 1;
					}
                break;

				////////////////////////////
				case SCP_TEXT:						// <nick><text>
                break;

				////////////////////////////
				case SCP_PRIV:						// <nick><text>
                break;

				////////////////////////////
				case SCP_NICK:						// <nick><newnick>
					_fstrncpy( (char far *)&nick, (char far *)&m->msg, SCP_NICKLEN );
					_fstrncpy( (char far *)&newnick, (char far *)&m->msg[SCP_NICKLEN], SCP_NICKLEN );
					u = userByNick( (char far *)&nick );
					if ( u != NULL )
					{
						if ( _fstrcmp( (char far *)&nick, (char far *)&ctx.nick ) == 0 )
							_fstrncpy( (char far *)&ctx.nick, (char far *)&newnick, SCP_NICKLEN );
						_fstrncpy( (char far *)&u->nick, (char far *)&newnick, SCP_NICKLEN );
					}
                break;

				////////////////////////////
				case SCP_PING:						// .
					// send: <PONG>
					q = msgNew( &omsg_q );
					if ( q == NULL ) break;
					oMsgAdd( q, 0, SCP_PONG, NULL );
                break;
			}

			msgDel( &imsg_q, m );
		}

		queue_del( &imsg_q );
	}

}

/***************************************************************************/
/* user routines														   */
/***************************************************************************/

/**********************************************************/
PUSER userAdd ( char far *nick )
{
    PUSER	u;

	u = (PUSER)queue_new( &user_q );
	if ( u == NULL ) return NULL;

	u->state = -1;
	_fstrncpy( u->nick, nick, SCP_NICKLEN );

	return NULL;
}

/**********************************************************/
void userDel ( PUSER u )
{
	u->state = 0;
	u->nick[0] = '\0';

	queue_del_node( &user_q, u );
}

/**********************************************************/
PUSER userByNick ( char far *nick )
{
	PUSER 	u;

	u = (PUSER)queue_head( &user_q );
	while ( u != NULL )
	{
		if ( _fstrcmp( u->nick, nick ) == 0 ) break;
		u = (PUSER)queue_next( &user_q, u );
	}

	return u;
}

/***************************************************************************/
/* msg routines														   	   */
/***************************************************************************/

/**********************************************************/
PMSG msgNew ( QUEUE *q )
{
	static int 	id;
	PMSG		m;

	m = (PMSG)queue_new( q );
    if ( m == NULL ) return NULL;

	id = (int)( (long)(id) + 1L ) & 0x7FFF;
	m->id = 1 + id;

	return m;
}

/**********************************************************/
void oMsgAdd ( PMSG m, int length, int cmd, char far *message )
{
	m->cmd 		= cmd;
	m->start	= 0;
	m->length 	= length;
    if ( length > 0 ) _fstrncpy( m->msg, message, length );
}

/**********************************************************/
void iMsgAdd ( PMSG m, int id, int start, int length, int cmd,
			   int completed, char far *message, int msglen )
{
	m->id 		= id;
	m->start 	= start;
	m->length 	= length;
	m->completed = completed;
	m->cmd 		= cmd;
	if ( msglen > 0 ) _fstrncpy( &m->msg[start], message, msglen );
}

/**********************************************************/
void msgDelTail ( QUEUE *q )
{
	PMSG 	m;

	m = (PMSG)queue_tail( q );
	if ( m == NULL ) return;
	m->msg[0] = '\0';

    queue_del_node( q, m );
}

/**********************************************************/
void msgDelHead ( QUEUE *q )
{
	PMSG 	m;

	m = (PMSG)queue_head( q );
	if ( m == NULL ) return;
	m->msg[0] = '\0';

    queue_del( q );
}

/**********************************************************/
void msgDel ( QUEUE *q, PMSG m )
{
	m->msg[0] = '\0';

	queue_del_node( q, m );
}

/**********************************************************/
PMSG msgByID ( QUEUE *q, int id )
{
	PMSG	m;

	m = (PMSG)queue_head( q );
	while ( m != NULL )
	{
		if ( m->id == id ) break;
		m = (PMSG)queue_next( q, m );
	}

	return m;
}

/***************************************************************************/
/* misc routines														   */
/***************************************************************************/

unsigned char hex_tb[16] = { '0', '1', '2', '3', '4', '5', '6', '7',
							 '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

/**********************************************************/
unsigned short itohb ( unsigned short num )
{
	return (((unsigned short)hex_tb[(num >> 4) & 0xF]) << 8) |
		   hex_tb[(num & 0xF)];
}

/**********************************************************/
unsigned long itohw ( unsigned short num )
{
	return (((unsigned long)hex_tb[(num >> 12) & 0xF]) << 24) |
		   (((unsigned long)hex_tb[(num >>  8) & 0xF]) << 16) |
		   (((unsigned long)hex_tb[(num >>  4) & 0xF]) <<  8) |
		   hex_tb[(num & 0xF)];
}

/**********************************************************/
unsigned char hbtoi ( unsigned char far *hex )
{
	unsigned char dec0, dec1;

	dec0 = hex[0] - '0';
	dec0 -= ( dec0 <= 9? 0: 'A'-'0' );
	dec1 = hex[1] - '0';
	dec1 -= ( dec1 <= 9? 0: 'A'-'0' );

	return (dec0 << 4) | dec1;
}

/**********************************************************/
unsigned short hwtoi ( unsigned char far *hex )
{
	unsigned short dec;
	unsigned char chr;
	int i;

	for ( i = 0; i < 4; i++ )
	{
		chr = hex[i] - '0';
		chr -= ( chr <= 9? 0: 'A'-'0' );
		dec = (dec << 4) | chr;
	}

	return dec;
}

/**********************************************************/
void tokenize ( char *text, int *tokenc, char *tokenv[], int tokenp[], int maxc )
{
    char	*cmd;
    int		p, l, i;
    char	c;

	p = 0;
	l = strlen( text );
	*tokenc = 0;

	do
	{
		do
		{
			c = text[p++];
			l -= 1;
		} while ( ((c == 32) || (c == 7)) && (l > 0) );

		tokenp[*tokenc] = p;
		if ( l == 0 )
		{
            if ( (c != 32) && (c != 7) )
            {
                *tokenv[*tokenc] = c;
                *tokenc += 1;
            }
            break;
        }

        i = 0;
		do
		{
			tokenv[*tokenc][i++] = c;
			c = text[p++];
			l -= 1;
		} while ( (c != 32) && (c != 7) && (l != 0) );

		if ( (c != 32) && (c != 7) )
			tokenv[*tokenc][i++] = c;

        tokenv[*tokenc][i] = '\0';

		*tokenc += 1;
	} while ( (l > 0) && (*tokenc < maxc) );
}

