;;
;; drvNT.asm -- Windows NT driver (wrapper for dsock VDD)
;;

                include lang.inc

                include equ.inc
                include intern.inc
                include dsockvdd.inc
                include isvbop.inc
                include	llist.inc
                include	cbuf.inc

ifndef		SOCKET_ERROR
		SOCKET_ERROR		equ	-1
endif

;;::::::::::::::
VDDCALL		macro	?cmd:req, ?pseg, ?pofs
    ifnb <?pseg>
		PS	__BX, es
		push	?pseg			;; es:__BX-> params
		pop	es			;; /
        ifdifi <?pseg>, <ss>
        	movdifi	__BX, O ?pofs		;; /
        else
        	lea	__BX, ?pofs		;; /
        endif
    endif
		movdifi	edx, ?cmd
        	mov 	ax, dsock_hnd
		stc
		DispatchCall
    ifnb <?pseg>
    		PP	es, __BX
    endif
endm


__CONST__
dsock_dll_zs    byte    'dsock.dll', 0
dsock_Disp_zs   byte    'DSock_Dispatch', 0
dsock_Init_zs   byte    'DSock_Init', 0


DS_FIXSEG
wnt_initialized	dw	FALSE
dsock_hnd   dw  0

drv_NT          label   DSDRV
		tNEARPTR wnt_init, wnt_end
		tNEARPTR wnt_bind, wnt_getpeername, wnt_getsockname
		tNEARPTR wnt_getsockopt, wnt_ioctlsocket, wnt_listen
		tNEARPTR wnt_setsockopt, wnt_shutdown, wnt_socket
		tNEARPTR wnt_accept, wnt_closesocket, wnt_connect, wnt_recv
		tNEARPTR wnt_recvfrom, wnt_select, wnt_send, wnt_sendto
		tNEARPTR wnt_gethostbyaddr, wnt_gethostbyname, wnt_gethostname
		tNEARPTR wnt_getservbyport, wnt_getservbyname, wnt_getprotobynumber
		tNEARPTR wnt_getprotobyname
		tNEARPTR wnt_startup, wnt_cleanup, wnt_asyncselect

ifndef		ASYNCSEL_CNT
		ASYNCSEL_CNT 		equ 128	;; enough???
ASYNCSEL_llst	LLST	<?>
endif

ifndef		MSG_CBUF_CNT
		MSG_CBUF_CNT		equ 256	;; /
msg_cbuf	CBUF	<?>
endif

ifdef		__MODE_PROT__
old_isr		dword	?
endif
old_OCW		byte	?

ifndef		wrkFlag
wrkFlag		byte	FALSE
endif
DS_ENDS


.data
asselisr_flg	word 	FALSE


DS_CODE
ifndef		__MODE_PROT__
old_isr		dword	?
endif

;;:::
load_vdd	proc	near pascal uses bx di si es,\
			vdd_name:NEARPTR byte,\
			init_proc:NEARPTR byte,\
			disp_proc:NEARPTR byte

                mov	si, vdd_name
                mov	bx, disp_proc
                mov	di, init_proc
                xor	ax, ax
                test	di, di
                jz	@F
                mov	ax, ds
@@:		mov	es, ax
		RegisterModule
		jc	@@error

@@exit:		ret

@@error:	xor	ax, ax
		jmp	short @@exit
load_vdd	endp

