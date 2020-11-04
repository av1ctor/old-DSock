''
'' scc.bas -- client for Simple Chat protocol
'' copyleft 2002 by v1ctor (av1ctor@yahoo.com.br)
''

'option explicit

defint a-z
'$include: '..\..\inc\dsock.bi'
'$include: 'schat.bi'

const SCC.MSRES!	= 1.0! / 18.2!

const SCC.OFFLINE%		= 0%
const SCC.ONLINE%		= 1%
const SCC.CONNECTING%	= 2%
const SCC.CONNECTED% 	= 3%
const SCC.JOINING%		= 4%
const SCC.JOINED%		= 5%
const SCC.STATES%		= 6%

type TSC
	state			as integer
	nick			as string * 8'SC.NICKLEN
	hostSocket		as long
	ha				as sockaddrIn
	cmd				as integer
end type

type TUSER
	prv				as integer
	nxt				as integer

	state			as integer
	nick			as string * 8'SC.NICKLEN
	mode			as integer
end type

type TMSG
	prv				as integer
	nxt				as integer

	id				as integer
	completed		as integer
	start			as integer
	length			as integer

	cmd				as integer
	msg				as string * 160'SC.MAXLEN
end type


'' protos :::
declare function sccInit%		( )
declare sub 	 sccEnd			( )
declare sub 	 sccMain		( )
declare function sccReceive%	( )
declare function sccConnecting% ( )
declare function sccConnect% 	( text as string )
declare sub 	 sccDisconnect  ( )
declare sub 	 sccUIProcess 	( text as string )
declare function sccUI%			( )
declare sub 	 sccProcess		( )
declare function sccSend%		( )

declare sub 	 userInit 		( )
declare function userNew% 		( )
declare function userAdd% 		( nick as string )
declare sub 	 userFree 		( u as integer )
declare sub 	 userDel 		( u as integer )
declare function userByNick% 	( nick as string )

declare sub 	 msgInit 		( mLst as TLIST, mTB() as TMSG, imax as integer )
declare function msgNew% 		( mLst as TLIST, mTB() as TMSG )
declare sub      oMsgAdd        ( m as integer, length as integer, cmd as integer, message as string )
declare sub 	 iMsgAdd 		( m as integer, id as integer, start as integer, _
								  length as integer, cmd as integer, completed as integer, _
                                  message as string )
declare sub 	 msgFree 		( mLst as TLIST, mTB() as TMSG, m as integer )
declare sub 	 msgDel 		( mLst as TLIST, mTB() as TMSG, m as integer )
declare sub 	 msgDelTail 	( mLst as TLIST, mTB() as TMSG )
declare sub 	 msgDelHead 	( mLst as TLIST, mTB() as TMSG )
declare function msgByID% 		( mLst as TLIST, mTB() as TMSG, id as integer )

declare sub 	 tokenize 		( text as string, tokenc as integer, tokenv() as string, tokenp() as integer, maxc as integer )
declare function hexabyte$ 		( num as integer )
declare function hexaword$ 		( num as integer )

clear ,, 4096

'' globals :::
dim shared ctx as TSC

dim shared userLst as TLIST, userTB(0 to SC.MAXUSERS-1) as TUSER
dim shared iMsgLst as TLIST, iMsgTB(0 to SC.MAXMSGS-1) as TMSG
dim shared oMsgLst as TLIST, oMsgTB(0 to SC.MAXMSGS-1) as TMSG

dim shared sttTB (0 to SCC.STATES-1) as string

	sttTB(SCC.OFFLINE) 		= "OFFLINE"
	sttTB(SCC.ONLINE) 		= "ONLINE"
	sttTB(SCC.CONNECTING) 	= "CONNECTING"
	sttTB(SCC.CONNECTED) 	= "CONNECTED"
	sttTB(SCC.JOINING) 		= "JOINING"
	sttTB(SCC.JOINED) 		= "JOINED"

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

	on error goto errtrap

	if ( not sccInit ) then end

	sccMain

	sccEnd
	end

