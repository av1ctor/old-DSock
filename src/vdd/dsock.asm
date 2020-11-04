;;
;; dsock.asm -- HL interface f/ DSock VDD and dumb DSock VxD slave
;;

		.386
		.model	flat, stdcall
		option	proc:private

		include windows.inc
		include	equ.inc
		include vdd.inc
		include w32.inc

		include kernel32.inc
		includelib kernel32.lib


.data
isNT 		dword 	FALSE


.code
;;:::
is_NT 		proc
		local	os:OSVERSIONINFOA
		mov	os.dwOSVersionInfoSize, T OSVERSIONINFOA
		invoke	GetVersionEx, A os
		mov	eax, TRUE
		cmp	os.dwPlatformId, VER_PLATFORM_WIN32_NT
		je	@F
		mov	eax, FALSE
@@:		ret
is_NT		endp

;;::::::::::::::
DSock_DllMain   proc    public\
			DllHandle:PVOID,\
			Reason:dword,\
			Context:dword

                invoke	is_NT
		mov	isNT, eax

		cmp	eax, TRUE
		jne	@F
		invoke	vdd_DllMain, Reason, DllHandle
		jmp	short @@exit

@@:    		invoke	w32_DllMain, Reason, DllHandle

@@exit:		ret
DSock_DllMain   endp
        	end 	DSock_DllMain
