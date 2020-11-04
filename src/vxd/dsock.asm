;;
;; DSOCK -- VxD that fixes WSOCK2 VxD bugs in SEND and RECV services,
;;	    that handles calls to winsock dll and that receives dioc
;;	    from the win32 slave and calls the callback in dos vm
;; copyleft (c) Mar/2002 by v1ctor [av1ctor@yahoo.com.br]
;;
;; needed to build: masm 6.15 + link 5.12 + Win98 DDK include files
;;

                .386p
                option	segment:flat
                option	offset:flat
                option	proc:private
                option	oldmacros

                .nolist
                include ddk9x\vmm.inc
                include ddk9x\vxdldr.inc
                include ddk9x\vwin32.inc
                include ddk9x\shell.inc
                .list
                include equ.inc
                include wsock2.inc
                include dsockvxd.inc
                include	cbuf.inc
                include	intern.inc


VxD_LOCKED_CODE_SEG
Declare_Virtual_Device  DSOCK,\
                       	DSVXD_VHIG, DSVXD_VLOW,\
                        DSOCK_Control,\
                       	UNDEFINED_DEVICE_ID,\
                       	UNDEFINED_INIT_ORDER,\
                       	api_handler,\
                       	NULL

Begin_control_dispatch  DSOCK
                Control_Dispatch Sys_Dynamic_Device_Init, dsock_init
                Control_Dispatch Sys_Dynamic_Device_Exit, dsock_exit
                Control_Dispatch W32_DEVICEIOCONTROL, dsock_dioc
                Control_Dispatch VM_Suspend2, dsock_vmsuspend
                Control_Dispatch VM_Resume, dsock_vmresume
                Control_Dispatch VM_Not_Executeable2, dsock_vmterminate
                Control_Dispatch VM_Terminate2, dsock_vmterminate
End_control_dispatch    DSOCK
VxD_LOCKED_CODE_ENDS


VxD_LOCKED_DATA_SEG
initialized     dword   FALSE
loaded          dword   FALSE

VMs         	dword   0

hList		dword	?
hSem     	dword   ?
hSysVM		dword	?

vmMutex		dword	?

vmctx_tb	dword	256 dup (?)		;; max 256 vms

		;; wsock2 vxd data
		WS2_ID			equ	3B0Ah
ws2_v86proc	dword	NULL
ws2_mapintb	dword	NULL
ws2_mapintb_pat	byte	1, 1, 0, 1, 1, 1, 1, 0, 0, 4, 3, 3, 0, 3

		;; winsock 16-bit dll data
winsock_sz	byte	'WINSOCK.DLL', 0
winsock_hInst	dword	0
winsock_ordtb	label	byte
                byte   	115			;; WSAStartup
                byte   	116			;; WSACleanup
                byte   	111			;; WSAGetLastError
                byte   	101			;; WSAAsyncSelect
                byte   	51			;; gethostbyaddr
                byte   	52			;; gethostbyname
                byte   	57			;; hostname
                byte   	56			;; servbyport
                byte   	55			;; servbyname
                byte   	54 			;; protobynumber
                byte   	53			;; protobyname
                WINSOCK_PROCS		equ	$-winsock_ordtb

winsock_ptb	dword	WINSOCK_PROCS dup (?)

                ;; win32 slave data
w32_hInst	dword	0
w32_hWnd	dword	0

		;; services jump tables
dioc_jmp_tb     label   dword
                dword	0			;; DIOC_Open/Ver msgs
                dword   OFFSET32 dioc_VER
                dword   OFFSET32 dioc_INIT
                dword   OFFSET32 dioc_END
                dword   OFFSET32 dioc_MSG
                DIOC_SERVICES   	equ     ($-dioc_jmp_tb) / 4

api_jmp_tb      label   dword
                dword	0
                dword   OFFSET32 api_VER
                dword   OFFSET32 api_INIT
                dword   OFFSET32 api_END
                dword   OFFSET32 api_dummy	;; dioc only
                dword   OFFSET32 api_STARTUP
                dword   OFFSET32 api_CLEANUP
                dword   OFFSET32 api_GETLASTERROR
                dword   OFFSET32 api_ASYNCSEL
                dword   OFFSET32 api_HOSTBYADDR
                dword   OFFSET32 api_HOSTBYNAME
                dword   OFFSET32 api_HOSTNAME
                dword   OFFSET32 api_SERVBYPORT
                dword   OFFSET32 api_SERVBYNAME
                dword   OFFSET32 api_PROTOBYNUMBER
                dword   OFFSET32 api_PROTOBYNAME
                dword   OFFSET32 api_RECV
                dword   OFFSET32 api_SEND
                API_SERVICES    	equ     ($-api_jmp_tb) / 4
VxD_LOCKED_DATA_ENDS

VxD_PAGEABLE_DATA_SEG
                ;; shell packet for loading the win32 slave (@ dsock.dll)
shpak           SHEXPACKET <T SHEXPACKET+SOF rundll_file+SOF rundll_parm+\
                            SOF rundll_dir, T SHEXPACKET, NULL,\
                            O rundll_file - O shpak, O rundll_parm - O shpak,\
                            O rundll_dir - O shpak, NULL, 0>
rundll_file     byte    "rundll32.exe", 0
rundll_parm     byte    "dsock.dll,w32_init", 0
rundll_dir      byte    64+3 dup (0)
VxD_PAGEABLE_DATA_ENDS


VxD_LOCKED_CODE_SEG
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; helper and callback procs
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;:::
;;  in: eax= callback
;;	ebx= dwRefData (with CBREF struct @ beginning)
;;
;; out: CF set if error
h_appytime_wait	proc	near32 uses ecx
		assume	ebx: ptr CBREF

		;; create a semaphore
		push	eax
		xor	ecx, ecx		;; count= 0
		VMMCall Create_Semaphore
		mov	[ebx].hSemaphore, eax
		pop	eax
		jc      @@error

		;; queue the callback
		VxDCall _SHELL_CallAtAppyTime, <eax, ebx, 0, 0>
		test	eax, eax
		jz  	@@error2

		;; wait for the semaphore being signaled by the callback
		mov     eax, [ebx].hSemaphore
		xor     ecx, ecx		;; flags= none
		VMMCall Wait_Semaphore

		;; delete the semaphore
		mov	eax, [ebx].hSemaphore
		VMMCall	Destroy_Semaphore

		clc				;; return ok (CF clean)

@@exit:		ret

@@error2:	;; delete the semaphore
		mov	eax, [ebx].hSemaphore
		VMMCall	Destroy_Semaphore

@@error:	stc				;; return error (CF set)
		jmp	short @@exit
h_appytime_wait	endp

;;:::
;;  in: edi-> dst
;;	ecx= dst size
;;	eax-> src
;;
;; out: ZF set if nothing copied
;;	edi & ecx updated
;;	eax= bytes copied
h_lstrcpyn	proc	near32 uses edx
                assume  edi:nothing

		push	ecx

		test	ecx, ecx
		jz	@@exit			;; size= 0?
		test	eax, eax
		jz	@@exit			;; NULL?
		test	edi, edi
		jz	@@exit			;; NULL?

@@loop:		mov	dl, [eax]		;; char= *src++
		inc	eax			;; /
		mov	[edi], dl		;; *dst++= char
		inc	edi			;; /
		dec	ecx			;; --size
		jz	@@full			;; full?
		test	dl, dl
		jnz	@@loop			;; any char?

@@exit:		pop	eax
		sub	eax, ecx		;; return bytes copied
		ret

@@full:		mov	B [edi-1], 0		;; null char
		jmp	short @@exit
h_lstrcpyn	endp

;;::::::::::::::
DEBUG_MSGBOX	macro	?msg:req
		local	??msg
	ifdef	DEBUG
		push	OFFSET32 ??msg
		call	h_dbgmsgbox
		jmp	short @F
??msg		byte	"&?msg", 0
@@:
	endif
endm

ifdef	DEBUG
;;:::
h_dbgmsgbox	proc	pascal msg:dword

		pushad
		mov 	edi, NULL
		mov 	ecx, msg
		VMMCall Get_Sys_VM_Handle
		mov 	eax, MB_SYSTEMMODAL
		VxDcall SHELL_SYSMODAL_Message
		popad

                ret
h_dbgmsgbox	endp
endif	;; DEBUG

;;:::
BeginProc	cb_ws16_load, CCALL
                ArgVar  dwRefData, DWORD
                ArgVar  dwFlags, DWORD
		EnterProc
		SaveReg	<ad>

		;; try loading winsock.dll
		VxDCall	_SHELL_LoadLibrary, <OFFSET32 winsock_sz>
		mov	winsock_hInst, eax
		cmp	eax, 31
		jbe	ws16_l_exit		;; handle not valid?

		;; get proc addresses by ordinal
		xor	esi, esi
		mov	ebx, WINSOCK_PROCS