;;::::::::::::::
;; out: ax= 0 if ok
wnt_init	proc    near pascal uses bx es

                cmp	wnt_initialized, TRUE
                je	@@done

                ;; create ASYNCSEL linked-list
                invoke	ListCreate, A ASYNCSEL_llst, ASYNCSEL_CNT, T ASYNCSEL
                jc	@@error

                ;; create DSVDD_MSG circular-buffer
                invoke	CBufCreate, A msg_cbuf, MSG_CBUF_CNT, T DSVDD_MSG
                jc	@@error2

                ;; load the vdd
                invoke  load_vdd, O dsock_dll_zs,\
                          O dsock_Init_zs,\
                          O dsock_Disp_zs
                mov dsock_hnd, ax
                test    ax, ax
                jz      @@error3                ;; error?

                ;; init dsock
                xor     eax, eax
	ifndef	__MODE_PROT__
                xor	bx, bx
	else
		mov	bx, 1
	endif
	if	(@Model	ne MODEL_FLAT)
		xor	cx, cx
	else
		mov	cx, 1
	endif
                VDDCALL	DSVDD_INIT_CMD
                cmp	eax, 'DSCK'
                jne	@@error3

                ;; install isr
	if	(@Model	ne MODEL_FLAT)
                ;; get current isr
                mov	ax, (35h*256) + (8+DSVDD_IRQ)
                int	21h
                mov	W old_isr+0, bx
                mov	W old_isr+2, es
                ;; set new
                push	ds
                mov	ax, cs
                mov	ds, ax
                mov	__DX, O asyncsel_isr
                mov	ax, (25h*256) + (8+DSVDD_IRQ)
                int	21h
                pop	ds
                ;; enable irq
                cli
                in      al, 21h
                mov	old_OCW, al
                and     al, not (1 shl DSVDD_IRQ)
                out     21h, al
                sti
	else
		.err	ERROR: No flat-mode support in drvNT::_init
	endif

                mov	wnt_initialized, TRUE

@@done:		xor     ax, ax                	;; return ok (0)

@@exit:         ret

@@error3:	invoke	CBufDestroy, A msg_cbuf

@@error2:       invoke	ListDestroy, A ASYNCSEL_llst

@@error:        mov     ax, -1                  ;; return error (-1)
                jmp     short @@exit
wnt_init	endp

;;::::::::::::::
wnt_end       	proc    near pascal

                cmp	wnt_initialized, TRUE
                jne	@@exit

	if	(@Model	ne MODEL_FLAT)
                ;; restore pic mask
                cli
                in      al, 21h
                mov	ah, old_OCW
                and	al, not (1 shl DSVDD_IRQ)
                and	ah, 1 shl DSVDD_IRQ
                or	al, ah
                out     21h, al
                sti
                ;; restore old isr
                push	ds
                lds	__DX, old_isr
                mov	ax, (25h*256) + (8+DSVDD_IRQ)
                int	21h
                pop	ds
	else
		.err	ERROR: No flat-mode support in drvNT::_end
	endif

                ;; finish with dsock
                VDDCALL	DSVDD_END_CMD

                ;; unload dsock VDD
                mov ax, dsock_hnd
                UnRegisterModule
                mov dsock_hnd, 0

                ;; destroy DSVDD_MSG circular-buffer
                invoke	CBufDestroy, A msg_cbuf

                ;; destroy ASYNCSEL linked-list
		invoke	ListDestroy, A ASYNCSEL_llst

                mov	wnt_initialized, FALSE

@@exit:         ret
wnt_end       	endp

;;::::::::::::::
;;  in: eax= wVersionRequested
;;	ebx= lpWSAData
;;
;; out: ax= 0 if ok
wnt_startup	proc	near pascal
		local	dsp:DSVDD_STARTUP

                cmp	wnt_initialized, TRUE
                jne	@@error

		mov	dsp._wVersionRequested, eax
		mov	dsp._lpWSAData, ebx

                ;; try starting dsock/winsock
                VDDCALL DSVDD_STARTUP_CMD, ss, dsp
                jc      @@error                 ;; error?

		mov     eax, dsp.result

@@exit:         ret

@@error:       	mov	ax, -1			;; return error (-1)
		jmp     short @@exit
wnt_startup	endp

;;::::::::::::::
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_cleanup	proc	near pascal uses cx __DI es
		local	dsp:DSVDD_CLEANUP

                cmp	wnt_initialized, TRUE
                jne	@@error

		;; free all nodes in ASYNCSEL linked-list
		mov	asselisr_flg, TRUE

		invoke	ListLast, A ASYNCSEL_llst
		jz	@F
