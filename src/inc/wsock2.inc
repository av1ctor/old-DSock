;; ********************************************************************
;; *                        Microsoft Windows                         *
;; *                Copyright(c) Microsoft Corp., 1993                *
;; ********************************************************************
;;
;; wsock.h
;;
;; WSOCK.386 VxD service definitions.
;;
;;
;; FILE HISTORY:
;;     DavidKa     ~?~???? Created.
;;     KeithMo     30-Dec-1993 Cleaned up a bit, made H2INC-able.
;;     v1ctor	   05-Mar-2002 Updated to work with wsock2.vxd.
;;
;; Note: All credits for discovering the changes between wsock and
;;       wsock2 parameters go to Berczi Gabor and his hacking abilities :).

ifndef          __WSOCK2_INC__
                __WSOCK2_INC__  equ 1

		;; Version numbers.
                WS2_Ver_Major         	equ     2
                WS2_Ver_Minor         	equ     2

		;; The current provider interface version number.  Increment
		;; this constant after any change that effects the provider
		;; interface.
                WS2_INTERFACE_VERSION 	equ     000000001h

		;; A locally-defined error code, indicating the underlying
		;; provider returned WSAEWOULDBLOCK for an operation invoked
		;; on a blocking socket.
                WS2_WILL_BLOCK        	equ     0FFFFh

		;; Infinite wait time for send/recv timeout.
		SOCK_IO_TIME            equ 	0FFFFFFFFh

		;; Incomplete types.
ifndef 		LPSOCK_INFO_DEFINED
		LPSOCK_INFO_DEFINED	equ	1
endif  		;; LPSOCK_INFO_DEFINED

ifndef		LINGER
                LINGER                  typedef word	;; [2]
endif
                LIST_ENTRY              typedef dword	;; [2]

SOCK_INFO	struct
					dword	26 dup (?)
		Handle			dword	?
SOCK_INFO	ends
       	        LPSOCK_INFO             typedef FARPTR SOCK_INFO

ifndef 	LPVOID
                LPVOID             	typedef FARPTR
endif 	;;LPVOID

		FD_READ         	equ	01h
		FD_WRITE        	equ	02h
		FD_OOB          	equ	04h
		FD_ACCEPT       	equ	08h
		FD_CONNECT      	equ	10h
		FD_CLOSE        	equ	20h

		;; All FD_* events.
		FD_ALL  		equ	(FD_READ or FD_WRITE or\
						 FD_OOB or FD_ACCEPT or\
						 FD_CONNECT or FD_CLOSE)

		;; This "special" FD_ event is used in select so that we may
		;; synthesize proper exceptfds for failed connection attempts.
                FD_FAILED_CONNECT       equ	100h

		INVALID_SOCKET 	equ  	(not 0)
		SOCKET_ERROR 	equ	-1

WSABUF 		struct 1
    		len			dword 	? ;; the length of the buffer
		buf     		dword	? ;; the pointer to the buffer
WSABUF		ends
		LPWSABUF		typedef	FARPTR WSABUF

WSAOVERLAPPED	struct 1
       		Internal      		dword	?
       		InternalHigh  		dword	?
       		_Offset        		dword	?
       		OffsetHigh    		dword	?
       		hEvent        		dword	?
WSAOVERLAPPED	ends
ifndef 		LPWSAOVERLAPPED_DEFINED
		LPWSAOVERLAPPED_DEFINED	equ	1
                LPWSAOVERLAPPED         typedef FARPTR WSAOVERLAPPED
endif

		;; A list of socket/event mask pairs.  A FARPTR to an array
		;; of these structures is passed to WsCreateMultipleNotify
		;; to create multiple notification objects.
SOCK_LIST       struct 1
                ;; the target socket
                Socket                  LPSOCK_INFO ?
		;; events the client is interested in
                EventMask               dword   ?
		;; user-defined context value (handle?)
                Context                 dword   ?
                ;; [v1c]: WSock2 has one more field!!!
                Unknown			dword	?
