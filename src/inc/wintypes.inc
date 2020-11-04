ifndef		__WINTYPES_INC__
                __WINTYPES_INC__ equ 1
		
if		(@Model eq MODEL_FLAT)
		size_t          textequ <dword>
		FARPROC		textequ	<>
else
                size_t          textequ <word>
                FARPROC         textequ <far>
endif
		;PFARPROC	typedef	tNEARPTR FARPROC

                VOID            textequ	<>
                PVOID          	typedef NEARPTR VOID
                LPVOID          typedef FARPTR VOID

	;;;;;;;;BYTE		typedef sbyte
                PBYTE           typedef NEARPTR BYTE
                LPBYTE          typedef FARPTR BYTE

                CHAR		textequ <sbyte>
                PCHAR           typedef NEARPTR CHAR
                LPCHAR          typedef FARPTR CHAR
		UCHAR		textequ <byte>
                PUCHAR          typedef NEARPTR UCHAR
                LPUCHAR         typedef FARPTR UCHAR
                PSTR           	typedef NEARPTR CHAR
                LPSTR          	typedef FARPTR CHAR

                _SHORT          textequ <sword>
                PSHORT          typedef NEARPTR _SHORT
                LPSHORT         typedef FARPTR _SHORT
                USHORT          textequ <word>
                PUSHORT         typedef NEARPTR USHORT
                LUPSHORT        typedef FARPTR USHORT
                
                SINT		textequ <size_t>
                PSINT		typedef NEARPTR SINT
                LPSINT		typedef FARPTR SINT                
                UINT		textequ <size_t>
                PUINT		typedef NEARPTR UINT
                LPUINT		typedef FARPTR UINT
                
                LONG            textequ <sdword>
                PLONG		typedef NEARPTR LONG
                LPLONG		typedef FARPTR LONG
                SLONG		textequ <LONG>
                PSLONG		typedef PLONG
                LPSLONG		typedef LPLONG
                ULONG		textequ <dword>
                PULONG		typedef NEARPTR ULONG
                LPULONG		typedef FARPTR ULONG

                BOOL		textequ <SINT>
                PBOOL        	typedef NEARPTR BOOL
                LPBOOL       	typedef FARPTR BOOL
                BOOLEAN         textequ <UCHAR>
                PBOOLEAN        typedef PBOOL
                LPBOOLEAN       typedef LPBOOL

		HWND		textequ <LPVOID>
                                
endif		;; __WINTYPES_INC__
