@echo off
set BCPATH=c:\prg\cmp\bc

bcc.exe -c -X -d -mm -3 -f2 -G -O2l -I%BCPATH%\include %1.c
rem -D__DEBUG__ 
tlink /Tde /3 /L%BCPATH%\lib c0m+queue+%1,%1.exe,nul,cm+..\..\lib\dsock

if exist %1.exe move /y %1.exe ..\..\bin
if exist %1.obj del %1.obj

set BCPATH=
