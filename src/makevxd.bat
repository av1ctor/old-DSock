@echo off
set $INCLUDE=%INCLUDE%
set INCLUDE=c:\prg\asm\masm\include\
set $src=dsock

ml /coff /c /Cx /DMASM6 /DBLD_COFF /DIS_32 /DWIN40COMPAT /DNEWSTRUCTS /DNO_MASM6_OPTIONS /Iinc %1 %2 vxd\%$src%.asm

link /vxd /nod /machine:IX86 /align:256 /def:vxd\%$src%.def %$src%.obj

if exist %$src%.obj del %$src%.obj
if exist %$src%.lib del %$src%.lib
if exist %$src%.exp del %$src%.exp
if exist %$src%.vxd move %$src%.vxd ..\bin
      
:end
set $src=
set INCLUDE=%$INCLUDE%
