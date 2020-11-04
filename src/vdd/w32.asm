;;
;; w32.asm -- the dumb win32 slave for dsock VxD
;;

		.386
		.model	flat, stdcall
		option	proc:private

		include windows.inc
		include	equ.inc
		include wsock2.inc
        	include dsockvxd.inc

                include kernel32.inc
                include user32.inc
                includelib kernel32.lib
                includelib user32.lib


.const
dsockvxd_zs 	byte    "\\.\DSOCK.VXD", 0
dsock_zs    	byte    "DSock", 0

.data?
dsock_h     	dword   ?
hInstance	dword	?
hWnd		dword	?


.code
;;::::::::::::::
w32_DllMain	proc	public\
			Reason:dword,\
			DllHandle:PVOID

		cmp	Reason, DLL_PROCESS_ATTACH
		jne	@@detach

		mov	eax, DllHandle
		mov	hInstance, eax

		;; link with vxd
        	invoke  CreateFile, A dsockvxd_zs, GENERIC_READ,\
				    FILE_SHARE_READ or FILE_SHARE_WRITE,\
				    NULL, OPEN_EXISTING,\
                                    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_DELETE_ON_CLOSE,\
                                    NULL
		cmp	eax, INVALID_HANDLE_VALUE
		je	@@error
        	mov 	dsock_h, eax

@@done:		mov	eax, TRUE
@@exit:		ret

@@detach:	cmp	Reason, DLL_PROCESS_DETACH
		jne	@@done
		;; link no more needed
        	cmp 	dsock_h, 0
		je	@@done
        	invoke  CloseHandle, dsock_h
                mov 	dsock_h, 0
                jmp	short @@done

@@error:	mov	eax, FALSE
		jmp	short @@exit
w32_DllMain	endp

;;::::::::::::::
w32_init	proc	public\
			_hWnd:HWND,\
			_hInst:HINSTANCE,\
			_lpszCmdLine:LPSTR,\
			_nCmdShow:dword

		local	bRet:dword

                ;; create a hidden dumb window
		call	create_win
		test	eax, eax
		jz	@@done
		mov	hWnd, eax

        	;; pass the hWnd to dsock vxd
        	invoke  DeviceIoControl, dsock_h, DSVXD_INIT_CMD,\
					 A hWnd, T dword, NULL, 0,\
					 A bRet, NULL
		test	eax, eax
		jz	@@done

                ;; check every 3 secs if still used by the vxd
                invoke	SetTimer, hWnd, 12345678h, 1000 * 3, NULL

                ;; run until dsock vxd send the DESTROY msg
		call	getmsg_loop

		invoke	KillTimer, hWnd, 12345678h

		;; clean up
        	cmp 	dsock_h, 0
		je	@@exit
        	invoke  DeviceIoControl, dsock_h, DSVXD_END_CMD,\
					 NULL, 0, NULL, 0,\
					 A bRet, NULL

@@done:     	invoke  CloseHandle, dsock_h
        	mov 	dsock_h, 0

@@exit:		ret
w32_init	endp

;;:::
getmsg_loop	proc
		local	msg:MSG

		jmp	short @F
@@loop:		cmp	eax, -1
		je	@@exit
		invoke	DispatchMessage, A msg
@@:		cmp	hWnd, 0
		je	@@exit
		invoke	GetMessage, A msg, hWnd, 0, 0
		test	eax, eax
		jnz	@@loop

@@exit:		ret
getmsg_loop	endp

;;:::
WindowProc 	proc 	_hWnd:HWND, _wMsg:UINT, _wParam:WPARAM, _lParam:LPARAM
		local	dmsg:DSVXD_MSG, OutBuffer[2]:dword, bRet:dword

		movzx	eax, W _wMsg

        	cmp 	eax, WM_DSOCK
		jb	@@user

        	;; pass msg to dsock vxd
        	cmp 	dsock_h, 0
		je	@@done
		mov	eax, _wMsg
		mov	dmsg.wMsg, eax
		mov	eax, _wParam
		mov	dmsg.wParam, eax
		mov	eax, _lParam
		mov	dmsg.lParam, eax
        	invoke  DeviceIoControl, dsock_h, DSVXD_MSG_CMD,\
					 A dmsg, T DSVXD_MSG,\
					 NULL, 0, A bRet, NULL

@@done:		xor	eax, eax

@@exit:		ret

@@user:		cmp	eax, WM_TIMER
		jne	@F
        	cmp 	dsock_h, 0
		je	@@quit
        	invoke  DeviceIoControl, dsock_h, DSVXD_VERSION_CMD,\
					 NULL, 0, A OutBuffer, 4+4,\
					 A bRet, NULL
		test	eax, eax
		jz	@@quit
		mov	eax, hWnd
		cmp	OutBuffer+4, eax
		jne	@@quit			;; hWnd's not the same?
		jmp	short @@done

@@:		cmp	eax, WM_DESTROY
		jne	@@default
@@quit:		invoke	PostQuitMessage, NULL
		jmp	short @@done

@@default:      invoke	DefWindowProc, _hWnd, _wMsg, _wParam, _lParam
            	jmp	short @@exit
WindowProc	endp

;;:::
;; out: eax= hWnd
create_win	proc
   		local	hw:WNDCLASSEX

   		mov	hw.cbSize, T WNDCLASSEX
		mov	hw.style, CS_HREDRAW or CS_VREDRAW
		mov	hw.lpfnWndProc, O WindowProc
		mov	eax, hInstance
		mov	hw.hInstance, eax
        	mov 	hw.lpszClassName, O dsock_zs
		mov	hw.cbClsExtra, 0
		mov	hw.cbWndExtra, 0
		mov	hw.hbrBackground, 0
		mov	hw.lpszMenuName, NULL
		mov	hw.hIcon, NULL
		mov	hw.hIconSm, NULL
		mov	hw.hCursor, NULL

		invoke	RegisterClassEx, A hw
		and	eax, 0000FFFFh

        	invoke  CreateWindowEx, NULL, eax, A dsock_zs,\
                                        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,\
        				CW_USEDEFAULT, CW_USEDEFAULT,\
        				CW_USEDEFAULT, NULL, NULL,\
        				hInstance, NULL

                ret
create_win	endp
		end
