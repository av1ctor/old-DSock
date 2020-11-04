;;
;; drvDOS.asm -- DOS driver (a stub for now, maybe using WATT-32 TSR later??)
;;

                include lang.inc

                include equ.inc
                include intern.inc


DS_FIXSEG
drv_DOS         label   DSDRV
                tNEARPTR dos_init, dos_end
DS_ENDS


DS_CODE
;;::::::::::::::
;; out: ax= 0 if ok
dos_init	proc    near pascal
                mov     ax, -1                  ;; return false
                ret
dos_init	endp

;;::::::::::::::
dos_end		proc    near pascal
                mov     ax, -1                  ;; return false
                ret
dos_end 	endp
DS_ENDS
                __END__
