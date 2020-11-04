;;
;; llist.asm -- linked-list module
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

                include llist.inc

		LL_ID		equ	'LL'	;; signature

DS_CODE
;;:::
;; out: CF set if error
;;	__ES:__DI-> node
;;	interrupts enabled! (if not __WIN32__)
ListAlloc	proc	near pascal __PUBLIC__\
			uses __BX __SI,\
			llist:NEARPTR LLST

                mov	__BX, llist		;; __BX-> list desc

		cmp	[__BX].LLST._ptr, NULL
		je	@@error
	if	(@Model ne MODEL_FLAT)
		mov	es, W [bx].LLST._ptr+2	;; es= llist's seg
	endif

	ifndef	__WIN32__
		cli				;; enter mutex 		*****
	else
		PS	eax, ecx, edx
		invoke	WaitForSingleObject, [ebx].LLST.hMutex, INFINITE
		PP	edx, ecx, eax
	endif

		mov	__DI, [__BX].LLST.fhead	;; es:di-> fnode
                test	__DI, __DI
                jz	@@error			;; no free node left?

		;; del from free nodes list
		;; fhead->next->prev= NULL; fhead= fhead->next
		mov	__SI, __ES:[__DI].NODE.next
		mov	[__BX].LLST.fhead, __SI
		test	__SI, __SI
		jz	@F
		mov	__ES:[__SI].NODE.prev, NULL

@@:		;; add to allocated nodes list
		;; node->prev= atail; node->next= NULL
		;; atail->next= node; atail= node
		mov	__SI, [__BX].LLST.atail
		mov	[__BX].LLST.atail, __DI
		mov	__ES:[__DI].NODE.prev, __SI
		mov	__ES:[__DI].NODE.next, NULL
		test	__SI, __SI
		jz	@F
		mov	__ES:[__SI].NODE.next, __DI

@@:		add	__DI, T NODE		;; skip header
		clc				;; return ok

@@exit:
	ifndef	__WIN32__
		sti				;; leave mutex 		*****
	else
		sbb	__SI, __SI		;; preserve CF
		PS	eax, ecx, edx
		invoke	ReleaseMutex, [ebx].LLST.hMutex
		PP	edx, ecx, eax
		add	__SI, __SI		;; restore CF
	endif
		ret

@@error:        stc                             ;; return error
		jmp	short @@exit
ListAlloc	endp

;;:::
;; out: interrupts enabled! (if not __WIN32__)
ListFree	proc	near pascal __PUBLIC__\
			uses __AX __BX __DI __SI es,\
			llist:NEARPTR LLST,\
			node:NEARPTR

		cmp	node, NULL
		je	@@exit			;; NULL?

		mov	__BX, llist		;; __BX-> list desc

		cmp	[__BX].LLST._ptr, NULL
		je	@@exit
	if	(@Model ne MODEL_FLAT)
		mov	es, W [bx].LLST._ptr+2	;; es= llist's seg
	endif

		mov	__DI, node		;; es:di-> node
		sub	__DI, T NODE		;; header

	ifndef	__WIN32__
		cli				;; enter mutex 		*****
	else
		PS	eax, ecx, edx
		invoke	WaitForSingleObject, [ebx].LLST.hMutex, INFINITE
		PP	edx, ecx, eax
	endif

		;; del from allocated nodes list
		;; node->prev->next= node->next
		mov	__SI, __ES:[__DI].NODE.prev
		mov	__AX, __ES:[__DI].NODE.next
		test	__SI, __SI
		jz	@F
		mov	__ES:[__SI].NODE.next, __AX

@@:		;; node->next->prev= node->prev
		test	__AX, __AX
		jz	@F
		xchg	__AX, __SI
		mov	__ES:[__SI].NODE.prev, __AX
		jmp	short @@add

@@:		mov	[__BX].LLST.atail, __SI	;; atail= node->prev

@@add:		;; add to free nodes list, as head
		;; fhead->prev= node; node->next= fhead
		mov	__SI, [__BX].LLST.fhead
		mov	__ES:[__DI].NODE.next, __SI
		test	__SI, __SI
		jz	@F
		mov	__ES:[__SI].NODE.prev, __DI

@@:		;; node->prev= NULL; fhead= node
		mov	__ES:[__DI].NODE.prev, NULL
		mov	[__BX].LLST.fhead, __DI

