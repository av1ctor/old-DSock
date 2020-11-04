//
// agethttp.c
//
// Retrieves a file using the Hyper Text Transfer Protocol
// and prints its contents to stdout, working asynchronously.
//

//
// Pass the server name and full path of the file on the
// command line and redirect the output to a file. The program
// prints messages to stderr as it progresses.
//
// Example:
//		GetHTTP www.idgbooks.com /index.html > index.html
//

//
// Obs: if the connection's speed is too high (>3mbps) or if testing in
//      localhost + a fast cpu (>400mhz) and if taking too much for checking
//		the input queue on main loop (ie, if running in full-screen in win
//		nt and printing many messages) and downloading a file with size
//		>300K, a message showing that the error 1234 for event 1 occured,
//		can be shown, as there are buffers for only 393.216 bytes at time;
//		sorry, but nothing can be done, it's real-mode and that's all memory
//		that could be allocated (and dynamically allocating mem for receive
//		buffers as in Windows won't work as dos/rtlib isn't reentrant)
//

#include <stdio.h>
#include <conio.h>
#include <string.h>
#include <malloc.h>
#include <io.h>
#include <fcntl.h>
#include "..\..\inc\dsock.h"
#include "queue.h"

int 			asyncsend 		( SOCKET 		Socket,
								  char 			FAR *buf,
								  int 			len,
								  int 			flags );

unsigned int 	farfwrite		( char 			far *buf,
								  unsigned int 	bytes,
								  FILE 			*f );

void 			HTTP_Get		( char 			far * lpServerName,
								  char 			far * lpFileName );

// Helper macro for displaying errors
#define PRINTERROR( s )	\
		fprintf( stderr, "\nError: %d Calling: %s\n", WSAGetLastError( ), s )


#define MAX_MSGS 	256

typedef struct _MSGQ {
#ifdef __DEBUG__
	unsigned int	id;
#endif
	int 			event;
	int 			error;
	char 			FAR *ptr;
	unsigned int 	ofs;
	int 			len;
} MSGQ;

#define BUFF_CNT 	(192)
#define BUFF_SIZE 	(2048)

/// Globals //////
QUEUE 			inq = { 0 },
				outq = { 0 },
				buffq = { 0 };


///
static long near clock ( void )
{
    asm     push    es
    asm     xor     ax, ax
    asm     mov     es, ax
    asm     mov     ax, es:[46Ch+0]
    asm     mov     dx, es:[46Ch+2]
    asm     pop     es
}

///////////////////////////////////////////////////////////////////////////
void main( int argc, char *argv[] )
{
	WORD 		wVersionRequested = MAKEWORD( 1,1 );
	WSADATA 	wsaData;
	int 		nRet;

	//
	// Check arguments
	//
	if ( argc != 3 )
	{
		fprintf( stderr,
				 "\nSyntax: GetHTTP ServerName FullPathName\n" );
		return;
	}

	//
	// Initialize WinSock.dll
	//
	nRet = WSAStartup( wVersionRequested, &wsaData );
	if ( nRet )
	{
		fprintf( stderr,"\nWSAStartup(): %d\n", nRet );
		WSACleanup( );
		return;
	}

	//
	// Check WinSock version
	//
	if ( wsaData.wVersion != wVersionRequested )
	{
		fprintf( stderr, "\nWinSock version not supported.\n" );
		WSACleanup( );
		return;
	}

	fprintf( stderr,"\nWinSock Version: %d.%d, Description: %s\n",
			 wsaData.wVersion >> 8, wsaData.wVersion & 0xFF,
			 wsaData.szDescription );


	//
	// Set "stdout" to binary mode
	//
	setmode( fileno( stdout), O_BINARY );

	//
	// Call HTTP_Get( ) to do all the work
	//
	HTTP_Get( argv[1], argv[2] );

	//
	// Release WinSock
	//
	fprintf( stderr, "\nFinishing..." );
	WSACleanup( );
	fprintf( stderr, " done.\n" );
}

