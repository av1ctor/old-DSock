;;
;; dsock.inc --
;;
;; This file includes parts which are Copyright (c) 1982-1986 Regents
;; of the University of California. All rights reserved.
;;

ifndef          __DSOCK_INC__
                __DSOCK_INC__ equ 1

                ;; Basic system type definitions, taken from the BSD
                ;; file sys/types.h.
                u_char        	typedef UCHAR
                u_short         typedef USHORT
                u_int           typedef ULONG	;; <-- UINT to ULONG !!!
                u_long          typedef ULONG

                ;; The new type to be used in all instances which refer to
                ;; sockets.
		SOCKET          typedef u_int

                LPLPCHAR        typedef FARPTR LPCHAR

               	;; Select uses arrays of SOCKETs.  These macros manipulate
               	;; such arrays.  FD_SETSIZE may be defined by the user
               	;; before including this file, but the default here should
               	;; be >= 64.

               	;; CAVEAT IMPLEMENTOR and USER: THESE MACROS AND TYPES MUST
               	;; BE INCLUDED IN WINSOCK2.H EXACTLY AS SHOWN HERE.
ifndef          FD_SETSIZE
                FD_SETSIZE      equ     64
endif

fd_set          struct		4
                fd_count	u_int   ?	;; how many are SET?
                fd_array	SOCKET  FD_SETSIZE dup (?) ;; an array of SOCKETs
fd_set          ends

	;;;;;;;;__WSAFDIsSet	proto 	FARPROC PASCAL :SOCKET, :FARPTR fd_set

comment `
;;::::::::::::::
;; #define FD_CLR(fd, set) do { \
;;     u_int __i; \
;;     for (__i = 0; __i < ((fd_set FAR *)(set))->fd_count ; __i++) { \
;;         if (((fd_set FAR *)(set))->fd_array[__i] == fd) { \
;;             while (__i < ((fd_set FAR *)(set))->fd_count-1) { \
;;                 ((fd_set FAR *)(set))->fd_array[__i] = \
;;                     ((fd_set FAR *)(set))->fd_array[__i+1]; \
;;                 __i++; \
;;             } \
;;             ((fd_set FAR *)(set))->fd_count--; \
;;             break; \
;;         } \
;;     } \
;; } while(0)
FD_CLR		macro	_fd:req, _set:req
		local	@@for, @@exit, @@break, @@while

if (@Model eq MODEL_FLAT)
		PS	eax, ebx, edx, esi

		mov	esi, _fd
		xor	ebx, ebx

@@for:		cmp	ebx, [esi].fd_set.fd_count
		jge	@@exit

		cmp	[esi].fd_set.fd_array[ebx], esi
		jne	@@break

		mov	edx, [esi].fd_set.fd_count
		dec	edx
@@while:	cmp	ebx, edx
		jge	@@break
		mov	eax, [esi].fd_set.fd_array[ebx+T SOCKET]
		mov	[esi].fd_set.fd_array[ebx], eax
		add	ebx, T SOCKET
		jmp	@@while

@@break:	dec	[esi].fd_set.fd_count
		jmp	@@exit

		add	ebx, T SOCKET
		jmp	@@for

@@exit:		PP	esi, edx, ebx, eax

else
		.err	<FD_CLR: no 16-bit version defined>
endif
endm

;;::::::::::::::
;; #define FD_SET(fd, set) do { \
;;     u_int __i; \
;;     for (__i = 0; __i < ((fd_set FAR *)(set))->fd_count; __i++) { \
;;         if (((fd_set FAR *)(set))->fd_array[__i] == (fd)) { \
;;             break; \
;;         } \
;;     } \
;;     if (__i == ((fd_set FAR *)(set))->fd_count) { \
;;         if (((fd_set FAR *)(set))->fd_count < FD_SETSIZE) { \
;;             ((fd_set FAR *)(set))->fd_array[__i] = (fd) \
;;             ((fd_set FAR *)(set))->fd_count++; \
;;         } \
;;     } \
;; } while(0)
FD_SET		macro	_fd:req, _set:req
		local	@@for

if (@Model eq MODEL_FLAT)
		PS	ebx, esi

		mov	esi, _fd
		xor	ebx, ebx

@@for:		cmp	ebx, [esi].fd_set.fd_count
		jge	@F
		cmp	[esi].fd_set.fd_array[ebx], esi
		je	@F
		add	ebx, T SOCKET
		jmp	@@for

@@:		cmp	ebx, [esi].fd_set.fd_count
		jne	@F
		cmp	[esi].fd_set.fd_count, FD_SETSIZE
		jge	@F
		mov	[esi].fd_set.fd_array[ebx], esi
		inc	[esi].fd_set.fd_count

@@:		PP	esi, ebx

else
		.err	<FD_SET: no 16-bit version defined>
endif
endm


;;::::::::::::::
;; #define FD_ZERO(set) (((fd_set FAR *)(set))->fd_count=0)
FD_ZERO	macro	_set:req
if (@Model eq MODEL_FLAT)
		push	ebx
		mov	ebx, _set
		mov	eax, FALSE
		cmp	[ebx].fd_set.fd_count, 0
		jne	@F
		mov	eax, TRUE
@@:		pop	ebx

else
		PS	bx, es
		les	bx, _set
		mov	ax, FALSE
		cmp	es:[bx].fd_set.fd_count, 0
		jne	@F
		mov	ax, TRUE
@@:		PP	es, bx
endif
endm

;;::::::::::::::
;; #define FD_ISSET(fd, set) __WSAFDIsSet((SOCKET)(fd), (fd_set FAR *)(set))
FD_ISSET	macro	_fd:req, _set:req
		invoke	__WSAFDIsSet _fd, _set
endm

		;; Structure used in select() call, taken from the BSD
		;; file sys/time.h.
timeval		struct		4
        	tv_sec		dword	? 	;; seconds
		tv_usec		dword	? 	;; and microseconds
timeval		ends

		;; Operations on timevals.

		;; NB: timercmp does not work for >= or <=.
;;::::::::::::::
;; #define timerisset(tvp)         ((tvp)->tv_sec || (tvp)->tv_usec)
timerisset	macro	_tvp:req
if (@Model eq MODEL_FLAT)
		push	ebx
		mov	ebx, _tvp
		mov	eax, TRUE
		cmp	[ebx].timeval.tv_sec, 0
		jne	@F
		cmp	[ebx].timeval.tv_usec, 0
		jne	@F
		mov	eax, FALSE
@@:		pop	ebx

else
		PS	es, bx
		les	bx, _tvp
		mov	ax, TRUE
		cmp	es:[bx].timeval.tv_sec, 0
		jne	@F
		cmp	es:[bx].timeval.tv_usec, 0
		jne	@F
		mov	ax, FALSE
@@:		PP	es, bx
endif
endm

;;::::::::::::::
;; #define timercmp(tvp, uvp, cmp) \
;;        ((tvp)->tv_sec cmp (uvp)->tv_sec || \
;;         (tvp)->tv_sec == (uvp)->tv_sec && (tvp)->tv_usec cmp (uvp)->tv_usec)
timercmp	macro	_tvp:req, _uvp:req, _cmp:req
if (@Model eq MODEL_FLAT)
		PS	ebx, ecx, edx, esi
		mov	ebx, _tvp
		mov	esi, _uvp

		mov	ecx, [ebx].timeval.tv_sec
		mov	edx, [esi].timeval.tv_sec
		mov	eax, TRUE
		cmp	ecx, edx
		j&_cmp	@F
		mov	eax, FALSE
		cmp	ecx, edx
		jne	@F
		mov	ecx, [ebx].timeval.tv_usec
		cmp	ecx, [esi].timeval.tv_usec
		mov	eax, TRUE
		j&_cmp	@F
		mov	eax, FALSE

@@:		PP	esi, edx, ecx, ebx

else
		PS	bx, ecx, edx, si, es, ds
		les	ebx, _tvp
		lds	esi, _uvp

		mov	ecx, es:[bx].timeval.tv_sec
		mov	edx, ds:[si].timeval.tv_sec
		mov	ax, TRUE
		cmp	ecx, edx
		j&_cmp	@F
		mov	ax, FALSE
		cmp	ecx, edx
		jne	@F
		mov	ecx, es:[bx].timeval.tv_usec
		cmp	ecx, ds:[si].timeval.tv_usec
		mov	ax, TRUE
		j&_cmp	@F
		mov	ax, FALSE

@@:		PP	ds, es, si, edx, ecx, bx
endif
endm

;;::::::::::::::
;; #define timerclear(tvp)         (tvp)->tv_sec = (tvp)->tv_usec = 0
timerclear	macro	_tvp:req
if (@Model eq MODEL_FLAT)
		push	ebx
		mov	ebx, _tvp
		mov	[ebx].timeval.tv_sec, 0
		mov	[ebx].timeval.tv_usec, 0
		pop	ebx

else
		PS	es, bx
		les	bx, _tvp
		mov	es:[bx].timeval.tv_sec, 0
		mov	es:[bx].timeval.tv_usec, 0
		PP	es, bx
endif
endm
` ;; comment
		;; Commands for ioctlsocket(),  taken from the BSD file fcntl.h.

		;; Ioctl's have the command encoded in the lower word,
		;; and the size of any in or out parameters in the upper
		;; word.  The high 2 bits of the upper word are used
		;; to encode the in/out status of the parameter; for now
		IOCPARM_MASK 	equ 07fh        ;; parameters must be < 128 bytes
		IOC_VOID 	equ 020000000h  ;; no parameters
		IOC_OUT 	equ 040000000h  ;; copy out parameters
		IOC_IN 		equ 080000000h 	;; copy in parameters
		IOC_INOUT 	equ (IOC_IN or IOC_OUT)
		;; 020000000h distinguishes new & old ioctl's

