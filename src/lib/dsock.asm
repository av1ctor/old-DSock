;;
;; dsock.asm -- high-level interface
;;

                include lang.inc

                include equ.inc
                include intern.inc
                include	wintypes.inc
                include dsock.inc

	ifdef	__LANG_PAS__
		include	drvDOS.asm
		include drv9X.asm
		include drvNT.asm
		include	llist.asm
		include	cbuf.asm
	endif

	ifdef	__LANG_BAS__
                h_zStr2bStr 	proto near pascal :near ptr, :near ptr BASSTR, :word
                h_bStr2zStr 	proto near pascal :near ptr BASSTR, :near ptr, :word
                h_strncpy	proto near pascal :far ptr, :far ptr, :word
	endif


		DS_REG_LIST_0		equ	eax
		DS_REG_LIST_1		equ	ebx
		DS_REG_LIST_2		equ	ecx
		DS_REG_LIST_3		equ	edx
		DS_REG_LIST_4		equ	edi
		DS_REG_LIST_5		equ	esi
;;::::::::::::::
DS_BODY_MOV     macro   ?reg:req, ?param:req
	if 	(T ?param eq 2)
		movsx	DS_REG_LIST_&?reg&, ?param
	else
                mov     DS_REG_LIST_&?reg&, ?param
	endif
endm
;;::::::::::::::
DS_BODY		macro	?ret:req, ?proc:req, ?errnum:req, ?params:vararg
                local	@@error, @@exit, ?a, ?cnt, ?reg

		?cnt	= 0
ifnb	<?params>
        for     ?a, <?params>
		?cnt	= ?cnt + 1
	endm
endif

	if	(?cnt gt 1)
		push	ebx
	endif
	if	(?cnt gt 4)
		push	edi
	endif
	if	(?cnt gt 5)
		push	esi
	endif

                cmp     initialized, TRUE
                jne     @@error			;; not initialized?

ifnb	<?params>
		?reg	= 0
        for     ?a, <?params>
                DS_BODY_MOV %?reg, <?a>
		?reg	= ?reg + 1
	endm
endif

		call	dsdrv.&?proc

                mov     ws_lastError, dx
	ifdifi	<?ret>, <int>
                RETLONG  eax
        endif

@@exit:
	if	(?cnt gt 5)
		pop	esi
	endif
	if	(?cnt gt 4)
		pop	edi
	endif
        if      (?cnt gt 1)
		pop	ebx
	endif

		ret

@@error:        mov     ws_lastError, WSANOTINITIALISED
        ifdifi	<?ret>, <int>
                RETLONG  %?errnum
        else
        	mov	eax, ?errnum
        endif
		jmp	short @@exit
endm


;;::::::::::::::
.fardata?
		XbyY_LEN		equ 1024	;; enough???
XbyY_buf	byte	(XbyY_LEN * 4) dup (?)


.data ;__BSS__
ifdef		__LANG_BAS__
	ifdef   __FAR_STRINGS__
		dw	?			;; fstr len (@ str_buf-2!!)
	endif
str_buf		byte	128 dup (?)
		byte	32 dup (?)

bstr		BASSTR	<?>
endif

ifndef		__LANG_BAS__
ntoa_buf	byte	4+4+4+4+1 dup (?)
endif

ifdef		__LANG_PAS__
last_exitproc	dword	?
endif


.data
ws_lastError	word 	WSANOTINITIALISED, 0

XbyY_ptr	tNEARPTR XbyY_buf

ifdef   	__FAR_STRINGS__
fstr_segTb 	dw      ?
fstr_ofsTb 	dw      NULL
                dw      ?
endif

ifdef		__LANG_BAS__
zstr_ptr	dd	str_buf
		dd	str_buf + 128
endif

ifdef		__LANG_PAS__
		extern	exitproc:dword
endif


__CONST__
thtb		byte	10, 100


DS_FIXSEG
initialized     word    FALSE
dsdrv           DSDRV   <?>
DS_ENDS


DS_CODE
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; non-blocking functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;::::::::::::::
;; int WSAAPI bind(SOCKET s, const struct sockaddr FAR * name, int namelen)
bind		proc	WSAAPI public\
			s:SOCKET,\
			_name:FARPTR sockaddr,\
			namelen:SINT

		DS_BODY	int, bind, SOCKET_ERROR, s, _name, namelen
bind		endp

;;::::::::::::::
;; int WSAAPI getpeername(SOCKET s, struct sockaddr FAR * name,
;;                        int FAR * namelen)
getpeername	proc	WSAAPI public\
			s:SOCKET,\
			_name:FARPTR sockaddr,\
			namelen:FARPTR SINT

		DS_BODY	int, getpeername, SOCKET_ERROR, s, _name, namelen
getpeername	endp

