ifndef		__VDD_INC__
		__VDD_INC__	equ 1

		vdd_DllMain	proto	:dword, :PVOID

		vdd_init	proto

		vdd_end		proto

		vdd_dispatch	proto

;;::::::::::::::
;; out: eax= flat ptr
FP2FLAT		macro	?farptr:req, ?size:req
		local	@@null

	ifidni  <?size>, <eax>
		.err	FP2FLAT: can't pass EAX as ?size!
	endif

		movdifi	eax, ?farptr		;; eax= farptr
		test	eax, eax
		jz	@@null
		push	ecx
		invoke	ntvdm.GetVDMPointer, eax, ?size, isPMode
		pop	ecx
@@null:
endm

comment `
FP2FLAT		macro	?ptr:req
		local	@@is16, @@2flat

		movdifi	edx, ?ptr		;; edx= farptr or offset32

		cmp	is32bit, 1
		jne	@@is16
		invoke	ntvdm.getDS		;; eax= ds
		and	eax, 0FFFFh
		jmp	short @@2flat

@@is16:		;; eax:edx= far ptr
	ifdifi	<?ptr>, <eax>
		mov	eax, edx
	endif
		and	edx, 0FFFFh
		shr	eax, 16

@@2flat:	invoke	ntvdm.VdmMapFlat, eax, edx, isPMode
endm
`

;;::::::::::::::
MAPIN		macro	?ptr:req, ?proc:req
		local	??idx

    if	&?proc&_MAPIN ne 0
		??idx	= 0

	repeat	&?proc&_MAPIN
		FP2FLAT <D [?ptr + ??idx]>, 65520
                mov	D [?ptr + ??idx], eax
                ??idx	= ??idx + 4
	endm
    endif
endm

endif		;; __VDD_INC__