SOCK_LIST       ends
                LPSOCK_LIST             typedef FARPTR SOCK_LIST

ifndef 		LPSOCK_LIST_DEFINED
		LPSOCK_LIST_DEFINED	equ	1
		LPSOCK_LIST		typedef FARPTR SOCK_LIST
endif  		;; LPSOCK_LIST_DEFINED

		;; A Winsock I/O Status Block.  This structure contains all
		;; information about completing/cancelling a blocking socket
		;; operation.  Whenever an APC is scheduled against a thread,
		;; the APC Context value points to the thread's WSIOSTATUS
		;; structure.  This is especially useful for 16-bit
		;; applications, since it enables the WSOCK VxD to "unblock"
		;; a 16-bit thread without calling "up" into user mode.
WSIOSTATUS      struct 1
                ;; completion status
                IoStatus                dword   ?
                ;; i/o has completed
		IoCompleted             sbyte   ?
		;; i/o has been cancelled
                IoCancelled             sbyte   ?
		;; i/o has timed out
                IoTimedOut              sbyte   ?
		;; spare (for dword alignment)
                IoSpare1                sbyte   ?
WSIOSTATUS      ends
                LPWSIOSTATUS            typedef FARPTR WSIOSTATUS

		;; This is is a special APC Routine value that may be passed
		;; into the various CreateNotify services.  If this value
		;; is specified as the APC Routine, then the APC is not
		;; actually invoked, and the APC Context is assumed to
		;; point to the thread's WSIOSTATUS block.
		;;
		;; Note that this is used for 16-bit applications only!
		SPECIAL_16BIT_APC 	equ 	-1

		;; This section defines the constants and structures
		;; necessary for communication between the WinSock DLLs and
		;; WSOCK.386.  For each command, there is defined a unique
		;; opcode and a structure defining the command parameters.
		;;
		;; Also, for each command, a 16-bit constants, *_MAPIN is
		;; defined.  This is used by the 16-bit interface to the
		;; provider VxDs to control the mapping of segmented 16:16
		;; FARPTRs to flat 0:32 FARPTRs within the command
		;; parameter structures.  Each structure is considered to be
		;; a sequence of one or more dwordS.  All FARPTRs that must
		;; be mapped MUST appear FIRST in the command structures.
		;; The *_MAPIN constant specifies how many parameters should
		;; be mapped for each command.
		;;
		;; Note also that the LPSOCK_INFO FARPTRs are not mapped,
		;; since they are opaque at the application level.
		;; ApcRoutine fields are not mapped either, since 32-bit
		;; APCs are scheduled via VWIN32, and 16-bit APCs are called
		;; directly.
		;;
		;; D A N G E R ! !   W A R N I N G ! !   D A N G E R ! !
		;;
		;; IF YOU CHANGE ANY FIELDS IN ANY OF THESE structures,
		;; ENSURE THE *_MAPIN CONSTANT REMAINS ACCURATE!  IF YOU
		;; DON'T, YOU'LL BREAK 16-BIT WINSOCK!!
		;;
		;; D A N G E R ! !   W A R N I N G ! !   D A N G E R ! !

                WS2_FIRST_CMD         	equ   	0100h
                WS2_ACCEPT_CMD        	equ	WS2_FIRST_CMD + 0000h
                WS2_BIND_CMD          	equ     WS2_FIRST_CMD + 0001h
                WS2_CLOSESOCKET_CMD   	equ	WS2_FIRST_CMD + 0002h
                WS2_CONNECT_CMD       	equ	WS2_FIRST_CMD + 0003h
                WS2_GETPEERNAME_CMD   	equ	WS2_FIRST_CMD + 0004h
                WS2_GETSOCKNAME_CMD   	equ	WS2_FIRST_CMD + 0005h
                WS2_GETSOCKOPT_CMD    	equ	WS2_FIRST_CMD + 0006h
                WS2_IOCTLSOCKET_CMD   	equ	WS2_FIRST_CMD + 0007h
                WS2_LISTEN_CMD        	equ	WS2_FIRST_CMD + 0008h
                WS2_RECV_CMD          	equ	WS2_FIRST_CMD + 0009h
                WS2_SELECT_SETUP_CMD  	equ	WS2_FIRST_CMD + 000Ah
                WS2_SELECT_CLEANUP_CMD 	equ	WS2_FIRST_CMD + 000Bh
                WS2_ASYNC_SELECT_CMD  	equ	WS2_FIRST_CMD + 000Ch
                WS2_SEND_CMD          	equ	WS2_FIRST_CMD + 000Dh
                WS2_SETSOCKOPT_CMD    	equ	WS2_FIRST_CMD + 000Eh
                WS2_SHUTDOWN_CMD      	equ	WS2_FIRST_CMD + 000Fh
                WS2_SOCKET_CMD        	equ	WS2_FIRST_CMD + 0010h

                WS2_CANCELEVENT_CMD     equ 	WS2_FIRST_CMD + 0011h

                WS2_INSTALLEVENTHANDLER_CMD equ WS2_FIRST_CMD + 0013h

                WS2_GETTHREADHANDLE_CMD equ 	WS2_FIRST_CMD + 0016h
                WS2_CALLTHREADPROC_CMD  equ 	WS2_FIRST_CMD + 0017h

                WS2_GETSOCKPROTOCOL_CMD equ 	WS2_FIRST_CMD + 001Ah
                WS2_GETSOCKINFO_CMD	equ 	WS2_FIRST_CMD + 001Bh

                ;;
                WS2_FD_FAILED_CONNECT equ 0100h

