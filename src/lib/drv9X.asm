;;
;; drv_9X.asm -- Windows 9X/Me driver (wrapper for wsock2 and dsock VxDs)
;;

                include lang.inc

                include equ.inc
                include wsock2.inc
                include intern.inc
                include dsockvxd.inc
                include	llist.inc
                include	cbuf.inc

                ;; VxD loader id and services
                VXDLDR_ID       	equ 	27h
                VXDLDR_VERSION  	equ 	0
                VXDLDR_LOAD     	equ 	1
                VXDLDR_UNLOAD   	equ 	2

                WSIOS_TIMEOUT		equ	90*4	;; 5*n secs


ifndef          FD_SETSIZE
		FD_SETSIZE		equ	64
endif

SOCK_LISTS	struct
		ReadList		SOCK_LIST FD_SETSIZE dup (<?>)
		WriteList		SOCK_LIST FD_SETSIZE dup (<?>)
		ExceptList		SOCK_LIST FD_SETSIZE dup (<?>)
SOCK_LISTS	ends

;;::::::::::::::
VxDCALL		macro	?api:req, ?cmd:req, ?pseg, ?pofs
	if	(@Model eq MODEL_FLAT)
		.err	VxDCALL: No 32-bit pmode support!
	endif

ifnb <?pseg>
		PS	ebx, es
		push	?pseg			;; es:ebx-> params
		pop	es			;; /

    ifdifi <?pseg>, <ss>
	ifndef	__LANG_PAS__
        	movdifi	ebx, O ?pofs		;; /
        else
            	xor	ebx, ebx
        	movdifi	bx, O ?pofs		;; /
        endif
    else
        	lea	ebx, ?pofs		;; /
    endif
endif
		movdifi	eax, ?cmd
		call	?api
ifnb <?pseg>
    		PP	es, ebx
endif
endm

;;::::::::::::::
TICKS_SINCE_MN	macro
if 		(@Model eq MODEL_FLAT)
		mov	eax, ds:[46Ch]
else
	ifdef	__MODE_PROT__
                .err	TICKS_SINCE_MN: No 16-bit pmode support!
	else
		push	es
		xor	ax, ax
		mov	es, ax
		mov	eax, D es:[46Ch]
		pop	es
	endif
endif
endm

__CONST__
sz_wsock2       byte    'WSOCK2', 0
sz_wsock2_vxd   byte    'WSOCK2.VXD', 0
sp_wsock2_vxd   byte    'WSOCK2  .VXD'

sz_dsock        byte    'DSOCK', 0
sz_dsock_vxd    byte    'DSOCK.VXD', 0
sp_dsock_vxd    byte    'DSOCK   .VXD'


DS_FIXSEG
w9x_initialized	dw	FALSE

drv_9X       	label	DSDRV
		tNEARPTR w9x_init, w9x_end
		tNEARPTR w9x_bind, w9x_getpeername, w9x_getsockname
		tNEARPTR w9x_getsockopt, w9x_ioctlsocket, w9x_listen
		tNEARPTR w9x_setsockopt, w9x_shutdown, w9x_socket
		tNEARPTR w9x_accept, w9x_closesocket, w9x_connect, w9x_recv
		tNEARPTR w9x_recvfrom, w9x_select, w9x_send, w9x_sendto
		tNEARPTR w9x_gethostbyaddr, w9x_gethostbyname, w9x_gethostname
		tNEARPTR w9x_getservbyport, w9x_getservbyname, w9x_getprotobynumber
		tNEARPTR w9x_getprotobyname
		tNEARPTR w9x_startup, w9x_cleanup, w9x_asyncselect

vxdldr_api      dword   NULL
wsock2_api      dword   NULL
dsock_api       dword   NULL
wsock2_loaded   word    FALSE
dsock_loaded    word    FALSE

ds_vmctx	dword	?

		ASYNCSEL_CNT 		equ 128	;; enough???
ASYNCSEL_llst	LLST	<?>

		SOCK_LISTS_CNT		equ 3	;; /
;;;;;;;;;;;;;;;;SOCK_LISTS_llst	LLST	<?>
SOCK_LISTS_ptr	dword	?

		MSG_CBUF_CNT		equ 256	;; /
msg_cbuf	CBUF	<?>

wrkFlag		byte	FALSE
DS_ENDS


.data ;; can't use __BSS__ 'cause m$ linker seems to have a bug that
      ;; will make it allocate WSABUF_CNT bytes for WSABUF_buf instead of
      ;; WSABUF_CNT WSABUF structs, grr
		WSABUF_CNT		equ 32	;; /
WSABUF_buf	WSABUF	WSABUF_CNT dup (<?>)
		WSABUF	4 dup (<?>)		;; +4 for safety


.data
WSABUF_ptr      tNEARPTR O WSABUF_buf


DS_CODE
;;:::
;; void unload_VxD(char *sz_vxd_name)
unload_VxD      proc    near pascal uses bx,\
                        sz_vxd_name:near ptr byte

                ;; get VxDLdr.VXD API's entry point, if not yet
                cmp     vxdldr_api, NULL
                jne     @F
                push    di
                push    es
                mov     bx, VXDLDR_ID
                mov     ax, 1684h
                int     2Fh
                mov     W vxdldr_api+0, di
                mov     W vxdldr_api+2, es
                pop     es
                pop     di

@@:             mov     bx, -1
                mov     dx, sz_vxd_name
                mov     ax, VXDLDR_UNLOAD
                call    vxdldr_api

                ret
unload_VxD      endp

;;:::
;; void unload_VxDs(void)
unload_VxDs     proc    near pascal

                ;; unload dsock.vxd (must be always the 1st unloaded!)
                cmp     dsock_loaded, TRUE
                jne     @F                      ;; VxD was loaded by us?
                invoke  unload_VxD, O sz_dsock
                mov     dsock_api, NULL
                mov     dsock_loaded, FALSE

@@:		;; unload wsock2.vxd
		cmp     wsock2_loaded, TRUE
                jne     @F                      ;; /
                invoke  unload_VxD, O sz_wsock2
                mov     wsock2_api, NULL
                mov	wsock2_loaded, FALSE

@@:             ret
unload_VxDs     endp

;;:::
;; far *load_VxD (char *sp_vxd_name, char *sz_vxd_name, bool far *vxd_loaded)
load_VxD        proc    near pascal uses bx di si fs es,\
                        sp_vxd_name:near ptr byte,\
                        sz_vxd_name:far ptr byte,\
                        vxd_loaded:far ptr word

		lfs     si, vxd_loaded          ;; -> bool
		mov     W fs:[si], FALSE	;; *vxd_loaded

		;; get VxDLdr.VXD API's entry point, if not yet
		cmp     vxdldr_api, NULL
		jne     @@get_api
		mov     bx, VXDLDR_ID
		mov     ax, 1684h
		int     2Fh
		mov     W vxdldr_api+0, di
		mov     W vxdldr_api+2, es