@@:		movzx	eax, winsock_ordtb[esi]
		VxDCall _SHELL_GetProcAddress, <winsock_hInst, eax>
		test	eax, eax
		jz	ws16_l_err
		mov	winsock_ptb[esi*4], eax
		inc	esi
		dec	ebx
		jnz	@B

ws16_l_exit:	;; signalize the semaphore
		mov	ebx, dwRefData
                assume  ebx: ptr CBREF
                mov     eax, [ebx].hSemaphore
		VMMCall Signal_Semaphore_No_Switch

		RestoreReg <ad>
		LeaveProc
		Return

ws16_l_err:	;; unload winsock dll
		VxDcall _SHELL_FreeLibrary, <winsock_hInst>
		mov	winsock_hInst, 0
		jmp	short ws16_l_exit
EndProc		cb_ws16_load

;;:::
BeginProc	cb_ws16_unload, CCALL
                ArgVar  dwRefData, DWORD
                ArgVar  dwFlags, DWORD
		EnterProc
		SaveReg	<ebx>

		;; unload winsock dll
		VxDCall _SHELL_FreeLibrary, <winsock_hInst>
		mov	winsock_hInst, 0

		;; signalize the semaphore
		mov	ebx, dwRefData
                assume  ebx: ptr CBREF
                mov     eax, [ebx].hSemaphore
		VMMCall Signal_Semaphore_No_Switch

		RestoreReg <ebx>
		LeaveProc
		Return
EndProc		cb_ws16_unload

;;:::
;;  in: dwRefData-> WS16CALL struct
BeginProc	cb_ws16_call, CCALL
                ArgVar  dwRefData, DWORD
                ArgVar  dwFlags, DWORD
		EnterProc
		SaveReg	<ebx>

		mov	ebx, dwRefData
                assume  ebx: ptr WS16CALL

		;; call winsock routine
                VxDCall _SHELL_CallDll, <NULL, [ebx].ptrProc, [ebx].sizeParams, [ebx].ptrParams>
                mov     [ebx].result, eax

		;; signalize the semaphore
                mov     eax, [ebx].hSemaphore
		VMMCall Signal_Semaphore_No_Switch

		RestoreReg <ebx>
		LeaveProc
		Return
EndProc		cb_ws16_call

;;:::
;; out: CF clean if ok
h_ws16_load	proc	near32
		local	_cbref:CBREF

		pushad

		cmp	winsock_hInst, 0
		jne	@@check

		mov	eax, OFFSET32 cb_ws16_load
		lea	ebx, _cbref
		call	h_appytime_wait
		jc	@@exit
		cmp	winsock_hInst, 31
		jbe	@@error			;; handle not valid?

@@exit:		popad
		ret

@@check:	cmp	winsock_hInst, 31+1	;; CF= (hInst <= 31? 1: 0)
		jmp	short @@exit

@@error:	DEBUG_MSGBOX <Error loading winsock.dll>
		stc
		jmp	short @@exit
h_ws16_load	endp

;;:::
h_ws16_unload	proc	near32
		local	_cbref:CBREF

		pushad

		cmp	winsock_hInst, 31+1
		jb	@@exit			;; handle not valid?

		mov	eax, OFFSET32 cb_ws16_unload
		lea	ebx, _cbref
		call	h_appytime_wait

@@exit:		popad
		ret
h_ws16_unload	endp

;;:::
BeginProc	cb_w32_exec, CCALL
                ArgVar  dwRefData, DWORD
                ArgVar  dwFlags, DWORD
		EnterProc
		SaveReg	<ebx>

        ;; load the win32 slave (hidden in dsock.dll)
		VxDCall	_SHELL_ShellExecute, <OFFSET32 shpak>
		mov	w32_hInst, eax

		;; signalize the semaphore
		mov	ebx, dwRefData
                assume  ebx: ptr CBREF
                mov     eax, [ebx].hSemaphore
		VMMCall Signal_Semaphore_No_Switch

		RestoreReg <ebx>
		LeaveProc
		Return
EndProc		cb_w32_exec

;;:::
BeginProc	cb_w32_finish, CCALL
                ArgVar  dwRefData, DWORD
                ArgVar  dwFlags, DWORD
		EnterProc
		SaveReg	<ebx>

                ;; post exit msg
                WM_DESTROY equ 2h
                VxDCall _SHELL_PostMessage, <w32_hWnd, WM_DESTROY, 0, 0, NULL, 0>
		mov	w32_hInst, 0
		mov	w32_hWnd, 0

w32_u_exit:	;; signalize the semaphore
		mov	ebx, dwRefData
                assume  ebx: ptr CBREF
                mov     eax, [ebx].hSemaphore
		VMMCall Signal_Semaphore_No_Switch

		RestoreReg <ebx>
		LeaveProc
		Return
EndProc		cb_w32_finish

;;:::
;;  in: eax-> dsock.dll location zstr
;; out: CF clean if ok
h_w32_exec	proc	near32
		local	_cbref:CBREF

		pushad

		cmp	w32_hInst, 0
		jne	@@check

                ;; copy dir string
                mov     edi, OFFSET32 rundll_dir
                mov     ecx, SOF rundll_dir
                call    h_lstrcpyn

                mov	eax, OFFSET32 cb_w32_exec
		lea	ebx, _cbref
		call	h_appytime_wait
		jc	@@exit
		cmp	w32_hInst, 32
		jbe	@@error			;; handle not valid?

@@exit:		popad
		ret

@@check:	cmp	w32_hInst, 32+1		;; CF= (hInst <= 32? 1: 0)
		jmp	short @@exit

@@error:        DEBUG_MSGBOX <Error running dsock.dll>
		stc
		jmp	short @@exit
h_w32_exec	endp

;;:::
h_w32_finish	proc	near32
		local	_cbref:CBREF

		pushad

		cmp	w32_hInst, 32
		jbe	@@exit			;; handle not valid?
		cmp	w32_hWnd, 0
		je	@@exit			;; /

		mov	eax, OFFSET32 cb_w32_finish
		lea	ebx, _cbref
		call	h_appytime_wait

@@exit:		popad
		ret
h_w32_finish	endp

;;:::
;;  in: esi= list handle
h_aselList_free	proc	near32 uses eax

@@loop:		VMMCall	List_Get_First
		assume	eax: ptr ASYNCSELCB
		jz	@@exit

		mov	[eax].id, 0		;; just f/ precaution
		mov	[eax].socket, 0		;; /
		mov	[eax].hSocket, 0	;; /
		mov	[eax].vmHandle, 0	;; /

		push	eax
		VMMCall	List_Remove
		pop	eax
		VMMCall	List_Deallocate		;; free node
		jmp	short @@loop

@@exit:		ret
h_aselList_free	endp

;;:::
;;  in: esi= list handle
;;	eax= hSocket
;;
;; out: eax= node (0 if not found)
h_aselList_find	proc	near32 uses edx

		mov	edx, eax

		VMMCall	List_Get_First
		jz	@@exit
		assume	eax: ptr ASYNCSELCB

@@loop:		cmp	[eax].hSocket, edx
		je	@@exit			;; curr.hSocket= hSocket?
		VMMCall	List_Get_Next		;; eax= next
		jnz	@@loop			;; not last node?

@@exit:		ret
h_aselList_find	endp

;;:::
;;  in: esi= list handle
;;	ebx= vm handle
;;
;; out: eax= node (0 if not found)
h_vm_find	proc	near32

		VMMCall	List_Get_First
		jz	@@exit
		assume	eax: ptr VM_CTX

@@loop:		cmp	[eax].handle, ebx
		je	@@exit			;; curr.handle= handle?
		VMMCall	List_Get_Next		;; eax= next
		jnz	@@loop			;; not last node?

@@exit:		ret
h_vm_find	endp

;;:::
;;  in: ebx= vm handle
;;
;; out: CF set if error
;;	eax-> VM_CTX
h_vm_new	proc	near32 uses edi esi
		assume	edi:ptr VM_CTX, ebx:ptr cb_s
		assume	esi:nothing

		VMMCall	_EnterMutex, <vmMutex, 0>

		mov	esi, hList

		;; check if vm already on list
		call	h_vm_find
		mov	edi, eax
		test	eax, eax
		jnz	@@done

		;; alloc new node
		VMMCall List_Allocate
		jc	@@error
		mov	edi, eax

		;; attach node to head of list
		VMMCall	List_Attach

		;; fill node
		mov	[edi].id, 'VCTX'
		mov	[edi].handle, ebx
		mov	eax, [ebx].CB_VMID
		mov	[edi].vm_id, eax
		mov	[edi].counter, 0

		;; create a mutex
		VMMCall	_CreateMutex, <0, 0>
		mov	[edi].mutex, eax
		test	eax, eax
		jz	@@error2

		;; create aselcb list
		mov	eax, LF_Alloc_Error
		mov	ecx, T ASYNCSELCB
		VMMCall	List_Create
		jc	@@error3
		mov	[edi].aselcbList, esi

		;; allocate selectors on sys vm
		VMMCall	_BuildDescriptorDWORDs, <0, 00FFFFh, 11110011b, 0, 0>
                VMMCall _Allocate_LDT_Selector, <hSysVM, edx, eax,\
						 DSVXD_SELECTORS, 0>
		test	eax, eax
                jz      @@error4
		mov	[edi].baseSel, eax

		inc	VMs			;; ++vms

		;; update vmctx_tb: vmctx_tb[vm id]= vm_ctx
		mov	eax, [ebx].CB_VMID
		mov	vmctx_tb[eax * 4], edi

