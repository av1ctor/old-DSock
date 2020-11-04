''
'' This header file corresponds to version 1.1 of the Windows Sockets specification.
''
'' This file includes parts which are Copyright (c) 1982-1986 Regents
'' of the University of California.  All rights reserved.  The
'' Berkeley Software License Agreement specifies the terms and
'' conditions for redistribution.
''
''

''
'' Windows type/macro definitions needed
''
'' typedef unsigned long       DWORD;
'' typedef int                 BOOL;
'' typedef unsigned char       BYTE;
'' typedef unsigned short      WORD;

declare function MAKEWORD% (byval lsb as integer, byval msb as integer)
declare function MAKELONG& (byval lsw as integer, byval msw as integer)

const NULL%				=	0%
const FALSE%        	=	0%
const TRUE%             =	1%

''
'' Basic system type definitions, taken from the BSD file sys/types.h.
''
'' typedef unsigned char   u_char;
'' typedef unsigned short  u_short;
'' typedef unsigned long   u_int;		'' v1c: int to long
'' typedef unsigned long   u_long;

''
'' The new type to be used in all
'' instances which refer to sockets.
''
'' typedef u_int           SOCKET;

''
'' Select uses arrays of SOCKETs.  These macros manipulate such
'' arrays.  FD_SETSIZE may be defined by the user before including
'' this file, but the default here should be >= 64.
''
'' CAVEAT IMPLEMENTOR and USER: THESE MACROS AND TYPES MUST BE
'' INCLUDED IN WINSOCK.H EXACTLY AS SHOWN HERE.
''
const FDSETSIZE%      	=	64% * 4%

type fdSet
        fdCount			as long     	'' how many are SET?
        fdArray			as string * FDSETSIZE '' an array of SOCKETs
end type

'' for PDS and VBDOS:
''const FDSETSIZE%      	=	64%
''type fdSet
''		fdCount			as long     	'' how many are SET?
''		fdArray(FDSETSIZE) as long 		'' an array of SOCKETs
''end type

''
'' Structure used in select() call, taken from the BSD file sys/time.h.
''
type timeval
        tvSec			as long         '' seconds
        tvUsec			as long        	'' and microseconds
end type

''
'' Commands for ioctlsocket(),  taken from the BSD file fcntl.h.
''
''
'' Ioctl's have the command encoded in the lower word,
'' and the size of any in or out parameters in the upper
'' word.  The high 2 bits of the upper word are used
'' to encode the in/out status of the parameter; for now
'' we restrict parameters to at most 128 bytes.
''
const IOCPARM.MASK%		=	&h7f%       '' parameters must be < 128 bytes
const IOC.VOID&        	=	&h20000000& '' no parameters
const IOC.OUT&         	=	&h40000000& '' copy out parameters
const IOC.IN&          	=	&h80000000&	'' copy in parameters
const IOC.INOUT&       	=	IOC.IN or IOC.OUT
'' &h20000000 distinguishes new & old ioctl's

const FIONREAD&    		= 	1074030207&	'' get # bytes to read
const FIONBIO&    		= 	-2147195266&'' set/clear non-blocking i/o
const FIOASYNC&    		= 	-2147195267&'' set/clear async i/o
  
'' Socket I/O Controls
const SIOCSHIWAT&    	=   -2147192064&'' set high watermark
const SIOCGHIWAT&    	= 	1074033409&	'' get high watermark
const SIOCSLOWAT&    	= 	-2147192062&'' set low watermark
const SIOCGLOWAT&    	= 	1074033411&	'' get low watermark
const SIOCATMARK&    	= 	1074033415&	'' at oob mark?

    
''
'' Structures returned by network data base library, taken from the
'' BSD file netdb.h.  All addresses are supplied in host order, and
'' returned in network order (suitable for use in system calls).
''

type hostent
        hName			as long 		'' official name of host
        hAliases		as long   		'' alias list
        hAddrtype		as integer      '' host address type
        hLength			as integer      '' length of address
        hAddrList		as long 		'' list of addresses
end type

''
'' It is assumed here that a network number
'' fits in 32 bits.
''
type netent
        nName			as long         '' official name of net
        nAliases  		as long			'' alias list
        nAddrtype		as integer     	'' net address type
        nNet			as long         '' network #
end type

type servent
        sName			as long         '' official service name
        sAliases  		as long			'' alias list
        sPort			as integer      '' port #
        sProto          as long			'' protocol to use
