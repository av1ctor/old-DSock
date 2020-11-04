//
// gethttp.c
//
// Retrieves a file using the Hyper Text Transfer Protocol
// and prints its contents to stdout.
//

//
// Pass the server name and full path of the file on the
// command line and redirect the output to a file. The program
// prints messages to stderr as it progresses.
//
// Example:
//		GetHTTP www.idgbooks.com /index.html > index.html
//

#include <stdio.h>
#include <string.h>
#include <io.h>
#include <fcntl.h>
#include "..\..\inc\dsock.h"

void GetHTTP( char far * lpServerName, char far * lpFileName );

// Helper macro for displaying errors
#define PRINTERROR( s )	\
		fprintf( stderr,"\n%s: %d\n", s, WSAGetLastError( ) )


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
	WORD wVersionRequested = MAKEWORD( 1,1 );
	WSADATA wsaData;
	int nRet;

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
		fprintf( stderr,"\nWSAStartup( ): %d\n", nRet );
		WSACleanup( );
		return;
	}

	//
	// Check WinSock version
	//
	if ( wsaData.wVersion != wVersionRequested )
	{
		fprintf( stderr,"\nWinSock version not supported\n" );
		WSACleanup( );
		return;
	}

	fprintf( stderr, "\nWinSock ver:%d.%d desc:%s\n",
			 wsaData.wVersion >> 8, wsaData.wVersion & 0xFF,
			 wsaData.szDescription );

	//
	// Set "stdout" to binary mode
	//
	setmode( fileno( stdout), O_BINARY );

	//
	// Call GetHTTP( ) to do all the work
	//
	GetHTTP( argv[1], argv[2] );

	//
	// Release WinSock
	//
	fprintf( stderr, "\nFinishing..." );
	WSACleanup( );
	fprintf( stderr, " done.\n" );
}

///////////////////////////////////////////////////////////////////////////
void GetHTTP( char far *lpServerName, char far *lpFileName )
{
	IN_ADDR     iaHost;
	LPHOSTENT   lpHostEntry;

	SOCKET      Socket;

	LPSERVENT   lpServEnt;
	SOCKADDR_IN saServer;

	int nRet;

	static char szBuffer[4096];

    long        start, end;
    long        bytes = 0;

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
	// Create a TCP/IP stream socket
	//
	Socket = socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
	if ( Socket == INVALID_SOCKET )
	{
		PRINTERROR( "socket( )" );
		return;
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
	// Connect the socket
	//
	fprintf( stderr,"\nConnecting to:%Fs\n", lpServerName );
	nRet = connect( Socket, ( LPSOCKADDR )&saServer, sizeof( SOCKADDR_IN ));
	if ( nRet == SOCKET_ERROR )
	{
		PRINTERROR( "connect( )" );
		closesocket( Socket );
		return;
	}


	//
	// Format the HTTP request
	//
	sprintf( szBuffer, "GET %Fs HTTP/1.1\n"\
					   "Host: %Fs\n"\
					   "Connection: close\n"\
					   "User-Agent: GetHTTP 0.0\n"\
					   "\n",
					   lpFileName, lpServerName );
	fprintf( stderr, "\nSending:\n%s", szBuffer );
	nRet = send( Socket, szBuffer, strlen( szBuffer ), 0 );
	if ( nRet == SOCKET_ERROR )
	{
		PRINTERROR( "send( )" );
		closesocket( Socket );
		return;
	}


	//
	// Receive the file contents and print to stdout
	//
	fprintf( stderr,"\nReceiving...\n" );

	start = clock();
	while ( 1 )
	{
		// Wait to receive, nRet = NumberOfBytesReceived
		nRet = recv( Socket, szBuffer, sizeof( szBuffer ), 0 );
		if ( nRet == SOCKET_ERROR )
		{
			PRINTERROR( "recv( )" );
			break;
		}

		// Did the server close the connection?
		if ( nRet == 0 )
			break;

		bytes += nRet;

        fprintf( stderr,"\nrecv( ) returned %d bytes:\n", nRet );

		// Write to stdout
		fwrite( szBuffer, nRet, 1, stdout );
	}
	end = clock();

    fprintf( stderr, "\nBytes:%ld Ticks:%d\n", bytes, end - start);

	//
	// Finish the connection
	//
	closesocket( Socket );
}