@@done:		inc     [edi].counter
		mov	eax, edi

@@exit:		push	eax
		VMMCall	_LeaveMutex, <vmMutex>
		pop	eax
		ret

@@error4:	mov	esi, [edi].aselcbList
		VMMCall	List_Destroy

@@error3:	VMMCall	_DestroyMutex, [edi].mutex

@@error2:	mov	eax, edi
		mov	esi, hList
		VMMCall List_Deallocate

@@error:	xor	eax, eax
		stc
		jmp	short @@exit
h_vm_new	endp

;;:::
;;  in: edi-> VM_CTX
;;	ebx= vm handle
h_vm_del	proc	near32 uses esi
		assume	edi:ptr VM_CTX

		VMMCall	_EnterMutex, <vmMutex, 0>

		cmp	[edi].id, 'VCTX'
		jne	@@exit			;; invalid struct?

		cmp	[edi].handle, ebx
		jne	@@exit			;; not same handle?

		sub	[edi].counter, 1
		jnz	@@exit			;; can't finish?

		;; update vmctx_tb: vmctx_tb[vm id]= 0
		mov	eax, [ebx].CB_VMID
		mov	vmctx_tb[eax * 4], 0

		;; free all selectors
		mov	eax, [edi].baseSel
		call	h_sels_free

		;; remove and dealloc any node in asel list
		mov	esi, [edi].aselcbList
		call	h_aselList_free
		;; destroy the list itself
		VMMCall	List_Destroy
		mov	[edi].aselcbList, 0

		;; destroy mutex
		VMMCall	_DestroyMutex, [edi].mutex
		mov	[edi].mutex, 0

		;; deattach node
		mov	esi, hList
		call	h_vm_find
		mov	[edi].id, 0		;; just f/ precaution
		mov	[edi].handle, 0		;; /
		VMMCall List_Remove
		;; free it
		mov	eax, edi
		VMMCall List_Deallocate

		dec	VMs			;; --vms

@@exit:		VMMCall	_LeaveMutex, <vmMutex>
		ret
h_vm_del	endp

;;:::
h_vm_del_all	proc	uses ebx edi esi

		mov	esi, hList

@@loop:		VMMCall	List_Get_First
		jz	@F
		mov	edi, eax
		assume	edi:ptr VM_CTX
		mov	ebx, [edi].handle
		call	h_vm_del
		jmp	short @@loop

@@:		ret
h_vm_del_all	endp

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; control procs
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

		CR0_WP		equ	00000000000000010000000000000000b
;;:::
;;  in: esi-> ObjectInfo
;;
;; out: CF clear if found and patched
;;	eax-> wsock2's mapintb
h_ws2_patch	proc	near32 uses ecx edi esi
	        assume	esi:ptr ObjectInfo, edi:nothing

	        cld

        	mov	edi, [esi].OI_LinearAddress
        	mov	ecx, [esi].OI_Size
        	mov	al, ws2_mapintb_pat[0]

@@loop:		repne	scasb
                jne	@@not_found

        	cmp	ecx, SOF ws2_mapintb_pat - 1
        	jb	@@not_found

        	PS	ecx, edi
        	mov	ecx, SOF ws2_mapintb_pat - 1
        	mov	esi, OFFSET32 ws2_mapintb_pat[1]
        	repe	cmpsb
        	PP	edi, ecx
        	jne	@@loop

        	;; apply the patch

		;; hack: clear WP flag in CR0
		mov	eax, cr0
		push	eax
		and	eax, not CR0_WP
		mov	cr0, eax

        	mov	B [edi-1][9], 3		;; f/ recv() (bug: =4)
        	mov	B [edi-1][13], 2	;; f/ send() (bug: =3)

		;; restore WP state
		pop	eax
		mov	cr0, eax

		clc				;; return found/patched
		lea	eax, [edi-1]		;; eax-> table

@@exit:		ret

@@not_found:	stc				;; return not found
		jmp	short @@exit
h_ws2_patch	endp

;;:::
h_ws2_fix	proc	near32

		;; get wsock2 v86_api proc
		mov	eax, WS2_ID
		xor	edi, edi
		VMMCall	Get_DDB
		test	ecx, ecx
		jz	@@error0
		assume	ecx:ptr VxD_Desc_Block
		mov	eax, [ecx].DDB_V86_API_Proc
		mov	ws2_v86proc, eax

		;; find wsock2's DeviceInfo
                VxDcall	VXDLDR_GetDeviceList
                assume	eax:ptr DeviceInfo
                jmp	short @@test

@@dloop:	cmp	[eax].DI_DeviceID, WS2_ID
		je	@F			;; wsock2 id?
		mov	eax, [eax].DI_Next	;; next
@@test:		test	eax, eax
		jnz	@@dloop			;; any left?
		jmp	short @@error1

@@:		;; go through wsock2 data segments and search for
		;; the buggy MAPIN table and patch it when found
		mov	ecx, [eax].DI_ObjCount
		jecxz	@@error2			;; no segs?!?
		mov	esi, [eax].DI_ObjInfo
		assume	esi: ptr ObjectInfo

@@oloop:;;;;;;;;test	[esi].OI_ObjType, 0001b
	;;;;;;;;jnz	@@next			;; not data type?
                call	h_ws2_patch
                jnc	@F			;; patched?
@@next:		add	esi, T ObjectInfo	;; next
		dec	ecx
		jnz	@@oloop			;; any left?
		jmp	short @@error3		;; !!!

@@:		mov	ws2_mapintb, eax	;; save ptr

		clc				;; return ok

@@exit:		ret

@@error:	stc				;; return error
		jmp	short @@exit


@@error0:	DEBUG_MSGBOX <ERROR: Get_DDB()>
		jmp	@@error

@@error1:	DEBUG_MSGBOX <ERROR: DI_DeviceID[]>
		jmp	@@error

@@error2:	DEBUG_MSGBOX <ERROR: DI_ObjCount>
		jmp	@@error

@@error3:	DEBUG_MSGBOX <ERROR: Pattern Not Found>
		jmp	@@error
h_ws2_fix	endp

;;:::
h_ws2_unfix	proc	near32 uses esi

		;; restore original wsock2 mapintb values
		mov	edx, ws2_mapintb
		assume	edx:nothing
		test	edx, edx
		jz	@F

		;; hack: clear WP flag in CR0
		mov	eax, cr0
		push	eax
		and	eax, not CR0_WP
		mov	cr0, eax

		mov	B [edx][9], 4		;; f/ recv()
		mov	B [edx][13], 3		;; f/ send()
		mov	ws2_mapintb, NULL

		;; restore WP state
		pop	eax
		mov	cr0, eax

@@:		ret
h_ws2_unfix	endp

;;::::::::::::::
BeginProc   	dsock_init

                cmp     initialized, TRUE
                je      ds_i_ok                 ;; already initialized?

		VMMCall	Get_Sys_VM_Handle	;; ebx= sysvm handle
		mov	hSysVM, ebx

                call	h_ws2_fix		;; patch wsock2
		jc	ds_i_err		;; error?

		;; create a semaphore used for sync
		xor	ecx, ecx		;; count= 0
		VMMCall Create_Semaphore
		mov	hSem, eax
		test	eax, eax
		jz	ds_i_err

		;; create mutex to access linked-lists
		VMMCall	_CreateMutex, <0, 0>
		mov	vmMutex, eax
		test	eax, eax
		jz	ds_i_err2

		;; create a linked-list for VM_CTX
		mov	eax, LF_Alloc_Error
		mov	ecx, T VM_CTX
		VMMCall	List_Create
		jc	ds_i_err3
		mov	hList, esi

		mov	VMs, 0
                mov     initialized, TRUE

ds_i_ok:	xor     eax, eax                ;; return ok (CF clean)

ds_i_exit:	ret

ds_i_err3:	VMMCall _DestroyMutex, vmMutex
		mov	vmMutex, 0

