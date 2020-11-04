;;
;; intern.inc -- DSock static lib internal definitions
;;

ifndef          __INTERN_INC__
                __INTERN_INC__ equ 1

DSDRV           struct
                _init	         	tNEARPTR ?
                _end        		tNEARPTR ?
                ;; non-blocking
                bind			tNEARPTR ?
                getpeername		tNEARPTR ?
                getsockname		tNEARPTR ?
                getsockopt		tNEARPTR ?
                ioctlsocket		tNEARPTR ?
 		listen			tNEARPTR ?
                setsockopt		tNEARPTR ?
                shutdown		tNEARPTR ?
                socket			tNEARPTR ?
                ;; blocking
                accept			tNEARPTR ?
                closesocket		tNEARPTR ?
                connect			tNEARPTR ?
                recv			tNEARPTR ?
                recvfrom		tNEARPTR ?
                select			tNEARPTR ?
                send			tNEARPTR ?
                sendto			tNEARPTR ?
                ;; database (blocking)
		gethostbyaddr		tNEARPTR ?
		gethostbyname		tNEARPTR ?
		gethostname		tNEARPTR ?
		getservbyport		tNEARPTR ?
		getservbyname		tNEARPTR ?
		getprotobynumber 	tNEARPTR ?
		getprotobyname		tNEARPTR ?
		;; extensions
		WSAStartup		tNEARPTR ?
		WSACleanup		tNEARPTR ?
		WSAAsyncSelect		tNEARPTR ?
DSDRV           ends

ASYNCSEL	struct
		id			dword	?
		socket			dword	?
		wMsg			dword	?
		fpProc			dword	?
ASYNCSEL	ends


;;::::::::::::::
DS_CODE         macro
ifndef	__LANG_PAS__
ds_text         segment para public _USE 'code'
                assume  cs:ds_text, ds:DGROUP, ss:DGROUP, es:nothing
else
.code
endif
endm
;;::::::::::::::
DS_FIXSEG	macro
ifndef          __LANG_BAS__
.data
else
DS_CODE
endif
endm

;;::::::::::::::
DS_ENDS         macro
@CurSeg       	ends
endm

;;::::::::::::::
;; out: __SI-> buf
CIRBUF_ALLOC	macro	?cb:req
		local	@@loop, @@_F

		;; pushf/cli/popf could be used here, but as cli is
		;; virtualized (=slow) and popf isn't too safe to use
		;; in pmode (doesn't restore the IF correctly) and sti
		;; can't be used as we don't know how the proc was
		;; entered, that "method" below is used to be sure an
		;; entry in the circular buffer won't be used by two
		;; at same time (as send() and recv() will be called
		;; by the callbacks)

		push	__AX

@@loop:         mov     __SI, &?cb&_ptr         ;; buf= ptr
		add	&?cb&_ptr, T ?cb	;; ++ptr
		mov	__AX, &?cb&_ptr         ;; p= ptr
		sub	__AX, T ?cb		;; --p

		cmp	&?cb&_ptr, O &?cb&_buf + SOF &?cb&_buf
		jb	@@_F			;; ptr not at end?
		mov	&?cb&_ptr, O &?cb&_buf	;; wrap

@@_F:		;; if p != buf, the list was updated while we were
		;; working on it, so the entry can't be used as it
		;; belongs to whose updated it, then... try again
		cmp	__AX, __SI
		jne	@@loop

		pop	__AX
endm


	ifndef	__LANG_PAS__
                externdef       drv_DOS:DSDRV
                externdef       drv_9X:DSDRV
                externdef       drv_NT:DSDRV
	endif

		STK_SIZE		equ	256
		MAX_STKS		equ	3
	ifndef	__LANG_PAS__
                externdef	ds$stks_buf:byte
	endif

endif           ;; __INTERN_INC__