end type

type protoent
        pName			as long         '' official protocol name
        pAliases  		as long			'' alias list
        pProto			as integer      '' protocol #
end type

''
'' Constants and structures defined by the internet system,
'' Per RFC 790, September 1981, taken from the BSD file netinet/in.h.
''

''
'' Protocols
''
const IPPROTO.IP%     	=	0%              '' dummy for IP
const IPPROTO.ICMP%     =	1%              '' control message protocol
const IPPROTO.GGP%      =	2%              '' gateway^2 (deprecated)
const IPPROTO.TCP%      =	6%              '' tcp
const IPPROTO.PUP%      =	12%             '' pup
const IPPROTO.UDP%      =	17%             '' user datagram protocol
const IPPROTO.IDP%      =	22%             '' xns idp
const IPPROTO.ND%       =	77%             '' UNOFFICIAL net disk proto

const IPPROTO.RAW%      =	255%            '' raw IP packet
const IPPROTO.MAX%      =	256%

''
'' Port/socket numbers: network standard functions
''
const IPPORT.ECHO%      =	7%
const IPPORT.DISCARD%   =	9%
const IPPORT.SYSTAT%    =	11%
const IPPORT.DAYTIME%   =	13%
const IPPORT.NETSTAT%   =	15%
const IPPORT.FTP%       =	21%
const IPPORT.TELNET%    =	23%
const IPPORT.SMTP%      =	25%
const IPPORT.TIMESERVER%=	37%
const IPPORT.NAMESERVER%=	42%
const IPPORT.WHOIS%     =	43%
const IPPORT.MTP%       =	57%

''
'' Port/socket numbers: host specific functions
''
const IPPORT.TFTP%      =	69%
const IPPORT.RJE%       =	77%
const IPPORT.FINGER%    =	79%
const IPPORT.TTYLINK%   =	87%
const IPPORT.SUPDUP%    =	95%

''
'' UNIX TCP sockets
''
const IPPORT.EXECSERVER%=	512%
const IPPORT.LOGINSERVER%=	513%
const IPPORT.CMDSERVER% =	514%
const IPPORT.EFSSERVER% =	520%

''
'' UNIX UDP sockets
''
const IPPORT.BIFFUDP%   =	512%
const IPPORT.WHOSERVER% =	513%
const IPPORT.ROUTESERVER%=	520%
                                        '' 520+1 also used

''
'' Ports < IPPORT.RESERVED are reserved for
'' privileged processes (e.g. root).
''
const IPPORT.RESERVED%	=	1024%

''
'' Link numbers
''
const IMPLINK.IP%       =	155%
const IMPLINK.LOWEXPER% =	156%
const IMPLINK.HIGHEXPER%=	158%

''
'' Internet address (old style... should be updated)
''
type inAddr
        Saddr			as	long
end type

''
'' Definitions of bits in internet address integers.
'' On subnets, the decomposition of addresses to host and net parts
'' is done according to subnet mask, not the masks here.
''
const IN.CLASSA.NET&    =	&hff000000&
const IN.CLASSA.NSHIFT% =	24%
const IN.CLASSA.HOST&   =	&h00ffffff&
const IN.CLASSA.MAX%    =	128%

const IN.CLASSB.NET&    =	&hffff0000&
const IN.CLASSB.NSHIFT% =	16%
const IN.CLASSB.HOST&   =	&h0000ffff&
const IN.CLASSB.MAX&    =	65536&

const IN.CLASSC.NET&   	=	&hffffff00&
const IN.CLASSC.NSHIFT% =	8%
const IN.CLASSC.HOST&   =	&h000000ff&

const INADDR.ANY&       =	&h00000000&
const INADDR.LOOPBACK&  =	&h7f000001&
const INADDR.BROADCAST& =	&hffffffff&
const INADDR.NONE&      =	&hffffffff&

''
'' Socket address, internet style.
''
type sockaddrIn
        sinFamily		as integer
        sinPort			as integer
        sinAddr			as inAddr
        sinZero			as string * 8
end type

const WSADESCRIPTIONLEN%=	256+1
const WSASYSSTATUSLEN%	=   128+1

type WSAData
        wVersion		as integer
        wHighVersion	as integer
        szDescription	as string * WSADESCRIPTIONLEN
        szSystemStatus	as string * WSASYSSTATUSLEN
        iMaxSockets		as integer
        iMaxUdpDg		as integer
        lpVendorInfo	as long