ds_i_err2:	mov	eax, hSem
		VMMCall Destroy_Semaphore	;; delete semaphore
		mov	hSem, 0

ds_i_err:	mov	eax, -1			;; return error (CF set)
		stc				;; /
		jmp	short ds_i_exit
EndProc     	dsock_init

;;::::::::::::::
BeginProc   	dsock_exit

                cmp     initialized, TRUE
                jne     ds_x_exit               ;; not initialized?

                ;; search vm list and Remove/Deallocate any
                ;; node + asyncList of each node!
                call	h_vm_del_all

                mov	esi, hList		;; delete list
                VMMCall	List_Destroy		;; /
                mov	hList, 0

		VMMCall _DestroyMutex, vmMutex
		mov	vmMutex, 0

                mov	eax, hSem
                VMMCall Destroy_Semaphore	;; delete sem
                mov	hSem, 0

                call	h_ws2_unfix

                mov	VMs, 0
                mov     initialized, FALSE

ds_x_exit:	xor     eax, eax                ;; return ok (CF clean)
		ret
EndProc     	dsock_exit

;;::::::::::::::
BeginProc   	dsock_vmsuspend

                xor     eax, eax                ;; return ok (CF clean)
		ret
EndProc     	dsock_vmsuspend

;;::::::::::::::
BeginProc   	dsock_vmresume

		xor     eax, eax                ;; return ok (CF clean)
		ret
EndProc     	dsock_vmresume

;;::::::::::::::
BeginProc   	dsock_vmterminate

		;; find vm_ctx for this vm, if any
		mov	esi, hList
	;;;;;;;;cCall	_EnterMutex, <vmMutex, 0>
		call	h_vm_find
	;;;;;;;;cCall	_LeaveMutex, <vmMutex>
		mov	edi, eax
		test	eax, eax
		jz	@F			;; no ctx?

		call	h_vm_del		;; delete it

		cmp	VMs, 0
		jg	@F			;; any vm?

		;; unload winsock.dll and win32 slave
                cmp	loaded, TRUE
                jne	@F
                call	h_w32_finish
                call	h_ws16_unload
                mov	loaded, FALSE

@@:             xor     eax, eax                ;; return ok (CF clean)
		ret
EndProc     	dsock_vmterminate

;;::::::::::::::
BeginProc       dsock_dioc
                assume	esi:ptr DIOCParams

                mov     eax, [esi].dwIoControlCode
                cmp     eax, DIOC_Open
                jle     ds_dioc_done

                cmp     eax, DIOC_SERVICES
                jae     ds_dioc_error
                call    dioc_jmp_tb[eax * 4]

ds_dioc_done:	xor     eax, eax                ;; return ok (CF clean)

ds_dioc_exit:	ret

ds_dioc_error:	DEBUG_MSGBOX <Invalid command for dioc>
		stc				;; return error (CF set)
		jmp     short ds_dioc_exit
EndProc         dsock_dioc

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; dioc procs
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;:::
;;  in: ebx= VMHandle
;;	edi= ThreadHandle
;;	edx= rm callback's far ptr
;; 	ebp-> Client_Reg_Struc
cb_asyncselcb	proc	near32
		assume	ebp:ptr Client_Reg_Struc

		Push_Client_State
		VMMCall	Begin_Nest_Exec

		;; call the rm callback
		mov   	ecx, edx		;; cx:dx-> rm cb
		and	edx, 0FFFFh
		shr	ecx, 16
		VMMCall Simulate_Far_Call
		VMMCall Resume_Exec

		VMMCall	End_Nest_Exec
		Pop_Client_State

		ret
cb_asyncselcb	endp

;;::::::::::::::
;; out: OutBuffer[0]= version (in fixed-point 8.8 notation)
;;	OutBuffer[1]= current hWnd
BeginProc       dioc_VER
                assume	esi:ptr DIOCParams

                mov     ebx, [esi].lpvOutBuffer
                mov     D [ebx+0], (DSVXD_VHIG shl 8) or DSVXD_VLOW
                xor	eax, eax
                cmp	VMs, 0
                je	@F			;; no VMs? exit indirectly
                mov	eax, w32_hWnd
@@:             mov     D [ebx+4], eax

                ret
EndProc         dioc_VER

;;::::::::::::::
;;  in: *lpvInBuffer= hWnd
BeginProc       dioc_INIT
		assume	esi:ptr DIOCParams, eax:nothing

                mov     eax, [esi].lpvInBuffer
                mov	eax, [eax]
                mov	w32_hWnd, eax
                test	eax, eax
                jnz	@F			;; valid handle?
                mov	w32_hInst, eax		;; don't wait for hWnd

@@:		;; signalize the semaphore (waking up api_ASYNCSEL
		;; if it stills waiting or incrementing the counter)
                mov     eax, hSem
		VMMCall Signal_Semaphore_No_Switch

		ret
EndProc         dioc_INIT

;;::::::::::::::
BeginProc       dioc_END
		assume	esi:ptr DIOCParams

                cmp     loaded, TRUE
                jne	@F
                call	h_ws16_unload		;; unload winsock dll

@@:		mov	w32_hWnd, 0
                mov	w32_hInst, 0
                mov	loaded, FALSE

		ret
EndProc         dioc_END

;;::::::::::::::
;;  in: *lpvInBuffer= DSVXD_MSG struct
BeginProc       dioc_MSG
		assume	esi:ptr DIOCParams, eax:nothing, ecx:nothing

                mov     ebx, [esi].lpvInBuffer
                assume	ebx: ptr DSVXD_MSG

                ;; thanks to Windows' wMsg being only 16-bit coz the
                ;; f*cking 16-bit backward compatibility shit, i can't
                ;; pass the address of the node in wMsg, so, all this
                ;; slow list searching has to be done, %$#!@%$!
                mov	eax, [ebx].wMsg
                mov eax, vmctx_tb[eax * 4 - (WM_DSOCK * 4)]
                test	eax, eax
                jz	d_msg_error1
                mov	esi, [eax].VM_CTX.aselcbList
                test	esi, esi
                jz	d_msg_error1
                mov	eax, [ebx].wParam	;; eax= socket
                call	h_aselList_find
                test	eax, eax
                jz	d_msg_error1
                mov	edi, eax
                assume	edi: ptr ASYNCSELCB

                ;; is it a valid ASYNCSELCB struct?
                cmp	[edi].id, 'CB32'
                jne	d_msg_error1		;; not?

		;; alloc from circular-buffer
		pushfd
		cli
                mov	ecx, [edi].cbuf
                CBUFSET	[ecx], <T DSVXD_MSG>
		popfd
                FP2FLAT	eax, [edi].vmHandle
                mov	edx, eax
                assume	edx: ptr DSVXD_MSG

                ;; copy to circular buffer
                mov	eax, [edi].wMsg
                mov	[edx].wMsg, eax
                ;; can't use wParam as wsock2 sends the socket
                ;; handle, not the ptr to the socket used to
                ;; communicate with the vxd
                mov	eax, [edi].socket
                mov	[edx].wParam, eax
                mov	eax, [ebx].lParam
                mov	[edx].lParam, eax

                ;; if rm callback is working currently or if simfarcall
                ;; callback was already scheduled, don't simulate a rm
                ;; farcall and/or don't schedule the callback again
		mov	eax, [edi].pWrkFlag
		cmp	B [eax], TRUE
		je	d_msg_exit
		mov	B [eax], TRUE

		;; schedule a callback in a vm that not the current (sys)
		xor	eax, eax		;; PriorityBoost= none
		mov     ebx, [edi].vmHandle
		VMMCall	Validate_VM_Handle
		jc	d_msg_error2		;; handle not valid?!?
		mov     ecx, PEF_Wait_For_STI or PEF_Wait_Not_Crit or\
			     PEF_Wait_Not_Time_Crit or PEF_Wait_Not_HW_Int
		mov	edx, [edi].fpProc
		mov     esi, OFFSET32 cb_asyncselcb
		xor     edi, edi		;; TimeOut= infinite
		VMMCall Call_Priority_VM_Event

d_msg_exit:	ret

d_msg_error1:	DEBUG_MSGBOX <dioc_MSG: Invalid struct>
		jmp	short d_msg_exit

d_msg_error2:	DEBUG_MSGBOX <dioc_MSG: Invalid VM handle>
		jmp	short d_msg_exit
EndProc         dioc_MSG

;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; v86-api procs
;;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

;;:::
;;  in: eax= base selector
h_sels_free	proc	near32
		pushad

		mov	esi, eax		;; esi= base sel
		mov	edi, DSVXD_SELECTORS	;; edi= sels

@@loop:		VMMCall _Free_LDT_Selector, <hSysVM, esi, 0>
		test	eax, eax
		jz	@@exit			;; error?
		add	esi, 8			;; next selector
		dec	edi
		jnz	@@loop			;; any left?