;;::::::::::::::
@_IO		macro	_x:req, _y:req
		exitm	(IOC_VOID or (_x shl 8) or _y)
endm

;;::::::::::::::
@_IOR		macro	_x:req, _y:req, _t:req
		exitm 	(IOC_OUT or ((T _t and IOCPARM_MASK) shl 16) or (_x shl 8) or _y)
endm

;;::::::::::::::
@_IOW		macro	_x:req, _y:req, _t:req
		exitm	(IOC_IN or ((T _t and IOCPARM_MASK) shl 16) or (_x shl 8) or _y)
endm

		FIONREAD 	equ @_IOR('f',127,u_long) ;; get # bytes to read
		FIONBIO 	equ @_IOW('f',126,u_long) ;; set/clear non-blocking i/o
		FIOASYNC 	equ @_IOW('f',125,u_long) ;; set/clear async i/o

		;; Socket I/O Controls
		SIOCSHIWAT 	equ @_IOW('s',0,u_long) ;; set high watermark
		SIOCGHIWAT 	equ @_IOR('s',1,u_long) ;; get high watermark
		SIOCSLOWAT 	equ @_IOW('s',2,u_long) ;; set low watermark
		SIOCGLOWAT 	equ @_IOR('s',3,u_long) ;; get low watermark
		SIOCATMARK 	equ @_IOR('s',7,u_long) ;; at oob mark?

		;; Structures returned by network data base library, taken
		;; from the BSD file netdb.h.  All addresses are supplied in
		;; host order, and returned in network order (suitable for
		;; use in system calls).
hostent		struct		4
        	h_name		LPCHAR	?	;; official name of host
        	h_aliases	LPLPCHAR ?	;; alias list
        	h_addrtype	_SHORT	?	;; host address type
        	h_length        _SHORT	?    	;; length of address
		h_addr_list	LPLPCHAR ? 	;; list of addresses
		h_addr 		equ  h_addr_list;; address, for backward compat
hostent		ends

		;; It is assumed here that a network number fits in 32 bits.
