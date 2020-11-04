;;
;; dsockvdd.inc -- DSOCK VDD services/structs
;;

ifndef          __DSOCKVDD_INC__
                __DSOCKVDD_INC__ equ 1

                ;; ver 0.5 (using 8.8)
                DSVDD_VHIG         	equ     0
                DSVDD_VLOW         	equ     128

        ;; dsock services
@enum		DSVDD_CMDS
		@const	DSVDD_INIT_CMD
		@const	DSVDD_END_CMD

		@const	DSVDD_STARTUP_CMD
		@const	DSVDD_CLEANUP_CMD
		@const	DSVDD_GETLASTERROR_CMD
		@const	DSVDD_SETLASTERROR_CMD
		@const	DSVDD_ASYNCSEL_CMD

		@const	DSVDD_ACCEPT_CMD
		@const	DSVDD_BIND_CMD
		@const	DSVDD_CLOSESOCKET_CMD
		@const	DSVDD_CONNECT_CMD
		@const	DSVDD_GETPEERNAME_CMD
		@const	DSVDD_GETSOCKNAME_CMD
		@const	DSVDD_GETSOCKOPT_CMD
		@const	DSVDD_HTONL_CMD
		@const	DSVDD_HTONS_CMD
		@const	DSVDD_INET_ADDR_CMD
		@const	DSVDD_INET_NTOA_CMD
		@const	DSVDD_IOCTLSOCKET_CMD
		@const	DSVDD_LISTEN_CMD
		@const	DSVDD_NTOHL_CMD
		@const	DSVDD_NTOHS_CMD
		@const	DSVDD_RECV_CMD
		@const	DSVDD_RECVFROM_CMD
		@const	DSVDD_SELECT_CMD
		@const	DSVDD_SEND_CMD
		@const	DSVDD_SENDTO_CMD
		@const	DSVDD_SETSOCKOPT_CMD
		@const	DSVDD_SHUTDOWN_CMD
		@const	DSVDD_SOCKET_CMD

		@const	DSVDD_GETHOSTBYADDR_CMD
		@const	DSVDD_GETHOSTBYNAME_CMD
		@const	DSVDD_GETHOSTNAME_CMD
		@const	DSVDD_GETSERVBYPORT_CMD
		@const	DSVDD_GETSERVBYNAME_CMD
		@const	DSVDD_GETPROTOBYNUMBER_CMD
		@const	DSVDD_GETPROTOBYNAME_CMD
@end

DSVDD_STARTUP	struct 4
		_lpWSAData		dword	?
		_wVersionRequested	dword	?
		result			dword	?
DSVDD_STARTUP	ends
		DSVDD_STARTUP_MAPIN	equ	1

DSVDD_CLEANUP	struct 4
		result			dword	?
		error			dword	?
DSVDD_CLEANUP	ends
		DSVDD_CLEANUP_MAPIN	equ	0

DSVDD_GETLASTERROR struct 4
		result			dword	?
DSVDD_GETLASTERROR ends
		DSVDD_GETLASTERROR_MAPIN equ	0

DSVDD_SETLASTERROR struct 4
		_iError			dword	?
DSVDD_SETLASTERROR ends
		DSVDD_SETLASTERROR_MAPIN equ	0

DSVDD_ASYNCSEL	struct 4
                _s			dword	?
                _wMsg			dword	?
                _lEvent			dword	?
                _cbuf			dword	?
                _fpWrkFlag		dword	?
                result			dword	?
                error			dword	?
DSVDD_ASYNCSEL	ends
		DSVDD_ASYNCSEL_MAPIN	equ	0


DSVDD_ACCEPT	struct 4
		_addr			dword	?
		_addrlen		dword	?
		_s			dword	?
		result			dword	?
		error			dword	?
DSVDD_ACCEPT	ends
		DSVDD_ACCEPT_MAPIN	equ	2

DSVDD_BIND	struct 4
		_name			dword	?
		_s			dword	?
		_namelen		dword	?
		result			dword	?
		error			dword	?
DSVDD_BIND	ends
		DSVDD_BIND_MAPIN	equ	1

DSVDD_CLOSESOCKET struct 4
		_s			dword	?
		result			dword	?
		error			dword	?
DSVDD_CLOSESOCKET ends
		DSVDD_CLOSESOCKET_MAPIN	equ	0

DSVDD_CONNECT	struct 4
		_name			dword	?
		_s			dword	?
		_namelen		dword	?
		result			dword	?
		error			dword	?
DSVDD_CONNECT	ends
		DSVDD_CONNECT_MAPIN	equ	1

DSVDD_GETPEERNAME struct 4
		_name			dword	?
		_namelen		dword	?
		_s			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETPEERNAME ends
		DSVDD_GETPEERNAME_MAPIN	equ	2

DSVDD_GETSOCKNAME struct 4
		_name			dword	?
		_namelen		dword	?
		_s			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETSOCKNAME ends
		DSVDD_GETSOCKNAME_MAPIN	equ	2

DSVDD_GETSOCKOPT struct 4
		_optval			dword	?
		_optlen			dword	?
		_s			dword	?
		_level			dword	?
		_optname		dword	?
		result			dword	?
		error			dword	?
DSVDD_GETSOCKOPT ends
		DSVDD_GETSOCKOPT_MAPIN	equ	2

DSVDD_HTONL	struct 4
		_hostlong		dword	?
		result			dword	?
		error			dword	?
DSVDD_HTONL	ends
		DSVDD_HTONL_MAPIN	equ	0

DSVDD_HTONS	struct 4
		_hostshort		dword	?
		result			dword	?
		error			dword	?