@@exit:		popad
		ret
h_sels_free	endp

;;:::
;;  in: ebp-> Client_Reg_Struc
;;	esi= Buffers
;;	ecx= BufferCount
h_buf2lin	proc	near32 uses eax ecx esi
		assume	ebp:ptr Client_Reg_Struc
		assume	esi:ptr WSABUF

@@loop:		mov	eax, [esi].buf
		test	eax, eax
		jz	@F
		mov	[ebp].Client_EAX, eax
		mov	eax, ((Client_Reg_Struc.Client_EAX+2) * 256) or Client_Reg_Struc.Client_EAX
		VMMCall	Map_Flat
@@:		mov	[esi].buf, eax
		add	esi, T WSABUF
		dec	ecx
		jnz	@@loop

		ret
h_buf2lin	endp

;;:::
;;  in: edi= dst list linaddr
;;	ecx= dst list size
;;	stack= 	src list sel,
;;	 	dst list fp,
;;		addr_flg (=TRUE if addr_list, =FALSE if alias)
;;
;; out: CF set if error
;;	edi & ecx updated
;;	eax= dstlist_fp (NULL if src list is empty)
;;	edx= bytes copied (0 /)
h_sel2fp_list	proc	near32 pascal uses ebx esi,\
			srclist_sel:dword, dstlist_fp:dword, addr_flg:dword
		local	bytes:dword
                assume  ebp:nothing, ebx:nothing, esi:nothing, edi:nothing

		mov	bytes, 0

		;; esi-> src list
		mov	eax, srclist_sel
		test	eax, eax
		jz	@@no_items		;; NULL ptr?
		SEL2FLAT eax
		cmp	eax, -1
		je	@@error
		mov	esi, eax

		;; get number of items on src list
		xor	edx, edx
                push	esi
                jmp	short @@test
@@:		add	esi, T dword		;; ++ptr
		add	edx, T dword
@@test:		cmp	D [esi], NULL
		jne	@B
		pop	esi

		test	edx, edx
		jz	@@no_items		;; list empty?

		sub	ecx, edx		;; dst size-= sizeof(src list)
		sub	ecx, T dword		;; -1 (null ptr at end)
		jbe	@@error			;; nothing left?

		mov	ebx, edi		;; ebx-> list
		mov	bytes, edx		;; bytes= sizeof(list)

		;; set start address for all items in dst list
		mov	eax, dstlist_fp
		lea	eax, [eax+edx+4]	;; dst fp+= sizeof(src list)
		push	edx
@@:		mov	[edi], eax
		add	edi, T dword
		sub	edx, T dword
		jnz	@B
		pop	edx

		add	edi, T dword		;; coz null ptr
		cmp	addr_flg, TRUE
		jne	@@alias

		;; copy addrs
@@aloop:	SEL2FLAT <D [esi]>		;; eax= flat(src list[i])
		cmp	eax, -1
		je	@@error
		add	esi, T dword		;; ++i
		cmp	ecx, 4
		jl	@@error			;; no room?
		mov	eax, D [eax]		;; = addr
		mov	[edi], eax		;; save
		add	edi, 4
		sub	ecx, 4
		add	bytes, 4		;; bytes+=sizeof(IP4 addr)
		add	D [ebx + T dword], 4	;; correct fp of next item
		add	ebx, T dword
		sub	edx, T dword
		jnz	@@aloop
		jmp	short @@done

@@alias:	;; copy strings
@@sloop:	SEL2FLAT <D [esi]>		;; eax= flat(src list[i])
		cmp	eax, -1
		je	@@error
		add	esi, T dword		;; ++i
		call	h_lstrcpyn
		jz	@@done			;; nothing copied?
		add	bytes, eax
		add	[ebx + T dword], eax	;; correct fp of next item
		add	ebx, T dword
		sub	edx, T dword
		jnz	@@sloop

@@done:		mov	D [ebx], NULL		;; mark end-of-array
		add	bytes, T dword		;; +null ptr
		mov	eax, dstlist_fp		;; return *dst list
		clc

@@exit:		mov	edx, bytes
		ret

@@no_items:	xor	eax, eax		;; return NULL
	;;;;;;;;clc
		jmp	short @@exit

@@error:	DEBUG_MSGBOX <sel2fp: error @ SEL2FLAT>
		xor	eax, eax		;; /
		stc
		jmp	short @@exit
h_sel2fp_list	endp

;;:::
;;  in: eax= sysvm hostent farptr
;;	Client_EDX= dosvm hostent farptr
;;	Client_ECX= /	  /       size (including buffer)
;;
;; out: CF set if error
h_hostent_conv	proc	near32 uses ebx ecx edi esi
                assume  ebp:ptr Client_Reg_Struc
                assume  ebx:nothing, esi:nothing, edi:nothing

		push	[ebp].Client_EAX	;; (0) save

		;; esi= sys vm hostent
		SEL2FLAT eax
		cmp	eax, -1
		je	@@error
		mov	esi, eax

		;; ebx-> dos vm hostent
		FP2FLAT [ebp].Client_EDX
		mov	ebx, eax

		;; edi-> buffer after hostent
		lea	edi, [ebx + T hostent]
		add	[ebp].Client_EDX, T hostent

		;; ecx= sizeof(buffer) - sizeof(hostent)
		mov	ecx, [ebp].Client_ECX
		sub	ecx, T hostent

		;; 1st: non-pointer field(s)
		mov	ax, [esi].w16_hostent.h_addrtype
		mov	[ebx].hostent.h_addrtype, ax
		mov	ax, [esi].w16_hostent.h_length
		mov	[ebx].hostent.h_length, ax

		;; 2nd: pointer field(s)
		mov	eax, [ebp].Client_EDX
		mov	[ebx].hostent.h_name, eax
		SEL2FLAT [esi].w16_hostent.h_name
		call	h_lstrcpyn
		add	[ebp].Client_EDX, eax	;; assuming no seg overrun!!!
		add	eax, -1			;; set to NULL if nothing
		sbb	eax, eax		;; copied, preserve ptr
		and	[ebx].hostent.h_name,eax;; otherwise

		;; 3rd: array(s) of pointers
		;; addr_list 1st as it's the important part
		invoke	h_sel2fp_list, [esi].w16_hostent.h_addr_list,\
			               [ebp].Client_EDX, TRUE
		jc	@@exit
		mov	[ebx].hostent.h_addr_list, eax
		add	[ebp].Client_EDX, edx	;; ///

		;; h_aliases
		invoke	h_sel2fp_list, [esi].w16_hostent.h_aliases,\
				       [ebp].Client_EDX, FALSE
	;;;;;;;;jc	@@exit
		mov	[ebx].hostent.h_aliases, eax

		clc

@@exit:		pop	[ebp].Client_EAX	;; (0) restore
		ret

@@error:	stc
		jmp	short @@exit
h_hostent_conv	endp

;;:::
;;  in: eax= sysvm servent farptr
;;	Client_EDX= dosvm servent farptr
;;	Client_ECX= /	  /       size (including buffer)
;;
;; out: CF set if error
h_servent_conv	proc	near32 uses ebx ecx edi esi
                assume  ebp:ptr Client_Reg_Struc
                assume  ebx:nothing, esi:nothing, edi:nothing

		push	[ebp].Client_EAX	;; (0) save

		;; esi= sys vm servent
		shr	eax, 16
		VMMCall	_SelectorMapFlat, <hSysVM, eax, 0>
		cmp	eax, -1
		je	@@error
		mov	esi, eax

		;; ebx-> dos vm servent
		FP2FLAT [ebp].Client_EDX
		mov	ebx, eax

		;; edi-> buffer after servent
		lea	edi, [ebx + T servent]
		add	[ebp].Client_EDX, T servent

		;; ecx= sizeof(buffer) - sizeof(servent)
		mov	ecx, [ebp].Client_ECX
		sub	ecx, T servent

		;; 1st: non-pointer field(s)
		mov	ax, [esi].w16_servent.s_port
		mov	[ebx].servent.s_port, ax

		;; 2nd: pointer field(s)
		;; s_name
		mov	eax, [ebp].Client_EDX
		mov	[ebx].servent.s_name, eax
		SEL2FLAT [esi].w16_servent.s_name
		call	h_lstrcpyn
		add	[ebp].Client_EDX, eax	;; assuming no seg overrun!!!
		add	eax, -1			;; set to NULL if nothing
		sbb	eax, eax		;; copied, preserve ptr
		and	[ebx].servent.s_name,eax;; otherwise
		;; s_proto
		mov	eax, [ebp].Client_EDX
		mov	[ebx].servent.s_proto, eax
		SEL2FLAT [esi].w16_servent.s_proto
		call	h_lstrcpyn
		add	[ebp].Client_EDX, eax	;; ///
		add	eax, -1			;; set to NULL...
		sbb	eax, eax		;; /
		and	[ebx].servent.s_proto, eax

		;; 3rd: array(s) of pointers
		;; s_aliases
		invoke	h_sel2fp_list, [esi].w16_servent.s_aliases,\
				       [ebp].Client_EDX, FALSE
	;;;;;;;;jc	@@exit
		mov	[ebx].servent.s_aliases, eax

		clc