netent 		struct		4
        	n_name		LPCHAR	?	;; official name of net
		n_aliases	LPLPCHAR ?	;; alias list
        	n_addrtype	_SHORT	?	;; net address type
        	n_net		u_long	?	;; network #
netent		ends

servent 	struct		4
		s_name		LPCHAR	?	;; official service name
		s_aliases	LPLPCHAR ?	;; alias list
        	s_port		_SHORT	?	;; port #
        	s_proto		LPCHAR	?	;; protocol to use
servent		ends

protoent 	struct		4
		p_name		LPCHAR	?	;; official protocol name
		p_aliases	LPLPCHAR ?	;; alias list
		p_proto		_SHORT	?	;; protocol #
protoent	ends

		;; Constants and structures defined by the internet system,
		;; Per RFC 790, September 1981, taken from the BSD file netinet/in.h.

		;; Protocols
		IPPROTO_IP 	equ     0 	;; dummy for IP
		IPPROTO_ICMP 	equ     1       ;; control message protocol
		IPPROTO_IGMP 	equ     2       ;; internet group management protocol
		IPPROTO_GGP 	equ     3       ;; gateway^2 (deprecated)
		IPPROTO_TCP 	equ     6       ;; tcp
		IPPROTO_PUP 	equ     12      ;; pup
		IPPROTO_UDP 	equ     17      ;; user datagram protocol
		IPPROTO_IDP 	equ     22      ;; xns idp
		IPPROTO_ND 	equ     77      ;; UNOFFICIAL net disk proto

		IPPROTO_RAW 	equ     255     ;; raw IP packet
		IPPROTO_MAX 	equ	256

		;; Port/socket numbers: network standard functions
		IPPORT_ECHO 	equ     7
		IPPORT_DISCARD 	equ     9
		IPPORT_SYSTAT 	equ     11
		IPPORT_DAYTIME 	equ     13
		IPPORT_NETSTAT 	equ     15
		IPPORT_FTP 	equ     21
		IPPORT_TELNET 	equ     23
		IPPORT_SMTP 	equ     25
		IPPORT_TIMESERVER equ   37
		IPPORT_NAMESERVER equ   42
		IPPORT_WHOIS 	equ     43
		IPPORT_MTP 	equ	57

		;; Port/socket numbers: host specific functions
		IPPORT_TFTP 	equ	69
		IPPORT_RJE 	equ     77
		IPPORT_FINGER 	equ     79
		IPPORT_TTYLINK 	equ     87
		IPPORT_SUPDUP 	equ     95


		;; UNIX TCP sockets
		IPPORT_EXECSERVER equ	512
		IPPORT_LOGINSERVER equ  513
		IPPORT_CMDSERVER equ    514
		IPPORT_EFSSERVER equ    520


		;; UNIX UDP sockets
		IPPORT_BIFFUDP equ      512
		IPPORT_WHOSERVER equ    513
		IPPORT_ROUTESERVER equ	520
		;; 520+1 also used


		;; Ports < IPPORT_RESERVED are reserved for
		;; privileged processes (e.g. root).
		IPPORT_RESERVED equ	1024

		;; Link numbers
		IMPLINK_IP 	equ     155
		IMPLINK_LOWEXPER equ    156
		IMPLINK_HIGHEXPER equ	158


		;; Internet address (old style... should be updated)
S_UN_B 		struct 		4
		s_b1		u_char 	?
		s_b2		u_char 	?
		s_b3		u_char 	?
		s_b4		u_char 	?
S_UN_B		ends
S_UN_W		struct 		4
		s_w1		u_short	?
		s_w2		u_short	?
S_UN_W		ends
S_UN        	union		4
                S_un_b		S_UN_B	<>
                S_un_w		S_UN_W	<>
                S_addr 		u_long 	?
S_UN		ends
in_addr		struct		4
		S_un		S_UN	<>
		;; can be used for most tcp & ip code
		s_addr 		equ  	S_un.S_addr
		;; host on imp
		s_host 		equ  	S_un.S_un_b.s_b2
		;; network
		s_net 		equ   	S_un.S_un_b.s_b1
		;; imp
		s_imp 		equ   	S_un.S_un_w.s_w2
		;; imp #
		s_impno 	equ 	S_un.S_un_b.s_b4
		;; logical host
		s_lh 		equ	S_un.S_un_b.s_b3
in_addr		ends

		;; Definitions of bits in internet address integers.
		;; On subnets, the decomposition of addresses to host and net parts
		;; is done according to subnet mask, not the masks here.
;;::::::::::::::
@IN_CLASSA	macro	_i:req
	if 	((_i and 080000000h) = 0)
		exitm	TRUE
	else
		exitm	FALSE
	endif
endm
		IN_CLASSA_NET 	equ     0ff000000h
		IN_CLASSA_NSHIFT equ    24
		IN_CLASSA_HOST 	equ     000ffffffh
		IN_CLASSA_MAX 	equ     128

;;::::::::::::::
@IN_CLASSB	macro	_i:req
	if 	((_i and 0C0000000h) = 080000000h)
		exitm	TRUE
	else
		exitm	FALSE
	endif
endm
		IN_CLASSB_NET 	equ     0FFFF0000h
		IN_CLASSB_NSHIFT equ    16
		IN_CLASSB_HOST 	equ     00000FFFFh
		IN_CLASSB_MAX 	equ	65536

;;::::::::::::::
@IN_CLASSC	macro	_i:req
	if 	((_i and 0E0000000h) = 0C0000000h)
		exitm	TRUE
	else
		exitm	FALSE
	endif
endm
		IN_CLASSC_NET 	equ	0FFFFFF00h
		IN_CLASSC_NSHIFT equ    8
		IN_CLASSC_HOST 	equ     0000000FFh

;;::::::::::::::
@IN_CLASSD	macro	_i:req
	if 	((_i and 0F0000000h) = 0E0000000h)
		exitm	TRUE
	else
		exitm	FALSE
	endif