;;::::::::::::::
;; int WSAAPI getsockname(SOCKET s, struct sockaddr FAR * name,
;;                        int FAR * namelen)
getsockname	proc	WSAAPI public\
			s:SOCKET,\
			_name:FARPTR sockaddr,\
			namelen:FARPTR SINT

		DS_BODY	int, getsockname, SOCKET_ERROR, s, _name, namelen
getsockname	endp

;;::::::::::::::
;; int WSAAPI getsockopt(SOCKET s, int level, int optname,
;;                       char FAR * optval, int FAR * optlen)
getsockopt	proc 	WSAAPI public\
			s:SOCKET,\
			level:SINT,\
			optname:SINT,\
			optval:FARPTR CHAR,\
			optlen:FARPTR SINT

		DS_BODY	int, getsockopt, SOCKET_ERROR, s, level, optname, optval, optlen
getsockopt	endp

;;::::::::::::::
;; u_long WSAAPI htonl(u_long hostlong)
htonl		proc	WSAAPI public\
			hostlong:u_long

		mov	edx, hostlong
		mov	eax, edx
		rol	edx, 8
		ror	eax, 8
		and	edx, 000FF00FFh
		and	eax, 0FF00FF00h
		or	eax, edx

		RETLONG	eax
		ret
htonl		endp

;;::::::::::::::
;; u_short WSAAPI htons(u_short hostshort)
htons		proc	WSAAPI public\
			hostshort:u_short

		mov	ax, hostshort
		xchg	al, ah

		ret
htons		endp

;;:::
;;  in: es:__BX-> src
;;
;; out: CF set if (char < 0 or > 255) or
;;	       if (digits < 0 or > 9) or
;;	       if (char after num isn't '.' or '\0')
;;	al= char
;;	__BX updated
h_a2c		proc	near pascal uses cx __SI

                xor	cl, cl

		;; find dot
		mov	ax, es:[__BX+1]
		cmp	al, '.'
		je	@@last
		test	al, al
		jz	@@last
		mov	__SI, 1
		cmp	ah, '.'
		je	@@loop
		test	ah, ah
		jz	@@loop
		inc	__SI

@@loop:		mov	al, es:[__BX]
		inc	__BX
		sub	al, '0'
		cmp	al, 9
		ja	@@error
		mul	thtb[__SI-1]
		add	cl, al
		jc	@@exit
		dec	__SI
		jnz	@@loop

@@last:		mov	ax, es:[__BX]
		add	__BX, 2
		sub	al, '0'
		cmp	al, 9
		ja	@@error
		add	al, cl
		jc	@@exit

		;; char= . or \0?
		cmp	ah, '.'
		je	@@exit
		test	ah, ah
		jz	@@exit

@@error:	stc				;; error

@@exit:		ret
h_a2c		endp

;;::::::::::::::
;; unsigned long WSAAPI inet_addr(const char FAR * cp)
inet_addr	proc	WSAAPI public\
			uses __BX __DI es\
			cp:STRING
                local	_in:in_addr

    ifdef	__LANG_BAS__
    		invoke	h_bStr2zStr, cp, O str_buf, 128
    		mov	ax, ds
    		mov	es, ax
    		mov	bx, O str_buf
    else
        if  	(@Model eq MODEL_FLAT)
		mov	eax, ds
		mov	es, eax
		mov	ebx, cp
	else
		les	bx, cp
	endif
    endif

		;; sanity checks
		;; 1st) max size= 4+4+4+3= 15 bytes
                mov	__DI, __BX
                mov	__CX, 16
                xor	al, al
                repne	scasb
                jne	@@error

                ;; 2nd) min size= 2+2+2+1= 7 bytes
                neg	__CX
                add	__CX, 15
                cmp	__CX, 7
                jl	@@error

                ;; 3rd) 3 dots are needed
                mov	__DI, __BX
                mov	al, '.'
                mov	dx, 3
@@loop:	        repne	scasb
		test	__CX, __CX
		jz	@@error
		dec	dx
		jnz	@@loop

		;; 4th) convert and check
		call	h_a2c
		jc	@@error
                mov	_in.S_un.S_un_b.s_b1, al
		call	h_a2c
		jc	@@error
                mov	_in.S_un.S_un_b.s_b2, al
		call	h_a2c
		jc	@@error
                mov	_in.S_un.S_un_b.s_b3, al
		call	h_a2c
		jc	@@error
                mov	_in.S_un.S_un_b.s_b4, al

		RETLONG _in.S_un.S_addr

@@exit:		ret

@@error:	RETLONG	INADDR_NONE
		jmp	short @@exit
inet_addr	endp

;;:::
;;  in: al= char
;;	ds:__BX-> dst
;;
;; out: __BX updated
h_c2a		proc	near pascal uses __SI

                cmp	al, 10
                jb	@@last			;; c < 10?
                mov	__SI, 2
                cmp	al, 100
                sbb	__SI, 0			;; c < 100? --i

