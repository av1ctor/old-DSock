''
'' GetHTTP.bas
''
'' Retrieves a file using the Hyper Text Transfer Protocol
'' and prints its contents to stdout.
''

''
'' Pass the server name and full path of the file on the
'' command line and redirect the output to a file. The program
'' prints messages to stderr as it progresses.
''
'' Example:
''		GetHTTP www.idgbooks.com /index.html > index.html
''

defint a-z
'$include: '..\..\inc\dsock.bi'
'$include: 'qb.bi'

const stdin%  = 0%
const stdout% = 1%
const stderr% = 2%

declare sub fwrite ( fileHandle as integer, bufferPtr as long, bufferLen as integer )

declare sub main ( argc as integer, argv() as string )
declare sub GetHTTP ( lpServerName as string, lpFileName as string )


const BUFFSIZE% = 4096%
dim shared recvBuffer(0 to (BUFFSIZE\2)-1) as integer

dim shared NEWLINE as string

''''''''
	NEWLINE = chr$( 13 ) + chr$( 10 )

	'' process command-line
	dim argv(0 to 9) as string
	cmd$ = command$ + chr$( 13 )
	p = 1
	argc = 0
	do
		do
			char = asc( mid$( cmd$, p, 1 ) )
			p = p + 1
		loop while ( (char = 32) or (char = 7) )
		if char = 13 then exit do

		do
			argv(argc) = argv(argc) + chr$( char )
			char = asc( mid$( cmd$, p, 1 ) )
			p = p + 1
		loop until ( (char = 32) or (char = 7) or (char = 13) )
		argc = argc + 1
	loop while ( char <> 13 )
	cmd$ = ""

	'' call main
	main argc, argv()

    '' exit
    end

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub main ( argc as integer, argv() as string )
	static wsaDat as WSAData
	dim wVersionRequested as integer
	dim nRet as integer

	''
	'' Check arguments
	''
	if ( argc <> 2 ) then
		print "Syntax: GetHTTP ServerName FullPathName"
		exit sub
	end if

	''
	'' Initialize WinSock.dll
	''
	wVersionRequested = MAKEWORD( 1, 1 )

	nRet = WSAStartup( wVersionRequested, wsaDat )
	if ( nRet <> 0 ) then
		print "WSAStartup():"; nRet
		nRet = WSACleanup
		exit sub
	end if

	''
	'' Check WinSock version
	''
	if ( wsaDat.wVersion <> wVersionRequested ) then
		print "WinSock version not supported"
		nRet = WSACleanup
		exit sub
	end if

	print using "WinSock ver:#/# desc:&"; _
				wsaDat.wVersion \ 256; wsaDat.wVersion and &hFF; _
			 	wsaDat.szDescription

	''
	'' Call GetHTTP( ) to do all the work
	''
	GetHTTP argv(0), argv(1)

	''
	'' Release WinSock
	''
	print "Finishing...";
	nRet = WSACleanup
	print " done."
end sub