;;::::::::::::::
;; Socket APIs.
;; [v1c]: all _PARAMS from struct's names taken out (they were too noisy :P)

WS2_ACCEPT 	struct 1
		Address			LPVOID	?
		ListeningSocket		LPSOCK_INFO ?
		ConnectedSocket		LPSOCK_INFO ?
		AddressLength           dword   ?
		ConnectedSocketHandle   dword   ?
		ApcRoutine		LPVOID	?
		ApcContext              dword   ?
       		AcceptFamily     	dword	?
       		GetExtInfo       	dword	?
       		Unknown          	dword	?
       		LocalNamePtr     	LPVOID	? ;; BUG: can't MAPIN
       		LocalNameLen     	dword	?
       		PeerNamePtr      	LPVOID	? ;; /
       		PeerNameLen      	dword	?
       		Unknown2         	dword	?
WS2_ACCEPT 	ends
		LPWS2_ACCEPT		typedef FARPTR WS2_ACCEPT
		WS2_ACCEPT_MAPIN	equ	1

WS2_BIND 	struct 1
		Address			LPVOID	?
		Socket			LPSOCK_INFO ?
		AddressLength           dword   ?
		ApcRoutine		LPVOID	?
		ApcContext              dword   ?
		ConnFamily       	dword	?
WS2_BIND 	ends
		LPWS2_BIND 		typedef FARPTR WS2_BIND
		WS2_BIND_MAPIN		equ	1

WS2_CLOSESOCKET struct 1
		Socket			LPSOCK_INFO ?
WS2_CLOSESOCKET ends
		LPWS2_CLOSESOCKET 	typedef FARPTR WS2_CLOSESOCKET
		WS2_CLOSESOCKET_MAPIN	equ 	0

WS2_CONNECT	struct 1
		Address			LPVOID	?
		Socket			LPSOCK_INFO ?
		AddressLength           dword	?
		ApcRoutine		LPVOID	?
		ApcContext              dword	?
		ConnEvent        	dword	?
