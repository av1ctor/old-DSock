''
'' scs.bas -- server for Simple Chat protocol
'' copyleft 2002 by v1ctor (av1ctor@yahoo.com.br)
''

'option explicit

defint a-z
'$include: '..\..\inc\dsock.bi'
'$include: 'schat.bi'

const SCS.TIMEOUT%	= 4%						'' in seconds

const SCS.OFFLINE% 	= 0%
const SCS.ONLINE% 	= 1%
const SCS.JOINING%	= 2%

type TSC
	sname			as string * 16				'' server name
	listenSocket 	as long
end type

type TUSER
	prv				as integer
	nxt				as integer

	id				as integer
	state			as integer
	s				as long
	nick			as string * 8'SC.NICKLEN
	mode			as integer

	ping			as integer					'' secs passed since last PONG answer
	fmsg			as integer					'' first msg on queue to send
end type

type TMSG
	prv				as integer
	nxt				as integer

    id              as integer
	completed		as integer
	start			as integer
    length			as integer

	cnt				as integer
	sender			as integer
	receiver		as integer

    cmd             as integer
    msg				as string * 160'SC.MAXLEN
end type

'' protos :::
declare sub 	 main 			( argc as integer, argv() as string )
declare sub 	 parseCmd 		( argc as integer, argv() as string )

declare function scsInit%		( port as integer )
declare sub 	 scsEnd			( )
declare sub 	 scsMain		( )
declare sub 	 scsPing 		( )
declare function scsUI%			( )
declare function scsAccept% 	( )
declare function scsReceive% 	( )
declare sub 	 scsIncoming 	( buffer as string, received as integer, u as integer )
declare sub 	 scsProcess		( )
declare function scsSend%		( )
declare sub 	 scsDump 		( )

declare sub 	 userInit 		( )
declare function userNew% 		( )
declare function userAdd% 		( s as long )
declare sub 	 userFree 		( u as integer )
declare sub 	 userDel 		( u as integer )
declare function userBySocket%	( s as long )
declare function userByNick% 	( nick as string )
declare sub 	 userUpdList 	( head as integer )
declare sub 	 userSendMsgs 	( u as integer )

declare sub 	 msgInit 		( mLst as TLIST, mTB() as TMSG, imax as integer )
declare function msgNew% 		( mLst as TLIST, mTB() as TMSG )
declare sub      oMsgAdd        ( m as integer, length as integer, cmd as integer, s as integer, message as string )
declare sub      oMsgToAdd      ( m as integer, length as integer, cmd as integer, s as integer, r as integer, message as string )
declare sub 	 iMsgAdd 		( m as integer, id as integer, start as integer, _
								  length as integer, cmd as integer, completed as integer, _
                                  s as integer, message as string )
declare sub 	 msgFree 		( mLst as TLIST, mTB() as TMSG, m as integer )
declare sub 	 msgDelTail 	( mLst as TLIST, mTB() as TMSG )
declare sub 	 msgDelHead 	( mLst as TLIST, mTB() as TMSG )
declare sub 	 msgDel 		( mLst as TLIST, mTB() as TMSG, m as integer )
declare sub 	 msgDelUser 	( mLst as TLIST, mTB() as TMSG, u as integer )
declare sub 	 msgUpdList 	( mLst as TLIST, mTB() as TMSG )
declare function msgByID% 		( mLst as TLIST, mTB() as TMSG, id as integer )

declare function hexabyte$ 		( num as integer )
declare function hexaword$ 		( num as integer )

clear ,, 4096

'' globals :::
dim shared ctx as TSC

dim shared userLst as TLIST, userTB(0 to SC.MAXUSERS-1) as TUSER
dim shared iMsgLst as TLIST, iMsgTB(0 to SC.MAXMSGS-1) as TMSG
dim shared oMsgLst as TLIST, oMsgTB(0 to SC.MAXMSGS-1) as TMSG

dim shared NEWLINE as string

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	on error goto errtrap

	NEWLINE = chr$( 13 ) + chr$( 10 )
	dim argc as integer, argv(0 to 9) as string

	parseCmd argc, argv()
	main argc, argv()
    end

errtrap:
	print "[ERROR] QB:"; err
	scsEnd
	end


