@echo off
set $src=dsock
set $qlblib=
set $extlib=

if [%1]==[] goto usage
goto %1

:build
ml /c /Cp /Iinc /D__CMP__=%1 lib\%$src%.asm lib\drv9x.asm lib\drvNT.asm lib\drvDOS.asm lib\llist.asm lib\cbuf.asm

lib16 ..\lib\%$libname%.lib -+%$src%-+drv9x-+drvNT-+drvDOS-+llist-+cbuf%$extlib%;
if exist ..\lib\%$libname%.bak del ..\lib\%$libname%.bak

if [%$qlblib%]==[] goto done

link16 /q /seg:800 ..\lib\%$libname%.lib,..\lib\%$libname%.qlb,nul,%$qlblib%;

:done
if exist %$src%.obj del %$src%.obj
if exist drv9x.obj del drv9x.obj
if exist drvNT.obj del drvNT.obj
if exist drvDOS.obj del drvDOS.obj
if exist llist.obj del llist.obj
if exist cbuf.obj del cbuf.obj
goto end

:BC
set $libname=%$src%
goto build

:QB
set $libname=%$src%qb
set $qlblib=bqlb45
set $extlib=-+c:\prg\cmp\qb\lib\qb.lib
goto build

:PDS
set $libname=%$src%pds
set $qlblib=qbxqlb
set $extlib=-+c:\prg\cmp\pds\lib\qbx.lib
goto build

:VBD
set $libname=%$src%vbd
set $qlblib=vbdosqlb
set $extlib=-+c:\prg\cmp\vbd\lib\vbdos.lib
goto build

:TP
ml /c /Cp /Iinc /D__CMP__=TP lib\%$src%.asm
tpc -GD %$src%.pas
if exist %$src%.obj del %$src%.obj
if exist %$src%.tpu move %$src%.tpu ..\lib
goto end

:usage
echo. usage: makelib BC or QB or PDS or VBD or TP

:end
set $libname=
set $extlib=
set $qlblib=
set $src=
