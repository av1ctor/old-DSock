@echo off
set $INCLUDE=%INCLUDE%
set INCLUDE=c:\prg\asm\masm\include\
set $src=dsock

ml /c /Cp /coff /Iinc /D__WIN32__ vdd\%$src%.asm vdd\w32.asm vdd\vdd.asm lib\llist.asm

rc /I%INCLUDE% /DOFFICIAL_BUILD /DVER_LANGNEUTRAL vdd\%$src%.rc

link /dll /subsystem:WINDOWS /version:4.0 /machine:IX86 /def:vdd\%$src%.def %$src%.obj w32.obj vdd.obj llist.obj vdd\%$src%.res

if exist vdd\%$src%.res del vdd\%$src%.res
if exist %$src%.obj del %$src%.obj
if exist %$src%.lib del %$src%.lib
if exist %$src%.exp del %$src%.exp
if exist %$src%.dll move %$src%.dll ..\bin
if exist w32.obj del w32.obj
if exist vdd.obj del vdd.obj
if exist llist.obj del llist.obj

set $src=
set INCLUDE=%$INCLUDE%