errtrap:
	print "[ERROR] QB:"; err
	sccEnd
	end


'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' client routines
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function sccInit%
	dim nRet as integer
	dim wsaDat as WSAData
	dim wVersionRequested as integer

	sccInit = 0

	ctx.state = SCC.OFFLINE
	ctx.hostSocket = 0
	ctx.cmd = 0
	ctx.nick = space$( SC.NICKLEN )

	print "starting..."

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

	screen 0: width 80
	cls
	view print 1 to 23
	locate 1, 1

    sccInit = -1
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub sccEnd
	dim nRet as integer, u as integer

	print "closing..."

	''
	'' close socket
	''
	if ( ctx.hostSocket <> 0 ) then
		nRet = shutdown( ctx.hostSocket, 2 )
		nRet = closesocket( ctx.hostSocket )
		ctx.hostSocket = 0
	end if

	''
	'' Release WinSock
	''
	nRet = WSACleanup
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub sccMain
    dim finish as integer

    finish = 0
	do until ( finish <> 0 )
		if ( sccReceive ) then
			print "[ERROR] sccReceive(): "; WSAGetLastError
			exit do
		end if

		finish = sccUI

		sccProcess

		if ( sccSend ) then
			print "[ERROR] sccSend (): "; WSAGetLastError
			exit do
		end if

		if ( ctx.cmd = SCP.QUIT ) then
			sccDisconnect
		end if

		ctx.cmd = 0

	loop

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function sccReceive%
    static lastTimer as single, currTimer as single
    dim rfds(0 to 1) as long, efds(0 to 1) as long
	dim tv AS timeval
	dim nRet as integer
	dim buffer as string, buffaddr as long
    dim p as integer, id as integer, start as integer, length as integer
	dim cmd as integer, emark as integer, imark as integer
	dim complete as integer, msglen as integer, m as integer

	sccReceive = 0

	'' not connected?
	if ( ctx.state = SCC.OFFLINE ) then exit function

	'' enough time elapsed (do not do polling too much times p/ sec)?
	currTimer = timer
	if ( abs(currTimer - lastTimer) < SCC.MSRES ) then exit function
	lastTimer = currTimer

	'' poll host socket, checking for incoming messages
	tv.tvSec = 0: tv.tvUsec = 0
	rfds(0) = 1
	rfds(1) = ctx.hostSocket
	efds(0) = 1
	efds(1) = ctx.hostSocket
    nRet = selectsocket( 0, rfds(0), 0, efds(0), tv )

	'' nothing new?
	if ( nRet = 0 ) then exit function

    '' error? dang!
    if ( (nRet < 0) or (efds(0) <> 0) ) then
        sccReceive = -1
        exit function
	end if

    buffer = string$( 1024, 32 )
    buffaddr = MAKELONG( sadd( buffer ), sseg( buffer ) )
	nRet = recv( ctx.hostSocket, buffaddr, SC.MAXLEN+SCP.HDRLEN, 0 )
	if ( nRet = SOCKET.ERROR ) then
		sccReceive = -1
		exit function
	end if

	if ( nRet = 0 ) then 				'' connection closed?
		sccDisconnect
		exit function
	end if

	'' add messages to incoming queue
    p = 1
	do until ( nRet < SCP.HDRLEN )
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
				iMsgAdd ( m ), id, start, length, cmd, complete, _
                    	mid$( buffer, p+SCP.MSGPOS, msglen )
            else
            	iMsgAdd ( m ), id, start, length, cmd, complete, ""
            end if
		end if

        p = p + SCP.HDRLEN + msglen
       	nRet = nRet - (SCP.HDRLEN + msglen)
	loop

	buffer = ""

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function sccConnecting%
	dim wfds(0 to 1) as long, efds(0 to 1) as long
	dim tv AS timeval
	dim nRet as integer

	sccConnecting = 0

	'' not connecting?
	if ( (ctx.state <> SCC.CONNECTING) or (ctx.hostSocket = 0) ) then exit function

	tv.tvSec = 0: tv.tvUsec = 0
	wfds(0) = 1
	wfds(1) = ctx.hostSocket
	efds(0) = 1
	efds(1) = ctx.hostSocket
	nRet = selectsocket( 0, 0, wfds(0), efds(0), tv )

	if ( nRet = 0 ) then exit function

	if ( (nRet < 0) or (efds(0) <> 0) ) then
	   	ctx.state = SCC.OFFLINE
    	nRet = closesocket( ctx.hostSocket )
    	ctx.hostSocket = 0

	   	if ( efds(0) <> 0 ) then WSASetLastError WSAEHOSTUNREACH

	   	sccConnecting = -1
	   	exit function
	end if

	ctx.state = SCC.CONNECTED

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function sccConnect% ( server as string )
	dim nRet as integer
	dim port as integer, pHost as long, p as integer
	dim sa as sockaddrIn

	sccConnect = 0

	if ( (ctx.state <> SCC.OFFLINE) ) then
		print "[ERROR] sccConnect(): Already connected or connecting"
		exit function
	end if

	p = instr( server, ":" )
	if ( p > 0 ) then
		port = val( mid$( server, 1, p-1 ) )
		server = left$( server, p-1 )
	else
		port = SC.DEFPORT
	end if

	''
	'' Resolve host name
	''
	pHost = gethostbyname( server )
    if ( pHost = NULL ) then
        print "[ERROR] gethostbyname()"; WSAGetLastError
        exit function
    end if

	''
	'' Fill in the address structure
	''
	sa.sinfamily = AF.INET
	sa.sinaddr.saddr = hostent.hAddrList( pHost )
	sa.sinport = htons( port )

    ''
    '' Create a TCP/IP stream socket
    ''
    ctx.hostSocket = socket( AF.INET, SOCK.STREAM, IPPROTO.TCP )
    if ( ctx.hostSocket = INVALID.SOCKET ) then
        print "[ERROR] socket():"; WSAGetLastError
        sccConnect = -1
        exit function
    end if

    '' put socket in non-blocking mode
    if ( ioctlsocket( ctx.hostSocket, FIONBIO, 1 ) = SOCKET.ERROR ) then
    	print "[ERROR] ioctlsocket():"; WSAGetLastError
    	nRet = closesocket( ctx.hostSocket )
    	ctx.hostSocket = 0
    	sccConnect = -1
    	exit function
    end if

	nRet = connect( ctx.hostSocket, sa, len( sa ) )
	if ( nRet = SOCKET.ERROR ) then
		if ( WSAGetLastError <> WSAEWOULDBLOCK ) then
    		nRet = closesocket( ctx.hostSocket )
    		ctx.hostSocket = 0
    		sccConnect = -1
    		exit function
    	end if
	end if

	ctx.state = SCC.CONNECTING

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub sccDisconnect
	dim nRet as integer

	if ( ctx.hostSocket = 0 ) then exit sub

	if ( ctx.state = SCC.OFFLINE ) then
		print "[ERROR] sccDisconnect(): not connected"
		exit sub
	end if

	if ( ctx.hostSocket <> 0 ) then
		nRet = shutdown( ctx.hostSocket, 2 )
		nRet = closesocket( ctx.hostSocket )
		ctx.hostSocket = 0
	end if

	'' reinitialize queues
	userInit
	msgInit iMsgLst, iMsgTB(), SC.MAXMSGS
	msgInit oMsgLst, oMsgTB(), SC.MAXMSGS

	ctx.state = SCC.OFFLINE

	print "*** Disconnected"

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub sccUIProcess ( text as string )
	dim q as integer, u as integer
	dim tokenc as integer, tokenv(0 to 3) as string, tokenp(0 to 3) as integer
	dim cmdString as string
	dim nick as string * 8