@@loop:		mov	__ES:[__DI].ASYNCSEL.id, 0
		mov	__ES:[__DI].ASYNCSEL.socket, 0
		mov	__AX, __DI
		invoke	ListPrev		;; __DI= prev
		invoke	ListFree, A ASYNCSEL_llst, __AX
		test	__DI, __DI
		jnz	@@loop			;; any node left?

@@:             ;; DSVDD_MSG cbuf head= tail
		mov	eax, msg_cbuf.head
		mov	msg_cbuf.tail, eax

		mov	asselisr_flg, FALSE

                VDDCALL DSVDD_CLEANUP_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	ax, -1			;; return error (-1)
		jmp	short @@exit
wnt_cleanup	endp

ifndef		__LANG_PAS__
;;:::
;;  in: eax= socket
;;
;; out: __ES:__DI-> node (NULL if not found)
h_aselList_find	proc	near

		invoke	ListLast, A ASYNCSEL_llst
		jz	@@exit

@@loop:		cmp	__ES:[__DI].ASYNCSEL.socket, eax
		je	@@exit			;; curr.socket= socket?
		invoke	ListPrev		;; __DI= prev
		jnz	@@loop			;; not last node?

@@exit:		ret
h_aselList_find	endp
endif

;;::::::::::::::
;;  in: eax= s
;;	ebx= hWnd
;;	ecx= wMsg
;;	edx= lEvent
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_asyncselect	proc	near pascal uses __DI es
		local	dsp:DSVDD_ASYNCSEL

		;; search if a node for this socket already exists
		call	h_aselList_find
		test	__DI, __DI
		jnz	@F			;; found?

		;; allocate a new node for ASYNCSELCB struct if any
		;; event selected
                test	edx, edx
		je	@@vdd_call		;; no events?
		invoke	ListAlloc, A ASYNCSEL_llst
		jc	@@error

@@:		;; fill node
		mov	__ES:[__DI].ASYNCSEL.id, 'CB16'
		mov	__ES:[__DI].ASYNCSEL.socket, eax
		mov	__ES:[__DI].ASYNCSEL.fpProc, ebx
		mov	__ES:[__DI].ASYNCSEL.wMsg, ecx

@@vdd_call:	mov	dsp._s, eax
		mov	dsp._lEvent, edx
		STOADDR	dsp._cbuf, S msg_cbuf, O msg_cbuf
		STOADDR	dsp._fpWrkFlag, S wrkFlag, O wrkFlag
		STOADDR	dsp._wMsg, __ES, __DI

		VDDCALL	DSVDD_ASYNCSEL_CMD, ss, dsp
		cmp	dsp.result, 0
		jne	@@error2		;; error?

		cmp	dsp._lEvent, 0
		jne	@@done			;; any event?

		;; delete node
		test	__DI, __DI
		jz	@@done			;; NULL node?
		mov	__ES:[__DI].ASYNCSEL.id, 0    ;; just f/ precaution
		mov	__ES:[__DI].ASYNCSEL.socket, 0;; /
		invoke	ListFree, A ASYNCSEL_llst, __DI

@@done:		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error2:	;; delete node
		test	__DI, __DI
		jz	@F			;; NULL node?
		mov	__ES:[__DI].ASYNCSEL.id, 0    ;; just f/ precaution
		invoke	ListFree, A ASYNCSEL_llst, __DI

@@:		mov	ax, 'EINT'		;; internal error

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
wnt_asyncselect	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= addr
;;	ecx= addrlen
;;
;; out: eax= socket (= INVALID_SOCKET if error)
;;	dx= error code
wnt_accept	proc	near pascal
		local	dsp:DSVDD_ACCEPT

		mov	dsp._s, eax
		mov	dsp._addr, ebx
		mov	dsp._addrlen, ecx

		VDDCALL	DSVDD_ACCEPT_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_accept	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_bind	proc	near pascal
		local	dsp:DSVDD_BIND

		mov	dsp._s, eax
		mov	dsp._name, ebx
		mov	dsp._namelen, ecx

		VDDCALL	DSVDD_BIND_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_bind	endp