DSVDD_HTONS	ends
		DSVDD_HTONS_MAPIN	equ	0

DSVDD_INET_ADDR	struct 4
		_cp			dword	?
		result			dword	?
		error			dword	?
DSVDD_INET_ADDR	ends
		DSVDD_INET_ADDR_MAPIN	equ	1

DSVDD_INET_NTOA	struct 4
		_in			dword	?
		result			dword	?
		error			dword	?
DSVDD_INET_NTOA	ends
		DSVDD_INET_NTOA_MAPIN	equ	0

DSVDD_IOCTLSOCKET struct 4
		_argp			dword	?
		_s			dword	?
		_cmd			dword	?
		result			dword	?
		error			dword	?
DSVDD_IOCTLSOCKET ends
		DSVDD_IOCTLSOCKET_MAPIN	equ	1

DSVDD_LISTEN	struct 4
		_s			dword	?
		_backlog		dword	?
		result			dword	?
		error			dword	?
DSVDD_LISTEN	ends
		DSVDD_LISTEN_MAPIN	equ	0

DSVDD_NTOHL	struct 4
		_netlong		dword	?
		result			dword	?
		error			dword	?
DSVDD_NTOHL	ends
		DSVDD_NTOHL_MAPIN	equ	0

DSVDD_NTOHS	struct 4
		_netshort		dword	?
		result			dword	?
		error			dword	?
DSVDD_NTOHS	ends
		DSVDD_NTOHS_MAPIN	equ	0

DSVDD_RECV	struct 4
		_buf			dword	?
		_s			dword	?
		_len			dword	?
		_flags			dword	?
		result			dword	?
		error			dword	?
DSVDD_RECV	ends
		DSVDD_RECV_MAPIN	equ	1

DSVDD_RECVFROM	struct 4
		_buf			dword	?
		_from			dword	?
		_fromlen		dword	?
		_s			dword	?
		_len			dword	?
		_flags			dword	?
		result			dword	?
		error			dword	?
DSVDD_RECVFROM	ends
		DSVDD_RECVFROM_MAPIN	equ	3

DSVDD_SELECT	struct 4
		_readfds		dword	?
		_writefds		dword	?
		_exceptfds		dword	?
		_timeout		dword	?
		_nfds			dword	?
		result			dword	?
		error			dword	?
DSVDD_SELECT	ends
		DSVDD_SELECT_MAPIN	equ	4

DSVDD_SEND	struct 4
		_buf			dword	?
		_s			dword	?
		_len			dword	?
		_flags			dword	?
		result			dword	?
		error			dword	?
DSVDD_SEND	ends
		DSVDD_SEND_MAPIN	equ	1

DSVDD_SENDTO	struct 4
		_buf			dword	?
		_to			dword	?
		_s			dword	?
		_len			dword	?
		_flags			dword	?
		_tolen			dword	?
		result			dword	?
		error			dword	?
DSVDD_SENDTO	ends
		DSVDD_SENDTO_MAPIN	equ	2

DSVDD_SETSOCKOPT struct 4
		_optval			dword	?
		_s			dword	?
		_level			dword	?
		_optname		dword	?
		_optlen			dword	?
		result			dword	?
		error			dword	?
DSVDD_SETSOCKOPT ends
		DSVDD_SETSOCKOPT_MAPIN	equ	1

DSVDD_SHUTDOWN	struct 4
		_s			dword	?
		_how			dword	?
		result			dword	?
		error			dword	?
DSVDD_SHUTDOWN	ends
		DSVDD_SHUTDOWN_MAPIN	equ	0

DSVDD_SOCKET	struct 4
		_af			dword	?
		_type			dword	?
		_protocol		dword	?
		result			dword	?
		error			dword	?
DSVDD_SOCKET	ends
                DSVDD_SOCKET_MAPIN	equ	0


DSVDD_GETHOSTBYADDR struct 4
		_addr			dword	?
		_len			dword	?
		_type			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETHOSTBYADDR ends
		DSVDD_GETHOSTBYADDR_MAPIN equ	1

DSVDD_GETHOSTBYNAME struct 4
		_name			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETHOSTBYNAME ends
		DSVDD_GETHOSTBYNAME_MAPIN equ	1

DSVDD_GETHOSTNAME	struct 4
		_name			dword	?
		_namelen		dword	?
		result			dword	?
		error			dword	?
DSVDD_GETHOSTNAME	ends
		DSVDD_GETHOSTNAME_MAPIN	equ	1

DSVDD_GETSERVBYPORT struct 4
		_proto			dword	?
		_port			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETSERVBYPORT ends
		DSVDD_GETSERVBYPORT_MAPIN equ	1

DSVDD_GETSERVBYNAME struct	4
		_name			dword	?
		_proto			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETSERVBYNAME ends
		DSVDD_GETSERVBYNAME_MAPIN equ	2

DSVDD_GETPROTOBYNUMBER struct 4
		_number			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETPROTOBYNUMBER ends
		DSVDD_GETPROTOBYNUMBER_MAPIN equ 0

DSVDD_GETPROTOBYNAME struct 4
		_name			dword	?
		result			dword	?
		error			dword	?
DSVDD_GETPROTOBYNAME ends
		DSVDD_GETPROTOBYNAME_MAPIN equ	1


ifndef	WM_USER
		WM_USER			equ	400h
endif
        WM_DSOCK        equ WM_USER + 100h

		DSVDD_IRQ		equ	3	;; COM2/4

DSVDD_MSG	struct
		wMsg			dword	?
		wParam			dword	?
		lParam			dword	?
DSVDD_MSG	ends

endif           ;; __DSOCKVDD_INC__