endm
		IN_CLASSD_NET 	equ     0F0000000h       ;; These ones aren't really
		IN_CLASSD_NSHIFT equ    28               ;; net and host fields, but
		IN_CLASSD_HOST 	equ     00FFFFFFFh       ;; routing needn't know.
;;::::::::::::::
@IN_MULTICAST	macro	_i:req
		exitm	@IN_CLASSD(_i)
endm

		INADDR_ANY 	equ     000000000h
		INADDR_LOOPBACK equ	07F000001h
		INADDR_BROADCAST equ    0FFFFFFFFh
		INADDR_NONE 	equ     0FFFFFFFFh

		ADDR_ANY 	equ 	INADDR_ANY


		;; Socket address, internet style.
sockaddr_in	struct		4
        	sin_family	_SHORT	?
        	sin_port	u_short	?
        	sin_addr	in_addr	<>
        	sin_zero	CHAR	8 dup (?)
sockaddr_in	ends

		WSADESCRIPTION_LEN equ	256
		WSASYS_STATUS_LEN equ   128
WSADATA		struct 		4
        	wVersion	word	?
        	wHighVersion	word	?
        	szDescription	CHAR	WSADESCRIPTION_LEN+1 dup (?)
        	szSystemStatus	CHAR	WSASYS_STATUS_LEN+1 dup (?)
        	iMaxSockets	word	?
        	iMaxUdpDg	word	?
        	lpVendorInfo	LPCHAR	?
WSADATA		ends
		LPWSADATA	typedef	FARPTR WSADATA

		;; Options for use with [gs]etsockopt at the IP level.
		IP_OPTIONS  		equ 1	;; set/get IP per-packet options
		IP_MULTICAST_IF     	equ 2   ;; set/get IP multicast interface
		IP_MULTICAST_TTL    	equ 3   ;; set/get IP multicast timetolive
		IP_MULTICAST_LOOP   	equ 4   ;; set/get IP multicast loopback
		IP_ADD_MEMBERSHIP   	equ 5   ;; add  an IP group membership
		IP_DROP_MEMBERSHIP  	equ 6   ;; drop an IP group membership

		IP_DEFAULT_MULTICAST_TTL equ 1	;; normally limit m'casts to 1 hop
		IP_DEFAULT_MULTICAST_LOOP equ 1 ;; normally hear sends if a member
		IP_MAX_MEMBERSHIPS   	equ 20  ;; per socket; must fit in one mbuf

 		;; Argument structure for IP_ADD_MEMBERSHIP and IP_DROP_MEMBERSHIP.
ip_mreq		struct
        	imr_multiaddr	in_addr <>	;; IP multicast address of group
        	imr_interface	in_addr <>  	;; local IP address of interface
ip_mreq		ends

		;; Definitions related to sockets: types, address families,
		;; options, taken from the BSD file sys/socket.h.

		;; This is used instead of -1, since the SOCKET type is
		;; unsigned.
		INVALID_SOCKET 	equ  	(not 0)
		SOCKET_ERROR 	equ	-1


		;; The  following  may  be used in place of the address
		;; family, socket type, or protocol  in  a  call  to
		;; WSASocket to indicate that the corresponding value should
		;; be taken from the supplied WSAPROTOCOL_INFO structure
		;; instead of the parameter itself.
		FROM_PROTOCOL_INFO equ 	-1


		;; Types
		SOCK_STREAM 	equ     1 	;; stream socket
		SOCK_DGRAM 	equ     2       ;; datagram socket
		SOCK_RAW 	equ     3       ;; raw-protocol interface
		SOCK_RDM 	equ     4       ;; reliably-delivered message
		SOCK_SEQPACKET 	equ  	5       ;; sequenced packet stream


		;; Option flags per-socket.
		SO_DEBUG 	equ  	00001h ;; turn on debugging info recording
		SO_ACCEPTCONN 	equ   	00002h ;; socket has had listen()
		SO_REUSEADDR 	equ    	00004h ;; allow local address reuse
		SO_KEEPALIVE 	equ    	00008h ;; keep connections alive
		SO_DONTROUTE 	equ    	00010h ;; just use interface addresses
		SO_BROADCAST 	equ    	00020h ;; permit sending of broadcast msgs
		SO_USELOOPBACK 	equ  	00040h ;; bypass hardware when possible
		SO_LINGER 	equ     00080h ;; linger on close if data present
		SO_OOBINLINE 	equ    	00100h ;; leave received OOB data in line

		SO_DONTLINGER 	equ   	(not SO_LINGER)

		;; Additional options.
		SO_SNDBUF 	equ     01001h ;; send buffer size
		SO_RCVBUF 	equ     01002h ;; receive buffer size
		SO_SNDLOWAT 	equ     01003h ;; send low-water mark
		SO_RCVLOWAT 	equ     01004h ;; receive low-water mark
		SO_SNDTIMEO 	equ     01005h ;; send timeout
		SO_RCVTIMEO 	equ     01000h ;; receive timeout
		SO_ERROR 	equ     01007h ;; get error status and clear
		SO_TYPE 	equ	01008h ;; get socket type

		;; Options for connect and disconnect data and options.
		;; Used only by non-TCP/IP transports such as DECNet,
		;; OSI TP4, etc.
		SO_CONNDATA     equ	07000h
		SO_CONNOPT      equ	07001h
		SO_DISCDATA     equ	07002h
		SO_DISCOPT      equ	07003h
		SO_CONNDATALEN  equ	07004h
		SO_CONNOPTLEN   equ	07005h
		SO_DISCDATALEN  equ	07006h
		SO_DISCOPTLEN   equ	07007h

		;; Option for opening sockets for synchronous access.
		SO_OPENTYPE     equ	07008h

		SO_SYNCHRONOUS_ALERT	equ	010h
		SO_SYNCHRONOUS_NONALERT equ	020h

		;; Other NT-specific options.
		SO_MAXDG        equ	07009h
		SO_MAXPATHDG    equ	0700Ah

		;; TCP options.
		TCP_NODELAY 	equ 	00001h
		TCP_BSDURGENT   equ	07000h


		;; Address families.
		AF_UNSPEC 	equ   	0  	;; unspecified
		AF_UNIX 	equ     1       ;; local to host (pipes, portals)
		AF_INET 	equ     2       ;; internetwork: UDP, TCP, etc.
		AF_IMPLINK 	equ     3       ;; arpanet imp addresses
		AF_PUP 		equ     4       ;; pup protocols: e.g. BSP
		AF_CHAOS 	equ     5       ;; mit CHAOS protocols
		AF_NS 		equ     6       ;; XEROX NS protocols
		AF_IPX 		equ     AF_NS   ;; IPX protocols: IPX, SPX, etc.
		AF_ISO 		equ     7    	;; ISO protocols
		AF_OSI 		equ     AF_ISO  ;; OSI is ISO
		AF_ECMA 	equ     8       ;; european computer manufacturers
		AF_DATAKIT 	equ     9       ;; datakit protocols
		AF_CCITT 	equ    	10      ;; CCITT protocols, X.25 etc
		AF_SNA 		equ     11      ;; IBM SNA
		AF_DECnet 	equ     12      ;; DECnet
		AF_DLI 		equ     13      ;; Direct data link interface
		AF_LAT 		equ     14      ;; LAT
		AF_HYLINK 	equ     15      ;; NSC Hyperchannel
		AF_APPLETALK 	equ    	16      ;; AppleTalk
		AF_NETBIOS 	equ     17      ;; NetBios-style addresses
		AF_VOICEVIEW 	equ    	18      ;; VoiceView
		AF_FIREFOX 	equ     19      ;; Protocols from Firefox
		AF_UNKNOWN1 	equ     20      ;; Somebody is using this!
		AF_BAN 		equ     21      ;; Banyan
		AF_ATM 		equ     22      ;; Native ATM Services
		AF_INET6 	equ     23      ;; Internetwork Version 6
		AF_CLUSTER 	equ     24      ;; Microsoft Wolfpack
		AF_12844 	equ     25      ;; IEEE 1284.4 WG AF

		AF_MAX 		equ	26

		;; Structure used by kernel to store most
		;; addresses.
