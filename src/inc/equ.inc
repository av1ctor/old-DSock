;;
;; equ.inc -- some shortcuts
;;

ifndef          __equ_inc__
                __equ_inc__     equ 1

                MODEL_FLAT		equ 	7
                TYPE_CONST		equ	0

ifdef		_VMM_
		@Model			equ	MODEL_FLAT
endif

                S                       equ 	seg
                O                       equ 	offset
                A			equ	addr
if		(@Model eq MODEL_FLAT)
                F                       equ 	ptr
                N                       equ 	ptr
else
                F                       equ 	far ptr
                N                       equ 	near ptr
endif
                Q                       equ 	qword ptr
                R                       equ 	real4 ptr
                D                       equ 	dword ptr
                W                       equ 	word ptr
                B                       equ 	byte ptr
                T                       equ 	type
                L			equ	length
                SOF			equ	sizeof

if		(@Model eq MODEL_FLAT)
                NEARPTR         	textequ <ptr>
                FARPTR          	textequ <ptr>
else
                NEARPTR         	textequ <near ptr>
                FARPTR          	textequ <far ptr>
endif
		tNEARPTR		typedef	NEARPTR
		tFARPTR			typedef	FARPTR


if		(@Model eq MODEL_FLAT)
		_USE			textequ <use32>
else
		_USE			textequ <use16>
endif


ifndef		FALSE
                FALSE           equ     0
endif
ifndef		TRUE
                TRUE            equ     1
endif
ifndef		NULL
                NULL            equ     0
endif


        if	(@Model eq MODEL_FLAT)
        	__AX		equ 	eax
        	__BX		equ 	ebx
        	__CX		equ	ecx
        	__DX		equ 	edx
        	__SI		equ 	esi
        	__DI		equ	edi
        	__BP		equ	ebp
        	__SP		equ	esp
        	__ES		equ	ds
        	__FS		equ	ds
        else
        	__AX		equ 	ax
        	__BX		equ	bx
        	__CX		equ	cx
        	__DX		equ 	dx
        	__SI		equ	si
        	__DI		equ	di
        	__BP		equ	bp
        	__SP		equ	sp
        	__ES		equ	es
        	__FS		equ	fs
        endif


;;::::::::::::::
;; push multiple
PS              macro   ?args:vararg
                local 	a
        for     a, <?args>
                push    a
        endm
endm

;;::::::::::::::
;; pop multiple
PP              macro   ?args:vararg
                local 	a
        for     a, <?args>
                pop     a
        endm
endm

;;::::::::::::::
movdifi		macro	?dst:req, ?src:req
	ifdifi 	<?dst>, <?src>
		mov     ?dst, ?src
	endif
endm

;;::::::::::::::
if (@Model eq MODEL_FLAT)
CLEAR           macro   ?bytes:req, ?offs:req
		local	?rem

		PS	eax, ecx, edi
                movdifi edi, ?offs

    if (T ?bytes gt 4) or (T ?bytes eq 0)
    		xor     eax, eax
    		mov	ecx, ?bytes / 4
    		rep	stosd
    		?rem	= ?bytes and 3
        if (?rem ne 0)
        	mov	ecx, ?rem
        	rep	stosb
        endif
    else
                push	edx
                movdifi edx, ?bytes
                xor     eax, eax
                mov	ecx, edx
                and	edx, 3
                shr	ecx, 2
                rep     stosd
                mov	ecx, edx
                rep	stosb
                pop	edx
    endif
                PP	edi, ecx, eax

endm
else
CLEAR           macro   ?bytes:req, ?segm:req, ?offs:req
	ifdifi 	<?segm>, <es>
                push	es			;; (0)
                push 	?segm
                pop     es
	endif
                PS	eax, cx, di
	ifdifi <?segm>, <ss>
	    if (T ?offs eq 2)
 		movdifi di, <?offs>
	    else
                movdifi di, <O ?offs>
            endif
        else
        	lea	di, ?offs
        endif

    if (T ?bytes gt 4) or (T ?bytes eq 0)
    		xor     eax, eax
    		mov	cx, ?bytes / 4
    		rep	stosd
    		?rem	= ?bytes and 3
        if (?rem ne 0)
        	mov	cx, ?rem
        	rep	stosb
        endif
    else
                push	dx
                movdifi dx, ?bytes
                xor     eax, eax
                mov	cx, dx
                and	dx, 3
                shr	cx, 2
		rep     stosd
		mov	cx, dx
                rep     stosb
                pop	dx
    endif

                PP	di, cx, eax
	ifdifi 	<?segm>, <es>
		pop	es			;; (0)
	endif
endm
endif

;;::::::::::::::
RETLONG		macro	?value:req
if (@Model eq MODEL_FLAT)
		movdifi	eax, ?value
else
    if (T ?value eq TYPE_CONST)
		mov	ax, ?value and 0FFFFh
		mov	dx, ?value shr 16
    else
		movdifi	eax, ?value
		mov	edx, eax
		shr	edx, 16
    endif
endif
endm

;;::::::::::::::
STOADDR		macro	?dst:req, ?seg:req, ?ofs:req
		mov	W ?dst+0, ?ofs
		mov	W ?dst+2, ?seg
endm


		;; HL-like macros :::::::::::::::::::::::::::::::::::::::::::

		NULL_ID		equ	0
		ENUM_ID		equ	1

		?m_id = NULL_ID
		?m_cnt = 0
;;::::::::::::::
@enum		macro	?enumtag
	ifnb	<?enumtag>
		?enumtag	textequ	<word>
	endif
		?m_cnt = 0
		?m_id = ENUM_ID
endm

;;::::::::::::::
@const		macro	?name:req, ?value
    if (?m_id eq ENUM_ID)
	ifnb <?value>
		?m_cnt = ?value
	endif
		?name		equ	?m_cnt
		?m_cnt = ?m_cnt + 1
    else
    		.err	<@const without @enum>
    endif
endm

;;::::::::::::::
@end		macro
    	if (?m_id eq ENUM_ID)
		?m_id = NULL_ID
    	else
    		.err	<@end without @enum>
    	endif
endm


;;::::::::::::::
@procptr	macro	?proc:req, ?params
		??&?proc	typedef proto ?params
                ?&?proc		typedef ptr ??&?proc
                ?proc		?&?proc ?
endm


;;::::::::::::::
@pstrz		macro	?name, ?string:req
	ifnb	<?name>
?name		label	byte
	endif
		word	@SizeStr(<?string>) - 2 + 1
		byte	?string
                byte	0
endm

endif   	;; __equ_inc__