@@get_api:	;; get the API's entry pointer (if VxD is already loaded)
		mov     ax, ds
		mov     es, ax
		mov     di, sp_vxd_name
		xor     bx, bx
		mov     ax, 1684h
		int     2Fh
		mov     dx, es
		mov     ax, di
		or      di, dx
		jz      @@load                  ;; not loaded?

@@exit:		ret

@@load:		cmp     W fs:[si], FALSE	;; *vxd_loaded
		jne     @@error                 ;; already tried to load?

		;; load the VxD
		push	ds
		mov     ax, VXDLDR_LOAD
		PS	cs, @F
		push	vxdldr_api
		lds	dx, sz_vxd_name
		retf
@@:		pop	ds
		jc      @@error
		mov     W fs:[si], TRUE		;; *vxd_loaded
		jmp     short @@get_api

@@error:	xor     dx, dx			;; return NULL
		xor     ax, ax			;; /
		jmp     short @@exit
load_VxD        endp

;;:::
;; out: ax-> null-term before adding file-name
add_fname	proc	near pascal\
			uses di si es ds,\
			path:far ptr,\
			fname:far ptr

                les	di, path

		;; skip dir string
		mov	cx, 128
		xor	al, al
		repne	scasb
		dec	di

		mov	ax, di			;; (0)

		;; add back-slash to end if needed
		cmp	B es:[di-1], '\'
		je	@F
		mov	B es:[di], '\'
		inc	di

@@:		;; add file name
		lds	si, fname
@@loop:		mov	dl, ds:[si]
		inc	si
		mov	es:[di], dl
		inc	di
		test	dl, dl
		jnz	@@loop

		ret
add_fname	endp

;;:::
;; bool load_VxDs(char *path)
load_VxDs       proc    near pascal\
			uses bx es,\
			path:far ptr

                ;; load wsock2.vxd (must be always the 1st loaded!)
                invoke  load_VxD, O sp_wsock2_vxd,\
                                  A sz_wsock2_vxd,\
                                  A wsock2_loaded
                mov     W wsock2_api+0, ax
                mov     W wsock2_api+2, dx
                or      ax, dx
                jz      @@error

                ;; add dsock.vxd to path
                invoke  add_fname, path, A sz_dsock_vxd
                mov	bx, ax			;; save pos

                ;; load dsock.vxd
                invoke  load_VxD, O sp_dsock_vxd,\
                                  path,\
                                  A dsock_loaded
                mov     W dsock_api+0, ax
                mov     W dsock_api+2, dx
                or      ax, dx
                jz      @@error2

                mov	es, W path+2
                mov	B es:[bx], 0		;; restore null-term

                mov     ax, TRUE                ;; return true

@@exit:         ret

@@error2:       ;; unload wsock2.vxd
                invoke  unload_VxD, O sz_wsock2
                mov     wsock2_loaded, FALSE

@@error:        xor     ax, ax                  ;; return false
                jmp     short @@exit
load_VxDs       endp

;;:::
dsock_exists    proc    near pascal\
			uses bx es,\
			path:far ptr

        	invoke  add_fname, path, A sz_dsock_vxd
		push	ax

		;; try opening the file for read-only access
                les	dx, path
                push	ds
                mov	ds, W path+2
                xor	cl, cl
                mov	ax, 3D00h
                int	21h
                pop	ds
                jc	@@error

                ;; close it
                mov	bx, ax
                mov	ah, 3Eh
                int	21h

@@done:		clc				;; found

@@exit:		pop	bx			;; (0)
		mov	B es:[bx], 0		;; restore null-term

		ret

@@error:	;; if error were 'access denied', assume file exists
		cmp	ax, 5
		je	@@done
		stc				;; does not exist
		jmp	short @@exit
dsock_exists    endp

;;:::
find_path	proc	near pascal\
			uses bx di si es,\
			path:far ptr

                ;; try 1st at current drive and dir
                les	di, path
                push	ds
                mov	ds, W path+2
                mov     ah, 19h
                int     21h
                add     al, 'A'
                mov     B es:[di+0], al
                mov     W es:[di+1], '\:'
                lea     si, es:[di+3]
                xor     dl, dl
                mov     ah, 47h
                int     21h
                pop	ds
        	invoke  dsock_exists, path
		jnc	@@done

                ;; now try at exe's dir
                mov	ah, 62h
                int	21h
                mov	es, bx
                mov     es, es:[2Ch]		;; es:di-> env block seg
                xor	di, di			;; /

                ;; search for '\0''\0''1''\0' then '\0' then '\'
                xor     ax, ax                  ;; '\0'
                mov     cx, 32768               ;; max env. size
@@loop:		repne   scasb
                jne     @@not_found
                scasb
                jne     @@loop

                cmp     es:[di], ax
                je      @@not_found            ;; any string following?

                ;; get exe full path length
                add     di, 2
                mov     bx, di
                mov     cx, 128
                repne   scasb

                ;; exclude exe file name (go to last slash)
                std
                mov     al, '\'
                neg     cx
                add     cx, 128
                repne   scasb
                cld

                mov     cx, di
                sub     cx, bx
                add     cx, 2                   ;; cx= exe dir (w/o exe name)

                ;; move it to path
                push	ds
                mov     ax, es
                les     di, path		;; es:di -> path
                mov	ds, ax			;; ds:si -> exe dir
                mov     si, bx			;; /
                rep     movsb
                mov	B es:[di], 0		;; + null-term
                pop	ds

                invoke  dsock_exists, path
                jc	@@not_found

@@done:		clc

@@exit:		ret

@@not_found:	;; let Windows itself search at %PATH%
		les	di, path
		mov	B es:[di], 0
		stc
		jmp	short @@exit
find_path	endp

;;::::::::::::::
;; out: ax= 0 if ok
w9x_init	proc    near pascal uses bx si di es
                local	path[128]:byte

                cmp	w9x_initialized, TRUE
                je	@@done

                ;; create ASYNCSEL linked-list
                invoke	ListCreate, A ASYNCSEL_llst, ASYNCSEL_CNT, T ASYNCSEL
                mov	di, 1
                jc	@@error

                ;; and SOCK_LISTS
	;;;;;;;;invoke	ListCreate, A SOCK_LISTS_llst, SOCK_LISTS_CNT, T SOCK_LISTS
		MALLOC	T SOCK_LISTS
		mov	W SOCK_LISTS_ptr+0, ax
		mov	W SOCK_LISTS_ptr+2, dx
		test	dx, dx
                mov	di, 2
                jz	@@error2

                ;; create DSVXD_MSG circular-buffer
                invoke	CBufCreate, A msg_cbuf, MSG_CBUF_CNT, T DSVXD_MSG
                mov	di, 3
                jc	@@error3

                invoke	find_path, A path
                mov	di, 4
                jc      @@error4

                ;; load the vxds
                invoke  load_VxDs, A path
                test    ax, ax
                mov	di, 5
                jz      @@error4                ;; error?

                ;; es:ebx-> path
                mov     ax, ss
                mov     es, ax
                lea     ebx, path

                ;; init dsock
                VxDCALL dsock_api, DSVXD_INIT_CMD
                mov	di, 6
                jc	@@error5
                mov     ds_vmctx, eax

                mov	w9x_initialized, TRUE

