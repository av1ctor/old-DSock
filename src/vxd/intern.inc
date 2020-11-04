;;
;; intern.inc -- internal DSock VxD include file
;;

ifndef          __INTERN_INC__
                __INTERN_INC__  equ 1


VM_CTX		struct
		id			dword	?
		mutex			dword	?
		handle			dword	?
		vm_id			dword	?
		counter			dword	?
		baseSel			dword	?
		aselcbList		dword	?
VM_CTX		ends

CBREF           struct 4
		hSemaphore		dword	?
CBREF		ends

WS16CALL        struct 4
					CBREF	<>
		ptrProc			dword	?
		sizeParams		dword	?
		ptrParams		dword	?
		result			dword	?
WS16CALL	ends


ASYNCSELCB      struct 4
		id			dword	?
		vmHandle		dword	?
		cbuf			dword	?
		pWrkFlag		dword	?
		wMsg			dword	?
		fpProc			dword	?
		socket			dword	?
		hSocket			dword	?
ASYNCSELCB	ends


		;; ###ent structs returned by winsock.dll
w16_hostent	struct 1
        	h_name			dword	?
        	h_aliases		dword 	?
        	h_addrtype		word	?
        	h_length        	word	?
		h_addr_list		dword 	?
w16_hostent	ends

w16_servent 	struct 1
		s_name			dword	?
		s_aliases		dword 	?
        	s_port			word	?
        	s_proto			dword	?
w16_servent	ends

w16_protoent 	struct 1
		p_name			dword	?
		p_aliases		dword	?
		p_proto			word	?
w16_protoent	ends

		;; ###ent structs returned to client
hostent		struct 4
        	h_name			dword	?
        	h_aliases		dword 	?
        	h_addrtype		word	?
        	h_length        	word	?
		h_addr_list		dword 	?
hostent		ends

servent 	struct 4
		s_name			dword	?
		s_aliases		dword 	?
        	s_port			word	?
        	s_proto			dword	?
servent		ends

protoent 	struct 4
		p_name			dword	?
		p_aliases		dword	?
		p_proto			word	?
protoent	ends


		;; macros ::::::::::::::
;;::::::::::::::
;; out: eax= ptr
SEL2FLAT	macro	?farptr:req, hVM:=<hSysVM>
		local	@@_F
		PS	ebx, ecx, edx

		movdifi	eax, <?farptr>
		mov	ebx, eax
		shr	eax, 16 		;; eax= sel
		and	ebx, 0FFFFh		;; ebx= ofs
		VMMCall	_SelectorMapFlat, <hVM, eax, 0>
		cmp	eax, -1
		je	@@_F
		add	eax, ebx		;; ++ ofs

@@_F:		PP	edx, ecx, ebx
endm

;;::::::::::::::
;;  in: ebp-> Client_Reg_Struc (if hVM is not passed)
;;
;; out: eax= ptr
;;
;; xxx: edx (if hVM is passed)
;;
;; obs: 32-bit clients not supported
FP2FLAT		macro	?fp:req, hVM
		local	@@_F, @@_end

		movdifi	eax, ?fp
		test	eax, eax
		jz	@@_end
	ifb	<hVM>
		mov	[ebp].Client_EAX, eax
		mov	eax, ((Client_Reg_Struc.Client_EAX+2) * 256) or Client_Reg_Struc.Client_EAX
		VMMCall	Map_Flat

	else
        	movdifi	edx, hVM
        	assume	edx:nothing
        	test	[edx].cb_s.CB_VM_Status, VMSTAT_PM_EXEC
        	jz	@@_F
        	SEL2FLAT eax, edx
		jmp	short @@_end

@@_F:		push	[edx].cb_s.CB_High_Linear
		mov	edx, eax
		and	eax, 0FFFFh
		shr	edx, 16-4
		and	edx, not 15
		add	eax, edx
		pop	edx
		add	eax, edx
	endif
@@_end:
endm

;;::::::::::::::
;;  in: ebx-> WS16CALL struct
;;
;; out: eax= result
;;	CF set if error
WS16_CALL	macro	?cmd:req, ?pParams:req, ?sParams:req
		local	@@_F
		cmp	winsock_hInst, 31+1
		jb	@@_F

		mov	eax, winsock_ptb[(?cmd-DSVXD_WS16START) * T dword]
                assume  ebx: ptr WS16CALL
                mov     [ebx].ptrProc, eax
                mov     [ebx].ptrParams, ?pParams
                mov     [ebx].sizeParams, ?sParams

		mov	eax, OFFSET32 cb_ws16_call
		call	h_appytime_wait
                mov     eax, [ebx].result
@@_F:
endm

;;::::::::::::::
;;  in: ebp-> Client_Reg_Struc
;;
;; out: ZF set if error
;;	?base changed
W16_SETDESC	macro	?sel:req, ?base:req
		FP2FLAT	<?base>		;; eax= flat(base)
		;; set sys vm descriptor (lin=64k, p=1, dpl=3, non-sys, type=RWUP, gran=1)
		VMMCall	_BuildDescriptorDWORDs, <eax, 00FFFFh, 11110011b, 0, 0>
                VMMCall _SetDescriptor, <?sel, hSysVM, edx, eax, 0>
		;; ?base= ?sel::0
		mov	edx, ?sel
		shl	edx, 16
		mov	?base, edx
		;; set ZF
		test	eax, eax
endm

endif		;; __INTERN_INC__