sockaddr	struct		4
        	sa_family	u_short ?	;; address family
        	sa_data		CHAR	14 dup (?) ;; up to 14 bytes of direct address
sockaddr	ends

		;; Structure used by kernel to pass protocol
		;; information in raw sockets.
sockproto	struct		4
		sp_family	u_short	?       ;; address family
        	sp_protocol	u_short	?    	;; protocol
sockproto	ends

		;; Protocol families, same as address families for now.
		PF_UNSPEC 	equ       AF_UNSPEC
		PF_UNIX 	equ         AF_UNIX
		PF_INET 	equ         AF_INET
		PF_IMPLINK 	equ      AF_IMPLINK
		PF_PUP 		equ          AF_PUP
		PF_CHAOS 	equ        AF_CHAOS
		PF_NS 		equ           AF_NS
		PF_IPX 		equ          AF_IPX
		PF_ISO 		equ          AF_ISO
		PF_OSI 		equ          AF_OSI
		PF_ECMA 	equ         AF_ECMA
		PF_DATAKIT 	equ      AF_DATAKIT
		PF_CCITT 	equ        AF_CCITT
		PF_SNA 		equ          AF_SNA
		PF_DECnet 	equ       AF_DECnet
		PF_DLI 		equ          AF_DLI
		PF_LAT 		equ          AF_LAT
		PF_HYLINK 	equ       AF_HYLINK
		PF_APPLETALK 	equ    AF_APPLETALK
		PF_VOICEVIEW 	equ    AF_VOICEVIEW
		PF_FIREFOX 	equ      AF_FIREFOX
		PF_UNKNOWN1 	equ     AF_UNKNOWN1
		PF_BAN 		equ          AF_BAN
		PF_ATM 		equ          AF_ATM
		PF_INET6 	equ        AF_INET6

		PF_MAX 		equ          AF_MAX


		;; Structure used for manipulating linger option.
linger		struct		4
        	l_onoff		u_short	?	;; option on/off
        	l_linger	u_short ?     	;; linger time