;;::::::::::::::
;;  in: eax= s
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_closesocket	proc	near pascal
		local	dsp:DSVDD_CLOSESOCKET

		mov	dsp._s, eax

		VDDCALL	DSVDD_CLOSESOCKET_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_closesocket	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_connect	proc	near pascal
		local	dsp:DSVDD_CONNECT

		mov	dsp._s, eax
		mov	dsp._name, ebx
		mov	dsp._namelen, ecx

		VDDCALL	DSVDD_CONNECT_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_connect	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_getpeername	proc	near pascal
		local	dsp:DSVDD_GETPEERNAME

		mov	dsp._s, eax
		mov	dsp._name, ebx
		mov	dsp._namelen, ecx

		VDDCALL	DSVDD_GETPEERNAME_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_getpeername	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_getsockname	proc	near pascal
		local	dsp:DSVDD_GETSOCKNAME

		mov	dsp._s, eax
		mov	dsp._name, ebx
		mov	dsp._namelen, ecx

		VDDCALL	DSVDD_GETSOCKNAME_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_getsockname	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= level
;;	ecx= optname
;;	edx= optval
;;	edi= optlen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_getsockopt	proc	near pascal
		local	dsp:DSVDD_GETSOCKOPT

		mov	dsp._s, eax
		mov	dsp._level, ebx
		mov	dsp._optname, ecx
		mov	dsp._optval, edx
		mov	dsp._optlen, edi

		VDDCALL	DSVDD_GETSOCKOPT_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_getsockopt	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= cmd
;;	ecx= argp
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_ioctlsocket	proc	near pascal
		local	dsp:DSVDD_IOCTLSOCKET

		mov	dsp._s, eax
		mov	dsp._cmd, ebx
		mov	dsp._argp, ecx

		VDDCALL	DSVDD_IOCTLSOCKET_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_ioctlsocket	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= backlog
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_listen	proc	near pascal
		local	dsp:DSVDD_LISTEN

		mov	dsp._s, eax
		mov	dsp._backlog, ebx

		VDDCALL	DSVDD_LISTEN_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_listen	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= buf
;;	ecx= len
;;	edx= flags
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_recv	proc	near pascal
		local	dsp:DSVDD_RECV

		mov	dsp._s, eax
		mov	dsp._buf, ebx
		mov	dsp._len, ecx
		mov	dsp._flags, edx

		VDDCALL	DSVDD_RECV_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_recv	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= *buf
;;	ecx= len
;;	edx= flags
;;	edi= *from
;;	esi= *fromlen
;;
;; out: eax= bytes received (= SOCKET_ERROR if error)
;;	dx= error code
wnt_recvfrom	proc	near pascal
		local	dsp:DSVDD_RECVFROM

		mov	dsp._s, eax
		mov	dsp._buf, ebx
		mov	dsp._len, ecx
		mov	dsp._flags, edx
		mov	dsp._from, edi
		mov	dsp._fromlen, esi

		VDDCALL	DSVDD_RECVFROM_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_recvfrom	endp

;;::::::::::::::
;;  in: eax= nfds
;;	ebx= *readfds
;;	ecx= *writefds
;;	edx= *exceptfds
;;	edi= timeout
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_select	proc	near pascal
		local	dsp:DSVDD_SELECT

		mov	dsp._nfds, eax
		mov	dsp._readfds, ebx
		mov	dsp._writefds, ecx
		mov	dsp._exceptfds, edx
		mov	dsp._timeout, edi

		VDDCALL	DSVDD_SELECT_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_select	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= *buf