@@loop:		mov	dl, thtb[__SI-1]
		and	ax, 00FFh
		div	dl
		add	al, '0'			;; 2 ascii
		mov	[__BX], al		;; save
		inc	__BX			;; /
                mov	al, ah			;; char= remainder
		dec	__SI
		jnz	@@loop

@@last:		add	al, '0'			;; last digit
		mov	[__BX], al
		inc	__BX

		ret
h_c2a		endp

;;::::::::::::::
;; char FAR * WSAAPI inet_ntoa(struct in_addr in)
inet_ntoa	proc	WSAAPI public uses __BX,\
			_in:in_addr

	ifdef	__LANG_BAS__
		mov	bx, O str_buf
	else
		mov	__BX, O ntoa_buf
	endif

		mov	al, _in.S_un.S_un_b.s_b1
		call	h_c2a
		mov	B [__BX], '.'
		inc	__BX
		mov	al, _in.S_un.S_un_b.s_b2
		call	h_c2a
		mov	B [__BX], '.'
		inc	__BX
		mov	al, _in.S_un.S_un_b.s_b3
		call	h_c2a
		mov	B [__BX], '.'
		inc	__BX
		mov	al, _in.S_un.S_un_b.s_b4
		call	h_c2a
		mov	B [__BX], 0

    ifdef	__LANG_BAS__
    		push	di
    		mov	ax, bx
    		sub	ax, O str_buf
    		mov	bx, O bstr
    		mov	di, O str_buf
    		BSTRS	bx, di, ax
    		pop	di
    		mov	ax, O bstr
    else
        if     (@Model eq MODEL_FLAT)
                mov     eax, O ntoa_buf         ;; return farptr
        else
                mov     ax, O ntoa_buf          ;; /
                mov	dx, ds			;; /
        endif
    endif

		ret
inet_ntoa	endp

;;::::::::::::::
;; int WSAAPI ioctlsocket(SOCKET s, long cmd, u_long FAR * argp)
ioctlsocket	proc	WSAAPI public\
			s:SOCKET,\
			cmd:LONG,\
			argp:FARPTR u_long

		DS_BODY	int, ioctlsocket, SOCKET_ERROR, s, cmd, argp
ioctlsocket	endp

;;::::::::::::::
;; int WSAAPI listen(SOCKET s, int backlog)
listen		proc	WSAAPI public\
			s:SOCKET,\
			backlog:SINT

		DS_BODY	int, listen, SOCKET_ERROR, s, backlog
listen		endp

;;::::::::::::::
;; u_long WSAAPI ntohl(u_long netlong)
ntohl		proc	WSAAPI public\
			netlong:u_long

		mov	edx, netlong
		mov	eax, edx
		rol	edx, 8
		ror	eax, 8
		and	edx, 000FF00FFh
		and	eax, 0FF00FF00h
		or	eax, edx

		RETLONG	eax
		ret
ntohl		endp

;;::::::::::::::
;; u_short WSAAPI ntohs(u_short netshort)
ntohs		proc	WSAAPI public\
			netshort:u_short

		mov	ax, netshort
		xchg	al, ah

		ret
ntohs		endp

;;::::::::::::::
;; int WSAAPI setsockopt(SOCKET s, int level, int optname, const char FAR * optval, int optlen)
setsockopt	proc	WSAAPI public\
			s:SOCKET,\
			level:SINT,\
			optname:SINT,\
			optval:FARPTR CHAR,\
			optlen:SINT

		DS_BODY	int, setsockopt, SOCKET_ERROR, s, level, optname, optval, optlen
setsockopt	endp

;;::::::::::::::
;; int WSAAPI shutdown(SOCKET s, int how)
shutdown	proc	WSAAPI public\
			s:SOCKET,\
			how:SINT

		DS_BODY	int, shutdown, SOCKET_ERROR, s, how
shutdown	endp

;;::::::::::::::
;; SOCKET WSAAPI socket (int af, int type, int protocol)
socket		proc	WSAAPI public\
			af:SINT,\
			_type:SINT,\
			protocol:SINT

		DS_BODY	long, socket, INVALID_SOCKET, af, _type, protocol
socket		endp

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; blocking functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;::::::::::::::
;; SOCKET accept (SOCKET s, struct sockaddr FAR *addr, int FAR *addrlen)
accept          proc    WSAAPI public\
			s:SOCKET,\
			_addr:FARPTR sockaddr,\
			addrlen:FARPTR SINT

                DS_BODY	long, accept, INVALID_SOCKET, s, _addr, addrlen
accept          endp

;;::::::::::::::
;; int WSAAPI closesocket(SOCKET s)
closesocket	proc	WSAAPI public\
			s:SOCKET

		DS_BODY	int, closesocket, SOCKET_ERROR, s
