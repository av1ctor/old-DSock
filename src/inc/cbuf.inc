;;
;; cbuf.inc -- circular-buffer module protos/structs
;;

ifndef          __cbuf_inc__
                __cbuf_inc__ 	equ 1


CBUF		struct
		base		tFARPTR	?
		top		tFARPTR	?
		head		tFARPTR	?
		tail		tFARPTR	?
	ifdef	__WIN32__
		hMutex		dword	?
	endif
CBUF		ends


;;::::::::::::::
;; out: eax= head (=NULL if head=tail)
CBUFGET		macro	?cbuf:req, ?entsize:req, ?mutex
		local	@@exit, @@null

    ifnb	<?mutex>
    	ifndef	__WIN32__
    		cli				;; enter mutex 		*****
    	else
		PS	eax, ecx
		invoke	WaitForSingleObject, &?cbuf&.hMutex, INFINITE
		PP	ecx, eax
    	endif
    endif
		mov	eax, &?cbuf&.CBUF.head
		cmp	eax, &?cbuf&.CBUF.tail
		je	@@null
		add	&?cbuf&.CBUF.head, ?entsize
		mov	edx, &?cbuf&.CBUF.top
		cmp	&?cbuf&.CBUF.head, edx
		jb	@@exit
		mov	edx, &?cbuf&.CBUF.base
		mov	&?cbuf&.CBUF.head, edx
                jmp	short @@exit

@@null:		xor	eax, eax

@@exit:
    ifnb	<?mutex>
	ifndef	__WIN32__
		sti				;; leave mutex 		*****
	else
		PS	eax, ecx
		invoke	ReleaseMutex, &?cbuf&.hMutex
		PP	ecx, eax
	endif
    endif
endm

;;::::::::::::::
;; out: eax= tail (=NULL if tail+1 = head)
CBUFSET		macro	?cbuf:req, ?entsize:req, ?mutex
		local	@@exit, @@null, @@_F

    ifnb	<?mutex>
    	ifndef	__WIN32__
    		cli				;; enter mutex 		*****
    	else
		PS	eax, ecx
		invoke	WaitForSingleObject, &?cbuf&.hMutex, INFINITE
		PP	ecx, eax
    	endif
    endif
		mov	edx, &?cbuf&.CBUF.tail
		mov	eax, edx
		add	edx, ?entsize
		cmp	edx, &?cbuf&.CBUF.top
		jb	@@_F
		mov	edx, &?cbuf&.CBUF.base

@@_F:		cmp	edx, &?cbuf&.CBUF.head
		je	@@null
		mov	&?cbuf&.CBUF.tail, edx
		jmp	short @@exit

@@null:		xor	eax, eax

@@exit:
    ifnb	<?mutex>
	ifndef	__WIN32__
		sti				;; leave mutex 		*****
	else
		PS	eax, ecx
		invoke	ReleaseMutex, &?cbuf&.hMutex
		PP	ecx, eax
	endif
    endif
endm

		CBufCreate	proto near pascal :NEARPTR CBUF, :word, :word

		CBufDestroy	proto near pascal :NEARPTR CBUF


endif		;; __cbuf_inc__