@@done:		xor     ax, ax                	;; return ok (0)

@@exit:         ret

@@error5:	invoke  unload_VxDs

@@error4:	invoke	CBufDestroy, A msg_cbuf

@@error3:
	;;;;;;;;invoke	ListDestroy, A SOCK_LISTS_llst
		FREE	SOCK_LISTS_ptr
		mov	SOCK_LISTS_ptr, NULL

@@error2:       invoke	ListDestroy, A ASYNCSEL_llst

@@error:        ;mov     ax, -1                  ;; return error (-1)
		mov	ax, di
                jmp     short @@exit
w9x_init	endp

;;::::::::::::::
w9x_end       	proc    near pascal uses ebx

                cmp	w9x_initialized, TRUE
                jne	@@exit

                ;; finish with dsock
                mov	ebx, ds_vmctx
                VxDCALL dsock_api, DSVXD_END_CMD

                ;; unload wsock2 and dsock VxDs
                invoke  unload_VxDs

                ;; destroy DSVXD_MSG circular-buffer
                invoke	CBufDestroy, A msg_cbuf

                ;; destroy SOCK_LISTS linked-list
	;;;;;;;;invoke	ListDestroy, A SOCK_LISTS_llst
		FREE	SOCK_LISTS_ptr
		mov	SOCK_LISTS_ptr, NULL

		;; and ASYNCSEL
		invoke	ListDestroy, A ASYNCSEL_llst

                mov	w9x_initialized, FALSE

@@exit:         ret
w9x_end       	endp

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; non-blocking functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_bind	proc	near pascal
		local	ws2p:WS2_BIND
		CLEAR 	WS2_BIND, ss, ws2p

		mov	ws2p.Socket, eax
		mov	ws2p.Address, ebx
		mov	ws2p.AddressLength, ecx

		VxDCALL wsock2_api, WS2_BIND_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_bind	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_getpeername	proc	near pascal uses esi es
		local	ws2p:WS2_GETPEERNAME
		CLEAR 	WS2_GETPEERNAME, ss, ws2p

		;; namelen passed by value to wsock
	if	(@Model ne MODEL_FLAT)
		mov	esi, ecx
		shr	ecx, 16
		jz	@F			;; namelen= NULL?
		mov	es, cx			;; es:si-> namelen
		movzx	ecx, W es:[si]		;; ecx= *namelen
	else
		mov	esi, ecx
		jecxz	@F
		mov	ecx, [ecx]
	endif

@@:		mov	ws2p.Socket, eax
		mov	ws2p.Address, ebx
		mov	ws2p.AddressLength, ecx

		VxDCALL	wsock2_api, WS2_GETPEERNAME_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		;; fill namelen
		test	esi, esi
		jz	@F			;; namelen= NULL?
	if	(@Model ne MODEL_FLAT)
		mov	ax, W ws2p.AddressLength
	else
		mov	eax, ws2p.AddressLength
	endif
		mov	__ES:[__SI], __AX	;; *addrlen= len

@@:		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_getpeername	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_getsockname	proc	near pascal uses esi es
		local	ws2p:WS2_GETSOCKNAME
		CLEAR 	WS2_GETSOCKNAME, ss, ws2p

		;; namelen passed by value to wsock
	if	(@Model ne MODEL_FLAT)
		mov	esi, ecx
		shr	ecx, 16
		jz	@F			;; namelen= NULL?
		mov	es, cx			;; es:si-> namelen
		movzx	ecx, W es:[si]		;; ecx= *namelen
	else
		mov	esi, ecx
		jecxz	@F
		mov	ecx, [ecx]
	endif

@@:		mov	ws2p.Socket, eax
		mov	ws2p.Address, ebx
		mov	ws2p.AddressLength, ecx

		VxDCALL	wsock2_api, WS2_GETSOCKNAME_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		;; fill namelen
		test	esi, esi
		jz	@F			;; namelen= NULL?
	if	(@Model ne MODEL_FLAT)
		mov	ax, W ws2p.AddressLength
	else
		mov	eax, ws2p.AddressLength
	endif
		mov	__ES:[__SI], __AX	;; *addrlen= len

@@:		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_getsockname	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= level
;;	ecx= optname
;;	edx= optval
;;	edi= optlen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_getsockopt	proc	near pascal uses esi es
		local	ws2p:WS2_GETSOCKOPT
		CLEAR 	WS2_GETSOCKOPT, ss, ws2p

		;; optlen passed by value to wsock
	if	(@Model ne MODEL_FLAT)
		mov	esi, edi
		shr	edi, 16
		jz	@F			;; optlen= NULL?
		mov	es, di			;; es:si-> optlen
		movzx	edi, W es:[si]		;; edi= *optlen
	else
		mov	esi, edi
		test	edi, edi
		jz	@F
		mov	edi, [edi]
	endif

@@:		mov	ws2p.Socket, eax
		mov	ws2p.OptionLevel, ebx
		mov	ws2p.OptionName, ecx
		mov	ws2p.IntValue, edx
		mov	ws2p.ValueLength, edi

		VxDCALL	wsock2_api, WS2_GETSOCKOPT_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		;; fill optlen
		test	esi, esi
		jz	@F			;; optlen= NULL?
		mov	eax, ws2p.ValueLength
		mov	__ES:[__SI], eax	;; *optlen= len

@@:		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_getsockopt	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= cmd
;;	ecx= argp
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_ioctlsocket	proc	near pascal uses esi es
		local	ws2p:WS2_IOCTLSOCKET
		CLEAR 	WS2_IOCTLSOCKET, ss, ws2p

		;; argp passed by value to wsock
	if	(@Model ne MODEL_FLAT)
		mov	esi, ecx
		shr	ecx, 16
		jz	@F			;; argp= NULL?
		mov	es, cx			;; es:si-> argp
		mov	ecx, es:[si]		;; ecx= *argp
	else
		mov	esi, ecx
		test	ecx, ecx
		jz	@F
		mov	ecx, [ecx]
	endif

@@:		mov	ws2p.Socket, eax
		mov	ws2p.Command, ebx
		mov	ws2p.Param, ecx
                mov     ws2p.WSock2Version, 4

                VxDCALL	wsock2_api, WS2_IOCTLSOCKET_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		;; fill argp
		test	esi, esi
		jz	@F			;; argp= NULL?
		mov	eax, ws2p.Param
		mov	__ES:[__SI], eax	;; *argp= param

@@:		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_ioctlsocket	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= backlog
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_listen	proc	near pascal
		local	ws2p:WS2_LISTEN
		CLEAR 	WS2_LISTEN, ss, ws2p

		mov	ws2p.Socket, eax
		mov	ws2p.BacklogSize, ebx

		VxDCALL wsock2_api, WS2_LISTEN_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_listen	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= level