''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub main ( argc as integer, argv() as string )
	dim port as integer

	if ( argc > 0 ) then
		port = val( argv(0) )
	else
		port = SC.DEFPORT
	end if

	if ( not scsInit( port ) ) then exit sub

	scsMain

	scsEnd

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub parseCmd ( argc as integer, argv() as string )
    dim cmd as string
    dim p as integer, char as integer

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

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' server routines
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function scsInit% ( port as integer )
	dim nRet as integer
	dim wsaDat as WSAData
	dim wVersionRequested as integer
	dim saServer as sockaddrIn

	ctx.listenSocket = 0
    ctx.sname = "SC-Serv"

	scsInit = 0

	'' initialize queues
	userInit
	msgInit iMsgLst, iMsgTB(), SC.MAXMSGS
	msgInit oMsgLst, oMsgTB(), SC.MAXMSGS

	''
	'' Initialize WinSock.dll
	''
	wVersionRequested = MAKEWORD( 1, 1 )
	nRet = WSAStartup( wVersionRequested, wsaDat )
	if ( nRet <> 0 ) then
		print "[ERROR] WSAStartup():"; nRet
		exit function
	end if

	''
	'' Check WinSock version
	''
	if ( wsaDat.wVersion <> wVersionRequested ) then
		print "[ERROR] WinSock version not supported"
		nRet = WSACleanup
		exit function
	end if

    ''
    '' Create a TCP/IP stream socket to "listen" with
    ''
    ctx.listenSocket = socket( AF.INET, SOCK.STREAM, IPPROTO.TCP )
    if ( ctx.listenSocket = INVALID.SOCKET ) then
        print "[ERROR] socket()"; WSAGetLastError
        exit function
    end if

	''
	'' Fill in the address structure
	''
	saServer.sinfamily = AF.INET
	saServer.sinaddr.saddr = INADDR.ANY
	saServer.sinport = htons( port )

	''
	'' bind the name to the socket
	''
	nRet = bind( ctx.listenSocket, saServer, len( saServer ) )
	if ( nRet = SOCKET.ERROR ) then
		print "[ERROR] bind()"; WSAGetLastError
		nRet = closesocket( ctx.listenSocket )
		exit function
	end if

	''
	'' Set the socket to listen
	''
	nRet = listen( ctx.listenSocket, SOMAXCONN )
	if ( nRet = SOCKET.ERROR ) then
		print "[ERROR] listen()"; WSAGetLastError
		nRet = closesocket( ctx.listenSocket )
		exit function
	end if


	screen 0: width 80
	cls


    scsInit = -1
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub scsEnd
	dim nRet as integer, u as integer

	print "closing..."


	''
	'' close connection to all clients
	''
	u = userLst.head
	do while ( u <> -1 )
        nRet = shutdown( userTB(u).s, 2 )
        nRet = closesocket( userTB(u).s )
		u = userTB(u).nxt
	loop

	''
	'' close listen socket
	''
	if ( ctx.listenSocket <> 0 ) then
		nRet = shutdown( ctx.listenSocket, 2 )
		nRet = closesocket( ctx.listenSocket )
		ctx.listenSocket = 0
	end if

    ''
	'' Release WinSock
	''
	nRet = WSACleanup
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub scsMain
    dim finish as integer

    finish = 0
	do until ( finish <> 0 )

		if ( scsAccept	) then
			print "[ERROR] scsAccept(): "; WSAGetLastError
			exit do
		end if

		if ( scsReceive ) then
			print "[ERROR] scsReceive(): "; WSAGetLastError
			exit do
		end if

		scsPing

		finish = scsUI

		scsProcess

		if ( scsSend ) then
			print "[ERROR] scsSend (): "; WSAGetLastError
			exit do
		end if

	loop

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub scsPing
	static lastTimer as single, currTimer as single
	dim i as integer, q as integer

	'' 1/4 of timeout elapsed?
	currTimer = timer
	if ( abs(currTimer - lastTimer) < (SCS.TIMEOUT/4) ) then exit sub
	lastTimer = currTimer

	'' check all users
	i = userLst.head
	do while ( i <> -1 )

		userTB(i).ping = userTB(i).ping + (SCS.TIMEOUT\4)

		'' timed out? close connection and tell other users
		if ( userTB(i).ping >= SCS.TIMEOUT ) then
			q = msgNew( iMsgLst, iMsgTB() )
			if ( q <> -1 ) then
				iMsgAdd ( q ), iMsgTB(q).id, 0, 0, SCP.QUIT, -1, ( i ), ""
			end if

		'' just send a PING msg then
		else
			q = msgNew( oMsgLst, oMsgTB() )
			if ( q <> -1 ) then
                oMsgToAdd ( q ), 0, SCP.PING, ( i ), ( i ), ""
			end if

		end if

		i = userTB(i).nxt
	loop

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function scsUI%
	static firstRun as integer, users as integer, imsgs as integer, omsgs as integer
	static lastRow as integer
	dim k as string
	dim m as integer, u as integer, cmd as integer

	scsUI = 0

	view print

	if ( not firstRun ) then
		firstRun = -1
		users = -1
		omsgs = -1
		imsgs = -1
	end if

	if ( users <> userLst.items ) then
		users = userLst.items
		locate 25, 1
		print "Users:"; users; "    ";
	end if

	if ( omsgs <> oMsgLst.items ) then
		omsgs = oMsgLst.items
		locate 25, 15
		print "oMsgs:"; omsgs; "    ";
	end if

	if ( imsgs <> iMsgLst.items ) then
		imsgs = iMsgLst.items
		locate 25, 30
		print "iMsgs:"; imsgs; "    ";
	end if

	'' check keys
	k = inkey$
	if ( len( k ) > 0 ) then
		select case asc( k )
			case 27
				scsUI = -1
		end select
	end if

	'' show joins/quits
	view print 1 to 12
	if ( lastRow = 0 ) then lastRow = 1
	locate lastRow, 1

	m = iMsgLst.head
	do while ( m <> -1 )

		if ( iMsgTB(m).completed ) then
			u = iMsgTB(m).sender

			select case iMsgTB(m).cmd

				''''''''''''''''''''''''''''
				case SCP.JOIN						'' <nick>
					print "*** Joins: "; left$( iMsgTB(m).msg, SC.NICKLEN )

				''''''''''''''''''''''''''''
				case SCP.QUIT						'' .
					print "*** Parts: "; userTB(u).nick

				''''''''''''''''''''''''''''
            	case SCP.TEXT                       '' <text>
                	print "<"; rtrim$( userTB(u).nick ); "> "; left$( iMsgTB(m).msg, iMsgTB(m).length )

				''''''''''''''''''''''''''''
				case SCP.PRIV						'' <nick><text>
                	print "*"; rtrim$( userTB(u).nick ); "* ->[("; rtrim$( left$( iMsgTB(m).msg, SC.NICKLEN ) ); ")] "; mid$( iMsgTB(m).msg, 1+SC.NICKLEN, iMsgTB(m).length-SC.NICKLEN )

				''''''''''''''''''''''''''''
				case SCP.NICK						'' <newnick>
					print "*** "; rtrim$(userTB(u).nick); " is now known as "; left$( iMsgTB(m).msg, SC.NICKLEN )

			end select
		end if

		m = iMsgTB(m).nxt
	loop

	lastRow = csrlin
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function scsAccept%
    dim rfds(0 to 1) as long, efds(0 to 1) as long
	dim tv AS timeval
	dim nRet as integer
	dim s as long
	dim sa as sockaddrIn, lensa as integer

	scsAccept = 0
	do
		tv.tvSec = 0: tv.tvUsec = 0
        rfds(0) = 1
        rfds(1) = ctx.listenSocket
        efds(0) = 1
        efds(1) = ctx.listenSocket
        nRet = selectsocket( 0, rfds(0), 0, efds(0), tv )

		if ( nRet = 0 ) then exit function

        if ( (nRet < 0) or (efds(0) <> 0) ) then
            scsAccept = -1
	    	exit function
	    end if

	    lensa = len( sa )
	    s = accept( ctx.listenSocket, sa, lensa )
	    if ( s = INVALID.SOCKET ) then
	    	scsAccept = -1
	    	exit function
		end if

	    if ( not userAdd( s ) ) then exit function
	loop

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function scsReceive%
    dim rfds(0 to SC.MAXUSERS) as long
	dim tv AS timeval
	dim nRet as integer, i as integer, u as integer, m as integer
	dim buffer as string, buffaddr as long

	scsReceive = 0

	if ( userLst.items = 0 ) then
		if ( iMsgLst.items <> 0 ) then
			m = iMsgLst.head
			do while ( m <> -1 )
				i = iMsgTB(m).nxt
				msgDelHead iMsgLst, iMsgTB()
				m = i
			loop
		end if

		exit function
	end if

    tv.tvSec = 0: tv.tvUsec = 0

	i = 0
	u = userLst.head
	do while ( u <> -1 )
		rfds(1+i) = userTB(u).s
		i = i + 1
		u = userTB(u).nxt
	loop
	rfds(0) = i

    nRet = selectsocket( 0, rfds(0), 0, 0, tv )

	if ( nRet = 0 ) then exit function

    if ( nRet < 0 ) then
	   	scsReceive = -1
	   	exit function
	end if

	for i = 1 to rfds(0)
	   	u = userBySocket( rfds(i) )
        if ( u <> -1 ) then
			buffer = string$( 1024, 32 )
			buffaddr = MAKELONG( sadd( buffer ), sseg( buffer ) )
			nRet = recv( userTB(u).s, buffaddr, SC.MAXLEN+SCP.HDRLEN, 0 )

			if ( (nRet = SOCKET.ERROR) or (nRet = 0) ) then
				m = msgNew( iMsgLst, iMsgTB() )
				if ( m <> -1 ) then
                    iMsgAdd ( m ), iMsgTB(i).id, 0, 0, SCP.QUIT, -1, ( u ), ""
				end if

			else
				scsIncoming buffer, nRet, ( u )
			end if
	   	end if
	next i

	buffer = ""

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub scsIncoming ( buffer as string, received as integer, u as integer ) static
    dim p as integer, id as integer, start as integer, length as integer
	dim cmd as integer, emark as integer, imark as integer
	dim complete as integer, msglen as integer, m as integer

    p = 1
	do until ( received < SCP.HDRLEN )
        id      = val( "&h" + mid$( buffer, p+SCP.IDPOS, 4 ) )
        start   = val( "&h" + mid$( buffer, p+SCP.STARTPOS, 2 ) )
        length  = val( "&h" + mid$( buffer, p+SCP.LENPOS, 2 ) )
        cmd     = val( "&h" + mid$( buffer, p+SCP.CMDPOS, 2 ) )

        emark   = instr( p+SCP.MSGPOS, buffer, chr$( SCP.ENDMARK ) )
        imark   = instr( p+SCP.MSGPOS, buffer, chr$( SCP.INIMARK ) )

		if ( emark > 0 ) then
			if ( imark > 0 ) then
				if ( emark < imark ) then
					msglen = (emark-1)-(p+SCP.MSGPOS-1)
					complete = -1
				else
					msglen = (imark-1)-(p+SCP.MSGPOS-1)
					complete = 0
				end if
			else
				msglen = (emark-1)-(p+SCP.MSGPOS-1)
				complete = -1
			end if
		else
			if ( imark > 0 ) then
				msglen = (imark-1)-(p+SCP.MSGPOS-1)
			else
				msglen = nRet
			end if
			complete = 0
		end if

		m = msgByID( iMsgLst, iMsgTB(), id )
		if ( m = -1 ) then m = msgNew( iMsgLst, iMsgTB() )
		if ( m <> -1 ) then
			if ( (length > 0) and (msglen > 0) ) then
				iMsgAdd ( m ), id, start, length, cmd, complete, ( u ), _
                    	mid$( buffer, p+SCP.MSGPOS, msglen )
            else
            	iMsgAdd ( m ), id, start, length, cmd, complete, ( u ), ""
            end if
		end if

        p = p + SCP.HDRLEN + msglen
       	received = received - (SCP.HDRLEN + msglen)
	loop
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub scsDump
	static lastRow as integer
	dim curRow as integer
	dim m as integer, s as integer, r as integer, cmd as integer

	'' show joins/quits
	view print 13 to 24
	if ( lastRow = 0 ) then lastRow = 13
	locate lastRow, 1

	m = oMsgLst.head
	do while ( m <> -1 )

		s = oMsgTB(m).sender
		r = oMsgTB(m).receiver

		if ( oMsgTB(m).cmd <> SCP.PING ) then
			if ( s <> r ) then
				print rtrim$( userTB(s).nick ); "->";
				if ( r = -1 ) then
					print "*all*:";
				else
					print rtrim$( userTB(r).nick ); ":";
				end if
			else
				print "-->" rtrim$( userTB(s).nick ); ":";
			end if

			select case oMsgTB(m).cmd
				case SCP.JOIN						'' <nick>
					print "JOIN"

				case SCP.QUIT						'' <nick>
					print "QUIT"

            	case SCP.TEXT                       '' <nick><text>
                    print "TEXT ("; mid$( oMsgTB(m).msg, 1+oMsgTB(m).start+SC.NICKLEN, oMsgTB(m).length-SC.NICKLEN-oMsgTB(m).start ); ")"

				case SCP.PRIV						'' <nick><text>
                    print "PRIV ("; mid$( oMsgTB(m).msg, 1+oMsgTB(m).start+SC.NICKLEN, oMsgTB(m).length-SC.NICKLEN-oMsgTB(m).start ); ")"

				case SCP.NICK						'' <nick><newnick>
                    print "NICK ("; mid$( oMsgTB(m).msg, 1+oMsgTB(m).start+SC.NICKLEN, SC.NICKLEN ); ")"

				case SCP.LIST
					print "LIST"

				case SCP.REFUSED
					print "REFUSED"

				case else
                    print "???"; mid$( oMsgTB(m).msg, 1+oMsgTB(m).start, oMsgTB(m).length-oMsgTB(m).start )

			end select

		end if

		m = oMsgTB(m).nxt
	loop

	lastRow = csrlin
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub scsProcess static
	dim i as integer, m as integer, q as integer, n as integer
	dim u as integer, r as integer
    dim cmd as integer, l as integer, lastPubMsg as integer
	dim userlist as string, users as integer, nick as string * 8

    lastPubMsg = -1
	m = iMsgLst.head
	do while ( m <> -1 )

		n = iMsgTB(m).nxt
		if ( iMsgTB(m).completed ) then
			u = iMsgTB(m).sender
			l = iMsgTB(m).length

			select case iMsgTB(m).cmd

				''''''''''''''''''''''''''''
				case SCP.JOIN
					'' recv: <nick>
					'' send: <nick> or <REFUSED>

					nick = space$( SC.NICKLEN )
					nick = ltrim$( rtrim$( left$( iMsgTB(m).msg, SC.NICKLEN ) ) )

					q = msgNew( oMsgLst, oMsgTB() )
					if ( q = -1 ) then exit do

					if ( userByNick( nick ) = -1 ) then
                    	if ( lastPubMsg = -1 ) then lastPubMsg = q
                    	userTB(u).nick = nick
						userTB(u).state = SCS.ONLINE
						oMsgAdd ( q ), SC.NICKLEN, SCP.JOIN, u, nick

					else
                    	oMsgToAdd ( q ), 0, SCP.REFUSED, u, u, ""
					end if

				''''''''''''''''''''''''''''
				case SCP.QUIT
				'' recv: .
				'' send: <nick>

					if ( userTB(u).state = SCS.ONLINE ) then
						q = msgNew( oMsgLst, oMsgTB() )
						if ( q = -1 ) then exit do
                    	if ( lastPubMsg = -1 ) then lastPubMsg = q
						oMsgAdd ( q ), SC.NICKLEN, SCP.QUIT, u, userTB(u).nick
					end if

					userDel ( u )

				''''''''''''''''''''''''''''
				case SCP.LIST
				'' recv: .
				'' send: <users><nicks list>

					if ( userTB(u).state = SCS.ONLINE ) then
						i = userLst.head
						do while ( i <> -1 )
							q = msgNew( oMsgLst, oMsgTB() )
							if ( q = -1 ) then exit do

				    		users = 0
				    		l = SC.MAXLEN - 2
				    		userlist = ""
				    		do while ( ( i <> -1 ) and ( l-SC.NICKLEN >= 0 ) )
				    			userlist = userlist + userTB(i).nick
				    			l = l - SC.NICKLEN
								i = userTB(i).nxt
								users = users + 1
				    		loop
				    		userlist = hexabyte( users ) + userlist
                        	oMsgToAdd ( q ), 2 + (SC.MAXLEN-2) - l, SCP.LIST, u, u, userlist
						loop
					end if
					userlist = ""

				''''''''''''''''''''''''''''
				case SCP.TEXT
				'' recv: <text>
				'' send: <nick><text>

					if ( userTB(u).state = SCS.ONLINE ) then
						q = msgNew( oMsgLst, oMsgTB() )
						if ( q = -1 ) then exit do
        	            if ( lastPubMsg = -1 ) then lastPubMsg = q
						oMsgAdd ( q ), SC.NICKLEN + l, SCP.TEXT, u, _
								userTB(u).nick + left$( iMsgTB(m).msg, l )
					end if

				''''''''''''''''''''''''''''
				case SCP.PRIV
				'' recv: <toNick><text>
				'' send: <nick><text>

					if ( userTB(u).state = SCS.ONLINE ) then
						r = userByNick( left$( iMsgTB(m).msg, SC.NICKLEN ) )
						if ( r <> -1 ) then
							if ( userTB(r).state = SCS.ONLINE ) then
								q = msgNew( oMsgLst, oMsgTB() )
								if ( q = -1 ) then exit do
                            	oMsgToAdd ( q ), l, SCP.PRIV, u, r, _
                            			  userTB(u).nick + _
                            			  mid$( iMsgTB(m).msg, 1+SC.NICKLEN, l-SC.NICKLEN )
							end if
						end if
					end if

				''''''''''''''''''''''''''''
				case SCP.NICK
				'' recv: <newnick>
				'' send: <nick><newnick>

					if ( userTB(u).state = SCS.ONLINE ) then
						nick = space$( SC.NICKLEN )
						nick = ltrim$( rtrim$( left$( iMsgTB(m).msg, SC.NICKLEN ) ) )

						q = msgNew( oMsgLst, oMsgTB() )
						if ( q = -1 ) then exit do
                    	if ( lastPubMsg = -1 ) then lastPubMsg = q

						if ( userByNick( nick ) = -1 ) then
							oMsgAdd ( q ), SC.NICKLEN*2, SCP.NICK, u, _
									userTB(u).nick + nick
							userTB(u).nick = nick
						else
                    		oMsgToAdd ( q ), 0, SCP.REFUSED, u, u, ""
						end if
					end if

				''''''''''''''''''''''''''''
				case SCP.PONG
				'' recv: .
				'' send: .

					userTB(u).ping = 0

			end select

			msgDel iMsgLst, iMsgTB(), ( m )
		end if

		m = n
	loop

    if ( lastPubMsg <> -1 ) then userUpdList lastPubMsg

    msgUpdList oMsgLst, oMsgTB()

    scsDump

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function scsSend%
    dim wfds(0 to SC.MAXUSERS) as long, efds(0 to SC.MAXUSERS) as long
	dim tv AS timeval
	dim nRet as integer, i as integer, u as integer, m as integer

	scsSend = 0

	if ( oMsgLst.items = 0  ) then exit function

	if ( userLst.items = 0 ) then
		m = oMsgLst.head
		do while ( m <> -1 )
			i = oMsgTB(m).nxt
			msgDelHead oMsgLst, oMsgTB()
			m = i
		loop
		exit function
	end if

	tv.tvSec = 0: tv.tvUsec = 0

	i = 0
	u = userLst.head
	do while ( u <> -1 )
		wfds(1+i) = userTB(u).s
        efds(1+i) = userTB(u).s
		i = i + 1
		u = userTB(u).nxt
	loop
	wfds(0) = i
    efds(0) = i

    nRet = selectsocket( 0, 0, wfds(0), 0, tv )

	if ( nRet = 0 ) then exit function

    if ( (nRet < 0)  ) then 'or (efds(0) <> 0)
	   	scsSend = -1
	   	exit function
	end if

	for i = 1 to wfds(0)
	   	u = userBySocket( wfds(i) )
	   	if ( u <> -1 ) then userSendMsgs u
	next i