;;	ecx= len
;;	edx= flags
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_send	proc	near pascal
		local	dsp:DSVDD_SEND

		mov	dsp._s, eax
		mov	dsp._buf, ebx
		mov	dsp._len, ecx
		mov	dsp._flags, edx

		VDDCALL	DSVDD_SEND_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_send	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= *buf
;;	ecx= len
;;	edx= flags
;;	edi= *to
;;	esi= tolen
;;
;; out: eax= bytes sent (= SOCKET_ERROR if error)
;;	dx= error code
wnt_sendto	proc	near pascal
		local	dsp:DSVDD_SENDTO

		mov	dsp._s, eax
		mov	dsp._buf, ebx
		mov	dsp._len, ecx
		mov	dsp._flags, edx
		mov	dsp._to, edi
		mov	dsp._tolen, esi

		VDDCALL	DSVDD_SENDTO_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_sendto	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= level
;;	ecx= optname
;;	edx= optval
;;	edi= optlen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_setsockopt	proc	near pascal
		local	dsp:DSVDD_SETSOCKOPT

		mov	dsp._s, eax
		mov	dsp._level, ebx
		mov	dsp._optname, ecx
		mov	dsp._optval, edx
		mov	dsp._optlen, edi

		VDDCALL	DSVDD_SETSOCKOPT_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_setsockopt	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= how
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
wnt_shutdown	proc	near pascal
		local	dsp:DSVDD_SHUTDOWN

		mov	dsp._s, eax
		mov	dsp._how, ebx

		VDDCALL	DSVDD_SHUTDOWN_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_shutdown	endp

;;::::::::::::::
;;  in: eax= af
;;	ebx= type
;;	ecx= protocol
;;
;; out: eax= socket (= INVALID_SOCKET if error)
;;	dx= error code
wnt_socket	proc	near pascal
		local	dsp:DSVDD_SOCKET

		mov	dsp._af, eax
		mov	dsp._type, ebx
		mov	dsp._protocol, ecx

		VDDCALL	DSVDD_SOCKET_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_socket	endp


;;::::::::::::::
;;  in: eax= addr
;;	ebx= len
;;	ecx= type
;;	__ES:__DI-> hostent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
wnt_gethostbyaddr proc	near pascal
		local	dsp:DSVDD_GETHOSTBYADDR

		mov	dsp._addr, eax
		mov	dsp._len, ebx
		mov	dsp._type, ecx

		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	esi, es			;; esi= /      addr
		shl	esi, 16                 ;; /
		mov	si, di                  ;; /
	else
		mov	esi, edi
	endif

		VDDCALL	DSVDD_GETHOSTBYADDR_CMD, ss, dsp
		mov	dx, W dsp.error
		test	eax, eax
		jz	@@exit			;; NULL?

	if	(@Model ne MODEL_FLAT)
		mov	eax, es			;; eax= es:di
		shl	eax, 16			;; /
		mov	ax, di			;; /
	else
		mov	eax, edi
	endif

@@exit:		ret
wnt_gethostbyaddr endp

;;::::::::::::::
;;  in: eax= name
;;	__ES:__DI-> hostent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
wnt_gethostbyname proc	near pascal
		local	dsp:DSVDD_GETHOSTBYNAME

		mov	dsp._name, eax

		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	esi, es			;; esi= /      addr
		shl	esi, 16                 ;; /
		mov	si, di                  ;; /
	else
		mov	esi, edi
	endif

		VDDCALL	 DSVDD_GETHOSTBYNAME_CMD, ss, dsp
		mov	dx, W dsp.error
		test	eax, eax
		jz	@@exit			;; NULL?

		xor	dx, dx			;; no error
	if	(@Model ne MODEL_FLAT)
		mov	eax, es			;; eax= es:di
		shl	eax, 16			;; /
		mov	ax, di			;; /
	else
		mov	eax, edi
	endif

@@exit:		ret
wnt_gethostbyname endp

