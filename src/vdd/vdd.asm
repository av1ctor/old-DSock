;;
;; vdd.cpp -- the VDD itself (d'uh!)
;;

		.386
		.model	flat, stdcall
		option	proc:private

		include	windows.inc
		include	equ.inc
		include vdd.inc
        	include dsockvdd.inc
		include	llist.inc
		include	cbuf.inc

		include kernel32.inc
		include user32.inc

		includelib kernel32.lib
		includelib user32.lib

ASYNCSELCB      struct 4
		id			dword	?
		socket			dword	?
		cbuf			dword	?
		pWrkFlag		dword	?
		wMsg			dword	?
ASYNCSELCB	ends


NTVDM 		struct 4
		@procptr getEAX
		@procptr getEBX
		@procptr getECX
		@procptr getEDX
		@procptr getESP
		@procptr getEBP
		@procptr getESI
		@procptr getEDI
		@procptr getIP
		@procptr getCS
		@procptr getSS
		@procptr getDS
		@procptr getES
		@procptr getCF

		@procptr setEAX, <value:dword>
		@procptr setEBX, <value:dword>
		@procptr setECX, <value:dword>
		@procptr setEDX, <value:dword>
		@procptr setESP, <value:dword>
		@procptr setEBP, <value:dword>
		@procptr setESI, <value:dword>
		@procptr setEDI, <value:dword>
                @procptr setIP, <value:word>
                @procptr setCS, <value:word>
                @procptr setSS, <value:word>
                @procptr setDS, <value:word>
                @procptr setES, <value:word>
		@procptr setCF, <value:dword>

		@procptr GetVDMPointer, <address:dword, _size:dword, mode:dword>

	        @procptr VDDSimulateInterrupt, <ms:dword, line:byte, count:dword>

		@procptr VDDInstallUserHook, <hVDD:dword, Ucr:dword, Uterm:dword, Ublock:dword, Uresume:dword>
NTVDM		ends

WS2_32		struct 4
		@procptr WSAStartup, <wVersionRequested:dword, lpWSAData:ptr WSADATA>
		@procptr WSACleanup
		@procptr WSAGetLastError
		@procptr WSASetLastError, <iError:dword>
		@procptr WSAAsyncSelect, <s:SOCKET, hWnd:HWND, wMsg:dword, lEvent:dword>

		@procptr accept, <s:SOCKET, _addr:ptr sockaddr, addrlen:ptr dword>
		@procptr bind, <s:SOCKET, _name:ptr sockaddr, namelen:dword>
		@procptr closesocket, <s:SOCKET>
		@procptr connect, <s:SOCKET, _name:ptr sockaddr, namelen:dword>
		@procptr getpeername, <s:SOCKET, _name:ptr sockaddr, namelen:ptr dword>
		@procptr getsockname, <s:SOCKET, _name:ptr sockaddr, namelen:ptr dword>
		@procptr getsockopt, <s:SOCKET, level:dword, optname:dword, optval:ptr byte, optlen:ptr dword>
		@procptr htonl, <hostlong:dword>
		@procptr htons, <hostshort:dword>
		@procptr inet_addr, <cp:ptr byte>
		@procptr inet_ntoa, <_in:dword>
		@procptr ioctlsocket, <s:SOCKET, cmd:dword, argp:ptr dword>
		@procptr listen, <s:SOCKET, backlog:dword>
		@procptr ntohl, <netlong:dword>
		@procptr ntohs, <netshort:dword>
		@procptr recv, <s:SOCKET, buf:ptr byte, len:dword, flags:dword>
		@procptr recvfrom, <s:SOCKET, buf:ptr byte, len:dword, flags:dword, from:ptr sockaddr, fromlen:ptr dword>
		@procptr select, <nfds:dword, readfds:ptr fds_set, writefds:ptr fds_set, exceptfds:ptr fds_set, timeout:ptr timeval>
		@procptr send, <s:SOCKET, buf:ptr byte, len:dword, flags:dword>
		@procptr sendto, <s:SOCKET, buf:ptr byte, len:dword, flags:dword, to:ptr sockaddr, tolen:dword>
		@procptr setsockopt, <s:SOCKET, level:dword, optname:dword, optval:ptr byte, optlen:dword>
		@procptr shutdown, <s:SOCKET, how:dword>
		@procptr socket, <af:dword, _type:dword, protocol:dword>

		@procptr gethostbyaddr, <_addr:ptr byte, len:dword, _type:dword>
		@procptr gethostbyname, <_name:ptr byte>
		@procptr gethostname, <_name:ptr byte, namelen:dword>
		@procptr getservbyport, <port:dword, _proto:ptr byte>
		@procptr getservbyname, <_name:ptr byte, _proto:ptr byte>
		@procptr getprotobynumber, <number:dword>
		@procptr getprotobyname, <_name:ptr byte>
WS2_32		ends

.const
ntvdm_zs	byte	"NTVDM.EXE", 0
ntvdm_plist	label byte
		@pstrz  , "getEAX"
		@pstrz  , "getEBX"
		@pstrz  , "getECX"
		@pstrz  , "getEDX"
		@pstrz  , "getESP"
		@pstrz  , "getEBP"
		@pstrz  , "getESI"
		@pstrz  , "getEDI"
		@pstrz  , "getIP"
		@pstrz  , "getCS"
		@pstrz  , "getSS"
		@pstrz  , "getDS"
		@pstrz  , "getES"
		@pstrz  , "getCF"

		@pstrz  , "setEAX"
		@pstrz  , "setEBX"
		@pstrz  , "setECX"
		@pstrz  , "setEDX"
		@pstrz  , "setESP"
		@pstrz  , "setEBP"
		@pstrz  , "setESI"
		@pstrz  , "setEDI"
		@pstrz  , "setIP"
		@pstrz  , "setCS"
		@pstrz  , "setSS"
		@pstrz  , "setDS"
		@pstrz  , "setES"
		@pstrz  , "setCF"

		@pstrz  , "MGetVdmPointer"

		@pstrz  , "call_ica_hw_interrupt"

		@pstrz  , "VDDInstallUserHook"
                word    0                       ;; EOL!!!

ws2_32_zs	byte	"ws2_32.dll", 0
ws2_32_plist	label byte
		@pstrz	, "WSAStartup"
		@pstrz	, "WSACleanup"
		@pstrz	, "WSAGetLastError"
		@pstrz	, "WSASetLastError"
		@pstrz	, "WSAAsyncSelect"

		@pstrz	, "accept"
		@pstrz	, "bind"
		@pstrz	, "closesocket"
		@pstrz	, "connect"
		@pstrz	, "getpeername"
		@pstrz	, "getsockname"
		@pstrz	, "getsockopt"
		@pstrz	, "htonl"
		@pstrz	, "htons"
		@pstrz	, "inet_addr"
		@pstrz	, "inet_ntoa"
		@pstrz	, "ioctlsocket"
		@pstrz	, "listen"
		@pstrz	, "ntohl"
		@pstrz	, "ntohs"
		@pstrz	, "recv"
		@pstrz	, "recvfrom"
		@pstrz	, "select"
		@pstrz	, "send"
		@pstrz	, "sendto"
		@pstrz	, "setsockopt"
		@pstrz	, "shutdown"
		@pstrz	, "socket"

		@pstrz	, "gethostbyaddr"
		@pstrz	, "gethostbyname"
		@pstrz	, "gethostname"
		@pstrz	, "getservbyport"
		@pstrz	, "getservbyname"
		@pstrz	, "getprotobynumber"
		@pstrz	, "getprotobyname"
		word    0                       ;; EOL!!!

dispatch_tb	label   dword
		dword	O _init
		dword	O _end

		dword	O _WSAStartup
		dword	O _WSACleanup
		dword	O _WSAGetLastError
		dword	O _WSASetLastError
		dword	O _WSAAsyncSelect

		dword	O _accept
		dword	O _bind
		dword	O _closesocket
		dword	O _connect
		dword	O _getpeername
		dword	O _getsockname
		dword	O _getsockopt
		dword	O _htonl
		dword	O _htons
		dword	O _inet_addr
		dword	O _inet_ntoa
		dword	O _ioctlsocket
		dword	O _listen
		dword	O _ntohl
		dword	O _ntohs
		dword	O _recv
		dword	O _recvfrom
		dword	O _select
		dword	O _send
		dword	O _sendto
		dword	O _setsockopt
		dword	O _shutdown
		dword	O _socket

		dword	O _gethostbyaddr
		dword	O _gethostbyname
		dword	O _gethostname
		dword	O _getservbyport
		dword	O _getservbyname
		dword	O _getprotobynumber
		dword	O _getprotobyname
                DISP_SERVICES   	equ     ($-dispatch_tb) / 4

dsock_zs    byte    "DSock", 0

.data?
hInstance 	HINSTANCE ?

hThread		dword	?
threadID	dword	?
hWnd		dword	?

started_cnt	dword	?
hList		LLST	<?>
hMutex		dword	?

sint_hSem	dword	?
sint_hThread	dword	?

isPMode		dword	?
is32bit		dword	?

hNTVDM          dword   ?
ntvdm		NTVDM	<?>

hWS2_32         dword   ?
ws2_32		WS2_32	<?>

.data
initialized	dword	FALSE


.code
;;::::::::::::::
vdd_DllMain	proc	public\
			Reason:dword,\
			DllHandle:PVOID

		cmp	Reason, DLL_PROCESS_ATTACH
		jne	@@detach

		mov	eax, DllHandle
		mov	hInstance, eax

@@done:		mov	eax, TRUE

@@exit:		ret

@@detach:	cmp	Reason, DLL_PROCESS_DETACH
		jne	@@done

		cmp	hNTVDM, 0
		je	@F
		invoke	FreeLibrary, hNTVDM
		mov	hNTVDM, 0

@@:		cmp	hWS2_32, 0
		je	@F
		invoke	FreeLibrary, hWS2_32
		mov	hWS2_32, 0
@@:		jmp	short @@done
vdd_DllMain	endp

;;:::
h_loadlib	proc	uses edi esi,
			libname:ptr byte,\
			procstruct:ptr,\
			proclist:ptr byte
		local	handle:dword

		invoke	LoadLibrary, libname
		mov	handle, eax
		test	eax, eax
		jz	@@exit

		;; get proc addresses
		mov	esi, proclist
		mov	edi, procstruct
		jmp	short @@test

@@loop:         mov	edx, esi
		add	esi, eax		;; next proc
		invoke	GetProcAddress, handle, edx
		test	eax, eax
		jz	@@error
		mov	[edi], eax		;; (PVOID)ntvdm[i]= proc addr
		add	edi, T dword		;; ++i

@@test:         movzx   eax, W [esi]            ;; get proc name size
		add	esi, T word
		test	eax, eax
		jnz	@@loop			;; not last proc?

@@exit:		mov	eax, handle
		ret

@@error:	invoke	FreeLibrary, handle
		mov	handle, 0
		jmp	short @@exit
h_loadlib	endp

;;::::::::::::::
DSock_Init  proc    public

		cmp	initialized, TRUE
		je	@@done

		;; load NTVDM.EXE (not really "load", as it's in
		;; the same process as this vdd already) and get
		;; proc addresses
		invoke	h_loadlib, A ntvdm_zs, A ntvdm, A ntvdm_plist
		mov	hNTVDM, eax
		test	eax, eax
		jz	@@exit			;; null?

		mov	initialized, TRUE

@@done:		invoke	ntvdm.setCF, 0

@@exit:		ret
DSock_Init  endp

;;::::::::::::::
DSock_Terminate proc    public
                int 3
                ret
DSock_Terminate endp

;;::::::::::::::
;;  in: edx= service
;;	es:__BX-> params
;;	CF set
;;
;; out: CF set if error
DSock_Dispatch  proc    public uses ebx edi esi

                cmp	initialized, TRUE
                jne	@@error

	        invoke	ntvdm.getEDX
                cmp     eax, DISP_SERVICES
                jae     @@error
                mov	esi, eax

                invoke 	ntvdm.setCF, 0		;; assume no error

                ;; ebx= flat(es:__BX)
                invoke	ntvdm.getES
		mov	edx, eax
		invoke	ntvdm.getEBX
		;; no 32-bit pmode client ptrs here, cause GetVDMPointer
		shl	edx, 16
		and	eax, 0FFFFh
		or	eax, edx
                invoke	ntvdm.GetVDMPointer, eax, 256, isPMode
                mov	ebx, eax

              	call    dispatch_tb[esi * 4]

@@exit:		ret

@@error:;;;;;;;;invoke 	ntvdm.setCF, 1
                jmp     short @@exit
DSock_Dispatch  endp

;;:::
h_aselList_free	proc	near uses edi

		cmp	hList._ptr, NULL
		je	@@exit

@@loop:		invoke	ListLast, A hList
		assume	edi: ptr ASYNCSELCB
		jz	@@exit

		mov	[edi].id, 0		;; just f/ precaution
		mov	[edi].socket, 0		;; /

		invoke	ListFree, A hList, edi
		jmp	short @@loop

@@exit:		ret
h_aselList_free	endp

;;::::::::::::::
;;  in: eax= 0
;;	bx= 0 if in V86-mode (real-mode) or 1 if in pmode (16 or 32 bits)
;;	cx= 0 if 16-bit, 1 if 32-bit
;;
;; out: eax= 'DSCK' if ok
_init		proc	public
		local	tid:dword

                assume	ebx:nothing

		cmp	initialized, TRUE
		jne	@@exit

		;; and ws2_32.dll
		invoke	h_loadlib, A ws2_32_zs, A ws2_32, A ws2_32_plist
		mov	hWS2_32, eax
		test	eax, eax
		jz	@@exit			;; null?

		;; save client mode
		invoke 	ntvdm.getEBX
		and	eax, 0FFFFh
		mov	isPMode, eax

		invoke 	ntvdm.getECX
		and	eax, 0FFFFh
		mov	is32bit, eax

		;; create a mutex for accessing the circular-buffer
		invoke	CreateMutex, NULL, FALSE, NULL
		mov	hMutex, eax
		test	eax, eax
		jz	@@error

		;; allocate ASYNSEL linked-list (must be < 64K!!)
                invoke	ListCreate, A hList, 1024, T ASYNCSELCB
                jc	@@error

		;; create semaphore used to wakeup simint thread
		invoke	CreateSemaphore, NULL, 0, 1023, NULL
		mov	sint_hSem, eax
		test	eax, eax
		jz	@@error

		;; create the simint thread
		simint_thread	proto	near :LPVOID
		invoke	CreateThread, NULL, 4096, simint_thread, NULL, 0, A tid
		mov	sint_hThread, eax
		test	eax, eax
		jz	@@error

		;; run the message loop as a thread
		window_thread	proto	near :LPVOID
		invoke	CreateThread, NULL, 4096, window_thread, NULL, 0, A threadID
		mov	hThread, eax
		test	eax, eax
		jz	@@error

		;; wait for hWnd be set
		xor	eax, eax
@@:		cmp	hWnd, 0
		jne	@F
		dec	eax
		jnz	@B
		jmp	short @@error

@@:		cmp	hWnd, -1
		je	@@error

		invoke 	ntvdm.setEAX, 'DSCK'	;; return ok

@@exit:		ret

@@error:	invoke	FreeLibrary, hWS2_32
		mov	hWS2_32, 0
                jmp	short @@exit
_init		endp

;;::::::::::::::
_end		proc	public
		assume	ebx:nothing

		cmp	initialized, TRUE
		jne	@@exit

		;; finish window thread
		cmp	hThread, 0
		je	@F
		;; tell thread to finish
        	invoke  PostThreadMessage, threadID, WM_DSOCK-1, 0, 0
		;; and wait
		invoke	WaitForSingleObject, hThread, 1000 * 3
                ;; close handle
		invoke	CloseHandle, hThread
		mov	hThread, 0

@@:		;; finish simint thread
		cmp	sint_hThread, 0
		je	@F
		mov	esi, sint_hSem
		mov	sint_hSem, 0
		invoke	ReleaseSemaphore, esi, 1, NULL
		;; and wait
		invoke	WaitForSingleObject, sint_hThread, 1000 * 3
                ;; close handle
		invoke	CloseHandle, sint_hThread
		mov	sint_hThread, 0
		;; destroy semaphore
		invoke	CloseHandle, esi

@@:		;; destroy async sel linked-list
		call	h_aselList_free
		invoke	ListDestroy, A hList

		;; destroy mutex
		cmp	hMutex, 0
		je	@F
		invoke	CloseHandle, hMutex
		mov	hMutex, 0

@@:		;; unload winsock lib
		cmp	hWS2_32, 0
		je	@F
		invoke	FreeLibrary, hWS2_32
		mov	hWS2_32, 0

@@:		;; unload ntvdm
		cmp	hNTVDM, 0
		je	@F
		invoke	FreeLibrary, hNTVDM
		mov	hNTVDM, 0

@@:		mov	initialized, FALSE

@@exit:		ret
_end		endp

;;::::::::::::::
_WSAStartup	proc
		assume	ebx:ptr DSVDD_STARTUP

		MAPIN	ebx, DSVDD_STARTUP

		invoke	ws2_32.WSAStartup, [ebx]._wVersionRequested,\
					   [ebx]._lpWSAData
		mov	[ebx].result, eax

		inc	started_cnt		;; ++counter

		ret
_WSAStartup	endp

;;::::::::::::::
_WSACleanup	proc
                assume	ebx:ptr DSVDD_CLEANUP

		MAPIN	ebx, DSVDD_CLEANUP

		dec	started_cnt		;; --counter
		jnz	@F
		call	h_aselList_free

@@:		invoke	ws2_32.WSACleanup
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_WSACleanup	endp

;;::::::::::::::
_WSAGetLastError proc
                assume	ebx:ptr DSVDD_GETLASTERROR

		MAPIN	ebx, DSVDD_GETLASTERROR

		invoke	ws2_32.WSAGetLastError
                mov	[ebx].result, eax

		ret
_WSAGetLastError endp

;;::::::::::::::
_WSASetLastError proc
                assume	ebx:ptr DSVDD_SETLASTERROR

		MAPIN	ebx, DSVDD_SETLASTERROR

		invoke	ws2_32.WSASetLastError, [ebx]._iError

		ret
_WSASetLastError endp

;;:::
;;  in: eax= socket
;;
;; out: edi= node (0 if not found)
h_aselList_find	proc	near

		invoke	ListLast, A hList
		jz	@@exit
		assume	edi: ptr ASYNCSELCB

@@loop:		cmp	[edi].socket, eax
		je	@@exit			;; curr.socket= socket?
		invoke	ListPrev		;; edi= prev
		jnz	@@loop			;; not last node?

@@exit:		ret
h_aselList_find	endp

;;::::::::::::::
_WSAAsyncSelect proc
		assume	ebx:ptr DSVDD_ASYNCSEL

		MAPIN	ebx, DSVDD_ASYNCSEL

		mov	eax, [ebx]._s
		call	h_aselList_find
		test	edi, edi
		jnz	@F			;; found?

		xor	edi, edi		;; assume NULL node
                cmp     [ebx]._lEvent, 0
		je	@@call			;; no events?

		;; allocate a new node for ASYNCSELCB struct
		invoke	ListAlloc, A hList
		jc	@@error

@@:		assume	edi: ptr ASYNCSELCB

		;; fill node
		mov	[edi].id, 'CB32'
		;; node.socket= _s
		mov	eax, [ebx]._s
		mov	[edi].socket, eax
		;; node.cbuf= fp2flat(_cbuf)
		FP2FLAT	[ebx]._cbuf, <T CBUF>
		mov	[edi].cbuf, eax
		;; node.pWrkFlag= fp2flat(_fpWrkFlag)
		FP2FLAT	[ebx]._fpWrkFlag, <T byte>
		mov	[edi].pWrkFlag, eax
        	;; node.wMsg= _wMsg; _wMsg= WM_DSOCK + (node - list.ptr)
        	lea 	eax, [edi + WM_DSOCK]
		sub	eax, hList._ptr
		xchg	eax, [ebx]._wMsg
		mov	[edi].wMsg, eax

@@call:		;; let ws2_32 do the work
		invoke	ws2_32.WSAAsyncSelect, [ebx]._s,\
					       hWnd,\
					       [ebx]._wMsg,\
					       [ebx]._lEvent
		mov	[ebx].result, eax
		test	eax, eax
		jnz	@@error2		;; error?

		mov	[ebx].error, 0		;; no error

@@done:		cmp	[ebx]._lEvent, 0
		jne	@@exit			;; any event?

		;; delete node
@@:		test	edi, edi
		jz	@@exit			;; NULL node?

@@:		mov	[edi].id, 0		;; just f/ precaution
		mov	[edi].socket, 0		;; /
		invoke	ListFree, A hList, edi

@@exit:		ret

@@error2:	invoke	ws2_32.WSAGetLastError
		mov	[ebx].error, eax
		jmp	short @@done

@@error:	mov	[ebx].result, SOCKET_ERROR
		mov	[ebx].error, 'EINT'	;; internal error
		jmp	short @@exit
_WSAAsyncSelect endp

;;::::::::::::::
_accept		proc
                assume	ebx:ptr DSVDD_ACCEPT

		MAPIN	ebx, DSVDD_ACCEPT

		invoke	ws2_32.accept, [ebx]._s,\
				       [ebx]._addr,\
				       [ebx]._addrlen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                cmp	eax, INVALID_SOCKET
                jne	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_accept		endp

;;::::::::::::::
_bind		proc
                assume	ebx:ptr DSVDD_BIND

		MAPIN	ebx, DSVDD_BIND

		invoke	ws2_32.bind, [ebx]._s,\
				     [ebx]._name,\
				     [ebx]._namelen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_bind		endp

;;::::::::::::::
_closesocket	proc
                assume	ebx:ptr DSVDD_CLOSESOCKET

		MAPIN	ebx, DSVDD_CLOSESOCKET

		invoke	ws2_32.closesocket, [ebx]._s
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_closesocket	endp

;;::::::::::::::
_connect	proc
                assume	ebx:ptr DSVDD_CONNECT

		MAPIN	ebx, DSVDD_CONNECT

		invoke	ws2_32.connect, [ebx]._s,\
					[ebx]._name,\
					[ebx]._namelen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_connect	endp

;;::::::::::::::
_getpeername	proc
                assume	ebx:ptr DSVDD_GETPEERNAME

		MAPIN	ebx, DSVDD_GETPEERNAME

		invoke	ws2_32.getpeername, [ebx]._s,\
					    [ebx]._name,\
					    [ebx]._namelen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_getpeername	endp

;;::::::::::::::
_getsockname	proc
                assume	ebx:ptr DSVDD_GETSOCKNAME

		MAPIN	ebx, DSVDD_GETSOCKNAME

		invoke	ws2_32.getsockname, [ebx]._s,\
					    [ebx]._name,\
					    [ebx]._namelen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_getsockname	endp

;;::::::::::::::
_getsockopt	proc
                assume	ebx:ptr DSVDD_GETSOCKOPT

		MAPIN	ebx, DSVDD_GETSOCKOPT

		invoke	ws2_32.getsockopt, [ebx]._s,\
					   [ebx]._level,\
					   [ebx]._optname,\
					   [ebx]._optval,\
					   [ebx]._optlen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_getsockopt	endp

;;::::::::::::::
_htonl		proc
                assume	ebx:ptr DSVDD_HTONL

		MAPIN	ebx, DSVDD_HTONL

		invoke	ws2_32.htonl, [ebx]._hostlong
                mov	[ebx].result, eax

		ret
_htonl		endp

;;::::::::::::::
_htons		proc
                assume	ebx:ptr DSVDD_HTONS

		MAPIN	ebx, DSVDD_HTONS

		invoke	ws2_32.htons, [ebx]._hostshort
                mov	[ebx].result, eax

		ret
_htons		endp

;;::::::::::::::
_inet_addr	proc
                assume	ebx:ptr DSVDD_INET_ADDR

		MAPIN	ebx, DSVDD_INET_ADDR

		invoke	ws2_32.inet_addr, [ebx]._cp
                mov	[ebx].result, eax

		ret
_inet_addr	endp

;;::::::::::::::
_inet_ntoa	proc
                assume	ebx:ptr DSVDD_INET_NTOA

		MAPIN	ebx, DSVDD_INET_NTOA

		invoke	ws2_32.inet_ntoa, [ebx]._in
                mov	[ebx].result, eax

		ret
_inet_ntoa	endp

;;::::::::::::::
_ioctlsocket	proc
                assume	ebx:ptr DSVDD_IOCTLSOCKET

		MAPIN	ebx, DSVDD_IOCTLSOCKET

		invoke	ws2_32.ioctlsocket, [ebx]._s,\
					    [ebx]._cmd,\
					    [ebx]._argp
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_ioctlsocket	endp

;;::::::::::::::
_listen		proc
                assume	ebx:ptr DSVDD_LISTEN

		MAPIN	ebx, DSVDD_LISTEN

		invoke	ws2_32.listen, [ebx]._s,\
				       [ebx]._backlog
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_listen		endp

;;::::::::::::::
_ntohl		proc
                assume	ebx:ptr DSVDD_NTOHL

		MAPIN	ebx, DSVDD_NTOHL

		invoke	ws2_32.ntohl, [ebx]._netlong
                mov	[ebx].result, eax

		ret
_ntohl		endp

;;::::::::::::::
_ntohs		proc
                assume	ebx:ptr DSVDD_NTOHS

		MAPIN	ebx, DSVDD_NTOHS

		invoke	ws2_32.ntohs, [ebx]._netshort
                mov	[ebx].result, eax

		ret
_ntohs		endp

;;::::::::::::::
_recv		proc
                assume	ebx:ptr DSVDD_RECV

		MAPIN	ebx, DSVDD_RECV

		invoke	ws2_32.recv, [ebx]._s,\
				     [ebx]._buf,\
				     [ebx]._len,\
				     [ebx]._flags
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                cmp	eax, SOCKET_ERROR
                jne	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_recv		endp

;;::::::::::::::
_recvfrom	proc
                assume	ebx:ptr DSVDD_RECVFROM

		MAPIN	ebx, DSVDD_RECVFROM

		invoke	ws2_32.recvfrom, [ebx]._s,\
					 [ebx]._buf,\
					 [ebx]._len,\
					 [ebx]._flags,\
					 [ebx]._from,\
					 [ebx]._fromlen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                cmp	eax, SOCKET_ERROR
                jne	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_recvfrom	endp

;;::::::::::::::
_select		proc
                assume	ebx:ptr DSVDD_SELECT

		MAPIN	ebx, DSVDD_SELECT

		invoke	ws2_32.select, [ebx]._nfds,\
				       [ebx]._readfds,\
				       [ebx]._writefds,\
				       [ebx]._exceptfds,\
				       [ebx]._timeout
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                cmp	eax, SOCKET_ERROR
                jne	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_select		endp

;;::::::::::::::
_send		proc
                assume	ebx:ptr DSVDD_SEND

		MAPIN	ebx, DSVDD_SEND

		invoke	ws2_32.send, [ebx]._s,\
				     [ebx]._buf,\
				     [ebx]._len,\
				     [ebx]._flags
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                cmp	eax, SOCKET_ERROR
                jne	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_send		endp

;;::::::::::::::
_sendto		proc
                assume	ebx:ptr DSVDD_SENDTO

		MAPIN	ebx, DSVDD_SENDTO

		invoke	ws2_32.sendto, [ebx]._s,\
				       [ebx]._buf,\
				       [ebx]._len,\
				       [ebx]._flags,\
				       [ebx]._to,\
				       [ebx]._tolen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                cmp	eax, SOCKET_ERROR
                jne	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_sendto		endp

;;::::::::::::::
_setsockopt	proc
                assume	ebx:ptr DSVDD_SETSOCKOPT

		MAPIN	ebx, DSVDD_SETSOCKOPT

		invoke	ws2_32.setsockopt, [ebx]._s,\
					   [ebx]._level,\
					   [ebx]._optname,\
					   [ebx]._optval,\
					   [ebx]._optlen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_setsockopt	endp

;;::::::::::::::
_shutdown	proc
                assume	ebx:ptr DSVDD_SHUTDOWN

		MAPIN	ebx, DSVDD_SHUTDOWN

		invoke	ws2_32.shutdown, [ebx]._s,\
					 [ebx]._how
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_shutdown	endp

;;::::::::::::::
_socket		proc
                assume	ebx:ptr DSVDD_SOCKET

		MAPIN	ebx, DSVDD_SOCKET

		invoke	ws2_32.socket, [ebx]._af,\
				       [ebx]._type,\
				       [ebx]._protocol
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                cmp	eax, INVALID_SOCKET
                jne	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_socket		endp

;;:::
;;  in: edi-> dst
;;	ecx= dst size
;;	eax-> src
;;
;; out: ZF set if nothing copied
;;	edi & ecx updated
;;	eax= bytes copied
h_lstrcpyn	proc	near uses edx
                assume  edi:nothing

		push	ecx

		test	ecx, ecx
		jz	@@exit			;; size= 0?
		test	eax, eax
		jz	@@exit			;; NULL?
		test	edi, edi
		jz	@@exit			;; NULL?

@@loop:		mov	dl, [eax]		;; char= *src++
		inc	eax			;; /
		mov	[edi], dl		;; *dst++= char
		inc	edi			;; /
		dec	ecx			;; --size
		jz	@@full			;; full?
		test	dl, dl
		jnz	@@loop			;; any char?

@@exit:		pop	eax
		sub	eax, ecx		;; return bytes copied
		ret

@@full:		mov	B [edi-1], 0		;; null char
		jmp	short @@exit
h_lstrcpyn	endp

;;:::
;;  in: edi= dst list linaddr
;;	ecx= dst list size
;;	stack= 	src list flat,
;;	 	dst list fp,
;;		addr_flg (=TRUE if addr_list, =FALSE if alias)
;;
;; out: CF set if error
;;	edi & ecx updated
;;	eax= dstlist_fp (NULL if src list is empty)
;;	edx= bytes copied (0 /)
h_flat2fp_list	proc	near32 pascal uses ebx esi,\
			srclist_flat:dword,\
			dstlist_fp:dword,\
			addr_flg:dword
		local	bytes:dword
                assume  ebp:nothing, ebx:nothing, esi:nothing, edi:nothing

		mov	bytes, 0

		;; esi-> src list
		mov	esi, srclist_flat
		test	esi, esi
		jz	@@no_items		;; NULL ptr?

		;; get number of items on src list
		xor	edx, edx
                push	esi
                jmp	short @@test
@@:		add	esi, T dword		;; ++ptr
		add	edx, T dword
@@test:		cmp	D [esi], NULL
		jne	@B
		pop	esi

		test	edx, edx
		jz	@@no_items		;; list empty?

		sub	ecx, edx		;; dst size-= sizeof(src list)
		sub	ecx, T dword		;; -1 (null ptr at end)
		jbe	@@error			;; nothing left?

		mov	ebx, edi		;; ebx-> list
		mov	bytes, edx		;; bytes= sizeof(list)

		;; set start address for all items in dst list
		mov	eax, dstlist_fp
		lea	eax, [eax+edx+4]	;; dst fp+= sizeof(src list)
		push	edx
@@:		mov	[edi], eax
		add	edi, T dword
		sub	edx, T dword
		jnz	@B
		pop	edx

		add	edi, T dword		;; coz null ptr
		cmp	addr_flg, TRUE
		jne	@@alias

		;; copy addrs
@@aloop:	mov 	eax, D [esi]		;; eax= flat(src list[i])
		test	eax, eax
		jz	@@error
		add	esi, T dword		;; ++i
		cmp	ecx, 4
		jl	@@error			;; no room?
		mov	eax, D [eax]		;; = addr
		mov	[edi], eax		;; save
		add	edi, 4
		sub	ecx, 4
		add	bytes, 4		;; bytes+=sizeof(IP4 addr)
		add	D [ebx + T dword], 4	;; correct fp of next item
		add	ebx, T dword
		sub	edx, T dword
		jnz	@@aloop
		jmp	short @@done

@@alias:	;; copy strings
@@sloop:	mov	eax, D [esi]		;; eax= flat(src list[i])
		test	eax, eax
		jz	@@error
		add	esi, T dword		;; ++i
		call	h_lstrcpyn
		jz	@@done			;; nothing copied?
		add	bytes, eax
		add	[ebx + T dword], eax	;; correct fp of next item
		add	ebx, T dword
		sub	edx, T dword
		jnz	@@sloop

@@done:		mov	D [ebx], NULL		;; mark end-of-array
		add	bytes, T dword		;; +null ptr
		mov	eax, dstlist_fp		;; return *dst list
		clc

@@exit:		mov	edx, bytes
		ret

@@no_items:	xor	eax, eax		;; return NULL
	;;;;;;;;clc
		jmp	short @@exit

@@error:	xor	eax, eax		;; /
		stc
		jmp	short @@exit
h_flat2fp_list	endp

;;:::
;;  in: eax= sysvm hostent flatptr
;;	Client_ESI= dosvm hostent farptr
;;	Client_ECX= /	  /       size (including buffer)
;;
;; out: CF set if error
h_hostent_conv	proc	near uses ebx ecx edi esi
                local	Client_ESI:dword
                assume  ebx:nothing, esi:nothing, edi:nothing

		;; esi= sys vm hostent
		mov	esi, eax

		;; ecx= sizeof(buffer) - sizeof(hostent)
		invoke	ntvdm.getECX
		mov	ecx, eax
		sub	ecx, T hostent

		;; ebx-> dos vm hostent
		invoke	ntvdm.getESI
		mov	Client_ESI, eax
		FP2FLAT eax, ecx
		mov	ebx, eax

		;; edi-> buffer after hostent
		lea	edi, [ebx + T hostent]
		add	Client_ESI, T hostent

		;; 1st: non-pointer field(s)
		mov	ax, [esi].hostent.h_addr
		mov	[ebx].hostent.h_addr, ax
		mov	ax, [esi].hostent.h_len
		mov	[ebx].hostent.h_len, ax

		;; 2nd: pointer field(s)
		mov	eax, Client_ESI
		mov	[ebx].hostent.h_name, eax
		mov	eax, [esi].hostent.h_name
		call	h_lstrcpyn
		add	Client_ESI, eax		;; assuming no seg overrun!!!
		add	eax, -1			;; set to NULL if nothing
		sbb	eax, eax		;; copied, preserve ptr
		and	[ebx].hostent.h_name,eax;; otherwise

		;; 3rd: array(s) of pointers
		;; addr_list 1st as it's the important part
		invoke	h_flat2fp_list, [esi].hostent.h_list,\
			                Client_ESI, TRUE
		jc	@@exit
		mov	[ebx].hostent.h_list, eax
		add	Client_ESI, edx		;; ///

		;; h_aliases
		invoke	h_flat2fp_list, [esi].hostent.h_alias,\
				        Client_ESI, FALSE
	;;;;;;;;jc	@@exit
		mov	[ebx].hostent.h_alias, eax

		clc

@@exit:		ret

@@error:	stc
		jmp	short @@exit
h_hostent_conv	endp

;;:::
;;  in: eax= sysvm servent flatptr
;;	Client_ESI= dosvm servent farptr
;;	Client_ECX= /	  /       size (including buffer)
;;
;; out: CF set if error
h_servent_conv	proc	near32 uses ebx ecx edi esi
                local	Client_ESI:dword
                assume  ebx:nothing, esi:nothing, edi:nothing

		;; esi= sys vm servent
		mov	esi, eax

		;; ecx= sizeof(buffer) - sizeof(servent)
		invoke	ntvdm.getECX
		mov	ecx, eax
		sub	ecx, T servent

		;; ebx-> dos vm servent
		invoke	ntvdm.getESI
		mov	Client_ESI, eax
		FP2FLAT eax, ecx
		mov	ebx, eax

		;; edi-> buffer after servent
		lea	edi, [ebx + T servent]
		add	Client_ESI, T servent

		;; 1st: non-pointer field(s)
		mov	ax, [esi].servent.s_port
		mov	[ebx].servent.s_port, ax

		;; 2nd: pointer field(s)
		;; s_name
		mov	eax, Client_ESI
		mov	[ebx].servent.s_name, eax
		mov	eax, [esi].servent.s_name
		call	h_lstrcpyn
		add	Client_ESI, eax		;; assuming no seg overrun!!!
		add	eax, -1			;; set to NULL if nothing
		sbb	eax, eax		;; copied, preserve ptr
		and	[ebx].servent.s_name,eax;; otherwise
		;; s_proto
		mov	eax, Client_ESI
		mov	[ebx].servent.s_proto, eax
		mov 	eax, [esi].servent.s_proto
		call	h_lstrcpyn
		add	Client_ESI, eax		;; ///
		add	eax, -1			;; set to NULL...
		sbb	eax, eax		;; /
		and	[ebx].servent.s_proto, eax

		;; 3rd: array(s) of pointers
		;; s_aliases
		invoke	h_flat2fp_list, [esi].servent.s_aliases,\
				        Client_ESI, FALSE
	;;;;;;;;jc	@@exit
		mov	[ebx].servent.s_aliases, eax

		clc

@@exit:		ret

@@error:	stc
		jmp	short @@exit
h_servent_conv	endp

;;:::
;;  in: eax= sysvm protoent flatptr
;;	Client_ESI= dosvm protoent farptr
;;	Client_ECX= /	  /       size (including buffer)
;;
;; out: CF set if error
h_protoent_conv	proc	near32 uses ebx ecx edi esi
                local	Client_ESI:dword
                assume  ebx:nothing, esi:nothing, edi:nothing

		;; esi= sys vm protoent
		mov	esi, eax

		;; ecx= sizeof(buffer) - sizeof(protoent)
		invoke	ntvdm.getECX
		mov	ecx, eax
		sub	ecx, T protoent

		;; ebx-> dos vm protoent
		invoke	ntvdm.getESI
		mov	Client_ESI, eax
		FP2FLAT eax, ecx
		mov	ebx, eax

		;; edi-> buffer after protoent
		lea	edi, [ebx + T protoent]
		add	Client_ESI, T protoent

		;; 1st: non-pointer field(s)
		mov	ax, [esi].protoent.p_proto
		mov	[ebx].protoent.p_proto, ax

		;; 2nd: pointer field(s)
		;; p_name
		mov	eax, Client_ESI
		mov	[ebx].protoent.p_name, eax
		mov 	eax, [esi].protoent.p_name
		call	h_lstrcpyn
		add	Client_ESI, eax		;; assuming no seg overrun!!!
		add	eax, -1			;; set to NULL if nothing
		sbb	eax, eax		;; copied, preserve ptr
		and	[ebx].protoent.p_name,eax;; otherwise

		;; 3rd: array(s) of pointers
		;; s_aliases
		invoke	h_flat2fp_list, [esi].protoent.p_aliases,\
				        Client_ESI, FALSE
	;;;;;;;;jc	@@exit
		mov	[ebx].protoent.p_aliases, eax

		clc

@@exit:		ret

@@error:	stc
		jmp	short @@exit
h_protoent_conv	endp

;;::::::::::::::
;; in:	ecx= hostent struct + buffer sizes
;;	esi= /			     farptr
_gethostbyaddr	proc
                assume	ebx:ptr DSVDD_GETHOSTBYADDR

		MAPIN	ebx, DSVDD_GETHOSTBYADDR

		invoke	ws2_32.gethostbyaddr, [ebx]._addr,\
					      [ebx]._len,\
					      [ebx]._type
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jnz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax
                jmp	short @@exit

@@:		call	h_hostent_conv
		jc	@@error

@@exit:		ret

@@error:	mov	[ebx].result, NULL
		mov	[ebx].error, 'EINT'
		jmp	short @@exit
_gethostbyaddr	endp

;;::::::::::::::
;; in:	ecx= hostent struct + buffer sizes
;;	esi= /			     farptr
_gethostbyname	proc
                assume	ebx:ptr DSVDD_GETHOSTBYNAME

		MAPIN	ebx, DSVDD_GETHOSTBYNAME

		invoke	ws2_32.gethostbyname, [ebx]._name
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jnz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax
                jmp	short @@exit

@@:		call	h_hostent_conv
		jc	@@error

@@exit:		ret

@@error:	mov	[ebx].result, NULL
		mov	[ebx].error, 'EINT'
		jmp	short @@exit
_gethostbyname	endp

;;::::::::::::::
_gethostname	proc
                assume	ebx:ptr DSVDD_GETHOSTNAME

		MAPIN	ebx, DSVDD_GETHOSTNAME

		invoke	ws2_32.gethostname, [ebx]._name,\
					    [ebx]._namelen
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax

@@:		ret
_gethostname	endp

;;::::::::::::::
;; in:	ecx= servent struct + buffer sizes
;;	esi= /			     farptr
_getservbyport	proc
                assume	ebx:ptr DSVDD_GETSERVBYPORT

		MAPIN	ebx, DSVDD_GETSERVBYPORT

		invoke	ws2_32.getservbyport, [ebx]._port,\
					      [ebx]._proto
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jnz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax
                jmp	short @@exit

@@:		call	h_servent_conv
		jc	@@error

@@exit:		ret

@@error:	mov	[ebx].result, NULL
		mov	[ebx].error, 'EINT'
		jmp	short @@exit
_getservbyport	endp

;;::::::::::::::
;; in:	ecx= servent struct + buffer sizes
;;	esi= /			     farptr
_getservbyname	proc
                assume	ebx:ptr DSVDD_GETSERVBYNAME

		MAPIN	ebx, DSVDD_GETSERVBYNAME

		invoke	ws2_32.getservbyname, [ebx]._name,\
					      [ebx]._proto
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jnz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax
                jmp	short @@exit

@@:		call	h_servent_conv
		jc	@@error

@@exit:		ret

@@error:	mov	[ebx].result, NULL
		mov	[ebx].error, 'EINT'
		jmp	short @@exit
_getservbyname	endp

;;::::::::::::::
;; in:	ecx= protoent struct + buffer sizes
;;	esi= /			      farptr
_getprotobynumber proc
                assume	ebx:ptr DSVDD_GETPROTOBYNUMBER

		MAPIN	ebx, DSVDD_GETPROTOBYNUMBER

		invoke	ws2_32.getprotobynumber, [ebx]._number
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jnz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax
                jmp	short @@exit

@@:		call	h_protoent_conv
		jc	@@error

@@exit:		ret

@@error:	mov	[ebx].result, NULL
		mov	[ebx].error, 'EINT'
		jmp	short @@exit
_getprotobynumber endp

;;::::::::::::::
;; in:	ecx= protoent struct + buffer sizes
;;	esi= /			      farptr
_getprotobyname proc
                assume	ebx:ptr DSVDD_GETPROTOBYNAME

		MAPIN	ebx, DSVDD_GETPROTOBYNAME

		invoke	ws2_32.getprotobyname, [ebx]._name
                mov	[ebx].result, eax

                mov	[ebx].error, 0
                test	eax, eax
                jnz	@F
                invoke	ws2_32.WSAGetLastError
                mov	[ebx].error, eax
                jmp	short @@exit

@@:		call	h_protoent_conv
		jc	@@error

@@exit:		ret

@@error:	mov	[ebx].result, NULL
		mov	[ebx].error, 'EINT'
		jmp	short @@exit
_getprotobyname endp

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; asynchronous events routines
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;:::
window_thread	proc	lpParam:LPVOID
		local	msg:MSG

                ;; create a hidden window (this must be done in
                ;; the same thread that will wait/dispatch msgs)
		call	create_win
		test	eax, eax
		jz	@@error
		mov	hWnd, eax

		jmp	short @@get
@@loop:		cmp	eax, -1
		je	@@exit

        	cmp 	msg.message, WM_DSOCK-1
		je	@@destroy
		invoke	DispatchMessage, A msg

@@get:		cmp	hWnd, 0
		je	@@exit
		invoke	GetMessage, A msg, NULL, 0, 0
		test	eax, eax
		jnz	@@loop

@@exit:		;; unreg class (needed for DLLs in NT)
        	invoke  UnregisterClass, A dsock_zs, hInstance

		xor	eax, eax
		ret

@@destroy:	invoke	DestroyWindow, hWnd
		jmp	short @@get

@@error:	mov	hWnd, -1
		mov	eax, -1
		ret
window_thread	endp

;;:::
simint_thread	proc	lParam:LPVOID

                ICA_MASTER		equ	0

@@loop:		cmp	sint_hSem, 0
		je	@@exit

		invoke	WaitForSingleObject, sint_hSem, INFINITE
		cmp	eax, WAIT_FAILED
		je	@@exit
		cmp	sint_hSem, 0
		je	@@exit

                invoke	ntvdm.VDDSimulateInterrupt, ICA_MASTER, DSVDD_IRQ, 1
		jmp	short @@loop

@@exit:		xor	eax, eax
		ret
simint_thread	endp

;;:::
WindowProc 	proc 	uses ebx edi,\
			_hWnd:HWND,\
			_wMsg:UINT,\
			_wParam:WPARAM,\
			_lParam:LPARAM
		local	tid:dword

		movzx	eax, W _wMsg

        	cmp 	eax, WM_DSOCK
		jb	@@user

		cmp	hList._ptr, NULL
		je	@@done
        	;; ebx-> node (msg - WM_DSOCK + hlist's base)
        	sub 	eax, WM_DSOCK
		add	eax, hList._ptr
		mov	ebx, eax
		assume	ebx:ptr ASYNCSELCB

		cmp	[ebx].id, 'CB32'
		jne	@@done			;; invalid sign?

		;; alloc from circular-buffer
	;;;;;;;;invoke	WaitForSingleObject, hMutex, INFINITE
                mov	edi, [ebx].cbuf
                CBUFSET	[edi], <T DSVDD_MSG>
@@:	;;;;;;;;invoke	ReleaseMutex, hMutex
                FP2FLAT	eax, <T DSVDD_MSG>
                assume	eax: ptr DSVDD_MSG

		;; fill cbuf
		mov	edx, [ebx].wMsg
		mov	[eax].wMsg, edx
		mov	edx, _wParam
		mov	[eax].wParam, edx
		mov	edx, _lParam
		mov	[eax].lParam, edx

                ;; if rm callback is working currently or simint thread
                ;; was already alerted, don't simulate a rm interrupt and/
                ;; or don't wake up the thread again
                mov	eax, [ebx].pWrkFlag
                cmp	B [eax], TRUE
                je	@@done
                mov	B [eax], TRUE

                ;; wakeup the simint thread
                invoke	ReleaseSemaphore, sint_hSem, 1, NULL

@@done:		xor	eax, eax

@@exit:		ret

@@user:		cmp	eax, WM_DESTROY
		jne	@@default
		invoke	PostQuitMessage, NULL
		jmp	short @@done

@@default:      invoke	DefWindowProc, _hWnd, _wMsg, _wParam, _lParam
            	jmp	short @@exit
WindowProc	endp

;;:::
;; out: eax= hWnd
create_win	proc
   		local	hw:WNDCLASSEX

   		mov	hw.cbSize, T WNDCLASSEX
		mov	hw.style, CS_HREDRAW or CS_VREDRAW
		mov	hw.lpfnWndProc, O WindowProc
		mov	eax, hInstance
		mov	hw.hInstance, eax
        	mov 	hw.lpszClassName, O dsock_zs
		mov	hw.cbClsExtra, 0
		mov	hw.cbWndExtra, 0
		mov	hw.hbrBackground, 0
		mov	hw.lpszMenuName, NULL
		mov	hw.hIcon, NULL
		mov	hw.hIconSm, NULL
		mov	hw.hCursor, NULL

		invoke	RegisterClassEx, A hw
		and	eax, 0000FFFFh

        	invoke  CreateWindowEx, 0, eax, A dsock_zs,\
                                        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,\
        				CW_USEDEFAULT, CW_USEDEFAULT,\
        				CW_USEDEFAULT, NULL, NULL,\
        				hInstance, NULL

@@exit:		ret
create_win	endp
		end