;;	ecx= optname
;;	edx= optval
;;	edi= optlen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_setsockopt	proc	near pascal
		local	ws2p:WS2_SETSOCKOPT
		CLEAR 	WS2_SETSOCKOPT, ss, ws2p

		mov	ws2p.Socket, eax
		mov	ws2p.OptionLevel, ebx
		mov	ws2p.OptionName, ecx
		mov	ws2p.IntValue, edx
		mov	ws2p.ValueLength, edi

		VxDCALL	wsock2_api, WS2_SETSOCKOPT_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_setsockopt	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= how
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_shutdown	proc	near pascal
		local	ws2p:WS2_SHUTDOWN
		CLEAR 	WS2_SHUTDOWN, ss, ws2p

		mov	ws2p.Socket, eax
		mov	ws2p.How, ebx

		VxDCALL	wsock2_api, WS2_SHUTDOWN_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_shutdown	endp

;;::::::::::::::
;;  in: eax= af
;;	ebx= type
;;	ecx= protocol
;;
;; out: eax= socket (= INVALID_SOCKET if error)
;;	dx= error code
w9x_socket	proc	near pascal
		local	ws2p:WS2_SOCKET
		CLEAR 	WS2_SOCKET, ss, ws2p

		mov	ws2p.Family, eax
		mov	ws2p.SocketType, ebx
		mov	ws2p.Protocol, ecx
		TICKS_SINCE_MN			;; must be an unique value
		mov	ws2p.NewSocketHandle, eax

		VxDCALL	wsock2_api, WS2_SOCKET_CMD, ss, ws2p
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		mov	eax, ws2p.NewSocket	;; return socket

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, INVALID_SOCKET	;; return invalid
		jmp	short @@exit
w9x_socket	endp

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; blocking functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;::::::::::::::
;;  in: eax= s
;;	ebx= addr
;;	ecx= addrlen
;;
;; out: eax= socket (= INVALID_SOCKET if error)
;;	dx= error code
w9x_accept	proc	near pascal uses esi es
		local	ws2p:WS2_ACCEPT, wsios:WSIOSTATUS
		CLEAR 	WS2_ACCEPT, ss, ws2p

		;; addrlen passed by value to wsock
	if	(@Model ne MODEL_FLAT)
		mov	esi, ecx
		shr	ecx, 16
		jz	@F			;; addrlen= NULL?
		mov	es, cx			;; es:si-> addrlen
		movzx	ecx, W es:[si]		;; ecx= *addrlen
	else
		mov	esi, ecx
		jecxz	@F
		mov	ecx, [ecx]
	endif

@@:		mov	ws2p.ListeningSocket, eax
		mov	ws2p.Address, ebx
		mov	ws2p.AddressLength, ecx
		TICKS_SINCE_MN			;; must be an unique value
        	mov 	ws2p.ConnectedSocketHandle, eax

		;; even passing NULL for both ApcRoutine and ApcContext
		;; fields, wsock2 will return immediatelly with the
		;; WS2_WILL_BLOCK result, being the socket in blocking
		;; mode or not, so the io status has to be checked anyway
		mov	ws2p.ApcRoutine, SPECIAL_16BIT_APC
		lea	__AX, wsios
		STOADDR	ws2p.ApcContext, ss, __AX
		mov	wsios.IoStatus, 0
		mov	D wsios.IoCompleted, 0

		VxDCALL	wsock2_api, WS2_ACCEPT_CMD, ss, ws2p
		cmp	ax, WS2_WILL_BLOCK
		je	@@wait_iostat		;; not an error
@@done:		test	ax, ax
		jnz	@@error			;; error?

		;; fill addrlen
		test	esi, esi
		jz	@F			;; addrlen= NULL?
	if	(@Model ne MODEL_FLAT)
		mov	ax, W ws2p.AddressLength
	else
		mov	eax, ws2p.AddressLength
	endif
		mov	__ES:[__SI], __AX	;; *addrlen= len

@@:		xor	dx, dx			;; no error
		mov	eax, ws2p.ConnectedSocket ;; return socket

@@exit:		ret

@@wait_iostat:	lea	__AX, wsios
		mov	ecx, WSIOS_TIMEOUT
		call	wait_iostatus
		cmp	wsios.IoTimedOut, TRUE
		jne	@@done
		mov	ax, 10000 + 60		;; WSAETIMEDOUT

@@error:	mov	dx, ax			;; save error
		mov	eax, INVALID_SOCKET	;; return invalid
		jmp	short @@exit
w9x_accept	endp

;;::::::::::::::
;;  in: eax= s
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_closesocket	proc	near pascal
		local	ws2p:WS2_CLOSESOCKET
		CLEAR 	WS2_CLOSESOCKET, ss, ws2p

		mov	ws2p.Socket, eax

		VxDCALL wsock2_api, WS2_CLOSESOCKET_CMD, ss, ws2p
		cmp	ax, WS2_WILL_BLOCK
		je	@F			;; not an error
		test	ax, ax
		jnz	@@error			;; error?

@@:		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_closesocket	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= name
;;	ecx= namelen
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_connect	proc	near pascal
		local	ws2p:WS2_CONNECT, wsios:WSIOSTATUS
		CLEAR 	WS2_CONNECT, ss, ws2p

		mov	ws2p.Socket, eax
		mov	ws2p.Address, ebx
		mov	ws2p.AddressLength, ecx

		mov	ws2p.ApcRoutine, SPECIAL_16BIT_APC
		lea	__AX, wsios
		STOADDR	ws2p.ApcContext, ss, __AX
		mov	wsios.IoStatus, 0
		mov	D wsios.IoCompleted, 0

		VxDCALL wsock2_api, WS2_CONNECT_CMD, ss, ws2p
		cmp	ax, WS2_WILL_BLOCK
		je	@@wait_iostat		;; not an error
@@done:		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@wait_iostat:	lea	__AX, wsios
		mov	ecx, WSIOS_TIMEOUT
		call	wait_iostatus
		cmp	wsios.IoTimedOut, TRUE
		jne	@@done
		mov	ax, 10000 + 60		;; WSAETIMEDOUT

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_connect	endp


ifndef          fd_set
fd_set          struct		4
                fd_count	dword   ?
                fd_array	dword	FD_SETSIZE dup (?)
fd_set          ends
endif

;;:::
;;  in: __ES:__DI-> SOCK_LIST
;;
;; out: eax= count
;;	ebx= __ES:__DI (NULL if no list or fd_count = 0)
fd_set2SOCK_LIST proc	near pascal\
			uses ecx edx __DI __SI ds,\
			fdset_list:FARPTR fd_set,\
			event:dword

		cmp	fdset_list, NULL
		je	@@null			;; no list?

	if	(@Model ne MODEL_FLAT)
		lds	si, fdset_list		;; __DS:__SI-> list
	else
		mov	esi, fdset_list
	endif

		mov	ecx, [__SI].fd_set.fd_count
		jecxz	@@null			;; count= 0?
		cmp	ecx, FD_SETSIZE
		jbe	@F
		mov	ecx, FD_SETSIZE