closesocket	endp

;;::::::::::::::
;; int WSAAPI connect(SOCKET s, const struct sockaddr FAR * name,
;;                     SINT namelen)
connect		proc	WSAAPI public\
			s:SOCKET,\
			_name:FARPTR sockaddr,\
			namelen:SINT

		DS_BODY	int, connect, SOCKET_ERROR, s, _name, namelen
connect		endp

;;::::::::::::::
;; int WSAAPI recv(SOCKET s, char FAR * buf, int len, int flags)
recv		proc	WSAAPI public\
			s:SOCKET,\
			buf:FARPTR CHAR,\
			len:SINT,\
			flags:SINT

		DS_BODY	int, recv, SOCKET_ERROR, s, buf, len, flags
recv		endp

;;::::::::::::::
;; int WSAAPI recvfrom(SOCKET s, char FAR * buf, int len, int flags,
;;                      struct sockaddr FAR * from, int FAR * fromlen)
recvfrom	proc	WSAAPI public\
			s:SOCKET,\
			buf:FARPTR CHAR,\
			len:SINT,\
			flags:SINT,\
			from:FARPTR sockaddr,\
			fromlen:FARPTR SINT

		DS_BODY	int, recvfrom, SOCKET_ERROR, s, buf, len, flags, from, fromlen
recvfrom	endp

;;::::::::::::::
;; int WSAAPI select(int nfds, fd_set FAR * readfds,
;;                   fd_set FAR * writefds, fd_set FAR *exceptfds,
;;                   const struct timeval FAR * timeout)
select		proc	WSAAPI public\
			nfds:SINT,\
			readfds:FARPTR fd_set,\
			writefds:FARPTR fd_set,\
			exceptfds:FARPTR fd_set,\
			timeout:FARPTR timeval

		DS_BODY	int, select, SOCKET_ERROR, nfds, readfds, writefds, exceptfds, timeout
select		endp

;;::::::::::::::
;; int WSAAPI send(SOCKET s, const char FAR * buf, int len, int flags)
send		proc	WSAAPI public\
			s:SOCKET,\
			buf:FARPTR CHAR,\
			len:SINT,\
			flags:SINT

		DS_BODY	int, send, SOCKET_ERROR, s, buf, len, flags
send		endp

;;::::::::::::::
;; int WSAAPI sendto(SOCKET s, const char FAR * buf, int len, int flags,
;;		     const struct sockaddr FAR * to, int tolen)
sendto		proc	WSAAPI public\
			s:SOCKET,\
			buf:FARPTR CHAR,\
			len:SINT,\
			flags:SINT,\
			to:FARPTR sockaddr,\
			tolen:SINT

		DS_BODY	int, sendto, SOCKET_ERROR, s, buf, len, flags, to, tolen
sendto		endp

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; database (blocking) functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;:::
XbyY_ALLOC	macro
		local	@@_F

	if	(@Model ne MODEL_FLAT)
		mov	ax, S XbyY_buf
		mov	es, ax
	endif
		mov	__DI, XbyY_ptr
		add	XbyY_ptr, XbyY_LEN
		cmp	XbyY_ptr, O XbyY_buf + SOF XbyY_buf
		jb	@@_F
		mov	XbyY_ptr, O XbyY_buf
@@_F:		mov	esi, XbyY_LEN
endm

;;::::::::::::::
;; struct hostent FAR * WSAAPI gethostbyaddr(const char FAR * addr, int len, int type)
gethostbyaddr	proc	WSAAPI public\
			uses di esi es,\
			_addr:FARPTR CHAR,\
			len:SINT,\
			_type:SINT

		XbyY_ALLOC
		DS_BODY	farptr, gethostbyaddr, NULL, _addr, len, _type
gethostbyaddr	endp

;;::::::::::::::
;; struct hostent FAR * WSAAPI gethostbyname(const char FAR * name)
gethostbyname	proc	WSAAPI public\
			uses di esi es,\
			_name:STRING

	ifdef	__LANG_BAS__
		invoke	h_bStr2zStr, _name, O str_buf, 128
		XbyY_ALLOC
		DS_BODY	farptr, gethostbyname, NULL, zstr_ptr
	else
		XbyY_ALLOC
		DS_BODY	farptr, gethostbyname, NULL, _name
	endif
gethostbyname	endp

ifndef		__LANG_BAS__
;;::::::::::::::
;; int WSAAPI gethostname(char FAR * name, int namelen)
gethostname	proc	WSAAPI public\
			_name:STRING,\
			namelen:SINT

		DS_BODY	int, gethostname, SOCKET_ERROR, _name, namelen
gethostname	endp

else
?gethostname	proc	near pascal\
			_name:FARPTR CHAR,\
			namelen:SINT

		DS_BODY	int, gethostname, SOCKET_ERROR, _name, namelen
?gethostname	endp