///////////////////////////////////////////////////////////////////////////
void WSAAPI Callback ( u_int wMsg, u_long wParam, u_long lParam )
{
	int 		bytes;
	MSGQ 		FAR *msg;


	//
	// If an error occured or if its any event but FD_WRITE, then
	// create a new entry on input queue
	//
	if ( ( WSAGETSELECTERROR( lParam ) != 0 ) ||
         ( WSAGETSELECTEVENT( lParam ) != FD_WRITE ) )
    {
		msg = (MSGQ FAR *)queue_new( &inq );
		if ( msg == NULL ) return;

#ifdef __DEBUG__
		msg->id	   = 'Iq';
#endif
		msg->event = WSAGETSELECTEVENT( lParam );
		msg->error = WSAGETSELECTERROR( lParam );
		msg->ptr   = NULL;
		msg->ofs   = 0;
		msg->len   = 0;

		// Any error occured?
		if ( msg->error != 0 ) return;
	}


	//
	// Process events
	//
	switch ( WSAGETSELECTEVENT( lParam ) )
	{
    	///////////////////////////
		case FD_READ:
			// Alloc a new slot in buffer queue
			msg->ptr = queue_new( &buffq );
			if ( msg->ptr == NULL )
			{
				msg->error = 1234;
				return;
			}

            // Read to buffer allocated
            bytes = recv( wParam, msg->ptr, BUFF_SIZE, 0 );
			if ( bytes == SOCKET_ERROR )
				msg->error = WSAGetLastError( );
			else
				msg->len = bytes;
		break;


		///////////////////////////
		case FD_WRITE:
			// Any item on output queue? send it/them
			while ( outq.items != 0 )
			{
				msg = queue_peek( &outq );
				while ( msg->len > 0 )
				{
					bytes = send( wParam, msg->ptr + msg->ofs, msg->len, 0 );
					if ( bytes == SOCKET_ERROR )
					{
						//
						// If an error other than WSAEWOULDBLOCK occured,
						// then alert the main loop
						//
						if ( WSAGetLastError( ) != WSAEWOULDBLOCK )
						{
							queue_del_node( &buffq, msg->ptr );
							queue_del_node( &outq, msg );

							msg = (MSGQ FAR *)queue_new( &inq );
							if ( msg == NULL ) return;
							msg->event = FD_WRITE;
							msg->error = WSAGetLastError( );
							return;
						}
						//
						// Else, leave the way it's now, a new FD_WRITE
						// message will be sent when would be more room
						//
						else
							return;
					}
					else
					{
						//
						// If not all was sent yet, still sending until
						// receiving the WSAEWOULDBLOCK error
						//
						msg->len -= bytes;
						if ( msg->len > 0 )
                    		msg->ofs += bytes;
					}
				}
				queue_del_node( &buffq, msg->ptr );
				msg->ptr = NULL;				// for safety
				queue_del_node( &outq, msg );
			}
		break;
	}
}

///////////////////////////////////////////////////////////////////////////
int static asyncsend ( SOCKET Socket, char FAR *buf, int len, int flags )
{
    int 		nRet;
    MSGQ		FAR *msg;

   	// Add a new msg to output queue
   	msg = queue_new( &outq );
	if ( msg == NULL ) return 1;
#ifdef __DEBUG__
	msg->id	 = 'Oq';
#endif
	msg->ptr = buf;
   	msg->ofs = 0;
   	msg->len = len;

	// Try sending most what can be sent
    while ( msg->len > 0 )
    {
		nRet = send( Socket, msg->ptr + msg->ofs, msg->len, flags );
		if ( nRet == SOCKET_ERROR )
		{
			// An critical error?
			if ( WSAGetLastError( ) != WSAEWOULDBLOCK )
			{
				queue_del_node( &outq, msg );
				return -1;
			}
			// Else, let the callback do the rest
			else
				return 0;
		}

		msg->len -= nRet;
		if ( msg->len > 0 )
			msg->ofs += nRet;
	}

	// All sent, delete msg from output queue
	if ( queue_del_node( &outq, msg ) == 0 )
		return -1;

	queue_del_node( &outq, msg );

	return 1;
}

///////////////////////////////////////////////////////////////////////////
int HTTP_ui ( void )
{
	if ( kbhit( ) )
	{
		getch( );
		return 0;
	}
	else
		return 1;
}

///////////////////////////////////////////////////////////////////////////
int HTTP_Send ( SOCKET socket, char *request, int requestlen )
{
	char		FAR *sendBuffer;
	int			nRet;

	sendBuffer = queue_new( &buffq );
	if ( sendBuffer == NULL ) return FALSE;

	_fmemcpy( sendBuffer, request, requestlen );

	nRet = asyncsend( socket, sendBuffer, requestlen, 0 );
	if ( (nRet == 1) || (nRet == -1) )
		if ( queue_del_node( &buffq, sendBuffer ) == 0 )
			return FALSE;

	return ( nRet == -1? FALSE : TRUE );
}