linger		ends


		;; Level number for (get/set)sockopt() to apply to socket itself.
		SOL_SOCKET 	equ 0FFFFh 	;; options for socket level

		;; Maximum queue length specifiable by listen.
		SOMAXCONN 	equ 07FFFFFFFh

		MSG_OOB 	equ 01h  	;; process out-of-band data
		MSG_PEEK 	equ 02h  	;; peek at incoming message
		MSG_DONTROUTE 	equ 04h  	;; send without using routing tables

		MSG_MAXIOVLEN   equ 16

		MSG_PARTIAL 	equ 08000h  	;; partial send or recv for message xport

		;; WinSock 2 extension -- new flags for WSASend(),
		;; WSASendTo(), WSARecv() and WSARecvFrom()
		MSG_INTERRUPT 	equ 	010h	;; send/recv in the interrupt context
		MSG_MAXIOVLEN 	equ 	16

		;; Define constant based on rfc883, used by gethostbyxxxx() calls.
		MAXGETHOSTSTRUCT equ	1024

		;; Define flags to be used with the WSAAsyncSelect() call.
		FD_READ         	equ	01h
		FD_WRITE        	equ	02h
		FD_OOB          	equ	04h
		FD_ACCEPT       	equ	08h
		FD_CONNECT      	equ	10h
		FD_CLOSE        	equ	20h

		;; All Windows Sockets error constants are biased by
		;; WSABASEERR from the "normal"
		WSABASEERR 		equ	10000

		;; Windows Sockets definitions of regular Microsoft C
		;; error constants
		WSAEINTR 		equ     (WSABASEERR+4)
		WSAEBADF 		equ     (WSABASEERR+9)
		WSAEACCES 		equ     (WSABASEERR+13)
		WSAEFAULT 		equ     (WSABASEERR+14)
		WSAEINVAL 		equ     (WSABASEERR+22)
		WSAEMFILE 		equ	(WSABASEERR+24)


		;; Windows Sockets definitions of regular Berkeley
		;; error constants
		WSAEWOULDBLOCK 		equ   	(WSABASEERR+35)
		WSAEINPROGRESS 		equ     (WSABASEERR+36)
		WSAEALREADY 		equ     (WSABASEERR+37)
		WSAENOTSOCK 		equ     (WSABASEERR+38)
		WSAEDESTADDRREQ 	equ     (WSABASEERR+39)
		WSAEMSGSIZE 		equ     (WSABASEERR+40)
		WSAEPROTOTYPE 		equ     (WSABASEERR+41)
		WSAENOPROTOOPT 		equ     (WSABASEERR+42)
		WSAEPROTONOSUPPORT 	equ  	(WSABASEERR+43)
		WSAESOCKTNOSUPPORT 	equ  	(WSABASEERR+44)
		WSAEOPNOTSUPP 		equ     (WSABASEERR+45)
		WSAEPFNOSUPPORT 	equ     (WSABASEERR+46)
		WSAEAFNOSUPPORT 	equ     (WSABASEERR+47)
		WSAEADDRINUSE 		equ     (WSABASEERR+48)
		WSAEADDRNOTAVAIL 	equ    	(WSABASEERR+49)
		WSAENETDOWN 		equ     (WSABASEERR+50)
		WSAENETUNREACH 		equ     (WSABASEERR+51)
		WSAENETRESET 		equ     (WSABASEERR+52)
		WSAECONNABORTED 	equ     (WSABASEERR+53)
		WSAECONNRESET 		equ     (WSABASEERR+54)
		WSAENOBUFS 		equ     (WSABASEERR+55)
		WSAEISCONN 		equ     (WSABASEERR+56)
		WSAENOTCONN 		equ     (WSABASEERR+57)
		WSAESHUTDOWN 		equ     (WSABASEERR+58)
		WSAETOOMANYREFS 	equ     (WSABASEERR+59)
		WSAETIMEDOUT 		equ     (WSABASEERR+60)
		WSAECONNREFUSED 	equ     (WSABASEERR+61)
		WSAELOOP 		equ     (WSABASEERR+62)
		WSAENAMETOOLONG 	equ     (WSABASEERR+63)
		WSAEHOSTDOWN 		equ     (WSABASEERR+64)
		WSAEHOSTUNREACH 	equ     (WSABASEERR+65)
		WSAENOTEMPTY 		equ     (WSABASEERR+66)
		WSAEPROCLIM 		equ     (WSABASEERR+67)
		WSAEUSERS 		equ     (WSABASEERR+68)
		WSAEDQUOT 		equ     (WSABASEERR+69)
		WSAESTALE 		equ     (WSABASEERR+70)
		WSAEREMOTE 		equ     (WSABASEERR+71)


		;; Extended Windows Sockets error constant definitions
		WSASYSNOTREADY 		equ   	(WSABASEERR+91)
		WSAVERNOTSUPPORTED 	equ  	(WSABASEERR+92)
		WSANOTINITIALISED 	equ   	(WSABASEERR+93)
		WSAEDISCON 		equ     (WSABASEERR+101)
		WSAENOMORE 		equ     (WSABASEERR+102)
		WSAECANCELLED 		equ     (WSABASEERR+103)
		WSAEINVALIDPROCTABLE 	equ 	(WSABASEERR+104)
		WSAEINVALIDPROVIDER 	equ 	(WSABASEERR+105)
		WSAEPROVIDERFAILEDINIT 	equ 	(WSABASEERR+106)
		WSASYSCALLFAILURE 	equ  	(WSABASEERR+107)
		WSASERVICE_NOT_FOUND 	equ 	(WSABASEERR+108)
		WSATYPE_NOT_FOUND 	equ  	(WSABASEERR+109)
		WSA_E_NO_MORE 		equ     (WSABASEERR+110)
		WSA_E_CANCELLED 	equ     (WSABASEERR+111)
		WSAEREFUSED 		equ	(WSABASEERR+112)


		;; Error return codes from gethostbyname() and gethostbyaddr()
		;; (when using the resolver). Note that these errors are
		;; retrieved via WSAGetLastError() and must therefore follow
		;; the rules for avoiding clashes with error numbers from
		;; specific implementations or language run-time systems.
		;; For this reason the codes are based at WSABASEERR+1001.
		;; Note also that [WSA]NO_ADDRESS is defined only for
		;; compatibility purposes.
		h_errno 	textequ	<invoke	WSAGetLastError>

		;; Authoritative Answer: Host not found
		WSAHOST_NOT_FOUND 	equ   	(WSABASEERR+1001)
		HOST_NOT_FOUND 		equ     WSAHOST_NOT_FOUND

		;; Non-Authoritative: Host not found, or SERVERFAIL
		WSATRY_AGAIN 		equ     (WSABASEERR+1002)
		TRY_AGAIN 		equ     WSATRY_AGAIN

		;; Non-recoverable errors, FORMERR, REFUSED, NOTIMP
		WSANO_RECOVERY 		equ     (WSABASEERR+1003)
		NO_RECOVERY 		equ     WSANO_RECOVERY

		;; Valid name, no data record of requested type
		WSANO_DATA 		equ     (WSABASEERR+1004)
		NO_DATA 		equ     WSANO_DATA

		;; no address, look for MX record
		WSANO_ADDRESS 		equ     WSANO_DATA
		NO_ADDRESS 		equ  	WSANO_ADDRESS

		;; Windows Sockets errors redefined as regular Berkeley
		;; error constants. These are commented out in Windows NT
		;; to avoid conflicts with errno.h. Use the WSA constants
		;; instead.