gethostname	proc	WSAAPI public\
			_name:STRING,\
			namelen:SINT

		invoke	?gethostname, zstr_ptr, 128
		cmp	ax, SOCKET_ERROR
		je	@F

		invoke	h_zStr2bStr, O str_buf, _name, namelen
		xor	ax, ax

@@:		ret
gethostname	endp
endif

;;::::::::::::::
;; struct servent FAR * WSAAPI getservbyport(int port, const char FAR * proto)
getservbyport	proc	WSAAPI public\
			uses di esi es,\
			port:SINT,\
			_proto:STRING

	ifdef	__LANG_BAS__
		invoke	h_bStr2zStr, _proto, O str_buf, 128
		XbyY_ALLOC
		DS_BODY	farptr, getservbyport, NULL, port, zstr_ptr
	else
		XbyY_ALLOC
		DS_BODY	farptr, getservbyport, NULL, port, _proto
	endif
getservbyport	endp

;;::::::::::::::
;; struct servent FAR * WSAAPI getservbyname(const char FAR * name,
;;					     const char FAR * proto)
getservbyname	proc	WSAAPI public\
			uses di esi es,\
			_name:STRING,\
			_proto:STRING

	ifdef	__LANG_BAS__
		invoke	h_bStr2zStr, _name, O str_buf, 128
		invoke	h_bStr2zStr, _proto, O str_buf+128, 32
		XbyY_ALLOC
		DS_BODY	farptr, getservbyname, NULL, zstr_ptr, zstr_ptr+4
	else
		XbyY_ALLOC
		DS_BODY	farptr, getservbyname, NULL, _name, _proto
	endif
getservbyname	endp

;;::::::::::::::
;; struct procent FAR * WSAAPI getprotobynumber(int number)
getprotobynumber proc	WSAAPI public\
			uses di esi es,\
			number:SINT

		XbyY_ALLOC
		DS_BODY	farptr, getprotobynumber, NULL, number
getprotobynumber endp

;;::::::::::::::
;; struct procent FAR * WSAAPI getprotobyname(const char FAR * name)
getprotobyname	proc	WSAAPI public\
			uses di esi es,\
			_name:STRING

	ifdef	__LANG_BAS__
		invoke	h_bStr2zStr, _name, O str_buf, 128
		XbyY_ALLOC
		DS_BODY	farptr, getprotobyname, NULL, zstr_ptr
	else
		XbyY_ALLOC
		DS_BODY	farptr, getprotobyname, NULL, _name
	endif
getprotobyname	endp


;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; extension functions
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;::::::::::::::
;; int WSAAPI WSAStartup (WORD wVersionRequested, LPWSADATA lpWSAData)
WSAStartup      proc    WSAAPI public\
			uses ebx,\
                        wVersionRequested:word,\
                        lpWSAData:LPWSADATA

                cmp     initialized, TRUE
                je      @F			;; already initialized?

                call    select_drv		;; select proper driver

                ;; try starting the driver
                call    dsdrv._init
                test    ax, ax
                jnz     @@error			;; error?

                mov     initialized, TRUE

                ;; add _end to exit queue
                _end    proto   far pascal
                ONEXIT	_end			;; <- rtlib dependent !!!!!

@@:         	movzx	eax, wVersionRequested
                mov	ebx, lpWSAData
                call    dsdrv.WSAStartup

@@exit:         ret

@@error:	;mov	eax, WSASYSNOTREADY	;; return error
                jmp     short @@exit
WSAStartup      endp

;;::::::::::::::
;; int WSAAPI WSACleanup (void)
WSACleanup	proc    WSAAPI public

                DS_BODY	int, WSACleanup, SOCKET_ERROR
WSACleanup	endp

;;::::::::::::::
;; void WSAAPI WSASetLastError(int iError)
WSASetLastError	proc	WSAAPI public\
			iError:SINT

		mov	ax, W iError
		mov	ws_lastError, ax
		ret
WSASetLastError	endp

;;::::::::::::::
;; int WSAAPI WSAGetLastError(void)
WSAGetLastError	proc	WSAAPI public

		movsx	eax, ws_lastError
		ret
WSAGetLastError	endp

;;::::::::::::::
;; int WSAAPI WSAAsyncSelect(SOCKET s, HWND hWnd, u_int wMsg, long lEvent)
WSAAsyncSelect	proc 	WSAAPI public\
			s:SOCKET,\
			hWnd:HWND,\
			wMsg:u_int,\
			lEvent:LONG

		DS_BODY	int, WSAAsyncSelect, SOCKET_ERROR, s, hWnd, wMsg, lEvent
WSAAsyncSelect	endp