end function

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' user routines
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub userInit static
	dim i as integer, p as integer, n as integer

	userLst.head = -1
	userLst.tail = -1
	userLst.fhead = 0
	userLst.items = 0

	p = -1
	n = 1
	for i = 0 to (SC.MAXUSERS-1)-1
		userTB(i).prv = p
		userTB(i).nxt = n
		p = i
		n = n + 1

		userTB(i).state = SCS.OFFLINE
        userTB(i).nick = string$( SC.NICKLEN, 32 )
	next i

	userTB(SC.MAXUSERS-1).prv = p
	userTB(SC.MAXUSERS-1).nxt = -1
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function userNew% static
	static id as integer
	dim i as integer, t as integer, n as integer

	i = userLst.fhead
	if ( i = -1 ) then
		userNew = -1
		exit function
	end if

	'' del from free list
	n = userTB(i).nxt
	if ( n <> -1 ) then
		 userTB(n).prv = -1
	end if
	userLst.fhead = n

	'' add to alloc list
	t = userLst.tail
	if ( t <> -1 ) then
		userTB(t).nxt = i
	else
		userLst.head = i
	end if
	userTB(i).prv = t
	userTB(i).nxt = -1
	userLst.tail = i

	id = cint( ( clng(id) + 1& ) and &h7FFF& )
	userTB(i).id = 1 + id

	userLst.items = userLst.items + 1

	userNew = i
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function userAdd% ( s as long ) static
    dim u as integer

	u = userNew
	if ( u = -1	) then
		userAdd = 0
		exit function
	end if

	userTB(u).state = SCS.JOINING
	userTB(u).s = s
    userTB(u).nick = space$( SC.NICKLEN )
	userTB(u).fmsg = -1
	userTB(u).ping = 0

	userAdd = -1
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub userFree ( u as integer ) static
	dim p as integer, n as integer, h as integer

	'' del from alloc list
	p = userTB(u).prv
	n = userTB(u).nxt
	if ( p <> -1 ) then
		userTB(p).nxt = n
	else
		userLst.head = n
	end if
	if ( n <> -1 ) then
		userTB(n).prv = p
	else
		userLst.tail = p
	end if

	'' add to free list
	h = userLst.fhead
	userTB(u).prv = -1
	userTB(u).nxt = h
	if ( h <> -1 ) then
		userTB(h).prv = u
	end if
	userLst.fhead = u

	userLst.items = userLst.items - 1

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub userDel ( u as integer )
	dim nRet as integer

	nRet = shutdown( userTB(u).s, 2 )
	nRet = closesocket( userTB(u).s )

	msgDelUser oMsgLst, oMsgTB(), ( u )

	userFree ( u )

	userTB(u).state = SCS.OFFLINE
    userTB(u).nick = space$( SC.NICKLEN )

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function userBySocket% ( s as long ) static
	dim i as integer

	i = userLst.head
	do while ( i <> -1 )
		if ( userTB(i).s = s ) then exit do
		i = userTB(i).nxt
	loop

	userBySocket = i
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function userByNick% ( nick as string ) static
	dim i as integer

	i = userLst.head
	do while ( i <> -1 )
		if ( userTB(i).nick = nick ) then exit do
		i = userTB(i).nxt
	loop

	userByNick = i
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub userUpdList ( head as integer )
	dim i as integer

	i = userLst.head
	do while ( i <> -1 )
		if ( userTB(i).fmsg = -1 ) then userTB(i).fmsg = head
		i = userTB(i).nxt
	loop

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub userSendMsgs ( u as integer ) static
	dim m as integer, n as integer
	dim r as integer, s as integer
	dim nRet as integer
	dim buffer as string, buffaddr as long

	m = userTB(u).fmsg
	do while ( m <> -1 )
		s = oMsgTB(m).sender
		r = oMsgTB(m).receiver
		'if ( ( s <> u ) or ( s = r ) ) then
			if ( ( r = -1 ) or ( r = u ) ) then

                length = oMsgTB(m).length - oMsgTB(m).start
				buffer = chr$( SCP.INIMARK ) + _
				 		    hexaword( oMsgTB(m).id ) + _
				 		    hexabyte( oMsgTB(m).start ) + _
				 		    hexabyte( length ) + _
				 		    hexabyte( oMsgTB(m).cmd )
				if ( length > 0 ) then
                    buffer = buffer + mid$( oMsgTB(m).msg, 1+oMsgTB(m).start, length )
				end if
				buffer = buffer + chr$( SCP.ENDMARK )

				buffaddr = MAKELONG( sadd( buffer ), sseg( buffer ) )
				nRet = send( userTB(u).s, buffaddr, SCP.HDRLEN + length, 0 )

				if ( nRet = SOCKET.ERROR ) then
					exit do
				end if

				nRet = nRet - SCP.HDRLEN
				'' lame way to handle not complete msgs been sent, cause
				'' non-blocking mode has to be used as blocking+threads
                '' or async sockets aren't psible: try next time
				'' sending the whole thing, ow...
				if ( nRet = length ) then
					oMsgTB(m).cnt = oMsgTB(m).cnt - 1
				else
					exit do
				end if
			end if
		'end if

		n = oMsgTB(m).nxt
		if ( oMsgTB(m).cnt = 0 ) then msgDel oMsgLst, oMsgTB(), ( m )
		m = n
	loop
	userTB(u).fmsg = m

	buffer = ""