@@exit:		pop	[ebp].Client_EAX	;; (0) restore
		ret

@@error:	stc
		jmp	short @@exit
h_servent_conv	endp

;;:::
;;  in: eax= sysvm protoent farptr
;;	Client_EDX= dosvm protoent farptr
;;	Client_ECX= /	  /       size (including buffer)
;;
;; out: CF set if error
h_protoent_conv	proc	near32 uses ebx ecx edi esi
                assume  ebp:ptr Client_Reg_Struc
                assume  ebx:nothing, esi:nothing, edi:nothing

		push	[ebp].Client_EAX	;; (0) save

		;; esi= sys vm protoent
		VMMCall	_SelectorMapFlat, <hSysVM, eax, 0>
		cmp	eax, -1
		je	@@error
		mov	esi, eax

		;; ebx-> dos vm protoent
		FP2FLAT [ebp].Client_EDX
		mov	ebx, eax

		;; edi-> buffer after protoent
		lea	edi, [ebx + T protoent]
		add	[ebp].Client_EDX, T protoent

		;; ecx= sizeof(buffer) - sizeof(protoent)
		mov	ecx, [ebp].Client_ECX
		sub	ecx, T protoent

		;; 1st: non-pointer field(s)
		mov	ax, [esi].w16_protoent.p_proto
		mov	[ebx].protoent.p_proto, ax

		;; 2nd: pointer field(s)
		;; p_name
		mov	eax, [ebp].Client_EDX
		mov	[ebx].protoent.p_name, eax
		SEL2FLAT [esi].w16_protoent.p_name
		call	h_lstrcpyn
		add	[ebp].Client_EDX, eax	;; assuming no seg overrun!!!
		add	eax, -1			;; set to NULL if nothing
		sbb	eax, eax		;; copied, preserve ptr
		and	[ebx].protoent.p_name,eax;; otherwise

		;; 3rd: array(s) of pointers
		;; s_aliases
		invoke	h_sel2fp_list, [esi].w16_protoent.p_aliases,\
				       [ebp].Client_EDX, FALSE
	;;;;;;;;jc	@@exit
		mov	[ebx].protoent.p_aliases, eax

		clc

@@exit:		pop	[ebp].Client_EAX	;; (0) restore
		ret

@@error:	stc
		jmp	short @@exit
h_protoent_conv	endp

;;::::::::::::::
;;  in: eax= service
;;
;; out: CF set if error
BeginProc       api_handler
                assume	ebp:ptr Client_Reg_Struc

                mov     eax, [ebp].Client_EAX
                cmp     eax, API_SERVICES
                jae     a_hdl_error

                and     [ebp].Client_EFlags, not CF_MASK ;; assume no errors
                call    api_jmp_tb[eax * 4]

a_hdl_exit:     ret

a_hdl_error:    DEBUG_MSGBOX <Invalid command for v86 api>
		or      [ebp].Client_EFlags, CF_MASK
                jmp     short a_hdl_exit
EndProc         api_handler

;;::::::::::::::
;;  out: eax= version (in fix 8.8 notation)
BeginProc       api_VER
                assume	ebp:ptr Client_Reg_Struc

                mov     [ebp].Client_EAX, (DSVXD_VHIG shl 8) or DSVXD_VLOW
                ret
EndProc         api_VER

;;::::::::::::::
BeginProc       api_dummy
                assume	ebp:ptr Client_Reg_Struc

		mov	[ebp].Client_EAX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK ;; error
                ret
EndProc         api_dummy

;;::::::::::::::
;;  in: es:ebx-> dsock.dll location zstr
;;
;; out: CF set if error
;;	eax= VM_CTX
BeginProc       api_INIT
                assume	ebp:ptr Client_Reg_Struc

                cmp     initialized, TRUE
		jne	a_init_error

		;; create a new vm_ctx if one does not exist yet
		call	h_vm_new
                jc	a_init_error
                mov	[ebp].Client_EAX, eax	;; save vm_ctx

                ;; load winsock.dll and win32 slave if 'em were not loaded
                cmp     loaded, TRUE
                je      a_init_exit

		;; load winsock 16-bit dll
		call	h_ws16_load
		jc	a_init_error2

        	;; load the win32 slave (hidden in dsock.dll)
                ;; eax= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
                VMMCall Map_Flat
                call	h_w32_exec
		jc	a_init_error3

                mov     loaded, TRUE

a_init_exit:	ret

a_init_error3:	call	h_ws16_unload		;; unload winsock dll

a_init_error2:	mov	edi, [ebp].Client_EAX
		call	h_vm_del

a_init_error:	or     	[ebp].Client_EFlags, CF_MASK
		mov	[ebp].Client_EAX, 0
		jmp	short a_init_exit
EndProc		api_INIT

;;::::::::::::::
;;  in: ebx= VM_CTX
;;
;; out: CF set if error
BeginProc       api_END
                assume	ebp:ptr Client_Reg_Struc

                cmp     initialized, TRUE
		jne	a_end_error

                cmp     loaded, TRUE
                jne     a_end_error

		;; del vm_ctx
		mov	edi, [ebp].Client_EBX
		call	h_vm_del

		cmp	VMs, 0
		jg	a_end_exit		;; any vm?

		;; unload winsock.dll and win32 slave
                call	h_w32_finish
                call	h_ws16_unload
                mov	loaded, FALSE

a_end_exit:	ret

a_end_error:	or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_end_exit
EndProc		api_END