WS2_CONNECT ends
		LPWS2_CONNECT  		typedef FARPTR WS2_CONNECT
		WS2_CONNECT_MAPIN	equ	1

WS2_GETPEERNAME struct 1
		Address			LPVOID	?
		Socket			LPSOCK_INFO ?
		AddressLength           dword   ?
WS2_GETPEERNAME ends
		LPWS2_GETPEERNAME 	typedef FARPTR WS2_GETPEERNAME
		WS2_GETPEERNAME_MAPIN	equ	1

WS2_GETSOCKNAME struct 1
		Address			LPVOID	?
		Socket			LPSOCK_INFO ?
		AddressLength           dword	?
WS2_GETSOCKNAME ends
		LPWS2_GETSOCKNAME 	typedef FARPTR WS2_GETSOCKNAME
		WS2_GETSOCKNAME_MAPIN	equ	1

WS2_GETSOCKOPT struct 1
		Value			LPVOID	?
		Socket			LPSOCK_INFO ?
		OptionLevel             dword   ?
		OptionName              dword   ?
		ValueLength             dword   ?
		IntValue                dword   ?
WS2_GETSOCKOPT ends
		LPWS2_GETSOCKOPT 	typedef FARPTR WS2_GETSOCKOPT
		WS2_GETSOCKOPT_MAPIN	equ	1

WS2_IOCTLSOCKET struct 1
		Socket			LPSOCK_INFO ?
		Command         	dword   ?
		Param           	dword	?
                Unknown1                dword   2 dup (?)
                ;; [v1c]: WSock2 returns an EFAULT error if not setting
                ;;        the WSock2Version field with a value >= 4
                WSock2Version           dword   ?
                Unknown2                dword   5 dup (?)
       		Buffer           	LPVOID	? ;; BUG: can't MAPIN
WS2_IOCTLSOCKET ends
		LPWS2_IOCTLSOCKET 	typedef FARPTR WS2_IOCTLSOCKET
		WS2_IOCTLSOCKET_MAPIN	equ	0

WS2_LISTEN 	struct 1
		Socket			LPSOCK_INFO ?
		BacklogSize         	dword 	?
WS2_LISTEN 	ends
		LPWS2_LISTEN   		typedef	FARPTR WS2_LISTEN
		WS2_LISTEN_MAPIN	equ	0

WS2_RECV 	struct 1
		Buffers			LPWSABUF ?
		Address			LPVOID	?
		AddrLenPtr       	LPVOID	?
		Socket			LPSOCK_INFO ?
		BufferCount            	dword   ?
		AddressLength           dword   ?
		Flags           	dword   ?
		BytesReceived           dword   ?
		ApcRoutine		LPVOID	?
		ApcContext              dword   ?
       		Unknown3         	dword	2 dup (?)
       		Overlapped       	LPWSAOVERLAPPED ? ;; BUG: can't MAPIN
WS2_RECV 	ends
		LPWS2_RECV		typedef FARPTR WS2_RECV
		WS2_RECV_MAPIN		equ	4 ;; BUG: should be 3

WS2_SELECT_SETUP struct 1
		ReadList		LPSOCK_LIST ?
		WriteList		LPSOCK_LIST ?
		ExceptList		LPSOCK_LIST ?
		ReadCount               dword   ?
		WriteCount              dword   ?
		ExceptCount             dword   ?
		ApcRoutine		LPVOID	?
		ApcContext              dword	?
WS2_SELECT_SETUP ends
		LPWS2_SELECT_SETUP 	typedef FARPTR WS2_SELECT_SETUP
		WS2_SELECT_SETUP_MAPIN 	equ	3

WS2_SELECT_CLEANUP struct 1
		ReadList		LPSOCK_LIST ?
		WriteList		LPSOCK_LIST ?
		ExceptList		LPSOCK_LIST ?
		ReadCount               dword	?
		WriteCount              dword   ?
		ExceptCount             dword   ?