;;::::::::::::::
;;  in: eax= name
;;	ebx= namelen
;;
;; out: eax= result (=0 if ok)
;;	dx= error code
wnt_gethostname	proc	near pascal
		local	dsp:DSVDD_GETHOSTNAME

		mov	dsp._name, eax
		mov	dsp._namelen, ebx

		VDDCALL	 DSVDD_GETHOSTNAME_CMD, ss, dsp

		mov	dx, W dsp.error
		mov	eax, dsp.result

		ret
wnt_gethostname	endp

;;::::::::::::::
;;  in: eax= port
;;	ebx= proto
;;	__ES:__DI-> servent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
wnt_getservbyport proc	near pascal
		local	dsp:DSVDD_GETSERVBYPORT

		mov	dsp._port, eax
		mov	dsp._proto, ebx

		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	esi, es			;; esi= /      addr
		shl	esi, 16                 ;; /
		mov	si, di                  ;; /
	else
		mov	esi, edi
	endif

		VDDCALL	DSVDD_GETSERVBYPORT_CMD, ss, dsp
		mov	dx, W dsp.error
		test	eax, eax
		jz	@@exit			;; NULL?

		xor	dx, dx			;; no error
	if	(@Model ne MODEL_FLAT)
		mov	eax, es			;; eax= es:di
		shl	eax, 16			;; /
		mov	ax, di			;; /
	else
		mov	eax, edi
	endif

@@exit:		ret
wnt_getservbyport endp

;;::::::::::::::
;;  in: eax= name
;;	ebx= proto
;;	__ES:__DI-> servent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
wnt_getservbyname proc	near pascal
		local	dsp:DSVDD_GETSERVBYNAME

		mov	dsp._name, eax
		mov	dsp._proto, ebx

		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	esi, es			;; esi= /      addr
		shl	esi, 16                 ;; /
		mov	si, di                  ;; /
	else
		mov	esi, edi
	endif

		VDDCALL	DSVDD_GETSERVBYNAME_CMD, ss, dsp
		mov	dx, W dsp.error
		test	eax, eax
		jz	@@exit			;; NULL?

		xor	dx, dx			;; no error
	if	(@Model ne MODEL_FLAT)
		mov	eax, es			;; eax= es:di
		shl	eax, 16			;; /
		mov	ax, di			;; /
	else
		mov	eax, edi
	endif

@@exit:		ret
wnt_getservbyname endp

;;::::::::::::::
;;  in: eax= number
;;	__ES:__DI-> protoent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
wnt_getprotobynumber proc near pascal
		local	dsp:DSVDD_GETPROTOBYNUMBER

		mov	dsp._number, eax

		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	esi, es			;; esi= /      addr
		shl	esi, 16                 ;; /
		mov	si, di                  ;; /
	else
		mov	esi, edi
	endif

		VDDCALL	DSVDD_GETPROTOBYNUMBER_CMD, ss, dsp
		mov	dx, W dsp.error
		test	eax, eax
		jz	@@exit			;; NULL?

		xor	dx, dx			;; no error
	if	(@Model ne MODEL_FLAT)
		mov	eax, es			;; eax= es:di
		shl	eax, 16			;; /
		mov	ax, di			;; /
	else
		mov	eax, edi
	endif

@@exit:		ret
wnt_getprotobynumber endp

;;::::::::::::::
;;  in: eax= name
;;	__ES:__DI-> protoent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
wnt_getprotobyname proc	near pascal
		local	dsp:DSVDD_GETPROTOBYNAME

		mov	dsp._name, eax

		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	esi, es			;; esi= /      addr
		shl	esi, 16                 ;; /
		mov	si, di                  ;; /
	else
		mov	esi, edi
	endif

		VDDCALL	DSVDD_GETPROTOBYNAME_CMD, ss, dsp
		mov	dx, W dsp.error
		test	eax, eax
		jz	@@exit			;; NULL?

	if	(@Model ne MODEL_FLAT)
		mov	eax, es			;; eax= es:di
		shl	eax, 16			;; /
		mov	ax, di			;; /
	else
		mov	eax, edi
	endif