@@:
	if	(@Model ne MODEL_FLAT)
		PS	es, di			;; (0)
	else
		push	edi			;; /
	endif

		mov	ebx, event
		xor	eax, eax		;; count= 0

@@loop:		mov	edx, [__SI].fd_set.fd_array
		add	__SI, T dword
                test	edx, edx
                jz	@F			;; invalid socket?
                mov	__ES:[__DI].SOCK_LIST.Socket, edx
                mov	__ES:[__DI].SOCK_LIST.EventMask, ebx
                mov	__ES:[__DI].SOCK_LIST.Context, 0
                mov	__ES:[__DI].SOCK_LIST.Unknown, 0
                add	__DI, T SOCK_LIST
                inc	eax			;; ++count
                dec	ecx
                jnz	@@loop			;; not last?

@@:		pop	ebx			;; (0)

		test	eax, eax
		jz	@@null			;; count= 0?

@@exit:		ret

@@null:		xor	eax, eax
		xor	ebx, ebx
		jmp	short @@exit
fd_set2SOCK_LIST endp

;;:::
;;  in: __ES:__DI-> SOCK_LIST
;;
;; out: eax= count
SOCK_LIST2fd_set proc	near pascal\
			uses ecx edx __DI __SI ds,\
			fdset_list:FARPTR fd_set

		cmp	fdset_list, NULL
		je	@@null			;; no list?

	if	(@Model ne MODEL_FLAT)
		lds	si, fdset_list		;; __DS:__SI-> list
	else
		mov	esi, fdset_list		;; /
	endif

		push	__SI			;; (0)
		xor	eax, eax		;; count= 0
		mov	__CX, FD_SETSIZE

@@loop:		mov	edx, __ES:[__DI].SOCK_LIST.Socket
                add	__DI, T SOCK_LIST
                test	edx, edx
                jz	@@next			;; socket= 0?

		mov	[__SI].fd_set.fd_array, edx
		add	__SI, T dword
                inc	eax			;; ++count

@@next:		dec	__CX
                jnz	@@loop

		pop	__SI			;; (0)
		mov	[__SI].fd_set.fd_count, eax

@@exit:		ret

@@null:		xor	eax, eax
		jmp	short @@exit
SOCK_LIST2fd_set endp

;ifndef		timeval
timeval		struct		4
        	tv_sec		dword	?
		tv_usec		dword	?
timeval		ends
;endif

;;::::::::::::::
;;  in: eax= nfsd
;;	ebx= *readfds
;;	ecx= *writefds
;;	edx= *exceptfds
;;	edi= *timeout
;;
;; out: eax= count (= SOCKET_ERROR if not ok)
;;	dx= error code
w9x_select	proc	near pascal uses esi es fs
		local	ws2p:WS2_SELECT_CLEANUP,\
			ws2ps:WS2_SELECT_SETUP,\
			wsios:WSIOSTATUS

	;;;;;;;;CLEAR 	WS2_SELECT_CLEANUP, ss, ws2p
	;;;;;;;;CLEAR 	WS2_SELECT_SETUP, ss, ws2ps

		mov	esi, edi		;; esi= *timeout

         ;;;;;;;invoke	ListAlloc, A SOCK_LISTS_llst
         ;;;;;;;mov     ax, 1234
         ;;;;;;;jc	@@error
         	les	di, SOCK_LISTS_ptr

		;; timeout= { 0, 0 }?
		test	esi, esi
		jz	@F			;; NULL?
	if	(@Model ne MODEL_FLAT)
		mov	eax, esi
		shr	eax, 16
		mov	fs, ax
		cmp	fs:[si].timeval.tv_sec, 0
		jne	@F
		cmp	fs:[si].timeval.tv_usec, 0
		je	@@cleanup
	else
		cmp	[esi].timeval.tv_sec, 0
		jne	@F
		cmp	[esi].timeval.tv_usec, 0
		je	@@cleanup
	endif

@@:		;; convert from fd_set to SOCK_LIST
		PS	ebx, __DI		;; (0)
		invoke	fd_set2SOCK_LIST, ebx, FD_READ or FD_ACCEPT
                mov	ws2ps.ReadCount, eax
                mov	ws2ps.ReadList, ebx

                lea	__DI, [__DI].SOCK_LISTS.WriteList
                invoke	fd_set2SOCK_LIST, ecx, FD_WRITE or FD_CONNECT
                mov	ws2ps.WriteCount, eax
                mov	ws2ps.WriteList, ebx

                add	__DI, T SOCK_LIST * FD_SETSIZE
                invoke	fd_set2SOCK_LIST, edx, FD_FAILED_CONNECT or FD_OOB
                mov	ws2ps.ExceptCount, eax
                mov	ws2ps.ExceptList, ebx
                PP	__DI, ebx		;; (0)

		mov	ws2ps.ApcRoutine, SPECIAL_16BIT_APC
		lea	__AX, wsios
		STOADDR	ws2ps.ApcContext, ss, __AX
		mov	wsios.IoStatus, 0
		mov	D wsios.IoCompleted, 0

		VxDCALL wsock2_api, WS2_SELECT_SETUP_CMD, ss, ws2ps
		cmp	ax, WS2_WILL_BLOCK
		je	@F			;; not an error
		test	ax, ax
		jnz	@@error			;; error?

@@wait:		;; wait iostatus or timeout
		PS	ecx, edx		;; (0)
		test	esi, esi
		jnz	@F			;; timeout != NULL?
		mov	ecx, WSIOS_TIMEOUT
		jmp	short @@wait_io

@@:		;; convert to ticks
		mov	eax, 18			;; 18.2
		mul	__FS:[__SI].timeval.tv_sec
		push	eax
		xor	edx, edx
		mov	eax, __FS:[__SI].timeval.tv_usec
		mov	ecx, 55000		;; 55000 us p/ tick
		div	ecx
		pop	ecx
		add	ecx, eax

@@wait_io:	lea	__AX, wsios
		call	wait_iostatus
		PP	edx, ecx		;; (0)
		jc	@F			;; _iostat' timeout doesn't matter
		cmp	wsios.IoCancelled, TRUE
		je	@@error
		cmp	wsios.IoTimedOut, TRUE
		jne	@@cleanup
		jmp	@@error

@@:		test	esi, esi
		jz	@@wait			;; timeout= NULL?

