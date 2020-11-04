defint a-z
'$include: '..\..\inc\dsock.bi'

''''''''
    dim wsaDat as WSAData
	dim wVersionRequested as integer
	dim nRet as integer

	''
	'' Initialize WinSock.dll
	''
	wVersionRequested = MAKEWORD( 1, 1 )

	nRet = WSAStartup( wVersionRequested, wsaDat )
	if ( nRet <> 0 ) then
		print "WSAStartup():"; nRet
		nRet = WSACleanup
        end
	end if

	''
	'' Check WinSock version
	''
	if ( wsaDat.wVersion <> wVersionRequested ) then
		print "WinSock version not supported"
		nRet = WSACleanup
        end
	end if

    ''
    ''
    ''
    dim lpHostEntry as long
    dim hostName as string
    hostName = space$( 32 )

    if ( gethostname( hostName, len( hostName ) ) = SOCKET.ERROR ) then
        print "gethostname():"; WSAGetLastError
		nRet = WSACleanup
        end
    end if

    lpHostEntry = gethostbyname( hostName )
    if ( lpHostEntry = NULL ) then
        print "gethostbyname():"; WSAGetLastError
		nRet = WSACleanup
        end
    end if

    print "ip: "; inetNtoa( hostent.hAddrList( lpHostEntry ) )

    ''
	'' Release WinSock
	''
	nRet = WSACleanup
    end