end type

''
'' Options for use with [gs]etsockopt at the IP level.
''
const IP.OPTIONS%     	=	1%   		'' set/get IP per-packet options
const IP.MULTICAST.IF%  =	2%          '' set/get IP multicast interface
const IP.MULTICAST.TTL% =	3%          '' set/get IP multicast timetolive
const IP.MULTICAST.LOOP%=	4%          '' set/get IP multicast loopback
const IP.ADD.MEMBERSHIP%=	5%          '' add  an IP group membership
const IP.DROP.MEMBERSHIP%=	6%          '' drop an IP group membership

const IP.DEFAULT.MULTICAST.TTL%=   1%   '' normally limit m'casts to 1 hop
const IP.DEFAULT.MULTICAST.LOOP%=  1%   '' normally hear sends if a member
const IP.MAX.MEMBERSHIPS%=        20%   '' per socket must fit in one mbuf

''
'' Argument structure for IP.ADD.MEMBERSHIP and IP.DROP.MEMBERSHIP.
''
type ipMreq
        imrMultiaddr	as inAddr  		'' IP multicast address of group
        imrInterface  	as inAddr		'' local IP address of interface
end type

''
'' Definitions related to sockets: types, address families, options,
'' taken from the BSD file sys/socket.h.
''

''
'' This is used instead of -1, since the
'' SOCKET type is unsigned.
''
const INVALID.SOCKET&  	= 	-1&
const SOCKET.ERROR%		= 	-1%

''
'' Types
''
const SOCK.STREAM%     	=	1%          '' stream socket
const SOCK.DGRAM%      	=	2%          '' datagram socket
const SOCK.RAW%        	=	3%          '' raw-protocol interface
const SOCK.RDM%        	=	4%          '' reliably-delivered message
const SOCK.SEQPACKET%  	=	5%        	'' sequenced packet stream

''
'' Option flags per-socket.
''
const SO.DEBUG%        	=	&h0001%   	'' turn on debugging info recording
const SO.ACCEPTCONN%   	=	&h0002%     '' socket has had listen()
const SO.REUSEADDR%    	=	&h0004%     '' allow local address reuse
const SO.KEEPALIVE%    	=	&h0008%     '' keep connections alive
const SO.DONTROUTE%    	=	&h0010%     '' just use interface addresses
const SO.BROADCAST%    	=	&h0020%     '' permit sending of broadcast msgs
const SO.USELOOPBACK%  	=	&h0040%     '' bypass hardware when possible
const SO.LINGER%       	=	&h0080%     '' linger on close if data present
const SO.OOBINLINE%    	=	&h0100%     '' leave received OOB data in line

const SO.DONTLINGER%	=	not SO.LINGER%

''
'' Additional options.
''
const SO.SNDBUF%       	=	&h1001%     '' send buffer size
const SO.RCVBUF%       	=	&h1002%     '' receive buffer size
const SO.SNDLOWAT%     	=	&h1003%     '' send low-water mark
const SO.RCVLOWAT%     	=	&h1004%     '' receive low-water mark
const SO.SNDTIMEO%     	=	&h1005%     '' send timeout
const SO.RCVTIMEO%     	=	&h1006%     '' receive timeout
const SO.ERROR%        	=	&h1007%     '' get error status and clear
const SO.TYPE%         	=	&h1008%   	'' get socket type

''
'' Options for connect and disconnect data and options.  Used only by
'' non-TCP/IP transports such as DECNet, OSI TP4, etc.
''
const SO.CONNDATA%     	=	&h7000%
const SO.CONNOPT%      	=	&h7001%
const SO.DISCDATA%     	=	&h7002%
const SO.DISCOPT%      	=	&h7003%
const SO.CONNDATALEN%  	=	&h7004%
const SO.CONNOPTLEN%   	=	&h7005%
const SO.DISCDATALEN%  	=	&h7006%
const SO.DISCOPTLEN%   	=	&h7007%

''
'' Option for opening sockets for synchronous access.
''
const SO.OPENTYPE%     	=	&h7008%

const SO.SYNCHRONOUS.ALERT%=  	&h10%
const SO.SYNCHRONOUS.NONALERT%= &h20%

