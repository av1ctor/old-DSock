;;
;; dsockvxd.inc -- DSOCK VxD services/structs
;;

ifndef          __DSOCKVXD_INC__
                __DSOCKVXD_INC__ equ 1

		DSVXD_TRUE		equ	1
		DSVXD_FALSE		equ	0

                ;; ver 0.5 (using 8.8)
                DSVXD_VHIG         	equ     0
                DSVXD_VLOW         	equ     128

        ;; dsock services
@enum		DSVXD_CMDS
		@const 	DSVXD_VERSION_CMD, 1
		@const 	DSVXD_INIT_CMD
		@const 	DSVXD_END_CMD

		@const 	DSVXD_MSG_CMD		;; dioc only!

		@const 	DSVXD_STARTUP_CMD
		@const 	DSVXD_CLEANUP_CMD
		@const	DSVXD_GETLASTERROR_CMD
		@const 	DSVXD_ASYNC_SELECT_CMD

		@const 	DSVXD_HOSTBYADDR_CMD
		@const 	DSVXD_HOSTBYNAME_CMD
		@const 	DSVXD_HOSTNAME_CMD
		@const 	DSVXD_SERVBYPORT_CMD
		@const 	DSVXD_SERVBYNAME_CMD
		@const 	DSVXD_PROTOBYNUMBER_CMD
		@const 	DSVXD_PROTOBYNAME_CMD

		@const 	DSVXD_RECV_CMD
		@const 	DSVXD_SEND_CMD
@end
		DSVXD_WS16START		equ	DSVXD_STARTUP_CMD

		DSVXD_SELECTORS		equ	2

WS16_STARTUP    struct 1
		_lpWSAData		dword	?	;; 6, 8
		_wVersionRequested	word	?	;; A
WS16_STARTUP	ends

DSVXD_STARTUP	struct 4
		params			WS16_STARTUP <>		;; off:0!!!
		vm_ctx			dword	?
DSVXD_STARTUP	ends


DSVXD_ASYNC_SEL	struct 4
		params			WS2_ASYNC_SELECT <>	;; off:0!!!
                cbuf			dword	?
                fpWrkFlag		dword	?
		vm_ctx			dword	?
DSVXD_ASYNC_SEL	ends


DSVXD_SEND	struct 4
		params			WS2_SEND <>		;; off:0!!!
		buf2lin			dword	?
DSVXD_SEND	ends

DSVXD_RECV	struct 4
		params			WS2_RECV <>		;; off:0!!!
		buf2lin			dword	?
DSVXD_RECV	ends


WS16_HOSTBYADDR struct 1
		_type			word	?	;; 6
		_len			word	?	;; 8
		_addr			dword	?	;; A, C
WS16_HOSTBYADDR	ends

DSVXD_HOSTBYADDR struct 4
		params			WS16_HOSTBYADDR <>	;; off:0!!!
		vm_ctx			dword	?
DSVXD_HOSTBYADDR ends


WS16_HOSTBYNAME struct 1
		_name			dword	?	;; 6
WS16_HOSTBYNAME	ends

DSVXD_HOSTBYNAME struct 4
		params			WS16_HOSTBYNAME <>	;; off:0!!!
		vm_ctx			dword	?
DSVXD_HOSTBYNAME ends


WS16_HOSTNAME   struct 1
		_namelen		word	?	;; 6
		_name			dword	?	;; 8, A
WS16_HOSTNAME	ends

DSVXD_HOSTNAME	struct 4
		params			WS16_HOSTNAME <>	;; off:0!!!
		vm_ctx			dword	?
DSVXD_HOSTNAME	ends


WS16_SERVBYPORT struct 1
		_proto			dword	?	;; 6, 8
		_port			word	?	;; A
WS16_SERVBYPORT	ends

DSVXD_SERVBYPORT struct 4
		params			WS16_SERVBYPORT <>	;; off:0!!!
		vm_ctx			dword	?
DSVXD_SERVBYPORT ends


WS16_SERVBYNAME struct 1
		_proto			dword	?	;; 6, 8
		_name			dword	?	;; A, C
WS16_SERVBYNAME	ends

DSVXD_SERVBYNAME struct	4
		params			WS16_SERVBYNAME <>	;; off:0!!!
		vm_ctx			dword	?
DSVXD_SERVBYNAME ends


WS16_PROTOBYNUMBER struct 1
		_number			word	?	;; 6
WS16_PROTOBYNUMBER ends

DSVXD_PROTOBYNUMBER struct 4
		params			WS16_PROTOBYNUMBER <>	;; off:0!!!
DSVXD_PROTOBYNUMBER ends


WS16_PROTOBYNAME struct 1
		_name			dword	?	;; 6, 8
WS16_PROTOBYNAME ends

DSVXD_PROTOBYNAME struct 4
		params			WS16_PROTOBYNAME <>	;; off:0!!!
		vm_ctx			dword	?
DSVXD_PROTOBYNAME ends


DSVXD_MSG       struct 4
		wMsg			dword	?	;; WM_USER + vm id
		wParam			dword	?	;; socket
		lParam			dword	?	;; error:event
DSVXD_MSG	ends

ifndef	WM_USER
		WM_USER			equ	400h
endif
        WM_DSOCK        equ WM_USER + 100h

endif           ;; __DSOCKVXD_INC__