comment `
		EWOULDBLOCK 	equ  		WSAEWOULDBLOCK
		EINPROGRESS 	equ             WSAEINPROGRESS
		EALREADY 	equ                WSAEALREADY
		ENOTSOCK 	equ                WSAENOTSOCK
		EDESTADDRREQ 	equ            WSAEDESTADDRREQ
		EMSGSIZE 	equ                WSAEMSGSIZE
		EPROTOTYPE 	equ              WSAEPROTOTYPE
		ENOPROTOOPT 	equ             WSAENOPROTOOPT
		EPROTONOSUPPORT equ         WSAEPROTONOSUPPORT
		ESOCKTNOSUPPORT equ         WSAESOCKTNOSUPPORT
		EOPNOTSUPP 	equ              WSAEOPNOTSUPP
		EPFNOSUPPORT 	equ            WSAEPFNOSUPPORT
		EAFNOSUPPORT 	equ            WSAEAFNOSUPPORT
		EADDRINUSE 	equ              WSAEADDRINUSE
		EADDRNOTAVAIL 	equ           WSAEADDRNOTAVAIL
		ENETDOWN 	equ                WSAENETDOWN
		ENETUNREACH 	equ             WSAENETUNREACH
		ENETRESET 	equ               WSAENETRESET
		ECONNABORTED 	equ            WSAECONNABORTED
		ECONNRESET 	equ              WSAECONNRESET
		ENOBUFS 	equ                 WSAENOBUFS
		EISCONN 	equ                 WSAEISCONN
		ENOTCONN 	equ                WSAENOTCONN
		ESHUTDOWN 	equ               WSAESHUTDOWN
		ETOOMANYREFS 	equ            WSAETOOMANYREFS
		ETIMEDOUT 	equ               WSAETIMEDOUT
		ECONNREFUSED 	equ            WSAECONNREFUSED
		ELOOP 		equ                   WSAELOOP
		ENAMETOOLONG 	equ            WSAENAMETOOLONG
		EHOSTDOWN 	equ               WSAEHOSTDOWN
		EHOSTUNREACH 	equ            WSAEHOSTUNREACH
		ENOTEMPTY 	equ   	          WSAENOTEMPTY
		EPROCLIM 	equ                WSAEPROCLIM
		EUSERS 		equ                  WSAEUSERS
		EDQUOT 		equ                  WSAEDQUOT
		ESTALE 		equ                  WSAESTALE
		EREMOTE 	equ                 WSAEREMOTE
`

                WSAAPI          textequ <FARPROC PASCAL>

		;;::::::::::::::
		;; Socket function prototypes

		;; SOCKET WSAAPI accept(SOCKET s, struct sockaddr FAR *addr, int FAR *addrlen)
		accept		proto 	WSAAPI :SOCKET, :FARPTR sockaddr,\
				 	addrlen:FARPTR SINT

		;; int WSAAPI bind(SOCKET s, const struct sockaddr FAR * name, int namelen)
		bind		proto	WSAAPI :SOCKET, :FARPTR sockaddr,\
					:SINT

		;; int WSAAPI closesocket(SOCKET s)
		closesocket	proto	WSAAPI :SOCKET

		;; int WSAAPI connect(SOCKET s, const struct sockaddr FAR * name, int namelen)
		connect		proto	WSAAPI :SOCKET, :FARPTR sockaddr,\
					:SINT

		;; int WSAAPI getpeername(SOCKET s, struct sockaddr FAR * name, int FAR * namelen)
		getpeername	proto	WSAAPI :SOCKET, :FARPTR sockaddr,\
					:FARPTR SINT

		;; int WSAAPI getsockname(SOCKET s, struct sockaddr FAR * name, int FAR * namelen)
		getsockname	proto	WSAAPI :SOCKET, :FARPTR sockaddr,\
					:FARPTR SINT

		;; int WSAAPI getsockopt(SOCKET s, int level, int optname, char FAR * optval, int FAR * optlen)
		getsockopt	proto 	WSAAPI :SOCKET, :SINT, :SINT,\
					:FARPTR CHAR, :FARPTR SINT

		;; u_long WSAAPI htonl(u_long hostlong)
		htonl		proto	WSAAPI :u_long

		;; u_short WSAAPI htons(u_short hostshort)
		htons		proto	WSAAPI :u_short

		;; unsigned long WSAAPI inet_addr(const char FAR * cp)
		inet_addr	proto	WSAAPI :STRING

		;; char FAR * WSAAPI inet_ntoa(struct in_addr in)
		inet_ntoa	proto	WSAAPI :in_addr

		;; int WSAAPI ioctlsocket(SOCKET s, long cmd, u_long FAR * argp)
		ioctlsocket	proto	WSAAPI :SOCKET, :LONG,\
					:FARPTR u_long

		;; int WSAAPI listen(SOCKET s, int backlog)
		listen		proto 	WSAAPI :SOCKET, :SINT

		;; u_long WSAAPI ntohl(u_long netlong)
		ntohl		proto	WSAAPI :u_long

		;; u_short WSAAPI ntohs(u_short netshort)
		ntohs		proto	WSAAPI :u_short

		;; int WSAAPI recv(SOCKET s, char FAR * buf, int len, int flags)
		recv		proto	WSAAPI :SOCKET, :FARPTR CHAR,\
					:SINT, :SINT

		;; int WSAAPI recvfrom(SOCKET s, char FAR * buf, int len, int flags, struct sockaddr FAR * from, int FAR * fromlen)
		recvfrom	proto	WSAAPI :SOCKET, :FARPTR CHAR, :SINT,\
					:SINT, :FARPTR sockaddr, :FARPTR SINT

		;; int WSAAPI select(int nfds, fd_set FAR * readfds, fd_set FAR * writefds, fd_set FAR *exceptfds, const struct timeval FAR * timeout)
		select		proto	WSAAPI :SINT, :FARPTR fd_set,\
					:FARPTR fd_set, :FARPTR fd_set,\
					:FARPTR timeval

		;; int WSAAPI send(SOCKET s, const char FAR * buf, int len, int flags)
		send		proto	WSAAPI :SOCKET, :FARPTR CHAR, :SINT,\
					:SINT

		;; int WSAAPI sendto(SOCKET s, const char FAR * buf, int len, int flags, const struct sockaddr FAR * to, int tolen)
		sendto		proto	WSAAPI :SOCKET, :FARPTR CHAR, :SINT,\
					:SINT, :FARPTR sockaddr, :SINT

		;; int WSAAPI setsockopt(SOCKET s, int level, int optname, const char FAR * optval, int optlen)
		setsockopt	proto	WSAAPI :SOCKET, :SINT, :SINT, :FARPTR CHAR,\
					:SINT

		;; int WSAAPI shutdown(SOCKET s, int how)
		shutdown	proto	WSAAPI :SOCKET, :SINT

		;; SOCKET WSAAPI socket(SINT af, int type, int protocol)
		socket		proto	WSAAPI :SINT, :SINT, :SINT


		;;::::::::::::::
		;; Database function prototypes
		;; struct hostent FAR * WSAAPI gethostbyaddr(const char FAR * addr, int len, int type)
		gethostbyaddr	proto	WSAAPI :FARPTR CHAR, :SINT, :SINT

		;; struct hostent FAR * WSAAPI gethostbyname(const char FAR * name)
		gethostbyname	proto	WSAAPI :STRING

		;; int WSAAPI gethostname(char FAR * name, int namelen)
		gethostname	proto	WSAAPI :STRING, :SINT

		;; struct servent FAR * WSAAPI getservbyport(int port, const char FAR * proto)
		getservbyport	proto	WSAAPI :SINT, :STRING

		;; struct servent FAR * WSAAPI getservbyname(const char FAR * name, const char FAR * proto)
		getservbyname	proto	WSAAPI :STRING, :STRING

		;; struct protoent FAR * WSAAPI getprotobynumber(int number)
		getprotobynumber proto	WSAAPI :SINT

		;; struct protoent FAR * WSAAPI getprotobyname(const char FAR * name)
		getprotobyname	proto	WSAAPI :STRING


		;;::::::::::::::
		;; Microsoft Windows Extension function prototypes

		;; int WSAAPI WSAStartup(WORD wVersionRequested, LPWSADATA lpWSAData)
		WSAStartup	proto	WSAAPI :word, :LPWSADATA

		;; int WSAAPI WSACleanup(void)
		WSACleanup	proto	WSAAPI

		;; int WSAAPI WSAGetLastError(void)
		WSAGetLastError	proto	WSAAPI

		;; void WSAAPI WSASetLastError(int iError)
		WSASetLastError	proto	WSAAPI :SINT

		;; int WSAAPI WSAAsyncSelect(SOCKET s, HWND hWnd, u_int wMsg, long lEvent)
		WSAAsyncSelect	proto 	WSAAPI :SOCKET, :HWND, :u_int, :LONG


		;;::::::::::::::
		;; Microsoft Windows Extended data types
 		SOCKADDR_IN	typedef sockaddr_in
		PSOCKADDR_IN	typedef NEARPTR sockaddr_in
		LPSOCKADDR_IN	typedef FARPTR sockaddr_in

		LINGER		typedef linger
		PLINGER		typedef NEARPTR linger
		LPLINGER	typedef FARPTR linger

		IN_ADDR		typedef in_addr
		PIN_ADDR	typedef NEARPTR in_addr
		LPIN_ADDR	typedef FARPTR in_addr

		FD_SET		typedef fd_set
		PFD_SET		typedef NEARPTR fd_set
		LPFD_SET	typedef FARPTR fd_set

		HOSTENT		typedef hostent
		PHOSTENT	typedef NEARPTR hostent
		LPHOSTENT	typedef FARPTR hostent

		SERVENT		typedef servent
		PSERVENT	typedef NEARPTR servent
		LPSERVENT	typedef FARPTR servent

		PROTOENT	typedef protoent
		PPROTOENT	typedef NEARPTR protoent
		LPPROTOENT	typedef FARPTR protoent

		TIMEVAL		typedef timeval
		PTIMEVAL	typedef NEARPTR timeval
		LPTIMEVAL	typedef FARPTR timeval