@@cleanup:	;; clear list
	if	(@Model ne MODEL_FLAT)
		CLEAR	T SOCK_LISTS, es, di
	else
		CLEAR	T SOCK_LISTS, edi
	endif

		;; convert from fd_set to SOCK_LIST
		PS	ebx, __DI		;; (0)
		invoke	fd_set2SOCK_LIST, ebx, FD_READ or FD_ACCEPT
                mov	ws2p.ReadCount, eax
                mov	ws2p.ReadList, ebx

                lea	__DI, [__DI].SOCK_LISTS.WriteList
                invoke	fd_set2SOCK_LIST, ecx, FD_WRITE or FD_CONNECT
                mov	ws2p.WriteCount, eax
                mov	ws2p.WriteList, ebx

                add	__DI, T SOCK_LIST * FD_SETSIZE
                invoke	fd_set2SOCK_LIST, edx, FD_FAILED_CONNECT or FD_OOB
                mov	ws2p.ExceptCount, eax
                mov	ws2p.ExceptList, ebx
                PP	__DI, ebx		;; (0)

		VxDCALL wsock2_api, WS2_SELECT_CLEANUP_CMD, ss, ws2p
                test	ax, ax
		jnz	@@error			;; error?

                ;; convert back to fd_set
                push	__DI			;; (0)
                invoke	SOCK_LIST2fd_set, ebx
                mov	ebx, eax		;; save count

                lea	__DI, [__DI].SOCK_LISTS.WriteList
                invoke	SOCK_LIST2fd_set, ecx
                add	ebx, eax		;; ++count

                add	__DI, T SOCK_LIST * FD_SETSIZE
                invoke	SOCK_LIST2fd_set, edx
                add	eax, ebx		;; ++count
                pop	__DI			;; (0)

                xor	dx, dx			;; no error

@@exit:	;;;;;;;;invoke	ListFree, A SOCK_LISTS_llst, __DI
		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_select	endp

comment `
;;:::
;;  in: eax= socket
;;	ebx= event mask
;;
;; out: ax= count (=1 if ready, =0 if not, >1 if error)
h_selsocket	proc	near pascal uses ecx
                local	ws2p:WS2_SELECT_CLEANUP, slist:SOCK_LIST
                CLEAR 	WS2_SELECT_CLEANUP, ss, ws2p

		mov	ecx, eax
		mov	slist.Socket, eax
		mov	slist.EventMask, ebx
		mov	slist.Context, 0

		lea	ax, slist
		STOADDR	ws2p.ReadList, ss, ax
		mov	ws2p.ReadCount, 1

		VxDCALL wsock2_api, WS2_SELECT_CLEANUP_CMD, ss, ws2p
                test	ax, ax
		jnz	@@exit			;; error?

		cmp	slist.Socket, ecx
		jne	@@exit			;; not same?

		mov	ax, 1			;; return count

@@exit:		ret
h_selsocket	endp
`

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; blocking + buggy functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;::::::::::::::
;;  in: eax= s
;;	ebx= buf
;;	ecx= len
;;	edx= flags
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_recv	proc	near pascal uses edi esi
		xor	edi, edi
		xor	esi, esi
		call	w9x_recvfrom
		ret
w9x_recv	endp

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
w9x_recvfrom	proc	near pascal uses es
		local	dsp:DSVXD_RECV, wsios:WSIOSTATUS, buf:NEARPTR
		CLEAR 	DSVXD_RECV, ss, dsp

		;; wasbuf has to stay valid for non-blocking sockets
		push	esi
		CIRBUF_ALLOC WSABUF
		mov	ds:[__SI].WSABUF.buf, ebx
		mov	ds:[__SI].WSABUF.len, ecx
		mov	buf, __SI
		pop	esi

		;; set params than won't be changed by the vxd
		mov	dsp.params.Socket, eax
		mov	dsp.params.Flags, edx
		mov	dsp.params.BufferCount, 1
		mov	dsp.params.ApcRoutine, SPECIAL_16BIT_APC

		;; fromlen passed by value to wsock
		xor	eax, eax
	if	(@Model ne MODEL_FLAT)
		mov	edx, esi
		shr	edx, 16
		jz	@F			;; NULL?
		mov	es, dx
		movzx	eax, W es:[si]
	else
		test	esi, esi
		jz	@F
		mov	eax, [esi]
	endif
@@:		mov	dsp.params.AddressLength, eax

@@try_again:	PS	edi, esi		;; (0)

		mov	__AX, buf
		STOADDR	dsp.params.Buffers, ds, __AX
		mov	dsp.params.Address, edi
		mov	dsp.params.AddrLenPtr, esi
		lea	__AX, wsios
		STOADDR	dsp.params.ApcContext, ss, __AX
		mov	wsios.IoStatus, 0
		mov	D wsios.IoCompleted, 0

        	VxDCALL	dsock_api, DSVXD_RECV_CMD, ss, dsp
		cmp	ax, WS2_WILL_BLOCK
		je	@@wait_iostat		;; not an error
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		mov	eax, dsp.params.BytesReceived	;; /

@@exit:		add	__SP, 4+4		;; (0)
		ret

@@wait_iostat:	lea	__AX, wsios
		mov	ecx, WSIOS_TIMEOUT
		call	wait_iostatus
		cmp	wsios.IoTimedOut, TRUE
		je	@@error2
                PP	esi, edi		;; (0)
                mov	dsp.buf2lin, 1		;; do not remap
                jmp	@@try_again

@@error2:	mov	ax, 10000 + 60		;; WSAETIMEDOUT

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_recvfrom	endp

;;::::::::::::::
;;  in: eax= s
;;	ebx= *buf
;;	ecx= len
;;	edx= flags
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_send	proc	near pascal uses edi esi
		xor	edi, edi
		xor	esi, esi
		call	w9x_sendto
		ret
w9x_send	endp

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
w9x_sendto	proc	near pascal uses es
		local	dsp:DSVXD_SEND, wsios:WSIOSTATUS, buf:NEARPTR
		CLEAR 	DSVXD_SEND, ss, dsp

		;; wasbuf has to stay valid for non-blocking sockets
		push	esi
		CIRBUF_ALLOC WSABUF
		mov	ds:[__SI].WSABUF.buf, ebx
		mov	ds:[__SI].WSABUF.len, ecx
		mov	buf, __SI
		pop	esi

		;; set params than won't be changed by the vxd
		mov	dsp.params.Socket, eax
		mov	dsp.params.Flags, edx
		mov	dsp.params.BufferCount, 1
		mov	dsp.params.AddressLength, esi
		mov	dsp.params.ApcRoutine, SPECIAL_16BIT_APC

@@try_again:	push	edi			;; (0)

		mov	__AX, buf
		STOADDR	dsp.params.Buffers, ds, __AX
		mov	dsp.params.Address, edi

		lea	__AX, wsios
		STOADDR	dsp.params.ApcContext, ss, __AX
		mov	wsios.IoStatus, 0
		mov	D wsios.IoCompleted, 0

        	VxDCALL dsock_api, DSVXD_SEND_CMD, ss, dsp
		cmp	ax, WS2_WILL_BLOCK
		je	@@wait_iostat		;; not an error
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		mov	eax, dsp.params.BytesSent;; /