WS2_SELECT_CLEANUP ends
		LPWS2_SELECT_CLEANUP 	typedef FARPTR WS2_SELECT_CLEANUP
		WS2_SELECT_CLEANUP_MAPIN equ	3

WS2_ASYNC_SELECT struct 1
		Socket			LPSOCK_INFO ?
		Window          	dword   ?
		Message         	dword   ?
		Events          	dword	?
WS2_ASYNC_SELECT ends
		LPWS2_ASYNC_SELECT 	typedef FARPTR WS2_ASYNC_SELECT
		WS2_ASYNC_SELECT_MAPIN 	equ	0

WS2_SEND 	struct 1
		Buffers			LPWSABUF ?
		Address			LPVOID	?
		Socket			LPSOCK_INFO ?
		BufferCount            	dword   ?
		AddrLenPtr       	LPVOID	? ;; BUG: can't MAPIN
		Flags           	dword   ?
		AddressLength           dword   ?
		BytesSent               dword   ?
		ApcRoutine		LPVOID	?
		ApcContext              dword   ?
		Unknown4         	dword	3 dup (?)
WS2_SEND 	ends
		LPWS2_SEND		typedef	FARPTR WS2_SEND
		WS2_SEND_MAPIN		equ	3 ;; BUG: see BUG above

WS2_SETSOCKOPT	struct 1
		Value			LPVOID	?
		Socket			LPSOCK_INFO ?
		OptionLevel             dword   ?
		OptionName              dword   ?
		ValueLength             dword   ?
		IntValue                dword   ?
WS2_SETSOCKOPT	ends
		LPWS2_SETSOCKOPT 	typedef FARPTR WS2_SETSOCKOPT
		WS2_SETSOCKOPT_MAPIN	equ	1

WS2_SOCKET 	struct 1
		Family           	dword	?
		SocketType              dword   ?
		Protocol                dword   ?
		NewSocket		LPSOCK_INFO ?
		NewSocketHandle         dword   ?
       		ProtocolCatalogID	dword	?
       		GroupID          	dword	?
       		Flags            	dword	?
WS2_SOCKET 	ends
		LPWS2_SOCKET   		typedef	FARPTR WS2_SOCKET
		WS2_SOCKET_MAPIN	equ	0

WS2_SHUTDOWN 	struct 1
		Socket			LPSOCK_INFO ?
		How             	dword	?
WS2_SHUTDOWN 	ends
		LPWS2_SHUTDOWN 		typedef	FARPTR WS2_SHUTDOWN
		WS2_SHUTDOWN_MAPIN	equ	0


;;::::::::::::::
;;

WS2_INSTALLEVENTHANDLER	struct 1
       		PostMessageCallBack  	LPVOID	?
       		Pad                  	byte	16 dup (?)
WS2_INSTALLEVENTHANDLER ends
		LPWS2_INSTALLEVENTHANDLER typedef FARPTR WS2_INSTALLEVENTHANDLER

WS2_GETTHREADHANDLE struct 1
		ThreadHandle		dword	?
WS2_GETTHREADHANDLE ends
		LPWS2_GETTHREADHANDLE	typedef FARPTR WS2_GETTHREADHANDLE

WS2_GETSOCKPROTOCOL struct 1
       		Socket               	LPSOCK_INFO ?
       		ProtocolCatalogID    	dword	?
       		Unknown              	dword	?
WS2_GETSOCKPROTOCOL ends
		LPWS2_GETSOCKPROTOCOL	typedef	FARPTR WS2_GETSOCKPROTOCOL

WS2_GETSOCKINFO	struct 1
       		Socket               	LPSOCK_INFO ?
       		Buffer               	LPVOID	?
       		_Length               	dword	?
WS2_GETSOCKINFO	ends
		LPWS2_GETSOCKINFO	typedef	FARPTR WS2_GETSOCKINFO

endif           ;; __WSOCK2_INC__