@@exit:		ret
wnt_getprotobyname endp
DS_ENDS

ifndef		__LANG_PAS__
__BSS__
cur_stack	dword	?
		word	?

.data
stks_ptr	tNEARPTR O ds$stks_buf + (STK_SIZE*MAX_STKS)
endif

DS_CODE
;;:::
asyncsel_isr	proc
		pushad
		PS	fs, es, ds

		;; enable re-entrance
		mov	al, 20h			;; nonspecific EOI
		out	20h, al			;; /
		sti				;; hw interrupts on

	if	(@Model ne MODEL_FLAT)
		;; ds-> dgroup
		mov	ax, @data		;; si= DGROUP
		mov	ds, ax
	else
		.exit	ERROR: No flat-mode support in drvNT::asyncsel_isr
	endif

		;; msg_cbuf being accessed currently?
		cmp	asselisr_flg, TRUE
		je	@@exit

		;; any free stack?
		cmp	stks_ptr, O ds$stks_buf
		je	@@exit			;; damnit

		;; switch stacks (ss=ds)
		push	cur_stack
	if	(@Model ne MODEL_FLAT)
		mov	W cur_stack+0, sp
		mov	W cur_stack+2, ss
	else
		mov	cur_stack, esp
		mov	W cur_stack+4, ss
	endif
		mov	ss, ax			;; ss=ds
	if	(@Model ne MODEL_FLAT)
		mov	sp, W stks_ptr
	else
		mov	esp, stks_ptr
	endif
		sub	stks_ptr, STK_SIZE

		;; invoke callback until no more msgs on queue
@@loop:		mov     wrkFlag, FALSE
		CBUFGET	msg_cbuf, <T DSVDD_MSG>
		test	eax, eax
		jz	@@done			;; nothing queued?
		mov     wrkFlag, TRUE

		;; fs:bx-> head
	if	(@Model ne MODEL_FLAT)
		mov	bx, ax
		shr	eax, 16
		mov	fs, ax
	else
		mov	ebx, eax
	endif

		;; es:di-> ASYNCSEL node
	if	(@Model ne MODEL_FLAT)
		les	di, fs:[bx].DSVDD_MSG.wMsg
	else
		mov	edi, [ebx].DSVDD_MSG.wMsg
	endif

		;; is it a valid struct?
		cmp	__ES:[__DI].ASYNCSEL.id, 'CB16'
		jne	@@loop

		;; call the callback
		push	__ES:[__DI].ASYNCSEL.wMsg
		push	__FS:[__BX].DSVDD_MSG.wParam
		push	__FS:[__BX].DSVDD_MSG.lParam
		call	__ES:[__DI].ASYNCSEL.fpProc
		jmp	short @@loop

@@done:		;; back to old stack
		add	stks_ptr, STK_SIZE
	if	(@Model ne MODEL_FLAT)
		lss	sp, cur_stack
	else
		lss	esp, fword ptr cur_stack
	endif
		pop	cur_stack

@@exit:		mov	wrkFlag, FALSE		;; alert the vdd

		PP	ds, es, fs
		popad
	if	(@Model ne MODEL_FLAT)
		iret
	else
		iretd
	endif


comment		`
@@chain:	;; not of our bussiness
    if	(@Model ne MODEL_FLAT)
    	ifndef	__MODE_PROT__
		jmp	old_isr
	else
		push	eax
		push	bp
		mov	bp, sp
		push	ds
		mov	ax, @data
		mov	ds, ax
		mov	eax, old_isr
		xchg	eax, [bp+2]
		pop	ds
		pop	bp
		retf
	endif
    else
		.err	ERROR: No flat-mode support in drvNT::asyncsel_isr
    endif
`
asyncsel_isr	endp
DS_ENDS
                __END__
