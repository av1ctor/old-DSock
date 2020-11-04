''
'' chat.bas -- non-blocking simple-and-lame chat example
''

defint a-z
'$include: '..\..\inc\dsock.bi'
'$include: 'qb.bi'

const stdin%  = 0%
const stdout% = 1%
const stderr% = 2%

declare sub fwrite ( fileHandle as integer, bufferPtr as long, bufferLen as integer )

declare sub ChatServer ( szServerPort as string )
declare sub ChatClient ( szServerName as string, szServerPort as string )
declare sub main       ( argc as integer, argv() as string )
declare sub doParseCmd ( argc as integer, argv() as string )

declare function nbConnect% ( s as long, addr as sockaddrIn, addrLen as integer )
declare function nbSend% ( s as long, buffer as long, bytes as integer )
declare function nbRecv% ( s as long, buffer as long, bytes as integer )


const BUFFSIZE% = 4096%
dim shared recvBuffer(0 to (BUFFSIZE\2)-1) as integer

dim shared NEWLINE as string


''''''''
	NEWLINE = chr$( 13 ) + chr$( 10 )	
	dim argc as integer, argv(0 to 9) as string

	'' parse command line and call main
	doParseCmd argc, argv()
	main argc, argv()
	

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub main ( argc as integer, argv() as string )
    const SERVER = 0%
    const CLIENT = 1%
    
	static nRet as integer
	static wsaDat as WSAData	
	static ChatMode as integer
	static szServerIP as string
	static szServerPort as string	
	static wVersionRequested as integer	


	''
	'' Check arguments
	''
	if ( ( argc = 2 ) and ( argv(0) = "server" ) ) then
	    
	    ''
	    '' Server mode
	    ''
        ChatMode = SERVER
        szServerPort = argv(1)          
        
	elseif ( ( argc = 3 ) and ( argv(0) = "client" ) ) then
	    
	    ''
	    '' Client mode
	    ''
        ChatMode = CLIENT        
        szServerIP   = argv(1)
        szServerPort = argv(2)
        
    else
        '' 
        '' Wrong syntax
        ''
        print "Syntax for server mode: QBChat server ServerPort
        print "Syntax for client mode: QBChat client ServerIP ServerPort"
		exit sub
		
	end if
	
	''
	'' Initialize WinSock.dll
	''
	wVersionRequested = MAKEWORD( 1, 1 )
	nRet = WSAStartup( wVersionRequested, wsaDat )
	if ( nRet <> 0 ) then
		print "WSAStartup():"; nRet
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
	
	
	'' 
	'' Go into chat mode
	'' 
	if ( ChatMode = CLIENT ) then
	    ChatClient szServerIP, szServerPort
	elseif ( ChatMode = SERVER ) then
	    ChatServer szServerPort
    end if
    
	
	''
	'' Release WinSock
	''	
	nRet = WSACleanup	
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub ChatServer ( szServerPort as string )
    dim nPort as integer
    dim listenSocket as long, remoteSocket as long
    dim lpRecvBuffer as long
    dim saServer as sockaddrIn, sa as sockaddrIn
    dim sendbuffer as string
	dim rfds(0 to 1) as long
	dim tv AS timeval

    nPort = val( szServerPort )
    
    ''
    '' Create a TCP/IP stream socket to "listen" with
    ''
    print "Creating..."
    listenSocket = socket( AF.INET, SOCK.STREAM, IPPROTO.TCP )
    if ( listenSocket = INVALID.SOCKET ) then
        print "Error: socket()"; WSAGetLastError
        exit sub 
    end if
    
	''
	'' Fill in the address structure
	''
	saServer.sinfamily = AF.INET
	saServer.sinaddr.saddr = INADDR.ANY
	saServer.sinport = htons(nPort)

	''
	'' bind the name to the socket
	''
	print "Binding..."
	nRet = bind( listenSocket, saServer, len( saServer ) )	
	if ( nRet = SOCKET.ERROR ) then	
		print "Error: bind()"; WSAGetLastError
		nRet = closesocket( listenSocket )
		exit sub
	end if
	
	''
	'' Set the socket to listen
	''
	print "Listening..."
	nRet = listen( listenSocket, SOMAXCONN )
	if ( nRet = SOCKET.ERROR ) then	
		print "Error: listen()"; WSAGetLastError
		nRet = closesocket( listenSocket )
		exit sub
	end if

	''
	'' Wait for an incoming request
	''	
	print "Accepting... (press any key to exit)"
    do while ( len( inkey$ ) = 0 )
		tv.tvSec = 0: tv.tvUsec = 0
		rfds(0) = 1
		rfds(1) = listenSocket
        nRet = selectsocket( 0, rfds(0), 0, 0, tv )

		if ( nRet < 0 ) then
			print "Error: select()"; WSAGetLastError
			nRet = closesocket( listenSocket )
			exit sub

		elseif ( nRet > 0 ) then
			print "New client!"
    	
    		remoteSocket = accept( listenSocket, sa, len( sa ) )    		
			if ( remoteSocket = INVALID.SOCKET ) then
				print "Error: accept()"; WSAGetLastError
				nRet = closesocket( listenSocket )
				exit sub
			else
				print "IP: "; inetNtoa( sa.sinAddr.Saddr )
				exit do
			end if
		end if
	loop
	if ( remoteSocket = 0 ) then exit sub


	''''''''''''''''''''''''''''''''''''
	print "Receiving... (press any key to stop)"
	lpRecvBuffer = MAKELONG( varptr(recvBuffer(0)), varseg(recvBuffer(0)) )
	nRet = nbRecv( remoteSocket, lpRecvBuffer, BUFFSIZE )
	if ( nRet = -1 ) then
		print "Error: nbRecv()"; WSAGetLastError
		nRet = closesocket( remoteSocket )
		nRet = closesocket( listenSocket )
		exit sub
	end if
	'' Write to stdout
	fwrite stdout, lpRecvBuffer, nRet
	print
	
	''''''''''''''''''''''''''''''''''''	
	input "Say: ", sendBuffer
	sendBuffer = sendBuffer + chr$( 0 )

	print "Sending... (press any key to stop)"
	nRet = nbSend( remoteSocket, _
				   MAKELONG( sadd( sendbuffer ), varseg( sendbuffer ) ), _
				   len( sendbuffer ) )
	if ( nRet = -1 ) then
		print "Error: nbSend()"; WSAGetLastError
	end if
	
	''
	'' Close BOTH sockets before exiting
	''
	print "Closing..."
    nRet = shutdown( remoteSocket, 2 )
    nRet = closesocket( remoteSocket )
    nRet = shutdown( listenSocket, 2 )
    nRet = closesocket( listenSocket )
    
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub ChatClient ( szServerName as string, szServerPort as string )
    dim nPort as integer
    dim iaHost as inAddr
	dim lpHostEntry as long    
    dim connSocket as long    
    dim lpRecvBuffer as long
    dim saServer as sockaddrIn
    dim sendbuffer as string
    dim wfds(0 to 1) as long
    dim tv AS timeval
    
    nPort = val( szServerPort )    
    
	''
	'' Find the server
	''
	print "Finding..."
	lpHostEntry = gethostbyname( szServerName )
    if ( lpHostEntry = NULL ) then    
        print "Error: gethostbyname()"; WSAGetLastError
        exit sub
    end if
    
	''
	'' Create a TCP/IP stream socket
	''
	print "Creating..."
	connSocket = socket( AF.INET, SOCK.STREAM, IPPROTO.TCP )
	if ( connSocket = INVALID.SOCKET ) then	
        print "Error: socket()"; WSAGetLastError
        exit sub
    end if
    
	''
	'' Fill in the address structure
	''
	saServer.sinfamily = AF.INET
	saServer.sinaddr.saddr = hostent.hAddrList( lpHostEntry )
	saServer.sinport = htons( nPort )

	print "Connecting... (press any key to exit)"
	nRet = nbConnect( connSocket, saServer, len( saServer ) )
	if ( nRet <> 0 ) then	
		if ( nRet = -1 ) then print "Error: nbConnect()"; WSAGetLastError
		nRet = closesocket( connSocket )
		exit sub
	end if
    		
	print "Connected!"
		
	
	''''''''''''''''''''''''''''''''''''
	input "Say: ", sendBuffer
    sendBuffer = sendBuffer + chr$( 0 )
	
	print "Sending... (press any key to stop)"
	nRet = nbSend( connSocket, _
				   MAKELONG( sadd( sendbuffer ), varseg( sendbuffer ) ), _ 
				   len( sendbuffer ) )
	if ( nRet <> len( sendbuffer ) ) then	
		print "Error: nbSend()"; WSAGetLastError
		nRet = closesocket( connSocket )
		exit sub
    end if    

	
	''''''''''''''''''''''''''''''''''''
	print "Receiving... (press any key to stop)"
	lpRecvBuffer = MAKELONG( varptr(recvBuffer(0)), varseg(recvBuffer(0)) )
	nRet = nbRecv( connSocket, lpRecvBuffer, BUFFSIZE )
	if ( nRet = -1 ) then
		print "Error: nbRecv()"; WSAGetLastError
		nRet = closesocket( connSocket )
		exit sub
	end if
	'' Write to stdout
	fwrite stdout, lpRecvBuffer, nRet
	print

    
    print "Closing..."
    nRet = shutdown( connSocket, 2 )
    nRet = closesocket( connSocket )
    
