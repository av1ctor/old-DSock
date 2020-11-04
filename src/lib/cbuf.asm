;;
;; cbuf.asm -- circular-buffer module
;;

                include lang.inc

	ifndef	__WIN32__
                include equ.inc
                include intern.inc

	else
		DS_CODE		textequ	<.code>
		DS_ENDS		textequ <>

		include	windows.inc
		include equ.inc

		include kernel32.inc
		includelib kernel32.lib
	endif

                include cbuf.inc


DS_CODE
;;:::
;; out: CF clear if ok
;;	cbuf desc filled
CBufCreate	proc	near pascal __PUBLIC__\
			uses es,\
			cbuf:NEARPTR CBUF,\
			entries:word,\
			entrysize:word

		pushad

		cmp	entries, 0
		je	@@error			;; no entries?

                mov	__BX, cbuf		;; __BX-> cbuf desc

		movzx	eax, entrysize
		movzx	edx, entries
		mul	edx			;; entry size * entries
		push	eax			;; (0)
		MALLOC	eax
	if	(@Model ne MODEL_FLAT)
		mov	W [bx].CBUF.base+0, ax	;; save ptr to cbuf
		mov	W [bx].CBUF.base+2, dx	;; /
		mov	W [bx].CBUF.head+0, ax
		mov	W [bx].CBUF.head+2, dx
		mov	W [bx].CBUF.tail+0, ax
		mov	W [bx].CBUF.tail+2, dx
		movzx	ecx, dx			;; ecx= dx:ax
		shl	ecx, 16			;; /
		mov	cx, ax			;; /
		or	ax, dx
	else
		mov	[ebx].CBUF.base, eax	;; save ptr
		mov	[ebx].CBUF.head, eax
		mov	[ebx].CBUF.tail, eax
		mov	ecx, eax
		test	eax, eax
	endif
		pop	edi			;; (0)
		jz	@@error			;; NULL?

		add	ecx, edi		;; top= base+entries*entsize
		mov	[__BX].CBUF.top, ecx

	ifdef	__WIN32__
		invoke	CreateMutex, NULL, FALSE, NULL
		mov	[ebx].CBUF.hMutex, eax
		test	eax, eax
		jz	@@error
	endif

		clc				;; return ok

@@exit:		popad
		ret

@@error:	stc				;; return error
		jmp	short @@exit
CBufCreate	endp

;;:::
CBufDestroy	proc	near pascal __PUBLIC__\
			cbuf:NEARPTR CBUF

		pushad

                mov	__BX, cbuf		;; __BX-> cbuf desc

		cmp	[__BX].CBUF.base, NULL
		je	@@exit			;; NULL?

		mov	[__BX].CBUF.head, NULL
		mov	[__BX].CBUF.tail, NULL

		FREE	[__BX].CBUF.base
		mov	[__BX].CBUF.base, NULL
		mov	[__BX].CBUF.top, NULL

	ifdef	__WIN32__
		invoke	CloseHandle, [ebx].CBUF.hMutex
		mov	[ebx].CBUF.hMutex, NULL
	endif

@@exit:		popad
		ret
CBufDestroy	endp
DS_ENDS
		__END__