const SCC.COMMANDS% = 6%

	text = ltrim$( rtrim$( text ) )

	'' process commands
	if ( left$( text, 1 ) = "/" ) then

		tokenize text, tokenc, tokenv(), tokenp(), 2

		select case ucase$( tokenv(0) )
			case "/QUIT"
				text = ""
				ctx.cmd = SCP.QUIT

			case "/JOIN"
				if ( ctx.nick = space$( SC.NICKLEN ) ) then
					print "*** Choose a nick first"
				else
					q = sccConnect( tokenv(1) )
				end if
			    exit sub

			''''''''''''''''''''''''''''
			case "/NICK"
				nick = space$( SC.NICKLEN )
				nick = tokenv(1)
				if ( ctx.state = SCC.ONLINE ) then
					ctx.cmd = SCP.NICK
					text = nick
				else
					ctx.nick = nick
					print "You are now known as "; ctx.nick
					exit sub
				end if

			''''''''''''''''''''''''''''
			case "/MSG"
            	nick = tokenv(1)
            	if ( tokenp(1) + len( tokenv(1) ) + 1 < len( text ) ) then
            		text = mid$( text, tokenp(1) + len( tokenv(1) ) + 1 )

            		if ( ctx.state = SCC.ONLINE ) then
            			print "-> [msg("; tokenv(1); ")] "; text
            		end if

            		text = nick + text
            		ctx.cmd = SCP.PRIV
            	else
            		exit sub
            	end if

			''''''''''''''''''''''''''''
			case "/CLEAR"
				cls 2
				exit sub

			''''''''''''''''''''''''''''
			case "/NAMES"
				print "*** Users:"
				u = userLst.head
				do while ( u <> -1 )
					print rtrim$( userTB(u).nick ); " ";
					u = userTB(u).nxt
				loop
				print
				exit sub

			''''''''''''''''''''''''''''
			case "/HELP"
				print "*** Commands:"
				restore sccCmdHelp
				for i = 1 to SCC.COMMANDS
					read cmdString
					print cmdString
				next i
				exit sub

			''''''''''''''''''''''''''''
			case else
				print "*** Unknow command"
				exit sub
		end select

	'' just pure text
	else
		ctx.cmd = SCP.TEXT
	end if

	if ( ctx.state <> SCC.ONLINE ) then
		print "*** Not connected"
		exit sub
	end if

	'' add to outcoming msg queue
	if ( (len( text ) > 0) or (ctx.cmd <> 0) ) then
		q = msgNew( oMsgLst, oMsgTB() )
		if ( q = -1 ) then exit sub
		oMsgAdd ( q ), len( text ), ctx.cmd, text
	end if

	exit sub

