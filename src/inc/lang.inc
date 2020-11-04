;;
;; lang.inc -- language/compiler dependent
;;

ifndef          __LANG_INC__
                __LANG_INC__    equ 1


ifndef		__WIN32__
ifidn		__CMP__, <BC>
                __LANG_C__      equ     1
                __MEM_MODEL__	textequ	<medium>
                __LANG_TYPE__	textequ	<c>
                __PUBLIC__      equ	public
                __END__		equ	end
                __CONST__	textequ	<.const>
                __BSS__		textequ	<.data?>

elseifidn	__CMP__, <TP>
                __LANG_PAS__    equ     1
                __MEM_MODEL__	textequ	<large>
                __LANG_TYPE__	textequ	<pascal>
                __PUBLIC__      equ	private
                __END__		textequ <>
                __CONST__	textequ	<.data>
                __BSS__		textequ	<.data>

else            ;; <QB> or <PDS> or <VBD>
                __LANG_BAS__    equ     1
                __MEM_MODEL__	textequ	<medium>
                __LANG_TYPE__	textequ	<pascal>
                __PUBLIC__      equ	public
                __END__		equ	end
                __CONST__	textequ	<.const>
                __BSS__		textequ	<.data?>

   ifdif        __CMP__, <QB>
                __FAR_STRINGS__ equ     1
   endif
endif		;; __CMP__

else		;; __WIN32__
                __MEM_MODEL__	textequ	<flat>
                __LANG_TYPE__	textequ	<stdcall>
                __PUBLIC__      equ	public
                __END__		equ	end
                __CONST__	textequ	<.const>
                __BSS__		textequ	<.data?>
endif		;; __WIN32__


ifdef           __LANG_BAS__
BASSTR         	struct
        ifndef  __FAR_STRINGS__
                len             word  	?       ;; QB's near strg descriptor
                ofs             word  	?
        else
                ofs_tb          word   	?       ;; QBX's far strg descriptor
                seg_tb          word   	?
        endif
BASSTR         	ends

ifdef   	__FAR_STRINGS__
FSTRG           struct                         	;; QBX's far string
                len             word   	?
                dat             byte   	?       ;; ...
FSTRG           ends
endif

;;::::::::::::::
;; get address and length of a BASIC string
;; ! ss must -> DGROUP
BSTRG           macro   ?strg_dsc:req, ?sg:req, ?of:req, ?len
	ifndef  __FAR_STRINGS__
                mov     ?of, ?strg_dsc
        ifnb    <?len>
                mov     ?len, ss:[?of].BASSTR.len
        endif
                push    ss
                pop     ?sg
                mov     ?of, ss:[?of].BASSTR.ofs

	else
                mov     ?of, ?strg_dsc
                push    ss:[?of].BASSTR.ofs_tb

                mov     ?of, ss:[?of].BASSTR.seg_tb
                mov     ?sg, ss:[?of]		;; get strg seg from seg_tb

                pop     ?of
                mov     ?of, ?sg:[?of]         	;; get strg ofs from ?sg:ofs_tb
        ifnb    <?len>
                mov     ?len, ?sg:[?of].FSTRG.len;; ?len= string length
        endif
                lea     ?of, [?of].FSTRG.dat  	;; ?sg:?of -> string data
	endif
endm


;;::::::::::::::
;; fill a BASIC string descriptor with address and length
;; ! ss and string must -> DGROUP
;; ! offs -> string data, and could be destroyed
BSTRS           macro   ?dsc:req, ?ofs:req, ?len:req
	ifndef  __FAR_STRINGS__
                mov     ss:[?dsc].BASSTR.len, ?len
                mov     ss:[?dsc].BASSTR.ofs, ?ofs
	else
                sub     ?ofs, 2                	;; -> string len

                ;; set far string tables
                mov     fstr_segTb, ss
                mov     fstr_ofsTb+2, ?ofs

                mov     ss:[?ofs].FSTRG.len, ?len;; set string length

                ;; set far string descriptor
                mov     ?ofs, O fstr_segTb
                mov     ss:[?dsc].BASSTR.seg_tb, ?ofs

                mov     ?ofs, O fstr_ofsTb+2
                mov     ss:[?dsc].BASSTR.ofs_tb, ?ofs
	endif
endm

		B$ASSN		proto far pascal src:far ptr, srclen:word,\
					 	 dst:far ptr, dstlen:word

elseifdef	__LANG_PAS__
PASSTR         	struct
                len             byte  	?
                _data         	byte  	?	;; ...
PASSTR         	ends

endif           ;; __LANG_BAS__


ifdef		__LANG_BAS__
		STRING		textequ	<NEARPTR BASSTR>
elseifdef	__LANG_PAS__
                STRING		textequ	<FARPTR PASSTR>
else
		STRING		textequ	<FARPTR CHAR>
endif


;;::::::::::::::
ONEXIT          macro   ?proc:req
    ifdef       __LANG_BAS__
                B_ONEXIT        proto far pascal :dword
                invoke  B_ONEXIT, ?proc
    elseifdef   __LANG_C__
                atexit          proto far c :dword
                invoke  atexit, ?proc
    elseifdef   __LANG_PAS__
		mov	eax, exitproc
		mov	last_exitproc, eax
		mov	W exitproc+0, O ?proc
		mov	W exitproc+2, S ?proc
    else
	ifndef	__WIN32__
    		.err	ERROR: no atexit()
    	endif
    endif
endm

;;::::::::::::::
MALLOC		macro   ?bytes:req
    ifdef       __LANG_BAS__
                qb_malloc	proto far pascal :dword
                invoke  qb_malloc, ?bytes
    elseifdef   __LANG_C__
                farmalloc	proto far c :dword
                PS	bx, es
                invoke  farmalloc, ?bytes
                PP	es, bx
    elseifdef   __LANG_PAS__
                pas_malloc	proto far pascal :dword
                invoke  pas_malloc, ?bytes
    else
    	ifndef	__WIN32__
    		.err	ERROR: no malloc()
    	else
                invoke	LocalAlloc, LPTR, ?bytes
    	endif
    endif
endm

;;::::::::::::::
FREE		macro   ?ptr:req
    ifdef       __LANG_BAS__
                qb_free		proto far pascal :dword
                invoke  qb_free, ?ptr
    elseifdef   __LANG_C__
                farfree		proto far c :dword
                PS	bx, es
                invoke  farfree, ?ptr
                PP	es, bx
    elseifdef   __LANG_PAS__
                pas_free	proto far pascal :dword
                invoke  pas_free, ?ptr
    else
    	ifndef	__WIN32__
    		.err	ERROR: no free()
    	else
    		invoke	LocalFree, ?ptr
    	endif
    endif
endm


	ifidni	__MEM_MODEL__, <flat>
                .386
	endif
                .model  __MEM_MODEL__, __LANG_TYPE__
	ifdifi	__MEM_MODEL__, <flat>
		.386
	endif
                option  proc:private

endif           ;; __LANG_INC__