@@exit:		add	__SP, 4			;; (0)
		ret

@@wait_iostat:	lea	__AX, wsios
		mov	ecx, WSIOS_TIMEOUT
		call	wait_iostatus
		cmp	wsios.IoTimedOut, TRUE
		je	@@error2
                pop	edi			;; (0)
                mov	dsp.buf2lin, 1		;; do not remap
                jmp	@@try_again

@@error2:	mov	ax, 10000 + 60		;; WSAETIMEDOUT

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_sendto	endp

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; database (blocking) functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

	;; have to pass a buffer after the struct to where the vxd
	;; will copy the struct + data that winsock.dll getXbyY will
	;; return, as all pointers will be pointing to the dll's
	;; process and can't be accessed directly from dos (nor in
	;; pmode as dosvm LDT != sysvm LDT)

;;::::::::::::::
;;  in: eax= addr
;;	ebx= len
;;	ecx= type
;;	__ES:__DI-> hostent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
w9x_gethostbyaddr proc	near pascal
		local	dsp:DSVXD_HOSTBYADDR
	;;;;;;;;CLEAR 	DSVXD_HOSTBYADDR, ss, dsp

		mov	dsp.params._addr, eax
		mov	dsp.params._len, bx
		mov	dsp.params._type, cx
		mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax
		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	edx, es			;; edx= /      addr
		shl	edx, 16                 ;; /
		mov	dx, di                  ;; /
	else
		mov	edx, edi
	endif

        	VxDCALL dsock_api, DSVXD_HOSTBYADDR_CMD, ss, dsp
		jc	@@error
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

@@error:	mov	eax, NULL		;; return error
		jmp	short @@exit
w9x_gethostbyaddr endp

;;::::::::::::::
;;  in: eax= name
;;	__ES:__DI-> hostent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
w9x_gethostbyname proc	near pascal
		local	dsp:DSVXD_HOSTBYNAME
	;;;;;;;;CLEAR 	DSVXD_HOSTBYNAME, ss, dsp

		mov	dsp.params._name, eax
		mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax
		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	edx, es			;; edx= /      addr
		shl	edx, 16                 ;; /
		mov	dx, di                  ;; /
	else
		mov	edx, edi
	endif

        	VxDCALL dsock_api, DSVXD_HOSTBYNAME_CMD, ss, dsp
		jc	@@error
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

@@error:	mov	eax, NULL		;; return error
		jmp	short @@exit
w9x_gethostbyname endp

;;::::::::::::::
;;  in: eax= name
;;	ebx= namelen
;;
;; out: eax= result (=0 if ok)
;;	dx= error code
w9x_gethostname	proc	near pascal
		local	dsp:DSVXD_HOSTNAME
	;;;;;;;;CLEAR 	DSVXD_HOSTNAME, ss, dsp

		mov	dsp.params._name, eax
		mov	dsp.params._namelen, bx
		mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax

        	VxDCALL dsock_api, DSVXD_HOSTNAME_CMD, ss, dsp
		jc	@@error
		test	ax, ax
		jnz	@@error			;; error?

		xor	dx, dx			;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	eax, SOCKET_ERROR	;; return error
		jmp	short @@exit
w9x_gethostname	endp

;;::::::::::::::
;;  in: eax= port
;;	ebx= proto
;;	__ES:__DI-> servent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
w9x_getservbyport proc	near pascal
		local	dsp:DSVXD_SERVBYPORT
	;;;;;;;;CLEAR 	DSVXD_SERVBYPORT, ss, dsp

		mov	dsp.params._port, ax
		mov	dsp.params._proto, ebx
		mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax
		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	edx, es			;; edx= /      addr
		shl	edx, 16                 ;; /
		mov	dx, di                  ;; /
	else
		mov	edx, edi
	endif

        	VxDCALL dsock_api, DSVXD_SERVBYPORT_CMD, ss, dsp
		jc	@@error
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

@@error:	mov	eax, NULL		;; return error
		jmp	short @@exit
w9x_getservbyport endp

;;::::::::::::::
;;  in: eax= name
;;	ebx= proto
;;	__ES:__DI-> servent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
w9x_getservbyname proc	near pascal
		local	dsp:DSVXD_SERVBYNAME
	;;;;;;;;CLEAR 	DSVXD_SERVBYNAME, ss, dsp

		mov	dsp.params._name, eax
		mov	dsp.params._proto, ebx
		mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax
		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	edx, es			;; edx= /      addr
		shl	edx, 16                 ;; /
		mov	dx, di                  ;; /
	else
		mov	edx, edi
	endif

        	VxDCALL dsock_api, DSVXD_SERVBYNAME_CMD, ss, dsp
		jc	@@error
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

@@error:	mov	eax, NULL		;; return error
		jmp	short @@exit
w9x_getservbyname endp

;;::::::::::::::
;;  in: eax= number
;;	__ES:__DI-> protoent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
w9x_getprotobynumber proc near pascal
		local	dsp:DSVXD_PROTOBYNUMBER
	;;;;;;;;CLEAR 	DSVXD_PROTOBYNUMBER, ss, dsp

		mov	dsp.params._number, ax
		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	edx, es			;; edx= /      addr
		shl	edx, 16                 ;; /
		mov	dx, di                  ;; /
	else
		mov	edx, edi
	endif

        	VxDCALL dsock_api, DSVXD_PROTOBYNUMBER_CMD, ss, dsp
		jc	@@error
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

@@error:	mov	eax, NULL		;; return error
		jmp	short @@exit
w9x_getprotobynumber endp

;;::::::::::::::
;;  in: eax= name
;;	__ES:__DI-> protoent struct + buffer
;;	esi= buffer len
;;
;; out: eax= __ES:__DI or NULL if error
;;	dx= error code
w9x_getprotobyname proc	near pascal
		local	dsp:DSVXD_PROTOBYNAME
	;;;;;;;;CLEAR 	DSVXD_PROTOBYNAME, ss, dsp

		mov	dsp.params._name, eax
		mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax
		mov	ecx, esi		;; ecx= buffer len
	if	(@Model ne MODEL_FLAT)
		mov	edx, es			;; edx= /      addr
		shl	edx, 16                 ;; /
		mov	dx, di                  ;; /
	else
		mov	edx, edi
	endif

        	VxDCALL dsock_api, DSVXD_PROTOBYNAME_CMD, ss, dsp
		jc	@@error
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

@@error:	mov	eax, NULL		;; return error
		jmp	short @@exit
w9x_getprotobyname endp
DS_ENDS

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; extension functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

.data
asselwrp_flg	word 	FALSE