;;::::::::::::::
;;  in: es:ebx-> DSVXD_STARTUP
;;
;; out: CF set if error
BeginProc       api_STARTUP, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi: ptr DSVXD_STARTUP

		;; edi= base selector
		mov	eax, [esi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_start_error		;; invalid struct?
		mov	edi, [eax].VM_CTX.baseSel

		;; correct _lpWSAData (convert farptr to sel::0)
		W16_SETDESC edi, [esi].params._lpWSAData

		;; call winsock::WSAStartup
		lea	ebx, _ws16call
		WS16_CALL DSVXD_STARTUP_CMD, esi, <T WS16_STARTUP>
		jc	a_start_error
		mov	[ebp].Client_EAX, eax

a_start_exit:	LeaveProc
		Return

a_start_error:	DEBUG_MSGBOX <Error calling winsock::WSAStartup>
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_start_exit
EndProc         api_STARTUP

;;::::::::::::::
;; out: CF set if error
BeginProc       api_CLEANUP, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc

		;; call winsock::WSACleanup
		lea	ebx, _ws16call
		WS16_CALL DSVXD_CLEANUP_CMD, NULL, 0
		jc	a_clean_error
		mov	[ebp].Client_EAX, eax

		;; ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !
		;; - shouldn't we call WSOCK2 ASYNC_SELECT service for every
		;;   socket in the linked-list of this vm and then
		;;   deallocate the nodes?
		;;   - has it to be done only when a counter would be 0?
		;; ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! ! !

a_clean_exit:	LeaveProc
		Return

a_clean_error:	DEBUG_MSGBOX <Error calling winsock::WSACleanup>
		mov	[ebp].Client_EAX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_clean_exit
EndProc         api_CLEANUP

;;::::::::::::::
;; out: CF set if error
;;	eax= last error
BeginProc       api_GETLASTERROR, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc

		;; call winsock::WSAGetLastError
		lea	ebx, _ws16call
		WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_lasterr_error
		mov	[ebp].Client_EAX, eax

a_lasterr_exit:	LeaveProc
		Return

a_lasterr_error:mov	[ebp].Client_EAX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_lasterr_exit
EndProc         api_GETLASTERROR

;;:::
BeginProc	cb_timeOut, CCALL
                ArgVar  dwRefData, DWORD
                ArgVar  dwFlags, DWORD
		EnterProc

		;; set timeout flag
		mov	eax, dwRefData
		mov	D [eax], TRUE

		;; signalize the semaphore
                mov     eax, hSem
		VMMCall Signal_Semaphore_No_Switch

		LeaveProc
		Return
EndProc		cb_timeOut

;;::::::::::::::
;;  in: es:ebx-> DSVXD_ASYNC_SEL
;;
;; out: CF set if error
BeginProc       api_ASYNCSEL, ESP
                LocalVar timeout, DWORD
                LocalVar newNode, DWORD
                EnterProc
                assume	ebp:ptr Client_Reg_Struc
                assume	eax:nothing, esi:nothing

		cmp	w32_hWnd, 0
		je	a_asyn_nohWnd		;; no hWnd? damnit!

a_asyn_cont:	;; edi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	edi, eax
		assume	edi: ptr DSVXD_ASYNC_SEL

		;; esi-> aselcb list
		mov	eax, [edi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_asyn_error
		mov	esi, [eax].VM_CTX.aselcbList

		;; search if a node for this socket already exists
		mov	newNode, FALSE
		mov	eax, [edi].params.Socket
		mov	eax, [eax].SOCK_INFO.Handle
		call	h_aselList_find
		test	eax, eax
		jnz	@F			;; found?

		xor	ecx, ecx		;; assume NULL node
                cmp     [edi].params.Events, 0
		je	@@dioc_call		;; no events?

		;; allocate a new node for ASYNCSELCB struct
		VMMCall	List_Allocate
		jc	a_asyn_error
		;; attach node to head of list
		VMMCall	List_Attach
		mov	newNode, TRUE

@@:		mov	ecx, eax		;; ecx-> node
		assume	ecx: ptr ASYNCSELCB

		;; fill node
		mov	[ecx].id, 'CB32'
		mov	[ecx].vmHandle, ebx
		;; node.socket= socket
		mov	eax, [edi].params.Socket
		mov	[ecx].socket, eax
		;; need Socket handle that will be passed to
		;; WndProc by wsock2 vxd
		mov	eax, [eax].SOCK_INFO.Handle
		mov	[ecx].hSocket, eax
		;; node.fpProc= Window; Window= win32 slave hWnd
		mov	eax, w32_hWnd
		xchg	eax, [edi].params.Window
		mov	[ecx].fpProc, eax
		;; node.cbuf= flat(cbuf)
		FP2FLAT	[edi].cbuf
		mov	[ecx].cbuf, eax
		;; node.pWrkFlag= flat(fpWrkFlag)
		FP2FLAT	[edi].fpWrkFlag
		mov	[ecx].pWrkFlag, eax
        ;; node.wMsg= Message; Message= WM_DSOCK + vm id
		mov	eax, [edi].vm_ctx
		mov	eax, [eax].VM_CTX.vm_id
        	add 	eax, WM_DSOCK
		xchg	eax, [edi].params.Message
		mov	[ecx].wMsg, eax

@@dioc_call:	push	[edi].params.Events	;; (0) save

		;; let wsock2 do the work
		PS	ecx, esi
		mov	[ebp].Client_EAX, WS2_ASYNC_SELECT_CMD
		call	ws2_v86proc
		PP	esi, ecx

		pop	eax			;; (0) restore

		cmp	[ebp].Client_EAX, 0
		jnz	@F			;; error?

		test	eax, eax
		jnz	a_asyn_exit		;; any event?

		;; delete node
@@:		test	ecx, ecx
		jz	a_asyn_exit		;; NULL node?
		cmp	newNode, TRUE
		jne	@F
		VMMCall	List_Get_First		;; must use before Remove'ng
@@:		mov	eax, ecx
		VMMCall	List_Remove
		mov	[ecx].id, 0		;; just f/ precaution
		mov	[ecx].vmHandle, 0 	;; /
		mov	[ecx].socket, 0		;; /
		mov	[ecx].hSocket, 0	;; /
		mov	eax, ecx		;; node
		VMMCall	List_Deallocate

a_asyn_exit:	LeaveProc
		Return

a_asyn_error:	mov	[ebp].Client_EAX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK ;; error
		jmp	short a_asyn_exit

;;...
a_asyn_nohWnd:	cmp	w32_hInst, 32
		jbe	a_asyn_error		;; no slave?

		pushad

		;; give some time to the win32 slave pass its hWnd
		mov	timeout, FALSE
		mov     eax, 3 * 1000		;; max 3 seconds
		lea     edx, timeout
		mov     esi, OFFSET32 cb_timeOut
		VMMCall Set_Global_Time_Out
						;; esi= timeout handle

		;; wait for semaphore be signaled (by timeout
		;; callback or by dioc_INIT)
		mov     eax, hSem
		xor     ecx, ecx		;; flags= none
		VMMCall Wait_Semaphore

		;; if no timeout, cancel it
		cmp	timeout, TRUE
		je	@F
		VMMCall	Cancel_Time_Out

@@:		popad
		cmp	w32_hWnd, 31
		ja	a_asyn_cont		;; hWnd valid?
		jmp	short a_asyn_error
EndProc         api_ASYNCSEL

;;::::::::::::::
;;  in: es:ebx-> DSVXD_HOSTBYADDR
;;	ecx= hostent struct + buffer sizes
;;	edx= /			     farptr
;;
;; out: CF set if error
;;	dx= error code
;;	eax= winsock::gethostbyaddr result
BeginProc       api_HOSTBYADDR, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi: ptr DSVXD_HOSTBYADDR

		;; edi= base selector
		mov	eax, [esi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_hbyaddr_error		;; invalid struct?
		mov	edi, [eax].VM_CTX.baseSel

		;; correct _addr (convert farptr to sel::0)
		W16_SETDESC edi, [esi].params._addr
		jz	a_hbyaddr_error

		;; call winsock::gethostbyaddr
		lea	ebx, _ws16call
		WS16_CALL DSVXD_HOSTBYADDR_CMD, esi, <T WS16_HOSTBYADDR>
		jc	a_hbyaddr_error
		mov	[ebp].Client_EAX, eax

		;; transfer returned hostent (in sysvm) to client hostent
		test	eax, eax
		jz	a_hbyaddr_null		;; error?
		call	h_hostent_conv
		jc	a_hbyaddr_error
		mov	[ebp].Client_EDX, 0

a_hbyaddr_exit:	LeaveProc
		Return

a_hbyaddr_null:	WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_hbyaddr_error
		mov	[ebp].Client_EDX, eax	;; error in dx
		jmp	short a_hbyaddr_exit

a_hbyaddr_error:DEBUG_MSGBOX <Error calling winsock::gethostbyaddr>
		mov	[ebp].Client_EDX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_hbyaddr_exit
EndProc         api_HOSTBYADDR

;;::::::::::::::
;;  in: es:ebx-> DSVXD_HOSTBYNAME
;;	ecx= hostent struct + buffer sizes
;;	edx= /			     farptr
;;
;; out: CF set if error
;;	dx= error code
;;	eax= winsock::gethostbyname result
BeginProc       api_HOSTBYNAME, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi: ptr DSVXD_HOSTBYNAME

		;; edi= base selector
		mov	eax, [esi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_hbyname_error		;; invalid struct?
		mov	edi, [eax].VM_CTX.baseSel

		;; correct _name (convert farptr to sel::0)
		W16_SETDESC edi, [esi].params._name
		jz	a_hbyname_error

		;; call winsock::gethostbyname
		lea	ebx, _ws16call
		WS16_CALL DSVXD_HOSTBYNAME_CMD, esi, <T WS16_HOSTBYNAME>
		jc	a_hbyname_error
		mov	[ebp].Client_EAX, eax

		;; transfer returned hostent (in sysvm) to client hostent
		test	eax, eax
		jz	a_hbyname_null		;; error?
		call	h_hostent_conv
		jc	a_hbyname_error
		mov	[ebp].Client_EDX, 0

a_hbyname_exit:	LeaveProc
		Return

a_hbyname_null:	WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_hbyname_error
		mov	[ebp].Client_EDX, eax	;; error in dx
		jmp	short a_hbyname_exit

a_hbyname_error:DEBUG_MSGBOX <Error calling winsock::gethostbyname>
		mov	[ebp].Client_EDX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_hbyname_exit
EndProc         api_HOSTBYNAME

;;::::::::::::::
;;  in: es:ebx-> DSVXD_HOSTNAME
;;
;; out: CF set if error
;;	eax= 0 if ok, =SOCKET_ERROR otherwise
;;	dx= error code
BeginProc       api_HOSTNAME, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi:ptr DSVXD_HOSTNAME

		;; edi= base selector
		mov	eax, [esi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_hname_error		;; invalid struct?
		mov	edi, [eax].VM_CTX.baseSel

		;; correct _name (convert farptr to sel::0)
		W16_SETDESC edi, [esi].params._name
		jz	a_hname_error

		;; call winsock::gethostname
		lea	ebx, _ws16call
		WS16_CALL DSVXD_HOSTNAME_CMD, esi, <T WS16_HOSTNAME>
		jc	a_hname_error
		movsx	eax, ax
		mov	[ebp].Client_EAX, eax
		test	eax, eax
		jnz	a_hname_sckerr
		mov	[ebp].Client_EDX, 0

a_hname_exit:	LeaveProc
		Return

a_hname_sckerr: WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_hname_error
		mov	[ebp].Client_EDX, eax	;; error in dx
		jmp	short a_hname_exit

a_hname_error:	DEBUG_MSGBOX <Error calling winsock::gethostname>
		mov	[ebp].Client_EDX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_hname_exit
EndProc         api_HOSTNAME

;;::::::::::::::
;;  in: es:ebx-> DSVXD_SERVBYNAME
;;	ecx= servent struct + buffer sizes
;;	edx= /			     farptr
;;
;; out: CF set if error
;;	dx= error code
;;	eax= winsock::getservbyname result
BeginProc       api_SERVBYNAME, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi:ptr DSVXD_SERVBYNAME

		;; edi= base selector
		mov	eax, [esi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_sbyname_error		;; invalid struct?
		mov	edi, [eax].VM_CTX.baseSel

		;; correct _name (convert farptr to sel::0)
		W16_SETDESC edi, [esi].params._name
		jz	a_sbyname_error
		;; and _proto
		add	edi, 8			;; next selector
		W16_SETDESC edi, [esi].params._proto
		jz	a_sbyname_error

		;; call winsock::getservbyname
		lea	ebx, _ws16call
		WS16_CALL DSVXD_SERVBYNAME_CMD, esi, <T WS16_SERVBYNAME>
		jc	a_sbyname_error
		mov	[ebp].Client_EAX, eax

		;; transfer returned servent (in sysvm) to client servent
		test	eax, eax
		jz	a_sbyname_null		;; error?
		call	h_servent_conv
		jc	a_sbyname_error
		mov	[ebp].Client_EDX, 0

a_sbyname_exit:	LeaveProc
		Return

a_sbyname_null:	WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_sbyname_error
		mov	[ebp].Client_EDX, eax	;; error in dx
		jmp	short a_sbyname_exit

a_sbyname_error:DEBUG_MSGBOX <Error calling winsock::getservbyname>
		mov	[ebp].Client_EDX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_sbyname_exit
EndProc         api_SERVBYNAME

;;::::::::::::::
;;  in: es:ebx-> DSVXD_SERVBYPORT
;;	ecx= servent struct + buffer sizes
;;	edx= /			     farptr
;;
;; out: CF set if error
;;	dx= error code
;;	eax= winsock::getservbyport result
BeginProc       api_SERVBYPORT, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi:ptr DSVXD_SERVBYPORT

		;; edi= base selector
		mov	eax, [esi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_sbyport_error		;; invalid struct?
		mov	edi, [eax].VM_CTX.baseSel

		;; correct _proto (convert farptr to sel::0)
		W16_SETDESC edi, [esi].params._proto
		jz	a_sbyport_error

		;; call winsock::getservbyport
		lea	ebx, _ws16call
		WS16_CALL DSVXD_SERVBYPORT_CMD, esi, <T WS16_SERVBYPORT>
		jc	a_sbyport_error
		mov	[ebp].Client_EAX, eax

		;; transfer returned servent (in sysvm) to client servent
		test	eax, eax
		jz	a_sbyport_null		;; error?
		call	h_servent_conv
		jc	a_sbyport_error
		mov	[ebp].Client_EDX, 0

a_sbyport_exit:	LeaveProc
		Return

a_sbyport_null:	WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_sbyport_error
		mov	[ebp].Client_EDX, eax	;; error in dx
		jmp	short a_sbyport_exit

a_sbyport_error:DEBUG_MSGBOX <Error calling winsock::getservbyport>
		mov	[ebp].Client_EDX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_sbyport_exit
EndProc         api_SERVBYPORT

;;::::::::::::::
;;  in: es:ebx-> DSVXD_PROTOBYNUMBER
;;	ecx= protoent struct + buffer sizes
;;	edx= /	 		      farptr
;;
;; out: CF set if error
;;	dx= error code
;;	eax= winsock::getprotobynumber result
BeginProc       api_PROTOBYNUMBER, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi:ptr DSVXD_PROTOBYNUMBER

		;; call winsock::getprotobyname
		lea	ebx, _ws16call
		WS16_CALL DSVXD_PROTOBYNUMBER_CMD, esi, <T WS16_PROTOBYNUMBER>
		jc	a_pbynum_error
		mov	[ebp].Client_EAX, eax

		;; transfer returned protoent (in sysvm) to client protoent
		test	eax, eax
		jz	a_pbynum_null		;; error?
		call	h_protoent_conv
		jc	a_pbynum_error
		mov	[ebp].Client_EDX, 0

a_pbynum_exit:	LeaveProc
		Return

a_pbynum_null:	WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_pbynum_error
		mov	[ebp].Client_EDX, eax	;; error in dx
		jmp	short a_pbynum_exit

a_pbynum_error:	DEBUG_MSGBOX <Error calling winsock::getprotobynumber>
		mov	[ebp].Client_EDX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_pbynum_exit
EndProc         api_PROTOBYNUMBER

;;::::::::::::::
;;  in: es:ebx-> DSVXD_PROTOBYNAME
;;	ecx= protoent struct + buffer sizes
;;	edx= /	 		      farptr
;;
;; out: CF set if error
;;	dx= error code
;;	eax= winsock::getprotobyname result
BeginProc       api_PROTOBYNAME, ESP
                LocalVar _ws16call, <T WS16CALL>
                EnterProc
                assume	ebp:ptr Client_Reg_Struc, eax:nothing

		;; esi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	esi, eax
		assume	esi:ptr DSVXD_PROTOBYNAME

		;; edi= base selector
		mov	eax, [esi].vm_ctx
		cmp	[eax].VM_CTX.id, 'VCTX'
		jne	a_pbyname_error		;; invalid struct?
		mov	edi, [eax].VM_CTX.baseSel

		;; correct _name (convert farptr to sel::0)
		W16_SETDESC edi, [esi].params._name
		jz	a_pbyname_error

		;; call winsock::getprotobyname
		lea	ebx, _ws16call
		WS16_CALL DSVXD_PROTOBYNAME_CMD, esi, <T WS16_PROTOBYNAME>
		jc	a_pbyname_error
		mov	[ebp].Client_EAX, eax

		;; transfer returned protoent (in sysvm) to client protoent
		test	eax, eax
		jz	a_pbyname_null		;; error?
		call	h_protoent_conv
		jc	a_pbyname_error
		mov	[ebp].Client_EDX, 0

a_pbyname_exit:	LeaveProc
		Return

a_pbyname_null:	WS16_CALL DSVXD_GETLASTERROR_CMD, NULL, 0
		jc	a_pbyname_error
		mov	[ebp].Client_EDX, eax	;; error in dx
		jmp	short a_pbyname_exit

a_pbyname_error:DEBUG_MSGBOX <Error calling winsock::getprotobyname>
		mov	[ebp].Client_EDX, 'EINT';; internal error
		or     	[ebp].Client_EFlags, CF_MASK
		jmp	short a_pbyname_exit
EndProc         api_PROTOBYNAME

;;::::::::::::::
;;  in: es:ebx-> DSVXD_RECV
BeginProc       api_RECV
                assume	ebp:ptr Client_Reg_Struc

		;; edi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	edi, eax
		assume	edi:ptr DSVXD_RECV

		;; map to flat WSABUF.buf fields in WS2_RECV.Buffers array
		cmp	[edi].buf2lin, 0
		jne	@@done			;; do not map to flat?
		FP2FLAT	[edi].params.Buffers
		mov	esi, eax
		mov	ecx, [edi].params.BufferCount
		call	h_buf2lin

@@done:		;; let wsock2 do the work
		mov	[ebp].Client_EAX, WS2_RECV_CMD
		jmp	ws2_v86proc
EndProc         api_RECV

;;::::::::::::::
;;  in: es:ebx-> DSVXD_SEND
BeginProc       api_SEND
                assume	ebp:ptr Client_Reg_Struc

		;; edi= flat(es:ebx)
		mov	eax, (Client_Reg_Struc.Client_ES * 256) or Client_Reg_Struc.Client_EBX
		VMMCall	Map_Flat
		mov	edi, eax
		assume	edi:ptr DSVXD_SEND

		;; AddrLenPtr field isn't at start of the struct as it should
		FP2FLAT [edi].params.AddrLenPtr
		mov	[edi].params.AddrLenPtr, eax

		;; map to flat WSABUF.buf fields in WS2_SEND.Buffers array
		cmp	[edi].buf2lin, 0
		jne	@@done			;; do not map to flat?
		FP2FLAT	[edi].params.Buffers
		mov	esi, eax
		mov	ecx, [edi].params.BufferCount
		call	h_buf2lin

@@done:		;; let wsock2 do the work
		mov	[ebp].Client_EAX, WS2_SEND_CMD
		jmp	ws2_v86proc
EndProc         api_SEND
VxD_LOCKED_CODE_ENDS
                end