;;::::::::::::::
;; void select_drv(void)
select_drv      proc    near pascal uses bx __DI __SI es ds

                ;; check if inside a Windows 9x/Me DOS box
                mov     ax, 1600h
                int     2Fh
                mov     __SI, O drv_9X		;; assume win9x
                test    al, al
                jnz     @@copy

                ;; check if running on a Windows NT DOS box
                mov     ax, 3000h               ;; version
                int     21h
                cmp     al, 5h
                jl      @@dos                   ;; major ver < 5?

                mov     ax, 3306h               ;; true version
                int     21h
                mov     __SI, O drv_NT		;; assume NT
                cmp     bx, 3205h
                je      @@copy                  ;; ver= 5.50?

@@dos:          mov     __SI, O drv_DOS

@@copy:	if	(@Model ne MODEL_FLAT)
		mov     ax, S dsdrv
                mov     ds, ax                  ;; ds= dsdrv's seg
                mov     es, ax                  ;; es= /
	endif
                mov     __DI, O dsdrv
                mov     __CX, T DSDRV
                rep     movsb

                ret
select_drv      endp

;;:::
_end		proc	far pascal
		pusha

                cmp     initialized, TRUE
                jne     @@exit			;; not initialized?

	ifdef	__LANG_PAS__
		mov	eax, last_exitproc
		mov	exitproc, eax
	endif

                call	dsdrv._end

		mov	initialized, FALSE

@@exit:		popa
		ret
_end		endp


ifdef		__LANG_PAS__

		TP_GetMem  proto far pascal :word
		TP_FreeMem proto far pascal :far ptr dword, :word

;;::::::::::::::
pas_malloc	proc 	far pascal public\
			uses ebx cx es,\
			bytes:dword

		mov     ebx, bytes
                add     ebx, 15 + 2           	;; +align +header
                shr     ebx, 4                  ;; convert to paragraph

                ;; check if DOS has enough free memory
                push    bx                      ;; save size
                mov	ah, 48h
                int	21h
                pop     bx                      ;; restore size
                jc 	@F       		;; nope?

                mov	dx, ax
                xor	ax, ax
                xor	cx, cx			;; size= 0 (to tell pas_free)
                jmp	short @@done

@@:		;; as DOS alloc did fail, try GetMem
                mov     dx, bx                  ;; convert paras to bytes
                shl     bx, 4                   ;; /
                shr     dx, 16-4                ;; /
                jnz	@@error			;; can't be >64K
                invoke  TP_GetMem, bx
                test	dx, dx
                jz	@@error

                mov	cx, bx			;; ax= size

@@done:         mov	es, dx			;; es:bx-> header
		mov	bx, ax			;; /
		mov	W es:[bx], cx		;; save size (needed by free)

		add	ax, 2			;; skip header

@@exit:         ret

@@error:        xor     ax, ax
                xor     dx, dx                  ;; return 0, error (CF=1)
                stc
                jmp     short @@exit
pas_malloc	endp

;;::::::::::::::
pas_free	proc 	far pascal public\
			uses bx cx es,\
			farptr:dword

		les	bx, farptr
		sub	bx, 2			;; back to header

		mov	ax, es:[bx]
		test	ax, ax
		jnz	@F

		mov	ah, 49h
		int	21h
		jmp	short @@exit

@@:		invoke	TP_FreeMem, es::bx, ax

@@exit:		ret
pas_free	endp

endif 		;; __LANG_PAS__


ifdef		__LANG_BAS__

;;::::::::::::::
WSAGETSELECTEVENT proc	far pascal public\
			lParam:dword
		mov	ax, W lParam+0
                ret
WSAGETSELECTEVENT endp

;;::::::::::::::
WSAGETSELECTERROR proc	far pascal public\
			lParam:dword
		mov	ax, W lParam+2
                ret
WSAGETSELECTERROR endp

;;::::::::::::::
MAKEWORD	proc	far pascal public\
			a:word, b:word
		mov	ax, b
		mov	dx, a
		shl	ax, 8
		and	dx, 00FFh
		or	ax, dx
		ret
MAKEWORD	endp

;;::::::::::::::
MAKELONG	proc	far pascal public\
			a:word, b:word
		mov	ax, a
		mov	dx, b
		ret
MAKELONG	endp

;;::::::::::::::
hent_name	proc	far pascal public\
			uses di si es,\
			entry:far ptr hostent

		mov	di, O str_buf

		les	si, entry
		xor	ax, ax
		cmp	es:[si].hostent.h_name, NULL
		je	@@done
		mov	eax, es:[si].hostent.h_name

		invoke	h_strncpy, ds::di, eax, 128

@@done:		mov	si, O bstr
    		BSTRS	si, di, ax
    		mov	ax, O bstr

		ret
hent_name	endp

