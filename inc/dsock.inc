(*
 * This header file corresponds to version 1.1 of the Windows Sockets specification.
 *
 * This file includes parts which are Copyright (c) 1982-1986 Regents
 * of the University of California.  All rights reserved.  The
 * Berkeley Software License Agreement specifies the terms and
 * conditions for redistribution.
 *
 *)

{$IFNDEF _WINSOCKAPI_}
{$DEFINE _WINSOCKAPI_}

const
	NULL			= nil;

type
    u_char 			= char;
    u_short 		= word;
    u_int 			= longint;
    u_long 			= longint;

    TSocket 		= u_int;

const
    FD_SETSIZE		= 64;

type
    fd_set = record
		fd_count    : u_short;
		fd_array	: array[0..FD_SETSIZE-1] of TSocket;
    end;

    timeval = record
		tv_sec,
		tv_usec		: longint;
    end;

const
    IOCPARM_MASK   	= $007f;
    IOC_VOID       	= $20000000;
    IOC_OUT        	= $40000000;
    IOC_IN         	= $80000000;
    IOC_INOUT      	= (IOC_IN OR IOC_OUT);

    FIONREAD    	= 1074030207;	{ get # bytes to read }
    FIONBIO    		= -2147195266;	{ set/clear non-blocking i/o }
    FIOASYNC    	= -2147195267;	{ set/clear async i/o }

    { Socket I/O Controls }
    SIOCSHIWAT    	= -2147192064;	{ set high watermark }
    SIOCGHIWAT    	= 1074033409;	{ get high watermark }
    SIOCSLOWAT    	= -2147192062;	{ set low watermark }
    SIOCGLOWAT    	= 1074033411;	{ get low watermark }
    SIOCATMARK    	= 1074033415;	{ at oob mark? }

type
    SunB = record
		s_b1,
		s_b2,
		s_b3,
		s_b4		: u_char;
    end;

    SunW = record
		s_w1,
		s_w2		: u_short;
    end;

    LPIN_ADDR 		= ^in_addr;
    in_addr = record
		case integer of
		0			: (S_un_b: SunB);
        1			: (S_un_w: SunW);
        2			: (S_addr: u_long);
    end;


    hostent = record
		h_name		: PChar;
		h_aliases	: ^PChar;
		h_addrtype	: word;
		h_length	: word;
		h_addr_list	: ^LPIN_ADDR;
    end;

    netent = record
		n_name		: PChar;
		n_aliases	: ^PChar;
		n_addrtype	: word;
		n_net		: u_long;
    end;

    servent = record
		s_name		: PChar;
		s_aliases	: ^PChar;
		s_port		: word;
		s_proto		: PChar;
    end;

    protoent = record
		p_name		: PChar;
		p_aliases	: ^Pchar;
		p_proto		: word;
    end;

const
	IPPROTO_IP     	= 0;
    IPPROTO_ICMP   	= 1;
    IPPROTO_GGP    	= 2;
    IPPROTO_TCP    	= 6;
    IPPROTO_PUP    	= 12;
    IPPROTO_UDP    	= 17;
    IPPROTO_IDP    	= 22;
    IPPROTO_ND     	= 77;

    IPPROTO_RAW    	= 255;
    IPPROTO_MAX    	= 256;


    IPPORT_ECHO    		= 7;
    IPPORT_DISCARD 		= 9;
    IPPORT_SYSTAT  		= 11;
    IPPORT_DAYTIME 		= 13;
    IPPORT_NETSTAT 		= 15;
    IPPORT_FTP     		= 21;
    IPPORT_TELNET  		= 23;
    IPPORT_SMTP    		= 25;
    IPPORT_TIMESERVER	= 37;
    IPPORT_NAMESERVER	= 42;
    IPPORT_WHOIS    	= 43;
    IPPORT_MTP      	= 57;

    IPPORT_TFTP    		= 69;
    IPPORT_RJE      	= 77;
    IPPORT_FINGER   	= 79;
    IPPORT_TTYLINK  	= 87;
    IPPORT_SUPDUP   	= 95;

    IPPORT_EXECSERVER	= 512;
    IPPORT_LOGINSERVER 	= 513;
    IPPORT_CMDSERVER   	= 514;
    IPPORT_EFSSERVER   	= 520;

    IPPORT_BIFFUDP     	= 512;
    IPPORT_WHOSERVER   	= 513;
    IPPORT_ROUTESERVER 	= 520;

    IPPORT_RESERVED		= 1024;

    IMPLINK_IP         	= 155;
    IMPLINK_LOWEXPER   	= 156;
    IMPLINK_HIGHEXPER  	= 158;

const
(*
 * Definitions of bits in internet address integers.
 * On subnets, the decomposition of addresses to host and net parts
 * is done according to subnet mask, not the masks here.
 *)
	IN_CLASSA_NET		= $ff000000;
	IN_CLASSA_NSHIFT    = 24;
	IN_CLASSA_HOST      = $00ffffff;
	IN_CLASSA_MAX       = 128;

	IN_CLASSB_NET       = $ffff0000;
	IN_CLASSB_NSHIFT    = 16;
	IN_CLASSB_HOST      = $0000ffff;
	IN_CLASSB_MAX       = 65536;

	IN_CLASSC_NET       = $ffffff00;
	IN_CLASSC_NSHIFT    = 8;
	IN_CLASSC_HOST      = $000000ff;

	INADDR_ANY          = $00000000;
	INADDR_LOOPBACK     = $7f000001;
	INADDR_BROADCAST    = $ffffffff;
	INADDR_NONE         = $ffffffff;


type
    sockaddr_in = record
		sin_family 	: integer;
        sin_port 	: u_short;
        sin_addr 	: in_addr;
        sin_zero 	: array[0..7] of char;
    end;

const
    WSADESCRIPTION_LEN = 256;
    WSASYS_STATUS_LEN  = 128;

type
    LPWSADATA = ^WSAData;
    WSAData = record
		wVersion 		: word;
        wHighVersion 	: word;
        szDescription 	: array[0..WSADESCRIPTION_LEN] of char;
        szSystemStatus 	: array[0..WSASYS_STATUS_LEN] of char;
        iMaxSockets		: integer;
        iMaxUdpDg 		: integer;
        lpVendorInfo 	: PChar;
    end;

const
	IP_OPTIONS  	= 1;

    INVALID_SOCKET 	= NOT(0);
    SOCKET_ERROR   	= -1;

    SOCK_STREAM    	= 1;
    SOCK_DGRAM     	= 2;
    SOCK_RAW       	= 3;
    SOCK_RDM       	= 4;
    SOCK_SEQPACKET 	= 5;

    SO_DEBUG       	= $0001;
    SO_ACCEPTCONN  	= $0002;
    SO_REUSEADDR   	= $0004;
    SO_KEEPALIVE   	= $0008;
    SO_DONTROUTE   	= $0010;
    SO_BROADCAST   	= $0020;
    SO_USELOOPBACK 	= $0040;
    SO_LINGER      	= $0080;
    SO_OOBINLINE   	= $0100;

    SO_DONTLINGER  	= $ff7f;

    SO_SNDBUF      	= $1001;
    SO_RCVBUF      	= $1002;
    SO_SNDLOWAT    	= $1003;
    SO_RCVLOWAT    	= $1004;
    SO_SNDTIMEO    	= $1005;
    SO_RCVTIMEO    	= $1006;
    SO_ERROR       	= $1007;
    SO_TYPE        	= $1008;

    AF_UNSPEC      	= 0;
    AF_UNIX        	= 1;
    AF_INET        	= 2;
    AF_IMPLINK     	= 3;
    AF_PUP         	= 4;
    AF_CHAOS       	= 5;
    AF_NS          	= 6;
    AF_NBS         	= 7;
    AF_ECMA        	= 8;
    AF_DATAKIT     	= 9;
    AF_CCITT       	= 10;
    AF_SNA         	= 11;
    AF_DECnet      	= 12;
    AF_DLI         	= 13;
    AF_LAT         	= 14;
    AF_HYLINK      	= 15;
    AF_APPLETALK   	= 16;

    AF_MAX         	= 17;

type
    sockaddr = record
		sa_family 	: u_short;
        sa_data 	: array[0..13] of char;
    end;

    sockproto = record
		sp_family 	: u_short;
        sp_protocol : u_short;
    end;

const
    PF_UNSPEC      	= AF_UNSPEC;
    PF_UNIX        	= AF_UNIX;
    PF_INET        	= AF_INET;
    PF_IMPLINK     	= AF_IMPLINK;
    PF_PUP         	= AF_PUP;
    PF_CHAOS       	= AF_CHAOS;
    PF_NS          	= AF_NS;
    PF_NBS         	= AF_NBS;
    PF_ECMA        	= AF_ECMA;
    PF_DATAKIT     	= AF_DATAKIT;
    PF_CCITT       	= AF_CCITT;
    PF_SNA         	= AF_SNA;
    PF_DECnet      	= AF_DECnet;
    PF_DLI         	= AF_DLI;
    PF_LAT         	= AF_LAT;
    PF_HYLINK      	= AF_HYLINK;
    PF_APPLETALK   	= AF_APPLETALK;

    PF_MAX         	= AF_MAX;

type
    linger = record
		l_onoff 	: u_short;
        l_linger 	: u_short;
    end;

const
    SOL_SOCKET     	= $ffff;

    SOMAXCONN      	= 5;

    MSG_OOB        	= $1;
    MSG_PEEK       	= $2;
    MSG_DONTROUTE  	= $4;

    MSG_MAXIOVLEN  	= 16;

    MAXGETHOSTSTRUCT   =  1024;

    FD_READ         = $01;
    FD_WRITE        = $02;
    FD_OOB          = $04;
    FD_ACCEPT       = $08;
    FD_CONNECT      = $10;
    FD_CLOSE       	= $20;


    WSABASEERR     		= 10000;

    WSAEINTR           	= (WSABASEERR + 4);
    WSAEBADF           	= (WSABASEERR + 9);
    WSAEFAULT          	= (WSABASEERR + 14);
    WSAEINVAL          	= (WSABASEERR + 22);
    WSAEMFILE          	= (WSABASEERR + 24);

    WSAEWOULDBLOCK     	= (WSABASEERR + 35);
    WSAEINPROGRESS     	= (WSABASEERR + 36);
    WSAEALREADY        	= (WSABASEERR + 37);
    WSAENOTSOCK        	= (WSABASEERR + 38);
    WSAEDESTADDRREQ    	= (WSABASEERR + 39);
    WSAEMSGSIZE        	= (WSABASEERR + 40);
    WSAEPROTOTYPE      	= (WSABASEERR + 41);
    WSAENOPROTOOPT     	= (WSABASEERR + 42);
    WSAEPROTONOSUPPORT 	= (WSABASEERR + 43);
    WSAESOCKTNOSUPPORT 	= (WSABASEERR + 44);
    WSAEOPNOTSUPP      	= (WSABASEERR + 45);
    WSAEPFNOSUPPORT    	= (WSABASEERR + 46);
    WSAEAFNOSUPPORT    	= (WSABASEERR + 47);
    WSAEADDRINUSE      	= (WSABASEERR + 48);
    WSAEADDRNOTAVAIL   	= (WSABASEERR + 49);
    WSAENETDOWN        	= (WSABASEERR + 50);
    WSAENETUNREACH     	= (WSABASEERR + 51);
    WSAENETRESET       	= (WSABASEERR + 52);
    WSAECONNABORTED    	= (WSABASEERR + 53);
    WSAECONNRESET      	= (WSABASEERR + 54);
    WSAENOBUFS         	= (WSABASEERR + 55);
    WSAEISCONN         	= (WSABASEERR + 56);
    WSAENOTCONN        	= (WSABASEERR + 57);
    WSAESHUTDOWN       	= (WSABASEERR + 58);
    WSAETOOMANYREFS    	= (WSABASEERR + 59);
    WSAETIMEDOUT       	= (WSABASEERR + 60);
    WSAECONNREFUSED    	= (WSABASEERR + 61);
    WSAELOOP           	= (WSABASEERR + 62);
    WSAENAMETOOLONG    	= (WSABASEERR + 63);
    WSAEHOSTDOWN       	= (WSABASEERR + 64);
    WSAEHOSTUNREACH    	= (WSABASEERR + 65);
    WSAENOTEMPTY       	= (WSABASEERR + 66);
    WSAEPROCLIM        	= (WSABASEERR + 67);
    WSAEUSERS          	= (WSABASEERR + 68);
    WSAEDQUOT          	= (WSABASEERR + 69);
    WSAESTALE          	= (WSABASEERR + 70);
    WSAEREMOTE         	= (WSABASEERR + 71);

    WSASYSNOTREADY     	= (WSABASEERR + 91);
    WSAVERNOTSUPPORTED 	= (WSABASEERR + 92);
    WSANOTINITIALISED  	= (WSABASEERR + 93);

    WSAHOST_NOT_FOUND  	= (WSABASEERR + 1001);
    HOST_NOT_FOUND     	= WSAHOST_NOT_FOUND;

    WSATRY_AGAIN       	= (WSABASEERR + 1002);
    TRY_AGAIN          	= WSATRY_AGAIN;

    WSANO_RECOVERY     	= (WSABASEERR + 1003);
    NO_RECOVERY        	= WSANO_RECOVERY;

    WSANO_DATA         	= (WSABASEERR + 1004);
    NO_DATA            	= WSANO_DATA;

    WSANO_ADDRESS      	= WSANO_DATA;
    NO_ADDRESS         	= WSANO_ADDRESS;

(*
    EWOULDBLOCK        =  WSAEWOULDBLOCK;
    EINPROGRESS        =  WSAEINPROGRESS;
    EALREADY           =  WSAEALREADY;
    ENOTSOCK           =  WSAENOTSOCK;
    EDESTADDRREQ       =  WSAEDESTADDRREQ;
    EMSGSIZE           =  WSAEMSGSIZE;
    EPROTOTYPE         =  WSAEPROTOTYPE;
    ENOPROTOOPT        =  WSAENOPROTOOPT;
    EPROTONOSUPPORT    =  WSAEPROTONOSUPPORT;
    ESOCKTNOSUPPORT    =  WSAESOCKTNOSUPPORT;
    EOPNOTSUPP         =  WSAEOPNOTSUPP;
    EPFNOSUPPORT       =  WSAEPFNOSUPPORT;
    EAFNOSUPPORT       =  WSAEAFNOSUPPORT;
    EADDRINUSE         =  WSAEADDRINUSE;
    EADDRNOTAVAIL      =  WSAEADDRNOTAVAIL;
    ENETDOWN           =  WSAENETDOWN;
    ENETUNREACH        =  WSAENETUNREACH;
    ENETRESET          =  WSAENETRESET;
    ECONNABORTED       =  WSAECONNABORTED;
    ECONNRESET         =  WSAECONNRESET;
    ENOBUFS            =  WSAENOBUFS;
    EISCONN            =  WSAEISCONN;
    ENOTCONN           =  WSAENOTCONN;
    ESHUTDOWN          =  WSAESHUTDOWN;
    ETOOMANYREFS       =  WSAETOOMANYREFS;
    ETIMEDOUT          =  WSAETIMEDOUT;
    ECONNREFUSED       =  WSAECONNREFUSED;
    ELOOP              =  WSAELOOP;
    ENAMETOOLONG       =  WSAENAMETOOLONG;
    EHOSTDOWN          =  WSAEHOSTDOWN;
    EHOSTUNREACH       =  WSAEHOSTUNREACH;
    ENOTEMPTY          =  WSAENOTEMPTY;
    EPROCLIM           =  WSAEPROCLIM;
    EUSERS             =  WSAEUSERS;
    EDQUOT             =  WSAEDQUOT;
    ESTALE             =  WSAESTALE;
    EREMOTE            =  WSAEREMOTE;
*)

type
    LPSOCKADDR 		= ^sockaddr;
    LPSOCKADDR_IN 	= ^sockaddr_in;
    LPLINGER 		= ^linger;
    LPHOSTENT 		= ^hostent;
    LPSERVENT 		= ^servent;
    LPPROTOENT 		= ^protoent;


type
	TWndProc		=	procedure( wMsg: u_int; wParam, lParam: u_long );

function accept 			(s: TSocket;
						 	 var addr: sockaddr;
						 	 addrlen: integer): TSocket; far;

function bind 				(s: TSocket;
						 	 var addr: sockaddr;
						 	 namelen: integer): integer; far;

function closesocket		(s: TSocket): integer; far;

function connect 			(s: TSocket;
						 	 var name: sockaddr;
						 	 namelen: integer): integer; far;

function ioctlsocket 		(s: TSocket;
						 	 cmd: longint;
						 	 argp: u_long): integer; far;

function getpeername 		(s: TSocket;
						 	 var name: sockaddr;
						 	 namelen: integer): integer; far;

function getsockname 		(s: TSocket;
						 	 var name: sockaddr;
						 	 namelen: integer): integer; far;

function getsockopt 		(s: TSocket;
						 	 level,
						 	 optname: integer;
						 	 optval: PChar;
						 	 optlen: integer): integer; far;

function htonl 				(hostlong: u_long): u_long; far;

function htons 				(hostshort: u_short): u_short; far;

function inet_addr 			(cp: pchar): LPIN_ADDR; far;

function inet_ntoa 			(inaddr: in_addr): pchar; far;

function listen 			(s: TSocket;
						 	 backlog: integer): integer; far;

function ntohl 				(netlong: u_long): u_long; far;

function ntohs 				(netshort: u_short): u_short; far;

function recv 				(s: TSocket;
						 	 buf: PChar;
						 	 len,
						 	 flags: integer): integer; far;

function recvfrom 			(s: TSocket;
						 	 buf: PChar;
						 	 len,
						 	 flags: integer;
						 	 var from: sockaddr;
						 	 var fromlen: integer): integer; far;

function select 			(nfds: integer;
						 	 var readfds,
						 	 	 writefds,
						 	 	 exceptfds: fd_set;
						 	 var timeout: timeval): longint; far;

function send 				(s: TSocket;
						 	 buf: PChar;
						 	 len,
						 	 flags: integer): integer; far;

function sendto 			(s: TSocket;
						 	 buf: PChar;
						 	 len,
						 	 flags: integer;
						 	 var addrto: sockaddr;
						 	 tolen: integer): integer; far;

function setsockopt 		(s: TSocket;
						 	 level,
						 	 optname: integer;
						 	 optval: PChar;
						 	 optlen: integer): integer; far;

function shutdown 			(s: TSocket;
						 	 how: integer): integer; far;

function socket 			(af,
							 struct,
							 protocol: integer): TSocket; far;

function gethostbyaddr 		(addr: PChar;
						 	 len,
						 	 struct: integer): LPHOSTENT; far;

function gethostbyname		(name: pchar): LPHOSTENT; far;

function getservbyport 		(port: integer;
						 	 proto: pchar): LPSERVENT; far;

function getservbyname 		(name,
							 proto: PChar): LPSERVENT; far;

function getprotobynumber 	(proto: integer): LPPROTOENT; far;

function getprotobyname 	(name: pchar): LPPROTOENT; far;

function WSAStartup 		(wVersionRequired: word;
						 	 lpWSData: LPWSADATA): integer; far;

function WSACleanup			: integer; far;

procedure WSASetLastError 	(iError: integer); far;

function WSAGetLastError	: integer; far;

function WSAAsyncSelect 	(s: TSocket;
						 	 hWnd: TWndProc;
						 	 wMsg: u_int;
						 	 lEvent: longint): integer; far;

function WSAGetSelectEvent	(lParam: longint): word; far;

function WSAGetSelectError 	(lParam: longint): word; far;

function MAKEWORD			(a, b: byte): word; far;

{$ENDIF}