DS_CODE
;;::::::::::::::
;;  in: eax= wVersionRequested
;;	ebx= lpWSAData
;;
;; out: ax= 0 if ok
w9x_startup	proc	near pascal
		local	dsp:DSVXD_STARTUP
	;;;;;;;;CLEAR 	DSVXD_STARTUP, ss, dsp

                cmp	w9x_initialized, TRUE
                jne	@@error

		mov	dsp.params._wVersionRequested, ax
		mov	dsp.params._lpWSAData, ebx
                mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax

                ;; try starting dsock/winsock
                VxDCALL dsock_api, DSVXD_STARTUP_CMD, ss, dsp
                jc      @@error                 ;; error?

		xor     ax, ax                	;; return ok (0)

@@exit:         ret

@@error:       	sbb	ax, ax			;; return error (-1)
		jmp     short @@exit
w9x_startup 	endp

;;::::::::::::::
;; out: eax= 0 if ok
;;	dx= error code
w9x_cleanup	proc	near pascal uses cx __DI es

                cmp	w9x_initialized, TRUE
                jne	@@error

		;; free all nodes in ASYNCSEL linked-list
		mov	asselwrp_flg, TRUE

		invoke	ListLast, A ASYNCSEL_llst
		jz	@F
@@loop:		mov	__ES:[__DI].ASYNCSEL.id, 0
		mov	__ES:[__DI].ASYNCSEL.socket, 0
		mov	__AX, __DI
		invoke	ListPrev		;; __DI= prev
		invoke	ListFree, A ASYNCSEL_llst, __AX
		test	__DI, __DI
		jnz	@@loop			;; any node left?

@@:		mov	asselwrp_flg, FALSE

                ;; stop dsock/winsock
                VxDCALL dsock_api, DSVXD_CLEANUP_CMD
                jc      @@error
                test    ax, ax
                jnz     @@error                 ;; error?


@@done:         xor     dx, dx                  ;; no error
		xor	eax, eax		;; /

@@exit:		ret

@@error:	mov	dx, ax			;; save error
		mov	ax, -1			;; return error (-1)
		jmp	short @@exit
w9x_cleanup	endp

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

;;::::::::::::::
;;  in: eax= s
;;	ebx= hWnd
;;	ecx= wMsg
;;	edx= lEvent
;;
;; out: eax= result (= 0 if ok)
;;	dx= error code
w9x_asyncselect	proc	near pascal uses __DI es
		local	dsp:DSVXD_ASYNC_SEL
	;;;;;;;;CLEAR 	DSVXD_ASYNC_SEL, ss, dsp

		;; search if a node for this socket already exists
		call	h_aselList_find
		test	__DI, __DI
		jnz	@F			;; found?

		;; allocate a new node for ASYNCSELCB struct if any
		;; event selected
                test	edx, edx
		je	@@vxd_call		;; no events?
		invoke	ListAlloc, A ASYNCSEL_llst
		jc	@@error

@@:		;; fill node
		mov	__ES:[__DI].ASYNCSEL.id, 'CB16'
		mov	__ES:[__DI].ASYNCSEL.socket, eax
		mov	__ES:[__DI].ASYNCSEL.fpProc, ebx
		mov	__ES:[__DI].ASYNCSEL.wMsg, ecx

@@vxd_call:	mov	dsp.params.Socket, eax
		mov	dsp.params.Events, edx
		STOADDR	dsp.params.Window, cs, O asyncsel_wrp
		STOADDR	dsp.params.Message, __ES, __DI
		STOADDR	dsp.cbuf, S msg_cbuf, O msg_cbuf
		STOADDR	dsp.fpWrkFlag, S wrkFlag, O wrkFlag
                mov	eax, ds_vmctx
		mov	dsp.vm_ctx, eax

		push	dsp.params.Events
        	VxDCALL dsock_api, DSVXD_ASYNC_SELECT_CMD, ss, dsp
		pop	edx
		jc	@@error2
		test	ax, ax
		jnz	@@error2		;; error?

		test	edx, edx
		jnz	@@done			;; any event?

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
w9x_asyncselect	endp
DS_ENDS


__BSS__
ds$stks_buf	byte	(STK_SIZE*MAX_STKS) dup (?)

cur_stack	dword	?
		word	?

.data
stks_ptr	tNEARPTR O ds$stks_buf + (STK_SIZE*MAX_STKS)


DS_CODE
;;:::
asyncsel_wrp	proc	far pascal

	if	(@Model ne MODEL_FLAT)
		;; ds-> dgroup
		mov	ax, @data
		mov	ds, ax
	else
		.exit	ERROR: No flat-mode support in drv9X::asyncsel_wrp proc yet
	endif

		;; msg_cbuf being accessed currently?
		cmp	asselwrp_flg, TRUE
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
		CBUFGET	msg_cbuf, <T DSVXD_MSG>
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
		les	di, fs:[bx].DSVXD_MSG.wMsg
	else
		mov	edi, [ebx].DSVXD_MSG.wMsg
	endif

		;; is it a valid struct?
		cmp	__ES:[__DI].ASYNCSEL.id, 'CB16'
		jne	@@loop

		;; call the callback
		push	__ES:[__DI].ASYNCSEL.wMsg
		push	__FS:[__BX].DSVXD_MSG.wParam
		push	__FS:[__BX].DSVXD_MSG.lParam
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

@@exit:		mov	wrkFlag, FALSE		;; alert the vxd
		ret
asyncsel_wrp	endp

;;:::
;;  in: ss:__AX-> wsios
;;	ecx= timeout in clock-ticks (1 tick= 55ms)
;;
;; out: ax= result
;;	CF set if IoTimedOut was set locally, clean otherwise
wait_iostatus	proc	near pascal uses ebx edx __BP ds

		mov	__BP, __AX		;; ss:bp-> wsios

	if 	(@Model ne MODEL_FLAT)
		xor	ax, ax
		mov	ds, ax
	endif

		xor	ebx, ebx		;; assume no mn wrap around
		mov	eax, 1573040
		sub	eax, ecx		;; mn - timeout

		mov	edx, D ds:[46Ch]

		;; check for midnight wrap around
		cmp	edx, eax		;; mn - n secs
		jb	@@loop
		mov	ebx, ecx
		mov	ecx, 1573040
		sub	ecx, edx		;; ecx= ticks before mn
		sub	ebx, ecx		;; ebx= diff

@@loop:		cmp	D [__BP].WSIOSTATUS.IoCompleted, 0
		jne	@@done			;; any flat set?
		mov	eax, D ds:[46Ch]
		sub	eax, edx		;; eax= curr - start
		cmp	eax, ecx
		jbe	@@loop			;; not timed-out?

		test	ebx, ebx
		jz	@@error			;; no wrap?
		mov	edx, D ds:[46Ch]
		mov	ecx, ebx		;; diff
		xor	ebx, ebx
		jmp	short @@loop

@@done:		;; return status
		mov	ax, W [__BP].WSIOSTATUS.IoStatus
                clc

@@exit:		ret

@@error:	mov	[__BP].WSIOSTATUS.IoTimedOut, TRUE
		mov	ax, 10000 + 60		;; WSAETIMEDOUT
		stc
		jmp	short @@exit
wait_iostatus	endp
DS_ENDS
                __END__
