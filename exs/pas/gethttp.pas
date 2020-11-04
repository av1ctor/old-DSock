program
	gethttp;

(*
 * gethttp.pas
 *
 * Retrieves a file using the Hyper Text Transfer Protocol
 * and prints its contents to stdout.
 *)

(*
 * Pass the server name and full path of the file on the
 * command line and redirect the output to a file. The program
 * prints messages to stderr as it progresses.
 *
 * Example:
 *		GetHTTP www.idgbooks.com /index.html > index.html
 *)

uses
    dsock, strings;

const
	NL = #13#10;


(*************************************************************************)
procedure PRINTERROR( s: string );
begin
	writeln( NL, 'ERROR:', WSAGetLastError, ' @ ', s );
end;

(*************************************************************************)
procedure Get_HTTP( lpServerName, lpFileName: pchar );
var
	iaHost		: IN_ADDR;
	lpHostEntry	: LPHOSTENT;

	Sock		: TSocket;

	lpServEntry	: LPSERVENT;
	saServer	: sockaddr_in;

	nRet		: integer;

	szBuffer	: array[0..1023] of char;

begin
	(*
	 * Use inet_addr() to determine if we're dealing with a name
	 * or an address
	 *)
	iaHost.s_addr := longint( inet_addr( lpServerName ) );
	if ( iaHost.s_addr = INADDR_NONE ) then begin
		{ Wasn't an IP address string, assume it is a name }
		lpHostEntry := gethostbyname( lpServerName );
		if ( lpHostEntry = NULL ) then begin
			PRINTERROR( 'gethostbyname()' );
			exit;
		end;
	end
	else begin
		{ It was a valid IP address string }
		lpHostEntry := gethostbyaddr( pchar( iaHost ),
									  sizeof( in_addr ), AF_INET );
		if ( lpHostEntry = NULL ) then begin
			PRINTERROR( 'gethostbyaddr()' );
			exit;
		end;

		lpServerName := lpHostEntry^.h_name;
	end;


	(*
	 * Create a TCP/IP stream socket
	 *)
	Sock := socket( AF_INET, SOCK_STREAM, IPPROTO_TCP );
	if ( Sock = INVALID_SOCKET ) then begin
		PRINTERROR( 'socket()' );
		exit;
	end;


	(*
	 * Find the port number for the HTTP service on TCP
	 *)
	lpServEntry := getservbyname( 'http', 'tcp' );
	if ( lpServEntry = NULL ) then
		saServer.sin_port := htons( 80 )
	else
		saServer.sin_port := lpServEntry^.s_port;


	(*
	 * Fill in the rest of the server address structure
	 *)
	saServer.sin_family := AF_INET;
	saServer.sin_addr := lpHostEntry^.h_addr_list^^;


	(*
	 * Connect the socket
	 *)
	writeln( NL, 'Connecting to:', lpServerName );
	nRet := connect( Sock, sockaddr( saServer ), sizeof( sockaddr_in ) );
	if ( nRet = SOCKET_ERROR ) then begin
		PRINTERROR( 'connect()' );
		closesocket( Sock );
		exit;
	end;


	(*
	 * Format the HTTP request
	 *)
	strcopy( szBuffer, 'GET ' );
	strcat ( szBuffer, lpFileName );
	strcat ( szBuffer, ' HTTP/1.1' + NL + 'Host: ' );
	strcat ( szBuffer, lpServerName );
	strcat ( szBuffer, NL +
					   'Connection: close' + NL +
					   'User-Agent: GetHTTP 0.0' + NL +
					   NL );
	writeln( NL, 'Sending:', NL, szBuffer );
	nRet := send( Sock, szBuffer, strlen( szBuffer ), 0 );
	if ( nRet = SOCKET_ERROR ) then begin
		PRINTERROR( 'send()' );
		closesocket( Sock );
		exit;
	end;


	(*
	 * Receive the file contents and print to stdout
	 *)
	writeln( NL, 'Receiving...' );
	while ( true ) do begin
		{ Wait to receive, nRet = NumberOfBytesReceived }
		nRet := recv( Sock, szBuffer, sizeof( szBuffer ) - 1, 0 );
		if ( nRet = SOCKET_ERROR ) then begin
			PRINTERROR( 'recv()' );
			exit;
		end;

		{ Did the server close the connection? }
		if ( nRet = 0 ) then
			exit;

		writeln( NL, 'recv() returned ', nRet, ' bytes:' );

		{ Write to stdout }
		szBuffer[nRet] := #0;			{ add null-term }
		write( szBuffer );
	end;

	(*
	 * Finish the connection
	 *)
	closesocket( Sock );
end;

(*************************************************************************)
var
	wVersionRequested: word;
	_wsaData	: WSADATA;
	nRet		: integer;
    serverName,
    fileName	: array[0..128] of char;

begin

	(*
	 * Check arguments
	 *)
	if ( ParamCount <> 2 ) then begin
		writeln( NL, 'Syntax: GetHTTP ServerName FullPathName' );
		exit;
	end;

	(*
	 * Initialize WinSock.dll
	 *)
    wVersionRequested := MAKEWORD( 1,1 );
	nRet := WSAStartup( wVersionRequested, @_wsaData );
	if ( nRet <> 0 ) then begin
		writeln( NL, 'WSAStartup():', nRet );
		WSACleanup;
		exit;
	end;

	(*
	 * Check WinSock version
	 *)
	if ( _wsaData.wVersion <> wVersionRequested ) then begin
		writeln( NL, 'WinSock version not supported' );
		WSACleanup;
		exit;
	end;

	writeln( NL, 'WinSock ver:', _wsaData.wVersion shr 8, '.',
							     _wsaData.wVersion and $FF,
				 ' desc:', _wsaData.szDescription );

	(*
	 * Call Get_HTTP() to do all the work
	 *)
	Get_HTTP( strpcopy( serverName, ParamStr(1) ),
			  strpcopy( fileName  , ParamStr(2) ) );

	(*
	 * Release WinSock
	 *)
	write( NL, 'Finishing...' );
	WSACleanup;
	writeln( ' done.' );
end.