;;::::::::::::::
hent_alias	proc	far pascal public\
			uses di si es,\
			entry:far ptr hostent

		mov	di, O str_buf

		les	si, entry
		xor	ax, ax
		cmp	es:[si].hostent.h_aliases, NULL
		je	@@done
		les	si, es:[si].hostent.h_aliases
		cmp	D es:[si], NULL
		je	@@done
		mov	eax, es:[si]

		invoke	h_strncpy, ds::di, eax, 128

@@done:		mov	si, O bstr
    		BSTRS	si, di, ax
    		mov	ax, O bstr

		ret
hent_alias	endp

;;::::::::::::::
hent_type	proc	far pascal public\
			uses bx es,\
			entry:far ptr hostent

		les	bx, entry
		mov	ax, es:[bx].hostent.h_addrtype
		ret
hent_type	endp

;;::::::::::::::
hent_len	proc	far pascal public\
			uses bx es,\
			entry:far ptr hostent

		les	bx, entry
		mov	ax, es:[bx].hostent.h_length
		ret
hent_len	endp

;;::::::::::::::
hent_addr	proc	far pascal public\
			uses si es,\
			entry:far ptr hostent

		xor	ax, ax
		xor	dx, dx

		les	si, entry
		cmp	es:[si].hostent.h_addr_list, NULL
		je	@@done
		les	si, es:[si].hostent.h_addr_list
		cmp	D es:[si], NULL
		je	@@done
		les	si, D es:[si]
		mov	ax, W es:[si+0]
		mov	dx, W es:[si+2]

@@done:		ret
hent_addr	endp

;;::::::::::::::
sent_port	proc	far pascal public\
			uses bx es,\
			entry:far ptr servent

		les	bx, entry
		mov	ax, es:[bx].servent.s_port
		ret
sent_port	endp

;;::::::::::::::
sent_proto	proc	far pascal public\
			uses di si es,\
			entry:far ptr servent

		mov	di, O str_buf

		les	si, entry
		xor	ax, ax
		cmp	es:[si].servent.s_proto, NULL
		je	@@done
		mov	eax, es:[si].servent.s_proto

		invoke	h_strncpy, ds::di, eax, 128

@@done:		mov	si, O bstr
    		BSTRS	si, di, ax
    		mov	ax, O bstr

		ret
sent_proto	endp

;;::::::::::::::
pent_proto	proc	far pascal public\
			uses bx es,\
			entry:far ptr protoent

		les	bx, entry
		mov	ax, es:[bx].protoent.p_proto
		ret
pent_proto	endp


		B$SETM          proto :dword

		_DMALLOC_	equ 1

ifdef	_DMALLOC_
;;::::::::::::::
DM_SET		macro	?seg:req, ?len:req
		PS	?seg, es

		mov	es, ?seg
		mov	W es:[00], ?len
		mov	W es:[02], '12'
		mov	D es:[04], '3456'
		mov	D es:[08], '7890'
		mov	D es:[12], 'ABCD'

		add	?seg, ?len
		dec	?seg
		mov	es, ?seg
		mov	D es:[00], '1234'
		mov	D es:[04], '5678'
		mov	D es:[08], '90AB'
		mov	D es:[12], 'CDEF'

		PP	es, ?seg
endm

;;::::::::::::::
DM_CHK		macro	?seg:req, ?errlbl:req
		local	@@error, @@exit

		PS	?seg, es

		mov	es, ?seg
		cmp	W es:[02], '12'
		jne	@@error
		cmp	D es:[04], '3456'
                jne	@@error
		cmp	D es:[08], '7890'
		jne	@@error
		cmp	D es:[12], 'ABCD'
		jne	@@error

		add	?seg, W es:[00]
		dec	?seg
		mov	es, ?seg
		cmp	D es:[00], '1234'
		jne	@@error
		cmp	D es:[04], '5678'
		jne	@@error
		cmp	D es:[08], '90AB'
		jne	@@error
		cmp	D es:[12], 'CDEF'
		je	@@exit

@@error:	PP	es, ?seg
		jmp	?errlbl

@@exit:		PP	es, ?seg
endm
endif	;; _DMALLOC_

;;::::::::::::::
qb_malloc	proc 	far pascal public\
			uses ebx,\
			bytes:dword

		mov     ebx, bytes
                add     ebx, 15           	;; +align
                shr     ebx, 4                  ;; convert to paragraph

	ifdef	_DMALLOC_
		add	ebx, 1 + 1
	endif

                ;; 1st) check if DOS has enough free memory
                push    bx                      ;; save size
                mov	ah, 48h
                int	21h
                pop     bx                      ;; restore size
                jnc     @@done       		;; no error?

                ;; 2nd) if DOS alloc did fail, check how many
                ;; bytes of free mem QB has
                invoke  B$SETM, D 0
                ;; dx:ax= largest free block size
                sub     ax, 16                  ;; -1 for the MCB
                sbb     dx, 0                   ;; /
                shr     ax, 4                   ;; convert bytes to paras
                shl     dx, 16-4                ;; /
                or      ax, dx                  ;; /

                ;; is the size enough?
                cmp     ax, bx
                jb      @@error           	;; not?

                ;; take that mem from QB
                mov     ax, bx
                inc     ax                      ;; +1 for MCB
                mov     dx, ax                  ;; convert paras to bytes
                shl     ax, 4                   ;; /
                shr     dx, 16-4                ;; /
                neg     ax                      ;; negate dx:ax
                adc     dx, 0                   ;; /
                neg     dx                      ;; /
                invoke  B$SETM, dx::ax

                ;; 3rd) reserve this block using DOS
                mov     ah, 48h
                int	21h
                jc      @@error2          	;; error???