end sub

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' message processing
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgInit ( mLst as TLIST, mTB() as TMSG, imax as integer ) static
	dim i as integer, p as integer, n as integer

	mLst.head = -1
	mLst.tail = -1
	mLst.fhead = 0
	mLst.items = 0

	p = -1
	n = 1
	for i = 0 to (imax-1)-1
		mTB(i).prv = p
		mTB(i).nxt = n
		p = i
		n = n + 1

		mTB( i ).msg = string$( SC.MAXLEN, 32 )
	next i

	mTB(imax-1).prv = p
	mTB(imax-1).nxt = -1
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function msgNew% ( mLst as TLIST, mTB() as TMSG ) static
	static id as integer
	dim i as integer, t as integer, n as integer

	i = mLst.fhead
	if ( i = -1 ) then
		msgNew = -1
		exit function
	end if

	'' del from free list
	n = mTB(i).nxt
	if ( n <> -1 ) then
		 mTB(n).prv = -1
	end if
	mLst.fhead = n

	'' add to alloc list
	t = mLst.tail
	if ( t <> -1 ) then
		mTB(t).nxt = i
    else
		mLst.head = i
	end if
	mTB(i).prv = t
	mTB(i).nxt = -1
	mLst.tail = i

	id = cint( ( clng(id) + 1& ) and &h7FFF& )
	mTB(i).id = -32768 + id

    mLst.items = mLst.items + 1

    msgNew = i
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub oMsgAdd ( m as integer, length as integer, cmd as integer, _
              s as integer, message as string ) static

	oMsgTB(m).start	 	= 0
	oMsgTB(m).length 	= length
    oMsgTB(m).cmd		= cmd
    oMsgTB(m).sender 	= s
	oMsgTB(m).receiver 	= -1
	oMsgTB(m).cnt 		= userLst.items
    if ( length > 0 ) then mid$( oMsgTB(m).msg, 1, length ) = message

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub oMsgToAdd ( m as integer, length as integer, cmd as integer, _
                s as integer, r as integer, message as string ) static

	oMsgTB(m).start	 	= 0
	oMsgTB(m).length 	= length
    oMsgTB(m).cmd		= cmd
    oMsgTB(m).sender 	= s
    oMsgTB(m).receiver 	= r
    oMsgTB(m).cnt 		= 1
    if ( length > 0 ) then mid$( oMsgTB(m).msg, 1, length ) = message

    if ( userTB(r).fmsg = -1 ) then userTB(r).fmsg = m

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub iMsgAdd ( m as integer, id as integer, start as integer, _
			  length as integer, cmd as integer, completed as integer, _
              s as integer, message as string ) static

	iMsgTB(m).id 		= id
	iMsgTB(m).start 	= start
	iMsgTB(m).length 	= length
	iMsgTB(m).completed = completed
	iMsgTB(m).cmd 		= cmd
	iMsgTB(m).sender	= s
    if ( length > 0 ) then mid$( iMsgTB(m).msg, 1+start ) = message

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgFree ( mLst as TLIST, mTB() as TMSG, m as integer )
	dim p as integer, n as integer, h as integer

	'' del from alloc list
	p = mTB(m).prv
	n = mTB(m).nxt

	if ( p <> -1 ) then
		mTB(p).nxt = n
	else
		mLst.head = n
	end if
	if ( n <> -1 ) then
		mTB(n).prv = p
	else
		mLst.tail = p
	end if

	'' add to free list
	h = mLst.fhead
	mTB(m).prv = -1
	mTB(m).nxt = h
	if ( h <> -1 ) then
		mTB(h).prv = m
	end if
	mLst.fhead = m

    mLst.items = mLst.items - 1

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgDelTail ( mLst as TLIST, mTB() as TMSG ) static

	mTB( mLst.tail ).msg = string$( SC.MAXLEN, 32 )

	msgFree mLst, mTB(), ( mLst.tail )

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgDelHead ( mLst as TLIST, mTB() as TMSG ) static

	mTB( mLst.head ).msg = string$( SC.MAXLEN, 32 )

	msgFree mLst, mTB(), ( mLst.head )

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgDel ( mLst as TLIST, mTB() as TMSG, m as integer ) static

	mTB( m ).msg = string$( SC.MAXLEN, 32 )

	msgFree mLst, mTB(), ( m )

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgDelUser ( mLst as TLIST, mTB() as TMSG, u as integer ) static
    dim m as integer, i as integer

	m = mLst.head
	do while ( m <> -1 )
		i = mTB(m).nxt

    	if ( mTB(m).receiver = u ) then
			mTB( m ).msg = string$( SC.MAXLEN, 32 )
			msgFree mLst, mTB(), ( m )
    	end if

    	m = i
	loop

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function msgByID% ( mLst as TLIST, mTB() as TMSG, id as integer ) static
	dim i as integer

	i = mLst.head
	do while ( i <> -1 )
		if ( mTB(i).id = id ) then exit do
		i = mTB(i).nxt
	loop

	msgByID = i
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgUpdList ( mLst as TLIST, mTB() as TMSG )
	dim m as integer, i as integer, u as integer

	m = mLst.head
	do while ( m <> -1 )
		i = mTB(m).nxt
		u = mTB(m).receiver
		if ( u <> -1 ) then
			'' bug: msg can stay with in queue if user slot was occuped in
            ''      the mid time by another user. users need unique IDs for
            ''      fixing that.
			if ( userTB(u).state = SCS.OFFLINE ) then
				msgDel mLst, mTB(), ( m )
			end if

		else
			if ( mTB(m).cnt > userLst.items ) then mTB(m).cnt = userLst.items
			if ( mTB(m).cnt <= 0 ) then msgDel mLst, mTB(), ( m )
		end if
		m = i
	loop

end sub

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' misc routines
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function hexaword$ ( num as integer ) static

    if ( num >= 0 ) then
    	if ( num < 16 ) then
    		hexaword$ = "000" + hex$( num )
    	elseif ( num < 256 ) then
    		hexaword$ = "00" + hex$( num )
    	else
    		hexaword$ = hex$( num )
    	end if
    else
    	hexaword$ = hex$( num )
    end if

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function hexabyte$ ( num as integer ) static

    if ( num >= 0 ) then
    	if ( num < 16 ) then
    		hexabyte$ = "0" + hex$( num )
    	else
    		hexabyte$ = hex$( num )
    	end if
    else
    	hexabyte$ = hex$( num )
    end if

end function

