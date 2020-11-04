;;
;; llist.inc -- linked-list module protos/structs
;;

ifndef          __llist_inc__
                __llist_inc__ 	equ 1


LLST		struct
		_ptr		tFARPTR	?	;; -> list
		fhead		tNEARPTR ?	;; -> 1st free node
		atail		tNEARPTR ?	;; -> last allocated node
	ifdef	__WIN32__
		hMutex		dword	?
	endif
LLST		ends

NODE		struct
                prev		tNEARPTR ?	;; -> preview node
                next		tNEARPTR ?	;; -> next node
NODE		ends



		ListCreate	proto near pascal :NEARPTR LLST, :word, :word

		ListDestroy	proto near pascal :NEARPTR LLST

		ListAlloc	proto near pascal :NEARPTR LLST

		ListFree	proto near pascal :NEARPTR LLST, :NEARPTR

		ListLast	proto near pascal :NEARPTR LLST

		ListPrev	proto near pascal

endif   	;; __llist_inc__
