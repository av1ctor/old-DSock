                
ifndef		__W32_INC__
		__W32_INC__	equ 1
		
		w32_DllMain	proto	:dword, :PVOID

		w32_init	proto	:dword, :dword, :dword, :dword

endif		;; __W32_INC__