@@exit:
	ifndef	__WIN32__
		sti				;; leave mutex 		*****
	else
		PS	eax, ecx, edx
		invoke	ReleaseMutex, [ebx].LLST.hMutex
		PP	edx, ecx, eax
	endif
		ret
ListFree	endp

;;:::
;; out: ZF set if no nodes
;;	__ES:__DI-> last node
ListLast	proc	near pascal __PUBLIC__\
			llist:NEARPTR LLST

		mov	__DI, llist		;; __DI-> list desc

	if	(@Model ne MODEL_FLAT)
		mov	es, W [di].LLST._ptr+2	;; es= llist's seg
	endif

		mov	__DI, [__DI].LLST.atail
		test	__DI, __DI
		jz	@F
		add	__DI, T NODE		;; skip header, ZF clear

@@:		ret
ListLast	endp

;;:::
;;  in: __ES:__DI-> current node
;;
;; out: ZF set if no preview
;;	__ES:__DI-> prev node
ListPrev	proc	near pascal __PUBLIC__

		test	__DI, __DI
		jz	@F
		mov	__DI, __ES:[__DI - T NODE].NODE.prev
		test	__DI, __DI
		jz	@F
		add	__DI, T NODE		;; skip header, ZF clear

@@:		ret
ListPrev	endp

;;:::
;; out: CF clear if ok
;;	list desc filled
ListCreate	proc	near pascal __PUBLIC__\
			uses es,\
			llist:NEARPTR LLST,\
			nodes:word,\
			nodesize:word

		pushad

		cmp	nodes, 1
		jbe	@@error			;; < 2 nodes?

                mov	__BX, llist		;; __BX-> list desc

		movzx	eax, nodesize
		add	eax, T NODE

		;; first free node can't be at offset 0 (NULL)
		mov	[__BX].LLST.fhead, __AX

		movzx	edx, nodes
		inc	edx			;; +1 coz offs can't be NULL
		mul	edx			;; node size * nodes+1
		MALLOC	eax
	if	(@Model ne MODEL_FLAT)
		mov	W [bx].LLST._ptr+0, ax	;; save ptr to list
		mov	W [bx].LLST._ptr+2, dx	;; /
		mov	es, dx
		or	dx, ax
	else
		mov	[ebx].LLST._ptr, eax	;; save ptr
		test	eax, eax
	endif
		jz	@@error			;; NULL?

		add	[__BX].LLST.fhead, __AX	;; fhead-> llist+1 blk
		mov	[__BX].LLST.atail, NULL

        	;; setup free nodes
        	movzx	edx, nodesize
        	add	edx, T NODE

		add	__AX, __DX		;; skip 1st node
		mov	__DI, __AX
		xor	__SI, __SI

		movzx	ecx, nodes
		dec	__CX
@@loop:		add	__AX, __DX		;; next
		mov	__ES:[__DI].NODE.prev, __SI
		mov	__ES:[__DI].NODE.next, __AX
		mov	__SI, __DI
		add	__DI, __DX
		dec	__CX
		jnz	@@loop
		;; last
		mov	__ES:[__DI].NODE.prev, __SI
		mov	__ES:[__DI].NODE.next, NULL

	ifdef	__WIN32__
		invoke	CreateMutex, NULL, FALSE, NULL
		mov	[ebx].LLST.hMutex, eax
		test	eax, eax
		jz	@@error
	endif

                clc				;; return ok

@@exit:		popad
		ret

@@error:	stc				;; return error
		jmp	short @@exit
ListCreate	endp

;;:::
ListDestroy	proc	near pascal __PUBLIC__\
			llist:NEARPTR LLST

		pushad

                mov	__BX, llist		;; __BX-> list desc

		cmp	[__BX].LLST._ptr, NULL
		je	@@exit			;; NULL?

		FREE	[__BX].LLST._ptr
		mov	[__BX].LLST._ptr, NULL
		mov	[__BX].LLST.fhead, NULL
		mov	[__BX].LLST.atail, NULL

	ifdef	__WIN32__
		invoke	CloseHandle, [ebx].LLST.hMutex
		mov	[ebx].LLST.hMutex, NULL
	endif

@@exit:		popad
		ret
ListDestroy	endp
DS_ENDS
		__END__