end sub


''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub doParseCmd ( argc as integer, argv() as string )
    static cmd as string
    
	cmd = lcase$( command$ + chr$( 13 ) )
	
	
	p = 1
	argc = 0
	
	do
		do
			char = asc( mid$( cmd, p, 1 ) )
			p = p + 1
		loop while ( (char = 32) or (char = 7) )
		
		if char = 13 then exit do

		do
			argv(argc) = argv(argc) + chr$( char )
			char = asc( mid$( cmd, p, 1 ) )
			p = p + 1
		loop until ( (char = 32) or (char = 7) or (char = 13) )
		
		argc = argc + 1
	loop while ( char <> 13 )
	
	cmd = ""
		
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

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function nbSend% ( s as long, buffer as long, bytes as integer )
    dim nRet as integer
    dim tv AS timeval
    dim wfds(0 to 1) as long
    dim sent as integer
    dim lpBuffer as long
    
    lpBuffer = buffer
	
	sent = 0
	do while ( ( len(inkey$) = 0 ) and ( bytes > 0 ) )
		
		tv.tvSec = 0
		tv.tvUsec = 0
		wfds(0) = 1
		wfds(1) = s
		nRet = selectsocket( 0, 0, wfds(0), 0, tv )
		
		if ( nRet < 0 ) then
			nbSend = -1
			exit function

		elseif ( nRet > 0 ) then
			nRet = send( s, lpBuffer, bytes, 0 )
			if ( nRet = SOCKET.ERROR ) then	
				nbSend = -1
				exit function
    		end if
    		
			if ( nRet = 0 ) then 				'' connection closed?
				nbSend = -1
				exit function
			end if
    		
    		lpBuffer = lpBuffer + nRet
    		bytes = bytes - nRet
    		sent = sent + nRet
    	end if
    loop
    
    nbSend = sent
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function nbRecv% ( s as long, buffer as long, bytes as integer )
    dim nRet as integer
    dim tv AS timeval
    dim rfds(0 to 1) as long
    dim received as integer
    dim lpBuffer as long

	lpBuffer = buffer
	
	received = 0
	do while ( ( len(inkey$) = 0 ) and ( bytes > 0 ) )
		
		tv.tvSec = 0
		tv.tvUsec = 0
		rfds(0) = 1
		rfds(1) = s
		nRet = selectsocket( 0, rfds(0), 0, 0, tv )
		
		if ( nRet < 0 ) then
			nbRecv = -1
			exit function

		elseif ( nRet > 0 ) then
			
			nRet = recv( s, lpBuffer, bytes, 0 )
			if ( nRet = INVALID.SOCKET ) then	
				nbRecv = -1
				exit function
			end if
				
			if ( nRet = 0 ) then 				'' connection closed?
				nbRecv = received
				exit function
			end if
			
			lpBuffer = lpBuffer + nRet
			bytes = bytes - nRet
			received = received + nRet
		end if
	loop

	nbRecv = received
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function nbConnect% ( s as long, addr as sockaddrIn, addrLen as integer )
    dim nRet as integer, connected as integer
    dim tv AS timeval
    dim wfds(0 to 1) as long, efds(0 to 1) as long
    
    ''
    '' put socket in non-blocking mode
    ''
    if ( ioctlsocket( s, FIONBIO, 1 ) = SOCKET.ERROR ) then 
    	print "Error @ ioctlsocket()"; WSAGetLastError
    	nbConnect = -1
    	exit function
    end if
	
	nRet = connect( s, addr, addrLen )
	if ( nRet = SOCKET.ERROR ) then	
		if ( WSAGetLastError <> WSAEWOULDBLOCK ) then
    		nbConnect = -1
    		exit function
    	end if
	end if
    
    connected = 0
    do while ( len( inkey$ ) = 0 )
		tv.tvSec = 0: tv.tvUsec = 0
		wfds(0) = 1
		wfds(1) = s
		efds(0) = 1
		efds(1) = s
		nRet = selectsocket( 0, 0, wfds(0), efds(0), tv )

		if ( nRet < 0 ) then
			nbConnect = -1
			exit function

		elseif ( nRet > 0 ) then
			if ( efds(0) = 0 ) then
				connected = -1
			end if
			exit do
    	end if
    loop
	
	if ( not connected ) then
		nbConnect = -2
	else
		nbConnect = 0
	end if
end function