''
'' Other NT-specific options.
''
const SO.MAXDG%        	=	&h7009%
const SO.MAXPATHDG%    	=	&h700A%

''
'' TCP options.
''
const TCP.NODELAY%     	=	&h0001%
const TCP.BSDURGENT%   	=	&h7000%

''
'' Address families.
''
const AF.UNSPEC%      	=	0%         	'' unspecified
const AF.UNIX%        	=	1%          '' local to host (pipes, portals)
const AF.INET%         	=	2%          '' internetwork: UDP, TCP, etc.
const AF.IMPLINK%      	=	3%          '' arpanet imp addresses
const AF.PUP%          	=	4%          '' pup protocols: e.g. BSP
const AF.CHAOS%        	=	5%          '' mit CHAOS protocols
const AF.IPX%          	=	6%          '' IPX and SPX
const AF.NS%           	=	6%          '' XEROX NS protocols
const AF.ISO%          	=	7%          '' ISO protocols
const AF.OSI%          	=	AF.ISO      '' OSI is ISO
const AF.ECMA%         	=	8%          '' european computer manufacturers
const AF.DATAKIT%      	=	9%          '' datakit protocols
const AF.CCITT%        	=	10%         '' CCITT protocols, X.25 etc
const AF.SNA%          	=	11%         '' IBM SNA
const AF.DECnet%       	=	12%         '' DECnet
const AF.DLI%          	=	13%         '' Direct data link interface
const AF.LAT%          	=	14%         '' LAT
const AF.HYLINK%       	=	15%         '' NSC Hyperchannel
const AF.APPLETALK%    	=	16%         '' AppleTalk
const AF.NETBIOS%      	=	17%         '' NetBios-style addresses

const AF.MAX%          	=	18%

''
'' Structure used by kernel to store most
'' addresses.
''
type sockaddr
        saFamily		as integer		'' address family
        saData			as string * 14	'' up to 14 bytes of direct address
end type

''
'' Structure used by kernel to pass protocol
'' information in raw sockets.
''
type sockproto
        spFamily		as integer     	'' address family
        spProtocol      as integer      '' protocol
end type

''
'' Protocol families, same as address families for now.
''
const PF.UNSPEC%       	= 	AF.UNSPEC
const PF.UNIX%         	= 	AF.UNIX
const PF.INET%         	= 	AF.INET
const PF.IMPLINK%      	= 	AF.IMPLINK
const PF.PUP%          	= 	AF.PUP
const PF.CHAOS%        	= 	AF.CHAOS
const PF.NS%           	= 	AF.NS
const PF.IPX%          	= 	AF.IPX
const PF.ISO%          	= 	AF.ISO
const PF.OSI%          	= 	AF.OSI
const PF.ECMA%         	= 	AF.ECMA
const PF.DATAKIT%      	= 	AF.DATAKIT
const PF.CCITT%        	= 	AF.CCITT
const PF.SNA%          	= 	AF.SNA
const PF.DECnet%       	= 	AF.DECnet
const PF.DLI%          	= 	AF.DLI
const PF.LAT%          	= 	AF.LAT
const PF.HYLINK%       	= 	AF.HYLINK
const PF.APPLETALK%    	= 	AF.APPLETALK

const PF.MAX%			= 	AF.MAX

''
'' Structure used for manipulating linger option.
''
type linger
        lOnoff			as integer      '' option on/off
        lLinger         as integer   	'' linger time
end type

''
'' Level number for (get/set)sockopt() to apply to socket itself.
''
const SOL.SOCKET%		=	&hffff   	'' options for socket level

''
'' Maximum queue length specifiable by listen.
''
const SOMAXCONN%       	=	5%

const MSG.OOB%         	=	&h1%        '' process out-of-band data
const MSG.PEEK%        	=	&h2%        '' peek at incoming message
const MSG.DONTROUTE%   	=	&h4%        '' send without using routing tables

const MSG.MAXIOVLEN%   	=	16%

const MSG.PARTIAL%     	=	&h8000%    	'' partial send or recv for message xport

''
'' Define constant based on rfc883, used by gethostbyxxxx() calls.
''
const MAXGETHOSTSTRUCT%	=	1024%

''
'' Define flags to be used with the WSAAsyncSelect() call.
''
const FD.READ%         	=	&h01%
const FD.WRITE%        	=	&h02%
const FD.OOB%          	=	&h04%
const FD.ACCEPT%       	=	&h08%
const FD.CONNECT%      	=	&h10%
const FD.CLOSE%        	=	&h20%