@@done:
	ifdef	_DMALLOC_
		DM_SET	ax, bx
		inc	ax
	endif

		mov     dx, ax
                xor     ax, ax                  ;; return dx:ax, ok (CF=0)

@@exit:         ret

@@error2:	;; give back to QB the mem allocated (and not used)
                invoke  B$SETM, 7FFFFFFFh
                stc

@@error:        mov     ax, 0
                mov     dx, ax                  ;; return 0, error (CF=1)
                jmp     short @@exit
qb_malloc	endp

;;::::::::::::::
qb_free		proc 	far pascal public\
			uses es,\
			farptr:dword

                mov     ax, W farptr+2
                test    ax, ax
                jz      @@exit                  ;; seg= NULL?

	ifdef	_DMALLOC_
		dec	ax
		DM_CHK	ax, @@error
	endif
                mov     es, ax                  ;; get seg

                mov     ah, 49h
                int     21h
                jc      @@exit                  ;; error?

		;; give mem block to BASIC (only works if block
                ;; is adjacent to BASIC's far heap)
                invoke  B$SETM, 7FFFFFFFh

		clc                             ;; return ok

@@exit:         ret

ifdef	_DMALLOC_
@@error:	push	ds
		mov	ax, cs
		mov	ds, ax
		mov	dx, O dm_err
		mov	ah, 9h
        ;int 21h
		pop	ds
		stc
        ;int 3
		jmp	@@exit
dm_err		db	'[ERROR] Memory corrupted', 13, 10, '$'
endif
qb_free		endp

;;:::
h_bStr2zStr 	proc    near pascal\
			uses es ds,\
			_bstr:near ptr BASSTR, _zstr:near ptr, _zsize:word

                pusha

                mov	ax, ds
                mov	es, ax
                mov     di, _zstr		;; es:di -> zStr

                dec	_zsize			;; - null term

                ;; ds:si -> bStr.data; cx= bStr.len
                mov	bx, _bstr
                BSTRG   bx, ds, si, cx
                cmp	cx, _zsize
                jle	@F
                mov	cx, _zsize

@@: 		mov     ax, cx
                shr     cx, 2                   ;; / 4
                and     ax, 3                   ;; % 4
                rep     movsd
                mov     cx, ax
                rep     movsb
                mov     es:[di], cl             ;; null terminator

                popa
                ret
h_bStr2zStr	endp

;;:::
h_zStr2bStr 	proc    near pascal\
			uses cx di es,\
			_zstr:near ptr, _bstr:near ptr BASSTR, _bsize:word

		mov	ax, ds
		mov	es, ax
		mov	di, _zstr
		xor	al, al
		mov	cx, 0FFFFh
		repne	scasb
		neg	cx
		add	cx, 0FFFFh - 1
		cmp	cx, _bsize
		jle	@F
		mov	cx, _bsize

@@:		mov	ax, _zstr
		mov	dx, _bstr
		invoke	B$ASSN, ds::ax, cx, ds::dx, 0

		ret
h_zStr2bStr	endp

;;:::
;; out: ax= bytes copied (-1 f/ null-term)
h_strncpy	proc	near pascal\
			uses cx di si es ds,\
			dst:far ptr, src:far ptr, dstlen:word

		lds	si, src
		les	di, dst
		mov	cx, dstlen

		xor	ax, ax			;; assume 0 bytes
		test	cx, cx
		jz	@@exit			;; size= 0?
		cmp	W src+2, 0
		je	@@exit			;; NULL?
		cmp	W dst+2, 0
		jz	@@exit			;; NULL?

@@loop:		mov	al, ds:[si]		;; char= *src++
		inc	si			;; /
		mov	es:[di], al		;; *dst++= char
		inc	di			;; /
		dec	cx			;; --size
		jz	@@full			;; full?
		test	al, al
		jnz	@@loop			;; any char?

@@done:		mov	ax, dstlen
		sub	ax, cx			;; return bytes copied
		dec	ax			;; -1 null term

@@exit:		ret

@@full:		mov	B es:[di-1], 0		;; null char
		jmp	short @@done
h_strncpy	endp

endif   	;; __LANG_BAS__
DS_ENDS
                end