///////////////////////////////////////////////////////////////////////////
void HTTP_Get ( char far *lpServerName, char far *lpFileName )
{
	IN_ADDR     iaHost;
	LPHOSTENT   lpHostEntry;
	LPSERVENT   lpServEnt;
	SOCKADDR_IN saServer;
	SOCKET		Socket;
	int 		nRet;

	static char httpRequest[512];
	int			disconnected = FALSE;
    MSGQ 		msg;

    long       	start = 0, end = 0;
    long        bytes = 0;

	//
	// Create message queues
	//
	if ( !queue_create( &inq, MAX_MSGS, sizeof( MSGQ ) ) ||
		 !queue_create( &outq, MAX_MSGS, sizeof( MSGQ ) ) ||
		 !queue_create( &buffq, BUFF_CNT, BUFF_SIZE ) )
	{
		fprintf( stderr, "\nERROR: creating the queue.\n" );
		return;
	}


	//
	// Use inet_addr( ) to determine if we're dealing with a name
	// or an address
	//
	iaHost.s_addr = inet_addr( lpServerName );
	if ( iaHost.s_addr == INADDR_NONE )
	{
		// Wasn't an IP address string, assume it is a name
		lpHostEntry = gethostbyname( lpServerName );
		if ( lpHostEntry == NULL )
		{
			PRINTERROR( "gethostbyname( )" );
			return;
		}
	}
	else
	{
		// It was a valid IP address string
		lpHostEntry = gethostbyaddr( (const char * )&iaHost,
									 sizeof( struct in_addr ), AF_INET );
		if ( lpHostEntry == NULL )
		{
			PRINTERROR( "gethostbyaddr( )" );
			return;
		}

		lpServerName = lpHostEntry->h_name;
	}


	//
	// Find the port number for the HTTP service on TCP
	//
	lpServEnt = getservbyname( "http", "tcp" );
	if ( lpServEnt == NULL )
		saServer.sin_port = htons( 80 );
	else
		saServer.sin_port = lpServEnt->s_port;


	//
	// Fill in the rest of the server address structure
	//
	saServer.sin_family = AF_INET;
	saServer.sin_addr = *( (LPIN_ADDR )*lpHostEntry->h_addr_list );


	//
	// Create a TCP/IP stream socket
	//
	Socket = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
	if ( Socket == INVALID_SOCKET )
	{
		PRINTERROR( "socket( )" );
		return;
	}


	//
	// All done asynchronously by now
	//
	nRet = WSAAsyncSelect( Socket, Callback, 0, FD_READ |
						 				     	FD_WRITE |
						 				     	FD_CLOSE |
						 					 	FD_CONNECT );
	if ( nRet == SOCKET_ERROR )
	{
		PRINTERROR( "WSAAsyncSelect( )" );
		closesocket( Socket );
		return;
	}


	//
	// Connect the socket
	//
	fprintf( stderr, "\nConnecting to [ %Fs ]... ", lpServerName );
	nRet = connect( Socket, ( LPSOCKADDR )&saServer, sizeof( SOCKADDR_IN ));
	if ( nRet == SOCKET_ERROR )
		if ( WSAGetLastError( ) != WSAEWOULDBLOCK )
		{
			PRINTERROR( "connect( )" );
			closesocket( Socket );
			return;
		}


    //
    // Fill HTTP request
    //
	sprintf( httpRequest, "GET %Fs HTTP/1.1\n"\
						  "Host: %Fs\n"\
						  "Connection: close\n"\
					   	  "User-Agent: GetHTTP 0.0\n"\
					   	  "\n",
					   	  lpFileName, lpServerName );

	//
	// Process events and wait any key be pressed
	//
	while ( TRUE )
	{
		if ( !HTTP_ui( ) )
			break;

		//
		// Check input queue
		//
		if ( inq.items != 0 )
		{
			if ( queue_get( &msg, &inq ) == 0 )
			{
				fprintf( stderr, "\nERROR! q_get()\n" );
				break;
			}

#ifdef __DEBUG__
			if ( msg.id != 'Iq' )
			{
				fprintf( stderr, "\nERROR! bad id\n" );
				break;
			}
#endif

			if ( msg.error != 0 )
			{
				fprintf( stderr, "\nEvent: %d Error: %d\n",
						 msg.event, msg.error );
				break;
			}

			switch ( msg.event )
			{
				case FD_CONNECT:
					fprintf( stderr, "connected.\n" );
					fprintf( stderr, "\nSending HTTP request:\n%s", httpRequest );
					if ( HTTP_Send( Socket, httpRequest, strlen( httpRequest ) ) == FALSE)
						PRINTERROR( "asyncsend( )" );
				break;

				case FD_CLOSE:
					if ( end == 0 ) end = clock( );
					disconnected = TRUE;
					fprintf( stderr, "\nDisconnected.\n" );
				break;

				case FD_READ:
					fprintf( stderr, "\nReceived %d bytes:\n", msg.len );
					if ( start == 0 ) start = clock( );
					if ( msg.ptr != NULL )
					{
						bytes += msg.len;
						if ( msg.len != 0 )
							farfwrite( msg.ptr, msg.len, stdout );
						if ( queue_del_node( &buffq, msg.ptr ) == 0 )
						{
							fprintf( stderr, "\nERROR! q_del()\n" );
							break;
						}
					}
				break;
			}

			if ( disconnected == TRUE )
				fprintf( stderr, "\n[ Press any key to exit ]\n" );
		}
	}

    fprintf( stderr, "\nBytes:%ld Ticks:%d\n", bytes, end - start);

    //
    // Destroy message queues
    //
	queue_destroy( &buffq );
	queue_destroy( &outq );
	queue_destroy( &inq );


	//
	// Finish the connection
	//
	shutdown( Socket, 2 );
	closesocket( Socket );
}

///////////////////////////////////////////////////////////////////////////
unsigned int farfwrite( char far *buf, unsigned int bytes, FILE *f )
{
	__asm {
			push	ds
			mov		ah, 40h
			mov		bx, f
			mov		bx, word ptr [bx].fd
			and		bx, 00FFh
			mov		cx, bytes
			lds		dx, buf
			int		21h
			pop		ds
	}

	return _AX;
}