''
'' All Windows Sockets error constants are biased by WSABASEERR from
'' the "normal"
''
const WSABASEERR%       =	10000%
''
'' Windows Sockets definitions of regular Microsoft C error constants
''
const WSAEINTR%			=	WSABASEERR+4%
const WSAEBADF%			=	WSABASEERR+9%
const WSAEACCES%		=	WSABASEERR+13%
const WSAEFAULT%		=	WSABASEERR+14%
const WSAEINVAL%		=	WSABASEERR+22%
const WSAEMFILE%		=	WSABASEERR+24%

''
'' Windows Sockets definitions of regular Berkeley error constants
''
const WSAEWOULDBLOCK%	=	WSABASEERR+35%
const WSAEINPROGRESS%	=	WSABASEERR+36%
const WSAEALREADY%		=	WSABASEERR+37%
const WSAENOTSOCK%		=	WSABASEERR+38%
const WSAEDESTADDRREQ%	=	WSABASEERR+39%
const WSAEMSGSIZE%		=	WSABASEERR+40%
const WSAEPROTOTYPE%	=	WSABASEERR+41%
const WSAENOPROTOOPT%	=	WSABASEERR+42%
const WSAEPROTONOSUPPORT%=	WSABASEERR+43%
const WSAESOCKTNOSUPPORT%=	WSABASEERR+44%
const WSAEOPNOTSUPP%	=	WSABASEERR+45%
const WSAEPFNOSUPPORT%	=	WSABASEERR+46%
const WSAEAFNOSUPPORT%	=	WSABASEERR+47%
const WSAEADDRINUSE%	=	WSABASEERR+48%
const WSAEADDRNOTAVAIL%	=	WSABASEERR+49%
const WSAENETDOWN%		=	WSABASEERR+50%
const WSAENETUNREACH%	=	WSABASEERR+51%
const WSAENETRESET%		=	WSABASEERR+52%
const WSAECONNABORTED%	=	WSABASEERR+53%
const WSAECONNRESET%	=	WSABASEERR+54%
const WSAENOBUFS%		=	WSABASEERR+55%
const WSAEISCONN%		=	WSABASEERR+56%
const WSAENOTCONN%		=	WSABASEERR+57%
const WSAESHUTDOWN%		=	WSABASEERR+58%
const WSAETOOMANYREFS%	=	WSABASEERR+59%
const WSAETIMEDOUT%		=	WSABASEERR+60%
const WSAECONNREFUSED%	=	WSABASEERR+61%
const WSAELOOP%			=	WSABASEERR+62%
const WSAENAMETOOLONG%	=	WSABASEERR+63%
const WSAEHOSTDOWN%		=	WSABASEERR+64%
const WSAEHOSTUNREACH%	=	WSABASEERR+65%
const WSAENOTEMPTY%		=	WSABASEERR+66%
const WSAEPROCLIM%		=	WSABASEERR+67%
const WSAEUSERS%		=	WSABASEERR+68%
const WSAEDQUOT%		=	WSABASEERR+69%
const WSAESTALE%		=	WSABASEERR+70%
const WSAEREMOTE%		=	WSABASEERR+71%

const WSAEDISCON%		=	WSABASEERR+101%

''
'' Extended Windows Sockets error constant definitions
''
const WSASYSNOTREADY%	=	WSABASEERR+91%
const WSAVERNOTSUPPORTED%=	WSABASEERR+92%
const WSANOTINITIALISED%=	WSABASEERR+93%

''
'' Error return codes from gethostbyname() and gethostbyaddr()
'' (when using the resolver). Note that these errors are
'' retrieved via WSAGetLastError() and must therefore follow
'' the rules for avoiding clashes with error numbers from
'' specific implementations or language run-time systems.
'' For this reason the codes are based at WSABASEERR+1001.
'' Note also that [WSA]NO_ADDRESS is defined only for
'' compatibility purposes.
''

'' Authoritative Answer: Host not found
const WSAHOST.NOT.FOUND%=	WSABASEERR+1001%
const HOST.NOT.FOUND%   =	WSAHOST.NOT.FOUND

'' Non-Authoritative: Host not found, or SERVERFAIL
const WSATRY.AGAIN%		=	WSABASEERR+1002%
const TRY.AGAIN%        =	WSATRY.AGAIN