sccCmdHelp:
data "/quit"
data "/join <host> [<port>]"
data "/nick <nickname>"
data "/msg <to> <message>"
data "/clear"
data "/names"
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function sccUI%
	static firstRun as integer
	static users as integer, imsgs as integer, omsgs as integer, state as integer
	static text as string, tlen as long, nick as string * 8
	dim k as string, curRow as integer
	dim m as integer, u as integer, cmd as integer

	sccUI = 0

	curRow = csrlin
	view print

	'' update status bar
	if ( not firstRun ) then
		firstRun = -1
		users = -1
		omsgs = -1
		imsgs = -1
		state = -1
	end if

	if ( users <> userLst.items ) then
		users = userLst.items
		locate 25, 1
		print "U:"; users; "    ";
	end if

	if ( omsgs <> oMsgLst.items ) then
		omsgs = oMsgLst.items
		locate 25, 10
		print "O:"; omsgs; "    ";
	end if

	if ( imsgs <> iMsgLst.items ) then
		imsgs = iMsgLst.items
		locate 25, 20
		print "I:"; imsgs; "    ";
	end if

	if ( state <> ctx.state ) then
		state = ctx.state
		locate 25, 80 - ( len( sttTB(state) ) + 4 )
		print "     "; sttTB(state);
	end if

	view print 1 to 23: locate curRow, 1

	'' process input
	k = inkey$
	if ( len( k ) > 0 ) then
		select case asc( k )
			case 27							'' esc
				sccUI = -1

			case 8							'' backspc
				if ( len( text ) > 1 ) then
					text = left$( text, len( text ) - 1 )
				else
					text = ""
				end if

			case 13							'' enter
				if ( len( text ) > 0 ) then
					sccUIProcess text
					text = ""
				end if

			case 32 to 127
				if ( len( text ) < SC.MAXLEN ) then
					text = text + k
				end if
		end select
	end if

	'' print current message
	if ( tlen <> len( text ) ) then
		curRow = csrlin: view print
		tlen = len( text )
		locate 24, 1
		if ( len( text ) <= 80 ) then
			print text;
			if ( len( text ) <> 80 ) then print space$( 80 - len( text ) );
		else
			print right$( text, 80 );
		end if
		view print 1 to 23: locate curRow, 1
	end if


	'' show joins/quits/text
	m = iMsgLst.head
	do while ( m <> -1 )

		if ( iMsgTB(m).completed ) then
			select case iMsgTB(m).cmd

				''''''''''''''''''''''''''''
				case SCP.JOIN						'' <nick>
					print "*** Joins: "; left$( iMsgTB(m).msg, SC.NICKLEN )

				''''''''''''''''''''''''''''
            	case SCP.QUIT                       '' <nick>
                	print "*** Parts: "; left$( iMsgTB(m).msg, SC.NICKLEN )

				''''''''''''''''''''''''''''
				case SCP.TEXT						'' <nick><text>
					nick = left$( iMsgTB(m).msg, SC.NICKLEN )
					if ( nick <> ctx.nick ) then
						print "<"; rtrim$(nick); "> ";
					end if

					print mid$( iMsgTB(m).msg, 1+SC.NICKLEN, iMsgTB(m).length-SC.NICKLEN )

				''''''''''''''''''''''''''''
				case SCP.PRIV						'' <nick><text>
					print "*"; rtrim$(left$( iMsgTB(m).msg, SC.NICKLEN )); "* "; mid$( iMsgTB(m).msg, 1+SC.NICKLEN, iMsgTB(m).length-SC.NICKLEN )

				''''''''''''''''''''''''''''
				case SCP.NICK						'' <nick><newnick>
					nick = mid$( iMsgTB(m).msg, 1+SC.NICKLEN, SC.NICKLEN )
					u = userByNick( left$( iMsgTB(m).msg, SC.NICKLEN ) )
					print "*** "; rtrim$(userTB(u).nick); " is now known as "; nick

			end select
		end if

		m = iMsgTB(m).nxt
	loop


end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub sccProcess static
	dim i as integer, m as integer, n as integer, q as integer, u as integer
	dim cmd as integer, p as integer
	dim users as integer
	dim nick as string * 8, newnick as string * 8

	'' check states
	select case ctx.state
		case SCC.CONNECTING
			if ( sccConnecting ) then
				print "[ERROR] sccConnecting(): "; WSAGetLastError
				exit sub
			end if

		case SCC.CONNECTED
			q = msgNew( oMsgLst, oMsgTB() )
			if ( q <> -1 ) then
				oMsgAdd ( q ), SC.NICKLEN, SCP.JOIN, ctx.nick
        		ctx.state = SCC.JOINING
        	end if

        case SCC.JOINED
			q = msgNew( oMsgLst, oMsgTB() )
			if ( q <> -1 ) then
				oMsgAdd ( q ), 0, SCP.LIST, ""
        		ctx.state = SCC.ONLINE
        	end if

    end select


	m = iMsgLst.head
	do while ( m <> -1 )

		n = iMsgTB(m).nxt
		if ( iMsgTB(m).completed ) then

			select case iMsgTB(m).cmd

				''''''''''''''''''''''''''''
				case SCP.JOIN					'' <nick>
					nick = space$( SC.NICKLEN )
					nick = rtrim$( left$( iMsgTB(m).msg, SC.NICKLEN ) )

					if ( (ctx.state = SCC.JOINING) and (nick = ctx.nick) ) then
						 ctx.state = SCC.JOINED
					end if

					if ( userByNick( nick ) = -1 ) then
						if ( not userAdd( nick ) ) then
						end if
					end if

				''''''''''''''''''''''''''''
				case SCP.REFUSED				'' .
					print "*** Nick already in use"
					if ( ctx.state <> SCC.ONLINE ) then sccDisconnect


				''''''''''''''''''''''''''''
				case SCP.QUIT					'' <nick>
					u = userByNick( left$( iMsgTB(m).msg, SC.NICKLEN ) )
					if ( u <> -1 ) then userDel ( u )

				''''''''''''''''''''''''''''
				case SCP.LIST					'' <hexa-users><nicks list>
					users = val( "&h" + left$( iMsgTB(m).msg, 2 ) )
					p = 3
					do while ( users > 0 )
				    	nick = mid$( iMsgTB(m).msg, p, SC.NICKLEN )
				    	if ( userByNick( nick ) = -1 ) then
				    		if ( not userAdd( nick ) ) then
							end if
				    	end if

				    	p = p + SC.NICKLEN

				    	users = users - 1
					loop

				''''''''''''''''''''''''''''
				case SCP.TEXT						'' <nick><text>

				''''''''''''''''''''''''''''
				case SCP.PRIV						'' <nick><text>

				''''''''''''''''''''''''''''
				case SCP.NICK						'' <nick><newnick>
					nick = left$( iMsgTB(m).msg, SC.NICKLEN )
					newnick = mid$( iMsgTB(m).msg, 1+SC.NICKLEN, SC.NICKLEN )
					u = userByNick( nick )
					if ( u <> -1 ) then
						if ( nick = ctx.nick ) then
							ctx.nick = newnick
						end if
						userTB(u).nick = newnick
					end if

				''''''''''''''''''''''''''''
				case SCP.PING						'' .
					'' send: <PONG>
					q = msgNew( oMsgLst, oMsgTB() )
					if ( q = -1 ) then exit do
					oMsgAdd ( q ), 0, SCP.PONG, ""

			end select

			msgDel iMsgLst, iMsgTB(), ( m )
		end if

		m = n
	loop

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function sccSend%
    dim wfds(0 to 1) as long, efds(0 to 1) as long
	dim tv AS timeval
	dim nRet as integer, m as integer, i as integer
	dim buffer as string, buffaddr as long

	sccSend = 0

	if ( (oMsgLst.items = 0) ) then exit function

	if ( (ctx.state = SCC.OFFLINE) or (ctx.state = SCC.CONNECTING) ) then
		m = oMsgLst.head
		do while ( m <> -1 )
			i = oMsgTB(m).nxt
			msgDelHead oMsgLst, oMsgTB()
			m = i
		loop
		exit function
	end if


	tv.tvSec = 0: tv.tvUsec = 0

	wfds(0) = 1
	wfds(1) = ctx.hostSocket
    efds(0) = 1
    efds(1) = ctx.hostSocket
    nRet = selectsocket( 0, 0, wfds(0), efds(0), tv )

	if ( nRet = 0 ) then exit function

    if ( (nRet < 0) or (efds(0) <> 0) ) then
	   	sccSend = -1
	   	exit function
	end if

	m = oMsgLst.head
	do while ( m <> -1 )

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
		nRet = send( ctx.hostSocket, buffaddr, SCP.HDRLEN + length, 0 )

		if ( nRet = SOCKET.ERROR ) then
	   		sccSend = -1
	   		exit function
	   	end if

		nRet = nRet - SCP.HDRLEN
		if ( nRet >= 0 ) then oMsgTB(m).start = oMsgTB(m).start + nRet
		if ( oMsgTB(m).start < oMsgTB(m).length ) then exit do
		m = oMsgTB(m).nxt
		msgDelHead oMsgLst, oMsgTB()
	loop

	buffer = ""

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

		userTB(i).state = 0
		userTB(i).nick = string$( SC.NICKLEN, 32 )
	next i

	userTB(SC.MAXUSERS-1).prv = p
	userTB(SC.MAXUSERS-1).nxt = -1
end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function userNew% static
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

	userLst.items = userLst.items + 1

	userNew = i
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function userAdd% ( nick as string ) static
    dim u as integer

	u = userNew
	if ( u = -1	) then
		userAdd = 0
		exit function
	end if

	userTB(u).state = -1
	userTB(u).nick = nick

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

	userFree ( u )

	userTB(u).state = 0
	userTB(u).nick = string$( SC.NICKLEN, 32 )

end sub

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

		mTB(i).msg = string$( SC.MAXLEN, 32 )
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
	mTB(i).id = 1 + id

	mLst.items = mLst.items + 1

	msgNew = i
end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub oMsgAdd ( m as integer, length as integer, cmd as integer, message as string ) static

	oMsgTB(m).cmd 		= cmd
	oMsgTB(m).start		= 0
	oMsgTB(m).length 	= length
    if ( length > 0 ) then mid$( oMsgTB(m).msg, 1, length ) = message

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub iMsgAdd ( m as integer, id as integer, start as integer, _
			  length as integer, cmd as integer, completed as integer, _
              message as string ) static

	iMsgTB(m).id 		= id
	iMsgTB(m).start 	= start
	iMsgTB(m).length 	= length
	iMsgTB(m).completed = completed
	iMsgTB(m).cmd 		= cmd
	if ( length > 0 ) then mid$( iMsgTB(m).msg, 1+start ) = message

end sub

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub msgFree ( mLst as TLIST, mTB() as TMSG, m as integer ) static
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
function msgByID% ( mLst as TLIST, mTB() as TMSG, id as integer ) static
	dim i as integer

	i = mLst.head
	do while ( i <> -1 )
		if ( mTB(i).id = id ) then exit do
		i = mTB(i).nxt
	loop

	msgByID = i
end function

'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
'' misc routines
'':::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function hexaword$ ( num as integer ) static

    if ( num < 16 ) then
    	hexaword$ = "000" + hex$( num )
    elseif ( num < 256 ) then
    	hexaword$ = "00" + hex$( num )
    else
    	hexaword$ = hex$( num )
    end if

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
function hexabyte$ ( num as integer ) static

    if ( num < 16 ) then
    	hexabyte$ = "0" + hex$( num )
    else
    	hexabyte$ = hex$( num )
    end if

end function

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
sub tokenize ( text as string, tokenc as integer, tokenv() as string, tokenp() as integer, maxc as integer )
    dim cmd as string
    dim p as integer, char as integer, l as integer

	p = 1
	l = len( text )
	tokenc = 0

	do
		do
			char = asc( mid$( text, p, 1 ) )
			p = p + 1
			l = l - 1
		loop while ( ((char = 32) or (char = 7)) and (l > 0) )

		tokenp(tokenc) = p - 1
		if ( l = 0 ) then
            if ( (char <> 32) and (char <> 7) ) then
                tokenv(tokenc) = chr$( char )
                tokenc = tokenc + 1
            end if

            exit do
        end if

		do
			tokenv(tokenc) = tokenv(tokenc) + chr$( char )
			char = asc( mid$( text, p, 1 ) )
			p = p + 1
			l = l - 1
		loop until ( (char = 32) or (char = 7) or (l = 0) )

		if ( (char <> 32) and (char <> 7) ) then
			tokenv(tokenc) = tokenv(tokenc) + chr$( char )
		end if

		tokenc = tokenc + 1
	loop while ( (l > 0) and (tokenc < maxc) )
end sub