comment `
		;; Windows message parameter composition and decomposition
		;; macros.

		;; WSAMAKEASYNCREPLY is intended for use by the Windows
		;; Sockets implementation when constructing the response to
		;; a WSAAsyncGetXByY() routine.
@WSAMAKEASYNCREPLY macro _buflen:req, _error:req
		exitm	@MAKELONG(_buflen, _error)
endm

		;; WSAMAKESELECTREPLY is intended for use by the Windows
		;; Sockets implementation when constructing the response to
		;; WSAAsyncSelect().
@WSAMAKESELECTREPLY macro _event:req, _error:req
		exitm	@MAKELONG(_event, _error)
endm

		;; WSAGETASYNCBUFLEN is intended for use by the Windows
		;; Sockets application to extract the buffer length from the
		;; lParam _IN the response to a WSAAsyncGetXByY().
@WSAGETASYNCBUFLEN macro _lParam:req
		exitm	@LOWORD(_lParam)
endm

		;; WSAGETASYNCERROR is intended for use by the Windows
		;; Sockets application to extract the error code from the
		;; lParam _IN the response to a WSAGetXByY().
@WSAGETASYNCERROR macro	_lParam:req
		exitm	@HIWORD(_lParam)
endm

		;; WSAGETSELECTEVENT is intended for use by the Windows
		;; Sockets application to extract the event code from the
		;; lParam _IN the response to a WSAAsyncSelect().
@WSAGETSELECTEVENT macro _lParam:req
		exitm	@LOWORD(_lParam)
endm

		;; WSAGETSELECTERROR is intended for use by the Windows
		;; Sockets application to extract the error code from the
		;; lParam _IN the response to a WSAAsyncSelect().
@WSAGETSELECTERROR macro _lParam:req
		exitm	@HIWORD(_lParam)
endm
` ;; comment

endif       ;; __DSOCK_INC__