'' Non recoverable errors, FORMERR, REFUSED, NOTIMP
const WSANO.RECOVERY%	=	WSABASEERR+1003%
const NO.RECOVERY%      =	WSANO.RECOVERY

'' Valid name, no data record of requested type
const WSANO.DATA%		=	WSABASEERR+1004%
const NO.DATA%          =	WSANO.DATA

'' no address, look for MX record
const WSANO.ADDRESS%	=	WSANO.DATA
const NO.ADDRESS%       =	WSANO.ADDRESS

''
'' Windows Sockets errors redefined as regular Berkeley error constants.
'' These are commented out in Windows NT to avoid conflicts with errno.h.
'' Use the WSA constants instead.
''

'' const EWOULDBLOCK	=	WSAEWOULDBLOCK
'' const EINPROGRESS	=	WSAEINPROGRESS
'' const EALREADY		=	WSAEALREADY
'' const ENOTSOCK		=	WSAENOTSOCK
'' const EDESTADDRREQ	=	WSAEDESTADDRREQ
'' const EMSGSIZE		=	WSAEMSGSIZE
'' const EPROTOTYPE		=	WSAEPROTOTYPE
'' const ENOPROTOOPT	=	WSAENOPROTOOPT
'' const EPROTONOSUPPORT=	WSAEPROTONOSUPPORT
'' const ESOCKTNOSUPPORT=	WSAESOCKTNOSUPPORT
'' const EOPNOTSUPP		=	WSAEOPNOTSUPP
'' const EPFNOSUPPORT	=	WSAEPFNOSUPPORT
'' const EAFNOSUPPORT	=	WSAEAFNOSUPPORT
'' const EADDRINUSE		=	WSAEADDRINUSE
'' const EADDRNOTAVAIL	=	WSAEADDRNOTAVAIL
'' const ENETDOWN		=	WSAENETDOWN
'' const ENETUNREACH	=	WSAENETUNREACH
'' const ENETRESET		=	WSAENETRESET
'' const ECONNABORTED	=	WSAECONNABORTED
'' const ECONNRESET		=	WSAECONNRESET
'' const ENOBUFS		=	WSAENOBUFS
'' const EISCONN		=	WSAEISCONN
'' const ENOTCONN		=	WSAENOTCONN
'' const ESHUTDOWN		=	WSAESHUTDOWN
'' const ETOOMANYREFS	=	WSAETOOMANYREFS
'' const ETIMEDOUT		=	WSAETIMEDOUT
'' const ECONNREFUSED	=	WSAECONNREFUSED
'' const ELOOP			=	WSAELOOP
'' const ENAMETOOLONG	=	WSAENAMETOOLONG
'' const EHOSTDOWN		=	WSAEHOSTDOWN
'' const EHOSTUNREACH	=	WSAEHOSTUNREACH
'' const ENOTEMPTY		=	WSAENOTEMPTY
'' const EPROCLIM		=	WSAEPROCLIM
'' const EUSERS			=	WSAEUSERS
'' const EDQUOT			=	WSAEDQUOT
'' const ESTALE			=	WSAESTALE
'' const EREMOTE		=	WSAEREMOTE

''
'' Socket function prototypes
''

declare function accept&				(byval s as long, _
								 	 	 seg addr as any, _
                          		 	 	 seg addrlen as integer)

declare function bind%					(byval s as long, _
								 	 	 seg addr as any, _
								 	 	 byval namelen as integer)

declare function closesocket% 			(byval s as long)

declare function connect% 				(byval s as long, _
									 	 seg connname as any, _
									 	 byval namelen as integer)

declare function ioctlsocket%			(byval s as long, _
									 	 byval cmd as long, _
									 	 seg argp as long)

declare function getpeername%			(byval s as long, _
									 	 seg peername as any, _
                            		 	 seg namelen as integer)

declare function getsockname%			(byval s as long, _
									 	 seg sockname as any, _
                            		 	 seg namelen as integer)

declare function getsockopt%			(byval s as long, _
									 	 byval level as integer, _
									 	 byval optname as integer, _
									 	 seg optval as any, _
									 	 seg optlen as integer)

declare function htonl& 				(byval hostlong as long)

declare function htons% 				(byval hostshort as integer)

declare function inetAddr& 				alias "inet_addr" _
										(cp as string)