''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub GetHTTP ( lpServerName as string, lpFileName as string )
	dim iaHost as inAddr
	dim lpHostEntry as long

	dim s as long

	dim lpServEnt as long
	dim saServer as sockaddrIn

	dim sendBuffer as string
	dim lpSendBuffer as long, lpRecvBuffer as long

	dim nRet as integer


	''
	'' Use inet_addr( ) to determine if we're dealing with a name
	'' or an address
	''
	iaHost.sAddr = inetAddr( lpServerName )
	if ( iaHost.sAddr = INADDR.NONE ) then
		'' Wasn't an IP address string, assume it is a name
		lpHostEntry = gethostbyname( lpServerName )
		if ( lpHostEntry = NULL ) then
			print "Error:"; WSAGetLastError; " Calling: gethostbyname()"
			exit sub
		end if
	else
		'' It was a valid IP address string
		lpHostEntry = gethostbyaddr( iaHost, len( iaHost ), AF.INET )
		if ( lpHostEntry = NULL ) then
			print "Error:"; WSAGetLastError; " Calling: gethostbyaddr()"
			exit sub
		end if

		lpServerName = hostent.hName( lpHostEntry )
	end if


	''
	'' Create a TCP/IP stream socket
	''
	s = socket( AF.INET, SOCK.STREAM, IPPROTO.TCP )
	if ( s = INVALID.SOCKET ) then
		print "Error:"; WSAGetLastError; " Calling: socket()"
		exit sub
	end if


	''
	'' Find the port number for the HTTP service on TCP
	''
	lpServEnt = getservbyname( "http", "tcp" )
	if ( lpServEnt = NULL ) then
		saServer.sinPort = htons( 80 )
	else
		saServer.sinPort = servent.sPort( lpServEnt )
	end if


	''
	'' Fill in the rest of the server address structure
	''
	saServer.sinFamily = AF.INET
	saServer.sinAddr.sAddr = hostent.hAddrList( lpHostEntry )


	''
	'' Connect the socket
	''
	print "Connecting to:"; lpServerName
	nRet = connect( s, saServer, len( saServer ))
	if ( nRet = SOCKET.ERROR ) then
		print "Error:"; WSAGetLastError; " Calling: connect()"
		nRet = closesocket( s )
		exit sub
	end if


	''
	'' Format the HTTP request
	''
	sendBuffer = "GET " + lpFileName + " HTTP/1.1" + NEWLINE + _
				 "Host: " + lpServerName + NEWLINE + _
				 "Connection: close" + NEWLINE + _
				 "User-Agent: GetHTTP 0.0" + NEWLINE + _
				 + NEWLINE


	''
	'' Send the request
	''
	print "Sending:"; sendBuffer
	'' if compiling/running with/in PDS or VBDOS, SSEG _must_ be used in
	'' place of VARSEG when needing the segment of some string; as in
	'' PDS/VBDOS the strings are FAR, VARSEG will return the segment of
	'' the string's descriptor, that's not the same as the string's data
	'' (in QB 4.x there's no problem as both descriptor and string
	'' are in DGROUP, but 4.x doesn't support SSEG...)
''$IF QB 4.x
	lpSendBuffer = MAKELONG( sadd(sendBuffer), varseg(sendBuffer) )
''$ELSEIF PDS or VBDOS
''    lpSendBuffer = MAKELONG( sadd(sendBuffer), sseg(sendBuffer) )
''$ENDIF
	nRet = send( s, lpSendBuffer, len( sendBuffer ), 0 )
	if ( nRet = SOCKET.ERROR ) then
		print "Error:"; WSAGetLastError; " Calling: send()"
		nRet = closesocket( s )
		exit sub
	end if


	''
	'' Receive the file contents and print to stdout
	''
	print "Receiving..."
	lpRecvBuffer = MAKELONG(varptr(recvBuffer(0)), varseg(recvBuffer(0)))
	do while ( TRUE )

		'' Wait to receive, nRet = NumberOfBytesReceived
		nRet = recv( s, lpRecvBuffer, BUFFSIZE, 0 )
		if ( nRet = SOCKET.ERROR ) then
			print "Error:"; WSAGetLastError; " Calling: recv()"
			exit do
		end if

		'' Did the server close the connection?
		if ( nRet = 0 ) then exit do

		print "recv() returned"; nRet; "bytes:"

		'' Write to stdout
		fwrite stdout, lpRecvBuffer, nRet
	loop

	''
	'' Finish the connection
	''
	nRet = shutdown( s, 2 )
	nRet = closesocket( s )
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub fwrite ( fileHandle as integer, bufferPtr as long, bufferLen as integer )
	static r as RegTypeX

	r.dx = cint( bufferPtr and &hFFFF& )
	r.ds = cint( bufferPtr \ 65536 )
	r.cx = bufferLen
	r.bx = fileHandle
	r.ax = &h4000
	interruptx &h21, r, r
end sub