declare function inetNtoa$ 				alias "inet_ntoa" _
										(byval inAddress as long)

declare function listen%				(byval s as long, _
									 	 byval backlog as integer)

declare function ntohl&					(byval netlong as long)

declare function ntohs%					(byval netshort as integer)

declare function recv% 					(byval s as long, _
									 	 byval buf as long, _
									 	 byval length as integer, _
									 	 byval flags as integer)

declare function recvfrom% 				(byval s as long, _
									 	 byval buf as long, _
									 	 byval length as integer, _
									 	 byval flags as integer, _
									 	 seg from as any, _
									 	 seg fromlen as integer)

declare function selectsocket%			alias "select" _
										(byval nfds as integer, _
									 	 seg readfds as long, _
									 	 seg writefds as long, _
									 	 seg exceptfds as long, _
									 	 seg timeout as timeval)

declare function selectsocketEx%		alias "select" _
										(byval nfds as integer, _
									 	 seg readfds as fdSet, _
									 	 seg writefds as fdSet, _
									 	 seg exceptfds as fdSet, _
									 	 seg timeout as timeval)

declare function send% 					(byval s as long, _
									 	 byval buf as long, _
									 	 byval length as integer, _
									 	 byval flags as integer)

declare function sendto%				(byval s as long, _
									 	 byval buf as long, _
									 	 byval length as integer, _
									 	 byval flags as integer, _
                       				 	 seg toaddr as any, _
                       				 	 byval tolen as integer)

declare function setsockopt%			(byval s as long, _
									 	 byval level as integer, _
									 	 byval optname as integer, _
                           			 	 seg optval as any, _
                           			 	 byval optlen as integer)

declare function shutdown% 				(byval s as long, _
									 	 byval how as integer)

declare function socket& 				(byval addrfamily as integer, _
									 	 byval socktype as integer, _
									 	 byval protocol as integer)

'' Database function prototypes

declare function gethostbyaddr& 		(seg addr as any, _
                                         byval length as integer, _
                                         byval addrtype as integer)

declare function gethostbyname& 		(hname as string)

declare function gethostname%			(hname as string, _
									 	 byval namelen as integer)

declare function getservbyport& 		(byval port as integer, _
										 proto as string)

declare function getservbyname& 		(sname as string, _
                                         proto as string)

declare function getprotobynumber& 		(byval proto as integer)

declare function getprotobyname& 		(pname as string)

'' Microsoft Windows Extension function prototypes

declare function WSAStartup%			(byval wVersionRequired as integer, _
									 	 seg lpWSAData as WSaData)

declare function WSACleanup% 			()

declare sub 	 WSASetLastError		(byval iError as integer)

declare function WSAGetLastError%		()

declare function WSAAsyncSelect%		(byval s as long, _
										 byval Callback as long, _
										 byval wMsg as long, _
                              			 byval lEvent as long)

''
'' Windows message parameter composition and decomposition
'' macros.
''
'' WSAGETSELECTEVENT is intended for use by the Windows Sockets application
'' to extract the event code from the lParam in the response
'' to a WSAAsyncSelect().
''
declare function WSAGETSELECTEVENT% (byval lParam as long)
''
'' WSAGETSELECTERROR is intended for use by the Windows Sockets application
'' to extract the error code from the lParam in the response
'' to a WSAAsyncSelect().
''
declare function WSAGETSELECTERROR% (byval lParam as long)


declare function hostent.hName$		alias "hent_name" 	(byval entry as long)
declare function hostent.hAliases$	alias "hent_alias"	(byval entry as long)
declare function hostent.hAddrtype%	alias "hent_type" 	(byval entry as long)
declare function hostent.hLength%	alias "hent_len"  	(byval entry as long)
declare function hostent.hAddrList&	alias "hent_addr" 	(byval entry as long)

declare function servent.sName$		alias "hent_name" 	(byval entry as long)
declare function servent.sAliases$	alias "hent_alias"	(byval entry as long)
declare function servent.sPort%		alias "sent_port" 	(byval entry as long)
declare function servent.sProto$	alias "sent_proto"	(byval entry as long)

declare function protoent.pName$	alias "hent_name"	(byval entry as long)
declare function protoent.pAliases$	alias "hent_alias"	(byval entry as long)
declare function protoent.pProto%	alias "pent_proto"	(byval entry as long)

